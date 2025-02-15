eksctl create fargateprofile \
    --cluster demo-cluster \
    --name fargate-demo \
    --namespace demo \
    --labels app=other \
    --region ap-northeast-2