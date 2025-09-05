#!/bin/python3

import json
import logging
import random
import requests
import urllib3
import random
import string
import time

# Constants and Configuration
LOG_FILE = "generate_data.log"
GENERATED_DATA_FILE = "generatedData.json"
DATE_FORMAT = "%Y-%m-%dT%H:%M:%S.%fZ"
# Default values
INDEX_NAME = "wazuh-states-inventory-browser-extensions"
USERNAME = "admin"
PASSWORD = "admin"
IP = "127.0.0.1"
PORT = "9200"

# Configure logging
logging.basicConfig(filename=LOG_FILE, level=logging.INFO)

# Suppress warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def random_string(length=8):
    return ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))

def random_sha256():
    return ''.join(random.choices('0123456789abcdef', k=64))

def random_permissions():
    return random.sample(
        ["tabs", "storage", "cookies", "history", "bookmarks", "notifications"],
        k=random.randint(1, 3)
    )

def random_browser():
    return random.choice(["chrome", "firefox", "safari", "ie"])

def generate_browser_extension():
    browser = random_browser()
    is_chrome = browser == "chrome"
    is_firefox = browser == "firefox"
    is_safari = browser == "safari"
    is_ie = browser == "ie"

    # ID and user name
    user_id = f"user{random.randint(1,10)}" if not is_ie else None

    # Name and ID of the extension
    ext_name = random.choice(["Adblock Plus", "LastPass", "Grammarly", "Honey", "Dark Reader"])
    ext_id = random_string(32) if is_chrome else random_string(16)

    # Common fields
    extension_data = {
        "browser": {
            "name": browser,
            "profile": {}
        },
        "user": {
            "id": user_id
        },
        "package": {
            "name": ext_name,
            "id": ext_id,
            "version": f"{random.randint(1,5)}.{random.randint(0,9)}.{random.randint(0,9)}",
            "description": f"{ext_name} browser extension",
            "vendor": random.choice(["Google", "Mozilla", "Microsoft", "Independent Dev"]),
            "build_version": "SafariSDK-602" if is_safari else None,
            "path": None,
            "reference": None,
            "permissions": None,
            "type": None,
            "enabled": random.choice([True, False]),
            "autoupdate": random.choice([True, False]) if is_firefox else None,
            "persistent": random.choice([True, False]) if is_chrome else None,
            "from_webstore": random.choice([True, False]) if is_chrome else None,
            "installed": int(time.time()) - random.randint(1000, 1000000),
        },
        "file": {
            "hash": {
                "sha256": random_sha256() if is_chrome else None
            }
        }
    }

    # Browser-specific fields
    if is_chrome:
        extension_data["browser"]["profile"] = {
            "name": random.choice(["Default", "Profile 1", "Work"]),
            "path": f"/home/{user_id}/.config/google-chrome/Profile {random.randint(1,3)}",
            "referenced": random.choice([True, False])
        }
        extension_data["package"]["path"] = f"/home/{user_id}/.config/google-chrome/Profile 1/Extensions/{ext_id}"
        extension_data["package"]["reference"] = "https://clients2.google.com/service/update2/crx"
        extension_data["package"]["permissions"] = random_permissions()

    elif is_firefox:
        extension_data["package"]["type"] = random.choice(["extension", "webapp"])
        extension_data["package"]["path"] = f"/home/{user_id}/.mozilla/firefox/{random_string(8)}.default/extensions/{ext_id}.xpi"
        extension_data["package"]["reference"] = f"https://addons.mozilla.org/firefox/downloads/file/{random.randint(1000,9999)}/"
        extension_data["package"]["visible"] = random.choice([True, False])

    elif is_safari:
        extension_data["package"]["path"] = f"/Users/{user_id}/Library/Safari/Extensions/{ext_name}.safariextz"

    elif is_ie:
        extension_data["package"]["path"] = f"HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Internet Explorer\\Extensions\\{ext_id}"

    return extension_data

def generate_agent():
    return {
        "host": {
            "architecture": random.choice(["x86_64", "arm64"]),
            "ip": f"192.168.{random.randint(0, 255)}.{random.randint(1, 254)}"
        },
        "id": random_string(8),
        "name": f"agent-{random.randint(1, 100)}",
        "version": f"{random.randint(1,5)}.{random.randint(0,9)}.{random.randint(0,9)}"
    }

def generate_wazuh():
    return {
        "cluster": {
            "name": random.choice(["cluster-alpha", "cluster-beta"]),
            "node": random.choice(["node-1", "node-2", "node-3"])
        },
        "schema": {
            "version": f"{random.randint(1,3)}.{random.randint(0,9)}"
        }
    }

def generate_random_data(number):
    data = []
    for _ in range(number):
        event_data = generate_browser_extension()
        # Add agent and Wazuh data
        event_data["agent"] = generate_agent()
        event_data["wazuh"] = generate_wazuh()

        data.append(event_data)
    return data

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
