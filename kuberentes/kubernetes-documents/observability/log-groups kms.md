## --- cloudwatch log groups kms ---

``` bash

cd /home/ec2-user
aws kms create-key  # <------------------------- 생성 시 key-id 나옴
aws kms get-key-policy --key-id key-id --policy-name default --output text > ./policy.json
sudo vim policy.json

{
 "Version": "2012-10-17",
    "Id": "key-default-1",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::226347592148:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "logs.ap-northeast-2.amazonaws.com"
            },
            "Action": [
                "kms:Encrypt*",
                "kms:Decrypt*",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:Describe*"
            ],
            "Resource": "*",
            "Condition": {
                "ArnEquals": {
                    "kms:EncryptionContext:aws:logs:arn": "arn:aws:logs:ap-northeast-2:account-id:log-group:*" # <------------------------------------- "MY account-id" 
                }
            }
        }    
    ]
}

aws kms put-key-policy --key-id key-id --policy-name default --policy file://policy.json

```

## key-id KMS에 검색 후, ARN 복사한 후에 Log Goups KMS에 넣기.