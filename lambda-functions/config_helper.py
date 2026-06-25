import os
import json
import urllib3

_http = urllib3.PoolManager()

_EXTENSION_PORT = os.environ.get('PARAMETERS_SECRETS_EXTENSION_HTTP_PORT', '2773')
_AWS_SESSION_TOKEN = os.environ['AWS_SESSION_TOKEN']
_PARAMETER_PREFIX = os.environ.get('SSM_PARAMETER_PREFIX', '')


def get_parameter(param_name, with_decryption=False):
    if not param_name.startswith('/'):
        param_name = f"{_PARAMETER_PREFIX}/{param_name}"

    url = f"http://localhost:{_EXTENSION_PORT}/systemsmanager/parameters/get/?name={param_name}"
    if with_decryption:
        url += "&withDecryption=true"
    headers = {"X-Aws-Parameters-Secrets-Token": _AWS_SESSION_TOKEN}
    try:
        response = _http.request("GET", url, headers=headers, timeout=5.0)
        if response.status != 200:
            raise Exception(f"Failed to get parameter: {response.status} {response.data}")

        data = json.loads(response.data)
        return data['Parameter']['Value']
    except Exception as e:
        raise Exception(f"Error retrieving parameter {param_name}: {str(e)}")


def get_secret(secret_arn):
    url = f"http://localhost:{_EXTENSION_PORT}/secretsmanager/get?secretId={secret_arn}"
    headers = {"X-Aws-Parameters-Secrets-Token": _AWS_SESSION_TOKEN}
    try:
        response = _http.request("GET", url, headers=headers, timeout=5.0)
        if response.status != 200:
            raise Exception(f"Failed to get secret: {response.status} {response.data}")

        data = json.loads(response.data)
        secret_string = data['SecretString']
        try:
            return json.loads(secret_string)
        except json.JSONDecodeError:
            return secret_string
    except Exception as e:
        raise Exception(f"Error retrieving secret {secret_arn}: {str(e)}")


class LambdaConfig:
    _cache = {}

    @classmethod
    def get(cls, key, param_path=None, secret_arn=None, default=None):
        if key in cls._cache:
            return cls._cache[key]

        value = default
        try:
            if param_path:
                value = get_parameter(param_path)
            elif secret_arn:
                value = get_secret(secret_arn)
        except Exception as e:
            if default is None:
                raise e
            print(f"Warning: Could not retrieve {key}, using default: {e}")

        cls._cache[key] = value
        return value

    @classmethod
    def clear_cache(cls):
        cls._cache = {}


CONFIG_PATHS = {
    'table_name': 'dynamodb/table-name',
    'bucket_name': 's3/data-bucket',
    'kms_key_id': 'kms/cloudfront-signer-arn',
    'delete_queue_url': 'sqs/delete-queue-url',
}


def get_table_name():
    return LambdaConfig.get('table_name', param_path=CONFIG_PATHS['table_name'])


def get_bucket_name():
    return LambdaConfig.get('bucket_name', param_path=CONFIG_PATHS['bucket_name'])


def get_kms_key_id():
    return get_parameter(CONFIG_PATHS['kms_key_id'], with_decryption=True)


def get_cloudfront_key_id():
    secret_arn = os.environ.get('SECRET_ARN_CLOUDFRONT')
    if not secret_arn:
        raise Exception("SECRET_ARN_CLOUDFRONT environment variable not set")
    secret = LambdaConfig.get('cloudfront_key', secret_arn=secret_arn)
    if isinstance(secret, dict):
        return secret.get('key_id')
    return secret


def get_delete_queue_url():
    param_path = os.environ.get('DELETE_QUEUE_URL_PARAM')
    if not param_path:
        param_path = CONFIG_PATHS['delete_queue_url']
    return LambdaConfig.get('delete_queue_url', param_path=param_path)

