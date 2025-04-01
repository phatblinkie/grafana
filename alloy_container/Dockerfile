FROM docker.io/grafana/alloy:latest
COPY config.alloy /etc/alloy/config.alloy
EXPOSE 12345
CMD ["run", "/etc/alloy/config.alloy", "--server.http.listen-addr=0.0.0.0:12345", "--storage.path=/var/lib/alloy/data"]
#run --server.http.listen-addr=0.0.0.0:12345 --storage.path=/var/lib/alloy/data \
#    /etc/alloy/config.alloy
