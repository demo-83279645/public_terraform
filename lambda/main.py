import boto3
import os
import json

def handler(event, context):
    alb = boto3.client('elbv2')
    listener_arn = os.environ['LISTENER_ARN']
    target_group_arn = os.environ['TARGET_GROUP_ARN']

    print(f"Received event: {json.dumps(event)}")

    try:
        message = json.loads(event['Records'][0]['Sns']['Message'])
        new_state_value = message.get('NewStateValue')
    except (KeyError, json.JSONDecodeError):
        print("Could not parse SNS message. Event format might be unexpected.")
        return

    # 既存のルールをすべて取得（デフォルトルールを除く）
    rules = alb.describe_rules(ListenerArn=listener_arn)['Rules']
    for rule in rules:
        if not rule['IsDefault']:
            print(f"Deleting existing rule: {rule['RuleArn']}")
            alb.delete_rule(RuleArn=rule['RuleArn'])

    if new_state_value == 'ALARM':
        print("CloudWatch alarm is in ALARM state. Setting maintenance mode rule.")
        # 指定されたHTMLコードをMessageBodyに設定
        maintenance_html = """
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>メンテナンス中</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            padding: 50px;
            background-color: #f4f4f4;
            color: #333;
        }
        .container {
            background-color: #fff;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            display: inline-block;
        }
        h1 {
            color: #d9534f;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>メンテナンス中です。</h1>
    </div>
</body>
</html>
"""
        alb.create_rule(
            ListenerArn=listener_arn,
            Priority=1,
            Actions=[
                {
                    'Type': 'fixed-response',
                    'FixedResponseConfig': {
                        'ContentType': 'text/html',
                        'MessageBody': maintenance_html,
                        'StatusCode': '503'
                    }
                }
            ],
            Conditions=[
                {
                    'Field': 'path-pattern',
                    'Values': ['/*']
                }
            ]
        )
        print("Listener rule updated to maintenance mode.")
    elif new_state_value == 'OK':
        print("CloudWatch alarm is in OK state. Reverting to normal rules.")
        alb.create_rule(
            ListenerArn=listener_arn,
            Priority=1,
            Actions=[
                {
                    'Type': 'forward',
                    'TargetGroupArn': target_group_arn
                }
            ],
            Conditions=[
                {
                    'Field': 'path-pattern',
                    'Values': ['/*']
                }
            ]
        )
        print("Listener rule reverted to normal mode.")
    else:
        print(f"Alarm state {new_state_value} received. No action taken.")