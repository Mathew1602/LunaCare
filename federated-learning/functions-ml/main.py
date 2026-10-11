from firebase_admin import firestore, initialize_app, storage
from firebase_functions import firestore_fn, https_fn, options, scheduler_fn

BUCKET = "newlunacare.firebasestorage.app"

initialize_app()


@https_fn.on_request(region="us-central1", memory=options.MemoryOption.MB_256)
def hello_ml(req: https_fn.Request) -> https_fn.Response:
    return https_fn.Response("LunaCare FL functions online")


@firestore_fn.on_document_written(document="users/{uid}", region="us-central1",
                                  memory=options.MemoryOption.MB_256)
def build_training_sample(event: firestore_fn.Event[firestore_fn.Change]) -> None:
    from build_training_sample import delete_contributions, sync_sample, watched

    before = event.data.before.to_dict() if event.data.before and event.data.before.exists else {}
    after = event.data.after.to_dict() if event.data.after and event.data.after.exists else {}
    if watched(before) == watched(after):
        return
    pid = after.get("flPseudoId") or before.get("flPseudoId")
    if not pid:
        return
    db = firestore.client()
    action = sync_sample(db, pid, after)
    print(f"training_samples/{pid[:8]}…: {action}")
    if not (after.get("consent") or {}).get("contributeToModel", False):
        latest = db.collection("users").document(event.params["uid"]).get()
        if latest.exists and ((latest.to_dict().get("consent") or {}).get("contributeToModel", False)):
            return
        delete_contributions(db, pid)
        print(f"fl_contributions/{pid[:8]}…: deleted (opted out or user deleted)")


@scheduler_fn.on_schedule(schedule="every sunday 03:00", timezone="America/Toronto",
                          region="us-central1", memory=options.MemoryOption.GB_2,
                          timeout_sec=1800)
def weekly_retrain(event: scheduler_fn.ScheduledEvent) -> None:
    from weekly_retrain import run_retrain

    result = run_retrain(firestore.client(), storage.bucket(BUCKET))
    print({k: v for k, v in result.items() if k != "trace"})
