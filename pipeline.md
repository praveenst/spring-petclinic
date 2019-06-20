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

## Performance Test Harness

Another key effor to this project is to have Jmeter take care of the performance testing. 

To run the Jmeter tests as part of the pipeline stage `Stage` , maven is used to implement that and as a result following changes are needed in pom.xml

```
       <plugin>
            <groupId>com.lazerycode.jmeter</groupId>
            <artifactId>jmeter-maven-plugin</artifactId>
            <version>2.0.3</version>
            <configuration>
                <testResultsTimestamp>false</testResultsTimestamp>
                <propertiesUser>
                    <threadgroup.count>2</threadgroup.count>
                    <threadgroup.rampup>2</threadgroup.rampup>
                    <threadgroup.duration>5</threadgroup.duration>
                    <jmeter.save.saveservice.output_format>csv</jmeter.save.saveservice.output_format>
                    <jmeter.save.saveservice.bytes>true</jmeter.save.saveservice.bytes>
                    <jmeter.save.saveservice.label>true</jmeter.save.saveservice.label>
                    <jmeter.save.saveservice.latency>true</jmeter.save.saveservice.latency>
                    <jmeter.save.saveservice.response_code>true</jmeter.save.saveservice.response_code>
                    <jmeter.save.saveservice.response_message>true</jmeter.save.saveservice.response_message>
                    <jmeter.save.saveservice.successful>true</jmeter.save.saveservice.successful>
                    <jmeter.save.saveservice.thread_counts>true</jmeter.save.saveservice.thread_counts>
                    <jmeter.save.saveservice.thread_name>true</jmeter.save.saveservice.thread_name>
                    <jmeter.save.saveservice.time>true</jmeter.save.saveservice.time>
                </propertiesUser>
            </configuration>
            <executions>
                <execution>
                    <id>jmeter-tests</id>
                    <phase>verify</phase>
                    <goals>
                        <goal>jmeter</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
        <plugin>
            <artifactId>maven-antrun-plugin</artifactId>
            <executions>
                <execution>
                    <phase>pre-site</phase>
                    <configuration>
                        <tasks>
                            <mkdir dir="${basedir}/target/jmeter/results/dashboard" />
                            <copy file="${basedir}/src/test/resources/reportgenerator.properties" 
                                  tofile="${basedir}/target/jmeter/bin/reportgenerator.properties" />
                            <copy todir="${basedir}/target/jmeter/bin/report-template">
                                <fileset dir="${basedir}/src/test/resources/report-template" />
                            </copy>
                            <java jar="${basedir}/target/jmeter/bin/ApacheJMeter-3.0.jar" fork="true">
                                <arg value="-g" />
                                <arg value="${basedir}/target/jmeter/results/*.jtl" />
                                <arg value="-o" />
                                <arg value="${basedir}/target/jmeter/results/dashboard/" />
                            </java>
                        </tasks>
                    </configuration>
                    <goals>
                        <goal>run</goal>
                    </goals>
                </execution>
            </executions>
```

Once you have the pom file, locally executing `./mvnw verify` from the root folder should take care of actually running the performance test. 

The throughput jmeter tests are in project root folder as `pet_clinic_local_aws_throughput.jmx`

For the automated verify stage, the jmeter file will be generated in `target/jmeter/src` folder and throughput test above couldo be copied over to that directory to get it part of the pipeling before invoking jenkins.

If jenkins need to pick up the change, make sure you stage the changes and commit to git repository. My thought process is to have this additional manual step as part of the approval process once the pipeline stages pass. The  `pet_clinic_local_aws_throughput.jmx` can  be executed as such using jmeter commandline. 

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


