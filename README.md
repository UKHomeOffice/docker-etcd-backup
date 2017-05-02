# docker-etcd-backup

Backup process for etcd2 (etcd3 is much simpler)

## Design

Due to the complexities of restoring a cluster two approaches are used:

1. node backup (quick to restore but dependant on a quorum of restored nodes)
2. cluster backup (complex to restore)

## Node backup

A node backup (tar) is performed throughout the day. Each node will push all data content to a backup location.

## Cluster backup

A cluster backup is taken once a day. Only one node will save the latest backup.

A cluster backup is made with `etcdctl backup` which strips node information thus requiring a cluster rebuild.

## Environment Variables

* `CLUSTER_BACKUP_TIMES:-0000` Times to carry out node agnostic cluster backups
* `NODE_BACKUP_TIMES:-0100 0700 1300 1900` Times to backup node data
* `ETCD_DATA_DIR` Location to backup from (will result in NOOP if not present)
* `ETCD_BACKUP_DIR` The root directory to backup to
* `ENV_FILE:-/etc/environment` Will be sourced if specified
* `NODE_NAME` Will be audited from ETCD_ENDPOINTS if not present
* `ETCD_ENDPOINTS:-https://localhost:2379`

## Restore process

### From Node Backup

1. Stop ETCD everywhere
2. Restore the latest .tar.gz file from `${ETCD_BACKUP_DIR}/YY/MM/DD/*.tar.gz` to the `${ETCD_DATA_DIR}`

### From Cluster Backup

1. Stop ETCD everywhere
2. See: https://github.com/coreos/etcd/blob/master/Documentation/v2/admin_guide.md#disaster-recovery
