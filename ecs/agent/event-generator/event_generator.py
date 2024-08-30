#!/bin/python3

import datetime
import random
import json
import requests
import warnings
import logging

# Constants and Configuration
LOG_FILE = 'generate_data.log'
GENERATED_DATA_FILE = 'generatedData.json'
DATE_FORMAT = "%Y-%m-%dT%H:%M:%S.%fZ"

# Configure logging
logging.basicConfig(filename=LOG_FILE, level=logging.INFO)

# Suppress warnings
warnings.filterwarnings("ignore")


def generate_random_date():
    start_date = datetime.datetime.now()
    end_date = start_date - datetime.timedelta(days=10)
    random_date = start_date + (end_date - start_date) * random.random()
    return random_date.strftime(DATE_FORMAT)


def generate_random_agent():
    agent = {
        'id': f'agent{random.randint(0, 99)}',
        'name': f'Agent{random.randint(0, 99)}',
        'type': random.choice(['filebeat', 'windows', 'linux', 'macos']),
        'version': f'v{random.randint(0, 9)}-stable',
        'is_connected': random.choice([True, False]),
        'last_login': generate_random_date(),
        'groups': [f'group{random.randint(0, 99)}', f'group{random.randint(0, 99)}'],
        'key': f'key{random.randint(0, 999)}'
    }
    return agent


def generate_random_host():
    family = random.choice(['debian', 'ubuntu', 'macos', 'ios', 'android', 'RHEL'])
    version = f'{random.randint(0, 99)}.{random.randint(0, 99)}'
    host = {
        'ip': f'{random.randint(1, 255)}.{random.randint(1, 255)}.{random.randint(1, 255)}.{random.randint(1, 255)}',
        'os': {
            'full': f'{family} {version}',
        }
    }
    return host


def generate_random_tags():
    tags = [f'tag{random.randint(0, 99)}' for _ in range(random.randint(0, 5))]
    return tags


def generate_random_data(number):
    data = []
    for _ in range(number):
        event_data = {
            'agent': generate_random_agent(),
            'host': generate_random_host(),
            'message': f'message{random.randint(0, 99999)}',
            'tags': generate_random_tags()
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
        ip = input("Enter the IP of your Indexer: ")
        port = input("Enter the port of your Indexer: ")
        index = input("Enter the index name: ")
        username = input("Username: ")
        password = input("Password: ")
        inject_events(ip, port, index, username, password, data)


if __name__ == "__main__":
    main()
