# About Pipeline Project 

- [Project Github Location](https://github.com/praveenst/spring-petclinic)

## To execute performance test script this locally,

```
git clone https://github.com/praveenst/spring-petclinic.git
cd spring-petclinic
./mvnw package
./mvnw verify

```

## Building and pushing to docker hub

The prerequisite for this step is to have Dockerfile in root folder. A valid docker file looks

```
FROM openjdk:latest
ADD target/spring-petclinic-2.1.0.BUILD-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
EXPOSE 8080
```

Once you have the Dockerfile in project root, the following commands can be used to build and push to the docker registry

```
docker build -t praveenst/pet-store-aws .
docker push praveenst/pet-store-awsa
```

## Starting jenkins pipeline

The gist of this project is to have a pipeline defined and expressed as a declarative configuration and let the jenkins do the rest.

The prerequisite here is to have Jenkinsfile in the root folder. The jenkins file has four stages, Build, Test, Stage and Deliver

- stage('Build') - takes care of building
- stage('Test') - takes care of development tests
- stage('Stage') - takes care of executing the e2e and performance tests
- stage('Deliver') - takes care of the delivery, in this case to build and push to docker hub

The additional steps to setup and launch the ec2 machine is currently a manual exercise documented in `Deploying on aws` section below. 

```
pipeline {
    agent {
        docker {
            image 'maven:3-alpine' 
            args '-v /root/.m2:/root/.m2' 
        }
    }
    stages {
        stage('Build') { 
            steps {
                sh 'mvn clean package'
                java -jar target/*.jar
            }
        }
        stage('Test') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }
        stage('Stage') {
            steps {
                sh 'mvn verify'
            }
        }
        stage('Deliver') {
            steps {
                sh 'docker build -t praveenst/pet-store-aws .'
                sh 'docker push praveenst/pet-store-aws'
            }
        }

    }
}
```

```
docker run   --rm   -u root   -p 9200:8080   -v jenkins-data:/var/jenkins_home   -v /var/run/docker.sock:/var/run/docker.sock   -v "$HOME":/home   jenkinsci/blueocean\

```

## Deploying on aws

```
ssh -i "petstorekey.pem" ec2-user@ec2-18-220-243-190.us-east-2.compute.amazonaws.com
sudo yum update -y
sudo yum install docker -y
sudo service docker start
sudo docker run -p 80:8080 praveenst/pet-store-aws

```
You can then access petclinic here: http://ec2-18-220-243-190.us-east-2.compute.amazonaws.com/vets.html


## Database configuration

In its default configuration, Petclinic uses an in-memory database (HSQLDB) which
gets populated at startup with data. A similar setup is provided for MySql in case a persistent database configuration is needed.
Note that whenever the database type is changed, the app needs to be run with a different profile: `spring.profiles.active=mysql` for MySql.

You could start MySql locally with whatever installer works for your OS, or with docker:

```
docker run -e MYSQL_ROOT_PASSWORD=petclinic -e MYSQL_DATABASE=petclinic -p 3306:3306 mysql:5.7.8
```


