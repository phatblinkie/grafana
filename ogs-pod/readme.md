#if the pod already exist, you can update it with

-- podman play kube --replace ogs-pod.yml

#if you update the containers images, the above command will update the containers in the pod to use the new updated image
if this happens, you should regenerate the systemd files
this process has been scripted on shell file

-- systemdfiles/create_install_or_update_user_systemd_files.sh


#after that, the pod can be managed with systemctl --user like this
#to stop
systemctl --user stop pod-ogs
#to start
systemctl --user start pod-ogs

# the pod should also auto start on system reboot without data loss
if it doesnt, make sure you run the command
loginctl enable-linger

if this is disabled, enable it, or as root 
loginctl enable-linger aap
