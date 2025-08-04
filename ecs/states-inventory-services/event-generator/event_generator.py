#!/bin/python3

import json
import logging
import random
import requests
import urllib3
import random
import string

# Constants and Configuration
LOG_FILE = "generate_data.log"
GENERATED_DATA_FILE = "generatedData.json"
DATE_FORMAT = "%Y-%m-%dT%H:%M:%S.%fZ"
# Default values
INDEX_NAME = "wazuh-states-inventory-services"
USERNAME = "admin"
PASSWORD = "admin"
IP = "127.0.0.1"
PORT = "9200"

# Configure logging
logging.basicConfig(filename=LOG_FILE, level=logging.INFO)

# Suppress warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def random_string(length=6):
    return ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))

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

def generate_file(is_linux=True):
    if is_linux:
        return {
            "path": f"/usr/lib/systemd/system/{random.choice(['nginx.service', 'sshd.service', 'cron.service'])}"
        }
    else:
        return {
            "path": f"C:\\Windows\\System32\\{random.choice(['svchost.exe', 'services.exe'])}"
        }

def generate_process(is_linux=True, state="running"):
    pid = random.randint(1000, 5000) if state.lower() in ["running", "active"] else 0
    executable = (
        random.choice(["/usr/bin/python3", "/usr/sbin/sshd", "/usr/sbin/nginx"])
        if is_linux
        else random.choice(["C:\\Program Files\\App\\app.exe", "C:\\Windows\\System32\\svchost.exe"])
    )
    return {
        "executable": executable,
        "pid": pid
    }

def generate_service(is_linux=True):
    # Estado y subestado según el SO
    if is_linux:
        state = random.choice(["active", "inactive", "failed"])
        sub_state = random.choice(["running", "dead", "exited"])
    else:
        state = random.choice(["RUNNING", "STOPPED"])
        sub_state = None

    name = random.choice(["nginx", "sshd", "cron", "wuauserv", "winlogon"])
    service_data = {
        "id": name,                      # Coincide con ECS/osquery
        "name": name.capitalize(),
        "description": f"{name} service",
        "state": state,
        "sub_state": sub_state,
        "address": (
            f"/lib/{name}.so" if is_linux else f"C:\\Windows\\System32\\{name}.dll"
        ),
        "type": random.choice(["OWN_PROCESS", "WIN32_SHARE_PROCESS"]) if not is_linux else "system",
        "exit_code": random.randint(0, 5) if state not in ["RUNNING", "active"] else 0,
        "win32_exit_code": (
            random.randint(0, 5) if not is_linux and state == "STOPPED" else 0
        ),
        "enabled": (
            random.choice(["enabled", "disabled", "static"]) if is_linux else None
        ),
        "following": (
            random.choice(["none", "multi-user.target"]) if is_linux else None
        ),
        "object_path": (
            f"/org/freedesktop/{name}" if is_linux else None
        ),
        "start_type": (
            random.choice(["AUTO_START", "DEMAND_START", "DISABLED"]) if not is_linux else None
        ),
        "target": {
            "ephemeral_id": str(random.randint(1000, 9999)),
            "type": random.choice(["start", "stop"]),
            "address": (
                f"/systemd/job/{name}" if is_linux else f"C:\\Jobs\\{name}"
            )
        }
    }
    return service_data

def generate_user(is_linux=True):
    return {
        "name": random.choice(["root", "SYSTEM", "nginx", "admin", "service"])
        if is_linux else random.choice(["SYSTEM", "Administrator", "LocalService"])
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

# ===================== #
#   Modificación generate_random_data
# ===================== #

def generate_random_data(number):
    data = []
    for _ in range(number):
        is_linux = random.choice([True, False])
        service_data = generate_service(is_linux=is_linux)
        event_data = {
            "agent": generate_agent(),
            "file": generate_file(is_linux=is_linux),
            "process": generate_process(is_linux=is_linux, state=service_data["state"]),
            "service": service_data,
            "user": generate_user(is_linux=is_linux),
            "wazuh": generate_wazuh()
        }
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
