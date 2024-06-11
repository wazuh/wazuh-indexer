FROM wazuh/wazuh/wazuh-manager:${WAZUH_VERSION}

# Install Logastash
RUN apt install wget apt-transport-https
RUN wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elastic-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/elastic-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-8.x.list
RUN apt-get update && apt-get install logstash

# Create keystore
RUN /usr/share/logstash/bin/logstash-keystore create
RUN echo "admin" | /usr/share/logstash/bin/logstash-keystore add INDEXER_USERNAME
RUN echo "admin" | /usr/share/logstash/bin/logstash-keystore add INDEXER_PASSWORD