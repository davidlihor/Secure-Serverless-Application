import boto3
import json
import datetime
import base64
from config_helper import get_kms_key_id, get_cloudfront_key_id

kms_client = boto3.client('kms')

_CF_KEY_ID = None


def get_cf_key_id():
    global _CF_KEY_ID
    if _CF_KEY_ID is None:
        _CF_KEY_ID = get_cloudfront_key_id()
    return _CF_KEY_ID


def lambda_handler(event, context):
    try:
        KMS_KEY_ARN = get_kms_key_id()
        CF_KEY_ID = get_cf_key_id()

        headers = event.get('headers', {})
        cf_domain = headers.get('X-CloudFront-Domain') or headers.get('x-cloudfront-domain')

        if not cf_domain:
            return {"statusCode": 400, "body": json.dumps({"error": "X-CloudFront-Domain header required"})}

        cf_domain = cf_domain.replace('https://', '').replace('http://', '').rstrip('/')

        try:
            user_id = event['requestContext']['authorizer']['claims']['sub']
        except (KeyError, TypeError):
            return {"statusCode": 401, "body": json.dumps({"error": "Unauthorized - Cognito claims missing"})}

        resource_url = f"https://{cf_domain}/users/{user_id}/*"

        expiry = int((datetime.datetime.now() + datetime.timedelta(hours=2)).timestamp())

        policy = {
            "Statement": [{
                "Resource": resource_url,
                "Condition": {"DateLessThan": {"AWS:EpochTime": expiry}}
            }]
        }
        policy_json = json.dumps(policy).replace(" ", "")

        kms_response = kms_client.sign(
            KeyId=KMS_KEY_ARN,
            Message=policy_json.encode('utf-8'),
            MessageType='RAW',
            SigningAlgorithm='RSASSA_PKCS1_V1_5_SHA_256'
        )

        def cf_base64(data):
            return base64.b64encode(data).decode('utf-8').replace('+', '-').replace('/', '~').replace('=', '_')

        encoded_policy = cf_base64(policy_json.encode('utf-8'))
        encoded_signature = cf_base64(kms_response['Signature'])

        cookie_attrs = f"Path=/; Domain={cf_domain}; HttpOnly; Secure; SameSite=None"

        return {
            "statusCode": 200,
            "multiValueHeaders": {
                "Set-Cookie": [
                    f"CloudFront-Policy={encoded_policy}; {cookie_attrs}",
                    f"CloudFront-Signature={encoded_signature}; {cookie_attrs}",
                    f"CloudFront-Key-Pair-Id={CF_KEY_ID}; {cookie_attrs}",
                    f"CloudFront-Hash-Algorithm=SHA256; {cookie_attrs}"
                ]
            },
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": f"https://{cf_domain}",
                "Access-Control-Allow-Credentials": "true"
            },
            "body": json.dumps({
                "status": "Access Granted",
                "folder": f"/users/{user_id}/",
                "domain": cf_domain
            })
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {"statusCode": 500, "body": json.dumps({"error": "Internal Server Error"})}

