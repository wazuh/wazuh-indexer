## Wazuh indexer integrations

This folder contains integrations with third-party XDR, SIEM and cybersecurity software. 
The goal is to transport Wazuh's analysis to the platform that suits your needs.

### Amazon Security Lake

TBD

##### Usage

A demo of the integration can be started using the content of this folder and Docker.

```console
docker compose -f ./docker/amazon-security-lake.yml up -d
```

This docker compose project will bring a *wazuh-indexer* node, a *wazuh-dashboard* node, 
a *logstash* node and our event generator. On the one hand, the event generator will push events 
constantly to the indexer. On the other hand, logstash will constantly query for new data and
deliver it to the integration Python program, also present in that node. Finally, the integration 
module will prepare and send the data to the Amazon Security Lake's S3 bucket. 
<!-- TODO continue with S3 credentials setup -->

For production usage, follow the instructions in our documentation page about this matter.
(_when-its-done_)

As a last note, we would like to point out that we also use this Docker environment for development.

### Other integrations

TBD
