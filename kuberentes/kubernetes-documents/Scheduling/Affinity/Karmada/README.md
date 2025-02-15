# Karmada

## Intro 
이 글은 AWS EKS에 Karmada를 설치하고 멤버 클러스터로 또 다른 EKS clsuter를 등록하고 테스트하는 과정을 기록했습니다. Karmada는 자체적으로 고가용성을 유지하고 있습니다. 그리고 Multi-cluster을 이용할 때 karmada를 사용하시면 편하게 Cluster을 관리할 수 있습니다. 

### 사전 준비 :
  - AWS EKS Cluster - Staging-cluster  
  - AWS EKS Cluster - prod-cluster  
  - kubectl 
  - eksctl 

command :

우선 kubectl-karmada를 깔아줍니다. kubectl은 kubernetes을 조종하는 명령어라면, kubectl-karmada는 karmada를 조종하는 명령어입니다. 

```sh
sudo curl -s https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh | sudo bash -s kubectl-karmada
```

그리고 ,,, karmada를 설치합니다. 만약에 아래와 같은 에러가 발생하게 될 경우에 아래와 같이 Security Groups을 수정합니다. 

Security Groups : eks-cluster-sg-<cluster_name>-{number} inbound port: 32443 Source : Bastion-sg
Security Groups : Bastion-sg inbound port: ALL Traffic Source : eks-cluster-sg-<cluster_name>-{number}

```sh
deploy.go:57] unable to create Namespace: Post "https://192.168.xx.xx:32443/api/v1/namespaces": dial tcp 192.168.xx.xx:32443: i/o timeout error
```

```sh
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
kubectl krew install karmada
kubectl karmada init
```

그리고 멤버클러스터 조인을 시켜줍니다. kubeconfig으로 동작을 하는데 ,, karmada를 이용할 때 불편함이 있긴 때문에 ~/.kube/config 파일을 karmada-apiserver.config으로 수정을 합니다. 그리고 개별적으로 Cluster에 접근을 할 수 있게 kubeconfig 파일을 생성합니다.  

```sh
aws eks update-kubeconfig --name staging-cluster 
kubectl karmada --kubeconfig /etc/karmada/karmada-apiserver.config  join staging --cluster-kubeconfig=$HOME/.kube/config
aws eks update-kubeconfig --name prod-cluster
kubectl karmada --kubeconfig /etc/karmada/karmada-apiserver.config  join prod --cluster-kubeconfig=$HOME/.kube/config

aws eks update-kubeconfig --name prod-cluster --kubeconfig ./prod.config
aws eks update-kubeconfig --name staging-cluster --kubeconfig ./staging.config

cd ~/.kube/
rm -rf config 
ls -n config /etc/karmada/karmada-apiserver.config
```

resourceSelectors와 조건이 같은 경우에 clusterAffinity: 연결된 cluster에 배포를 하게 됩니다. karmada-apiserver는 이 PropagationPolicy을 보면서 동작을 하게 됩니다.

```sh 
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: staging-rp
spec:
  resourceSelectors:
    - apiVersion: apps/v1
      kind: Deployment
      labelSelector:
        matchLabels:
          stage: staging
    - apiVersion: v1
      kind: Service
      labelSelector:
        matchLabels:
          stage: staging
    - apiVersion: v1
      kind: Pod
      labelSelector:
        matchLabels:
          stage: staging
  placement:
    clusterAffinity:
      clusterNames:
        - staging
---
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: prod-rp
spec:
  resourceSelectors:
    - apiVersion: apps/v1
      kind: Deployment
      labelSelector:
        matchLabels:
          stage: prod
    - apiVersion: v1
      kind: Service
      labelSelector:
        matchLabels:
          stage: prod
    - apiVersion: v1
      kind: Pod
      labelSelector:
        matchLabels:
          stage: prod
  placement:
    clusterAffinity:
      clusterNames:
        - prod
```sh

```sh
kubectl apply -f policy.yaml
```
