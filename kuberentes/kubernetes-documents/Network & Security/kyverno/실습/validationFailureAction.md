"audit" 이는 정책 위반 시 경고만 출력되고, 리소스 생성이 차단되지 않는다는 뜻입니다. 
만약 위반된 정책으로 리소스 생성이 차단되기를 원하신다면 validationFailureAction을 "enforce"로 설정해야 합니다.