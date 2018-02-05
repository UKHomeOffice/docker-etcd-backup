#!/usr/bin/env bash

set -o errexit
set -o pipefail

[[ ${DEBUG} == 'true' ]] && set -x

# Use the v3 api
export ETCDCTL_API=3

ETCD_ENDPOINT=${ETCD_ENDPOINT:-https://localhost:4001}
CA_FILE=${CA_FILE:-/srv/kubernetes/ca.crt}
ETCD_CMD=${ETCD_CMD:-"etcdctl --cacert ${CA_FILE}"}

DATESTAMP=`date +%Y%m%d_%H%M`
BACKUP_PATH=${BACKUP_PATH:-/tmp}
BACKUP_FILE=${BACKUP_PATH}/etcd_backup.db
BACKUP_TAR=${BACKUP_PATH}/etcd_${DATESTAMP}.tar.gz
ETCD_ENDPOINTS=`${ETCD_CMD} --endpoints ${ETCD_ENDPOINT} member list | awk '{print $5}' | tr '\n' ',' | sed s/.$//`

function error_exit() {
  echo "ERROR: ${1}"
  exit 1
}

function info() {
  echo "INFO: ${1}"
}

function move_s3() {
  local destpath=${S3_PATH}${BACKUP_TAR#${BACKUP_PATH}}

  # Noop when no backup
  [[ -z ${S3_PATH} ]] && \
    return 0

  # Check destination before uploading
  if [[ -f ${BACKUP_TAR} ]] ; then
    info "Uploading backed up file to s3"
    aws s3 mv ${BACKUP_TAR} ${destpath} --sse aws:kms --sse-kms-key-id ${KMS_ID}
  else
    error_exit "Backed up file does not exist"
    exit 1
  fi
}

function tar_backup() {
  (
    cd ${BACKUP_PATH}
    tar -cvzf ${BACKUP_TAR} ${BACKUP_FILE}
    rm -fr ${BACKUP_FILE}
  )
  info "Backed up to:${BACKUP_FILE}"
}

# Creates a backup of the current cluster
function clusterbackup() {

  info "Start Cluster Backup"
  ${ETCD_CMD} --endpoints ${ETCD_ENDPOINTS} snapshot save ${BACKUP_FILE}
  tar_backup
  move_s3
}

[[ -z ${ETCD_ENDPOINTS} ]] && error_exit "Could not find etcd endpoints"

clusterbackup
