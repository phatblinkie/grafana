echo WARNING this will build or rebuild the pod from the images created by the 1.buildallimages.sh script
echo WARNING, there will be data loss as the containers use built in volumes.
sleep 10
podman pod stop ogs

mkdir -v -p ~/container_storage_data
chmod -v 0777 ~/container_storage_data

mkdir -v -p ~/container_storage_data/mimirconfigs
cp mimir/config.yml ~/container_storage_data/mimirconfigs/
chmod -v 0755 ~/container_storage_data/mimirconfigs
chmod -v 0644 ~/container_storage_data/mimirconfigs/config.yml

mkdir -v -p ~/container_storage_data/grafana/{provisioning,dashboards}
cp -v grafana/sample_dashboards/*.yml ~/container_storage_data/grafana/provisioning/
chmod -v 0777 ~/container_storage_data/grafana
chmod -v 0777 ~/container_storage_data/grafana/{provisioning,dashboards}
chmod -v 0666 ~/container_storage_data/grafana/provisioning/*.yml

cp -v grafana/datasources.yaml ~/container_storage_data/grafana/provisioning/
chmod -v 0666 ~/container_storage_data/grafana/provisioning/datasources.yaml

cp -v grafana/sample_dashboards/dashboards.yml ~/container_storage_data/grafana/dashboards/
chmod -v 0666  ~/container_storage_data/grafana/dashboards/dashboards.yml

cp -v grafana/sample_dashboards/*.json ~/container_storage_data/grafana/dashboards/
chmod -v 0666  ~/container_storage_data/grafana/dashboards/*.json

cd ogs-pod

#fix path that has to be hard coded with substitution
echo adjusting path to $HOME
#replace HOMEDIR with current users actual home dir, then build the pod

cat ogs-pod.yml.template | sed "s|HOMEDIR|$HOME|g" > ogs-pod.yml

podman play kube --replace ogs-pod.yml


echo UPDATING SYSTEMD
cd systemdfiles

./create_install_or_update_user_systemd_files.sh

podman pod ls
echo all done, you should now have a running pod with grafana, loki, mimir, and the old semaphore ui!
echo grafana is on port 3000  use admin/admin for first login.

echo you can use the playbooks to install the agents with ansible to your linux and windows hosts
