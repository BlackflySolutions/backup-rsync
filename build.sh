#!/bin/bash
docker build -t backup-rsync:latest .
docker build --disable-content-trust -t backup-rsync:google-cloud-cli-slim -f Dockerfile.google-cloud-cli-slim .
docker build --disable-content-trust -t backup-rsync:google-cloud-cli-alpine -f Dockerfile.google-cloud-cli-alpine .
# docker tag backup-rsync:latest blackflysolutions/backup-rsync:latest
