#!/usr/bin/env bash

set -o errexit
set -o pipefail

[[ ${DEBUG} == 'true' ]] && set -x

# Supported external envs:
CLUSTER_BACKUP_TIMES=${CLUSTER_BACKUP_TIMES:-0000}
NODE_BACKUP_TIMES=${NODE_BACKUP_TIMES:-0100 0700 1300 1900}
ENV_FILE=${ENV_FILE:-/etc/environment}
ETCD_ENDPOINTS=${ETCD_ENDPOINTS:-https://localhost:2379}

# Internal constants
rel_etcd_backup_path=./member
rel_bak="%Y/%m/%d"
LOCAL_BAK="${ETCD_BACKUP_DIR}/${rel_bak}"

function error_exit() {
  echo "${1}"
  exit 1
}

function gettime() {
  date +%H%M
}

function is_master() {
  if [[ -d ${ETCD_DATA_DIR}/member ]]; then
    return 0
  else
    return 1
  fi
}

function s3_exists() {
  local s3file="${1}"

  if ! aws s3 ls ${s3file} ; then
    ec=${PIPESTATUS[*]}
    if [[ ${ec} -ne 1 ]]; then
      error_exit "Error detecting s3 file ${s3file}"
    else
      # file doesn't exist
      return 1
    fi
  else
    # file exists in s3
    return 0
  fi
}

function move_s3() {
  local sourcefile=${1}
  local destpath=${S3_PATH}${sourcefile#${ETCD_BACKUP_DIR}}

  # Noop when no backup
  [[ -z ${S3_PATH} ]] && \
    return 0

  # Check destination before uploading
  if ! s3_exists ${destpath} ; then
    aws s3 mv ${sourcefile} ${destpath} --sse aws:kms --sse-kms-key-id ${KMS_ID}
  else
    # Don't keep a backup that are already copied
    # - this should only happen for cluster backups
    rm ${sourcefile}
  fi
}

function setnode() {
  if [[ ! -z "${NODE_BACKUP_TIMES}" ]]; then
    if [[ -z "${NODE_NAME}" ]]; then
      echo "Auditing NODE_NAME from ${ETCD_ENDPOINTS}..."
      NODE_NAME=$(curl -QL ${ETCD_ENDPOINTS}/v2/stats/self 2>/dev/null | jq -r ".name")
      echo "NODE_NAME=${NODE_NAME}"
    fi
  fi
}

# Creates a local backup of the current cluster
function clusterbackup() {

  echo "Start Cluster Backup"
  local backup_path=$(date "+${LOCAL_BAK}")
  local time=$(gettime)
  local file=${backup_path}/cluster_${time}.tar.gz

  mkdir -p ${backup_path}
  echo "Backing up cluster data"
  etcdctl backup --data-dir=${ETCD_DATA_DIR} --backup-dir=${backup_path}
  (
    cd ${backup_path}
    tar -cvzf ${file} ${rel_etcd_backup_path}
  )
  rm -fr ${backup_path}/member
  echo "Backed up to:${file}"
  move_s3 ${file}
}

# Will create a backup file and push to S3
function nodebackup() {

  echo "Start Node Backup"
  local backup_path=$(date "+${LOCAL_BAK}")
  local time=$(gettime)
  local file=${backup_path}/${NODE_NAME}_${time}.tar.gz

  mkdir -p ${backup_path}
  echo "Backing up node data for ${NODE_NAME}"
  (
    cd ${ETCD_DATA_DIR}
    tar -cvzf ${file} ${rel_etcd_backup_path}
  )
  echo "Backed up to:${file}"
  move_s3 ${file}
}

function istime() {
  local backuptime=${1}
  local time=${2:-$(gettime)}

  # This only compares minute's not seconds.
  # It's very unlikely we backup more often than once a minute
  if [[ "${time}" == "${backuptime}" ]]  ; then
    return 0
  else
    return 1
  fi
}

echo "Startup time:$(gettime)"
echo "Backup times:"
echo "  cluster: [${CLUSTER_BACKUP_TIMES}]"
echo "  node: [${NODE_BACKUP_TIMES}]"

[[ ! -z ${EXIT_AT} ]] && \
  echo "Exit time: ${EXIT_AT}"

[[ -z "${CLUSTER_BACKUP_TIMES}${NODE_BACKUP_TIMES}" ]] && \
  error_exit "Must specify one, or both of \$CLUSTER_BACKUP_TIMES and \$NODE_BACKUP_TIMES"

[[ -z ${ETCD_DATA_DIR} ]] && \
  error_exit "Must specify a root etcd data path \$ETCD_DATA_DIR"

[[ -z ${ETCD_BACKUP_DIR} ]] && \
  error_exit "Must specify a root backup path \$ETCD_BACKUP_DIR"

if [[ ! -z ${S3_PATH} ]] && is_master ; then
  setnode
  testfile=${ETCD_BACKUP_DIR}/test-${NODE_NAME}
  echo "Testing backup of ${testfile}"
  echo "test" > ${testfile}
  move_s3 ${testfile}
  echo "Moving backups to ${S3_PATH}/YY/MM/DD/HHMM...tar.gz"
fi

while true; do

  # Needed to dynamically get node id from within daemon-set
  if [[ -f ${ENV_FILE} ]]; then
    source ${ENV_FILE}
  fi

  if ! is_master ; then
    [[ ${nooped} -ne 1 ]] && echo "No Data, Noop."
    nooped=1
    sleep 60
    continue
  else
    nooped=0
    setnode
  fi
  backedup="false"
  checktime=$(gettime) # Prevent dependency on current time moving on..
  for backuptime in ${CLUSTER_BACKUP_TIMES} ; do
    if istime ${backuptime} ${checktime}; then
      echo "Time:$(gettime)"
      clusterbackup
      backedup="true"
    fi
  done
  for backuptime in ${NODE_BACKUP_TIMES} ; do
    if istime ${backuptime} ${checktime}; then
      echo "Time:$(gettime)"
      nodebackup
      backedup="true"
    fi
  done
  if istime ${EXIT_AT} ${checktime}; then
    echo "Requested exit time reached EXIT_AT=${EXIT_AT}"
    break
  fi
  if [[ ${backedup} == 'true' ]]; then
    sleep 60 # Ensure we skip past the checked time (we don't want to run twice in the same minute)
  else
    sleep 15 # four attempts a minute to match a given time (we only check minutes)
  fi
done
echo "Exiting at:$(gettime)"
echo ""