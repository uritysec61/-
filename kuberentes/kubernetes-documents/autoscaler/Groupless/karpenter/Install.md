## GrouplessKarpenter
- refor 
  https://karpenter.sh/ version check

1. environmental variables

    ```sh
    CLUSTER_NAME=apdev-cluster
    AWS_PARTITION="aws"

    AWS_REGION="$(aws configure list | grep region | tr -s " " | cut -d" " -f3)"

    OIDC_ENDPOINT="$(aws eks describe-cluster --name ${CLUSTER_NAME} \
    --query "cluster.identity.oidc.issuer" --output text)"

    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' \
    --output text)
    ```

2. IAM Role create

    ```sh
    echo '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "ec2.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }' > node-trust-policy.json
    aws iam create-role \
        --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
        --assume-role-policy-document file://node-trust-policy.json

    aws iam attach-role-policy \
        --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
        --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
    aws iam attach-role-policy \
        --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
        --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy   
    aws iam attach-role-policy \
        --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
        --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
    aws iam attach-role-policy \
        --role-name "KarpenterNodeRole-${CLUSTER_NAME}" \
        --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

    aws iam create-instance-profile \
        --instance-profile-name "KarpenterNodeInstanceProfile-${CLUSTER_NAME}"
    aws iam add-role-to-instance-profile \
        --instance-profile-name "KarpenterNodeInstanceProfile-${CLUSTER_NAME}" \
        --role-name "KarpenterNodeRole-${CLUSTER_NAME}"

    cat << EOF > controller-trust-policy.json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_ENDPOINT#*//}"
                },
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Condition": {
                    "StringEquals": {
                        "${OIDC_ENDPOINT#*//}:aud": "sts.amazonaws.com",
                        "${OIDC_ENDPOINT#*//}:sub": "system:serviceaccount:karpenter:karpenter"
                    }
                }
            }
        ]
    }
    EOF

    aws iam create-role \
        --role-name KarpenterControllerRole-${CLUSTER_NAME} \
        --assume-role-policy-document file://controller-trust-policy.json

    cat << EOF > controller-policy.json
    {
        "Statement": [
            {
                "Action": [
                    "ssm:GetParameter",
                    "ec2:DescribeImages",
                    "ec2:RunInstances",
                    "ec2:DescribeSubnets",
                    "ec2:DescribeSecurityGroups",
                    "ec2:DescribeLaunchTemplates",
                    "ec2:DescribeInstances",
                    "ec2:DescribeInstanceTypes",
                    "ec2:DescribeInstanceTypeOfferings",
                    "ec2:DescribeAvailabilityZones",
                    "ec2:DeleteLaunchTemplate",
                    "ec2:CreateTags",
                    "ec2:CreateLaunchTemplate",
                    "ec2:CreateFleet",
                    "ec2:DescribeSpotPriceHistory",
                    "pricing:GetProducts"
                ],
                "Effect": "Allow",
                "Resource": "*",
                "Sid": "Karpenter"
            },
            {
                "Action": "ec2:TerminateInstances",
                "Condition": {
                    "StringLike": {
                        "ec2:ResourceTag/Name": "*karpenter*"
                    }
                },
                "Effect": "Allow",
                "Resource": "*",
                "Sid": "ConditionalEC2Termination"
            },
            {
                "Effect": "Allow",
                "Action": "iam:PassRole",
                "Resource": "arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${CLUSTER_NAME}",
                "Sid": "PassNodeIAMRole"
            },
            {
                "Effect": "Allow",
                "Action": "eks:DescribeCluster",
                "Resource": "arn:${AWS_PARTITION}:eks:${AWS_REGION}:${AWS_ACCOUNT_ID}:cluster/${CLUSTER_NAME}",
                "Sid": "EKSClusterEndpointLookup"
            }
        ],
        "Version": "2012-10-17"
    }
    EOF

    aws iam put-role-policy \
        --role-name KarpenterControllerRole-${CLUSTER_NAME} \
        --policy-name KarpenterControllerPolicy-${CLUSTER_NAME} \
        --policy-document file://controller-policy.json
    ```

3. Tags Additional

    ```sh
    for NODEGROUP in $(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} \
        --query 'nodegroups' --output text); do aws ec2 create-tags \
            --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}" \
            --resources $(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} \
            --nodegroup-name $NODEGROUP --query 'nodegroup.subnets' --output text )
    done    

    NODEGROUP=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} \
        --query 'nodegroups[0]' --output text)
    LAUNCH_TEMPLATE=$(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} \
        --nodegroup-name ${NODEGROUP} --query 'nodegroup.launchTemplate.{id:id,version:version}' \
        --output text | tr -s "\t" ",")
    # If your EKS setup is configured to use only Cluster security group, then please execute -

    SECURITY_GROUPS=$(aws eks describe-cluster \
        --name ${CLUSTER_NAME} --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)
    # If your setup uses the security groups in the Launch template of a managed nodegroup, then :
    # SECURITY_GROUPS=$(aws ec2 describe-launch-template-versions \
    #    --launch-template-id ${LAUNCH_TEMPLATE%,*} --versions ${LAUNCH_TEMPLATE#*,}    \
    #    --query 'LaunchTemplateVersions[0].LaunchTemplateData.[NetworkInterfaces[0].Groups||SecurityGroupIds]' \
    #    --output text)

    aws ec2 create-tags \
        --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}" \
        --resources ${SECURITY_GROUPS}
    ```

3. ConfigMap Setting

    ```sh
    kubectl edit configmap aws-auth -n kube-system

    apiVersion: v1
    data:
      mapRoles: |
        - groups:
          - system:bootstrappers
          - system:nodes
          rolearn: arn:aws:iam::226347592148:role/dev-global-eks-node-iam-role
          username: system:node:{{EC2PrivateDNSName}}
    +   - groups:
    +     - system:bootstrappers
    +     - system:nodes
    +     rolearn: arn:aws:iam::073762821266:role/KarpenterNodeRole-apdev-eks-cluster
    +     username: system:node:{{EC2PrivateDNSName}}
    kind: ConfigMap
    metadata:
      ...
    :x
    export KARPENTER_VERSION=v0.25.0
    ```

4. Karpenter apply 

    ```sh
    helm template karpenter oci://public.ecr.aws/karpenter/karpenter \
        --version ${KARPENTER_VERSION} \
        --namespace karpenter \
        --set settings.aws.defaultInstanceProfile=KarpenterNodeInstanceProfile-${CLUSTER_NAME} \
        --set settings.aws.clusterName=${CLUSTER_NAME} \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:role/KarpenterControllerRole-${CLUSTER_NAME}" \
        --set controller.resources.requests.cpu=1 \
        --set controller.resources.requests.memory=1Gi \
        --set controller.resources.limits.cpu=1 \
        --set controller.resources.limits.memory=1Gi \
        --set replicas=2 > karpenter.yaml
    ```

5. Karpenter File Modify

    ```sh
    vi karpenter.yaml
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                  - key: karpenter.sh/provisioner-name
                    operator: DoesNotExist
    +           - matchExpressions:
    +             - key: eks.amazonaws.com/nodegroup
    +               operator: In
    +               values:
    +               - apdev-eks-ng # 노드그룹 이름은 현재 사용중인 노드 그룹으로 수정하기
    #               - YOUR_NODE_GROUP_NAMEB   (두 개면 두 개로 설정)
    ```

6. CRD & Karpenter with cluster apply

    ```sh 
    kubectl create namespace karpenter

    kubectl create -f \
            https://raw.githubusercontent.com/aws/karpenter/$KARPENTER_VERSION/pkg/apis/crds/karpenter.sh_provisioners.yaml

    kubectl create -f \
            https://raw.githubusercontent.com/aws/karpenter/$KARPENTER_VERSION/pkg/apis/crds/karpenter.k8s.aws_awsnodetemplates.yaml  

    kubectl api-resources \
        --categories karpenter \
        -o wide

    ------------

    NAME               SHORTNAMES   APIVERSION                   NAMESPACED       KIND              VERBS                                                           CATEGORIES
    awsnodetemplates                karpenter.k8s.aws/v1alpha1   false            AWSNodeTemplate   delete,deletecollection,get,list,patch,create,update,watch      karpenter
    provisioners                    karpenter.sh/v1alpha5        false            Provisioner       delete,deletecollection,get,list,patch,create,update,watch      karpenter

    ------------

    kubectl apply -f karpenter.yaml
    kubectl get pod -n karpenter

     cat <<EOF | kubectl apply -f -
    ---
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
      labels:
        app: karpenter
        version: v0.25.0
    spec:
      requirements:
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: [c, m, r]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
      providerRef:
        name: default

    ---
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
      labels:
        app: karpenter
        version: v0.25.0
    spec:
      amiFamily: AL2
      subnetSelector:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
      securityGroupSelector:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
    EOF
    ```
------------

## other 

Spot Service LIned Role 생성 (EC2 Spot 처음 쓰는 계정에서 필요함)
```sh
aws iam create-service-linked-role --aws-service-name spot.amazonaws.com || true
```
Provisioner 삭제 후 , 다시 Karpenter 생성할 때 에러가 날 경우 EX ) error ->  
  
2022-11-16T12:22:26.840Z	ERROR	webhook.DefaultingWebhook	Reconcile error	{"commit": "ea5dc14", "knative.dev/traceid": "f3e8c3df-73db-4389-8d78-f3e6c7f3168c", "knative.dev/key": "<namespace>/karpenter-cert", "duration": "28.509508ms", "error": "failed to update webhook: Operation cannot be fulfilled on mutatingwebhookconfigurations.admissionregistration.k8s.io \"defaulting.webhook.karpenter.sh\": the object has been modified; please apply your changes to the latest version and try again"}
   
```sh
kubectl rollout restart deployment -n karpenter karpenter
```