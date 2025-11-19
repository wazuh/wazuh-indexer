#!/bin/python3

import json
import logging
import random
import requests
import urllib3
import random
import string
from enum import Enum

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
class OS(Enum):
    LINUX = "Linux"
    WINDOWS = "Windows"
    MACOS = "macOS"

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

def generate_file(os_type=OS.LINUX):
    if os_type == OS.LINUX:
        return {
            "path": f"/usr/lib/systemd/system/{random.choice(['nginx.service', 'sshd.service', 'cron.service'])}"
        }
    elif os_type == OS.MACOS:
        return {
            "path": f"/Applications/{random.choice(['App.app', 'Service.app'])}"
        }

def generate_process(os_type=OS.LINUX, state="running"):
    pid = random.randint(1000, 5000) if state.lower() in ["running", "active"] else 0
    if os_type == OS.WINDOWS:
        executable = random.choice(["C:\\Program Files\\App\\app.exe", "C:\\Windows\\System32\\svchost.exe"])
    elif os_type == OS.LINUX:
        executable = random.choice(["/usr/bin/python3", "/usr/sbin/sshd", "/usr/sbin/nginx"])
    else:
        executable = random.choice(["/Applications/App.app/Contents/MacOS/App", "/usr/bin/terminal"])

    if os_type == OS.WINDOWS:
        return {
            "executable": executable,
            "pid": pid,
            "user.name": random.choice(["root", "admin", "user"])
        }
    elif os_type == OS.LINUX:
        return {
            "executable": executable,
            "user.name": random.choice(["root", "admin", "user"])
        }
    else:
        return {
            "executable": executable,
            "pid": pid,
            "args": [f"--option{random.randint(1, 5)}={random_string(4)}"],
            "user.name": random.choice(["root", "admin", "user"]),
            "group.name": random.choice(["root", "admin", "users"]),
            "working_directory": f"/home/{random.choice(['user1', 'user2', 'user3'])}",
            "root_directory": f"/home/{random.choice(['user1', 'user2', 'user3'])}"
        }

def generate_service(os_type=OS.LINUX):
    # State and substate depending on the OS
    if os_type == OS.LINUX:
        state = random.choice(["active", "inactive", "failed"])
        sub_state = random.choice(["running", "dead", "exited"])
    elif os_type == OS.WINDOWS:
        state = random.choice(["RUNNING", "STOPPED"])
    else:  
        state = random.choice(["running", "stopped"])
    
    if os_type == OS.LINUX:
        name = random.choice(["nginx", "sshd", "cron"])
        service_data = {
            "id": name,                      # Matches ECS/osquery
            "description": f"{name} service",
            "state": state,
            "sub_state": sub_state,
            "enabled": (
                random.choice(["enabled", "disabled", "static"])
            ),
            "following": (
                random.choice(["none", "multi-user.target"])
            ),
            "object_path": (
                f"/org/freedesktop/{name}"
            ),
            "target": {
                "ephemeral_id": str(random.randint(1000, 9999)),
                "type": random.choice(["start", "stop"]),
                "address": (
                    f"/systemd/job/{name}"
                )
            }
        }
    elif os_type == OS.WINDOWS:
        name = random.choice(["wuauserv", "bits", "wscsvc"])
        service_data = {
            "id": name,
            "name": random.choice(["Windows Update", "Background Intelligent Transfer Service", "Windows Security Center"]),
            "description": f"{name} service",
            "state": state,
            "start_type": random.choice(["AUTO_START", "DEMAND_START"]),
            "type": "OWN_PROCESS",
            "exit_code": random.choice([0, 1, 2]),
            "win32_exit_code": random.choice([0, 1, 2]),
            "address": f"\\\\{random.choice(['localhost', 'remotehost'])}"
        }

    else:
        service_data = {
            "id": random.choice(["com.apple.mdnamed", "com.apple.sshd"]),
            "name": random.choice(["MDNSResponder", "SSHD"]),
            "state": random.choice(["active", "stopped", "failed"]),
            "start_type": random.choice(["AUTO_START", "DEMAND_START"]),
            "type": "OWN_PROCESS",
            "enabled": random.choice(["enabled", "disabled"]),
            "restart": random.choice(["always", "on-failure", "never"]),
            "frequency": random.randint(10, 3600),
            "starts": {
                "on_mount": random.choice([True, False]),
                "on_path_modified": ["/usr/local", "/etc"],
                "on_not_empty_directory": ["/var/log"],
            },
            "inetd_compatibility": random.choice([True, False]),
        }
    return service_data

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

def generate_log(os_type=OS.LINUX):
    if os_type == OS.MACOS:
        return {
            "file": {
                "path": random.choice([
                    "/var/log/system.log",
                    "/var/log/install.log",
                    "/var/log/secure.log"
                ]),
            }
        }

def generate_error(os_type=OS.LINUX):
    if os_type == OS.MACOS:
        return {
            "log": {
                "file": {
                    "path": random.choice([
                        "/var/log/system.log",
                        "/var/log/install.log",
                        "/var/log/secure.log"
                    ]),
                }
            }
        }

def generate_random_data(number):
    data = []
    for _ in range(number):
        os_choice = random.choice(list(OS))
        service_data = generate_service(os_type=os_choice)
        event_data = {
            "agent": generate_agent(),
            "process": generate_process(os_type=os_choice, state=service_data["state"]),
            "service": service_data,
            "wazuh": generate_wazuh()
        }

        if os_choice == OS.MACOS:
            event_data["log"] = generate_log(os_type=os_choice)
            event_data["error"] = generate_error(os_type=os_choice)

        if os_choice == OS.LINUX:
            event_data["file"] = generate_file(os_type=os_choice)

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
