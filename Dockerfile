FROM openjdk:latest

ADD target/spring-petclinic-2.1.0.BUILD-SNAPSHOT.jar app.jar

ENTRYPOINT ["java", "-jar", "app.jar"]

EXPOSE 8080
