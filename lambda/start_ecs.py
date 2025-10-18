import boto3

def lambda_handler(event, context):
    ecs_client = boto3.client('ecs')
    
    cluster_name = 'shadow-navi-cluster'
    service_name = 'shadow-navi-app-service'
    
    ecs_client.update_service(
        cluster=cluster_name,
        service=service_name,
        desiredCount=1  # 必要なタスク数に設定
    )
    
    return {
        'statusCode': 200,
        'body': 'ECS service started successfully!'
    }