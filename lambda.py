import json
import os

import urllib3


def handler(event, context):
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
        'TenantId': event.get('TenantId', os.environ.get('TENANT_ID')),
        'ProjectId': event.get('ProjectId', os.environ.get('PROJECT_ID')),
        'TenantEmail': event.get('TenantEmail', os.environ.get('TENANT_EMAIL')),
        'RoleArn': event.get('RoleArn'),
    }

    webhook_url = os.environ.get('WEBHOOK_URL')

    try:
        response = urllib3.PoolManager().request(
            'POST',
            webhook_url,
            body=json.dumps(diagnostic_data).encode('utf-8'),
            headers={'Content-Type': 'application/json'},
            timeout=urllib3.Timeout(total=10),
        )
        status = response.status
    except Exception as e:
        print(e)
        status = None

    # A failed create or update fails the apply; destroying never depends on Miggo.
    if status != 200 and tf_action != 'delete':
        reason = f'answered {status}' if status else 'was unreachable'
        raise RuntimeError(f'Miggo webhook {reason} for the {tf_action} request')

    return {
        'statusCode': status or 500,
        'body': json.dumps(f'{tf_action.capitalize()} request processed'),
    }
