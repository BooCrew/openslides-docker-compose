#!/bin/bash

set -e

[[ -n "${REPMGR_NODE_ID}" ]] || {
  echo "ERROR: REPMGR_NODE_ID not set.  Cannot continue."
  sleep 10
  exit 2
}

# Set up the postgres cluster
su postgres -c /usr/local/sbin/cluster-setup

# Create SSH privilege separation dir (needed when running /usr/sbin/sshd
# directly, see supervisor.conf)
mkdir -p /run/sshd

# By default, start supervisord in foreground
printf "INFO: Executing command: '%s'\n" "$*"
exec "$@"
