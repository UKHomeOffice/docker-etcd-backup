# docker-etcd-backup

[![Build Status](https://drone.digital.homeoffice.gov.uk/api/badges/UKHomeOffice/docker-etcd-backup/status.svg)](https://drone.digital.homeoffice.gov.uk/UKHomeOffice/docker-etcd-backup)

Cluster Backup process for etcd3

## Cluster backup

A cluster backup is made with `etcdctl backup` which strips node information thus requiring a cluster rebuild. This backup is saved as a tar file in the `/tmp` directory by default. If `S3_PATH` is specified it will be uploaded to S3 and encrypted with the KMS key that you have specified using the `KMS_ID` variable.

## Environment Variables

* `BACKUP_PATH:-/tmp` The root directory to backup to
* `ETCD_ENDPOINT:-https://localhost:4001`
* `S3_PATH` Will backup to this path and delete off host when done
* `KMS_ID` Specifies which KMS encryption key to use in S3
* `CA_FILE:-/srv/kubernetes/ca.crt` Path to the CA for your etcd cluster
* `ETCDCTL_CERT` Path to the cert for your etcd cluster
* `ETCDCTL_KEY` Path to the private key for your etcd cert

## Restore process

### From Cluster Backup

1. Stop ETCD everywhere
2. See: https://github.com/coreos/etcd/blob/master/Documentation/v2/admin_guide.md#disaster-recovery
