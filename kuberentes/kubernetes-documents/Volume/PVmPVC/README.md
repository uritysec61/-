# PV/PVC
First, you must configure an EKS cluster in order to configure PV/PVC. Also, 0/2 nodes are available: pod has unbound immerseantVolumeClaims. preempt: 0/2 nodes are available: 2 Preemption is not help for scheduling.

## Amazon EBS CSI (aws-ebs-sci-driver)

AWS official website :
```sh
1. https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html
2. https://docs.aws.amazon.com/eks/latest/userguide/creating-an-add-on.html
```

Check the official home page so that you can create aws-ebs-sci-driver.

## AWS EBS Volumes CLI Command 
```sh
aws ec2 create-volume --region ap-northeast-2 --availability-zone ap-northeast-2a --size 5 --volume-type gp2
```

## pv.yaml
```sh
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-1
spec:
  accessModes:
  - ReadWriteOnce
  volumeMode: Filesystem
  capacity:
    storage: 5Gi
  csi:
    driver: ebs.csi.aws.com
    fsType: ext4
    volumeHandle: vol-xxxxxxxxxxxxxx
 ```

In the volumeHandle portion, insert the ID into the volumes that you created through the AWS CLI command. And modify the storage:5Gi portion to match the storage size you created. 
```sh
kubectl apply -f pv.yaml
```

## pvc.yaml
```sh
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-1
spec:
  storageClassName: "" # Empty string must be explicitly set otherwise default StorageClass will be set
  accessModes:         # kubectl patch storageclass "scName" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
    # volumeMode: Filesystem
    # volumeName: pv-1
```

If the storage part of pvc.yaml is set to be larger than the pv storage capacity, pvc will not function properly, be aware of this.
```sh
kubectl apply -f pvc.yaml
```

## TEST pod.yaml
```sh
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pods
  labels:
    nginx: test
spec:
  containers:
    - name: nginx
      image: nginx
      volumeMounts:
      - name: ebs-volume
        mountPath: /data
          #  nodeSelector:
          # failure-domain.beta.kubernetes.io/zone: ap-northeast-2a
  volumes:
    - name: ebs-volume
      persistentVolumeClaim:
        claimName: pvc-1
``` 

pod.yaml create after , 0/2 nodes are available: pod has unbound immerseantVolumeClaims. preempt: 0/2 nodes are available: 2 Preemption is not help for scheduling.
```sh
kubectl apply -f pod.yaml
```

If this is the case and an error occurs, check the Volumes AZ. And if the AZ where the pod was generated is different, the node selector in the pod allows the pod to be generated in the appropriate AZ. Thank you. 