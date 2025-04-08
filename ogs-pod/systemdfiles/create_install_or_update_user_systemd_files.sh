mkdir -p ~/.config/systemd/user
podman generate systemd --files --name --restart-policy always --restart-sec 20 ogs
mv *.service ~/.config/systemd/user/
loginctl enable-linger
systemctl --user daemon-reload
systemctl --user enable pod-ogs.service
podman pod stop ogs
systemctl --user stop pod-ogs.service
systemctl --user start pod-ogs.service
