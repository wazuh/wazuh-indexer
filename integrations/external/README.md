# Wazuh integrations

This folder contains a Docker compose project to test integrations with Splunk and Elasticsearch, from the Wazuh Indexer as well as from the Wazuh manager.

## Services

The Docker Compose project contains these services:

- 1x Splunk Indexer 9.0.4.
- 1x Wazuh stack (indexer, dashboard and manager). The manager container also has a Splunk Forwarder and a Logstash installation in the `/opt` folder.
- 1x Elastic stack (Elasticsearch, Kibana and the setup container).
- 1x OpenSearch stack (OpenSearch and OpenSearch Dashboards).
- 1x Logstash 8.6.2.
- 1x Generator, to generate the certificates and download the required packages.

### Additional content

- Dashboards for Splunk, Kibana and OpenSearch
- Sample alerts for the last 7 days after starting the environments. Those are inside the `wazuh-manager` in `/var/ossec/logs/alerts/sample_alerts.json` and also in the `alerts.json` file merged with the non-sample data.

## Requirements

Installed and working installations of:

- Docker.
- Docker compose.

## Usage

The **.env** file contains variables used to configure the environment, such as component versions, forwarded ports and initial credentials. Modify it as required.

Start all the containers running `docker compose up -d`. It is necessary to manually start the Splunk integration in the manager container by running `/opt/splunkforwarder/bin/splunk start --accept-license`. To stop the environment, use `docker compose down`.

The Splunk Indexer instance is accessible on https://localhost:8000, credentials `admin:password`. In this instance, the logs imported from the Wazuh Indexer are in the `main` index, and the logs imported from the manager are in the `wazuh-alerts` index.

The Wazuh Dashboard instance is accessible on https://localhost:5601 credentials `admin:SecretPassword`.

The Kibana instance is accessible on http://localhost:5602 credentials `elastic:changeme`. In this instance, the logs imported from the Wazuh Indexer are in the `indexer-wazuh-alerts-4.x-<date>` index, and the logs imported from the manager are in the `wazuh-alerts-4.x-<date>` index.

The OpenSearch dashboards instance is accessible on http://localhost:5603 credentials `admin:admin`. In this instance, the logs imported from the Wazuh Indexer are in the `indexer-wazuh-alerts-4.x-<date>` index, and the logs imported from the manager are in the `wazuh-alerts-4.x-<date>` index.

The integration from the manager contains sample data, and also the alerts that are generated. The integration from the indexer will not contain any sample data. Additionally, the dashboards for all the platforms will only work with the index `wazuh-alerts...`, meaning that they will not reflect the data generated from the Indexer integration.

## Importing the dashboards

### Splunk

The dashboards for Splunk are located in `extra/dashboards/Splunk`. The steps to import them to the indexer are the following:

- Open a dashboard file and copy all its content.
- In the Splunk UI, navigate to `Search & Reporting`, `Dashboards`, click `Create New Dashboard`, write the title and select `Dashboard Studio`, select `Grid` and click on `Create`.
- On the top menu, there is a `Source` icon. Click on it, and replace all the content with the copied content from the dashboard file. After that, click on `Back` and click on `Save`.
- Repeat the steps for all the desired dashboards.

### Elastic

The dashboards for Elastic are located in `docker/integrations/extra/dashboards/elastic`. The steps to import them to the indexer are the following:

- On Kibana, expand the left menu, and go to `Stack management`.
- Click on `Saved Objects`, select `Import`, click on the `Import` icon and browse the dashboard file. It is possible to import only the desired dashboard, or the file `all-dashboards.ndjson`, that contains all the dashboards.
- Click on Import.
- Repeat the steps for all the desired dashboards.

Imported dashboards will appear in the `Dashboards` app on the left menu.

### OpenSearch

The dashboards for OpenSearch are located in `docker/integrations/extra/dashboards/opensearch`. The steps to import them to the indexer are the following:

- On OpenSearch Dashboards, expand the left menu, and go to `Stack management`
- Click on `Saved Objects`, select `Import`, click on the `Import` icon and browse the dashboard file. It is possible to import only the desired dashboard, or the file `all-dashboards.ndjson`, that contains all the dashboards.
- Click on Import.
- Repeat the steps for all the desired dashboards.

Imported dashboards will appear in the `Dashboards` app on the left menu.
