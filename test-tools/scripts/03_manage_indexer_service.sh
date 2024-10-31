#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Function to check the status of the wazuh-indexer service
check_service_is_running() {
    if systemctl is-active --quiet wazuh-indexer ; then
        echo "wazuh-indexer service is running."
    else
        echo "Error: wazuh-indexer service is not running." >&2
        exit 1
    fi
}

# Function to display usage help
usage() {
    echo "Usage: $0 --action <start|stop|restart>"
    echo
    echo "This script manages the wazuh-indexer service."
    echo
    echo "Options:"
    echo "    -a, --action    Specify the action to perform: start, stop, or restart."
    echo "    -h, --help      Show this help message and exit."
    echo
    exit 1
}

# Parse named arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --action|-a) ACTION="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Check if ACTION is provided
if [ -z "$ACTION" ]; then
    echo "Error: Action is required."
    usage
fi

# Execute the action
case $ACTION in
    start)
        echo "Starting wazuh-indexer service..."
        systemctl daemon-reload > /dev/null 2>&1
        systemctl enable wazuh-indexer > /dev/null 2>&1
        systemctl start wazuh-indexer > /dev/null 2>&1
        check_service_is_running
        ;;
    stop)
        echo "Stopping wazuh-indexer service..."
        systemctl stop wazuh-indexer
        systemctl is-active --quiet wazuh-indexer
        if [ $? -ne 0 ]; then
            echo "wazuh-indexer service stopped successfully."
        else
            echo "Error: Failed to stop wazuh-indexer service." >&2
            exit 1
        fi
        ;;
    restart)
        echo "Restarting wazuh-indexer service..."
        systemctl restart wazuh-indexer
        check_service_is_running
        ;;
    *)
        echo "Error: Invalid action specified. Use start, stop, or restart."
        usage
        ;;
esac
