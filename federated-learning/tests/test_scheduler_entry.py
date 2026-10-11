"""weekly_retrain entry point must accept every X-CloudScheduler-ScheduleTime format Cloud Scheduler sends.
firebase-functions 0.4.x crashed on fractional seconds (manual "Force run"), before run_retrain started."""
import pytest
from flask import Flask, request

import main
import weekly_retrain


@pytest.mark.parametrize("header", [
    "2026-10-18T00:00:02.462208-07:00",
    "2026-10-18T03:00:00-04:00",
    "2026-10-18T07:00:00Z",
])
def test_schedule_time_header_parses(monkeypatch, header):
    calls = []
    monkeypatch.setattr(main.firestore, "client", lambda: None)
    monkeypatch.setattr(main.storage, "bucket", lambda name: None)
    monkeypatch.setattr(weekly_retrain, "run_retrain", lambda db, bucket, force=False: calls.append(1) or {})
    with Flask(__name__).test_request_context("/", method="POST",
                                              headers={"X-CloudScheduler-ScheduleTime": header}):
        assert main.weekly_retrain(request).status_code == 200
    assert calls == [1]
