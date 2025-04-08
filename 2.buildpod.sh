echo WARNING this will build or rebuild the pod from the images created by the 1.buildallimages.sh script
echo WARNING, there will be data loss as the containers use built in volumes.
sleep 10

mkdir -p container_storage_data
chmod 0777 container_storage_data

cd ogs-pod
podman play kube --replace ogs-pod.yml


echo UPDATING SYSTEMD
cd systemdfiles

./create_install_or_update_user_systemd_files.sh

podman pod ls
echo all done, you should now have a running pod!
