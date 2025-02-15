# Fluent bit

## Install Fluent bit

```bash
#!/bin/bash -eux
# Create namespace
kubectl create namespace amazon-cloudwatch || true
CLUSTER="day1-cluster"

# Create configmap
ClusterName=$CLUSTER
RegionName=$(aws configure get region)
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'
[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'
kubectl create configmap fluent-bit-cluster-info \
--from-literal=cluster.name=${ClusterName} \
--from-literal=http.server=${FluentBitHttpServer} \
--from-literal=http.port=${FluentBitHttpPort} \
--from-literal=read.head=${FluentBitReadFromHead} \
--from-literal=read.tail=${FluentBitReadFromTail} \
--from-literal=logs.region=${RegionName} -n amazon-cloudwatch

# Create IRSA for fluent bit
eksctl create iamserviceaccount \
--cluster $CLUSTER \
--namespace amazon-cloudwatch \
--name fluent-bit \
--attach-policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy \
--override-existing-serviceaccounts \
--approve

# Install fluent bit manifest
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml

kubectl get pods -n amazon-cloudwatch

# Modify fluent bit manifest 

kubectl delete -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml  # <- 전에 미리 생성을 했다면 , 삭제를 하고 진행합니다.

sudo yum install wget -y 
wget https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml # 파일을 수정을 합니다. 

# Relete unnecessary service account & adjust cpu request
sed -i 1,5d /tmp/fluent-bit.yaml
sed -i 's/500m/200m/' /tmp/fluent-bit.yaml
kubectl apply -f /tmp/fluent-bit.yaml
```
