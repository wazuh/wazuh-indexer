import pydantic
import typing


class AnalyticInfo(pydantic.BaseModel):
    category: str
    name: str
    type_id: int
    uid: str


# Deprecated since v1.1.0. Use AnalyticInfo instead.
class Analytic(pydantic.BaseModel):
    category: str
    name: str
    type: str = "Rule"
    type_id: int = 1
    uid: str


class TechniqueInfo(pydantic.BaseModel):
    name: str
    uid: str


class AttackInfo(pydantic.BaseModel):
    tactic: TechniqueInfo
    technique: TechniqueInfo
    version: str


class FindingInfo(pydantic.BaseModel):
    analytic: AnalyticInfo
    attacks: typing.List[AttackInfo]
    title: str
    types: typing.List[str]
    uid: str


# Deprecated since v1.1.0. Use FindingInfo instead.
class Finding(pydantic.BaseModel):
    title: str
    types: typing.List[str]
    uid: str


class ProductInfo(pydantic.BaseModel):
    name: str
    lang: str
    vendor_name: str


class Metadata(pydantic.BaseModel):
    log_name: str
    log_provider: str
    product: ProductInfo
    version: str


class Resource(pydantic.BaseModel):
    name: str
    uid: str


class DetectionFinding(pydantic.BaseModel):
    activity_id: int = 1
    category_name: str = "Findings"
    category_uid: int = 2
    class_name: str = "Detection Finding"
    class_uid: int = 2004
    count: int
    message: str
    finding_info: FindingInfo
    metadata: Metadata
    raw_data: str
    resources: typing.List[Resource]
    risk_score: int
    severity_id: int
    status_id: int = 99
    time: int
    type_uid: int = 200401
    unmapped: typing.Dict[str, typing.List[str]] = pydantic.Field()


# Deprecated since v1.1.0. Use DetectionFinding instead.
class SecurityFinding(pydantic.BaseModel):
    activity_id: int = 1
    analytic: Analytic
    attacks: typing.List[AttackInfo]
    category_name: str = "Findings"
    category_uid: int = 2
    class_name: str = "Security Finding"
    class_uid: int = 2001
    count: int
    message: str
    finding: Finding
    metadata: Metadata
    raw_data: str
    resources: typing.List[Resource]
    risk_score: int
    severity_id: int
    state_id: int = 1
    status_id: int = 99
    time: int
    type_uid: int = 200101
    unmapped: typing.Dict[str, typing.List[str]] = pydantic.Field()
