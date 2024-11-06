#!/bin/python3

import json
import logging
import requests
import warnings

# Constants and Configuration
LOG_FILE = 'generate_data.log'
GENERATED_DATA_FILE = 'generatedData.json'
DATE_FORMAT = "%Y-%m-%dT%H:%M:%S.%fZ"

# Configure logging
logging.basicConfig(filename=LOG_FILE, level=logging.INFO)

# Suppress warnings
warnings.filterwarnings("ignore")


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
                url = f'https://{ip}:{port}/_plugins/_commandmanager'

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
    data = ""

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
