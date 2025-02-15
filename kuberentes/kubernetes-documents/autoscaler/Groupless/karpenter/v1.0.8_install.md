# 1. Install utilities

Karpenter is installed in clusters with a Helm chart.

Karpenter requires cloud provider permissions to provision nodes, for AWS IAM Roles for Service Accounts (IRSA) should be used. IRSA permits Karpenter (within the cluster) to make privileged requests to AWS (as the cloud provider) via a ServiceAccount.

Install these tools before proceeding:

    AWS CLI
    kubectl - the Kubernetes CLI
    eksctl (>= v0.191.0) - the CLI for AWS EKS
    helm - the package manager for Kubernetes

Configure the AWS CLI with a user that has sufficient privileges to create an EKS cluster. Verify that the CLI can authenticate properly by running `aws sts get-caller-identity`.


## 2. Set environment variables
After setting up the tools, set the Karpenter and Kubernetes version:

```sh
export KARPENTER_NAMESPACE="kube-system"
export KARPENTER_VERSION="1.0.8"
export K8S_VERSION="1.31"
```

Then set the following environment variable:

```sh 
export AWS_PARTITION="aws" # if you are not using standard partitions, you may need to configure to aws-cn / aws-us-gov
export CLUSTER_NAME="demo-cluster"
export AWS_DEFAULT_REGION="ap-northeast-2"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export TEMPOUT="$(mktemp)"
export ARM_AMI_ID="$(aws ssm get-parameter --name /aws/service/eks/optimized-ami/${K8S_VERSION}/amazon-linux-2-arm64/recommended/image_id --query Parameter.Value --output text)"
export AMD_AMI_ID="$(aws ssm get-parameter --name /aws/service/eks/optimized-ami/${K8S_VERSION}/amazon-linux-2/recommended/image_id --query Parameter.Value --output text)"
export GPU_AMI_ID="$(aws ssm get-parameter --name /aws/service/eks/optimized-ami/${K8S_VERSION}/amazon-linux-2-gpu/recommended/image_id --query Parameter.Value --output text)"
```

Warning  
  
If you open a new shell to run steps in this procedure, you need to set some or all of the environment variables again. To remind yourself of these values, type:

```sh
echo "${KARPENTER_NAMESPACE}" "${KARPENTER_VERSION}" "${K8S_VERSION}" "${CLUSTER_NAME}" "${AWS_DEFAULT_REGION}" "${AWS_ACCOUNT_ID}" "${TEMPOUT}" "${ARM_AMI_ID}" "${AMD_AMI_ID}" "${GPU_AMI_ID}"
```

## 3. Create a Cluster

Create a basic cluster with `eksctl`. The following cluster configuration will:
Use CloudFormation to set up the infrastructure needed by the EKS cluster. See CloudFormation for a complete description of what `cloudformation.yaml` does for Karpenter.
Create a Kubernetes service account and AWS IAM Role, and associate them using IRSA to let Karpenter launch instances.
Add the Karpenter node role to the aws-auth configmap to allow nodes to connect.
Use AWS EKS managed node groups for the kube-system and karpenter namespaces. Uncomment fargateProfiles settings (and comment out managedNodeGroups settings) to use Fargate for both namespaces instead.
Set KARPENTER_IAM_ROLE_ARN variables.
Create a role to allow spot instances.
Run Helm to install Karpenter

```sh
curl -fsSL https://raw.githubusercontent.com/aws/karpenter-provider-aws/v"${KARPENTER_VERSION}"/website/content/en/preview/getting-started/getting-started-with-karpenter/cloudformation.yaml  > "${TEMPOUT}" \
&& aws cloudformation deploy \
  --stack-name "Karpenter-${CLUSTER_NAME}" \
  --template-file "${TEMPOUT}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides "ClusterName=${CLUSTER_NAME}"

eksctl create cluster -f - <<EOF
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: demo-cluster
  version: "1.31"
  region: ap-northeast-2
  tags:
    karpenter.sh/discovery: demo-cluster


vpc:
  subnets:
    public:
      public-a: { id: subnet-076256aedd3136e1e }
      public-b: { id: subnet-095f90dd28db7f488 }
    private:
      private-a: { id: subnet-095191ebe12d50647 }
      private-b: { id: subnet-0ccc860868f1c4cc7 }

iam:
  withOIDC: true
  podIdentityAssociations:
  - namespace: "kube-system"
    serviceAccountName: karpenter
    roleName: demo-cluster-karpenter
    permissionPolicyARNs:
    - arn:aws:iam::226347592148:policy/KarpenterControllerPolicy-demo-cluster
  serviceAccounts:
  - metadata:
      name: appmesh-controller
      namespace: appmesh-system
    attachPolicyARNs:
      - "arn:aws:iam::aws:policy/AWSCloudMapFullAccess"
      - "arn:aws:iam::aws:policy/AWSAppMeshFullAccess"
  - metadata:
      name: aws-load-balancer-controller
      namespace: kube-system
    wellKnownPolicies:
      awsLoadBalancerController: true
  - metadata:
      name: ebs-csi-controller-sa
      namespace: kube-system
    wellKnownPolicies:
      ebsCSIController: true
  - metadata:
      name: efs-csi-controller-sa
      namespace: kube-system
    wellKnownPolicies:
      efsCSIController: true
  - metadata:
      name: external-dns
      namespace: kube-system
    wellKnownPolicies:
      externalDNS: true
  - metadata:
      name: cert-manager
      namespace: cert-manager
    wellKnownPolicies:
      certManager: true
  - metadata:
      name: cluster-autoscaler
      namespace: kube-system
      labels: {aws-usage: "cluster-ops"}
    wellKnownPolicies:
      autoScaler: true
  - metadata:
      name: build-service
      namespace: ci-cd
    wellKnownPolicies:
      imageBuilder: true
  - metadata:
      name: autoscaler-service
      namespace: kube-system
    attachPolicy:
      Version: "2012-10-17"
      Statement:
      - Effect: Allow
        Action:
        - "autoscaling:DescribeAutoScalingGroups"
        - "autoscaling:DescribeAutoScalingInstances"
        - "autoscaling:DescribeLaunchConfigurations"
        - "autoscaling:DescribeTags"
        - "autoscaling:SetDesiredCapacity"
        - "autoscaling:TerminateInstanceInAutoScalingGroup"
        - "ec2:DescribeLaunchTemplateVersions"
        Resource: '*'

iamIdentityMappings:
  - arn: arn:aws:iam::226347592148:role/root
    groups:
      - system:masters
    username: admin
    noDuplicateARNs: true # prevents shadowing of ARNs
  - arn: "arn:aws:iam::226347592148:role/KarpenterNodeRole-demo-cluster"
    username: system:node:{{EC2PrivateDNSName}}
    groups:
    - system:bootstrappers
    - system:nodes
    ## If you intend to run Windows workloads, the kube-proxy group should be specified.
    # For more information, see https://github.com/aws/karpenter/issues/5099.
    # - eks:kube-proxy-windows

managedNodeGroups:
  - name: demo-app-mng
    labels: { role: apps }
    instanceType: t3.medium
    amiFamily: AmazonLinux2
    instanceName: demo-app-mng
    desiredCapacity: 2
    minSize: 2
    maxSize: 20
    privateNetworking: true
    volumeType: gp3
    volumeEncrypted: true
    subnets:
      - private-a
      - private-b
    tags:
      k8s.io/cluster-autoscaler/enabled: "true"
      k8s.io/cluster-autoscaler/wsi-cluster: "owned"
    iam:
      withAddonPolicies:
        imageBuilder: true
        externalDNS: true
        certManager: true
        cloudWatch: true
addons:
- name: eks-pod-identity-agent
EOF

export KARPENTER_IAM_ROLE_ARN="arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-karpenter"
echo ${KARPENTER_IAM_ROLE_ARN}
```

## 4. Install Karpenter

```sh
# Logout of helm registry to perform an unauthenticated pull against the public ECR
helm registry logout public.ecr.aws

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --version "${KARPENTER_VERSION}" --namespace "${KARPENTER_NAMESPACE}" --create-namespace \
  --set "settings.clusterName=${CLUSTER_NAME}" \
  --set "settings.interruptionQueue=${CLUSTER_NAME}" \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi \
  --set controller.resources.limits.cpu=1 \
  --set controller.resources.limits.memory=1Gi \
  --wait
```

## 5. Create NodePool

A single Karpenter NodePool is capable of handling many different pod shapes. Karpenter makes scheduling and provisioning decisions based on pod attributes such as labels and affinity. In other words, Karpenter eliminates the need to manage many different node groups.

Create a default NodePool using the command below. This NodePool uses `securityGroupSelectorTerms` and subnetSelectorTerms to discover resources used to launch nodes. We applied the tag `karpenter.sh/discovery` in the `eksctl` command above. Depending on how these resources are shared between clusters, you may need to use different tagging schemes.

The `consolidationPolicy` set to `WhenEmptyOrUnderutilized` in the `disruption` block configures Karpenter to reduce cluster cost by removing and replacing nodes. As a result, consolidation will terminate any empty nodes on the cluster. This behavior can be disabled by setting `consolidateAfte` to `Never`, telling Karpenter that it should never consolidate nodes. Review the NodePool API docs for more information.

Note: This NodePool will create capacity as long as the sum of all created capacity is less than the specified limit.

```sh
cat <<EOF | envsubst | kubectl apply -f -
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      expireAfter: 720h # 30 * 24h = 720h
  limits:
    cpu: 1000
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2 # Amazon Linux 2
  role: "KarpenterNodeRole-${CLUSTER_NAME}" # replace with your cluster name
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  amiSelectorTerms:
    - id: "${ARM_AMI_ID}"
    - id: "${AMD_AMI_ID}"
#   - id: "${GPU_AMI_ID}" # <- GPU Optimized AMD AMI 
#   - name: "amazon-eks-node-${K8S_VERSION}-*" # <- automatically upgrade when a new AL2 EKS Optimized AMI is released. This is unsafe for production workloads. Validate AMIs in lower environments before deploying them to production.
EOF
```

You can increase the number of nodes only with the instance type you want. If you want that, use the below.

```sh
cat <<EOF | envsubst | kubectl apply -f -
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ["t3.medium"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      expireAfter: 720h # 30 * 24h = 720h
  limits:
    cpu: 1000
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2 # Amazon Linux 2
  role: "KarpenterNodeRole-${CLUSTER_NAME}" # replace with your cluster name
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  amiSelectorTerms:
    - id: "${ARM_AMI_ID}"
    - id: "${AMD_AMI_ID}"
#   - id: "${GPU_AMI_ID}" # <- GPU Optimized AMD AMI 
#   - name: "amazon-eks-node-${K8S_VERSION}-*" # <- automatically upgrade when a new AL2 EKS Optimized AMI is released. This is unsafe for production workloads. Validate AMIs in lower environments before deploying them to production.
EOF
```