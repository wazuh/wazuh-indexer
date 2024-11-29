#!/bin/python3

import argparse
import datetime
import json
import logging
import random
import requests
import urllib3
import uuid

LOG_FILE = 'generate_data.log'
GENERATED_DATA_FILE = 'generatedData.json'
DATE_FORMAT = "%Y-%m-%dT%H:%M:%S.%fZ"
# Default values
INDEX_NAME = ".commands"
USERNAME = "admin"
PASSWORD = "admin"
IP = "127.0.0.1"
PORT = "9200"

# Configure logging
logging.basicConfig(filename=LOG_FILE, level=logging.INFO)

# Suppress warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def generate_random_date(initial_date=None, days_range=30):
    if initial_date is None:
        initial_date = datetime.datetime.now()
    random_days = random.randint(0, days_range)
    new_timestamp = initial_date + datetime.timedelta(days=random_days)
    return int(new_timestamp.timestamp() * 1000)  # Convert to milliseconds and return as int


def generate_random_command(include_all_fields=False):
    command = {
        "source": random.choice(["Users/Services", "Engine", "Content manager"]),
        "user": f"user{random.randint(1, 100)}",
        "target": {
            "id": f"target{random.randint(1, 10)}",
            "type": random.choice(["agent", "group", "server"])
        },
        "action": {
            "name": random.choice(["restart", "update","change_group", "apply_policy"]),
            "args": [f"/path/to/executable/arg{random.randint(1, 10)}"],
            "version": f"v{random.randint(1, 5)}"
        },
        "timeout": random.randint(10, 100)
    }
    if include_all_fields:
        document = {
            "@timestamp": generate_random_date(),
            "delivery_timestamp": generate_random_date(),
            "agent": {"groups": [f"group{random.randint(1, 5)}"]},
            "command": {
                **command,
                "status": random.choice(["pending", "sent", "success", "failure"]),
                "result": {
                    "code": random.randint(0, 255),
                    "message": f"Result message {random.randint(1, 1000)}",
                    "data": f"Result data {random.randint(1, 100)}"
                },
                "request_id": str(uuid.uuid4()),
                "order_id": str(uuid.uuid4())
            }
        }
        return document

    return command


def generate_random_data(number, include_all_fields=False):
    data = []
    for _ in range(number):
        data.append(generate_random_command(include_all_fields))
    return data


def inject_events(ip, port, index, username, password, data, use_index=False):
    session = requests.Session()
    session.auth = (username, password)
    session.verify = False
    headers = {'Content-Type': 'application/json'}

    try:
        for event_data in data:
            if use_index:
                # Generate UUIDs for the document id
                doc_id = str(uuid.uuid4())
                url = f'https://{ip}:{port}/{index}/_doc/{doc_id}'
            else:
                # Default URL for command manager API without the index
                url = f'https://{ip}:{port}/_plugins/_command_manager/commands'
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
        description="Generate and optionally inject events into an OpenSearch index or Command Manager."
    )
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
        "Do you want to inject the generated data into your indexer/command manager? (y/n) "
    ).strip().lower()
    if inject == 'y':
        ip = input(f"Enter the IP of your Indexer (default: '{IP}'): ") or IP
        port = input(f"Enter the port of your Indexer (default: '{PORT}'): ") or PORT

        if args.index:
            index = input(f"Enter the index name (default: '{INDEX_NAME}'): ") or INDEX_NAME
        else:
            index = None

        username = input(f"Username (default: '{USERNAME}'): ") or USERNAME
        password = input(f"Password (default: '{PASSWORD}'): ") or PASSWORD

        inject_events(ip, port, index, username, password,
                      data, use_index=bool(args.index))


if __name__ == "__main__":
    main()
