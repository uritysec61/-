# fargate CoreDNS Monitoring

## Intro
CloudWatch Dashboard를 통해 Kubernetes 내부에서 발생한 모든 DNS Query에 대한 Log가 기록 및 Log table 형태로 볼 수 있도록 구성합니다.

--- 

## 사전 준비 :
    - EKS Cluster
    - eksctl 
    - kubectl

### fargate CoreDNS Create

우선 기본적으로 생성된 CoreDNS를 fargate profile을 이용하여, fargate CoreDNS를 생성합니다.

```sh
# CoreDNS Config
eksctl create fargateprofile \
    --cluster demo-cluster \
    --name coredns-profile \
    --namespace kube-system \
    --region ap-northeast-2
kubectl patch deployment coredns -n kube-system --type=json -p='[{"op": "remove", "path": "/spec/template/metadata/annotations", "value": "eks.amazonaws.com/compute-type"}]'  
kubectl rollout restart -n kube-system deployment coredns
```

```sh
k edit cm coredns -n kube-system
* * * * * * * * *
  Corefile: |
    .:53 {
        log
        errors
        health {
            lameduck 5s
          }
* * * * * * * * *
```

### fargate observability

fargate에서 CloudWatch에 Log groups에 전송을 하려면, fargate observability을 생성하여야 합니다. 그리고 fargate profile role에 CloudWatch에 Log group과 logs을 올릴 수 있는 권한들이 줘야 합니다.

```sh
curl -O https://raw.githubusercontent.com/aws-samples/amazon-eks-fluent-logging-examples/mainline/examples/fargate/cloudwatchlogs/permissions.json
```


```sh
aws iam create-policy --policy-name eks-fargate-logging-policy --policy-document file://permissions.json
```

```sh
ROLE_NAME=$(aws eks describe-fargate-profile --cluster-name skills-eks-cluster --fargate-profile-name coredns-profile --query "fargateProfile.podExecutionRoleArn" --output text | awk -F '/' '{print $NF}')

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::111122223333:policy/eks-fargate-logging-policy \
  --role-name $ROLE_NAME
```

```sh
kind: Namespace
apiVersion: v1
metadata:
  name: aws-observability
  labels:
    aws-observability: enabled
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: aws-logging
  namespace: aws-observability
  labels:
data:
  # Configuration files: server, input, filters and output
  # ======================================================
  flb_log_cw: "true"  # Ships Fluent Bit process logs to CloudWatch.

  output.conf: |
    [OUTPUT]
        Name cloudwatch
        Match kube.*
        region ap-northeast-2
        log_group_name coredns-cloudwatch
        log_stream_prefix from-fluent-bit-
        auto_create_group true
```

```sh
k apply -f aws-observability.yaml
k rollout restart deploy/coredns -n kube-system
```

### Log Table Query 문 

```sh 
fields @timestamp, @message, @logStream, @log
| parse @message / (?<DNS>\[.*) /
| display DNS
| limit 10000