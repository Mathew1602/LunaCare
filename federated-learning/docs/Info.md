## 1. Firestore contract (project `newlunacare`)

`users/{uid}.ppdLabel`

```json
{
  "status": "unverified" | "ppd" | "no_ppd",
  "verifiedAt": <Timestamp, server time>,
  "verifiedBy": "<doctorId>"
}
```

- Only `ppd` (label 1.0) and `no_ppd` (label 0.0) become training data. `unverified` is never treated as negative.
- Security rules block clients from writing `ppdLabel`. It must be written with the **admin SDK** (backend).
- Writing it fires the `build_training_sample` Cloud Function, which builds `training_samples/{pseudoId}`
  from the mother's latest contribution snapshot dated on or before `verifiedAt`. Only mothers with
  `consent.contributeToModel == true` are used.
- **The backend must point at `newlunacare`** for labels to reach the pipeline. It currently uses `lunacare-d181e`.

## 2. `luna-backend` (Express)

Suggested endpoint:

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
- Before real use: Firebase Auth for doctors, a `role=doctor` custom claim, and the `patientIds` check above.

## 3. `luna-doctor-portal` (React, `Dashboard.jsx`)

Suggested "PPD Verified" column in the Patient Registry table:

- Segmented control: **Unverified | PPD | No PPD**, value from `ppdLabelStatus`.
- On change: confirm dialog ("Mark this patient as PPD? This is used to improve the risk model."),
  then optimistic update and `PATCH /users/:id/ppd-label` through `api.js`. Roll back on error.
- `onClick={e => e.stopPropagation()}` on the control so the row click (open patient) doesn't fire.

## 4. `luna-ml-service` (FastAPI on Cloud Run)

Each promoted model is published to Storage bucket `newlunacare.firebasestorage.app`:

```
ml/models/current.json            {"version": N, "pklPath": "ml/models/vN/ppd_xgb_artifact.pkl", "sha256": "..."}
ml/models/vN/ppd_xgb_artifact.pkl same keys as today: model, feature_cols, target_col, X_columns (+ version)
ml/models/vN/metrics.json
```

Suggested `ModelHolder` reload:

1. On startup and every 10 minutes, read `ml/models/current.json`.
2. If `version` changed, download `pklPath`, `joblib.load` it, and swap the model under a lock.
3. Return `model_version` in the `/predict` response.
4. Keep serving the bundled pkl if Storage can't be reached.

**Version pinning (required to unpickle):** the pkl is a pickled `XGBRegressor`, so the service must run
`xgboost==3.2.0` and `scikit-learn==1.6.1` (same as `functions-ml/requirements.txt`). Other versions can fail
to load or silently change predictions. Check `sha256` from `current.json` before loading; never load a pkl
from any other path, since unpickling runs code.

Feature notes for `/predict` callers:
- Missing values must be `NaN`, not `0`.
- `_last` is the **last observed** value in the 30-day window (not the day-30 value).
- `features.py` in `federated-learning/functions-ml/` is the reference implementation.

Cross-project read access (Cloud Run runs in `fir-example-bd842`):

```bash
gcloud storage buckets add-iam-policy-binding gs://newlunacare.firebasestorage.app \
  --member="serviceAccount:<cloud-run-service-account>@fir-example-bd842.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```
