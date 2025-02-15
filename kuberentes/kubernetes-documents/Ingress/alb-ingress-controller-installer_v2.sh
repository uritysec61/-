#helm 설치
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

#OIDC 생성
eksctl utils associate-iam-oidc-provider --cluster my-cluster --approve --region ap-northeast-2

#AWS Load Balancer Controller의 IAM 정책을 다운로드
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json

#다운로드 한 정책을 사용하여 IAM정책을 만듬
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

#생성한 정책을 사용하여 serviceaccount 생성
eksctl create iamserviceaccount \
  --cluster=my-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::073762821266:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region ap-northeast-2

#eks-charts 리포지토리를 추가
helm repo add eks https://aws.github.io/eks-charts

#로컬 리포지토리를 업데이트
helm repo update

#Load Balancer Controller을 설치
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=my-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
#  --set nodeSelector.app=other  Labels을 이용하여 원하는 NodeGroup에 배포할 수 있습니다.

#잘 설치 되어 있는지 확인
kubectl get deployment -n kube-system aws-load-balancer-controller
