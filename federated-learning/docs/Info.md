# LunaCare PPD Model: How Retraining Works
- Firebase project: `newlunacare` (Blaze plan)
- Firestore location: `nam5` · Functions region: `us-central1` · Storage bucket: `newlunacare.firebasestorage.app`
- Code: `federated-learning/` (backend pipeline) and `LunaCare/FederatedLearning/` (iOS side)

---

## 1. The big picture

LunaCare predicts a PPD risk score (0 to 1) from the last 30 days of a mother's data: mood and
symptom logs plus HealthKit data (sleep, heart rate, HRV, steps, etc.).

The model is an **XGBoost regressor**, converted to **Core ML** so it runs on the phone. The risk
score is always computed **on the device**. Raw logs never leave the phone for the model.

```
 iPhone (opted-in mother)                 Firebase                              Doctor
 ─────────────────────────                ────────                              ──────
 30 days of logs + HealthKit
        │ summarize to 168 numbers
        ▼
 fl_contributions/{pseudoId}/snapshots ──┐
   (weekly, anonymous)                   │
                                         │   users/{uid}.ppdLabel  ◄─────────── marks PPD / no PPD
                                         ▼          │                           (via backend)
                          build_training_sample ◄───┘  (Cloud Function, fires on label/consent change)
                                         │
                                         ▼
                          training_samples/{pseudoId}  (features + doctor label, no identity)
                                         │
                          weekly_retrain (Sunday 03:00 Toronto)
                            synthetic base data + real samples → train → evaluate → gate
                                         │ passes gate
                                         ▼
                          Storage ml/models/vN/  +  Firestore ml_models/current = N
                                         │
 ModelUpdateService  ◄───────────────────┘
   download → verify → compile → hot-swap
```

Phones only **run** the model. All training happens in one Cloud Function, once a week.

---

## 2. How the data is collected (iOS)

### 2.1 Opt-in

Settings → Privacy → "Contribute to model" writes `users/{uid}.consent.contributeToModel = true`.
The first time a user opts in, the app also creates a random `users/{uid}.flPseudoId` (a UUID).
That pseudoId is the only key used for all training data.

Turning it off:
- sets `contributeToModel = false` first (security rules then reject any upload still in progress),
- deletes all of the user's `fl_contributions` from the phone,
- and the `build_training_sample` function also deletes them server-side, as a backup.

### 2.2 The 30-day window (`PPDWindowLoader.swift`)

Builds one record per day for the last 30 days by merging:
- daily `measurements` (HealthKit),
- `mood_logs` → `mood_1to5` (ecstatic 5, happy 4, okay 3, sad 2, angry 1),
- `symptom_logs` → fatigue, bleeding, hair loss, appetite, sleep trouble on 1–10 (unselected = 1).

If several logs exist on the same day, the latest one wins. Data comes from Firestore if cloud sync
is on, otherwise from the local stores on the phone. The same loader is used for on-device scoring
and for uploads, so both see identical features.

### 2.3 The 168 features (`PPDFeaturePipeline.swift`, mirrored by `functions-ml/features.py`)

28 daily measures × 6 summaries = 168 numbers:

| Summary | Meaning |
|---|---|
| `mean`, `std`, `min`, `max` | over the days that have a value |
| `slope` | linear trend across the 30 days |
| `last` | last **observed** value in the window (not necessarily day 30) |

Missing values stay missing (`NaN` / `null`), never `0`. Feature names and the schema version
(`FEATURE_SCHEMA_VERSION = 1`) live in `functions-ml/schema.py`. Swift and Python are kept
identical by a parity test (section 9).

### 2.4 Upload (`FLContributionService.swift`)

Runs when the app becomes active or a user signs in, at most **once every 7 days** per user
(forced immediately on opt-in). It uploads only if:
- consent is on and the user has a `flPseudoId`,
- at least **14 of the 30 days** have data.

It writes `fl_contributions/{pseudoId}/snapshots/{yyyy-MM-dd}`:

```json
{ "features": { "<168 names>": number | null },
  "daysWithData": 21,
  "windowStart": <Timestamp>, "windowEnd": <Timestamp>,
  "featureSchemaVersion": 1, "appModelVersion": 3 }
```

The 12 most recent snapshots are kept; older ones are deleted.

---

## 3. How it stays anonymous

| What | Where it lives | Contains identity? |
|---|---|---|
| Raw mood/symptom/health logs | phone (and the user's own `users/{uid}/...` if cloud sync is on) | not used for training |
| Snapshot (168 summary numbers) | `fl_contributions/{pseudoId}/...` | **no** uid, name or email |
| Training sample | `training_samples/{pseudoId}` | **no**; features + label only |
| Link uid ↔ pseudoId | `users/{uid}.flPseudoId` | readable only by that user and the admin SDK |

Guarantees enforced by `firestore.rules`:
- Only the owner can write their own snapshots, only while consent is on, and only in the exact
  expected shape (168 features, valid dates, schema version 1). No extra fields can be smuggled in.
- `flPseudoId` is write-once, and a user can't claim another user's pseudoId.
- `training_samples`, `training_runs` are not readable or writable by any app user.
- `ml_models` is read-only for signed-in users. Storage `ml/models/**` is read-only; everything
  else in Storage (e.g. the training dataset) is private.
- Opting out or deleting the account removes all contributions and the training sample.

Training only ever sees the 168 aggregates plus a 0/1 doctor label. It cannot tell which mother a
sample belongs to.

---

## 4. Doctor labels

Each user doc has:

```json
"ppdLabel": {
  "status": "unverified" | "ppd" | "no_ppd",
  "verifiedAt": <Timestamp | null>,
  "verifiedBy": "<doctorId>" | null
}
```

- New users get `{status: "unverified", verifiedAt: null, verifiedBy: null}` at signup
  (`UserRepository.createUserProfile`). Existing users were backfilled.
- Only `ppd` (label 1.0) and `no_ppd` (label 0.0) become training data. `unverified` is never
  treated as "no PPD".
- The app can only add that initial unverified label. Setting `ppd` / `no_ppd` requires the
  **admin SDK** (backend or `scripts/set_ppd_label.py`).
- There is one label per user. A new label replaces the previous one (and its training sample).

### 4.1 From label to training sample (`build_training_sample` function)

Fires on every write to `users/{uid}`, but only acts when label status, `verifiedAt`, consent or
`flPseudoId` changed. It then:

1. **Deletes** the sample if consent is off, the status is `unverified`, or there's no `verifiedAt`
   (and deletes all `fl_contributions` if consent is off).
2. Finds the newest snapshot whose window ends **on or before** `verifiedAt` and is at most
   **14 days** older than it. Data from after the diagnosis is never used.
3. If found and valid → writes `training_samples/{pseudoId}` with `pending: false`, the cleaned
   features and the label.
4. If no snapshot yet → writes a `pending: true` placeholder. Every Sunday the retrain retries
   pending samples. If still nothing after **30 days**, the pending sample is deleted
   (the doctor should re-verify after the mother's next upload).
5. If the snapshot has malformed features → the sample is dropped.

---

## 5. When the model retrains

`weekly_retrain` is a scheduled Cloud Function:
- **Every Sunday at 03:00 America/Toronto** (Cloud Scheduler job
  `firebase-schedule-weekly_retrain-us-central1`), 2 GB memory, 30-minute timeout.
- It can also be started manually (section 8).

Each run writes a document in `training_runs/` with its status, counts, metrics and reason.

### 5.1 Steps of a run

1. **Lock.** Takes `training_runs/_lock` (expires after 1 hour) so two runs can't overlap.
   If locked → `status: skipped`, "another retrain is running".
2. **Resolve pending** samples (section 4.1, step 4).
3. **Count new labels.** A sample is "new" if it was never used in a promoted model and was not
   already evaluated in an earlier rejected candidate.
   **Fewer than 5 new labels → `status: skipped`** (e.g. "0 new labels < 5"). No training happens.
4. **Load data.**
   - Synthetic base dataset `ml/base/user_level.parquet` (one row per synthetic mother, already
     split into fixed `train` / `test` sets).
   - All real `training_samples` with `pending: false` and schema version 1.
5. **Split real samples.** About 20% go to a **real holdout**, picked by hashing the pseudoId, so a
   mother always stays on the same side across runs.
6. **Train** a fresh XGBoost model on synthetic `train` + real train samples. Real samples get
   **5× weight**. Fixed hyperparameters and seed (600 trees, depth 5, learning rate 0.02).
7. **Evaluate** both the current model and the new one on:
   - synthetic `test` set → `mae_synth`, `r2_synth`
   - real holdout → `mae_real`, `auc_real`, `n_real_holdout`
     (these are `null` while the real holdout is empty)
8. **Gate** (section 5.2) → promote or keep as candidate.

### 5.2 Conditions to promote a new model

The new model is promoted only if **all** of these hold:

| Check | Rule |
|---|---|
| vs. current model, synthetic | `new.mae_synth ≤ current.mae_synth + 0.005` |
| vs. original v1 baseline | `new.mae_synth ≤ v1.mae_synth + 0.005` (stops slow drift over many versions) |
| vs. current model, real data | only when the real holdout has **≥ 5** samples: `new.mae_real ≤ current.mae_real` |

- **Pass → `status: promoted`.** Published as version N+1 (section 6). The real samples are
  stamped with `usedInVersion: N+1`.
- **Fail → `status: candidate`.** Nothing changes for users. The rejected model and its metrics are
  saved to `ml/candidates/{runId}/` for inspection, and the samples are stamped with
  `candidateRun` so the same data doesn't trigger another retrain next week. New labels are needed.
- Crash → `status: failed` with the error and a short traceback in the run document.

---

## 6. How a model is converted and published (`publish.py`, `convert.py`)

When a model is promoted:

1. **Convert to Core ML** with `coremltools` (`convert.to_coreml`). XGBoost learns its own
   `base_score`; coremltools assumes 0.5, so the real value is patched into the Core ML model.
2. **Validate** the Core ML spec: inputs are exactly the 168 feature names in order, output is
   `ppd_risk_score_0to1`, 600 trees, and the base score matches.
3. **Score 3 fixed test personas** (high, semi-high, average risk; `personas.py`) and store the
   features and expected scores in `metrics.json`. Phones use these to check the download.
4. **Upload** to Storage `ml/models/vN/`:
   - `PPDRiskModel.mlmodel` (for iOS)
   - `ppd_xgb_artifact.pkl` (joblib-pickled XGBoost model, for the Python ML service)
   - `metrics.json`
5. Write `ml_models/history/versions/vN`, then `ml/models/current.json`, then
   **`ml_models/current` last**. Phones watch `ml_models/current`, so they never see a half-published
   version.

`ml_models/current` contains `version`, `mlmodelPath`, `pklPath`, `metricsPath`, `sha256`
(of the .mlmodel), `metrics`, `featureSchemaVersion`, `trainedAt`, `runId`.

Version numbers only go up. A rollback republishes an old model as a **new** number
(`scripts/republish_version.py`). Example: v3 is a republish of v1 (`republishedFrom: 1`).

---

## 7. How phones get the new model (`ModelUpdateService.swift`)

When the app becomes active (at most every **6 hours**, signed-in users only):

1. Reads `ml_models/current`. Continues only if `version` is newer than the installed one, the
   feature schema matches, and that version wasn't rejected before.
2. Downloads the `.mlmodel` and checks its **sha256**.
3. Compiles it on the device.
4. Runs the 3 personas from `metrics.json` and requires each score to match within **0.0001**.
5. Swaps it into `PPDRiskModelRunner` without restarting the app. Keeps the new and previous
   version on disk; older ones are removed.

If the checksum or persona check fails, that version is skipped until a newer one is published.
Network errors just retry next time. The app ships with v1 bundled and falls back to it.
The active version is shown at Settings → Privacy → "Risk model version".

---

## 8. Commands

All from the `federated-learning/` folder unless noted. Setup once:

```bash
brew install python@3.11 libomp openjdk
python3.11 -m venv functions-ml/venv
functions-ml/venv/bin/pip install -r functions-ml/requirements.txt
npm --prefix tests/rules install
```

Admin scripts use `~/Downloads/newlunacare-firebase-adminsdk-fbsvc-0968d9f0e2.json` unless
`GOOGLE_APPLICATION_CREDENTIALS` is set, and refuse to run against any other project.
Never commit that key.

### Deploy

```bash
firebase deploy --only functions:ml --project newlunacare
firebase deploy --only firestore:rules,firestore:indexes,storage --project newlunacare
```

Always use `--only`. `functions:ml` is the Python codebase; a plain `firebase deploy` could touch
other functions in the project.

### Run, inspect, and debug the functions

```bash
# Start the weekly retrain now (normally Sunday 03:00)
gcloud scheduler jobs run firebase-schedule-weekly_retrain-us-central1 \
  --location us-central1 --project newlunacare

# Logs
firebase functions:log --only weekly_retrain --project newlunacare
firebase functions:log --only build_training_sample --project newlunacare
gcloud functions logs read weekly_retrain --region us-central1 --project newlunacare --limit 50

# List deployed functions / scheduler job
firebase functions:list --project newlunacare
gcloud scheduler jobs describe firebase-schedule-weekly_retrain-us-central1 \
  --location us-central1 --project newlunacare

# Health check (URL shown by functions:list; should reply "LunaCare FL functions online")
curl <hello_ml URL>
```

Results of each run: Firebase console → Firestore → `training_runs` (newest document).

### Labels and models (from the repo root)

```bash
PY=federated-learning/functions-ml/venv/bin/python

$PY federated-learning/scripts/set_ppd_label.py --email <email> --status ppd|no_ppd|unverified
$PY federated-learning/scripts/set_ppd_label.py --uid <uid> --status ppd --by <doctorId>
$PY federated-learning/scripts/set_ppd_label.py --list        # opted-in users, label, sample state
$PY federated-learning/scripts/set_ppd_label.py --backfill    # add unverified label to users missing one

$PY federated-learning/scripts/republish_version.py --from-version 1    # rollback
$PY federated-learning/scripts/bootstrap_base_dataset.py --csv <synthetic.csv>   # one-time, already done
```

### Tests

```bash
export PATH="$(brew --prefix openjdk)/bin:$PATH"
functions-ml/venv/bin/python -m pytest tests -q
firebase emulators:exec --only firestore,storage "npm --prefix tests/rules test"
OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES firebase emulators:exec --only firestore,functions \
  "functions-ml/venv/bin/python -m pytest tests/test_trigger_emulator.py -q"
```

The `OBJC_...` variable stops a macOS fork crash ("socket hang up") in the Functions emulator.

---

## 9. Swift / Python parity

The phone computes features in Swift; training uses Python. They must match exactly.

```bash
PY=federated-learning/functions-ml/venv/bin/python   # from repo root
$PY federated-learning/scripts/export_parity_fixture.py --check-coreml
$PY federated-learning/scripts/convert_bundled_model.py        # only when the bundled .pkl changes
```

Debug builds run `PPDParityCheck` at launch and print `[PPDParity] PASS/FAIL` in the Xcode console
(features within 1e-6, Core ML score within 1e-4 of the Python model).

---

## 10. Changing things safely

- **Feature changes** (new measure, different summary): bump `FEATURE_SCHEMA_VERSION` in both
  `schema.py` and `PPDFeaturePipeline.swift`, update the rules (`features.size()` and version),
  rebuild the base dataset, and regenerate the parity fixture. Old snapshots and phones on the old
  schema are ignored automatically.
- **Library versions:** `xgboost==3.2.0`, `scikit-learn==1.6.1`, `coremltools==9.0`
  (`functions-ml/requirements.txt`). Changing them can change predictions or break unpickling.
- **Rules:** `firestore.rules` replaces the live rules on deploy. Keep the `doctors/` block in sync
  with the console.

---

## 11. Current status

- Live model: **v3** (= v1 synthetic baseline, `mae_synth ≈ 0.0968`, `r2_synth ≈ 0.817`).
- Real labelled samples: **0**. Sunday runs will be `skipped` until at least 5 opted-in mothers
  with a recent snapshot are labelled `ppd` / `no_ppd`.
- `mae_real` / `auc_real` stay `null` until the real holdout has samples (roughly 25+ labelled
  mothers, since ~20% go to the holdout).

---

## 12. Work needed in the other repos

### 12.1 `luna-backend` (Express)

```
PATCH /users/:id/ppd-label
body: { "status": "ppd" | "no_ppd" | "unverified" }
auth: doctor only; doctor's patientIds must contain :id
```

```js
await admin.firestore().doc(`users/${id}`).set({
  ppdLabel: {
    status,
    verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    verifiedBy: req.doctor.id,
  },
}, { merge: true });
```

- Validate `status` against the three values. Return 400 otherwise.
- Add `ppdLabelStatus` (default `"unverified"`) to each row of `GET /users`.
- **The backend must point at `newlunacare`** for labels to reach the pipeline. It currently uses
  `lunacare-d181e`.
- Before real use: Firebase Auth for doctors, a `role=doctor` custom claim, and the `patientIds` check.

### 12.2 `luna-doctor-portal` (React, `Dashboard.jsx`)

"PPD Verified" column in the Patient Registry table:

- Segmented control: **Unverified | PPD | No PPD**, value from `ppdLabelStatus`.
- On change: confirm dialog ("Mark this patient as PPD? This is used to improve the risk model."),
  then optimistic update and `PATCH /users/:id/ppd-label` through `api.js`. Roll back on error.
- `onClick={e => e.stopPropagation()}` on the control so the row click (open patient) doesn't fire.

### 12.3 `luna-ml-service` (FastAPI on Cloud Run)

Load the latest model from Storage instead of a bundled file:

```
ml/models/current.json            {"version": N, "pklPath": "ml/models/vN/ppd_xgb_artifact.pkl", "sha256": "..."}
ml/models/vN/ppd_xgb_artifact.pkl keys: model, feature_cols, target_col, X_columns, version
ml/models/vN/metrics.json
```

1. On startup and every 10 minutes, read `ml/models/current.json`.
2. If `version` changed, download `pklPath`, `joblib.load` it, and swap the model under a lock.
3. Return `model_version` in the `/predict` response.
4. Keep serving the bundled pkl if Storage can't be reached.

**Version pinning (required to unpickle):** run `xgboost==3.2.0` and `scikit-learn==1.6.1`.
Other versions can fail to load or silently change predictions. Only load a pkl from
`ml/models/vN/` in this bucket (write access is blocked by Storage rules), since unpickling runs code.
Note: the `sha256` in `current.json` is the hash of the **.mlmodel**, not the .pkl, so it can't be
used to verify the pkl. Publishing a separate pkl hash is still to do.

Feature notes for `/predict` callers:
- Missing values must be `NaN`, not `0`.
- `_last` is the **last observed** value in the 30-day window.
- `functions-ml/features.py` is the reference implementation.

Cross-project read access (Cloud Run runs in `fir-example-bd842`):

```bash
gcloud storage buckets add-iam-policy-binding gs://newlunacare.firebasestorage.app \
  --member="serviceAccount:<cloud-run-service-account>@fir-example-bd842.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```
