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
INDEX_NAME = "wazuh-commands"
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
        initial_date = datetime.datetime.now(datetime.timezone.utc)
    random_days = random.randint(0, days_range)
    new_timestamp = initial_date + datetime.timedelta(days=random_days)
    return new_timestamp.strftime('%Y-%m-%dT%H:%M:%SZ')


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
            "args": { "arg1": f"/path/to/executable/arg{random.randint(1, 10)}"},
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
    if not include_all_fields:
        return {"commands": data}
    return data


def inject_events(protocol, ip, port, index, username, password, data, use_index=False):
    try:
        if not use_index:
            # Use the command-manager API
            url = f'{protocol}://{ip}:{port}/_plugins/_command_manager/commands'
            send_post_request(username, password, url, data)
            return
        for event_data in data:
            # Generate UUIDs for the document id
            doc_id = str(uuid.uuid4())
            url = f'{protocol}://{ip}:{port}/{index}/_doc/{doc_id}'
            send_post_request(username, password, url, event_data)
        logging.info('Data injection completed successfully.')
    except Exception as e:
        logging.error(f'Error: {str(e)}')


def send_post_request(username, password, url, event_data):
    session = requests.Session()
    session.auth = (username, password)
    session.verify = False
    headers = {'Content-Type': 'application/json'}
    # Send request
    response = session.post(url, data=json.dumps(event_data), headers=headers)
    if response.status_code not in [201, 200]:
        logging.error(f'Error: {response.status_code}')
        logging.error(response.text)
    return response


def main():
    parser = argparse.ArgumentParser(
        description="Generate and optionally inject events into an OpenSearch index or Command Manager."
    )
    parser.add_argument(
        "--index",
        action="store_true",
        help="Generate additional fields for indexing and inject into a specific index."
    )
    parser.add_argument(
        "--protocol",
        choices=['http', 'https'],
        default='https',
        help="Specify the protocol to use: http or https."
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
        json.dump(data, outfile)
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

        inject_events(args.protocol, ip, port, index, username, password,
                      data, use_index=bool(args.index))


if __name__ == "__main__":
    main()
