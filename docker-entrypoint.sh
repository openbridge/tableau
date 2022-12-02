#!/usr/bin/env bash

set -o nounset
set -o pipefail
set -o xtrace

if [ -f /opt/tableau/.installed ]; then
  sudo /opt/tableau/tableau_server/packages/customer-bin.*/tsm initialize --start-server --request-timeout 1800

  # wait for config to propagate to all services
  sleep 5

  read server_status <<< $(sudo /opt/tableau/tableau_server/packages/customer-bin.*/tsm status | awk '/Status:/ { print $2 }')
  if [ "$server_status" != "RUNNING" ]; then
    if [ "$server_status" == "DEGRADED" ]; then
      echo "Server status is $server_status, installation will attempt to continue..."
    else
      echo "Server status is $server_status. Canceling."
      exit 1
    fi
  fi

  # wait for config to propagate to all services
  sleep 5

  # Extract the gateway port from the configuration and topology JSON file
  gateway_port="$(grep worker0.gateway.port ${TABLEAU_SERVER_DATA_DIR}/data/tabsvc/config/gateway_0.${version_string}/ports.yml | awk -F ':' '{print $2}' | tr -d ' ')"


else
  sudo bash -c "/install.sh"
fi

exec "$@"
