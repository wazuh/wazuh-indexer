# =========
# 1st approach
# =========
# I ran the script from my host machine .It failed due to Javadoc not being 
# installed in my machine
# =========
# bash scripts/build.sh -v 2.11.0 -s false -p linux -a x64 -d rpm


# =========
# 2nd approach
# =========
# Use a Docker container. It worked and the rpm package was created
# =========
# docker run -ti --rm \
#     -v .:/usr/share/opensearch \
#     -w /usr/share/opensearch \
#     eclipse-temurin:17 \
#     bash scripts/build.sh -v 2.11.0 -s false -p linux -a x64 -d rpm


# =========
# 3rd approach
# =========
# Dockerfile
# =========
# docker build -t wazuh-indexer-builder:4.9.0 .
# docker run wazuh-indexer-builder:4.9.0
# docker run wazuh-indexer-builder:4.9.0 -v 2.11.0 -s false -p linux -a x64 -d rpm
# docker run -v .:/usr/share/opensearch wazuh-indexer-builder:4.9.0 -v 2.11.0 -s false -p linux -a x64 -d rpm

# mkdir wazuh-indexer-packages
# cd wazuh-indexer-packages
# docker run -v .:/usr/share/opensearch/artifacts wazuh-indexer-builder:4.9.0 


FROM eclipse-temurin:17 AS builder

# USER 1000:1000

ENV JAVA_HOME=/opt/java/openjdk

# Probably better to use a volume
COPY . /usr/share/opensearch

WORKDIR /usr/share/opensearch

CMD ["-v", "2.11.0", "-s", "false", "-p", "linux", "-a", "x64", "-d", "tar"]

ENTRYPOINT [ "bash", "scripts/build.sh" ]
