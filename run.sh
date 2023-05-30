#!/bin/bash

# Parameters
COMMAND="$1"
OPTION_TYPE="$2"
KEY_FILE="$3"
OPTIONS_KEY=".[env.backup].options.${OPTION_TYPE}"
#echo $COMMAND
#echo $OPTION_TYPE
if [ ! -z "$KEY_FILE"]; then
  gcloud auth login --cred-file=$KEY_FILE 
fi
#echo $OPTIONS_KEY
#cat /etc/backups.json
if [ "$COMMAND" = "backups-job" ]; then
  # backup according to /etc/backups.json
  # the backups variable gets set as the top level keys of the json file, i.e. machine names of the backups to run
  # each key has to define a destination and process
  # and may define additional options per 'option type', where OPTION_TYPE is a mechanism for the calling script to pass in an extra argument
  backups="$(jq -r 'keys_unsorted | map(@sh) | join(" ")' /etc/backups.json)"
  eval "set -- $backups"
  for backup; do
    export backup
    source="/backup-source/"
    destination="$(jq -r '.[env.backup].destination' /etc/backups.json | envsubst)"
    process="$(jq -r '.[env.backup].process' /etc/backups.json | envsubst)"
    # include options for this OPTION TYPE in the process if defined in the json file
    if options="$(jq -er $OPTIONS_KEY /etc/backups.json | envsubst)"; then
      RUN="$process $options $source $destination"
    else
      RUN="$process $source $destination"
    fi
    echo $RUN
    $RUN
  done
else
  exec "$@"
fi
