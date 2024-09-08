import json
import boto3
import urllib3
import os

def handler(event, context):
    http = urllib3.PoolManager()

    tf_action = event['tf']['action']

    account_id = context.invoked_function_arn.split(":")[4]
    region = context.invoked_function_arn.split(":")[3]

    diagnostic_data = {
        'AccountId': account_id,
        'Region': region,
        'RequestType': tf_action.capitalize(),
        'StackId': event['StackId'],
        'RequestId': context.aws_request_id,
        'LogicalResourceId': event['LogicalResourceId'],
        'TenantId': os.environ.get('TENANT_ID'),
        'ProjectId': os.environ.get('PROJECT_ID'),
        'TenantEmail': os.environ.get('TENANT_EMAIL')
    }

    webhook_url = os.environ.get('WEBHOOK_URL')

    try:
        encoded_data = json.dumps(diagnostic_data).encode('utf-8')
        response = http.request(
            'POST',
            webhook_url,
            body=encoded_data,
            headers={'Content-Type': 'application/json'}
        )

        return {
            'statusCode': response.status,
            'body': json.dumps(f'{tf_action.capitalize()} request processed')
        }
    except Exception as e:
        print(e)
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error processing {tf_action} request')
        }
