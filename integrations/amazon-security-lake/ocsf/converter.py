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
            "count": event["rule"]["firedtimes"],
            "message": event["rule"]["description"],
            "finding_info": {
                "analytic": {
                    "category": join(event["rule"]["groups"]),
                    "name": event["decoder"]["name"],
                    "type_id": 1,
                    "uid": event["rule"]["id"],
                },
                "attacks": {
                    "tactic": {
                        "name": join(event["rule"]["mitre"]["tactic"]),
                    },
                    "technique": {
                        "name": join(event["rule"]["mitre"]["technique"]),
                        "uid": join(event["rule"]["mitre"]["id"]),
                    },
                    "version": "v13.1"
                },
                "title": event["rule"]["description"],
                "types": [
                    event["input"]["type"]
                ],
                "uid": event['id']
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
            "raw_data": event["full_log"],
            "resources": [
                {
                    "name": event["agent"]["name"],
                    "uid": event["agent"]["id"]
                },
            ],
            "risk_score": event["rule"]["level"],
            "severity_id": normalize(event["rule"]["level"]),
            "status_id": 99,
            "time": event["timestamp"],
            "type_uid": 200401,
            "unmapped": {
                "data_sources": [
                    event["_index"],
                    event["location"],
                    event["manager"]["name"]
                ],
                "nist": event["rule"]["nist_800_53"],  # Array
            }
        }

    return ocsf_class_template
