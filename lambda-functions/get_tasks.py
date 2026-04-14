import json
import boto3
from boto3.dynamodb.conditions import Key
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
        user_id = event['requestContext']['authorizer']['claims']['sub']

        response = get_table().query(
            KeyConditionExpression=Key('userId').eq(user_id),
            ScanIndexForward=False
        )
        
        tasks = response.get('Items', [])
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(tasks)
        }
        
    except KeyError as e:
        print(f"Missing key: {e}")
        return {
            'statusCode': 401,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Unauthorized - Invalid token'})
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Internal server error'})
        }

def get_cors_headers():
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'OPTIONS,POST,GET,PUT,DELETE'
    }
