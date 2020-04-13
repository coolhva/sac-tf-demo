#!/bin/bash

apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

apt-get update
apt-get install -y docker-ce

apt-get install -y git
mkdir -p /data/web
git clone -b ${ git_branch } --single-branch https://github.com/${ git_repo }.git /data/web/

docker run -d -p 8080:80 -v /data/web:/usr/share/nginx/html:ro nginx

${ connector_command }