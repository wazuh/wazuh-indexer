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
INDEX_NAME = "wazuh-agents"
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
    random_date = start_date + (end_date - start_date) * random.random()
    return random_date.strftime(DATE_FORMAT)


def generate_random_agent():
    agent = {
        'id': f'agent{random.randint(0, 99)}',
        'name': f'Agent{random.randint(0, 99)}',
        'type': random.choice(['filebeat', 'windows', 'linux', 'macos']),
        'version': f'v{random.randint(0, 9)}-stable',
        'status': random.choice(['active', 'inactive']),
        'last_login': generate_random_date(),
        'groups': [f'group{random.randint(0, 99)}', f'group{random.randint(0, 99)}'],
        'key': f'key{random.randint(0, 999)}',
        'host': generate_random_host()
    }
    return agent


def generate_random_host():
    family = random.choice(
        ['debian', 'ubuntu', 'macos', 'ios', 'android', 'RHEL'])
    version = f'{random.randint(0, 99)}.{random.randint(0, 99)}'
    host = {
        'architecture': random.choice(['x86_64', 'arm64']),
        'boot': {
            'id': f'boot{random.randint(0, 9999)}'
        },
        'cpu': {
            'usage': random.uniform(0, 100)
        },
        'disk': {
            'read': {
                'bytes': random.randint(0, 1000000)
            },
            'write': {
                'bytes': random.randint(0, 1000000)
            }
        },
        'domain': f'domain{random.randint(0, 999)}',
        'geo': {
            'city_name': random.choice(['San Francisco', 'New York', 'Berlin', 'Tokyo']),
            'continent_code': random.choice(['NA', 'EU', 'AS']),
            'continent_name': random.choice(['North America', 'Europe', 'Asia']),
            'country_iso_code': random.choice(['US', 'DE', 'JP']),
            'country_name': random.choice(['United States', 'Germany', 'Japan']),
            'location': {
                'lat': round(random.uniform(-90.0, 90.0), 6),
                'lon': round(random.uniform(-180.0, 180.0), 6)
            },
            'name': f'geo{random.randint(0, 999)}',
            'postal_code': f'{random.randint(10000, 99999)}',
            'region_iso_code': f'region{random.randint(0, 999)}',
            'region_name': f'Region {random.randint(0, 999)}',
            'timezone': random.choice(['PST', 'EST', 'CET', 'JST'])
        },
        'hostname': f'host{random.randint(0, 9999)}',
        'id': f'hostid{random.randint(0, 9999)}',
        'ip': f'{random.randint(1, 255)}.{random.randint(1, 255)}.{random.randint(1, 255)}.{random.randint(1, 255)}',
        'mac': f'{random.randint(0, 255):02x}:{random.randint(0, 255):02x}:{random.randint(0, 255):02x}:{random.randint(0, 255):02x}:{random.randint(0, 255):02x}:{random.randint(0, 255):02x}',
        'name': f'hostname{random.randint(0, 9999)}',
        'network': {
            'egress': {
              'bytes': random.randint(0, 1000000),
              'packets': random.randint(0, 1000000)
            },
            'ingress': {
                'bytes': random.randint(0, 1000000),
                'packets': random.randint(0, 1000000)
            }
        },
        'os': {
            'family': family,
            'full': f'{family} {version}',
            'kernel': f'kernel{random.randint(0, 999)}',
            'name': family,
            'platform': random.choice(['linux', 'windows', 'macos']),
            'type': family,
            'version': version
        },
        'pid_ns_ino': f'{random.randint(1000000, 9999999)}',
        'risk': {
            'calculated_level': random.choice(['low', 'medium', 'high']),
            'calculated_score': random.uniform(0, 100),
            'calculated_score_norm': random.uniform(0, 1),
            'static_level': random.choice(['low', 'medium', 'high']),
            'static_score': random.uniform(0, 100),
            'static_score_norm': random.uniform(0, 1)
        },
        'uptime': random.randint(0, 1000000)
    }
    return host


def generate_random_data(number):
    data = []
    for _ in range(number):
        event_data = {
            'agent': generate_random_agent()
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
