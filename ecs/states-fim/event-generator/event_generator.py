#!/bin/python3

import datetime
import json
import logging
import random
import requests
import urllib3

# Constants and Configuration
LOG_FILE = 'generate_data.log'
GENERATED_DATA_FILE = 'generatedData.json'
DATE_FORMAT = "%Y-%m-%dT%H:%M:%S.%fZ"
# Default values
INDEX_NAME = "wazuh-states-fim"
USERNAME = "admin"
PASSWORD = "admin"
IP = "127.0.0.1"
PORT = "9200"

# Configure logging
logging.basicConfig(filename=LOG_FILE, level=logging.INFO)

# Suppress warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def generate_random_date():
    start_date = datetime.datetime.now()
    end_date = start_date - datetime.timedelta(days=10)
    random_date = end_date + (start_date - end_date) * random.random()
    return random_date.strftime(DATE_FORMAT)


def generate_random_agent():
    agent = {
        'id': f'agent{random.randint(0, 99)}',
        'groups': [f'group{random.randint(0, 99)}', f'group{random.randint(0, 99)}']
    }
    return agent


def generate_random_file():
    file = {
        'attributes': f'attr{random.randint(0, 999)}',
        'gid': f'gid{random.randint(0, 999)}',
        'group': f'group{random.randint(0, 99)}',
        'hash': {
            'md5': f'md5_{random.randint(0, 999)}',
            'sha1': f'sha1_{random.randint(0, 999)}',
            'sha256': f'sha256_{random.randint(0, 999)}'
        },
        'inode': f'inode{random.randint(0, 999)}',
        'mode': f'mode{random.randint(0, 999)}',
        'mtime': generate_random_date(),
        'name': f'file{random.randint(0, 999)}',
        'owner': f'owner{random.randint(0, 99)}',
        'path': f'/path/to/file{random.randint(0, 999)}',
        'size': random.randint(0, 99999),
        'target_path': f'/path/to/target_file{random.randint(0, 999)}',
        'type': f'type{random.randint(0, 99)}',
        'uid': f'uid{random.randint(0, 999)}'
    }
    return file


def generate_random_registry():
    registry = {
        'key': f'regkey{random.randint(0, 999)}',
        'value': f'regvalue{random.randint(0, 999)}'
    }
    return registry


def generate_random_data(number):
    data = []
    for _ in range(number):
        event_data = {
            'agent': generate_random_agent(),
            'file': generate_random_file(),
            'registry': generate_random_registry()
        }
        data.append(event_data)
    return data


def inject_events(ip, port, index, username, password, data):
    url = f'https://{ip}:{port}/{index}/_doc'
    session = requests.Session()
    session.auth = (username, password)
    session.verify = False
    headers = {'Content-Type': 'application/json'}

    try:
        for event_data in data:
            response = session.post(url, json=event_data, headers=headers)
            if response.status_code != 201:
                logging.error(f'Error: {response.status_code}')
                logging.error(response.text)
                break
        logging.info('Data injection completed successfully.')
    except Exception as e:
        logging.error(f'Error: {str(e)}')


def main():
    try:
        number = int(input("How many events do you want to generate? "))
    except ValueError:
        logging.error("Invalid input. Please enter a valid number.")
        return

    logging.info(f"Generating {number} events...")
    data = generate_random_data(number)

    with open(GENERATED_DATA_FILE, 'a') as outfile:
        for event_data in data:
            json.dump(event_data, outfile)
            outfile.write('\n')

    logging.info('Data generation completed.')

    inject = input(
        "Do you want to inject the generated data into your indexer? (y/n) ").strip().lower()
    if inject == 'y':
        ip = input(f"Enter the IP of your Indexer (default: '{IP}'): ") or IP
        port = input(f"Enter the port of your Indexer (default: '{PORT}'): ") or PORT
        index = input(f"Enter the index name (default: '{INDEX_NAME}'): ") or INDEX_NAME
        username = input(f"Username (default: '{USERNAME}'): ") or USERNAME
        password = input(f"Password (default: '{PASSWORD}'): ") or PASSWORD
        inject_events(ip, port, index, username, password, data)


if __name__ == "__main__":
    main()
