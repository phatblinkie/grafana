echo WARNING, this may cause data loss if the images are already created.
sleep 10

cd grafana
echo Building grafana image
sleep 3
./1.build-grafana-image.sh

cd ../loki
echo Building loki image
sleep 3
./1.build-loki-image.sh

cd ../mimir
echo Building mimir image
sleep 3
./1.build-mimir-image.sh

cd ../vuejs-dashboard
podman build -f Dockerfile-freshbuild -t ogs-dashboard:latest

