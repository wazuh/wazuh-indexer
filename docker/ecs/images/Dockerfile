FROM python:latest

RUN apt-get update && \
    apt-get upgrade && \
    apt-get install \
    git && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    git clone https://github.com/elastic/ecs.git

# Change this to a volume
ADD docker/ecs/images/generate.sh ecs/generate.sh
ADD . wazuh-indexer/
