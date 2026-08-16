from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

from .domain import Case, Evidence, InvestigatorRole


@dataclass(frozen=True)
class InvestigativeAssignment:
    investigator_id: str
    role: InvestigatorRole
    objective: str


class Investigator(Protocol):
    role: InvestigatorRole

    def investigate(self, case: Case) -> list[Evidence]: ...


class InvestigationPolicy:
    """Safety boundary for autonomous investigative work.

    Integrations must provide an explicit lawful_basis before collection.
    The framework does not implement credential bypass, intrusion, private
    interception, or deceptive impersonation of real people.
    """

    ALLOWED_SOURCE_TYPES = {
        "public_web",
        "public_api",
        "client_provided",
        "authorized_system",
        "authorized_log",
    }

    def validate_evidence(self, evidence: Evidence) -> None:
        if evidence.source_type not in self.ALLOWED_SOURCE_TYPES:
            raise PermissionError(
                f"source type '{evidence.source_type}' is not approved"
            )
        if not evidence.lawful_basis.strip():
            raise PermissionError("evidence requires an explicit lawful basis")


class InvestigationOrchestrator:
    def __init__(self, policy: InvestigationPolicy | None = None) -> None:
        self.policy = policy or InvestigationPolicy()

    def collect(self, case: Case, investigator: Investigator) -> int:
        evidence_items = investigator.investigate(case)
        accepted = 0
        for evidence in evidence_items:
            self.policy.validate_evidence(evidence)
            case.add_evidence(evidence)
            accepted += 1
        return accepted
