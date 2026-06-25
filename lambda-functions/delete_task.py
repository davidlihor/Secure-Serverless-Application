import json
import boto3
from config_helper import get_delete_queue_url

sqs = boto3.client('sqs')
_queue_url = None


def get_queue_url():
    global _queue_url
    if _queue_url is None:
        _queue_url = get_delete_queue_url()
    return _queue_url


def lambda_handler(event, context):
    try:
        user_id = event['requestContext']['authorizer']['claims']['sub']
        task_id = event['pathParameters']['taskId']

        message = {
            'userId': user_id,
            'taskId': task_id,
            'requestedAt': context.aws_request_id,
            'source': 'api_gateway'
        }

        response = sqs.send_message(
            QueueUrl=get_queue_url(),
            MessageBody=json.dumps(message),
            MessageAttributes={
                'taskId': {
                    'StringValue': task_id,
                    'DataType': 'String'
                },
                'userId': {
                    'StringValue': user_id,
                    'DataType': 'String'
                }
            }
        )

        print(f"Queued deletion: task={task_id}, messageId={response['MessageId']}")

        return {
            'statusCode': 202,
            'headers': get_cors_headers(event),
            'body': json.dumps({
                'message': 'Task deletion queued successfully',
                'taskId': task_id,
                'messageId': response['MessageId'],
                'status': 'PENDING_CLEANUP'
            })
        }

    except KeyError as e:
        print(f"Missing key: {e}")
        return {
            'statusCode': 401,
            'headers': get_cors_headers(event),
            'body': json.dumps({'error': 'Unauthorized - Invalid token'})
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(event),
            'body': json.dumps({'error': 'Internal server error'})
        }


def get_cors_headers(event=None):
    headers = event.get('headers', {}) if event else {}
    origin = headers.get('origin') or headers.get('Origin') or '*'
    return {
        'Access-Control-Allow-Origin': origin,
        'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-CloudFront-Domain,x-cloudfront-domain',
        'Access-Control-Allow-Methods': 'OPTIONS,POST,GET,PUT,DELETE',
        'Access-Control-Allow-Credentials': 'true'
    }