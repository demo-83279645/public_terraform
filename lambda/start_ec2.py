import boto3
import os

def lambda_handler(event, context):
    """
    環境変数 INSTANCE_IDS で指定されたEC2インスタンスを起動します。
    INSTANCE_IDSはカンマ区切りの文字列を想定しています。
    例: 'i-xxxxxxxxxxxxxxxxx,i-yyyyyyyyyyyyyyyyy'
    """
    
    # 1. 環境変数 INSTANCE_IDS を取得し、カンマで分割してリスト化
    instance_ids_str = os.environ.get('INSTANCE_IDS', '')
    
    # 2. リストから空の要素を削除し、有効なインスタンスIDのリストを作成
    valid_instance_ids = [id.strip() for id in instance_ids_str.split(',') if id.strip()]

    if not valid_instance_ids:
        print("起動対象のインスタンスIDが環境変数 INSTANCE_IDS に指定されていません。")
        return {
            'statusCode': 400,
            'body': 'No valid instance IDs specified in INSTANCE_IDS environment variable.'
        }
    
    print(f"以下のEC2インスタンスを起動します: {valid_instance_ids}")
    
    ec2 = boto3.client('ec2')
    
    try:
        # EC2インスタンスを起動
        response = ec2.start_instances(
            InstanceIds=valid_instance_ids
        )
        
        print(f"起動リクエストが送信されました: {response}")
        return {
            'statusCode': 200,
            'body': f'Successfully started instances: {valid_instance_ids}'
        }

    except Exception as e:
        print(f"EC2インスタンスの起動中にエラーが発生しました: {e}")
        return {
            'statusCode': 500,
            'body': f'Error starting instances: {e}'
        }
