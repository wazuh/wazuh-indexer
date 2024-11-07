#!/bin/python3

import datetime
import json
import logging
import random
import requests
import warnings

# Constants and Configuration
LOG_FILE = 'generate_data.log'
GENERATED_DATA_FILE = 'generatedData.json'
DATE_FORMAT = "%Y-%m-%dT%H:%M:%S.%fZ"
# Default values
INDEX_NAME = "wazuh-states-inventory-networks"
USERNAME = "admin"
PASSWORD = "admin"
IP = "127.0.0.1"
PORT = "9200"

# Configure logging
logging.basicConfig(filename=LOG_FILE, level=logging.INFO)

# Suppress warnings
warnings.filterwarnings("ignore", category=urllib3.exceptions.InsecureRequestWarning)


def generate_random_date():
    start_date = datetime.datetime.now()
    end_date = start_date - datetime.timedelta(days=10)
    random_date = end_date + (start_date - end_date) * random.random()
    return random_date.strftime(DATE_FORMAT)


def generate_random_ip():
    return f"{random.randint(1, 255)}.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(0, 255)}"


def generate_random_network_data():
    network = {
        'protocol': random.choice(['TCP', 'UDP', 'ICMP']),
        'type': random.choice(['ipv4', 'ipv6'])
    }
    return network


def generate_random_host():
    host = {
        'ip': generate_random_ip(),
        'mac': f'{random.randint(0, 255):02x}:{random.randint(0, 255):02x}:{random.randint(0, 255):02x}:{random.randint(0, 255):02x}:{random.randint(0, 255):02x}:{random.randint(0, 255):02x}',
        'network': {
            'egress': {
                'bytes': random.randint(1000, 1000000),
                'packets': random.randint(100, 10000)
            },
            'ingress': {
                'bytes': random.randint(1000, 1000000),
                'packets': random.randint(100, 10000)
            }
        }
    }
    return host


def generate_random_data(number):
    data = []
    for _ in range(number):
        event_data = {
            '@timestamp': datetime.datetime.now().strftime(DATE_FORMAT),
            'destination': {
                'ip': generate_random_ip(),
                'port': random.randint(1, 65535)
            },
            'device': {
                'id': f'device{random.randint(1, 1000)}'
            },
            'file': {
                'inode': f'inode{random.randint(1, 1000)}'
            },
            'host': generate_random_host(),
            'network': generate_random_network_data(),
            'observer': {
                'ingress': {
                    'interface': {
                        'alias': f'alias{random.randint(1, 1000)}',
                        'name': f'interface{random.randint(1, 1000)}'
                    }
                }
            },
            'process': {
                'name': f'process{random.randint(1, 1000)}',
                'pid': random.randint(1, 10000)
            },
            'source': {
                'ip': generate_random_ip(),
                'port': random.randint(1, 65535)
            }
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

    inject = input("Do you want to inject the generated data into your indexer? (y/n) ").strip().lower()
    if inject == 'y':
        ip = input(f"Enter the IP of your Indexer (default: '{IP}'): ") or IP
        port = input(f"Enter the port of your Indexer (default: '{PORT}'): ") or PORT
        index = input(f"Enter the index name (default: '{INDEX_NAME}'): ") or INDEX_NAME
        username = input(f"Username (default: '{USERNAME}'): ") or USERNAME
        password = input(f"Password (default: '{PASSWORD}'): ") or PASSWORD
        inject_events(ip, port, index, username, password, data)


if __name__ == "__main__":
    main()
