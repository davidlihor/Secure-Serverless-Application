import boto3
import io
import json
from PIL import Image
from config_helper import get_table_name

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
_table = None


def get_table():
    global _table
    if _table is None:
        _table = dynamodb.Table(get_table_name())
    return _table


def lambda_handler(event, context):
    try:
        print(f"Received event: {json.dumps(event)}")

        if isinstance(event, list):
            data = event[0]
        else:
            data = event

        if 'body' in data and isinstance(data['body'], str):
            data = json.loads(data['body'])

        detail = data.get('detail', data)

        bucket_name = detail.get('bucket', {}).get('name')
        object_key = detail.get('object', {}).get('key')

        if not bucket_name or not object_key:
            s3_data = detail.get('s3', {})
            bucket_name = s3_data.get('bucket', {}).get('name')
            object_key = s3_data.get('object', {}).get('key')

        if not bucket_name or not object_key:
            print(f"Error: Couldn't find bucket/key in {json.dumps(data)}")
            return {'statusCode': 400, 'body': 'Invalid structure'}

        if not object_key.endswith('photo.png'):
            return {'statusCode': 200, 'body': f'Skipped {object_key}'}

        parts = object_key.strip('/').split('/')
        user_id = parts[1]
        task_id = parts[2]

        response = s3.get_object(Bucket=bucket_name, Key=object_key)
        image_content = response['Body'].read()

        with Image.open(io.BytesIO(image_content)) as img:
            img.thumbnail((200, 200))
            buffer = io.BytesIO()
            img.save(buffer, format=img.format if img.format else 'PNG')
            buffer.seek(0)

            new_key = object_key.replace('photo.png', 'thumbnail.png')

            s3.put_object(
                Bucket=bucket_name,
                Key=new_key,
                Body=buffer,
                ContentType=response.get('ContentType', 'image/png')
            )

        print(f"Updating DynamoDB for Task {task_id}...")
        get_table().update_item(
            Key={
                'userId': user_id,
                'taskId': task_id
            },
            UpdateExpression="SET hasImage = :val",
            ExpressionAttributeValues={
                ':val': True
            }
        )

        return {
            'statusCode': 200,
            'original': object_key,
            'thumbnail': new_key,
            'db_status': 'updated'
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        raise e
