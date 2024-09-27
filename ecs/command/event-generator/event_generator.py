#!/bin/python3

# This script generates sample events and injects them into an OpenSearch index.
# The events follow the provided template structure with command-related data fields.
# Additional fields are generated when the --index option is passed.

import random
import json
import requests
import warnings
import logging
import argparse

LOG_FILE = 'generate_data.log'
GENERATED_DATA_FILE = 'generatedData.json'

# Configure logging
logging.basicConfig(filename=LOG_FILE, level=logging.INFO)

# Suppress warnings
warnings.filterwarnings("ignore")


def generate_random_command(include_all_fields=False):
    command = {
        "source": random.choice(["Users/Services", "Engine", "Content manager"]),
        "user": f"user{random.randint(1, 100)}",
        "target": f"WazuhServerCluster{random.randint(1, 10)}",
        "type": random.choice(["agent_group", "agent", "wazuh_server"]),
        "action": {
            "type": random.choice(["Agent groups", "Agent", "Server cluster"]),
            "args": [f"/path/to/executable/arg{random.randint(1, 10)}"],
            "version": f"v{random.randint(1, 10)}"
        },
        "timeout": random.randint(10, 100)
    }

    if include_all_fields:
        command["status"] = random.choice(
            ["pending", "sent", "success", "failure"]
        )
        command["result"] = {
            "code": random.randint(0, 255),
            "message": f"Result message {random.randint(1, 1000)}",
            "data": f"Result data {random.randint(1, 100)}"
        }
        command["request_id"] = random.randint(1000, 9999)
        command["order_id"] = random.randint(1000, 9999)

    return command


def generate_random_data(number, include_all_fields=False):
    data = []
    for _ in range(number):
        data.append(generate_random_command(include_all_fields))
    return data


def inject_events(ip, port, index, username, password, data, use_index=False):
    url = f'https://{ip}:{port}/_plugins/_commandmanager'

    session = requests.Session()
    session.auth = (username, password)
    session.verify = False
    headers = {'Content-Type': 'application/json'}

    try:
        for event_data in data:
            if use_index:
                id = event_data["request_id"] + event_data["order_id"]
                url = f'https://{ip}:{port}/{index}/_doc/{id}'

            response = session.post(url, json=event_data, headers=headers)
            if response.status_code != 201:
                logging.error(f'Error: {response.status_code}')
                logging.error(response.text)
                break
        logging.info('Data injection completed successfully.')
    except Exception as e:
        logging.error(f'Error: {str(e)}')


def main():
    parser = argparse.ArgumentParser(
        description="Generate and optionally inject events into an OpenSearch index or Command Manager.")
    parser.add_argument(
        "--index",
        action="store_true",
        help="Generate additional fields for indexing and inject into a specific index."
    )
    args = parser.parse_args()

    try:
        number = int(input("How many events do you want to generate? "))
    except ValueError:
        logging.error("Invalid input. Please enter a valid number.")
        return

    logging.info(f"Generating {number} events...")
    data = generate_random_data(number, include_all_fields=args.index)

    with open(GENERATED_DATA_FILE, 'a') as outfile:
        for event_data in data:
            json.dump(event_data, outfile)
            outfile.write('\n')

    logging.info('Data generation completed.')

    inject = input(
        "Do you want to inject the generated data into your indexer/command manager? (y/n) ").strip().lower()
    if inject == 'y':
        ip = input("Enter the IP of your Indexer: ")
        port = input("Enter the port of your Indexer: ")

        if args.index:
            index = input("Enter the index name: ")
        else:
            index = None

        username = input("Username: ")
        password = input("Password: ")

        inject_events(ip, port, index, username, password,
                      data, use_index=args.index)


if __name__ == "__main__":
    main()
