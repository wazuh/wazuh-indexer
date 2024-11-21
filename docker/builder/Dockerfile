# Use the official Ubuntu Noble image as the base image
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
        git \
        build-essential \
        debmake \
        debhelper-compat \
        libxrender1 \
        libxtst6 \
        libxi6 \
        libatk1.0-0 \
        libatk-bridge2.0-0 \
        libcups2 \
        libdrm2 \
        libatspi2.0-dev \
        libxcomposite-dev \
        libxdamage1 \
        libxfixes3 \
        libxfixes-dev \
        libxrandr2 \
        libgbm-dev \
        libxkbcommon-x11-0 \
        libpangocairo-1.0-0 \
        libcairo2 \
        libcairo2-dev \
        libnss3 \
        libnspr4 \
        libnspr4-dev \
    && rm -rf /var/lib/apt/lists/*

# Define build arguments with default values
ARG indexer_branch=master
ARG indexer_plugins_branch=master
ARG indexer_reporting_branch=master
ARG revision=0
ARG is_stage=false
ARG distribution=tar
ARG architecture=x64

# Use build arguments as environment variables in the container
ENV INDEXER_BRANCH=${indexer_branch} \
    INDEXER_PLUGINS_BRANCH=${indexer_plugins_branch} \
    INDEXER_REPORTING_BRANCH=${indexer_reporting_branch} \
    REVISION=${revision} \
    IS_STAGE=${is_stage} \
    DISTRIBUTION=${distribution} \
    ARCHITECTURE=${architecture}

# Clone the repositories using the specified branches
RUN git clone --branch ${INDEXER_BRANCH} https://github.com/wazuh/wazuh-indexer --depth 1 /opt/wazuh-indexer && \
    git clone --branch ${INDEXER_PLUGINS_BRANCH} https://github.com/wazuh/wazuh-indexer-plugins --depth 1 /opt/wazuh-indexer-plugins && \
    git clone --branch ${INDEXER_REPORTING_BRANCH} https://github.com/wazuh/wazuh-indexer-reporting --depth 1 /opt/wazuh-indexer-reporting

# Save repositories hashes
RUN cd /opt/wazuh-indexer && indexer_hash=$(git rev-parse --short HEAD) && \
    cd /opt/wazuh-indexer-plugins && plugins_hash=$(git rev-parse --short HEAD) && \
    cd /opt/wazuh-indexer-reporting && reporting_hash=$(git rev-parse --short HEAD)

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

# Copy build scripts to /opt directory
COPY ../../build-scripts/* /opt/build-scripts/

# Clean up APT when done
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ---PACKAGE-BUILDING---

# Baptize min
RUN PACKAGE_MIN_NAME=$(bash /opt/build-scripts/baptizer.sh -m \
    -a ${ARCHITECTURE} \
    -d ${DISTRIBUTION} \
    -r ${REVISION} \
    -l ${plugins_hash} \
    -e ${reporting_hash} \
    $(if [ "${IS_STAGE}" = "true" ]; then echo "-x"; fi))

# Baptize package (min)
RUN PACKAGE_MIN_NAME=$(bash /opt/build-scripts/baptizer.sh \
    -a ${ARCHITECTURE} \
    -d ${DISTRIBUTION} \
    -r ${REVISION} \
    -l ${plugins_hash} \
    -e ${reporting_hash} \
    $(if [ "${IS_STAGE}" = "true" ]; then echo "-x"; fi))

# Baptize package
RUN PACKAGE_NAME=$(bash /opt/build-scripts/baptizer.sh \
    -a ${ARCHITECTURE} \
    -d ${DISTRIBUTION} \
    -r ${REVISION} \
    -l ${plugins_hash} \
    -e ${reporting_hash} \
    $(if [ "${IS_STAGE}" = "true" ]; then echo "-x"; fi))

# Build
RUN bash /opt/build-scripts/build.sh \
    -a ${ARCHITECTURE} \
    -d ${DISTRIBUTION} \
    -n ${PACKAGE_MIN_NAME}

# Assamble
RUN bash build-scripts/assemble.sh \
    -a ${ARCHITECTURE} \
    -d ${DISTRIBUTION} \
    -r ${REVISION}

# Create a directory to store the resulting packages \
RUN mkdir -p /artifacts/dist/

# Move the resulting package to /artifacts/dist/
RUN mv /opt/artifacts/dist/${PACKAGE_NAME} /artifacts/dist/
