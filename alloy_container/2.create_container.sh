#podman create --name="alloy" -it -p 12345:12345 docker.io/grafana/alloy:latest
podman create --name="alloy-custom" -it -p 12345:12345 localhost/alloy-custom:latest
#echo you now have made a container named "alloy"
echo you now have made a container named "alloy-custom"
echo to start it run the 3.start_container.sh file
