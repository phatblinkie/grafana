#!/bin/bash
echo you need to be logged into registry.redhat.io
echo run podman login registry.redhat.io  

#build website
cd sitesource
npm config set strict-ssl false
#nvm install 18.20.4
#should have nodejs version 18.20.4 now
#npm install 
#npm run build
cd ..

#build image for containers to use
podman build -f Dockerfile-freshbuild -t ogs-dashboard:latest

#display container
podman images
