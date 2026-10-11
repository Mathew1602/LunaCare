"""Shared admin SDK setup for the FL scripts. Refuses to run against any project but newlunacare."""
import json
import os
import sys
from pathlib import Path

import firebase_admin
from firebase_admin import credentials

PROJECT_ID = "newlunacare"
BUCKET = "newlunacare.firebasestorage.app"
DEFAULT_KEY = Path.home() / "Downloads/newlunacare-firebase-adminsdk-fbsvc-0968d9f0e2.json"

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "federated-learning" / "functions-ml"))


def init_admin():
    if firebase_admin._apps:
        return firebase_admin.get_app()
    key = Path(os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", DEFAULT_KEY)).expanduser()
    project = json.loads(key.read_text()).get("project_id")
    if project != PROJECT_ID:
        sys.exit(f"refusing to run: credentials are for '{project}', expected '{PROJECT_ID}'")
    return firebase_admin.initialize_app(credentials.Certificate(str(key)),
                                         {"projectId": PROJECT_ID, "storageBucket": BUCKET})
