FROM python:latest

RUN apt-get update && \
    apt-get upgrade && \
    apt-get install \
    git  \
    jq && \
    apt-get clean \ && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    git clone https://github.com/elastic/ecs.git && \
    pip install -r ecs/scripts/requirements.txt && \
    mkdir /wazuh-indexer

# Change this to a volume
ADD docker/ecs/images/generate.sh ecs/generate.sh
#ADD docker/ecs/images/entrypoint.sh entrypoint.sh
ADD ecs/ /wazuh-indexer/ecs

WORKDIR ecs/

ENTRYPOINT ["generate.sh"]
