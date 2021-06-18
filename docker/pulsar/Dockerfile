FROM adoptopenjdk:8-jdk-hotspot
# Prepare environment
ENV PULSAR_HOME=/pulsar
ENV PATH=$PULSAR_HOME/bin:$PATH
RUN groupadd --system --gid=9999 pulsar && useradd --system --home-dir $PULSAR_HOME --uid=9999 --gid=pulsar pulsar
WORKDIR $PULSAR_HOME

ARG PULSAR_VERSION
ENV PULSAR_VERSION ${PULSAR_VERSION}
# Install Pulsar
RUN set -ex; \
  apt-get update && apt-get install -y wget; \
  PULSAR_VERSION=$PULSAR_VERSION; \
  wget -O pulsar.tgz "https://archive.apache.org/dist/pulsar/pulsar-${PULSAR_VERSION}/apache-pulsar-${PULSAR_VERSION}-bin.tar.gz"; \
  tar -xf pulsar.tgz --strip-components=1; \
  rm pulsar.tgz; \
  \
  chown -R pulsar:pulsar .;

EXPOSE 6650 8080
CMD [ "bin/pulsar","standalone" ]
