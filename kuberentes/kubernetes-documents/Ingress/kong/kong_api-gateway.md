# Kong API Gateway with AWS ALB

사전 준비 : 
    -> eksctl
    -> kubectl
    -> EKS Cluster
    -> aws load balancer controller 
```sh
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/experimental-install.yaml
```

먼저 Kong API Gateway를 구성하기 위해서 , Helm을 이용하여 Kong을 설치합니다.
```sh
helm repo add kong https://charts.konghq.com
helm repo update
```

If you search for Helm charts with:

```sh 
helm search repo kong
```

그 후에 , Kong API Gateway Helm Chart를 보면 kong-proxy에 Service Type이 Load Balancer으로 되어 있습니다. 이 부분을 NodePort로 수정합니다.

```sh
#controller:
#  ingressController:
#    env:
#      LOG_LEVEL: trace
#      dump_config: true
gateway:
  admin:
    http:
      enabled: true
  proxy:
    type: NodePort
    http:
      enabled: true
      nodePort: 32001
    tls:
      enabled: false
#  ingressController:
#    env:
#      LOG_LEVEL: trace
```

이제 설치를 합니다.

```sh
helm install kong kong/ingress -f kong-values.yaml -n kong
```

이제 GatewayClass를 이용하여, Kubernetes Gateway API와 Kong Gateway를 통합하여 외부 및 내부 트래픽을 효율적으로 관리할 수 있도록 설정합니다.

```sh 
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: kong-class
  annotations:
    konghq.com/gatewayclass-unmanaged: 'true'
spec:
  controllerName: konghq.com/kic-gateway-controller
```

Now create the class with:

```sh
kubectl apply -f kong-gw-class.yaml 
```

Kong Gateway가 모든 네임스페이스의 HTTP 요청(포트 80)을 수신하고 라우팅할 수 있도록 구성합니다.

```sh
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: kong-gateway
  namespace: kong
spec:
  gatewayClassName: kong-class
  listeners:
  - name: kong-listeners
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: All
```

Now create the resource with:

```sh
kubectl apply -f kong-gw-gateway.yaml 
```

HTTPRoute를 활용하여, Kong Gateway에게 어디로 접근을 해야하는지 구성을 합니다. 

```sh
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kong-httproute
  namespace: wsi
  annotations:
    konghq.com/strip-path: 'false'
spec:
  parentRefs:
  - name: kong-gateway
    namespace: kong
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /v1/customer
    backendRefs:
      - name: customer-service
        port: 80
        kind: Service
  - matches:
    - path:
        type: PathPrefix
        value: /healthcheck
    backendRefs:
      - name: customer-service
        port: 80
        kind: Service
  - matches:
    - path:
        type: PathPrefix
        value: /v1/product
    backendRefs:
      - name: product-service
        port: 80
        kind: Service
  - matches:
    - path:
        type: PathPrefix
        value: /healthcheck
    backendRefs:
      - name: product-service
        port: 80
        kind: Service
  - matches:
    - path:
        type: PathPrefix
        value: /v1/order
    backendRefs:
      - name: order-service
        port: 80
        kind: Service
  - matches:
    - path:
        type: PathPrefix
        value: /healthcheck
    backendRefs:
      - name: order-service
        port: 80
        kind: Service
```

We now create this route with:

```sh
kubectl apply -f kong-HTTProute.yaml
```

이제 Kong Proxy로 HTTProute를 통하여, 정상적으로 호출을 합니다. 이제 ingress 생성할 때, Service를 Kong으로 잡습니다.

```sh
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kong-ingress
  namespace: kong
  annotations:
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    alb.ingress.kubernetes.io/group.name: kong-tg
    alb.ingress.kubernetes.io/healthcheck-path: /healthcheck
    alb.ingress.kubernetes.io/load-balancer-name: kong-alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    kubernetes.io/ingress.class: alb

spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kong-gateway-proxy
                port:
                  number: 80
```