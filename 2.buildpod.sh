echo WARNING this will build or rebuild the pod from the images created by the 1.buildallimages.sh script
echo WARNING, there will be data loss as the containers use built in volumes.
sleep 10

mkdir -v -p ~/container_storage_data
chmod -v 0777 ~/container_storage_data

mkdir -v -p ~/container_storage_data/mimirconfigs
cp mimir/config.yml ~/container_storage_data/mimirconfigs/
chmod -v 0755 ~/container_storage_data/mimirconfigs
chmod -v 0644 ~/container_storage_data/mimirconfigs/config.yml

mkdir -v -p ~/container_storage_data/grafana
chmod -v 0777 ~/container_storage_data/grafana

mkdir -v -p ~/container_storage_data/grafana/provisioning
chmod -v 0777 ~/container_storage_data/grafana/provisioning
cp -v grafana/datasources.yaml ~/container_storage_data/grafana/provisioning/
chmod -v 0666 ~/container_storage_data/grafana/provisioning/datasources.yaml

mkdir -v -p ~/container_storage_data/grafana/sample_dashboards
mkdir -v -p ~/container_storage_data/grafana/grafana-dashboard-provisioning
cp -v grafana/sample_dashboards/*.json ~/container_storage_data/grafana/sample_dashboards/
cp -v grafana/sample_dashboards/*.yml grafana/sample_dashboards/*.yaml ~/container_storage_data/grafana/grafana-dashboard-provisioning/


chmod -v 0777 ~/container_storage_data/grafana/sample_dashboards ~/container_storage_data/grafana/grafana-dashboard-provisioning
chmod -v 0644 ~/container_storage_data/grafana/grafana-dashboard-provisioning/* ~/container_storage_data/grafana/sample_dashboards/*




cd ogs-pod
podman play kube --replace ogs-pod.yml


echo UPDATING SYSTEMD
cd systemdfiles

./create_install_or_update_user_systemd_files.sh

podman pod ls
echo all done, you should now have a running pod!
