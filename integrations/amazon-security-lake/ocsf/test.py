#!/usr/bin/python

from converter import convert
import json

converted_event = {}
with open("wazuh-event.sample.json", "r") as fd:
    sample_event = json.load(fd)
    # print(json.dumps(sample_event, indent=4))
    converted_event = convert(sample_event)
    
if converted_event:
    with open("wazuh-event.ocsf.json", "w") as fd:
        json.dump(converted_event, fd)
        print("Done")