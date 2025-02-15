# What is Circuit Breaker?
Circuit breaker is a technology to prevent the failure from spreading to other services when a failure occurs at the application or server stage. For example, if service A sends a request to service B, service A also cannot return a response, which has an impact. This situation can be prevented with a circuit breaker.
  
Condition of circuit breaker  
- CLOSED: Normal call status  
- OPEN: Call blocked due to failure  
- HALF OPEN: Status of attempting a call again after a certain period of time  
  
First, after creating two Py applications developed for practical practice, such as Docker Hub or AWS ECR.  

## deployment.yaml 

```sh
# 200 Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v200
  namespace: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo
      version: v200
  template:
    metadata:
      labels:
        app: demo
        version: v200
    spec:
      containers:
      - name: demo-v200
        image: 226347592148.dkr.ecr.ap-northeast-2.amazonaws.com/demo-ecr:ok  # 200 응답 이미지
        ports:
        - containerPort: 8081

---

# 5xx Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v5xx
  namespace: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo
      version: v5xx
  template:
    metadata:
      labels:
        app: demo
        version: v5xx
    spec:
      containers:
      - name: app-v5xx
        image: 226347592148.dkr.ecr.ap-northeast-2.amazonaws.com/demo-ecr:error  # 5xx 응답 이미지
        imagePullPolicy: Always
        ports:
        - containerPort: 8081
```

## gateway 

```sh
# Gateway 설정
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: demo-gateway
  namespace: demo
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
```

## svc.yaml & vs.yaml

```sh 
# demo-service Service
apiVersion: v1
kind: Service
metadata:
  name: demo-service
  namespace: demo
spec:
  selector:
    app: demo
  ports:
  - protocol: TCP
    port: 8081
    targetPort: 8081
---
# VirtualService 설정
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: demo-virtualservice
  namespace: demo 
spec:
  hosts:
  - "*"
  gateways:
  - demo-gateway
  http:
  - route:
    - destination:
        host: demo-service
        port:
          number: 8081
```

## dr.yaml

```sh
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: demo-dr
  namespace: demo
spec:
  host: demo-service  
  trafficPolicy:
    outlierDetection:
      maxEjectionPercent: 100 # 서비스 전체를 차단  
      consecutive5xxErrors: 3 # 5xx 오류가 2회 연속 발생하면 Circuit Breaker 발동
      interval: 5s            # 오류를 체크하는 주기
      baseEjectionTime: 30s   # Circuit Breaker 발동 시 30초간 해당 서비스로의 트래픽을 차단
```

In the DestinationRule option, spec.trafficPolicy is set to block all traffic to the service for 30 seconds if 5xx errors occur twice in 5 seconds, and our application returns 500 errors with a 50% probability, resulting in a Service Unavailable error as circuit breaker continues to remain OPEN.  
   
To solve this problem, we need to reduce the time for outlierDetection.baseEjectionTime and outlierDetection.interval.