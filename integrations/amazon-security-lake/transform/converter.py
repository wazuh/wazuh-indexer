import json

import pydantic
import transform.models as models


def normalize(level: int) -> int:
    """
    Normalizes rule level into the 0-6 range, required by OCSF.
    """
    # TODO normalization
    return level


def join(iterable, separator=","):
    return (separator.join(iterable))


def to_detection_finding(event: models.wazuh.Event) -> models.ocsf.DetectionFinding:
    finding_info = models.ocsf.FindingInfo(
        analytic=models.ocsf.AnalyticInfo(
            category=", ".join(event.rule.groups),
            name=event.decoder.name,
            type_id=1,
            uid=event.rule.id
        ),
        attacks=models.ocsf.AttackInfo(
            tactic=models.ocsf.TechniqueInfo(
                name=", ".join(event.rule.mitre.tactic),
                uid=", ".join(event.rule.mitre.id)
            ),
            technique=models.ocsf.TechniqueInfo(
                name=", ".join(event.rule.mitre.technique),
                uid=", ".join(event.rule.mitre.id)
            ),
            version="v13.1"
        ),
        title=event.rule.description,
        types=[event.input.type],
        uid=event.id
    )

    metadata = models.ocsf.Metadata(
        log_name="Security events",
        log_provider="Wazuh",
        product=models.ocsf.ProductInfo(
            name="Wazuh",
            lang="en",
            vendor_name="Wazuh, Inc,."
        ),
        version="1.1.0"
    )

    resources = [models.ocsf.Resource(
        name=event.agent.name, uid=event.agent.id)]

    severity_id = normalize(event.rule.level)

    unmapped = {
        "data_sources": [
            event.location,
            event.manager.name
        ],
        "nist": event.rule.nist_800_53  # Array
    }

    return models.ocsf.DetectionFinding(
        count=event.rule.firedtimes,
        message=event.rule.description,
        finding_info=finding_info,
        metadata=metadata,
        raw_data=event.full_log,
        resources=resources,
        risk_score=event.rule.level,
        severity_id=severity_id,
        time=event.timestamp,
        unmapped=unmapped
    )


def from_json(event: dict) -> models.wazuh.Event:
    # Needs to a string, bytes or bytearray
    try:
        return models.wazuh.Event.model_validate_json(json.dumps(event))
    except pydantic.ValidationError as e:
        print(e)


def _test():
    ocsf_event = {}
    with open("wazuh-event.sample.json", "r") as fd:
        # Load from file descriptor
        event = json.load(fd)
        try:
            # Create instance of Event from JSON input (must be string, bytes or bytearray)
            event = models.wazuh.Event.model_validate_json(json.dumps(event))
            print(event)
            ocsf_event = to_detection_finding(event)

        except KeyError as e:
            raise (e)
        except pydantic.ValidationError as e:
            print(e)

        if ocsf_event:
            with open("wazuh-event.ocsf.json", "w") as fd:
                json.dump(ocsf_event.model_dump(), fd)
                print(ocsf_event.model_dump())


if __name__ == '__main__':
    _test()
