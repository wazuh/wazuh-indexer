# Logstash image of Elastic: logstash-oss (default) or logstash.
ARG LOGSTASH_IMAGE=docker.elastic.co/logstash/logstash-oss
ARG LOGSTASH_OSS_VERSION
FROM ${LOGSTASH_IMAGE}:${LOGSTASH_OSS_VERSION}

ENV LOGSTASH_KEYSTORE_PASS "SecretPassword"
ENV LS_PATH "/usr/share/logstash"
USER logstash

# Input to read from the Wazuh indexer and output to write to OpenSearch, at the versions
# the integrations are tested with. The plugin manager needs more than the default 1 GB heap.
# https://github.com/elastic/logstash/issues/6600
ARG LOGSTASH_INPUT_OPENSEARCH_VERSION=1.0.0
ARG LOGSTASH_OUTPUT_OPENSEARCH_VERSION=2.1.1
RUN LS_JAVA_OPTS="-Xms2g -Xmx2g" logstash-plugin install \
      --version ${LOGSTASH_INPUT_OPENSEARCH_VERSION} logstash-input-opensearch && \
    LS_JAVA_OPTS="-Xms2g -Xmx2g" logstash-plugin install \
      --version ${LOGSTASH_OUTPUT_OPENSEARCH_VERSION} logstash-output-opensearch

# logstash-output-opensearch 2.1.1 calls File.exists?, which Ruby 3.4 (Logstash 9) no longer has,
# so it cannot install the index template (opensearch-project/logstash-output-opensearch#288).
RUN sed -i 's/::File\.exists?/::File.exist?/' \
      /usr/share/logstash/vendor/bundle/jruby/*/gems/logstash-output-opensearch-${LOGSTASH_OUTPUT_OPENSEARCH_VERSION}-java/lib/logstash/outputs/opensearch/template_manager.rb

# Copy and run the setup.sh script to create and configure a keystore for Logstash.
COPY --chown=logstash:logstash ./setup.sh /usr/share/logstash/bin/setup.sh
RUN bash /usr/share/logstash/bin/setup.sh

# Disable ECS compatibility
RUN `echo "pipeline.ecs_compatibility: disabled" >> /usr/share/logstash/config/logstash.yml`

WORKDIR /usr/share/logstash
