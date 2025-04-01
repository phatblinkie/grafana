from  docker.io/grafana/loki:3.4.1
VOLUME /mnt/config
COPY loki-config.yaml /mnt/config/loki-config.yaml

#docker create --name loki -d -v $(pwd):/mnt/config -p 3100:3100 docker.io/grafana/loki:3.4.1 -config.file=/mnt/config/loki-config.yaml

