import boto3
import os

def lambda_handler(event, context):
    """
    環境変数 INSTANCE_IDS で指定されたEC2インスタンスを停止します。
    INSTANCE_IDSはカンマ区切りの文字列を想定しています。
    例: 'i-xxxxxxxxxxxxxxxxx,i-yyyyyyyyyyyyyyyyy'
    """
    
    # 1. 環境変数 INSTANCE_IDS を取得し、カンマで分割してリスト化
    instance_ids_str = os.environ.get('INSTANCE_IDS', '')
    
    # 2. リストから空の要素を削除し、有効なインスタンスIDのリストを作成
    valid_instance_ids = [id.strip() for id in instance_ids_str.split(',') if id.strip()]

    if not valid_instance_ids:
        print("停止対象のインスタンスIDが環境変数 INSTANCE_IDS に指定されていません。")
        return {
            'statusCode': 400,
            'body': 'No valid instance IDs specified in INSTANCE_IDS environment variable.'
        }
    
    print(f"以下のEC2インスタンスを停止します: {valid_instance_ids}")
    
    ec2 = boto3.client('ec2')

    try:
        # EC2インスタンスを停止
        response = ec2.stop_instances(
            InstanceIds=valid_instance_ids
        )
        
        print(f"停止リクエストが送信されました: {response}")
        return {
            'statusCode': 200,
            'body': f'Successfully stopped instances: {valid_instance_ids}'
        }

    except Exception as e:
        print(f"EC2インスタンスの停止中にエラーが発生しました: {e}")
        return {
            'statusCode': 500,
            'body': f'Error stopping instances: {e}'
        }
