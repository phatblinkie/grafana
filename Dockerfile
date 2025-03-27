ARG GRAFANA_VERSION="11.6.0"

FROM grafana/grafana-oss:${GRAFANA_VERSION}

ARG GF_INSTALL_IMAGE_RENDERER_PLUGIN="false"

ARG GF_GID="0"
ARG GF_INSTALL_PLUGINS="grafana-clock-panel,grafana-simple-json-datasource,alexanderzobnin-zabbix-app,nagasudhirpulla-api-datasource,frser-sqlite-datasource,speakyourcode-button-panel,briangann-datatable-panel,gapit-htmlgraphics-panel,grafana-polystat-panel,serrrios-statusoverview-panel,benjaminfourmaux-status-panel,yesoreyeram-infinity-datasource"


# 1011  wget 'https://grafana.com/api/plugins/alexanderzobnin-zabbix-app/versions/5.0.4/download?os=linux'
# 1023  wget 'https://grafana.com/api/plugins/grafana-clock-panel/versions/2.1.8/download'
# 1025  wget https://grafana.com/api/plugins/nagasudhirpulla-api-datasource/versions/1.2.4/download
# 1027  wget https://grafana.com/api/plugins/frser-sqlite-datasource/versions/3.5.0/download
# 1029  wget https://grafana.com/api/plugins/speakyourcode-button-panel/versions/0.3.2/download
# 1031  wget https://grafana.com/api/plugins/briangann-datatable-panel/versions/1.0.4/download
# 1033  wget https://grafana.com/api/plugins/gapit-htmlgraphics-panel/versions/2.1.1/download
# 1035  wget https://grafana.com/api/plugins/grafana-polystat-panel/versions/2.1.14/download
# 1037  wget https://grafana.com/api/plugins/serrrios-statusoverview-panel/versions/0.0.4/download
# 1039  wget https://grafana.com/api/plugins/benjaminfourmaux-status-panel/versions/1.0.0/download
# 1041  wget 'https://grafana.com/api/plugins/yesoreyeram-infinity-datasource/versions/3.2.0/download?os=linux&arch=amd64'

ENV GF_PATHS_PLUGINS="/var/lib/grafana-plugins"
ENV GF_PLUGIN_RENDERING_CHROME_BIN="/usr/bin/chrome"

USER root

RUN mkdir -p "$GF_PATHS_PLUGINS" && \
    chown -R grafana:${GF_GID} "$GF_PATHS_PLUGINS" && \
    if [ $GF_INSTALL_IMAGE_RENDERER_PLUGIN = "true" ]; then \
      if grep -i -q alpine /etc/issue; then \
        apk add --no-cache udev ttf-opensans chromium && \
        ln -s /usr/bin/chromium-browser "$GF_PLUGIN_RENDERING_CHROME_BIN"; \
      else \
        cd /tmp && \
        curl -sLO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
        DEBIAN_FRONTEND=noninteractive && \
        apt-get update -q && \
        apt-get install -q -y ./google-chrome-stable_current_amd64.deb && \
        rm -rf /var/lib/apt/lists/* && \
        rm ./google-chrome-stable_current_amd64.deb && \
        ln -s /usr/bin/google-chrome "$GF_PLUGIN_RENDERING_CHROME_BIN"; \
      fi \
    fi

USER grafana

RUN if [ $GF_INSTALL_IMAGE_RENDERER_PLUGIN = "true" ]; then \
      if grep -i -q alpine /etc/issue; then \
        grafana-cli \
          --pluginsDir "$GF_PATHS_PLUGINS" \
          --pluginUrl https://github.com/grafana/grafana-image-renderer/releases/latest/download/plugin-alpine-x64-no-chromium.zip \
          plugins install grafana-image-renderer; \
      else \
        grafana-cli \
          --pluginsDir "$GF_PATHS_PLUGINS" \
          --pluginUrl https://github.com/grafana/grafana-image-renderer/releases/latest/download/plugin-linux-x64-glibc-no-chromium.zip \
          plugins install grafana-image-renderer; \
      fi \
    fi


RUN if [ ! -z "${GF_INSTALL_PLUGINS}" ]; then \
      OLDIFS=$IFS; \
      IFS=','; \
      set -e ; \
      for plugin in ${GF_INSTALL_PLUGINS}; do \
        IFS=$OLDIFS; \
        if expr match "$plugin" '.*\;.*'; then \
          pluginUrl=$(echo "$plugin" | cut -d';' -f 1); \
          pluginInstallFolder=$(echo "$plugin" | cut -d';' -f 2); \
          grafana-cli --pluginUrl ${pluginUrl} --pluginsDir "${GF_PATHS_PLUGINS}" plugins install "${pluginInstallFolder}"; \
        else \
          grafana-cli --pluginsDir "${GF_PATHS_PLUGINS}" plugins install ${plugin}; \
        fi \
      done \
    fi

#add persistent volume so the container doesnt need to
VOLUME /var/lib/grafana
COPY configs/grafana.ini /etc/grafana/grafana.ini


# go to the custom directory
#cd packaging/docker/custom

#FROM docker.io/grafana/grafana-oss:11.6.0

# running the build command
# include the plugins you want e.g. clock planel etc
#docker build \
#  --build-arg "GRAFANA_VERSION=grafana/grafana-oss:11.6.0" \
#  --build-arg "GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource" \
#  -t grafana-oss-custom1 .

# running the custom Grafana container using the docker run command
#docker run -d -p 3000:3000 --name=grafana grafana-oss-custom1


#Setting	Default value
#GF_PATHS_CONFIG	/etc/grafana/grafana.ini
#GF_PATHS_DATA	/var/lib/grafana
#GF_PATHS_HOME	/usr/share/grafana
#GF_PATHS_LOGS	/var/log/grafana
#GF_PATHS_PLUGINS	/var/lib/grafana/plugins
#GF_PATHS_PROVISIONING	/etc/grafana/provisioning
