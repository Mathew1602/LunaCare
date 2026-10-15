// Run via: firebase emulators:exec --only firestore,storage "npm --prefix tests/rules test"
import { after, before, beforeEach, test } from "node:test";
import { readFileSync } from "node:fs";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { Timestamp, deleteDoc, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";
import { getBytes, ref, uploadString } from "firebase/storage";

const ALICE = "alice";
const BOB = "bob";
const ALICE_PID = "pid-alice";
const BOB_PID = "pid-bob";

const DAY_MS = 86400000;
const FEATURES = Object.fromEntries(Array.from({ length: 168 }, (_, i) => [`f${i}`, i === 0 ? null : 1.0]));

function snapshot(overrides = {}) {
  const now = Date.now();
  return {
    features: FEATURES,
    daysWithData: 20,
    windowStart: Timestamp.fromMillis(now - 29 * DAY_MS),
    windowEnd: Timestamp.fromMillis(now),
    featureSchemaVersion: 1,
    appModelVersion: 1,
    ...overrides,
  };
}

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "newlunacare",
    firestore: { rules: readFileSync(new URL("../../firestore.rules", import.meta.url), "utf8") },
    storage: { rules: readFileSync(new URL("../../storage.rules", import.meta.url), "utf8") },
  });
});

after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users", ALICE), { consent: { contributeToModel: true }, flPseudoId: ALICE_PID });
    await setDoc(doc(db, "users", BOB), { consent: { contributeToModel: true }, flPseudoId: BOB_PID });
    await setDoc(doc(db, "fl_contributions", BOB_PID), { featureSchemaVersion: 1 });
    await setDoc(doc(db, "training_samples", ALICE_PID), { label: 1.0 });
    await setDoc(doc(db, "ml_models", "current"), { version: 1 });
    await setDoc(doc(db, "doctors", "doc1"), { patientIds: [ALICE], pendingPatientIds: [BOB] });
    await uploadString(ref(ctx.storage(), "ml/models/v1/metrics.json"), "{}");
    await uploadString(ref(ctx.storage(), "ml/base/user_level.parquet"), "x");
  });
});

const alice = () => env.authenticatedContext(ALICE).firestore();
const anon = () => env.unauthenticatedContext().firestore();

test("user cannot write ppdLabel", async () => {
  await assertFails(updateDoc(doc(alice(), "users", ALICE), { ppdLabel: { status: "ppd" } }));
  await assertFails(setDoc(doc(alice(), "users", ALICE), { ppdLabel: { status: "ppd" } }, { merge: true }));
});

test("new user cannot create own doc with ppdLabel", async () => {
  const db = env.authenticatedContext("carol").firestore();
  await assertFails(setDoc(doc(db, "users", "carol"), { ppdLabel: { status: "no_ppd" } }));
  await assertSucceeds(setDoc(doc(db, "users", "carol"), { name: "Carol" }));
});

test("client may only add the initial unverified ppdLabel", async () => {
  const initial = { status: "unverified", verifiedAt: null, verifiedBy: null };
  const db = env.authenticatedContext("carol").firestore();
  await assertSucceeds(setDoc(doc(db, "users", "carol"), { name: "Carol", ppdLabel: initial }, { merge: true }));
  await assertFails(updateDoc(doc(db, "users", "carol"), { ppdLabel: { ...initial, verifiedBy: "me" } }));
  const dave = env.authenticatedContext("dave").firestore();
  await assertFails(setDoc(doc(dave, "users", "dave"), { ppdLabel: { ...initial, extra: 1 } }));
  await assertFails(setDoc(doc(dave, "users", "dave"), { ppdLabel: { ...initial, status: "ppd" } }));
  await env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), "users", ALICE), { ppdLabel: { status: "ppd" } }, { merge: true }));
  await assertFails(setDoc(doc(alice(), "users", ALICE), { ppdLabel: initial }, { merge: true }));
});

test("user can still update consent and other fields", async () => {
  await assertSucceeds(updateDoc(doc(alice(), "users", ALICE), { "consent.contributeToModel": false }));
  await assertSucceeds(setDoc(doc(alice(), "users", ALICE), { doctorIds: ["doc1"] }, { merge: true }));
});

test("flPseudoId is write-once", async () => {
  await assertFails(updateDoc(doc(alice(), "users", ALICE), { flPseudoId: BOB_PID }));
  const db = env.authenticatedContext("carol").firestore();
  await assertSucceeds(setDoc(doc(db, "users", "carol"), { consent: { contributeToModel: true }, flPseudoId: "pid-carol" }));
});

test("cannot claim a pseudoId that already has contributions", async () => {
  const carol = env.authenticatedContext("carol").firestore();
  await assertFails(setDoc(doc(carol, "users", "carol"), { flPseudoId: BOB_PID }));
  await assertSucceeds(deleteDoc(doc(alice(), "users", ALICE)));
  await assertFails(setDoc(doc(alice(), "users", ALICE), { flPseudoId: BOB_PID }));
  await assertSucceeds(setDoc(doc(alice(), "users", ALICE), { flPseudoId: "pid-alice-2" }));
});

test("user can delete own user doc", async () => {
  await assertSucceeds(deleteDoc(doc(alice(), "users", ALICE)));
});

test("user can write own contributions and snapshots", async () => {
  await assertSucceeds(setDoc(doc(alice(), "fl_contributions", ALICE_PID), { featureSchemaVersion: 1 }, { merge: true }));
  await assertSucceeds(setDoc(doc(alice(), "fl_contributions", ALICE_PID, "snapshots", "2026-10-11"), snapshot()));
  await assertSucceeds(getDoc(doc(alice(), "fl_contributions", ALICE_PID, "snapshots", "2026-10-11")));
  await assertSucceeds(deleteDoc(doc(alice(), "fl_contributions", ALICE_PID, "snapshots", "2026-10-11")));
});

test("snapshots and contribution docs must have the expected shape", async () => {
  const path = ["fl_contributions", ALICE_PID, "snapshots", "2026-10-11"];
  const { features, ...noFeatures } = snapshot();
  await assertFails(setDoc(doc(alice(), ...path), noFeatures));
  await assertFails(setDoc(doc(alice(), ...path), snapshot({ features: { f0: 1.0 } })));
  await assertFails(setDoc(doc(alice(), ...path), snapshot({ uid: ALICE })));
  await assertFails(setDoc(doc(alice(), ...path), snapshot({ windowEnd: Timestamp.fromMillis(Date.now() + DAY_MS) })));
  await assertFails(setDoc(doc(alice(), ...path), snapshot({ daysWithData: "20" })));
  await assertFails(setDoc(doc(alice(), ...path), snapshot({ featureSchemaVersion: 2 })));
  await assertFails(setDoc(doc(alice(), "fl_contributions", ALICE_PID), { featureSchemaVersion: 1, email: "a@b.c" }));
  await assertSucceeds(setDoc(doc(alice(), ...path), snapshot()));
});

test("user cannot touch another user's contributions", async () => {
  await assertFails(setDoc(doc(alice(), "fl_contributions", BOB_PID), { x: 1 }));
  await assertFails(getDoc(doc(alice(), "fl_contributions", BOB_PID)));
  await assertFails(setDoc(doc(alice(), "fl_contributions", BOB_PID, "snapshots", "2026-10-11"), snapshot()));
  await assertFails(setDoc(doc(anon(), "fl_contributions", ALICE_PID), { x: 1 }));
});

test("opted-out user can read and delete but not write contributions", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "fl_contributions", ALICE_PID, "snapshots", "2026-10-10"), snapshot());
    await updateDoc(doc(db, "users", ALICE), { "consent.contributeToModel": false });
  });
  await assertFails(setDoc(doc(alice(), "fl_contributions", ALICE_PID), { featureSchemaVersion: 1 }, { merge: true }));
  await assertFails(setDoc(doc(alice(), "fl_contributions", ALICE_PID, "snapshots", "2026-10-11"), snapshot()));
  await assertSucceeds(getDoc(doc(alice(), "fl_contributions", ALICE_PID, "snapshots", "2026-10-10")));
  await assertSucceeds(deleteDoc(doc(alice(), "fl_contributions", ALICE_PID, "snapshots", "2026-10-10")));
  await assertSucceeds(deleteDoc(doc(alice(), "fl_contributions", ALICE_PID)));
});

test("user without pseudoId cannot write contributions", async () => {
  const db = env.authenticatedContext("dave").firestore();
  await assertFails(setDoc(doc(db, "fl_contributions", "pid-dave"), { x: 1 }));
});

test("clients cannot read or write training data", async () => {
  await assertFails(getDoc(doc(alice(), "training_samples", ALICE_PID)));
  await assertFails(setDoc(doc(alice(), "training_samples", ALICE_PID), { label: 0.0 }));
  await assertFails(getDoc(doc(alice(), "training_runs", "r1")));
});

test("signed-in user can read ml_models/current, nobody can write it", async () => {
  await assertSucceeds(getDoc(doc(alice(), "ml_models", "current")));
  await assertFails(getDoc(doc(anon(), "ml_models", "current")));
  await assertFails(setDoc(doc(alice(), "ml_models", "current"), { version: 99 }));
});

test("doctors rules unchanged: patient reads and approves", async () => {
  await assertSucceeds(getDoc(doc(alice(), "doctors", "doc1")));
  const bob = env.authenticatedContext(BOB).firestore();
  await assertSucceeds(updateDoc(doc(bob, "doctors", "doc1"), { pendingPatientIds: [], patientIds: [ALICE, BOB] }));
});

test("storage: models readable when signed in, base data private", async () => {
  const s = env.authenticatedContext(ALICE).storage();
  await assertSucceeds(getBytes(ref(s, "ml/models/v1/metrics.json")));
  await assertFails(uploadString(ref(s, "ml/models/v9/x.mlmodel"), "x"));
  await assertFails(getBytes(ref(s, "ml/base/user_level.parquet")));
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), "ml/models/v1/metrics.json")));
});

test("user can read and write own subcollections", async () => {
  await assertSucceeds(setDoc(doc(alice(), "users", ALICE, "measurements", "2026-10-11"), { steps: 100 }));
  await assertSucceeds(setDoc(doc(alice(), "users", ALICE, "mood_logs", "a", "nested", "b"), { x: 1 }));
  await assertSucceeds(getDoc(doc(alice(), "users", ALICE, "measurements", "2026-10-11")));
  await assertFails(getDoc(doc(alice(), "users", BOB, "measurements", "2026-10-11")));
});
