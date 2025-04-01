FROM docker.io/grafana/mimir:2.16.0
VOLUME /var/mimir
#EXPOSE 9009
#RUN mkdir -p /etc/mimir
COPY config.yml /etc/mimir/config.yml
COPY runtime_config.yml /etc/mimir/runtime_config.yml

CMD ["run", "/bin/mimir", "--config.file=/etc/mimir/config.yml", "--runtime-config.file=/etc/mimir/runtime-config.yml", "--log.level info"]

