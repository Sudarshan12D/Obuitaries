import boto3

print('Loading function')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table("Obituaries-30133072")


def get_handler(event, context):
    response = table.scan()
    items = response.get('Items', [])
    while 'LastEvaluatedKey' in response:
        response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
        items += response.get('Items', [])
    return items