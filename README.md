# Docker Image: ETCD Backup

[![Build Status](https://drone-gh.acp.homeoffice.gov.uk/api/badges/UKHomeOffice/docker-etcd-backup/status.svg)](https://drone-gh.acp.homeoffice.gov.uk/UKHomeOffice/docker-etcd-backup)

Cluster Backup process for ETCD v3

## Cluster backup

A cluster backup is made with `etcdctl backup` which strips node information thus requiring a cluster rebuild. This backup is saved as a tar file in the `/tmp` directory by default. If `S3_PATH` is specified it will be uploaded to S3 and encrypted with the KMS key that you have specified using the `KMS_ID` variable.

## Configurable options

The following environment variables can be passed in to configure etcd backups for your environment:

| ENVIRONMENT VARIABLE | DESCRIPTION | REQUIRED | DEFAULT VALUE |
|----------------------|-------------|----------|---------------|
| BACKUP_PATH | Set the directory to copy the etcd backup to | N | `/tmp` |
| ETCDCTL_CACERT | Verify the ETCD certificate using this CA bundle | N | `/srv/kubernetes/ca.crt` |
| ETCDCTL_CERT | TLS certificate file for ETCD | N | `/srv/kubernetes/etcd.pem` |
| ETCDCTL_ENDPOINT | ETCD endpoint | N | `https://localhost:2379` |
| ETCDCTL_KEY | TLS key file for ETCD | N | `/srv/kubernetes/etcd-key.pem` |
| S3_AWS_ENDPOINT | Custom S3 endpoint URL | N | NULL |
| S3_CA_BUNDLE | The CA bundle for the S3 endpoint | N | NULL |
| S3_KMS_ID | A KMS ID to use for encrypting the backups in S3 | N | NULL |
| S3_NO_SSL_VERIFY | Skip TLS verify for the S3 endpoint | N | `false` |
| S3_PATH | Provide the S3 bucket path to copy the backup to, e.g. `s3://my-bucket`<br>If unset, the backup is left in `BACKUP_PATH` | N | NULL |

## Restore process

1. Stop ETCD everywhere
2. See: https://etcd.io/docs/current/op-guide/recovery/
