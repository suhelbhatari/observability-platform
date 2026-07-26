#!/usr/bin/env bash
# Human-friendly wrapper around ansible/playbooks/decommission_node.yml
set -euo pipefail

usage() {
  echo "Usage: $0 -h <hostname> [-f]"
  echo "  -f  skip confirmation prompt"
  exit 1
}

FORCE=0
while getopts "h:f" opt; do
  case $opt in
    h) HOSTNAME_ARG="$OPTARG" ;;
    f) FORCE=1 ;;
    *) usage ;;
  esac
done
: "${HOSTNAME_ARG:?hostname required}"

if [[ "$FORCE" -ne 1 ]]; then
  read -rp "Decommission ${HOSTNAME_ARG} from monitoring? This stops alerting immediately. [y/N] " confirm
  [[ "$confirm" == "y" || "$confirm" == "Y" ]] || { echo "Aborted."; exit 0; }
fi

echo ">> Decommissioning ${HOSTNAME_ARG}..."
ansible-playbook "$(dirname "$0")/../ansible/playbooks/decommission_node.yml" \
  -e "hostname=${HOSTNAME_ARG}"

echo ">> Done. Historical data for ${HOSTNAME_ARG} is retained per the ClickHouse TTL policy."
