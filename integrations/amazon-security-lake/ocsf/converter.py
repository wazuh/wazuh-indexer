#!/usr/bin/python

# event comes from Filebeat
event = {}

def normalize(level: int) -> int:
    """
    Normalizes rule level into the 0-6 range, required by OCSF.
    """
    # TODO normalization
    return level

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
                "category": event["_source"]["rule"]["groups"], # Err: rule.groups is a string array, but analytic.category is a string
                "name": event["_source"]["decoder"]["name"],
                "type": "Rule", # analytic.type is redundant together with type_id
                "type_id": 1,
                "uid": event["_source"]["rule"]["id"], 
            },
            "attacks": {
                "tactic": event["_source"]["rule"]["mitre"]["tactic"], # Err: rule.mitre.tactic is a string array, but attacks.tactic is an object
                "technique": event["_source"]["rule"]["mitre"]["technique"], # Err: rule.mitre.technique is a string array, but attacks.technique is an object
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
                # Skipped. 
                # OCSF description of this field is: The version of the product, as
                # defined by the event source. For example: 2013.1.3-beta. We do not
                # save such info as part of the event data.
                # "version": "4.9.0", 
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
            "nist": event["_source"]["rule"]["nist_800_53"], # Array
        }
    }

    return ocsf_class_template