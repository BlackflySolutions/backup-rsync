FROM debian:latest
RUN apt-get update && apt-get install -y --no-install-recommends rsync jq gettext-base ssh-client && rm -rf /var/lib/apt/lists/* && apt-get purge -y
ADD run.sh /opt
ADD boto.config /root/.boto
RUN chmod +x /opt/run.sh
ENTRYPOINT [ "sh", "/opt/run.sh" ]
# default cmd runs jobs in backups.json
CMD ["backups-job"]
