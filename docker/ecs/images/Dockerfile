FROM python:3.10

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install  -y git jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    git clone https://github.com/elastic/ecs.git && \
    pip install -r ecs/scripts/requirements.txt && \
    mkdir -p /source/ecs

# Change this to a volume
ADD docker/ecs/images/generate.sh /ecs/generate.sh
#ADD docker/ecs/images/entrypoint.sh entrypoint.sh
#ADD ecs/ /source/ecs
# This directory will be attached to a volume
RUN mkdir -p /source/ecs

RUN chmod +x /ecs/generate.sh

WORKDIR /ecs

ENTRYPOINT ["/bin/bash", "/ecs/generate.sh"]
