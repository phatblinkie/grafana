step 0. Fix the fapolicyd rules to allow git-lfs and ansible to operate. copy the files from fapolicyd_rules/ and put place them into /etc/fapolicyd/rules.d/. Then Restart the service with 'systemctl restart fapolicyd'

step 1. add a disk to the vm to hold the containers data, size is up to you, but recommend nothing smaller than 60 gigs to allow for growth

step 2. execute the shell script as normal user, with 'bash Install_Menu.sh'

step 3. follow the steps in order, after providing the sudo password.

step 4. browse to the grafana container using the host ip, no port is needed because we installed an nginx reverse proxy.

--This maps internal port 3000 to external port 80

Since all the containers data is stored on the host file system, updating shouldnt make data loss.
previously the data was inserted into the container with a Dockerfile now its not stored inside the image
