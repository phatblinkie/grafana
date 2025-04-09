echo There will be data loss!
sleep 10
podman pod stop ogs
sudo rm -rf /home/admin/container_storage_data

./1.buildallimages.sh  && ./2.buildpod.sh

