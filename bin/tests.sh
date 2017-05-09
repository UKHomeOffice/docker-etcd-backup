#!/usr/bin/env bash

set -o errexit
set -o pipefail

[[ ${DEBUG} == 'true' ]] && set -x

export ETCD_ENDPOINTS=http://etcd2:2379
export ETCD_DATA_DIR=${ETCD_DATA_DIR:-${PWD}/etcd2}
export ETCD_BACKUP_DIR=${ETCD_BACKUP_DIR:-${ETCD_DATA_DIR}/backup}
export IMAGE=${IMAGE:-quay.io/ukhomeofficedigital/etcd-backup:latest}

function start_etcd() {

  docker stop etcd2 && docker rm etcd2 && true

  mkdir -p ${ETCD_DATA_DIR}

  docker run -d \
    --name=etcd2 \
    -p 2379:2379 \
    -v ${ETCD_DATA_DIR}:${ETCD_DATA_DIR} \
    -e ETCD_DATA_DIR \
    -e ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379 \
    -e ETCD_ADVERTISE_CLIENT_URLS=${ETCD_ENDPOINTS} \
    quay.io/coreos/etcd:v2.3.7
  docker logs etcd2 -f &

  # Wait for data...
  while ! test -d ${ETCD_DATA_DIR}/member ; do
    sleep 1
  done

}

start_etcd

backupnow_time=$(date -u --date='5sec' +'%H%M')
cluster_time=$(date -u --date='1min 5sec' +'%H%M')
node_time1=$(date -u --date='1min 10sec' +'%H%M')
node_time2=$(date -u --date='2min 10sec' +'%H%M')

# Add test for backup now flag:
mkdir -p ${ETCD_BACKUP_DIR}/bunf
touch ${ETCD_BACKUP_DIR}/bunf

# Run the backup container
docker run -i \
  --link etcd2 \
  -v ${ETCD_DATA_DIR}:${ETCD_DATA_DIR} \
  -e DEBUG \
  -e ETCD_DATA_DIR \
  -e ETCD_ENDPOINTS \
  -e ETCD_BACKUP_DIR \
  -e NODE_BACKUP_TIMES="${node_time1} ${node_time2}" \
  -e CLUSTER_BACKUP_TIMES="${cluster_time}" \
  -e EXIT_AT=${node_time2} \
  --rm \
  ${IMAGE}

echo "TEST - can we find the files"
# test that all the backups are present
for filename in default_${backupnow_time}.tar.gz cluster_${backupnow_time}.tar.gz cluster_${cluster_time}.tar.gz default_${node_time1}.tar.gz default_${node_time2}.tar.gz ; do
  files=$(find ${ETCD_BACKUP_DIR})
  if echo "$files" | grep ${filename} ; then
    echo "TEST PASSED for backup found - ${filename}"
  else
    echo "TEST FAILED - backup NOT found ${filename}"
    exit 1
  fi
done

# test that all the backups can be used:
docker stop etcd2 && true

for backup in $(find ${ETCD_BACKUP_DIR} -name *.tar.gz) ; do
    rm -fr ${ETCD_DATA_DIR}/member
    tar -xzf ${backup} -C ${ETCD_DATA_DIR}
    if [[ ! -d ${ETCD_DATA_DIR}/member ]]; then
      echo "TEST FAILED - missing files expected from restore (no ./member dir)"
      exit 1
    fi
    start_etcd
    echo ""
    if curl -QL http://127.0.0.1:2379/health 2> /dev/null | jq -r .health | grep "true" ; then
      echo "TEST FAILED for restored backup:${backup}: cluster not healthy!"
      exit 1
    else
      echo "TEST PASSED for restored backup:${backup}"
    fi
    docker stop etcd2
done

echo "All TESTS PASSED"
