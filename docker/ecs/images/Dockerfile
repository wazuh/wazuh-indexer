FROM python:latest

RUN apt-get update && \
    apt-get upgrade && \
    apt-get install \
    git && \
    apt-get clean \ && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    git clone https://github.com/elastic/ecs.git

# Change this to a volume
ADD docker/ecs/images/generate.sh ecs/generate.sh
ADD docker/ecs/images/entrypoint.sh entrypoint.sh
ADD . wazuh-indexer/

ENTRYPOINT ["entrypoint.sh"]
