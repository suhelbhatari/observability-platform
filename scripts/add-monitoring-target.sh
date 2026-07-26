#!/usr/bin/env bash
# Human-friendly wrapper around ansible/playbooks/onboard_node.yml
# Adds a VM / app host / appliance / image instance to monitoring.
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 -h <hostname> -i <ip> -t <team> [-p <log_glob_path>] [-y <target_type>]

  -h  Unique hostname (used as inventory key)          [required]
  -i  IP address of the target                         [required]
  -t  Owning team (for alert routing / cost attribution) [required]
  -p  Log file glob to tail (default: /var/log/app/*.log)
  -y  Target type: vm | appliance | image  (default: vm)

Example:
  $0 -h web-app-07 -i 10.0.40.55 -t checkout-squad -p "/var/log/checkout/*.log"
USAGE
  exit 1
}

LOG_PATH="/var/log/app/*.log"
TARGET_TYPE="vm"

while getopts "h:i:t:p:y:" opt; do
  case $opt in
    h) HOSTNAME_ARG="$OPTARG" ;;
    i) IP_ARG="$OPTARG" ;;
    t) TEAM_ARG="$OPTARG" ;;
    p) LOG_PATH="$OPTARG" ;;
    y) TARGET_TYPE="$OPTARG" ;;
    *) usage ;;
  esac
done

: "${HOSTNAME_ARG:?hostname required}" "${IP_ARG:?ip required}" "${TEAM_ARG:?team required}"

echo ">> Onboarding ${HOSTNAME_ARG} (${IP_ARG}) for team ${TEAM_ARG}..."

ansible-playbook "$(dirname "$0")/../ansible/playbooks/onboard_node.yml" \
  -e "hostname=${HOSTNAME_ARG}" \
  -e "target_host=${IP_ARG}" \
  -e "owner_team=${TEAM_ARG}" \
  -e "target_type=${TARGET_TYPE}" \
  -e "log_paths=['${LOG_PATH}']"

echo ">> Done. ${HOSTNAME_ARG} should appear in Grafana within ~1 minute (Prometheus file_sd refresh)."
echo ">> Verify: https://grafana.<your-domain>/d/fleet-overview?var-host=${HOSTNAME_ARG}"
