from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from hashlib import sha256
from typing import Any


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class InvestigatorRole(str, Enum):
    CASE_MANAGER = "case_manager"
    OSINT = "osint"
    BEHAVIOR = "behavior"
    COMMUNICATIONS = "communications"
    FORENSICS = "forensics"
    COUNTERINTELLIGENCE = "counterintelligence"
    CORROBORATOR = "corroborator"


class RiskLevel(str, Enum):
    NONE = "none"
    LOW = "low"
    MODERATE = "moderate"
    HIGH = "high"
    CRITICAL = "critical"


@dataclass(frozen=True)
class Evidence:
    evidence_id: str
    case_id: str
    source_type: str
    source_uri: str
    observed_at: datetime
    content: str
    collected_by: str
    lawful_basis: str
    metadata: dict[str, Any] = field(default_factory=dict)
    content_hash: str = field(init=False)

    def __post_init__(self) -> None:
        digest = sha256(self.content.encode("utf-8")).hexdigest()
        object.__setattr__(self, "content_hash", digest)


@dataclass
class Finding:
    finding_id: str
    case_id: str
    title: str
    statement: str
    confidence: float
    evidence_ids: list[str] = field(default_factory=list)
    risk: RiskLevel = RiskLevel.NONE
    analyst: str = ""
    created_at: datetime = field(default_factory=utc_now)

    def __post_init__(self) -> None:
        if not 0.0 <= self.confidence <= 1.0:
            raise ValueError("confidence must be between 0 and 1")


@dataclass
class Case:
    case_id: str
    objective: str
    client_reference: str
    created_at: datetime = field(default_factory=utc_now)
    investigators: dict[str, InvestigatorRole] = field(default_factory=dict)
    evidence: dict[str, Evidence] = field(default_factory=dict)
    findings: list[Finding] = field(default_factory=list)
    status: str = "open"

    def add_investigator(self, investigator_id: str, role: InvestigatorRole) -> None:
        self.investigators[investigator_id] = role

    def add_evidence(self, evidence: Evidence) -> None:
        if evidence.case_id != self.case_id:
            raise ValueError("evidence belongs to a different case")
        self.evidence[evidence.evidence_id] = evidence

    def add_finding(self, finding: Finding) -> None:
        if finding.case_id != self.case_id:
            raise ValueError("finding belongs to a different case")
        missing = set(finding.evidence_ids) - self.evidence.keys()
        if missing:
            raise ValueError(f"finding references missing evidence: {sorted(missing)}")
        self.findings.append(finding)
