#!/usr/bin/python

# event comes from Filebeat
event = {}


def normalize(level: int) -> int:
    """
    Normalizes rule level into the 0-6 range, required by OCSF.
    """
    # TODO normalization
    return level


def join(iterable, separator=","):
    return (separator.join(iterable))


def convert(event: dict) -> dict:
    """
    Converts Wazuh events to OCSF's Detecting Finding (2004) class.
    """
    ocsf_class_template = \
        {
            "activity_id": 1,
            "category_name": "Findings",
            "category_uid": 2,
            "class_name": "Detection Finding",
            "class_uid": 2004,
            "count": event["_source"]["rule"]["firedtimes"],
            "message": event["_source"]["rule"]["description"],
            "finding_info": {
                "analytic": {
                    "category": join(event["_source"]["rule"]["groups"]),
                    "name": event["_source"]["decoder"]["name"],
                    "type_id": 1,
                    "uid": event["_source"]["rule"]["id"],
                },
                "attacks": {
                    "tactic": {
                        "name": join(event["_source"]["rule"]["mitre"]["tactic"]),
                    },
                    "technique": {
                        "name": join(event["_source"]["rule"]["mitre"]["technique"]),
                        "uid": join(event["_source"]["rule"]["mitre"]["id"]),
                    },
                    "version": "v13.1"
                },
                "title": event["_source"]["rule"]["description"],
                "types": [
                    event["_source"]["input"]["type"]
                ],
                "uid": event["_source"]['id']
            },
            "metadata": {
                "log_name": "Security events",
                "log_provider": "Wazuh",
                "product": {
                    "name": "Wazuh",
                    "lang": "en",
                    "vendor_name": "Wazuh, Inc,."
                },
                "version": "1.1.0",
            },
            "raw_data": event["_source"]["full_log"],
            "resources": [
                {
                    "name": event["_source"]["agent"]["name"],
                    "uid": event["_source"]["agent"]["id"]
                },
            ],
            "risk_score": event["_source"]["rule"]["level"],
            "severity_id": normalize(event["_source"]["rule"]["level"]),
            "status_id": 99,
            "time": event["_source"]["timestamp"],
            "type_uid": 200401,
            "unmapped": {
                "data_sources": [
                    event["_index"],
                    event["_source"]["location"],
                    event["_source"]["manager"]["name"]
                ],
                "nist": event["_source"]["rule"]["nist_800_53"],  # Array
            }
        }

    return ocsf_class_template
