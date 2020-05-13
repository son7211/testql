# Reading Time

이 Reading Time 응용 프로그램은 직원의 추천 도서를 소개하는 Web 어플리케이션입니다.



### 준비

이 응용 프로그램은 Java와 [Maven] (https://maven.apache.org/)가 필요합니다. 또한 임베디드 Tomcat 서블릿 컨테이너를 사용하고 있습니다. Java와 Maven이 설치되어 있는지 확인하려면 터미널에서 다음 명령을 실행하십시오 :
```
mvn --version
```

### 시작

응용 프로그램을 시작하려면 다음 명령을 실행하십시오 :

```
mvn clean install
sh target/bin/webapp
open http://localhost:8080
```

테스트를 실행하지 않고 설치하려면 다음 명령을 실행하십시오 :

```
mvn -B -DskipTests=true clean install
```

단위 테스트를 실행하려면 다음 명령을 실행하십시오 :

```
mvn clean test
```

## Actions 설정

이 프로젝트는 2 개의 워크 플로우를 실행합니다.

1. 피쳐 분기에 push 때마다 빌드 (컴파일 단위 테스트) 실행
2. master로 병합 때마다 빌드 Azure Web App에 배포


