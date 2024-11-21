FROM ubuntu:noble

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Update the package list and install necessary tools
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y \
    wget \
    curl \
    unzip \
    gnupg2 \
    git

# Define build arguments
ARG indexer_branch=master
ARG indexer_plugins_branch=master
ARG indexer_reporting_branch=master

# Use build arguments as environment variables in the container
ENV INDEXER_BRANCH=${indexer_branch}
ENV INDEXER_PLUGINS_BRANCH=${indexer_plugins_branch}
ENV INDEXER_REPORTING_BRANCH=${indexer_reporting_branch}

# Clone the repositories using the specified branches
RUN git clone --branch ${INDEXER_BRANCH} https://github.com/wazuh/wazuh-indexer --depth 1 && \
    git clone --branch ${INDEXER_PLUGINS_BRANCH} https://github.com/wazuh/wazuh-indexer-plugins --depth 1 && \
    git clone --branch ${INDEXER_REPORTING_BRANCH} https://github.com/wazuh/wazuh-indexer-reporting --depth 1

# Install OpenJDK 21
RUN wget -O- https://download.java.net/openjdk/jdk21/ri/openjdk-21+35_linux-x64_bin.tar.gz | tar xz -C /opt/

# Set JAVA_HOME environment variable
ENV JAVA_HOME=/opt/jdk-21
ENV PATH=$JAVA_HOME/bin:$PATH

# Install Gradle 8.10
ENV GRADLE_VERSION=8.10

RUN wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -P /tmp \
    && unzip -d /opt/gradle /tmp/gradle-${GRADLE_VERSION}-bin.zip \
    && rm /tmp/gradle-${GRADLE_VERSION}-bin.zip

# Set GRADLE_HOME environment variable
ENV GRADLE_HOME=/opt/gradle/gradle-${GRADLE_VERSION}
ENV PATH=$GRADLE_HOME/bin:$PATH

# Clean up APT when done
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY ../../build-scripts/* .
