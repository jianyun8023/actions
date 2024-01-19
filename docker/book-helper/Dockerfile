FROM debian:bookworm

RUN apt update && apt install -y curl jq calibre
WORKDIR /data
ARG TARGETARCH \
    bookhunter_version=0.14.3 \
    bookimporter_version=0.0.2
ENV ARCH=${TARGETARCH}

RUN curl -L https://github.com/bookstairs/bookhunter/releases/download/v${bookhunter_version}/bookhunter_${bookhunter_version}_linux_${ARCH}.tar.gz | tar xz -C /tmp/ bookhunter_${bookhunter_version}_linux_${ARCH}/bookhunter \
    && mv /tmp/bookhunter_${bookhunter_version}_linux_${ARCH}/bookhunter /usr/bin/bookhunter \
    && rm -rf /tmp/bookhunter_${bookhunter_version}_linux_${ARCH}
RUN curl -L https://github.com/jianyun8023/bookimporter/releases/download/v${bookimporter_version}/bookimport_${bookimporter_version}_linux_${ARCH}.tar.gz | tar xz -C /tmp/ bookimport_${bookimporter_version}_linux_${ARCH}/bookimport \
    && mv /tmp/bookimport_${bookimporter_version}_linux_${ARCH}/bookimport /usr/bin/bookimport \
    && rm -rf /tmp/bookimport_${bookimporter_version}_linux_${ARCH}

CMD [ "bash","-c","bookhunter version && bookimport version && calibredb --version && ebook-meta --version echo ${ARCH}" ]
