#!/bin/bash

sudo apt update -y && sudo apt upgrade -y

sudo apt install apt-transport-https ca-certificates curl software-properties-common -y

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y

sudo apt update -y
sudo apt install docker-ce -y
sudo apt install docker-compose -y

sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER