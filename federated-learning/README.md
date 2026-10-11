# LunaCare Federated Learning

FL-inspired, privacy-preserving centralized retraining of the LunaCare PPD risk model
(XGBoost → Core ML). Opted-in mothers upload a pseudonymous 30-day feature summary
(168 aggregates, no raw logs, no identity). A weekly Cloud Function retrains on synthetic
data plus doctor-verified samples, gates on a fixed holdout, and publishes a new Core ML
model that the iOS app downloads and hot-swaps. Phones never train; they only run inference.

Firebase project: `newlunacare` (Blaze). Functions region: `us-central1`.

## Layout

```
federated-learning/
├── firebase.json            # functions codebase "ml", rules, indexes, emulators
├── .firebaserc              # default project: newlunacare
├── firestore.rules          # Step 6 (merged with the live users/doctors rules)
├── storage.rules
├── firestore.indexes.json
├── functions-ml/            # Cloud Functions gen2, Python 3.11
│   ├── main.py              # hello_ml, build_training_sample (Step 7), weekly_retrain (Step 8)
│   ├── schema.py            # feature names + schema version (no heavy imports; used by the trigger)
│   ├── features.py          # 168-feature summary, mirror of iOS PPDFeaturePipeline
│   ├── build_training_sample.py  # training_samples sync, pending expiry, feature sanitising, opt-out cleanup
│   ├── weekly_retrain.py    # retrain, evaluate, gate (vs current + fixed v1 baseline), run lock
│   ├── publish.py           # Core ML convert + validate + versioned upload (Step 9)
│   ├── personas.py          # seeded notebook personas for metrics.json
│   ├── convert.py           # XGBoost -> Core ML with the correct base_score
│   └── requirements.txt
├── scripts/
│   ├── set_ppd_label.py               # Step 5: doctor label via admin SDK
│   ├── bootstrap_base_dataset.py      # Step 8a: parquet + v1 to Storage
│   ├── republish_version.py           # rollback: republish vK as a new version
│   ├── export_parity_fixture.py       # -> LunaCare/FederatedLearning/ppd_parity_fixture.json
│   └── convert_bundled_model.py       # -> LunaCare/MachineLearning/PPDRiskModel.mlmodel
├── tests/
│   ├── test_weekly_retrain.py         # pytest: split, gate, Core ML structure + parity, publish order
│   ├── test_trigger_emulator.py       # Step 7 trigger in the emulator
│   └── rules/rules.test.mjs           # Step 6 rules in the emulator
└── docs/Info.md
```

## Setup (macOS)

```bash
brew install python@3.11 libomp
cd federated-learning
python3.11 -m venv functions-ml/venv
functions-ml/venv/bin/pip install -r functions-ml/requirements.txt
```

`requirements.txt` installs `xgboost-cpu` on Linux (Cloud Build, avoids ~300 MB of CUDA libs)
and regular `xgboost` on macOS, since `xgboost-cpu` ships no macOS wheel. `libomp` is required
by XGBoost on macOS.

One-time cloud setup (already done for `newlunacare`):

```bash
gcloud services enable cloudfunctions.googleapis.com run.googleapis.com \
  cloudbuild.googleapis.com artifactregistry.googleapis.com \
  cloudscheduler.googleapis.com eventarc.googleapis.com pubsub.googleapis.com \
  firebasestorage.googleapis.com storage.googleapis.com --project newlunacare
```

- Firebase console → Storage → Get started (region `us-central1`).
- GCP Billing → Budgets & alerts → $5 budget alert.

## Swift / Python parity (Step 2)

```bash
PY=federated-learning/functions-ml/venv/bin/python   # from repo root
$PY federated-learning/scripts/convert_bundled_model.py        # only when the .pkl changes
$PY federated-learning/scripts/export_parity_fixture.py --check-coreml
```

Debug builds run `PPDParityCheck` at launch and print `[PPDParity] PASS/FAIL` to the Xcode console
(features within 1e-6, Core ML score within 1e-4 of `model.predict`).

## Labels and demo data (Steps 5, 8)

Admin scripts use `~/Downloads/newlunacare-firebase-adminsdk-fbsvc-0968d9f0e2.json` unless
`GOOGLE_APPLICATION_CREDENTIALS` is set, and refuse any other project.

```bash
PY=federated-learning/functions-ml/venv/bin/python   # from repo root
$PY federated-learning/scripts/set_ppd_label.py --email <email> --status ppd|no_ppd|unverified
$PY federated-learning/scripts/set_ppd_label.py --list
gcloud scheduler jobs run firebase-schedule-weekly_retrain-us-central1 --location us-central1 --project newlunacare
$PY federated-learning/scripts/republish_version.py --from-version 1             # rollback (phones only move forward)
```

## iOS model updates (Step 10)

`LunaCare/FederatedLearning/ModelUpdateService.swift` checks `ml_models/current` on app activation (max once per 6 h,
signed-in users only). A newer version is downloaded from Storage, checked against `sha256`, compiled on device,
checked against the persona scores in `metrics.json` (1e-4), then swapped into `PPDRiskModelRunner`.
The Privacy screen shows the active version. The bundled model is v1.

## Tests

```bash
cd federated-learning
functions-ml/venv/bin/python -m pytest tests -q
npm --prefix tests/rules install
firebase emulators:exec --only firestore,storage "npm --prefix tests/rules test"
firebase emulators:exec --only firestore,functions "functions-ml/venv/bin/python -m pytest tests/test_trigger_emulator.py -q"
```

The emulator needs Java (`brew install openjdk`, then add `/opt/homebrew/opt/openjdk/bin` to `PATH`).
On macOS the Functions emulator worker can crash on fork ("socket hang up"); run the trigger tests with
`OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES`.

## Deploy

```bash
cd federated-learning
firebase deploy --only functions:ml --project newlunacare
firebase deploy --only firestore:rules,firestore:indexes,storage --project newlunacare
```

`firestore.rules` replaces the live rules. Keep the `doctors/` block in sync with the console.

Always deploy with `--only`. Never commit the admin SDK key, parquet, `.pkl`, or `.mlmodel`
artifacts; they live in Firebase Storage.
