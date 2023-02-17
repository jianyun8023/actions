FROM alpine:latest
# Prepare environment
ARG SNELL_VERSION
ENV SNELL_VERSION ${SNELL_VERSION:-4.0.1}
ENV SNELL_PSK=RANDOM_KEY_HERE
ENV SNELL_PORT=6333
WORKDIR /app

# Install Snell
RUN set -ex; \
  apk update && apk add  wget unzip; \
  SNELL_VERSION=$SNELL_VERSION; \
  wget -O snell-server.zip "https://dl.nssurge.com/snell/snell-server-v${SNELL_VERSION}-linux-amd64.zip"; \
  unzip  snell-server.zip;\
  rm snell-server.zip; \
  chmod +x ./snell-server;

EXPOSE $SNELL_PORT
CMD [ "/app/snell-server" ]
