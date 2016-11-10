#!/usr/bin/env bash
set -e

logger() {
  DT=$(date '+%Y/%m/%d %H:%M:%S')
  echo "$DT service.sh: $1"
}

logger "Starting Consul..."
if [ -x "$(command -v systemctl)" ]; then
  logger "using systemctl"
  sudo systemctl enable consul.service
  sudo systemctl start consul
else
  logger "using upstart"
  sudo start consul
fi

sleep 2

logger "Starting Nomad..."
if [ -x "$(command -v systemctl)" ]; then
  logger "using systemctl"
  sudo systemctl enable nomad.service
  sudo systemctl start nomad
else 
  logger "using upstart"
  sudo start nomad
fi
