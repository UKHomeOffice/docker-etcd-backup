FROM alpine:3.13

ENV ETCD_VER v3.4.3

RUN apk add --update --no-cache bash curl tar

RUN curl -L https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz && \
    tar -xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /usr/local/bin && \
    rm /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz && \
    ln -s /usr/local/bin/etcd-${ETCD_VER}-linux-amd64/etcdctl /usr/local/bin/ && \
    ln -s /usr/local/bin/etcd-${ETCD_VER}-linux-amd64/etcd /usr/local/bin/

# aws cli v2 does not work on alpine - https://github.com/aws/aws-cli/issues/4685
RUN apk -Uuv add --no-cache groff less python3 py-pip && \
    pip install awscli six && \
    apk --purge -v del curl

COPY bin/backup.sh /usr/local/bin/backup.sh

ENTRYPOINT ["/usr/local/bin/backup.sh"]
