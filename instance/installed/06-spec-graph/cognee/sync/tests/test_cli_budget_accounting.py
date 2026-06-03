from __future__ import annotations

from typing import Any

from cognee_sync import cli


def test_token_usage_counts_prefers_actual_counts() -> None:
    actual = {"prompt_tokens": 11, "completion_tokens": 7, "total_tokens": 18}

    assert cli._token_usage_counts(999, actual) == (11, 7, 18)


def test_token_usage_counts_falls_back_to_requested_tokens() -> None:
    assert cli._token_usage_counts(400, None) == (400, 0, 400)


def test_record_cognify_usage_records_only_delta_when_actual_exceeds_reservation(
    monkeypatch: Any,
) -> None:
    budget_calls: list[tuple[str, int]] = []
    event_calls: list[dict[str, Any]] = []

    monkeypatch.setattr(cli, "_record_budget_usage", lambda repo_key, consumed: budget_calls.append((repo_key, consumed)))
    monkeypatch.setattr(
        cli,
        "_emit_token_usage_event",
        lambda **kwargs: event_calls.append(kwargs),
    )

    actual = {"prompt_tokens": 120, "completion_tokens": 80, "total_tokens": 200}
    cli._record_cognify_usage(
        repo_key="eposforge",
        dataset_name="eposforge-sync",
        model="test-model",
        requested_tokens=150,
        actual=actual,
        latency_ms=42,
        budget_enforce=True,
        emit_usage_events=True,
    )

    assert budget_calls == [("eposforge", 50)]
    assert event_calls == [
        {
            "repo_key": "eposforge",
            "dataset_name": "eposforge-sync",
            "model": "test-model",
            "prompt_tokens": 120,
            "completion_tokens": 80,
            "total_tokens": 200,
            "latency_ms": 42,
        }
    ]


def test_record_cognify_usage_records_nothing_extra_when_actual_is_below_reservation(
    monkeypatch: Any,
) -> None:
    budget_calls: list[tuple[str, int]] = []
    event_calls: list[dict[str, Any]] = []

    monkeypatch.setattr(cli, "_record_budget_usage", lambda repo_key, consumed: budget_calls.append((repo_key, consumed)))
    monkeypatch.setattr(
        cli,
        "_emit_token_usage_event",
        lambda **kwargs: event_calls.append(kwargs),
    )

    actual = {"prompt_tokens": 60, "completion_tokens": 20, "total_tokens": 80}
    cli._record_cognify_usage(
        repo_key="eposforge",
        dataset_name="eposforge-sync",
        model="test-model",
        requested_tokens=150,
        actual=actual,
        latency_ms=11,
        budget_enforce=True,
        emit_usage_events=True,
    )

    assert budget_calls == []
    assert event_calls == [
        {
            "repo_key": "eposforge",
            "dataset_name": "eposforge-sync",
            "model": "test-model",
            "prompt_tokens": 60,
            "completion_tokens": 20,
            "total_tokens": 80,
            "latency_ms": 11,
        }
    ]
