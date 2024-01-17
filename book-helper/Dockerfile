FROM debian:bookworm

WORKDIR /data
ARG ARCH=amd64
ENV ARCH=${ARCH}
RUN apt update && apt install -y curl jq calibre
RUN curl -L https://github.com/bookstairs/bookhunter/releases/download/v0.14.0/bookhunter_0.14.0_linux_$ARCH.tar.gz | tar xz -C /tmp/ bookhunter_0.14.0_linux_$ARCH/bookhunter && mv /tmp/bookhunter_0.14.0_linux_$ARCH/bookhunter /usr/bin/bookhunter && rm -rf /tmp/bookhunter_0.14.0_linux_amd64
RUN curl -L https://github.com/jianyun8023/bookimporter/releases/download/v0.0.2/bookimport_0.0.2_linux_$ARCH.tar.gz | tar xz -C /tmp/ bookimport_0.0.2_linux_$ARCH/bookimport && mv /tmp/bookimport_0.0.2_linux_$ARCH/bookimport /usr/bin/bookimport && rm -rf /tmp/bookimport_0.0.2_linux_amd64

CMD [ "bash","-c","bookhunter version && bookimport version && calibredb --version && ebook-meta --version echo $ARCH" ]
