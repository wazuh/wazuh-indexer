FROM python:3.10

# Update the package list and upgrade all packages
RUN apt-get update && \
    apt-get upgrade -y && \
    # Install dependencies
    apt-get install  -y git jq && \
    # Cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    # Clone elastic ECS repository and install required Python libraries
    git clone https://github.com/elastic/ecs.git && \
    pip install -r ecs/scripts/requirements.txt && \
    # Create the directory for the ecs definitions (this will be used as a volume)
    mkdir -p /source/ecs

# Ensure the generate.sh script is in the correct location
ADD docker/ecs/images/generate.sh /ecs/generate.sh

# Define the directory as a volume to allow for external mounting
VOLUME /source/ecs

# Ensure the generate.sh script is executable
RUN chmod +x /ecs/generate.sh

# Set the working directory to the ECS repository
WORKDIR /ecs

# Define the entry point for the container to execute the generate.sh script
ENTRYPOINT ["/bin/bash", "/ecs/generate.sh"]
