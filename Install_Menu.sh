#!/bin/bash

script_version="1.0.0"
# Integrated Monitoring Stack Deployment Tool
# Combines both privileged (root) and non-privileged (user) operations
# Always requests sudo password at start and uses it when needed

# ---------- Initial Setup ----------

# Clear the sudo password variable on exit
cleanup() {
    unset SUDO_PASSWORD
    # Clear sudo cache to ensure fresh prompt next time
    sudo -k
}
trap cleanup EXIT


# ---------- Improved Sudo Password Handling ----------

get_sudo_password() {
    # Clear any existing sudo credentials
    sudo -k

    echo "===================================================="
    echo " Monitoring Stack Deployment Tool - Ver. $script_version"
    echo "===================================================="
    echo "This script requires root privileges for some operations."

    # Loop until we get a valid sudo password
    while true; do
        echo "Please enter your sudo password to proceed:"
        read -r -s SUDO_PASSWORD

        # Verify the password works by trying to list root directory
        echo
        echo -n "Verifying sudo access... "
        if echo "$SUDO_PASSWORD" | sudo -S ls /root >/dev/null 2>&1; then
            echo "OK"
            break
        else
            echo "FAILED"
            echo "Incorrect sudo password. Please try again."
            unset SUDO_PASSWORD
        fi
    done

    # Export the verified password
    export SUDO_PASSWORD
    echo
}

run_with_sudo() {
    # Use the verified password with proper newline handling
    echo -e "$SUDO_PASSWORD\n" | sudo -S "$@" 2>/dev/null
}

# ---------- Privileged Functions (run as root) ----------

# Function to add NFS export and reload NFS
create_and_share_nfs() {
    echo "Configuring NFS..."
    echo "Checking if NFS server is installed"
    if [ $(rpm -qa|grep -c nfs-utils) -eq 0 ]
    then
	    echo "ERROR: NFS is not installed, run as root 'dnf install nfs-utils'"
	    return 1
    fi
    # Define the NFS export line
    local export_line="/mission-share/nfs *(rw,sync,no_subtree_check,no_root_squash)"

    # Check if the export already exists
    run_with_sudo mkdir -p /mission-share/nfs
    run_with_sudo chmod 0777 /mission-share/nfs
    if run_with_sudo grep -q "/mission-share/nfs" /etc/exports; then
        echo "Warning: /mission-share already exists in /etc/exports. Please check manually."
    else
        # Create a temporary file with the export line
        local temp_file=$(mktemp)
        echo "$export_line" > "$temp_file"

        # Append the temporary file to /etc/exports using sudo
        if echo "$SUDO_PASSWORD" | sudo -S sh -c "cat '$temp_file' >> /etc/exports" 2>/dev/null; then
            echo "Successfully appended to /etc/exports."
        else
            echo "Error: Failed to append to /etc/exports."
            rm -f "$temp_file"
            return 1
        fi

        # Clean up the temporary file
        rm -f "$temp_file"
    fi

    # Reload NFS exports
    echo "Reloading NFS exports..."
    if ! run_with_sudo exportfs -r || ! run_with_sudo exportfs; then
        echo "Error: Failed to reload NFS exports."
        return 1
    fi

    # Create NFS mission-share directories
    echo "Creating NFS Mission-Share Directories..."
    run_with_sudo mkdir -p /mission-share/nfs/tide/{ccads-in,ccads-out,arc-out,fuse-out,sceptre-in,sceptre-out,esa-out,eped-out,idm-in,fail,tmp,save,idm-in/save}
    run_with_sudo mkdir -p /mission-share/nfs/audit_logs

    # Set permissions (adjust as needed for NFS)
    echo "Setting permissions for NFS directories..."
    run_with_sudo chmod -R 777 /mission-share/nfs
    #run_with_sudo chown -R nobody:nogroup /mission-share

    # Enable and start NFS server
    echo "Enabling and starting NFS server..."
    if ! run_with_sudo systemctl enable --now nfs-server; then
        echo "Error: Failed to enable or start nfs-server."
        return 1
    fi

    echo "NFS configuration completed."
}


# Example usage: Call the function with fqdn and optional directory path
# rename_ssl "nifi.test" "/path/to/your/files"

rename_ssl() {
  # Define the fully qualified domain name (fqdn)
  local fqdn="$1"
  # Define the directory where the files are located (default to current directory)
  local dir="${2:-.}"

  # Check if fqdn is provided
  if [[ -z "$fqdn" ]]; then
    echo "Error: fqdn must be provided."
    return 1
  fi

  # Check if the directory exists
  if [[ ! -d "$dir" ]]; then
    echo "Error: Directory '$dir' does not exist."
    return 1
  fi

  # Normalize directory path to remove trailing slash
  dir="${dir%/}"

  # Initialize a flag to track if any files were found
  local files_found=false

  # Escape dots in fqdn for proper pattern matching
  local escaped_fqdn
  escaped_fqdn=$(echo "$fqdn" | sed 's/\./\\./g')


  # Use find to locate files matching the pattern
  while IFS= read -r file; do
    # Check if the file exists (redundant but safe)
    if [[ -f "$file" ]]; then
      # Extract the extension
      local ext="${file##*.}"
      # Rename the file to ssl.<extension>
      mv "$file" "$dir/ssl.$ext"
      echo "Renamed $file to ssl.$ext"
      files_found=true
    fi
  done < <(find "$dir" -maxdepth 1 -type f -name "$escaped_fqdn.*")

  # Check if no files were found and print a warning
  if [[ "$files_found" == false ]]; then
    echo "Warning: No files matching '$fqdn.*' were found in '$dir'."
    echo "Debug: Directory contents:"
    ls -l "$dir"
    return 1
  fi
}


# Function to generate the ssl keys for the containers
generate_ssl_keys() {
    #fix perms on files and folder to current user
    cd /mission-share/vast-ca/
    echo "Creating SSL Certs"
    certs="bash server-cert-gen.sh"

    hostname -i
    read -p "Please enter msnsvr IP address: " msnsvr_ip
    # Display the entered IP address
    echo "You entered: $msnsvr_ip"

    hostname
    read -p "Please enter msnsvr FQDN (e.g. msnsvr.army.local): " msnsvr_fqdn

    # Display the entered fqdn
    echo "You entered: $msnsvr_fqdn"
    cat /etc/resolv.conf
    read -p "Please enter domain name (e.g. army.local): " domain
    echo "You entered: $domain"
    local temp_file=$(mktemp)
    echo "$msnsvr_ip      $msnsvr_fqdn       msnsvr     grafana     loki     mimir   nifi.$domain" > $temp_file
    echo "$SUDO_PASSWORD" | sudo -S sh -c "cat '$temp_file' >> /etc/hosts"

    certs="bash server-cert-gen.sh"

    # Creating Grafana Certs
    echo -e "\nCreating Grafana certs...\n\n"
    podman unshare chmod 0755 *.sh
    # Use printf to send commands to create grafana certs
    printf "grafana.$domain\n\nUS\nMaryland\nAPG\nFII\n3650\nsilkwave\n" | ./server-cert-gen.sh /mission-share/podman/containers/keys/grafana/
    #copy them to generic naming, so its easier to template
    rename_ssl "grafana.$domain" "/mission-share/podman/containers/keys/grafana/"
    podman unshare chmod 0644 /mission-share/podman/containers/keys/grafana/ssl.*

    # Creating Loki Certs
    echo -e "\nCreating Loki certs...\n\n"

    # Use printf to send commands to create loki certs
    printf "loki.$domain\n\nUS\nMaryland\nAPG\nFII\n3650\nsilkwave\n" | ./server-cert-gen.sh /mission-share/podman/containers/keys/loki/
    rename_ssl "loki.$domain" "/mission-share/podman/containers/keys/loki/"
    podman unshare chmod 0644 /mission-share/podman/containers/keys/loki/ssl.*


    # Creating Mimir Certs
    echo -e "\nCreating Mimir certs...\n\n"

    # Use printf to send commands to create mimir certs
    printf "mimir.$domain\n\nUS\nMaryland\nAPG\nFII\n3650\nsilkwave\n" | ./server-cert-gen.sh /mission-share/podman/containers/keys/mimir/
    rename_ssl "mimir.$domain" "/mission-share/podman/containers/keys/mimir/"
    podman unshare chmod 0644 /mission-share/podman/containers/keys/mimir/ssl.*
    # Creating Nifi Certs
    echo -e "\nCreating Nifi certs...\n\n"

    # Use printf to send commands to create nifi certs
    printf "nifi.$domain\n\msnsvr.$domain\n\nUS\nMaryland\nAPG\nFII\n3650\nsilkwave\n" | ./server-cert-gen.sh /mission-share/podman/containers/keys/nifi/
    rename_ssl "nifi.$domain" "/mission-share/podman/containers/keys/nifi/"
    podman unshare chmod 0644 /mission-share/podman/containers/keys/nifi/ssl.*

    # Use printf to send commands to create local nginx certs
    echo -e "\nCreating NGINX proxy certs...\n\n"
    printf "$msnsvr_ip\n\\$msnsvr_ip\n\nUS\nMaryland\nAPG\nFII\n3650\nsilkwave\n" | ./server-cert-gen.sh /mission-share/podman/containers/keys/nginx/
    rename_ssl "$msnsvr_ip" "/mission-share/podman/containers/keys/nginx/"
    #podman unshare chmod 0644 /mission-share/podman/containers/keys/nginx/ssl.*
    run_with_sudo cp -v /mission-share/podman/containers/keys/nginx/ssl.* /etc/pki/tls/
    echo "fixing selinux context on nginx keys"
    run_with_sudo semanage fcontext -a -t cert_t "/etc/pki/tls/ssl.crt"
    run_with_sudo semanage fcontext -a -t cert_t "/etc/pki/tls/ssl.key"
    run_with_sudo restorecon -v -F "/etc/pki/tls/ssl.crt"
    run_with_sudo restorecon -v -F "/etc/pki/tls/ssl.key"
    # change back to installer dir
    cd $OLDPWD

}


# Function to append to /etc/fstab
append_to_fstab() {
    local fstab_line="$1"
    if run_with_sudo grep -q "/mission-share" /etc/fstab; then
        echo "Warning: /mission-share already exists in /etc/fstab. Please check manually."
    else
        # Create a temporary file with the fstab line
        local temp_file=$(mktemp)
        echo "$fstab_line" > "$temp_file"

        # Use sudo to append the temporary file to /etc/fstab
        if echo "$SUDO_PASSWORD" | sudo -S sh -c "cat '$temp_file' >> /etc/fstab" 2>/dev/null; then
            echo "Successfully appended to /etc/fstab."
	    echo "Reloading systemctl"
	    run_with_sudo systemctl daemon-reload
        else
            echo "Error: Failed to append to /etc/fstab."
            rm -f "$temp_file"
            return 1
        fi

        # Clean up the temporary file
        rm -f "$temp_file"

        # Verify the fstab syntax
        if run_with_sudo mount -a >/dev/null 2>&1; then
            echo "fstab syntax is valid."
        else
            echo "Error: Invalid fstab entry detected. Restoring backup."
            run_with_sudo cp /etc/fstab.bak /etc/fstab 2>/dev/null
            return 1
        fi
    fi
}

configure_system_settings() {
    echo -e "\n[ROOT] Configuring System Settings..."

    safe_modify "/etc/sysctl.d/99-sysctl.conf" \
        "run_with_sudo sed -i 's/^user\.max_user_namespaces=0/user.max_user_namespaces=999999/' /etc/sysctl.d/99-sysctl.conf" \
        "Modifying user.max_user_namespaces setting"

    safe_modify "/usr/share/rhel/secrets/rhsm/syspurpose/syspurpose.json" \
        "run_with_sudo chmod 0644 /usr/share/rhel/secrets/rhsm/syspurpose/syspurpose.json" \
        "Setting permissions for syspurpose.json"

    safe_modify "/etc/yum.repos.d/redhat.repo" \
        "run_with_sudo chmod 0644 /etc/yum.repos.d/redhat.repo" \
        "Setting permissions for redhat.repo"

    # Apply sysctl changes immediately
    echo -e "\nApplying sysctl changes..."
    run_with_sudo sysctl -p /etc/sysctl.d/99-sysctl.conf | grep 'user.max_user_namespaces = 999999'
    check_success "Failed to apply sysctl changes" || return 1

    # Verify the setting was applied
    echo -e "\nVerifying sysctl settings..."
    run_with_sudo sysctl -a | grep user.max_user_namespaces

    # Change podman image storage location
    echo -e "\nSetting podman image location"
            # Use sudo to append the temporary file to /etc/fstab
	mkdir -p ~/.config/containers 2>/dev/null
        if cat configs/storage.conf > ~/.config/containers/storage.conf; then
            echo "Successfully overwrote ~/.config/containers/storage.conf"
        else
            echo "Error: Failed to overwrite ~/.config/containers/storage.conf"
            return 1
        fi
    #podman info | grep -A5 'store'

    #make pods run without active session
    loginctl enable-linger
    echo -e "\nSystem settings configured successfully."
}

provision_disk() {
    echo -e "\n[ROOT] Disk Provisioning..."

    list_available_disks() {
    # Get all disks (excluding CD-ROM devices)
    local disks=($(run_with_sudo lsblk -d -n -o NAME | grep -v sr))

    if [ ${#disks[@]} -eq 0 ]; then
        echo "No disks detected in system!" >&2
        return 1
    fi

    local available_disks=()
    for disk in "${disks[@]}"; do
        disk_path="/dev/$disk"

        # Check if disk has no filesystem and no partitions
        if ! run_with_sudo blkid -o device | grep -q "$disk_path" && \
           [ $(run_with_sudo lsblk -n -o TYPE "$disk_path" | grep -c part) -eq 0 ]; then
            available_disks+=("$disk_path")
        fi
    done

    if [ ${#available_disks[@]} -eq 0 ]; then
        echo "No eligible disks found (must be unmounted with no filesystem/partitions)" >&2
        return 1
    fi

    # Display disks with numbers and sizes
    echo "Available disks:"
    for i in "${!available_disks[@]}"; do
        size=$(run_with_sudo lsblk -n -o SIZE "${available_disks[$i]}")
        echo "$((i+1)). ${available_disks[$i]} (${size})"
    done

    # Export results
    AVAILABLE_DISKS=("${available_disks[@]}")
    export AVAILABLE_DISKS
    return 0
    }

    while true; do
        read -p "Have you added a virtual disk for podman data? (yes/no) " response
        case $response in
            [yY]|[yY][eE][sS])
                if ! list_available_disks; then
                    echo "No suitable disks found. Please add a disk and try again."
                    return 1
                fi

                while true; do
                    read -p "Select disk number (1-${#AVAILABLE_DISKS[@]}): " disk_num
                    if [[ "$disk_num" =~ ^[0-9]+$ ]] && [ "$disk_num" -ge 1 ] && [ "$disk_num" -le ${#AVAILABLE_DISKS[@]} ]; then
                        selected_disk="${AVAILABLE_DISKS[$((disk_num-1))]}"
                        break
                    else
                        echo "Invalid selection. Please enter a number between 1 and ${#AVAILABLE_DISKS[@]}."
                    fi
                done

                echo "You selected: $selected_disk"
                read -p "Confirm format with XFS and mount to /mission-share? (yes/no) " confirm
                if [[ "$confirm" =~ [yY]|[yY][eE][sS] ]]; then
                    echo "Creating XFS filesystem on $selected_disk..."
                    run_with_sudo mkfs.xfs -f "$selected_disk"
                    check_success "Failed to create XFS filesystem" || return 1

		    echo "Triggering device rescan to force UUID"
		    run_with_sudo udevadm trigger
		    sleep 2

                    echo "Creating mount point /mission-share..."
                    run_with_sudo mkdir -p /mission-share
                    run_with_sudo chmod 0777 /mission-share

                    echo "Mounting $selected_disk to /mission-share..."
                    run_with_sudo mount "$selected_disk" /mission-share
                    check_success "Failed to mount disk" || return 1

                    run_with_sudo chmod 0777 /mission-share
                    #take care of selinux label now before its populated with stuff
                    run_with_sudo semanage fcontext -a -t container_file_t "/mission-share(/.*)?"
                    run_with_sudo restorecon -Rv /mission-share

                    mkdir -p /mission-share/upload
                    chmod 0777 /mission-share/upload


		    #let podman command make the directoies for us
                    podman info >/dev/null
                    podman unshare mkdir -p /mission-share/podman/containers

                    echo "Adding $selected_disk to /etc/fstab..."
                    uuid=$(run_with_sudo blkid -s UUID -o value "$selected_disk")
		            echo "UUID found is $uuid"

                    if [ -z "$uuid" ]; then
                        echo "Error: Could not get UUID of $selected_disk" >&2
                        return 1
                    fi

                    fstab_line="UUID=$uuid /mission-share xfs defaults 0 0"
                    echo $fstab_line
                    if run_with_sudo grep -q "/mission-share" /etc/fstab; then
                        echo "Warning: /mission-share already exists in /etc/fstab. Please check manually."
                    else
                        # Backup /etc/fstab first
			        run_with_sudo cp /etc/fstab /etc/fstab.bak
			        append_to_fstab "$fstab_line"
                    fi

                    echo "Disk provisioning completed successfully!"
                    return 0
                else
                    echo "Operation cancelled."
                    return 0
                fi
                ;;
            [nN]|[nN][oO])
                echo "Skipping disk provisioning."
                return 0
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

install_nginx() {
    echo -e "\n[ROOT] Nginx Installation and Configuration..."

    if ! command -v nginx &> /dev/null; then
        echo "Installing nginx..."
        run_with_sudo dnf install nginx -y
        check_success "Failed to install nginx" || return 1
        echo "Nginx installed successfully"
    else
        echo "Nginx is already installed"
    fi

    config_source="configs/nginx.conf"
    config_dest="/etc/nginx/nginx.conf"

    if [ ! -f "$config_source" ]; then
        echo "Error: Source config file $config_source not found" >&2
        return 1
    fi

    echo "Copying Nginx configuration..."
    run_with_sudo cp -vf "$config_source" "$config_dest"
    run_with_sudo mkdir -vp /usr/share/nginx/html/rpms
    run_with_sudo chmod -v 0755 /usr/share/nginx/html/rpms
    run_with_sudo cp -vf alloy_installers/alloy-1.7.5-1.amd64.rpm /usr/share/nginx/html/rpms/
    run_with_sudo chmod -v 0644 /usr/share/nginx/html/rpms/alloy-1.7.5-1.amd64.rpm
    run_with_sudo cp -vf alloy_installers/alloy-installer-windows-amd64.exe.zip /usr/share/nginx/html/rpms/
    run_with_sudo chmod -v 0644 /usr/share/nginx/html/rpms/alloy-installer-windows-amd64.exe.zip
    check_success "Failed to copy Nginx configuration" || return 1

    run_with_sudo chmod -v 644 "$config_dest"
    echo "Configuration copied successfully"

    configure_selinux

    echo "Enabling and starting Nginx service..."
    run_with_sudo systemctl enable nginx
    run_with_sudo systemctl restart nginx
    check_success "Failed to restart Nginx" || return 1

    echo "Nginx configuration completed successfully!"
}

configure_selinux() {
    if command -v getenforce &> /dev/null && [ "$(getenforce)" = "Enforcing" ]; then
        echo "Configuring SELinux for Nginx proxy..."

        run_with_sudo setsebool -P httpd_can_network_connect 1
        check_success "Failed to set SELinux boolean" || return 1

        for port in 3000 3100 9009; do
            if ! run_with_sudo semanage port -l | grep -q "http_port_t.*tcp.*${port}"; then
                echo "Adding SELinux exception for port $port..."
                run_with_sudo semanage port -a -t http_port_t -p tcp ${port} 2>/dev/null || \
                echo "Warning: May need to install policycoreutils-python-utils for semanage"
            fi
        done

        echo "SELinux configuration complete"
    else
        echo "SELinux is not enforcing, skipping configuration"
    fi
}

configure_firewall() {
    echo -e "\n[ROOT] Firewall Configuration..."

    if ! command -v firewall-cmd &> /dev/null; then
        echo "Warning: firewalld is not installed. Skipping firewall configuration."
        return 0
    fi

    if ! systemctl is-active --quiet firewalld; then
        echo "Starting firewalld..."
        run_with_sudo systemctl start firewalld
    fi

    declare -A PORTS=(
        ["HTTP"]="80/tcp"
        ["HTTPs"]="443/tcp"
        ["Grafana"]="3000/tcp"
        ["Mimir"]="3100/tcp"
        ["Loki"]="9009/tcp"
	["Gitlab-ssl"]="9443/tcp"
	["Gitlab-http"]="8088/tcp"
	["Gitlab-ssh"]="2200/tcp"
    )


    for service in "${!PORTS[@]}"; do
        port=${PORTS[$service]}
        if ! run_with_sudo firewall-cmd --query-port="$port" | grep -q "yes"; then
            echo "Opening port $port for $service..."
            run_with_sudo firewall-cmd --permanent --add-port="$port"
            check_success "Failed to open port $port" || return 1
        fi
    done

    echo "Adding NFS service"
    run_with_sudo firewall-cmd --permanent --now --add-service="nfs"


    echo "Reloading firewalld..."
    run_with_sudo firewall-cmd --reload
    check_success "Failed to reload firewalld" || return 1

    echo "Firewall configuration completed successfully!"
}

# ---------- Non-Privileged Functions (run as user) ----------

pull_container_images() {
    echo -e "\n[USER] Pulling Container Images..."

    if [ ! -f "versions.txt" ]; then
        echo "Error: versions.txt file not found!" >&2
        return 1
    fi

    #without new disk, there isnt enough room
    if [ $(grep -c /mission-share /etc/mtab) -eq 0 ]
       then
       echo "Please add the 2nd disk, and run the mount option in this script first"
       return 1
    fi

    # Login to registry
    podman login -u Brian_Bowen -p '0o9i8u7y)O(I*U&Y' registry1.dso.mil

    # Load versions
    . versions.txt

    # Pull and tag Grafana
    echo "Downloading grafana version ${GRAFANA_VERSION}"
    podman pull registry1.dso.mil/ironbank/opensource/grafana/grafana:${GRAFANA_VERSION}
    podman image tag grafana:${GRAFANA_VERSION} grafana-oss-custom:${GRAFANA_VERSION}

    # Pull and tag Loki
    echo "Downloading loki version ${LOKI_VERSION}"
    podman pull registry1.dso.mil/ironbank/opensource/grafana/loki:${LOKI_VERSION}
    podman image tag loki:${LOKI_VERSION} loki-custom:${LOKI_VERSION}

    # Pull and tag Mimir
    echo "Downloading mimir version ${MIMIR_VERSION}"
    podman pull registry1.dso.mil/ironbank/opensource/grafana/mimir:${MIMIR_VERSION}
    podman image tag mimir:${MIMIR_VERSION} mimir-custom:${MIMIR_VERSION}

    # Pull and tag Nifi
    echo "Downloading nifi version ${NIFI_VERSION}"
    #podman pull registry1.dso.mil/ironbank/opensource/apache/nifi:${NIFI_VERSION}
    #until it can be stored on ironbank, use my personal hub for now, so this function still works at least
    #the image was modified, so sourcing its original location is not a good idea
    podman pull docker.io/phatblinkie/bigimage:tsb_py
    podman image tag nifi:${NIFI_VERSION} nifi-custom:${NIFI_VERSION}

    # Pull and tag GITLAB-CE
    echo "Downloading Gitlab-ce version ${GITLAB_VERSION}"
    podman pull docker.io/gitlab/gitlab-ce:${GITLAB_VERSION}
    podman image tag gitlab-ce:${GITLAB_VERSION} gitlab-ce-custom:${GITLAB_VERSION}

    echo -e "\nImage download process completed:"
    podman images | egrep "custom|TAG"
}


split_large_files() {
  # Directory containing the files (default: current directory)
  local dir="${1:-.}"

  # Size threshold (.5GB in bytes)
  local threshold=$((500 * 1024 * 1024))

  # Check if the directory exists
  if [[ ! -d "$dir" ]]; then
    echo "Error: Directory '$dir' does not exist."
    return 1
  fi

  # Find files larger than 1.5GB
  find "$dir" -maxdepth 1 -type f -size +${threshold}c | while IFS= read -r file; do
    # Get file size in human-readable format for logging
    local size
    size=$(ls -sh "$file" | awk '{print $1}')
    echo "Found file: $file ($size), splitting into 500MB chunks..."

    # Split the file into 500mb chuncks
    split --verbose -b 500m "$file" "${file}.part."
    if [[ $? -eq 0 ]]; then
      echo "Successfully split $file into chunks:"
      ls -lh "${file}.part."*
    else
      echo "Error: Failed to split $file"
    fi
  done
}

reassemble_files() {
  # Directory containing the split files (default: current directory)
  local dir="${1:-.}"

  # Check if the directory exists
  if [[ ! -d "$dir" ]]; then
    echo "Error: Directory '$dir' does not exist."
    return 1
  fi

  # Normalize directory path to remove trailing slash
  dir="${dir%/}"

  # Initialize a flag to track if any files were reassembled
  local files_reassembled=false

  # Find unique base filenames from split parts (e.g., nifi-1.24-py.tar.gz from nifi-1.24-py.tar.gz.part.aa)
  find "$dir" -maxdepth 1 -type f -name '*.part.*' | sed 's/\.part\.[a-z]\+$//' | sort -u | while IFS= read -r base_file; do
    # Check if the base file already exists
    if [[ -f "$base_file" ]]; then
      echo "Warning: Original file '$base_file' already exists. Skipping reassembly."
      continue
    fi

    # Get list of parts for this base file
    local parts
    parts=$(find "$dir" -maxdepth 1 -type f -name "${base_file##*/}.part.*" | sort)

    # Check if any parts were found
    if [[ -z "$parts" ]]; then
      echo "Warning: No split parts found for '$base_file'."
      continue
    fi

    # Log the parts being reassembled
    echo "Reassembling '$base_file' from parts:"
    echo "$parts" | while IFS= read -r part; do
      echo "  $part"
    done

    # Combine the parts into the original file
    cat $parts > "$base_file"
    if [[ $? -eq 0 ]]; then
      echo "Successfully reassembled '$base_file'"
      echo
      echo
      files_reassembled=true
      # Optional: List the reassembled file details
      ls -lh "$base_file"
      rm "${base_file}.part."*
        echo "Deleted split parts for '$base_file'"
	echo
	echo
    else
      echo "Error: Failed to reassemble '$base_file'"
      return 1
    fi
  done

}
# Example usage
# reassemble_files "/mission-share/podman/containers/keys/nifi"

install_tarball_images () {
    echo -e "\n[USER] Installing tarball container images"

    echo "Copying repo images to /mission-share/upload/"
    rsync -avh --progress upload_contents_to_mission-share_upload_dir/* /mission-share/upload/
    echo "Checking file integrity..."
    sha1sum -c --ignore-missing /mission-share/upload/sha1sum.txt
    if [ $? -ne 0 ]; then
        echo "Error: SHA1 checksum verification failed. Please check the uploaded files."
        return 1
    fi
    echo "File integrity check passed."
    echo "Reassembling split files if needed..."
    reassemble_files "/mission-share/upload"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to reassemble split files. Please check the upload directory."
        return 1
    fi
    echo "Reassembly complete or previously performed. Proceeding with 2nd integrity check..."
    sha1sum -c /mission-share/upload/sha1sum-after-assembly.txt
    if [ $? -ne 0 ]; then
        echo "Error: SHA1 checksum verification after reassembly failed. Please check the uploaded files."
        return 1
    fi
    echo "File integrity check after reassembly passed."
    echo -e "\n[USER] Importing tarball container images"
    for i in `ls /mission-share/upload/*.tar.gz|grep -v part`;  # Exclude split parts
	do
        echo "Importing container image: $i"
        mkdir -p /mission-share/.tmp >/dev/null
	    export TMPDIR=/mission-share/.tmp && podman load -i "$i"
	done
}

copy_source_directories() {
    echo -e "\n[ROOT] Copying Source Directories to target disk"
    # Check for rsync
    if ! command -v rsync &> /dev/null; then
        echo "Error: rsync is required but not installed. Please install it first." >&2
        return 1
    fi
    # Set up container storage

    path="/mission-share/podman/containers"
    rootpath="/mission-share"
    podmanshare="/mission-share/podman"
    echo
    echo "Creating container storage folders..."
    #run_with_sudo chmod 0777 $path
    run_with_sudo chcon -t -R container_file_t $podmanshare

    echo "Making needed directories"
    podman unshare mkdir -vp "$path/grafana/provisioning/dashboards" \
          "$path/grafana/provisioning" \
          "$path/grafana/dashboards" \
          "$path/grafana" \
          "$path/loki" \
          "$path/mimir" \
          "$path/nifi" \
          "$path/nifi/"{conf,lib,logs} \
          "$path/configs" \
          "$path/keys/"{grafana,mimir,loki,nifi,nginx} \
          "$rootpath/tide/"{out,in,ccads-in,ccads-out,arc-out,fuse-out,sceptre-in,sceptre-out,esa-out,eped-out,fail,tmp,save,idm-in/save} \
          "$rootpath/audit_logs" \
	  "$path/gitlab/"{logs,config,data}



    podman unshare cp -v configs/* $path/configs/
    podman unshare chmod 0644 $path/configs/*

    # Copy provisioning files
    echo
    echo "Copying Grafana datasource files to $path/grafana/provisioning/"
    podman unshare cp -v grafana/provisioning/datasources/datasources.yaml $path/grafana/provisioning/
    #chmod -v 0644 $path/grafana/provisioning/datasources.yaml

    # Sync dashboards and plugins
    echo
    echo "Copying Grafana dashboards and plugins to $path/grafana/dashboards/"
    podman unshare rsync -ah grafana/provisioning/dashboards/ $path/grafana/dashboards/
    echo
    echo "removing old not needed files"
    podman unshare rm -vf $path/grafana/dashboards/*.yaml
    echo
    echo "Copying Grafana provisioning files to $path/grafana/provisioning/dashboards/"
    podman unshare rsync -ah grafana/provisioning/dashboards/*.yaml $path/grafana/provisioning/dashboards/
    echo
    echo "Copying Grafana plugins to $path/grafana/"
    podman unshare rsync -ah grafana/plugins $path/grafana/

    #original files from docker
    echo
    echo "Copying vast-ca, images, tools to new location"
    podman unshare rsync -ah vast-ca $rootpath/
    #manually done by user
    #podman unshare rsync -ah images /mission-share/
    podman unshare rsync -ah tools $rootpath/
    #let nifi create this file itself
    #podman unshare touch $path/nifi/logs/nifi-app.log
    podman unshare chmod -R 777 $rootpath/tide

    #nifi directories
    echo
    echo "Copying Nifi configuration files to $path/nifi"
    podman unshare rsync -avh nifi/ $path/nifi/
    echo "Fixing permissions on Nifi directories"
    podman unshare find /mission-share/podman/containers/nifi/ -type d -exec chmod 0777 {} \;
    podman unshare find /mission-share/podman/containers/nifi/ -type f -exec chmod 0644 {} \;
    #sadly, we have to get the container subuid and chmod things due to the way the umask has been set
    grep $USER /etc/subuid|awk -F: '{ print $2 }' | awk -F- '{ print $1 }' | while read -r uid; do
        echo "Setting permissions for user $USER with UID $uid"
        run_with_sudo chmod 0777 $path/nifi/logs $path/nifi/conf $path/nifi/lib
        run_with_sudo chown -R $uid:$uid $path/nifi/logs $path/nifi/conf $path/nifi/lib
    done
    run_with_sudo chmod 0777 /mission-share/podman/containers/nifi/conf/*.zip
    run_with_sudo chmod 0777 /mission-share/podman/containers/nifi/conf/*.gz

    #gitlab direcotories
    echo
    #podman unshare mkdir -p /mission-share/podman/containers/gitlab/{logs,config,data}
    run_with_sudo chmod 0777 /mission-share/podman/containers/gitlab
    run_with_sudo chmod 0777 /mission-share/podman/containers/gitlab/{logs,config,data}
}

build_and_start_pod() {
    echo -e "\n[USER] Building and Starting Pod..."

    # Check permissions on system files
    check_permission "/usr/share/rhel/secrets/rhsm/syspurpose/syspurpose.json" "644"
    check_permission "/etc/yum.repos.d/redhat.repo" "644"
    podmanshare="/mission-share/podman"
    run_with_sudo chcon -t -R container_file_t $podmanshare
    run_with_sudo restorecon -R $podmanshare

    # Stop existing pod if running
    echo "Stopping ogs pod if running..."
    podman pod stop ogs

    #sadly, with all this customization, we have to 777 some dirs
    podman unshare chmod -v 0777 /mission-share/podman/containers/{grafana,mimir,loki,nifi,nifi/*}

    # Load versions
    . versions.txt

    # Generate and deploy pod YAML
    echo "Generating new pod YAML from template..."
    cd ogs-pod || return 1
    cat ogs-pod.yml.template | sed "s|HOMEDIR|/mission-share|g" | \
        sed "s|GRAFANA_VERSION|$GRAFANA_VERSION|g" | \
        sed "s|LOKI_VERSION|$LOKI_VERSION|g" | \
        sed "s|MIMIR_VERSION|$MIMIR_VERSION|g" | \
	sed "s|GITLAB_VERSION|$GITLAB_VERSION|g" | \
        sed "s|--UID--|$UID|g" | \
        sed "s|--GID--|$UID|g" > ogs-pod.yml

    #echo "Building pod with --replace..."
    #podman play kube --replace ogs-pod.yml

    echo "Creating Systemd files to manage pod with systemd..."
    # Create Quadlet directory
     mkdir -p ~/.config/containers/systemd
     mkdir -p ~/.config/systemd/user

    # Copy Quadlet file (ensure podman unshare if needed for permissions)
    podman unshare cp -f ogs-pod.yml /mission-share/podman/containers/ogs-pod.yml
    echo "Starting initial pod..."
    podman kube play --replace --userns=keep-id /mission-share/podman/containers/ogs-pod.yml
    echo "Generating systemd service files for podman pod ogs..."
    podman generate systemd --name --files ogs
    mv -fv *.service ~/.config/systemd/user/

    # Reload systemd to generate service
    systemctl --user daemon-reload

    #stopping pod if it exists
    echo "Stopping existing ogs pod if running..."
    podman pod stop ogs

    # Start the service with systemd
    echo "Enabling and starting pod-ogs.service..."
    systemctl --user enable --now pod-ogs.service

    sleep 3
    podman ps -a
    echo "Pod created and started successfully!"
    podman ps

    # Enable linger - was previously done in system settings, but ensure it here too
    loginctl enable-linger

    echo -e "\nAll done! You should now have a running pod with:"
    echo "- Grafana on port 3000 (admin/admin)"
    echo "- Loki on port 9009"
    echo "- Mimir on port 3100"
    echo "- Nifi on port 8443,8080,3200,9092"
    echo "- Gitlab on port 2200, 9443, 8088"
    echo "- Parent NGINX proxy on port 80 and 443"
    # change back to installer dir
    cd $OLDPWD
}

# ---------- Helper Functions ----------

check_permission() {
    local file="$1"
    local expected_perm="$2"
    local actual_perm=$(stat -c "%a" "$file" 2>/dev/null)

    if [[ "$actual_perm" != "$expected_perm" ]]; then
        echo "[FAIL] $file has permissions $actual_perm (expected $expected_perm)"
        echo "Please run the system configuration first or manually fix with:"
        echo "sudo chmod $expected_perm $file"
        return 1
    fi
    return 0
}

safe_modify() {
    local file="$1"
    local action="$2"
    local description="$3"

    echo -n "${description}... "
    if [ -f "$file" ]; then
        eval "$action"
        echo "Done."
    else
        echo "Skipped (file not found)."
    fi
}

check_success() {
    if [ $? -ne 0 ]; then
        echo "Error: $1" >&2
        return 1
    fi
}

# ---------- Menu System ----------

show_menu() {
    clear
    echo "===================================================="
    echo " Monitoring Stack Deployment Tool - Ver. $script_version"
    echo "===================================================="
    echo " Privileged Operations:"
    echo " 1. Configure System Settings"
    echo " 2. Provision Disk for Podman Data"
    echo " 3. Copy container source directories"
    echo " 4. Generate SSL Certificates"
    echo " 5. Configure NFS Server"
    echo " 6. Install and Configure Nginx Proxy"
    echo " 7. Configure Firewall"
    echo "===================================================="
    echo " Non-Privileged Operations: "
    echo " Choose based off network available "
    echo " 8i. Pull Container Images - Internet required"
    echo " 8n. Install Packaged Images - No Internet required"
    echo " 9. Build and Start Pod"
    echo ""
    echo " 10i. Run ALL Operations - Internet required"
    echo " 10n. Run ALL Operations - No Internet required"
    echo " 0. Exit"
    echo "===================================================="
}

run_all_operations() {
    echo -e "\n=== Running All Operations ==="

    # Run root operations
    echo -e "\n[Running privileged operations]"
    configure_system_settings
    provision_disk
    copy_source_directories
    generate_ssl_keys
    create_and_share_nfs
    install_nginx
    configure_firewall

    # Run user operations
    echo -e "\n[Running non-privileged operations]"
    pull_container_images
    build_and_start_pod

    echo -e "\nAll operations completed!"
}

run_all_operations_disconnected() {
    echo -e "\n=== Running All Operations ==="

    # Run root operations
    echo -e "\n[Running privileged operations]"
    configure_system_settings
    provision_disk
    copy_source_directories
    generate_ssl_keys
    create_and_share_nfs
    install_nginx
    configure_firewall

    install_tarball_images
    build_and_start_pod

    echo -e "\nAll operations completed!"
}

# ---------- Main Execution ----------

# Always get sudo password at the very start
get_sudo_password

# Interactive menu mode
while true; do
    show_menu
    read -p "Enter your choice (0-8): " choice

    case $choice in
	1) configure_system_settings ;;
	2) provision_disk ;;
        3) copy_source_directories ;;
        4) generate_ssl_keys ;;
        5) create_and_share_nfs ;;
        6) install_nginx ;;
        7) configure_firewall ;;
        8i) pull_container_images ;;
        8n) install_tarball_images ;;
        9) build_and_start_pod ;;
        10i) run_all_operations ;;
        10n) run_all_operations_disconnected ;;
        0)
            echo "Exiting. Have a nice day!"
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac

    read -p "Press [Enter] to continue..."
done
