
script_version="20260119.0"

if (( $EUID == 0 )); then
    echo "ERROR: This script must not be run as root, run as normal user that will manage the containers. 'miadmin?'" 1>&2; exit 1;
fi

if (( $EUID != 1000 )); then
    echo "ERROR: This script must only br run as the user \"admin\" or a user with UID=1000, your UID is $EUID" 1>&2; exit 1;
fi

if ! command -v rsync &> /dev/null; then
    echo "ERROR: rsync is required but not installed. Please install it first." 1>&2; exit 1;
fi

if ! command -v podman &> /dev/null; then
    echo "ERROR: podman is required but not installed. Please install it first." 1>&2; exit 1;
fi

if ! command -v git-lfs &> /dev/null; then
    echo "ERROR: git-lfs is required but not installed. Please install it first." 1>&2; exit 1;
fi

if ! command -v ip > /dev/null 2>&1; then
    echo "ERROR: 'ip' command not found. Please install iproute2."; exit 1;
fi

cleanup ()
{
    unset SUDO_PASSWORD;
    rm -f /tmp/install_config.* /tmp/install_errors_*.log;
    sudo -k
}
trap cleanup EXIT

get_sudo_password ()
{
    sudo -k;
    echo "====================================================";
    echo " Monitoring Stack Deployment Tool - Ver. $script_version";
    echo "====================================================";
    echo "INFO: This script requires root privileges for some operations.";
    while true; do
        echo "INFO: Please enter your sudo password to proceed:";
        read -r -s SUDO_PASSWORD;
        echo;
        echo -n "INFO: Verifying sudo access... ";
        if echo "$SUDO_PASSWORD" | sudo -S ls /root > /dev/null 2>&1; then
            echo "SUCCESS: Sudo access verified";
            break;
        else
            echo "ERROR: Incorrect sudo password. Please try again." 1>&2;
            unset SUDO_PASSWORD;
        fi;
    done;
    export SUDO_PASSWORD;
    echo
}

run_with_sudo ()
{
    echo -e "$SUDO_PASSWORD\n" | sudo -S "$@" 2> /dev/null
}

check_permission ()
{
    local file="$1";
    local expected_perm="$2";
    local actual_perm=$(stat -c "%a" "$file" 2>/dev/null);
    if [[ "$actual_perm" != "$expected_perm" ]]; then
        echo "ERROR: $file has permissions $actual_perm (expected $expected_perm)" 1>&2;
        echo "INFO: Please run the system configuration first or manually fix with:" 1>&2;
        echo "sudo chmod $expected_perm $file" 1>&2;
        return 1;
    fi;
    echo "SUCCESS: $file permissions verified as $expected_perm";
    return 0
}

safe_modify ()
{
    local file="$1";
    local action="$2";
    local description="$3";
    echo -n "INFO: ${description}... ";
    if [ -f "$file" ]; then
        if eval "$action"; then
            echo "SUCCESS: ${description} completed";
        else
            echo "ERROR: Failed to ${description}" 1>&2;
            return 1;
        fi;
    else
        echo "INFO: Skipped (file not found)";
    fi
}

check_success ()
{
    if [ $? -ne 0 ]; then
        echo "ERROR: $1" 1>&2;
        return 1;
    fi;
    echo "SUCCESS: $1 completed"
}

collect_user_inputs ()
{
    if [[ "$TERM" == "dumb" || -z "$TERM" ]]; then
        echo "Error: Incompatible terminal type ($TERM). Setting TERM=xterm.";
        export TERM=xterm;
    fi;
    read -r rows cols < <(stty size);
    if [[ $rows -lt 10 || $cols -lt 60 ]]; then
        echo "Warning: Terminal size ($rows x $cols) is too small. Setting to 24x80.";
        stty rows 24 cols 80;
    fi;
    DEFAULT_OGS_DOMAIN_NAME='ogs18.ogs.mi.ds.army.smil.mil';
    DEFAULT_LDAP_SERVER="192.168.10.200";
    DEFAULT_LDAP_SEARCH_BASE="OU=Users,OU=ogs,DC=ogs18,DC=mi,DC=ds,DC=army,DC=smil,DC=mil";
    DEFAULT_LISTEN_IP_ADDRESS="0.0.0.0";
    DEFAULT_HOST_IP_ADDRESS=$(ip route get 1 | awk '{print $7; exit}');
    DEFAULT_LDAP_BIND_USER="forward.sa@$DEFAULT_OGS_DOMAIN_NAME";
    DEFAULT_LDAP_BIND_PASSWORD_VALUE="changeme";
    DEFAULT_GRAFANA_DOMAIN_FQDN="grafana.$DEFAULT_OGS_DOMAIN_NAME";
    DEFAULT_GRAFANA_ADMIN_USERNAME="admin";
    DEFAULT_GRAFANA_ADMIN_PW="changeme";
    VARS_FILE="variables.conf";
    if [ -f "$VARS_FILE" ]; then
        if ! source "$VARS_FILE" 2>> "$ERROR_LOG"; then
            echo "Variables config file found" > /dev/null;
        fi;
    else
        echo "Variables config NOT file found" > /dev/null;
    fi;
    while true; do
        CONFIG_FILE=$(mktemp /tmp/install_config.XXXXXX);
        ERROR_LOG="/tmp/install_errors_$(date +%s).log";
        cat > "$CONFIG_FILE" <<EOF
# Edit the values below for your installation.
# Lines starting with # are comments and ignored.
# Do not add spaces around = signs or remove single quotes.
# Keep values in single quotes to handle special characters.
# Example: LDAP_BIND_PASSWORD_VALUE='0o9i8u7y)O(I*U&Y'
# Save with (escape + :wq or cancel with escape + :q!) in vi.

#general-settings
OGS_DOMAIN_NAME='${OGS_DOMAIN_NAME:-$DEFAULT_OGS_DOMAIN_NAME}'
# NOTE! use the ip, not the dns name for the ldap server,
# some containers run into issues resolving dns
LDAP_SERVER='${LDAP_SERVER:-$DEFAULT_LDAP_SERVER}'
LDAP_SEARCH_BASE='${LDAP_SEARCH_BASE:-$DEFAULT_LDAP_SEARCH_BASE}'
#use 0.0.0.0 for all addresses
LISTEN_IP_ADDRESS='${LISTEN_IP_ADDRESS:-$DEFAULT_LISTEN_IP_ADDRESS}'
HOST_IP_ADDRESS='${HOST_IP_ADDRESS:-$DEFAULT_HOST_IP_ADDRESS}'
#should be a service account, that cannot change anything, likely forward.sa@$DEFAULT_OGS_DOMAIN_NAME
LDAP_BIND_USER_VALUE='${LDAP_BIND_USER_VALUE:-$DEFAULT_LDAP_BIND_USER}'
LDAP_BIND_PASSWORD_VALUE='${LDAP_BIND_PASSWORD_VALUE:-$DEFAULT_LDAP_BIND_PASSWORD_VALUE}'

#Grafana-specific - if ldap is down, local master admin account
GRAFANA_DOMAIN_FQDN='${GRAFANA_DOMAIN_FQDN:-$DEFAULT_GRAFANA_DOMAIN_FQDN}'
GRAFANA_ADMIN_USERNAME='${GRAFANA_ADMIN_USERNAME:-$DEFAULT_GRAFANA_ADMIN_USERNAME}'
GRAFANA_ADMIN_PW='${GRAFANA_ADMIN_PW:-$DEFAULT_GRAFANA_ADMIN_PW}'

EOF

        EDITOR="vi";
        if ! command -v "$EDITOR" > /dev/null 2>&1; then
            echo "Error: No text editor (vi) found." | tee -a "$ERROR_LOG";
            exit 1;
        fi;
        if ! $EDITOR "$CONFIG_FILE" 2>> "$ERROR_LOG"; then
            echo "Editor exited abnormally. Check $ERROR_LOG for details." | tee -a "$ERROR_LOG";
            whiptail --title "Confirm Exit" --yesno "Do you want to cancel and exit the installer?" 10 60 2>> "$ERROR_LOG" || {
                echo "Input cancelled by user.";
                rm -f "$CONFIG_FILE";
                exit 1
            };
            rm -f "$CONFIG_FILE";
            continue;
        fi;
        echo "Raw configuration file contents:" >> "$ERROR_LOG";
        cat "$CONFIG_FILE" >> "$ERROR_LOG";
        echo "------------------------" >> "$ERROR_LOG";
        grep -v '^#' "$CONFIG_FILE" | grep -v '^$' > "${CONFIG_FILE}.clean";
        if ! source "${CONFIG_FILE}.clean" 2>> "$ERROR_LOG"; then
            echo "Error: Failed to source configuration file. Check syntax in $CONFIG_FILE." | tee -a "$ERROR_LOG";
            whiptail --msgbox "Error: Invalid configuration file syntax. Ensure each line has KEY='VALUE' format with no spaces around = and values in single quotes (e.g., '0o9i&Y')." 10 60 2>> "$ERROR_LOG";
            rm -f "$CONFIG_FILE" "${CONFIG_FILE}.clean";
            continue;
        fi;
        SUMMARY="Please review the entered values:\n\n";
        SUMMARY+="#General-Settings\n";
        SUMMARY+="OGS_DOMAIN_NAME: $OGS_DOMAIN_NAME\n";
        SUMMARY+="LDAP_SERVER: $LDAP_SERVER\n";
        SUMMARY+="LDAP_SEARCH_BASE: $LDAP_SEARCH_BASE\n";
        SUMMARY+="#use 0.0.0.0 for all addresses\n";
        SUMMARY+="LISTEN_IP_ADDRESS: $LISTEN_IP_ADDRESS\n\n";
        SUMMARY+="HOST_IP_ADDRESS: $HOST_IP_ADDRESS\n";
        SUMMARY+="LDAP_BIND_USER_VALUE: $LDAP_BIND_USER_VALUE\n";
        SUMMARY+="LDAP_BIND_PASSWORD_VALUE: $LDAP_BIND_PASSWORD_VALUE\n";
        SUMMARY+="\n";
        SUMMARY+="Grafana-specific  - if ldap is down, local master admin account\n";
        SUMMARY+="GRAFANA_DOMAIN_FQDN: $GRAFANA_DOMAIN_FQDN\n";
        SUMMARY+="GRAFANA_ADMIN_USERNAME: $GRAFANA_ADMIN_USERNAME\n";
        SUMMARY+="GRAFANA_ADMIN_PW: $GRAFANA_ADMIN_PW\n";
        SUMMARY+="\n";
        SUMMARY+="Does this look correct?";
        if ! whiptail --title "Confirm Values" --yesno "$SUMMARY" 40 80 2>> "$ERROR_LOG"; then
            echo "User rejected values, returning to editor." >> "$ERROR_LOG";
            continue;
        fi;
        cat > "$VARS_FILE" <<EOF
# Edit the values below for your installation.
# Lines starting with # are comments and ignored.
# Do not add spaces around = signs or remove single quotes.
# Keep values in single quotes to handle special characters.
# Example: LDAP_BIND_PASSWORD_VALUE='0o9i8u7y)O(I*U&Y'
# Save with (escape + :wq or cancel with escape + :q!) in vi.

#general-settings
OGS_DOMAIN_NAME='$OGS_DOMAIN_NAME'
# NOTE! use the ip, not the dns name for the ldap server,
# some containers run into issues resolving dns
LDAP_SERVER='$LDAP_SERVER'
LDAP_SEARCH_BASE='$LDAP_SEARCH_BASE'
#use 0.0.0.0 for all addresses
LISTEN_IP_ADDRESS='$LISTEN_IP_ADDRESS'
HOST_IP_ADDRESS='$HOST_IP_ADDRESS'
LDAP_BIND_USER_VALUE='$LDAP_BIND_USER_VALUE'
LDAP_BIND_PASSWORD_VALUE='$LDAP_BIND_PASSWORD_VALUE'

#Grafana-specific  - if ldap is down, local master admin account
GRAFANA_DOMAIN_FQDN='$GRAFANA_DOMAIN_FQDN'
GRAFANA_ADMIN_USERNAME='$GRAFANA_ADMIN_USERNAME'
GRAFANA_ADMIN_PW='$GRAFANA_ADMIN_PW'

EOF

        echo "Saved values to $VARS_FILE" >> "$ERROR_LOG";
        export OGS_DOMAIN_NAME;
        export LDAP_SERVER;
        export LDAP_SEARCH_BASE;
        export LISTEN_IP_ADDRESS;
        export HOST_IP_ADDRESS;
        export LDAP_BIND_USER_VALUE;
        export LDAP_BIND_PASSWORD_VALUE;
        export GRAFANA_DOMAIN_FQDN;
        export GRAFANA_ADMIN_USERNAME;
        export GRAFANA_ADMIN_PW;
        break;
    done
}

rename_ssl ()
{
    local fqdn="$1";
    local dir="${2:-.}";
    if [[ -z "$fqdn" ]]; then
        echo "ERROR: fqdn must be provided" 1>&2;
        return 1;
    fi;
    if [[ ! -d "$dir" ]]; then
        echo "ERROR: Directory '$dir' does not exist" 1>&2;
        return 1;
    fi;
    dir="${dir%/}";
    local files_found=false;
    local escaped_fqdn;
    escaped_fqdn=$(echo "$fqdn" | sed 's/\./\\./g');
    echo "INFO: Renaming SSL files for '$fqdn' in '$dir'";
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            local ext="${file##*.}";
            mv "$file" "$dir/ssl.$ext";
            echo "SUCCESS: Renamed $file to ssl.$ext";
            files_found=true;
        fi;
    done < <(find "$dir" -maxdepth 1 -type f -name "$escaped_fqdn.*");
    if [[ "$files_found" == false ]]; then
        echo "WARNING: No files matching '$fqdn.*' were found in '$dir'";
        echo "INFO: Debug: Directory contents:";
        ls -l "$dir";
        return 1;
    fi;
    echo "SUCCESS: SSL file renaming completed"
}

rename_ssl_grafana ()
{
    local fqdn="$1";
    local dir="${2:-.}";
    if [[ -z "$fqdn" ]]; then
        echo "ERROR: fqdn must be provided" 1>&2;
        return 1;
    fi;
    if [[ ! -d "$dir" ]]; then
        echo "ERROR: Directory '$dir' does not exist" 1>&2;
        return 1;
    fi;
    dir="${dir%/}";
    local files_found=false;
    local escaped_fqdn;
    escaped_fqdn=$(echo "$fqdn" | sed 's/\./\\./g');
    echo "INFO: Renaming SSL files for '$fqdn' in '$dir'";
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            local ext="${file##*.}";
            mv "$file" "$dir/ssl.grafana.$ext";
            echo "SUCCESS: Renamed $file to ssl.grafana.$ext";
            files_found=true;
        fi;
    done < <(find "$dir" -maxdepth 1 -type f -name "$escaped_fqdn.*");
    if [[ "$files_found" == false ]]; then
        echo "WARNING: No files matching '$fqdn.*' were found in '$dir'";
        echo "INFO: Debug: Directory contents:";
        ls -l "$dir";
        return 1;
    fi;
    echo "SUCCESS: SSL file renaming completed"
}

generate_ssl_keys ()
{
    cd /mission-share/vast-ca/;
    echo "INFO: Creating SSL certificates";
    msnsvr_ip=$HOST_IP_ADDRESS;
    msnsvr_fqdn=$GRAFANA_DOMAIN_FQDN;
    grafana_fqdn=$GRAFANA_DOMAIN_FQDN;
    domain=$OGS_DOMAIN_NAME;
    echo "DOMAIN=$domain" > /mission-share/podman/containers/keys/DOMAIN;
    mkdir -p /mission-share/.tmp 2> /dev/null;
    local temp_file=$(mktemp);
    echo "$msnsvr_ip $msnsvr_fqdn $grafana_fqdn grafana loki mimir addedbyscript" > "$temp_file";
    echo "INFO: Updating /etc/hosts with msnsvr details";
    if [ `grep -c addedbyscript /etc/hosts` -gt 0 ]; then
        echo "$SUDO_PASSWORD" | sudo -S sh -c "sed -i '/addedbyscript/d' /etc/hosts" 2> /dev/null;
        if echo "$SUDO_PASSWORD" | sudo -S sh -c "cat '$temp_file' >> /etc/hosts" 2> /dev/null; then
            echo "SUCCESS: Updated /etc/hosts";
        else
            echo "ERROR: Failed to update /etc/hosts" 1>&2;
            rm -f "$temp_file";
            return 1;
        fi;
    else
        if echo "$SUDO_PASSWORD" | sudo -S sh -c "cat '$temp_file' >> /etc/hosts" 2> /dev/null; then
            echo "SUCCESS: Updated /etc/hosts";
        else
            echo "ERROR: Failed to update /etc/hosts" 1>&2;
            rm -f "$temp_file";
            return 1;
        fi;
    fi;
    rm -f "$temp_file";
    read -p "Press [Enter] to continue...";
    clear;
    echo "INFO: Creating Grafana certificates";
    podman unshare chmod 0755 *.sh;
    printf "$GRAFANA_DOMAIN_FQDN\nmsnsvr.$OGS_DOMAIN_NAME\n$HOST_IP_ADDRESS\n\nUS\nMaryland\nAPG\nFII\n3650\nsilkwave\n" | ./server-cert-gen.sh /mission-share/podman/containers/keys/grafana/;
    if rename_ssl "$GRAFANA_DOMAIN_FQDN" "/mission-share/podman/containers/keys/grafana/"; then
        podman unshare chmod 0644 /mission-share/podman/containers/keys/grafana/ssl.*;
        echo "SUCCESS: Grafana certificates created and renamed";
    else
        echo "ERROR: Failed to create or rename Grafana certificates" 1>&2;
        return 1;
    fi;
    read -p "Press [Enter] to continue...";
    clear;
    echo "INFO: Creating Loki certificates";
    printf "loki.$OGS_DOMAIN_NAME\n$HOST_IP_ADDRESS\n\nUS\nMaryland\nAPG\nFII\n3650\nsilkwave\n" | ./server-cert-gen.sh /mission-share/podman/containers/keys/loki/;
    if rename_ssl "loki.$OGS_DOMAIN_NAME" "/mission-share/podman/containers/keys/loki/"; then
        podman unshare chmod 0644 /mission-share/podman/containers/keys/loki/ssl.*;
        echo "SUCCESS: Loki certificates created and renamed";
    else
        echo "ERROR: Failed to create or rename Loki certificates" 1>&2;
        return 1;
    fi;
    read -p "Press [Enter] to continue...";
    clear;
    echo "INFO: Creating Mimir certificates";
    printf "mimir.$OGS_DOMAIN_NAME\n$HOST_IP_ADDRESS\n\nUS\nMaryland\nAPG\nFII\n3650\nsilkwave\n" | ./server-cert-gen.sh /mission-share/podman/containers/keys/mimir/;
    if rename_ssl "mimir.$OGS_DOMAIN_NAME" "/mission-share/podman/containers/keys/mimir/"; then
        podman unshare chmod 0644 /mission-share/podman/containers/keys/mimir/ssl.*;
        echo "SUCCESS: Mimir certificates created and renamed";
    else
        echo "ERROR: Failed to create or rename Mimir certificates" 1>&2;
        return 1;
    fi;
    read -p "Press [Enter] to continue...";
    clear;
    echo "INFO: Creating NGINX proxy certificates";
    printf "$GRAFANA_DOMAIN_FQDN\n$OGS_DOMAIN_NAME\n$HOST_IP_ADDRESS\n\nUS\nMaryland\nAPG\nFII\n3650\nsilkwave\n" | ./server-cert-gen.sh /mission-share/podman/containers/keys/nginx/;
    if rename_ssl "$GRAFANA_DOMAIN_FQDN" "/mission-share/podman/containers/keys/nginx/"; then
        echo "INFO: Copying NGINX certificates to /etc/pki/tls";
        if run_with_sudo cp -v /mission-share/podman/containers/keys/nginx/ssl.* /etc/pki/tls/; then
            echo "SUCCESS: NGINX certificates copied to /etc/pki/tls";
        else
            echo "ERROR: Failed to copy NGINX certificates to /etc/pki/tls" 1>&2;
            return 1;
        fi;
    fi;
    read -p "Press [Enter] to continue...";
    clear;
    cd $OLDPWD;
    echo "INFO: Copying DOD CA  certificates to /etc/pki/ca-trust/extracted/pem";
    if run_with_sudo cp -v DOD_certs/DOD_CAs.pem /etc/pki/ca-trust/extracted/pem/; then
        echo "SUCCESS: DOD CA certificates copied to /etc/pki/ca-trust/extracted/pem/";
    else
        echo "ERROR: Failed to copy DOD CA certificates to /etc/pki/ca-trust/extracted/pem/" 1>&2;
        return 1;
    fi;
    echo "INFO: Fixing SELinux context on NGINX keys";
    run_with_sudo semanage fcontext -a -t cert_t "/etc/pki/tls/ssl.crt";
    run_with_sudo semanage fcontext -a -t cert_t "/etc/pki/tls/ssl.key";
    run_with_sudo semanage fcontext -a -t cert_t "/etc/pki/tls/ssl.zfts.crt";
    run_with_sudo semanage fcontext -a -t cert_t "/etc/pki/tls/ssl.zfts.key";
    run_with_sudo semanage fcontext -a -t cert_t "/etc/pki/ca-trust/extracted/pem/DOD_CAs.pem";
    run_with_sudo restorecon -v -F "/etc/pki/tls/ssl.crt";
    run_with_sudo restorecon -v -F "/etc/pki/tls/ssl.key";
    run_with_sudo restorecon -v -F "/etc/pki/tls/ssl.zfts.crt";
    run_with_sudo restorecon -v -F "/etc/pki/tls/ssl.zfts.key";
    run_with_sudo restorecon -v -F "/etc/pki/ca-trust/extracted/pem/DOD_CAs.pem";
    run_with_sudo chmod 0444 "/etc/pki/ca-trust/extracted/pem/DOD_CAs.pem";
    echo "SUCCESS: SELinux context fixed for NGINX keys";
    echo "SUCCESS: SSL certificate generation completed"
}

append_to_fstab ()
{
    local fstab_line="$1";
    if run_with_sudo grep -q "/mission-share" /etc/fstab; then
        echo "WARNING: /mission-share already exists in /etc/fstab. Please check manually.";
    else
        local temp_file=$(mktemp);
        echo "$fstab_line" > "$temp_file";
        echo "INFO: Appending to /etc/fstab";
        if echo "$SUDO_PASSWORD" | sudo -S sh -c "cat '$temp_file' >> /etc/fstab" 2> /dev/null; then
            echo "SUCCESS: Appended to /etc/fstab";
            echo "INFO: Reloading systemctl";
            if run_with_sudo systemctl daemon-reload; then
                echo "SUCCESS: Systemctl reloaded";
            else
                echo "ERROR: Failed to reload systemctl" 1>&2;
                return 1;
            fi;
        else
            echo "ERROR: Failed to append to /etc/fstab" 1>&2;
            rm -f "$temp_file";
            return 1;
        fi;
        rm -f "$temp_file";
        echo "INFO: Verifying fstab syntax";
        if run_with_sudo mount -a > /dev/null 2>&1; then
            echo "SUCCESS: fstab syntax is valid";
        else
            echo "ERROR: Invalid fstab entry detected. Restoring backup" 1>&2;
            if run_with_sudo cp /etc/fstab.bak /etc/fstab 2> /dev/null; then
                echo "SUCCESS: Restored /etc/fstab from backup";
            else
                echo "ERROR: Failed to restore /etc/fstab from backup" 1>&2;
                return 1;
            fi;
            return 1;
        fi;
    fi
}

replace_auditd_rules ()
{
    echo "";
    echo "=== Replace auditd Rules ===";
    echo "";
    echo "Stopping auditd...";
    run_with_sudo systemctl stop auditd 2>&1 > /dev/null;
    echo "Deleting old rule files...";
    run_with_sudo rm -f /etc/audit/rules.d/*.rules;
    echo "Installing new rule files...";
    if [[ -d "./rules.d" ]]; then
        run_with_sudo cp -f ./rules.d/*.rules /etc/audit/rules.d/;
    else
        echo "WARNING: ./rules.d directory not found; no new rules copied.";
        read -p "Press [Enter] to continue...";
    fi;
    echo "INFO: emptying audit rule file is present  /etc/audit/rules.d/99-podman-load.rules";
    if [ -e /etc/audit/rules.d/99-podman-load.rules ]; then
        if run_with_sudo truncate -s 0 /etc/audit/rules.d/99-podman-load.rules; then
            echo "SUCCESS: emptied /etc/audit/rules.d/99-podman-load.rules";
        else
            echo "ERROR: unable to empty /etc/audit/rules.d/99-podman-load.rules";
            return 1;
        fi;
    else
        echo "INFO: /etc/audit/rules.d/99-podman-load.rules not present, skipping";
    fi;
    run_with_sudo find /etc/audit/rules.d/ -type f -name "*.rules" -exec chmod 0600 {} \;;
    echo "Restarting auditd...";
    run_with_sudo systemctl start auditd;
    echo "";
    echo "=== Replace auditd Rules ===";
    echo "SUCCESS: Auditd rules replaced.";
    echo "=== Be advised, a system restart will be required to load new rules due to immutable settings ===";
    read -rp "Press [Enter] to acknowledge and continue...";
    echo ""
}

configure_system_settings ()
{
    echo "INFO: Configuring system settings";
    safe_modify "/etc/sysctl.d/99-sysctl.conf" "run_with_sudo sed -i 's/^user\.max_user_namespaces=0/user.max_user_namespaces=9999/' /etc/sysctl.d/99-sysctl.conf" "Modifying user.max_user_namespaces setting";
    safe_modify "/usr/share/rhel/secrets/rhsm/syspurpose/syspurpose.json" "run_with_sudo chmod 0644 /usr/share/rhel/secrets/rhsm/syspurpose/syspurpose.json" "Setting permissions for syspurpose.json";
    safe_modify "/etc/yum.repos.d/redhat.repo" "run_with_sudo chmod 0644 /etc/yum.repos.d/redhat.repo" "Setting permissions for redhat.repo";
    echo "INFO: Checking permissions on system files";
    if check_permission "/usr/share/rhel/secrets/rhsm/syspurpose/syspurpose.json" "644" && check_permission "/etc/yum.repos.d/redhat.repo" "644"; then
        echo "SUCCESS: System file permissions verified";
    else
        echo "ERROR: System file permission checks failed" 1>&2;
        return 1;
    fi;
    echo "INFO: Applying sysctl changes";
    if run_with_sudo sysctl -p /etc/sysctl.d/99-sysctl.conf | grep -q 'user.max_user_namespaces = 9999'; then
        echo "SUCCESS: Sysctl changes applied";
    else
        echo "ERROR: Failed to apply sysctl changes" 1>&2;
        return 1;
    fi;
    echo "INFO: Verifying sysctl settings";
    run_with_sudo sysctl -a | grep user.max_user_namespaces;
    echo "SUCCESS: Sysctl settings verified";
    echo "INFO: Setting podman image location";
    mkdir -p ~/.config/containers 2> /dev/null;
    if cat configs/storage.conf > ~/.config/containers/storage.conf; then
        echo "SUCCESS: Overwrote ~/.config/containers/storage.conf";
    else
        echo "ERROR: Failed to overwrite ~/.config/containers/storage.conf" 1>&2;
        return 1;
    fi;
    echo "INFO: Enabling linger for user $USER";
    if loginctl enable-linger; then
        echo "SUCCESS: Linger enabled for user $USER";
    else
        echo "ERROR: Failed to enable linger for user $USER" 1>&2;
        return 1;
    fi;
    replace_auditd_rules;
    echo "INFO: Finding 0777 shared object and static library files and fixing permissions";
    if run_with_sudo find / -type f -perm 0777 \( -name "*.so" -o -name "*.a" \) -exec chmod 0644 {} \;; then
        echo "SUCCESS: Fixed permissions on shared object and static library files";
    else
        echo "ERROR: Failed to fix permissions on some shared object or static library files";
        return 1;
    fi;
    echo -e "\nINFO: V-272496: fixing sudoers";
    run_with_sudo cp -fv configs/sudoers.d.v-272496 /etc/sudoers.d/v-272496;
    echo -e "\nINFO: V-257965: fixing net.ipv4.conf.default.rp_filter = 1";
    echo -e "$SUDO_PASSWORD" | sudo -S sh -c "sed -i 's/^net\.ipv4\.conf\.default\.rp_filter *= *2/net.ipv4.conf.default.rp_filter = 1/' /usr/lib/sysctl.d/50-default.conf" 2> /dev/null;
    echo -e "\nINFO: V-257830 Disabling epel repo";
    run_with_sudo dnf config-manager --set-disabled epel;
    echo -e "\nINFO: V-257830 Disabling epel-cisco-openh264 repo";
    run_with_sudo dnf config-manager --set-disabled epel-cisco-openh264;
    echo -e "\nINFO: V-257811: limit scope of ptrace to child processes";
    echo -e "$SUDO_PASSWORD" | sudo -S sh -c "sed -i 's/^kernel\.yama\.ptrace_scope *= *0/kernel.yama.ptrace_scope = 1/' /usr/lib/sysctl.d/10-default-yama-scope.conf" 2> /dev/null;
    echo -e "\nINFO: V-257803: Disable coredumps";
    echo -e "$SUDO_PASSWORD" | sudo -S sh -c "sed -i 's|^kernel\.core_pattern=.*|kernel.core_pattern=\|/bin/false|' /usr/lib/sysctl.d/50-coredump.conf" 2> /dev/null;
    echo -e "\nINFO: adding group named container-admins";
    run_with_sudo groupadd container-admins;
    echo -e "\nINFO: applying group ownership and perms to /usr/bin/podman";
    run_with_sudo chown -v root:container-admins /usr/bin/podman;
    run_with_sudo chmod -v 750 /usr/bin/podman;
    echo -e "\nINFO: applying facl to /usr/bin/podman";
    run_with_sudo setfacl -m g:$(id -gn):rx /usr/bin/podman;
    echo -e "\nINFO: adding root, admin, miadmin to group container-admins";
    run_with_sudo usermod -aG container-admins miadmin;
    run_with_sudo usermod -aG container-admins admin;
    run_with_sudo usermod -aG container-admins root;
    echo -e "\nINFO: V-270875 (container runtime stigs): place limits on containers";
    run_with_sudo cp -fv configs/containers.conf /etc/containers/;
    echo -e "\nINFO: V-233192 (container runtime stigs): limit registries";
    run_with_sudo cp -fv configs/registries.conf /etc/containers/registries.conf;
    echo -e "\nINFO: Fixing permissions on container config files";
    run_with_sudo chown root:root /etc/containers/*.conf;
    run_with_sudo chmod 0644 /etc/containers/*.conf;
    USER_TO_CHECK="${SUDO_USER:-$USER}";
    TARGET_GROUP="container-admins";
    TARGET_GID=$(getent group "$TARGET_GROUP" | awk -F: '{print $3}');
    ACTIVE_GIDS=$(grep "^Groups" /proc/self/status | awk '{for(i=2;i<=NF;i++)print $i}');
    if ! grep -q -w "$TARGET_GID" <<< "$ACTIVE_GIDS"; then
        echo;
        echo "==============================================================";
        echo "⚠️  NOTICE: Your account ($USER_TO_CHECK) was added to '$TARGET_GROUP'.";
        echo "However, your *current session* does not have this group active yet.";
        echo "You must log out and log back in for changes to take effect.";
        echo "==============================================================";
        echo;
        read -rp "Press [Enter] to acknowledge and log out of this session...";
        if [[ -n "$SSH_CONNECTION" ]]; then
            echo "INFO: Closing SSH session...";
            SSHD_PID=$(ps -o ppid= -p $$ | tr -d ' ');
            if [[ -n "$SSHD_PID" ]]; then
                kill -TERM "$SSHD_PID" 2> /dev/null;
                sleep 2;
                kill -KILL "$SSHD_PID" 2> /dev/null;
            else
                CUR_TTY=$(tty | sed 's#/dev/##');
                ps -t "$CUR_TTY" -o pid=,comm= 2> /dev/null | awk '/sshd/ {print $1}' | xargs -r kill -KILL 2> /dev/null;
            fi;
        else
            echo "INFO: Closing local terminal session...";
            CUR_TTY=$(who am i 2>/dev/null | awk '{print $2}');
            if [[ -n "$CUR_TTY" ]]; then
                pkill -KILL -t "$CUR_TTY" 2> /dev/null;
            else
                logout;
            fi;
        fi;
    else
        echo -e "\nINFO: '$USER_TO_CHECK' session already includes $TARGET_GROUP group.";
    fi;
    echo -e "\nSUCCESS: System settings configured"
}

provision_disk ()
{
    echo "INFO: Disk provisioning";
    list_available_disks ()
    {
        local disks=($(run_with_sudo lsblk -d -n -o NAME | grep -v sr));
        if [ ${#disks[@]} -eq 0 ]; then
            echo "ERROR: No disks detected in system" 1>&2;
            return 1;
        fi;
        local available_disks=();
        for disk in "${disks[@]}";
        do
            disk_path="/dev/$disk";
            if ! run_with_sudo blkid -o device | grep -q "$disk_path" && [ $(run_with_sudo lsblk -n -o TYPE "$disk_path" | grep -c part) -eq 0 ]; then
                available_disks+=("$disk_path");
            fi;
        done;
        if [ ${#available_disks[@]} -eq 0 ]; then
            echo "ERROR: No eligible disks found (must be unmounted with no filesystem/partitions)" 1>&2;
            return 1;
        fi;
        echo "INFO: Available disks:";
        for i in "${!available_disks[@]}";
        do
            size=$(run_with_sudo lsblk -n -o SIZE "${available_disks[$i]}");
            echo "INFO: $((i+1)). ${available_disks[$i]} (${size})";
        done;
        AVAILABLE_DISKS=("${available_disks[@]}");
        export AVAILABLE_DISKS;
        return 0
    };
    while true; do
        read -p "INFO: Have you added a virtual disk for podman data? (yes/no) " response;
        case $response in
            [yY] | [yY][eE][sS])
                if ! list_available_disks; then
                    echo "ERROR: No suitable disks found. Please add a disk and try again" 1>&2;
                    return 1;
                fi;
                while true; do
                    read -p "INFO: Select disk number (1-${#AVAILABLE_DISKS[@]}): " disk_num;
                    if [[ "$disk_num" =~ ^[0-9]+$ ]] && [ "$disk_num" -ge 1 ] && [ "$disk_num" -le ${#AVAILABLE_DISKS[@]} ]; then
                        selected_disk="${AVAILABLE_DISKS[$((disk_num-1))]}";
                        break;
                    else
                        echo "ERROR: Invalid selection. Please enter a number between 1 and ${#AVAILABLE_DISKS[@]}" 1>&2;
                    fi;
                done;
                echo "INFO: You selected: $selected_disk";
                read -p "INFO: Confirm format with XFS and mount to /mission-share? (yes/no) " confirm;
                if [[ "$confirm" =~ [yY]|[yY][eE][sS] ]]; then
                    echo "INFO: Creating XFS filesystem on $selected_disk";
                    if run_with_sudo mkfs.xfs -f "$selected_disk"; then
                        echo "SUCCESS: Created XFS filesystem on $selected_disk";
                    else
                        echo "ERROR: Failed to create XFS filesystem on $selected_disk" 1>&2;
                        return 1;
                    fi;
                    echo "INFO: Triggering device rescan to force UUID";
                    run_with_sudo udevadm trigger;
                    sleep 2;
                    echo "INFO: Creating mount point /mission-share";
                    run_with_sudo mkdir -p /mission-share;
                    run_with_sudo chmod 0777 /mission-share;
                    echo "INFO: Mounting $selected_disk to /mission-share";
                    if run_with_sudo mount "$selected_disk" /mission-share; then
                        echo "SUCCESS: Mounted $selected_disk to /mission-share";
                    else
                        echo "ERROR: Failed to mount $selected_disk to /mission-share" 1>&2;
                        return 1;
                    fi;
                    run_with_sudo chmod 0777 /mission-share;
                    echo "INFO: Setting SELinux context for /mission-share";
                    run_with_sudo semanage fcontext -a -t container_file_t "/mission-share(/.*)?";
                    run_with_sudo restorecon -Rv /mission-share;
                    echo "SUCCESS: SELinux context set for /mission-share";
                    echo "INFO: Creating upload directory";
                    mkdir -p /mission-share/upload;
                    chmod 0777 /mission-share/upload;
                    echo "SUCCESS: Upload directory created";
                    echo "INFO: Initializing podman storage directories";
                    podman info > /dev/null;
                    podman unshare mkdir -p /mission-share/podman/containers;
                    echo "SUCCESS: Podman storage directories initialized";
                    echo "INFO: Adding $selected_disk to /etc/fstab";
                    uuid=$(run_with_sudo blkid -s UUID -o value "$selected_disk");
                    echo "INFO: UUID found is $uuid";
                    if [ -z "$uuid" ]; then
                        echo "ERROR: Could not get UUID of $selected_disk" 1>&2;
                        return 1;
                    fi;
                    fstab_line="UUID=$uuid /mission-share xfs defaults 0 0";
                    echo "INFO: fstab entry: $fstab_line";
                    if run_with_sudo grep -q "/mission-share" /etc/fstab; then
                        echo "WARNING: /mission-share already exists in /etc/fstab. Please check manually.";
                    else
                        run_with_sudo cp /etc/fstab /etc/fstab.bak;
                        echo "SUCCESS: Backed up /etc/fstab";
                        append_to_fstab "$fstab_line";
                    fi;
                    echo "SUCCESS: Disk provisioning completed";
                    return 0;
                else
                    echo "INFO: Operation cancelled";
                    return 0;
                fi
            ;;
            [nN] | [nN][oO])
                echo "INFO: Skipping disk provisioning";
                return 0
            ;;
            *)
                echo "ERROR: Please answer yes or no" 1>&2
            ;;
        esac;
    done
}

install_nginx ()
{
    echo "INFO: Installing and configuring Nginx";
    if ! command -v nginx &> /dev/null; then
        echo "INFO: Installing nginx";
        if run_with_sudo dnf install nginx -y; then
            echo "SUCCESS: Nginx installed";
        else
            echo "ERROR: Failed to install nginx" 1>&2;
            return 1;
        fi;
    else
        echo "INFO: Nginx is already installed";
    fi;
    config_source="configs/nginx.conf";
    config_dest="/etc/nginx/nginx.conf";
    if [ ! -f "$config_source" ]; then
        echo "ERROR: Source config file $config_source not found" 1>&2;
        return 1;
    fi;
    echo "substituting domain value in nginx template file";
    if cat configs/nginx.conf.template | sed "s|grafana.DOMAIN|$GRAFANA_DOMAIN_FQDN|g" | sed "s|IP_ADDRESS|$HOST_IP_ADDRESS|g" > configs/nginx.conf; then
        echo "SUCCESS: Generated nginx.conf";
    else
        echo "ERROR: Failed to create nginx.conf file" 1>&2;
        return 1;
    fi;
    echo "INFO: Copying Nginx configuration";
    if run_with_sudo cp -vf "$config_source" "$config_dest" && run_with_sudo chmod -v 0644 "/etc/nginx/nginx.conf" && run_with_sudo mkdir -vp /usr/share/nginx/html/rpms && run_with_sudo chmod -v 0755 /usr/share/nginx/html/rpms && run_with_sudo cp -vf alloy_installers/alloy-1.7.5-1.amd64.rpm /usr/share/nginx/html/rpms/ && run_with_sudo chmod -v 0644 /usr/share/nginx/html/rpms/alloy-1.7.5-1.amd64.rpm && run_with_sudo cp -vf alloy_installers/alloy-installer-windows-amd64.exe.zip /usr/share/nginx/html/rpms/ && run_with_sudo chmod -v 0644 /usr/share/nginx/html/rpms/alloy-installer-windows-amd64.exe.zip; then
        echo "SUCCESS: Nginx configuration and files copied";
    else
        echo "ERROR: Failed to copy Nginx configuration or files" 1>&2;
        return 1;
    fi;
    run_with_sudo chmod -v 644 "$config_dest";
    echo "SUCCESS: Nginx configuration permissions set";
    configure_selinux;
    echo "INFO: Enabling and starting Nginx service";
    if run_with_sudo systemctl enable nginx && run_with_sudo systemctl restart nginx; then
        echo "SUCCESS: Nginx service enabled and started";
    else
        echo "ERROR: Failed to enable or start Nginx service" 1>&2;
        return 1;
    fi;
    echo "SUCCESS: Nginx configuration completed"
}



configure_selinux ()
{
    if command -v getenforce &> /dev/null && [ "$(getenforce)" = "Enforcing" ]; then
        echo "INFO: Configuring SELinux for Nginx proxy";
        if run_with_sudo setsebool -P httpd_can_network_connect 1; then
            echo "SUCCESS: SELinux boolean set";
        else
            echo "ERROR: Failed to set SELinux boolean" 1>&2;
            return 1;
        fi;
        for port in 3000 3100 8088 9009;
        do
            if ! run_with_sudo semanage port -l | grep -q "http_port_t.*tcp.*${port}"; then
                echo "INFO: Adding SELinux exception for port $port";
                if run_with_sudo semanage port -a -t http_port_t -p tcp ${port} 2> /dev/null; then
                    echo "SUCCESS: SELinux port $port added";
                else
                    echo "WARNING: Failed to add SELinux port $port. May need to install policycoreutils-python-utils";
                fi;
            else
                echo "INFO: SELinux port $port already configured";
            fi;
        done;
        echo "SUCCESS: SELinux configuration completed";
    else
        echo "INFO: SELinux is not enforcing, skipping configuration";
    fi
}

configure_firewall ()
{
    echo "INFO: Configuring firewall";
    if ! command -v firewall-cmd &> /dev/null; then
        echo "WARNING: firewalld is not installed. Skipping firewall configuration";
        return 0;
    fi;
    if ! systemctl is-active --quiet firewalld; then
        echo "INFO: Starting firewalld";
        if run_with_sudo systemctl start firewalld; then
            echo "SUCCESS: Firewalld started";
        else
            echo "ERROR: Failed to start firewalld" 1>&2;
            return 1;
        fi;
    fi;
    declare -A PORTS=(["HTTPs"]="443/tcp" ["Grafana"]="3000/tcp" ["Loki"]="3100/tcp" ["Mimir"]="9009/tcp");
    for service in "${!PORTS[@]}";
    do
        port=${PORTS[$service]};
        if ! run_with_sudo firewall-cmd --query-port="$port" | grep -q "yes"; then
            echo "INFO: Opening port $port for $service";
            if run_with_sudo firewall-cmd --permanent --add-port="$port"; then
                echo "SUCCESS: Port $port opened for $service";
            else
                echo "ERROR: Failed to open port $port for $service" 1>&2;
                return 1;
            fi;
        else
            echo "INFO: Port $port for $service is already configured";
        fi;
    done;
    echo "INFO: Reloading firewalld";
    if run_with_sudo firewall-cmd --reload; then
        echo "SUCCESS: Firewalld reloaded";
    else
        echo "ERROR: Failed to reload firewalld" 1>&2;
        return 1;
    fi;
    echo "SUCCESS: Firewall configuration completed"
}

empty_firewall_rules ()
{
    echo "INFO: Removing firewall rules";
    if ! command -v firewall-cmd &> /dev/null; then
        echo "WARNING: firewalld is not installed. Skipping firewall configuration";
        return 0;
    fi;
    if ! systemctl is-active --quiet firewalld; then
        echo "INFO: Starting firewalld";
        if run_with_sudo systemctl start firewalld; then
            echo "SUCCESS: Firewalld started";
        else
            echo "ERROR: Failed to start firewalld" 1>&2;
            return 1;
        fi;
    fi;
    declare -A PORTS=(["HTTPs"]="443/tcp" ["Grafana"]="3000/tcp" ["Loki"]="3100/tcp" ["Mimir"]="9009/tcp");
    for service in "${!PORTS[@]}";
    do
        port=${PORTS[$service]};
        if run_with_sudo firewall-cmd --query-port="$port" | grep -q "yes"; then
            echo "INFO: Removing port $port for $service";
            if run_with_sudo firewall-cmd --permanent --remove-port="$port"; then
                echo "SUCCESS: Port $port close for $service";
            else
                echo "ERROR: Failed to close port $port for $service" 1>&2;
                return 1;
            fi;
        else
            echo "INFO: Port $port for $service was not already configured";
        fi;
    done;
    echo "INFO: Reloading firewalld";
    if run_with_sudo firewall-cmd --reload; then
        echo "SUCCESS: Firewalld reloaded";
    else
        echo "ERROR: Failed to reload firewalld" 1>&2;
        return 1;
    fi;
    echo "SUCCESS: Firewall rule removal process completed"
}

pull_container_images ()
{
    echo "INFO: Pulling container images";
    if [ ! -f "versions.txt" ]; then
        echo "ERROR: versions.txt file not found" 1>&2;
        return 1;
    fi;
    if [ "$(grep -c /mission-share /etc/mtab)" -eq 0 ]; then
        echo "ERROR: Please add the 2nd disk and run the mount option in this script first" 1>&2;
        return 1;
    fi;
    echo "====================================================";
    echo " Secure Login to registry1.dso.mil";
    echo "====================================================";
    read -r -p "Username: " REGISTRY_USERNAME;
    read -r -s -p "Password: " REGISTRY_PASSWORD;
    echo "";
    echo "INFO: Attempting login...";
    if printf "%s\n" "$REGISTRY_PASSWORD" | podman login --username "$REGISTRY_USERNAME" --password-stdin registry1.dso.mil; then
        echo "SUCCESS: Logged into registry1.dso.mil";
    else
        echo "ERROR: Failed to log into registry1.dso.mil" 1>&2;
        unset REGISTRY_USERNAME REGISTRY_PASSWORD;
        return 1;
    fi;
    unset REGISTRY_USERNAME REGISTRY_PASSWORD;
    . versions.txt;
    echo "INFO: Downloading Grafana version ${GRAFANA_VERSION}";
    if podman pull registry1.dso.mil/ironbank/opensource/grafana/grafana:${GRAFANA_VERSION} && podman image tag grafana:${GRAFANA_VERSION} grafana-oss-custom:${GRAFANA_VERSION}; then
        echo "SUCCESS: Grafana image pulled and tagged";
    else
        echo "ERROR: Failed to pull or tag Grafana image" 1>&2;
        return 1;
    fi;
    echo "INFO: Downloading Loki version ${LOKI_VERSION}";
    if podman pull registry1.dso.mil/ironbank/opensource/grafana/loki:${LOKI_VERSION} && podman image tag loki:${LOKI_VERSION} loki-custom:${LOKI_VERSION}; then
        echo "SUCCESS: Loki image pulled and tagged";
    else
        echo "ERROR: Failed to pull or tag Loki image" 1>&2;
        return 1;
    fi;
    echo "INFO: Downloading Mimir version ${MIMIR_VERSION}";
    if podman pull registry1.dso.mil/ironbank/opensource/grafana/mimir:${MIMIR_VERSION} && podman image tag mimir:${MIMIR_VERSION} mimir-custom:${MIMIR_VERSION}; then
        echo "SUCCESS: Mimir image pulled and tagged";
    else
        echo "ERROR: Failed to pull or tag Mimir image" 1>&2;
        return 1;
    fi;
    echo "INFO: Listing custom images";
    podman images | egrep "custom|TAG";
    echo "SUCCESS: Image download process completed"
}

split_large_files ()
{
    local dir="${1:-.}";
    if [[ ! -d "$dir" ]]; then
        echo "ERROR: Directory '$dir' does not exist" 1>&2;
        return 1;
    fi;
    local threshold=$((500 * 1024 * 1024));
    echo "INFO: Checking for files larger than 500MB in '$dir'";
    find "$dir" -maxdepth 1 -type f -size +${threshold}c | while IFS= read -r file; do
        local size;
        size=$(ls -sh "$file" | awk '{print $1}');
        echo "INFO: Found file: $file ($size), splitting into 500MB chunks";
        if split --verbose -b 500m "$file" "${file}.part."; then
            echo "SUCCESS: Split $file into chunks";
            ls -lh "${file}.part."*;
        else
            echo "ERROR: Failed to split $file" 1>&2;
            return 1;
        fi;
    done;
    echo "SUCCESS: File splitting process completed"
}

reassemble_files ()
{
    local dir="${1:-.}";
    if [[ ! -d "$dir" ]]; then
        echo "ERROR: Directory '$dir' does not exist" 1>&2;
        return 1;
    fi;
    dir="${dir%/}";
    local files_reassembled=false;
    echo "INFO: Checking for split files in '$dir'";
    find "$dir" -maxdepth 1 -type f -name '*.part.*' | sed 's/\.part\.[a-z]\+$//' | sort -u | while IFS= read -r base_file; do
        if [[ -f "$base_file" ]]; then
            echo "WARNING: Original file '$base_file' already exists. Skipping reassembly";
            continue;
        fi;
        local parts;
        parts=$(find "$dir" -maxdepth 1 -type f -name "${base_file##*/}.part.*" | sort);
        if [[ -z "$parts" ]]; then
            echo "WARNING: No split parts found for '$base_file'";
            continue;
        fi;
        echo "INFO: Reassembling '$base_file' from parts:";
        echo "$parts" | while IFS= read -r part; do
            echo "INFO: $part";
        done;
        if cat $parts > "$base_file"; then
            echo "SUCCESS: Reassembled '$base_file'";
            ls -lh "$base_file";
            rm "${base_file}.part."*;
            echo "SUCCESS: Deleted split parts for '$base_file'";
            files_reassembled=true;
        else
            echo "ERROR: Failed to reassemble '$base_file'" 1>&2;
            return 1;
        fi;
    done;
    if [[ "$files_reassembled" == false ]]; then
        echo "INFO: No files needed reassembly";
    fi;
    echo "SUCCESS: File reassembly process completed"
}

install_tarball_images ()
{
    echo "INFO: Installing tarball container images";
    echo "INFO: Copying repo images to /mission-share/upload";
    if rsync -avh --progress upload_contents_to_mission-share_upload_dir/* /mission-share/upload/; then
        echo "SUCCESS: Copied images to /mission-share/upload";
    else
        echo "ERROR: Failed to copy images to /mission-share/upload" 1>&2;
        return 1;
    fi;
    echo "INFO: Checking file integrity";
    if sha1sum -c --ignore-missing /mission-share/upload/sha1sum.txt; then
        echo "SUCCESS: File integrity check passed";
    else
        echo "ERROR: SHA1 checksum verification failed. Please check the uploaded files" 1>&2;
        return 1;
    fi;
    echo "INFO: Reassembling split files if needed";
    if reassemble_files "/mission-share/upload"; then
        echo "SUCCESS: Reassembly completed";
    else
        echo "ERROR: Failed to reassemble split files" 1>&2;
        return 1;
    fi;
    echo "INFO: Performing second integrity check";
    if sha1sum -c /mission-share/upload/sha1sum-after-assembly.txt; then
        echo "SUCCESS: Second integrity check passed";
    else
        echo "ERROR: SHA1 checksum verification after reassembly failed" 1>&2;
        return 1;
    fi;
    echo "INFO: Importing tarball container images";
    for i in $(ls /mission-share/upload/*.tar.gz | grep -v part);
    do
        echo "INFO: Importing container image: $i";
        mkdir -p /mission-share/.tmp > /dev/null;
        if export TMPDIR=/mission-share/.tmp && podman load -i "$i"; then
            echo "SUCCESS: Imported container image $i";
        else
            echo "ERROR: Failed to import container image $i" 1>&2;
            return 1;
        fi;
    done;
    echo "SUCCESS: Tarball image installation completed"
}

copy_source_directories ()
{
    echo "INFO: Copying source directories to /mission-share/";
    if ! command -v rsync &> /dev/null; then
        echo "ERROR: rsync is required but not installed. Please install it first" 1>&2;
        return 1;
    fi;
    path="/mission-share/podman/containers";
    rootpath="/mission-share";
    podmanshare="/mission-share/podman";
    echo "INFO: Creating container storage folders";
    run_with_sudo chcon -t -R container_file_t $podmanshare;
    echo "SUCCESS: SELinux context set for $podmanshare";
    echo "INFO: Making needed directories";
    if podman unshare mkdir -vp "$path/grafana/provisioning/dashboards" "$path/grafana/provisioning" "$path/grafana/dashboards" "$path/grafana" "$path/loki" "$path/mimir" "$path/configs" "$path/keys/"{grafana,mimir,loki,nginx} "$rootpath/audit_logs"; then
        echo "SUCCESS: Directories created";
    else
        echo "ERROR: Failed to create directories" 1>&2;
        return 1;
    fi;
    echo "INFO: Copying configuration files";
    if podman unshare cp -v configs/* $path/configs/ && podman unshare chmod 0644 $path/configs/*; then
        echo "SUCCESS: Configuration files copied and permissions set";
    else
        echo "ERROR: Failed to copy configuration files or set permissions" 1>&2;
        return 1;
    fi;
    echo "INFO: Copying Grafana datasource files to $path/grafana/provisioning";
    if podman unshare cp -v grafana/provisioning/datasources/datasources.yaml $path/grafana/provisioning/; then
        echo "SUCCESS: Grafana datasource files copied";
    else
        echo "ERROR: Failed to copy Grafana datasource files" 1>&2;
        return 1;
    fi;
    echo "INFO: Copying Grafana dashboards to $path/grafana/dashboards";
    if podman unshare rsync -ah grafana/provisioning/dashboards/ $path/grafana/dashboards/; then
        echo "SUCCESS: Grafana dashboards copied";
    else
        echo "ERROR: Failed to copy Grafana dashboards" 1>&2;
        return 1;
    fi;
    echo "INFO: Removing old unneeded files";
    if podman unshare rm -vf $path/grafana/dashboards/*.yaml; then
        echo "SUCCESS: Removed old unneeded files";
    else
        echo "ERROR: Failed to remove old unneeded files" 1>&2;
        return 1;
    fi;
    echo "INFO: Copying Grafana provisioning files to $path/grafana/provisioning/dashboards";
    if podman unshare rsync -ah grafana/provisioning/dashboards/*.yaml $path/grafana/provisioning/dashboards/; then
        echo "SUCCESS: Grafana provisioning files copied";
    else
        echo "ERROR: Failed to copy Grafana provisioning files" 1>&2;
        return 1;
    fi;
    echo "INFO: Copying Grafana plugins to $path/grafana";
    if podman unshare rsync -ah grafana/plugins $path/grafana/; then
        echo "SUCCESS: Grafana plugins copied";
    else
        echo "ERROR: Failed to copy Grafana plugins" 1>&2;
        return 1;
    fi;
    echo "INFO: Copying vast-ca to new location";
    if podman unshare rsync -ah vast-ca $rootpath/; then
        echo "SUCCESS: Copied vast-ca and tools";
    else
        echo "ERROR: Failed to copy vast-ca or tools" 1>&2;
        return 1;
    fi;

    echo "INFO: Setting permissions on mimir directories"
    if run_with_sudo chmod 0777 /mission-share/podman/containers/mimir; then
        echo "SUCCESS: mimir directory permissions set"
    else
        echo "ERROR: Failed to set mimir directory permissions" >&2
        return 1
    fi
    echo "SUCCESS: Source directory copying completed"
}

validate_ip ()
{
    local ip=$1;
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip";
        for octet in "${octets[@]}";
        do
            if [[ $octet -gt 255 || $octet -lt 0 ]]; then
                return 1;
            fi;
        done;
        return 0;
    else
        return 1;
    fi
}

fix_fapolicyd ()
{
    echo "INFO: Setting fapolicyd rules";
    run_with_sudo cp -vf fapolicyd_rules/*.rules /etc/fapolicyd/rules.d/;
    if run_with_sudo fapolicyd-cli --reload-rules; then
        echo "SUCCESS: fapolicyd rules reloaded";
    else
        echo "ERROR: Unable to determine if fapolicyd rules were accepted.";
        return 1;
    fi
}

get_default_ip ()
{
    local iface;
    iface=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}');
    if [[ -z "$iface" ]]; then
        echo "No default route found" 1>&2;
        return 1;
    fi;
    ip -o -4 addr show dev "$iface" | awk '{print $4}' | cut -d'/' -f1
}

get_ip_addresses ()
{
    ip -o addr show | awk '/inet / {print $2, $4}' | grep -vE '^(docker|br-|veth|lo)' | awk '{print $2}' | cut -d'/' -f1 | sort -u
}

build_and_start_pod ()
{
    echo "INFO: Building and starting OGS pod";
    podmanshare="/mission-share/podman";
    echo "INFO: Setting SELinux context for $podmanshare";
    if run_with_sudo chcon -t container_file_t -R $podmanshare; then
        echo "SUCCESS: SELinux context set for $podmanshare";
    else
        echo "ERROR: Failed to set SELinux context for $podmanshare";
        return 1;
    fi;
    if run_with_sudo restorecon -R $podmanshare; then
        echo "SUCCESS: SELinux restored context for $podmanshare";
    else
        echo "ERROR: Failed to set SELinux context for $podmanshare";
        return 1;
    fi;
    echo "INFO: Stopping OGS pod if running - in case we need to replace it, has to be stopped";
    if podman pod stop -t 60 ogs 2> /dev/null; then
        echo "SUCCESS: OGS pod stopped or not running";
    else
        echo "INFO: No OGS pod was running or stop command ignored";
    fi;
    echo "INFO: Loading versions from versions.txt";
    if . versions.txt; then
        echo "SUCCESS: Versions loaded";
    else
        echo "ERROR: Failed to load versions.txt" 1>&2;
        return 1;
    fi;
    echo "INFO: Generating new pod YAML from template";
    cd ogs-pod || {
        echo "ERROR: Failed to change to ogs-pod directory" 1>&2;
        return 1
    };
    if cat ogs-pod.yml.template | sed "s|HOMEDIR|/mission-share|g" | sed "s|GRAFANA_VERSION|$GRAFANA_VERSION|g" | sed "s|LOKI_VERSION|$LOKI_VERSION|g" | sed "s|MIMIR_VERSION|$MIMIR_VERSION|g" | sed "s|LDAP_BIND_PASSWD_VALUE|$LDAP_BIND_PASSWORD_VALUE|g" | sed "s|GRAFANA_ADMIN_USERNAME|$GRAFANA_ADMIN_USERNAME|g" | sed "s|GRAFANA_ADMIN_PW|$GRAFANA_ADMIN_PW|g" | sed "s|--UID--|$UID|g" | sed "s|--GID--|$UID|g" > ogs-pod.yml; then
        echo "SUCCESS: Generated OGS pod YAML";
    else
        echo "ERROR: Failed to generate OGS pod YAML" 1>&2;
        return 1;
    fi;
    echo "INFO: Generating Grafana LDAP values from template";
    if cat ../configs/grafana_ldap.toml.template | sed "s|LDAP_SERVER|$LDAP_SERVER|g" | sed "s|LDAP_BIND_USER_VALUE|$LDAP_BIND_USER_VALUE|g" | sed "s|LDAP_SEARCH_BASE|$LDAP_SEARCH_BASE|g" > ../configs/grafana_ldap.toml; then
        echo "SUCCESS: Generated configs/grafana_ldap.toml";
    else
        echo "ERROR: Failed to generate configs/grafana_ldap.toml" 1>&2;
        return 1;
    fi;
    echo "INFO: Creating Systemd directories";
    if mkdir -p ~/.config/containers/systemd ~/.config/systemd/user; then
        echo "SUCCESS: Systemd directories created";
    else
        echo "ERROR: Failed to create Systemd directories" 1>&2;
        return 1;
    fi;
    echo "INFO: Copying pod yml file";
    if podman unshare cp -f ogs-pod.yml /mission-share/podman/containers/ogs-pod.yml; then
        echo "SUCCESS: pod yml file copied";
    else
        echo "ERROR: Failed to copy pod yml file" 1>&2;
        return 1;
    fi;
    echo "INFO: Copying Grafana ldap config file";
    if podman unshare cp -f ../configs/grafana_ldap.toml /mission-share/podman/containers/configs/grafana_ldap.toml; then
        echo "SUCCESS: grafana_ldap.toml file copied";
    else
        echo "ERROR: Failed to copy grafana_ldap.toml file" 1>&2;
        return 1;
    fi;
    echo "INFO: Starting initial OGS pod";
    if podman kube play --replace --start=false --userns=keep-id /mission-share/podman/containers/ogs-pod.yml; then
        echo "SUCCESS: Initial OGS pod started";
    else
        echo "ERROR: Failed to start initial OGS pod" 1>&2;
        return 1;
    fi;
    echo "INFO: Generating systemd service files for OGS pod";
    if podman generate systemd --name --files ogs && mv -fv *.service ~/.config/systemd/user/; then
        echo "SUCCESS: Systemd service files generated and moved";
    else
        echo "ERROR: Failed to generate or move systemd service files" 1>&2;
        return 1;
    fi;
    echo "INFO: Reloading systemd user daemon";
    if systemctl --user daemon-reload; then
        echo "SUCCESS: Systemd user daemon reloaded";
    else
        echo "ERROR: Failed to reload systemd user daemon" 1>&2;
        return 1;
    fi;
    echo "INFO: Stopping existing OGS pod if running - so we can start it with systemctl";
    if podman pod stop -t 60 ogs 2> /dev/null; then
        echo "SUCCESS: Existing OGS pod stopped or not running";
    else
        echo "INFO: No OGS pod was running or stop command ignored";
    fi;
    echo "INFO: Enabling and starting pod-ogs.service";
    if systemctl --user enable --now pod-ogs.service; then
        echo "SUCCESS: pod-ogs.service enabled and started";
    else
        echo "ERROR: Failed to enable or start pod-ogs.service" 1>&2;
        return 1;
    fi;
    sleep 3;
    echo "INFO: Listing all containers";
    podman ps -a -p;
    echo "SUCCESS: OGS pod created and started";
    echo "INFO: Enabling linger for user $USER";
    if loginctl enable-linger; then
        echo "SUCCESS: Linger enabled for user $USER";
    else
        echo "ERROR: Failed to enable linger for user $USER" 1>&2;
        return 1;
    fi;
    echo "SUCCESS: OGS pod deployment completed";
    echo "INFO:   OGS services available:";
    echo "INFO: - Grafana on port 3000";
    echo "INFO: - Mimir on port 9009";
    echo "INFO: - Loki on port 3100";
    echo "INFO: - Parent NGINX proxy on port 443";
    echo "INFO:   Access Grafana at: https://$GRAFANA_DOMAIN_FQDN/";
    echo "INFO: - initial login username $GRAFANA_ADMIN_USERNAME";
    echo "INFO: - initial login password $GRAFANA_ADMIN_PW";
    cd "$OLDPWD"
}

check_permission ()
{
    local file="$1";
    local expected_perm="$2";
    local actual_perm=$(stat -c "%a" "$file" 2>/dev/null);
    if [[ "$actual_perm" != "$expected_perm" ]]; then
        echo "ERROR: $file has permissions $actual_perm (expected $expected_perm)" 1>&2;
        echo "INFO: Please run the system configuration first or manually fix with:" 1>&2;
        echo "sudo chmod $expected_perm $file" 1>&2;
        return 1;
    fi;
    echo "SUCCESS: $file permissions verified as $expected_perm";
    return 0
}

safe_modify ()
{
    local file="$1";
    local action="$2";
    local description="$3";
    echo -n "INFO: ${description}... ";
    if [ -f "$file" ]; then
        if eval "$action"; then
            echo "SUCCESS: ${description} completed";
        else
            echo "ERROR: Failed to ${description}" 1>&2;
            return 1;
        fi;
    else
        echo "INFO: Skipped (file not found)";
    fi
}

check_success ()
{
    if [ $? -ne 0 ]; then
        echo "ERROR: $1" 1>&2;
        return 1;
    fi;
    echo "SUCCESS: $1 completed"
}

stop_pod_named ()
{
    local podname="$1";
    if [[ -z "$podname" ]]; then
        echo "ERROR: No pod name provided to stop_pod_named" 1>&2;
        return 1;
    fi;
    echo "INFO: Checking if pod '$podname' exists";
    if ! podman pod exists "$podname" &> /dev/null; then
        echo "ERROR: Pod '$podname' does not exist" 1>&2;
        return 1;
    fi;
    echo "INFO: Stopping pod '$podname' with 'podman pod stop -t 60 $podname'";
    if ! podman pod stop -t 60 "$podname" &> /dev/null; then
        echo "ERROR: Failed to stop pod '$podname'" 1>&2;
        return 1;
    fi;
    echo "SUCCESS: Pod '$podname' stopped successfully";
    return 0
}

stop_and_delete_pod ()
{
    local podname="$1";
    if [[ -z "$podname" ]]; then
        echo "ERROR: No pod name provided to stop_and_delete_pod" 1>&2;
        return 1;
    fi;
    echo "INFO: Beginning stop and delete process for pod '$podname'";
    echo "INFO: Checking if 'pod-$podname' service exists";
    if ! systemctl --user list-units --type=service --all | grep -q "pod-$podname"; then
        echo "INFO: 'pod-$podname' service does not exist, proceeding to podman operations";
    else
        echo "INFO: Checking if 'pod-$podname' service is active";
        if systemctl --user is-active --quiet "pod-$podname"; then
            echo "INFO: 'pod-$podname' service is active, stopping with 'systemctl --user stop pod-$podname'";
            if ! systemctl --user stop "pod-$podname"; then
                echo "ERROR: Failed to stop 'pod-$podname' service" 1>&2;
                return 1;
            fi;
            echo "SUCCESS: 'pod-$podname' service stopped successfully";
        else
            echo "INFO: 'pod-$podname' service is not active";
        fi;
        echo "INFO: Disabling 'pod-$podname' service with 'systemctl --user disable pod-$podname'";
        if ! systemctl --user disable "pod-$podname" &> /dev/null; then
            echo "ERROR: Failed to disable 'pod-$podname' service" 1>&2;
            return 1;
        fi;
        echo "SUCCESS: 'pod-$podname' service disabled successfully";
    fi;
    if ! stop_pod_named "$podname"; then
        echo "ERROR: Failed to stop pod '$podname'" 1>&2;
        return 1;
    fi;
    echo "INFO: Deleting pod '$podname' with 'podman pod rm --force $podname'";
    if ! podman pod rm --force "$podname" &> /dev/null; then
        echo "ERROR: Failed to delete pod '$podname'" 1>&2;
        return 1;
    fi;
    echo "SUCCESS: Pod '$podname' deleted successfully";
    echo;
    echo;
    read -p "INFO: Confirm you wish to delete the data from pod: $podname (yes/no) " confirm;
    if [[ "$confirm" =~ [yY]|[yY][eE][sS] ]]; then
        echo "INFO: Removing Container files for pod named: $podname";
        if [ "$podname" == "ogs" ]; then
            deletepath="/mission-share/podman/containers/ogs-pod.yml
            /mission-share/podman/containers/grafana
            /mission-share/podman/containers/loki
            /mission-share/podman/containers/mimir";
        fi;
        echo "Standby, this could take a minute";
        for i in `echo -e $deletepath`;
        do
            if run_with_sudo rm -rf "$i"; then
                echo "SUCCESS: Removed files on path $deletepath";
            else
                echo "ERROR: Failed to Remove files on path $deletepath" 1>&2;
                return 1;
            fi;
        done;
    else
        echo -e "\nSkipping file deletion sequence\n";
    fi;
    return 0
}

stop_and_delete_pod_auto ()
{
    local podname="$1";
    if [[ -z "$podname" ]]; then
        echo "ERROR: No pod name provided to stop_and_delete_pod" 1>&2;
        return 1;
    fi;
    echo "INFO: Beginning stop and delete process for pod '$podname'";
    echo "INFO: Checking if 'pod-$podname' service exists";
    if ! systemctl --user list-units --type=service --all | grep -q "pod-$podname"; then
        echo "INFO: 'pod-$podname' service does not exist, proceeding to podman operations";
    else
        echo "INFO: Checking if 'pod-$podname' service is active";
        if systemctl --user is-active --quiet "pod-$podname"; then
            echo "INFO: 'pod-$podname' service is active, stopping with 'systemctl --user stop pod-$podname'";
            if ! systemctl --user stop "pod-$podname"; then
                echo "ERROR: Failed to stop 'pod-$podname' service" 1>&2;
                return 1;
            fi;
            echo "SUCCESS: 'pod-$podname' service stopped successfully";
        else
            echo "INFO: 'pod-$podname' service is not active";
        fi;
        echo "INFO: Disabling 'pod-$podname' service with 'systemctl --user disable pod-$podname'";
        if ! systemctl --user disable "pod-$podname" &> /dev/null; then
            echo "ERROR: Failed to disable 'pod-$podname' service" 1>&2;
            return 1;
        fi;
        echo "SUCCESS: 'pod-$podname' service disabled successfully";
    fi;
    if ! stop_pod_named "$podname"; then
        echo "ERROR: Failed to stop pod '$podname'" 1>&2;
        return 1;
    fi;
    echo "INFO: Deleting pod '$podname' with 'podman pod rm --force $podname'";
    if ! podman pod rm --force "$podname" &> /dev/null; then
        echo "ERROR: Failed to delete pod '$podname'" 1>&2;
        return 1;
    fi;
    echo "SUCCESS: Pod '$podname' deleted successfully";
    echo;
    echo;
    confirm="yes";
    if [[ "$confirm" =~ [yY]|[yY][eE][sS] ]]; then
        echo "INFO: Removing Container files for pod named: $podname";
        if [ "$podname" == "ogs" ]; then
            deletepath="/mission-share/podman/containers/ogs-pod.yml
            /mission-share/podman/containers/grafana
            /mission-share/podman/containers/loki
            /mission-share/podman/containers/mimir";
        fi;
        echo "Standby, this could take a minute";
        for i in `echo -e $deletepath`;
        do
            if run_with_sudo rm -rf "$i"; then
                echo "SUCCESS: Removed files on path $deletepath";
            else
                echo "ERROR: Failed to Remove files on path $deletepath" 1>&2;
                return 1;
            fi;
        done;
    else
        echo -e "\nSkipping file deletion sequence\n";
    fi;
    return 0
}

reset_podman ()
{
    echo "INFO: performing podman system reset to clear locked file handles";
    if podman system reset -f; then
        echo "SUCCESS: podman reset successful";
        return 0;
    else
        echo "ERROR: podman reset failed- run 'podman system reset' -f manually";
        return 1;
    fi
}

delete_all_mission-share_data ()
{
    run_with_sudo rm -rf "/mission-share";
    return 0
}

cleanup_pod_services ()
{
    local podname="$1";
    local systemd_user_dir="$HOME/.config/systemd/user";
    local pod_service="pod-$podname.service";
    if [[ -z "$podname" ]]; then
        echo "ERROR: No pod name provided to cleanup_pod_services" 1>&2;
        return 1;
    fi;
    echo "INFO: Beginning cleanup of service files for pod '$podname'";
    echo "INFO: Checking if '$pod_service' exists";
    if ! systemctl --user list-units --type=service --all | grep -q "$pod_service"; then
        echo "INFO: '$pod_service' does not exist, proceeding to file cleanup";
    else
        echo "INFO: Checking if '$pod_service' is active";
        if systemctl --user is-active --quiet "$pod_service"; then
            echo "INFO: '$pod_service' is active, stopping with 'systemctl --user stop $pod_service'";
            if ! systemctl --user stop "$pod_service"; then
                echo "ERROR: Failed to stop '$pod_service'" 1>&2;
                return 1;
            fi;
            echo "SUCCESS: '$pod_service' stopped successfully";
        else
            echo "INFO: '$pod_service' is not active";
        fi;
        echo "INFO: Disabling '$pod_service' with 'systemctl --user disable $pod_service'";
        if ! systemctl --user disable "$pod_service" &> /dev/null; then
            echo "ERROR: Failed to disable '$pod_service'" 1>&2;
            return 1;
        fi;
        echo "SUCCESS: '$pod_service' disabled successfully";
    fi;
    echo "INFO: Retrieving dependencies for '$pod_service' using 'systemctl --user list-dependencies'";
    local wants_services;
    wants_services=$(systemctl --user list-dependencies "$pod_service" | grep -E "container-$podname-.*\.service" | sed 's/.*├─//;s/.*└─//');
    if [[ -z "$wants_services" ]]; then
        echo "INFO: No container service dependencies found for '$pod_service'";
    else
        echo "INFO: Found container service dependencies: $wants_services";
    fi;
    while IFS= read -r service; do
        if [[ -z "$service" ]]; then
            continue;
        fi;
        echo "INFO: Checking if '$service' exists";
        if ! systemctl --user list-units --type=service --all | grep -q "$service"; then
            echo "INFO: '$service' does not exist, skipping";
            continue;
        fi;
        echo "INFO: Checking if '$service' is active";
        if systemctl --user is-active --quiet "$service"; then
            echo "INFO: '$service' is active, stopping with 'systemctl --user stop $service'";
            if ! systemctl --user stop "$service"; then
                echo "ERROR: Failed to stop '$service'" 1>&2;
                return 1;
            fi;
            echo "SUCCESS: '$service' stopped successfully";
        else
            echo "INFO: '$service' is not active";
        fi;
    done <<< "$wants_services";
    echo "INFO: Removing service file '$systemd_user_dir/$pod_service'";
    if [[ -f "$systemd_user_dir/$pod_service" ]]; then
        if ! rm -f "$systemd_user_dir/$pod_service"; then
            echo "ERROR: Failed to remove '$systemd_user_dir/$pod_service'" 1>&2;
            return 1;
        fi;
        echo "SUCCESS: '$pod_service' removed successfully";
    else
        echo "INFO: '$pod_service' file does not exist, skipping";
    fi;
    while IFS= read -r service; do
        if [[ -z "$service" ]]; then
            continue;
        fi;
        echo "INFO: Removing service file '$systemd_user_dir/$service'";
        if [[ -f "$systemd_user_dir/$service" ]]; then
            if ! rm -f "$systemd_user_dir/$service"; then
                echo "ERROR: Failed to remove '$systemd_user_dir/$service'" 1>&2;
                return 1;
            fi;
            echo "SUCCESS: '$service' removed successfully";
        else
            echo "INFO: '$service' file does not exist, skipping";
        fi;
    done <<< "$wants_services";
    echo "INFO: Reloading systemd user daemon with 'systemctl --user daemon-reload'";
    if ! systemctl --user daemon-reload; then
        echo "ERROR: Failed to reload systemd user daemon" 1>&2;
        return 1;
    fi;
    echo "SUCCESS: Systemd user daemon reloaded successfully";
    echo "SUCCESS: Cleanup of service files for pod '$podname' completed successfully";
    return 0
}

check_vars_file ()
{
    VARS_FILE="variables.conf";
    if [ -f "$VARS_FILE" ]; then
        if ! source "$VARS_FILE"; then
            echo "Warning: Failed to source $VARS_FILE. Check permissions on the file variables.conf";
        fi;
        export OGS_DOMAIN_NAME;
        export LDAP_SERVER;
        export LDAP_SEARCH_BASE;
        export LISTEN_IP_ADDRESS;
        export HOST_IP_ADDRESS;
        export LDAP_BIND_USER_VALUE;
        export LDAP_BIND_PASSWORD_VALUE;
        export GRAFANA_DOMAIN_FQDN;
        export GRAFANA_ADMIN_USERNAME;
        export GRAFANA_ADMIN_PW;
        export VARS_FOUND=" \u2714 Vars file found";
        return 1;
    else
        export VARS_FOUND=" \u2716 ERROR:  <-- Vars file Not found -- run this option first";
        return 0;
    fi
}

show_menu ()
{
    clear;
    check_vars_file;
    echo "========================================================================";
    echo "       Monitoring Stack Deployment Tool - Ver. $script_version";
    echo "========================================================================";
    echo " Privileged Operations:";
    echo -e " 0)  Input/adjust parameters $VARS_FOUND";
    echo " 1)  Configure System Settings";
    echo " 2)  Provision Disk for Podman Data";
    echo " 3)  Copy container source directories";
    echo " 4)  Generate SSL Certificates - GLAM packages";
    echo " 5)  Install and Configure Nginx Proxy";
    echo " 6)  Configure Firewall";
    echo "";
    echo "======================== Image Imports =================================";
    echo "      NOTE: Choose based off networking available ";
    echo " 7)  Pull Container Images   - Internet required";
    echo " 8)  Install Packaged Images - No Internet required";
    echo "";
    echo "========================Pod Options=====================================";
    echo " 9)  Build and Start (graf,loki,mimir) Pod";
    echo "";
    echo " q)  Exit";
    echo "";
    echo "===================== Un-Install Options ===============================";
    echo " u1)  Stop and Delete OGS (glam) pod";
    echo " u2)  Runs u1, u2, and completely clear out all PODS, containers, keys, files and images on /mission-share";
    echo "       -- takes /mission-share back to empty state";
    echo " u3)  Remove Customized Firewall rules"
}

umount_disk ()
{
    if [ grep -c mission-share /etc/mtab -eq 0 ]; then
        echo "/mission-share is not mounted";
        return 0;
    fi;
    if run_with_sudo umount /mission-share; then
        echo "SUCCESS: /mission-share unmounted";
        return 0;
    else
        echo "ERROR: Failed to unmount /mission-share";
        return 1;
    fi
}

remove_disk_from_fstab ()
{
    echo "INFO: making backup of fstab to /tmp/fstab.backup";
    cp -f /etc/fstab /tmp/fstab.backup;
    if run_with_sudo sed -i '/\/mission-share/d' /etc/fstab; then
        echo "SUCCESS: fstab modified, reloading systemctl";
        run_with_sudo systemctl daemon-reload;
        return 0;
    else
        echo "ERROR: unable to modify /etc/fstab file";
        return 1;
    fi
}

get_sudo_password

while true; do
    show_menu; read -p "Enter your choice: " choice; case $choice in
        0)
            collect_user_inputs && show_menu
        ;;
        1)
            configure_system_settings
        ;;
        2)
            provision_disk
        ;;
        3)
            copy_source_directories
        ;;
        4)
            generate_ssl_keys
        ;;
        5)
            install_nginx
        ;;
        5a)
            install_nginx_no_pki
        ;;
        6)
            configure_firewall
        ;;
        7)
            pull_container_images
        ;;
        8)
            install_tarball_images
        ;;
        9)
            build_and_start_pod
        ;;
        u1)
            if stop_and_delete_pod "ogs"; then
                echo "SUCCESS: Stopped and deleted pod 'ogs'";
            else
                echo "ERROR: Failed to stop and delete pod 'ogs'" 1>&2;
            fi; if cleanup_pod_services "ogs"; then
                echo "SUCCESS: Cleaned up services for pod 'ogs'";
            else
                echo "ERROR: Failed to clean up services for pod 'ogs'" 1>&2;
            fi
        ;;
        u2)
            if podman pod exists ogs; then
                echo "Removing pod 'ogs'"; stop_and_delete_pod_auto "ogs"; if cleanup_pod_services "ogs"; then
                    echo "SUCCESS: Cleaned up services for pod 'ogs'";
                else
                    echo "ERROR: Failed to clean up services for pod 'ogs'" 1>&2;
                fi;
            else
                echo "pod ogs not found, skipping" 1>&2;
            fi; reset_podman; echo "INFO: Removing all files under /mission"; delete_all_mission-share_data; podman system reset -f > /dev/null 2>&1
        ;;
        u3)
            empty_firewall_rules
        ;;
        q)
            echo "INFO: Exiting. Have a nice day!"; exit 0
        ;;
        Q)
            echo "INFO: Exiting. Have a nice day!"; exit 0
        ;;
        *)
            echo "ERROR: Invalid option. Please try again" 1>&2
        ;;
    esac; read -p "Press [Enter] to continue...";
done
