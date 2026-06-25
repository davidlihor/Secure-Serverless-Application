import json
import boto3
import uuid
from datetime import datetime
from config_helper import get_table_name

dynamodb = boto3.resource('dynamodb')
_table = None

def get_table():
    global _table
    if _table is None:
        _table = dynamodb.Table(get_table_name())
    return _table

def lambda_handler(event, context):
    try:
        body = json.loads(event['body'])
        title = body.get('title', '').strip()
        
        if not title:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(event),
                'body': json.dumps({'error': 'Task title is required'})
            }
        
        user_id = event['requestContext']['authorizer']['claims']['sub']
        task_id = str(uuid.uuid4())

        item = {
            'userId': user_id,
            'taskId': task_id,
            'title': title,
            'completed': False,
            'createdAt': datetime.now().isoformat()
        }
        get_table().put_item(Item=item)
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(event),
            'body': json.dumps(item)
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
