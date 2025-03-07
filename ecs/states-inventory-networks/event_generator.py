#!/bin/python3

import datetime
import json
import logging
import random
import requests
import urllib3

# Constants and Configuration
LOG_FILE = "generate_data.log"
GENERATED_DATA_FILE = "generatedData.json"
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
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def generate_random_data(number):
    data = []
    for _ in range(number):
        event_data = {
            "@timestamp": generate_random_date(),
            "agent": generate_random_agent(),
            "host": generate_random_host(True),
            "event": generate_random_event(),
            "network": generate_random_network(),
            "observer": generate_random_observer(),
            "operation": generate_random_operation(),
        }
        data.append(event_data)
    return data


def generate_random_date():
    start_date = datetime.datetime.now()
    end_date = start_date - datetime.timedelta(days=10)
    random_date = start_date + (end_date - start_date) * random.random()
    return random_date.strftime(DATE_FORMAT)


def generate_random_agent():
    agent = {
        "id": f"agent{random.randint(0, 99)}",
        "name": f"Agent{random.randint(0, 99)}",
        "version": f"v{random.randint(0, 9)}-stable",
        "host": generate_random_host(False),
    }
    return agent


def generate_random_host(is_root_level_level=False):
    if is_root_level_level:
        host = {
            "ip": f"{random.randint(1, 255)}.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(0, 255)}"
        }
    else:
        host = {
            "architecture": random.choice(["x86_64", "arm64"]),
            "ip": f"{random.randint(1, 255)}.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(0, 255)}",
        }
    return host


def generate_random_event():
    return {"event": f"{random.randint(1000,10000000000)}"}


def generate_random_geo():
    geo = {
        "city_name": "CityName",
        "continent_code": "NA",
        "continent_name": "North America",
        "country_iso_code": "US",
        "country_name": "United States",
        "location": {
            "lat": round(random.uniform(-90, 90), 6),
            "lon": round(random.uniform(-180, 180), 6),
        },
        "name": f"location{random.randint(0, 999)}",
        "postal_code": f"{random.randint(10000, 99999)}",
        "region_iso_code": "US-CA",
        "region_name": "California",
        "timezone": "America/Los_Angeles",
    }
    return geo


def generate_random_network():
    network = {
        "broadcast": f"{random.randint(1, 255)}.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(0, 255)}",
        "dhcp": f"dhcp{random.randint(0, 9999)}",
        "metric": random.randint(1, 100),
        "netmask": f"{random.randint(1, 255)}.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(0, 255)}",
        "protocol": random.choice(["TCP", "UDP", "ICMP"]),
    }
    return network


def generate_random_interface():
    return {"name": f"name{random.randint(0, 9999)}"}


def generate_random_observer():
    observer = {"ingress": {"interface": generate_random_interface(False)}}
    return observer


def generate_random_operation():
    return {"operation": {"name": random.choice(["INSERTED", "MODIFIED", "DELETED"])}}


def inject_events(ip, port, index, username, password, data):
    url = f"https://{ip}:{port}/{index}/_doc"
    session = requests.Session()
    session.auth = (username, password)
    session.verify = False
    headers = {"Content-Type": "application/json"}

    try:
        for event_data in data:
            response = session.post(url, json=event_data, headers=headers)
            if response.status_code != 201:
                logging.error(f"Error: {response.status_code}")
                logging.error(response.text)
                break
        logging.info("Data injection completed successfully.")
    except Exception as e:
        logging.error(f"Error: {str(e)}")


def main():
    try:
        number = int(input("How many events do you want to generate? "))
    except ValueError:
        logging.error("Invalid input. Please enter a valid number.")
        return

    logging.info(f"Generating {number} events...")
    data = generate_random_data(number)

    with open(GENERATED_DATA_FILE, "a") as outfile:
        for event_data in data:
            json.dump(event_data, outfile)
            outfile.write("\n")

    logging.info("Data generation completed.")

    inject = (
        input("Do you want to inject the generated data into your indexer? (y/n) ")
        .strip()
        .lower()
    )
    if inject == "y":
        ip = input(f"Enter the IP of your Indexer (default: '{IP}'): ") or IP
        port = input(f"Enter the port of your Indexer (default: '{PORT}'): ") or PORT
        index = input(f"Enter the index name (default: '{INDEX_NAME}'): ") or INDEX_NAME
        username = input(f"Username (default: '{USERNAME}'): ") or USERNAME
        password = input(f"Password (default: '{PASSWORD}'): ") or PASSWORD
        inject_events(ip, port, index, username, password, data)


if __name__ == "__main__":
    main()
