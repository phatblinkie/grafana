on a fresh system, you can run the 2 scripts
1.buildallimages.sh
2.buildpod.sh 

and it SHOULD
build the images
build the containers in a pod named ogs
update the --user systemd files to auto start the pod on boot
start the pod

Rerunning these, can result in loss of stored data inside the containers if they already exists. be careful
