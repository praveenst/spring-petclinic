#!/bin/bash

sudo yum update -y
sudo yum install docker -y
sudo service docker start
sudo docker run -p 80:8080 praveenst/pet-store-aws
