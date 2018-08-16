#!/usr/bin/env bash

set -o errexit
set -o pipefail

[[ ${DEBUG} == 'true' ]] && set -x

export NC='\e[0m'
export GREEN='\e[0;32m'
export YELLOW='\e[0;33m'
export RED='\e[0;31m'

log()     { (2>/dev/null echo -e "$@${NC}"); }
info()    { log "${GREEN}[INFO] $@"; }
warning() { log "${YELLOW}[WARNING] $@"; }
error()   { log "${RED}[ERROR] $@"; }

export DATESTAMP=`date +%Y%m%d_%H%M`
export BACKUP_PATH=${BACKUP_PATH:-/tmp}
export BACKUP_FILE=${BACKUP_PATH}/etcd_backup.db
export BACKUP_TAR=${BACKUP_PATH}/etcd_${DATESTAMP}.tar.gz
export ETCDCTL_API=3
export ETCDCTL_CACERT=${ETCDCTL_CACERT:-/srv/kubernetes/ca.crt}
export ETCDCTL_ENDPOINTS=${ETCDCTL_ENDPOINTS:-https://localhost:2379}
export ETCDCTL_ENDPOINTS=`etcdctl member list | awk '{print $5}' | tr '\n' ',' | sed s/.$//`

function move_s3() {
  # No-op when no backup
  if [[ -z ${S3_PATH} ]]; then
    warning "No 'S3_PATH' has been defined, backup is located in ${BACKUP_TAR}"
    exit 0
  fi

  local destpath=${S3_PATH}${BACKUP_TAR#${BACKUP_PATH}}
  local s3cli_args=""

  # Check destination before uploading
  if [[ -f ${BACKUP_TAR} ]]; then
    info "Uploading backed up file to s3"
    if [[ -n ${S3_CA_BUNDLE} ]]; then
      s3cli_args+=" --ca-bundle ${S3_CA_BUNDLE}"
    elif [[ ${S3_NO_SSL_VERIFY} == true ]]; then
      s3cli_args+=" --no-verify-ssl"
    fi
    if [[ -n ${S3_AWS_ENDPOINT} ]]; then
      s3cli_args+=" --endpoint-url ${S3_AWS_ENDPOINT}"
    fi
    if [[ -n ${S3_KMS_ID} ]]; then
      s3cli_args+=" --sse aws:kms --sse-kms-key-id ${S3_KMS_ID}"
    fi
    aws s3 mv ${s3cli_args} ${BACKUP_TAR} ${destpath}
  else
    error "Backed up file does not exist"
    exit 1
  fi
}

function tar_backup() {
  (
    cd ${BACKUP_PATH}
    tar -cvzf ${BACKUP_TAR} ${BACKUP_FILE}
    rm -fr ${BACKUP_FILE}
  )
  info "Backed up to: ${BACKUP_TAR}"
}

# Creates a backup of the current cluster
function clusterbackup() {
  info "Start Cluster Backup"
  etcdctl snapshot save ${BACKUP_FILE}
  tar_backup
  move_s3
}

[[ -z ${ETCDCTL_ENDPOINTS} ]] && error "Could not find etcd endpoints" && exit 1

clusterbackup
