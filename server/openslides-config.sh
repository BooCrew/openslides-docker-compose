#!/bin/bash

# Insert config files into the configuration database

set -e

MODE=

usage() {
  cat << EOF
Usage: ${BASH_SOURCE[0]} <list|add|connect> [FILES]
EOF
}

fatal() {
  printf "ERROR: %s\n" "$*"
  exit 23
}

list_configs_in_db() {
  readarray -d '' CONFIG_FILES < \
    <(psql -At0 -h db -d instancecfg -c 'SELECT DISTINCT filename FROM files')
}

# same as function from entrypoint, so this could be improved
insert_config_into_db() {
  [[ -f "$1" ]] || fatal "File not found: $1"
  local cfg b64
  local cfg="$(realpath "$1")"
  b64="$(base64 < "$cfg")"
  psql -v ON_ERROR_STOP=1 -1 -h db -d instancecfg \
    -c "INSERT INTO files(filename, data, from_host)
      VALUES(
        '${cfg}',
        decode('$b64', 'base64'),
        '$(hostname)'
      )"
}

[[ "$#" -ge 1 ]] || { usage; exit 2; }

case "$1" in
  "list")
    list_configs_in_db # set $CONFIG_FILES array
    if [[ "${#CONFIG_FILES[@]}" -gt 0 ]]; then
      echo "The database contains the following config files:"
      for i in "${CONFIG_FILES[@]}"; do
        echo " - $i"
      done
    else
      echo "No config files in database."
    fi
    ;;
  "add")
    shift
    [[ "$#" -ge 1 ]] || fatal "--add requires at least 1 argument."
    for i in "$@"; do
      echo "Adding config file to database: ${i}..."
      insert_config_into_db "$i"
    done

    [[ "$NO_HINT" -ne 1 ]] || exit 0
    cat << EOF
Hint: to force an update on all server containers:

- for docker-compose:
  docker-compose up -d --force-recreate --no-deps server prioserver

- for Docker Swarm services:
  docker service update --force ${STACK:-<stackname>}_server &&
  docker service update --force ${STACK:-<stackname>}_prioserver
EOF
    ;;
  "connect")
    exec psql -h db -d instancecfg
    ;;
  *)
    usage
    exit 2
    ;;
esac
