#!/bin/bash

# Parameters
OPTION="$1"
#echo $OPTION
#cat /etc/backups.json
if [ "$OPTION" = "backups-job" ]; then
# backup according to /etc/backups.json
# backups is the top level keys of the json file, machine names of the backups to run
# each key has to define source, destination and process
  backups="$(jq -r 'keys_unsorted | map(@sh) | join(" ")' /etc/backups.json)"
  eval "set -- $backups"
  for backup; do
    export backup
    source="/backup-source/"
    destination="$(jq -r '.[env.backup].destination' /etc/backups.json | envsubst)"
    process="$(jq -r '.[env.backup].process' /etc/backups.json | envsubst)"
    RUN="$process $source $destination"
    # echo $RUN
    $RUN
  done
else
  exec "$@"
fi
