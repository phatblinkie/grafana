from  docker.io/grafana/loki:3.4.1
#RUN mkdir -p /etc/loki && chown loki:loki /etc/loki
#VOLUME /mnt/config
#USER root
COPY loki-config.yaml /etc/loki/local-config.yaml
RUN ls -ail /etc/loki
#RUN chown loki:loki /etc/loki/local-config.yaml
RUN ls -ail /etc/loki

RUN cat /etc/loki/local-config.yaml
#docker create --name loki -d -v $(pwd):/mnt/config -p 3100:3100 docker.io/grafana/loki:3.4.1 -config.file=/mnt/config/loki-config.yaml

