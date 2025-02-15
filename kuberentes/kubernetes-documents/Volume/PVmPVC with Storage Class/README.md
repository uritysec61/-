# Storage Class

ex 
```sh
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp2             kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  8h
gp3             kubernetes.io/aws-ebs   Delete          Immediate              false                  13m

```

Description of the VOLUMEBINDING MODE option.
WaitForFirstConsumer -> pods is created, pv is created.
Immediate -> pods are not generated, Immediate creates pv immediately.

The default value for Storage Classes is Immersion, and WaitForFirstConsumer must be placed in the yaml file separately.

```sh
volumeBindingMode: WaitForFirstConsumer
```

## WaitForFirstConsumer vs Immediate
The reason why WaitForFirstConsumer is so efficient is that it creates pv and volumes when it generates pods, so it is very efficient,
In the case of Immediate, creating pv and volumes is not very efficiently good, but in the case of large volumes, Immediate is efficiently
It could be good, because in the case of WaitForFirstConsumer, pv and volumes are created after the pods are created, and if the capacity is large, 
the time will be It's consumed a lot.

## Amazon EBS CSI (aws-ebs-sci-driver)

AWS official website :
```sh
1. https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html
2. https://docs.aws.amazon.com/eks/latest/userguide/creating-an-add-on.html
```

Check the official home page so that you can create aws-ebs-sci-driver.

## pvc.yaml
```sh
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-1
spec:
  storageClassName: "gp2" # Empty string must be explicitly set otherwise default StorageClass will be set
  accessModes:            # kubectl patch storageclass "scName" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
        #volumeMode: Filesystem
        #volumeName: pv-1
```

The EKS Cluster has created a Storage Class in gp2 by default, which is used in this session.

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
    app: app
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

```sh
kubectl apply -f pod.yaml
```

---

## sc.yaml
```sh
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
parameters:
  fsType: ext4
  type: gp3
provisioner: kubernetes.io/aws-ebs
reclaimPolicy: Delete
```

If you use this sc.yaml, you can use gp3. Also, you need to change the storage class name in pvc.yaml.

```sh
kubectl patch storageclass "scName" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

You can use the command above to default to the storage class, which will go to the default value even if you do not put a value in pvc.yaml storage ClassName.