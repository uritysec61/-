## Fargate IAM에 CloudWatch 권한을 주어야 합니다. 

## Fargate Logs

```bash

kind: Namespace  
apiVersion: v1  
metadata:  
  name: aws-observability  
  labels:  
    aws-observability: enabled  

kubectl apply -f aws-observability-namespace.yaml  

# 일반적인 Fluent Conf에 포함된 주요 단원은 Service, Input, Filter, Output입니다. 하지만 Fargate 로그 라우터는 다음 부분만 수락합니다.  

#   Filter 및Output 부분입니다.  

#   Parser 부분.  

#   기타 부분을 제공하는 경우 해당 부분은 거부됩니다.  

kind: ConfigMap
apiVersion: v1
metadata:
  name: aws-logging
  namespace: aws-observability
data:
  flb_log_cw: "false"  # Set to true to ship Fluent Bit process logs to CloudWatch.
  filters.conf: |
    [FILTER]
        Name parser
        Match *
        Key_name log
        Parser crio
    [FILTER]
        Name kubernetes
        Match kube.*
        Merge_Log On
        Keep_Log Off
        Buffer_Size 0
        Kube_Meta_Cache_TTL 300s
    
#    [FILTER]
#    Name grep
#    Match *
#    Exclude log /healthcheck

  output.conf: |
    [OUTPUT]
        Name cloudwatch_logs
        Match   kube.*
        region region-code
        log_group_name my-logs
        log_stream_prefix from-fluent-bit-
        log_retention_days 60
        auto_create_group true
  parsers.conf: |
    [PARSER]
        Name crio
        Format Regex
        Regex ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>P|F) (?<log>.*)$
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z

```