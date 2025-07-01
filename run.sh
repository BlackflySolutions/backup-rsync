#!/bin/bash
# Backup according to the config file /etc/backups.json, or if it exists, /backup-source/conf/backups.json
# which is assumed to be a local addition for that volume (or a replacement if no /etc/backups.json if provided)
# Parameters
COMMAND="$1"
OPTION_TYPE="$2"
KEY_FILE="$3"
OPTIONS_KEY=".[env.backup].options.${OPTION_TYPE}"
SUBDIRECTORIES_KEY=".[env.backup].subdirectories.${OPTION_TYPE}"
CLEANUP_KEY=".[env.backup].cleanup.${OPTION_TYPE}"
#echo $COMMAND
#echo $OPTION_TYPE
if [ ! -z "${KEY_FILE}" ]; then
  #echo "Initializing gcloud"
  gcloud --no-user-output-enabled auth login --cred-file=$KEY_FILE
  #echo "Finished initializing gcloud"
fi
#echo $OPTIONS_KEY
#cat /etc/backups.json
#cat /backup-source/conf/backups.json
# We accept four different COMMANDS for four different usages 
# How the actual 'backup' request is run will depend on that choice
if [ "$COMMAND" = "backups-job" ] || [ "$COMMAND" = "backups-status" ] || [ "$COMMAND" = "backups-report" ] || [ "$COMMAND" = "backups-cleanup" ]; then
  # backup according to a backups.json file, which contains an array representation of the backup configuration
  # the backups variable gets set as the top level keys of the json file, i.e. machine names of the backups to run
  # each key has to define a destination and process
  # and may define additional options per 'option type', where OPTION_TYPE is a mechanism for the calling script to pass in an extra argument
  # OPTION_TYPE allows for variations on different file structures, e.g. for wordpress vs drupal and volumes that only contain sites/default, for example.
  CONFIG_FILE="/etc/backups.json"
  if [ -f /backup-source/conf/backups.json ]; then
    CONFIG_FILE_LOCAL="/backup-source/conf/backups.json"
    if [ -f $CONFIG_FILE ]; then
      CONFIG_FILE_COMBINED="/tmp/backups.json"
      jq -s '.[0] * .[1]' $CONFIG_FILE $CONFIG_FILE_LOCAL > $CONFIG_FILE_COMBINED
      CONFIG_FILE=$CONFIG_FILE_COMBINED
    else
      CONFIG_FILE=$CONFIG_FILE_LOCAL
    fi
  fi
  backups="$(jq -r 'keys_unsorted | map(@sh) | join(" ")' $CONFIG_FILE)"
  eval "set -- $backups"
  for backup; do
    export backup
    #echo "Running $backup"
    source="/backup-source/"
    export destination="$(jq -r '.[env.backup].destination' $CONFIG_FILE | envsubst)"
    if prefix="$(jq -re '.[env.backup].prefix' $CONFIG_FILE | envsubst)"; then
      if [ "null" == "$prefix" ]; then
        prefix=""
      fi
    fi
    export prefix
    # echo "Destination is $prefix$destination, now check for subdirs"
    # include subdir for this OPTION TYPE as addition to source and destination directory if defined in the json file
    if subdir="$(jq -re $SUBDIRECTORIES_KEY $CONFIG_FILE | envsubst)"; then
      if [ "null" != "$subdir" ]; then
        #echo "Found a non-null subdirectory"
        source="${source}${subdir}/"
        export destination="${destination}/${subdir}"
      fi
    fi
    #echo "Final destination is now $destination"
    # see if I need to run something to initialize the remote destination/subdir directory (may use subdir as an env variable!)
    if initialize="$(jq -re '.[env.backup].initialize' $CONFIG_FILE | envsubst)"; then
      if [ "$initialize" = "null" ]; then
        initialize=""
      fi
    fi
    #echo "Initialize is $initialize"
    # if source isn't a directory, we'll skip this backup!
    #echo "Source is $source"
    if [ -d "$source" ]; then
      # include options for this OPTION TYPE in the process if defined in the json file
      #echo "Getting options"
      if options="$(jq -re $OPTIONS_KEY $CONFIG_FILE)"; then
        if [ "$options" = "null" ]; then
          options=""
        fi
        #echo "found options!"
      fi
      #echo "Options is $options"
      # special hackish setting of options = ignore means skip it
      if [ "ignore" != "$options" ]; then
        # test for simpler RUN for backups-report, or backups-cleanup, skipped if configuration is not defined
        if [ "$COMMAND" = "backups-report" ]; then
          RUN=""
          if report="$(jq -re '.[env.backup].report' $CONFIG_FILE | envsubst)"; then
            if [ "$report" != "null" ]; then
              RUN="$report"
            fi
          fi
        #echo "running reporting"
        #echo $RUN
        elif [ "$COMMAND" = "backups-cleanup" ]; then
          RUN=""
          if cleanup="$(jq -re $CLEANUP_KEY $CONFIG_FILE | envsubst)"; then
            if [ "null" != "$cleanup" ]; then
              RUN="$cleanup"
            fi
          fi
        else
          # assume I'm doing a backups job or status, use the (required) process configuration
          process="$(jq -r '.[env.backup].process' $CONFIG_FILE | envsubst)"
          if [ "$COMMAND" = "backups-status" ]; then
            extra_args=" -n --stats"
          else
            extra_args=""
          fi
          # generate the RUN string
          RUN="$process $extra_args $options $source $prefix$destination"
        fi
        #echo "testing if I have a RUN"
        if [ ! -z "$RUN" ]; then
          if [ ! -z "$initialize" ]; then
            echo "$initialize"
            $initialize
          fi
          echo "$RUN"
          $RUN
        fi
      fi
    #else
    #echo "Source does not exist, skipping"
    fi
  done
else
  #echo "Running explicit cmd"
  exec "$1"
fi
