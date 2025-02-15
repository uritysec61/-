#!/bin/bash
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.31.0/2024-09-12/bin/linux/amd64/kubectl
                            # amd64 1.31 version : curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.31.0/2024-09-12/bin/linux/amd64/kubectl (Default)
                            # amd64 1.29 version : curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.29.0/2024-01-04/bin/linux/amd64/kubectl 
                            # amd64 1.28 version : curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.28.5/2024-01-04/bin/linux/amd64/kubectl
                            # amd64 1.27 version : curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.27.9/2024-01-04/bin/linux/amd64/kubectl
                            # amd64 1.26 version : curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.26.12/2024-01-04/bin/linux/amd64/kubectl
                            # amd64 1.25 version : curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.25.16/2024-01-04/bin/linux/amd64/kubectl
                            # amd64 1.24 version : curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.24.17/2024-01-04/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/bin/
echo "-------------------------------------------------------"
kubectl version --client
echo "-------------------------------------------------------"

# Reference Site -> https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/install-kubectl.html
# Mapping with Cluster Command -> aws eks update-kubeconfig --region <region-code> --name <my-cluster

# If you have an alias for kubectl, you can extend shell completion to work with that alias:

echo 'alias k=kubectl' >>~/.bashrc
source ~/.bashrc