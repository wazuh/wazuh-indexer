#!/env/bin/python3.9

import transform
import json


def _test():
    ocsf_event = {}
    with open("./wazuh-event.sample.json", "r") as fd:
        # Load from file descriptor
        raw_event = json.load(fd)
        try:
            event = transform.converter.from_json(raw_event)
            print(event)
            ocsf_event = transform.converter.to_detection_finding(event)
            print("")
            print("--")
            print("")
            print(ocsf_event)
        #     event = Event.model_validate_json(json.dumps(event))
        #     print(event)
        #     ocsf_event = to_detection_finding(event)

        except KeyError as e:
            raise (e)
        # except ValidationError as e:
        #     print(e)

        # if ocsf_event:
        #     with open("wazuh-event.ocsf.json", "w") as fd:
        #         json.dump(ocsf_event.model_dump(), fd)
        #         print(ocsf_event.model_dump())


if __name__ == '__main__':
    _test()
