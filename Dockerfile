FROM alpine:3.6
ENV ETCD_VER v3.0.17
RUN apk add --update --no-cache bash curl jq tar rsync

RUN curl -L  https://github.com/coreos/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz && \
    tar -xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /usr/local/bin && \
    rm /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz && \
    ln -s /usr/local/bin/etcd-${ETCD_VER}-linux-amd64/etcdctl /usr/local/bin/ && \
    ln -s /usr/local/bin/etcd-${ETCD_VER}-linux-amd64/etcd /usr/local/bin/

RUN apk -Uuv add --no-cache groff less python py-pip && \
    pip install awscli && \
    apk --purge -v del py-pip

ADD bin/* /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/backup.sh"]
