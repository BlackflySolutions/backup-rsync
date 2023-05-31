#!/bin/bash

# Parameters
COMMAND="$1"
OPTION_TYPE="$2"
KEY_FILE="$3"
OPTIONS_KEY=".[env.backup].options.${OPTION_TYPE}"
SUBDIRECTORIES_KEY=".[env.backup].subdirectories.${OPTION_TYPE}"
#echo $COMMAND
#echo $OPTION_TYPE
if [ ! -z "${KEY_FILE}" ]; then
  gcloud --no-user-output-enabled auth login --cred-file=$KEY_FILE
fi
#echo $OPTIONS_KEY
#cat /etc/backups.json
if [ "$COMMAND" = "backups-job" ] || [ "$COMMAND" = "backups-status" ] || [ "$COMMAND" = "backups-report" ]; then
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
    # see if I need to run something to initialize the destination directory
    if initialize="$(jq -re '.[env.backup].initialize' /etc/backups.json | envsubst)"; then
      if [ "$initialize" = "null" ]; then
        initialize=""
      fi
    fi
    # include subdir for this OPTION TYPE as addition to source and destination directory if defined in the json file
    if subdir="$(jq -er $SUBDIRECTORIES_KEY /etc/backups.json | envsubst)"; then
      if [ "null" != "$subdir" ]; then
        source="${source}${subdir}/"
        destination="${destination}/${subdir}"
      fi
    fi
    # if source isn't a directory, we'll skip this backup!
    if [ -d "$source" ]; then
      # if I'm reporting, I'll just do it now, ignoring options and extra args, etc.
      if [ "$COMMAND" = "backups-report" ]; then
        report="$(jq -r '.[env.backup].report' /etc/backups.json | envsubst)"
        RUN="$report $destination"
      else
        process="$(jq -r '.[env.backup].process' /etc/backups.json | envsubst)"
        if [ "$COMMAND" = "backups-status" ]; then
          extra_args=" -n --stats"
        else
          extra_args=""
        fi
        # include options for this OPTION TYPE in the process if defined in the json file
        if options="$(jq -er $OPTIONS_KEY /etc/backups.json | envsubst)"; then
          # hackish way to skip one of the option types
          if [ "$options" = "ignore" ]; then
            RUN=""
          elif [ "$options" = "null" ]; then
            RUN="$process $extra_args $source $destination"
          else
            RUN="$process $extra_args $options $source $destination"
          fi
        else
          RUN="$process $extra_args $source $destination"
        fi
      fi
      echo $RUN
      if [ ! -z "$initialize" ]; then
        $initialize $destination
      fi
      $RUN
    fi
  done
else
  exec "$@"
fi
