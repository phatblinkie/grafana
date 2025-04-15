#!/bin/bash
OUTPUT_DIR="/var/lib/node_exporter/textfile_collector"
METRIC_FILE="${OUTPUT_DIR}/software_metrics.prom.tmp"
FINAL_FILE="${OUTPUT_DIR}/software_metrics.prom"

# Create directory if needed
mkdir -p "$OUTPUT_DIR"

# Function to escape Prometheus label values
escape_label() {
  echo "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g' \
    -e 's/^/"/' \
    -e 's/$/"/' \
    -e 's/\n/\\n/g' \
    -e 's/\r/\\r/g'
}

# Write the metric header
echo '# HELP linux_software_info Installed software information
# TYPE linux_software_info gauge' > "$METRIC_FILE"

# For Debian/Ubuntu (dpkg)
if command -v dpkg >/dev/null; then
  dpkg-query -W --showformat='${Package} ${Version} ${Architecture}\n' | while read pkg ver arch; do
    printf 'linux_software_info{name=%s,version=%s,arch=%s} 1\n' \
      "$(escape_label "$pkg")" \
      "$(escape_label "$ver")" \
      "$(escape_label "$arch")" >> "$METRIC_FILE"
  done
fi

# For RHEL/CentOS (rpm)
if command -v rpm >/dev/null; then
  rpm -qa --queryformat '%{NAME} %{VERSION}-%{RELEASE} %{ARCH}\n' | while read pkg ver arch; do
    printf 'linux_software_info{name=%s,version=%s,arch=%s} 1\n' \
      "$(escape_label "$pkg")" \
      "$(escape_label "$ver")" \
      "$(escape_label "$arch")" >> "$METRIC_FILE"
  done
fi

# For Alpine (apk)
if command -v apk >/dev/null; then
  apk info -v | while read pkg; do
    name=$(echo "$pkg" | sed 's/-[0-9].*$//')
    ver=$(echo "$pkg" | grep -o '[0-9].*$')
    printf 'linux_software_info{name=%s,version=%s,arch=""} 1\n' \
      "$(escape_label "$name")" \
      "$(escape_label "$ver")" >> "$METRIC_FILE"
  done
fi

# Atomically update the file
mv -f "$METRIC_FILE" "$FINAL_FILE"
