# backup-rsync

This project is designed as a general purpose tool for backing up docker volumes.

I use it for a boutique drupal/civicrm hosting service, i.e. where I have a number of sites on multiple nodes.

For this purposes of this project a "backup" is defined by:
1. A source, which is defined by a named volume, $VOLUME
2. A destination "directory" and protocol.
3. A process, by default 'rsync', potentially with various flags.

This image is designed to be invoked with 
a. the source volume mounted at /backup-source
b. the destination typically a host directory bind-mounted as /destination-source, or else defined as an external url of some kind.
c. the process by default as 'rsync', potentially something else, especially for the external url, including any parameters.

A simple example invocation to backup $VOLUME to /var/backup/docker/volume-backups/$VOLUME might be something like:

VOLUME=test; docker run --rm \
  --mount source=$VOLUME,target=/backup-source,readonly \
  --mount type=bind,source=/var/backup/docker/volume-backups/$VOLUME,target=/backup-dest \
  --mount type=bind,source=",target=/backup-dest \
  --mount type=bind,source="$(pwd)"/backups.json,target=/etc/backups.json,readonly \
  --mount type=bind,source="$(pwd)"/boto.config,target=/root/boto.config,readonly \
  blackflysolutions/backup-rsync

which would result in this being executed in the container:

rsync -az /backup-source/ /backup-dest

and attempts to rsync to a remote host and a gcloud bucket, if so configured.

## Options

When backing up to an external cloud (for example), you'll need to fill in and mount the boto config file as /root/.boto to provide the credentials. An example is provided.
