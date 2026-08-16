from datetime import datetime, timezone

import pytest

from agent_x.domain import Case, Evidence, Finding, InvestigatorRole


def evidence(case_id: str, evidence_id: str = "e1") -> Evidence:
    return Evidence(
        evidence_id=evidence_id,
        case_id=case_id,
        source_type="public_web",
        source_uri="https://example.test/item",
        observed_at=datetime.now(timezone.utc),
        content="observed fact",
        collected_by="investigator-1",
        lawful_basis="publicly accessible source",
    )


def test_evidence_hash_is_deterministic() -> None:
    item = evidence("case-1")
    assert len(item.content_hash) == 64


def test_case_rejects_cross_case_evidence() -> None:
    case = Case("case-1", "test", "client")
    with pytest.raises(ValueError):
        case.add_evidence(evidence("case-2"))


def test_finding_requires_existing_evidence() -> None:
    case = Case("case-1", "test", "client")
    finding = Finding(
        "f1", "case-1", "Finding", "statement", 0.9, evidence_ids=["missing"]
    )
    with pytest.raises(ValueError):
        case.add_finding(finding)


def test_investigator_role_registration() -> None:
    case = Case("case-1", "test", "client")
    case.add_investigator("i1", InvestigatorRole.OSINT)
    assert case.investigators["i1"] == InvestigatorRole.OSINT
