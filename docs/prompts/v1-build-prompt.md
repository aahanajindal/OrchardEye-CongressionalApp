# OrchardEye — Comprehensive v1 Build Prompt (for Claude / ChatGPT)

> **Purpose:** a ready-to-paste prompt to drive Claude or ChatGPT (or Claude Code) while building OrchardEye v1.
> **How to use:** paste **§1 Master Prompt** first to establish context, then run the **§3 phase prompts** one at a time (they map to the PRD milestones). Keep claims honest — the constraints block is load-bearing.
> Tip: with a coding agent, run the master prompt once, then feed phases sequentially; with chat, paste the master prompt + one phase per message.

---

## 1. Master prompt (paste first)

```text
You are a senior mobile + ML engineer helping me build "OrchardEye" v1, a Congressional
App Challenge project for Washington's 8th District (tree-fruit country).

PRODUCT
OrchardEye is a smartphone app + a low-cost clip-on near-infrared (NIR) spectral sensor.
From ONE scan of a fruit or leaf it answers two questions:
  1. "Is it diseased?"  — on-device computer vision classifies visible disease, or "healthy".
  2. "Is it good?"      — an 18-channel NIR sensor (AS7265x, 410–940 nm) estimates ripeness
                          stage and sugar (Brix), which the camera physically cannot see.
It then FUSES both into one plain-language verdict and updates per-plant trend charts.
The disease model is APPLE only: pretrain on PlantVillage apple, then fine-tune on field
apple imagery. Target user: small apple growers in central WA.

HARDWARE (BOM < $130)
- SparkFun AS7265x "Triad" spectral sensor (18 channels, 410–940 nm)
- ESP32 dev board (reads sensor over I2C, streams to phone over BLE)
- Handheld Brix refractometer (ground-truth for training the Brix model)
- 3D-printed dark shroud (fix scan distance, block ambient light)

TECH STACK
- App: Flutter or React Native (single cross-platform codebase). Recommend and justify one.
- On-device inference: TensorFlow Lite, INT8-quantized models.
- Disease model: MobileNetV2 / EfficientNet-Lite fine-tuned on PlantVillage → TFLite.
- Quality models: ripeness classifier (SVM/MLP) + Brix regressor (PLS/shallow ANN) on the
  18-channel spectrum, trained on a custom-collected, variety-specific calibration set.
- Sensor link: BLE (ESP32 ↔ phone). Firmware reads AS7265x over I2C.
- Weather: free API (OpenWeatherMap / Open-Meteo), cached for offline use.

HARD CONSTRAINTS (do not violate)
- OFFLINE-FIRST: a scan must complete and produce a verdict with NO signal. Cloud is
  optional enhancement only.
- ON-DEVICE: all inference runs on the phone; target capture→verdict < 3 s.
- HONEST CLAIMS: the AS7265x tops out near 940 nm. Do NOT claim deep sugar/water bands
  (1450 nm, 2100 nm) — those need expensive InGaAs sensors and are out of scope. Keep all
  spectral claims within 410–940 nm (ripeness, chlorophyll, surface chemistry).
- NO medical / regulatory / food-safety certification claims.
- ACCESSIBILITY: voice guidance + color-coded cards + large tap targets; works one-handed
  outdoors.

PIPELINE (build toward this; details in docs/design/ai-pipeline.md)
capture → image/signal quality gate → preprocessing → quantized on-device models
(disease CV + crop-health + ripeness + Brix) → fusion & risk reasoning → verdict + voice
+ trend update → community confirm/correct loop.

HOW I WANT YOU TO WORK
- Ask clarifying questions before writing large code if requirements are ambiguous.
- Propose a clean project structure first; get my OK; then implement in small steps.
- Prefer simple, debuggable, well-commented code. Decision-level fusion before any fancy
  feature-level fusion.
- For every feature, give acceptance criteria and how to test it.
- Flag anything that risks the honesty constraints above.
Acknowledge this context and propose the v1 project structure + your Flutter-vs-RN
recommendation. Then wait for me to pick a phase.
```

---

## 2. Feature spec to include (features → subfeatures → acceptance criteria)

Paste this when you want the model to implement against a precise spec. (Tiers: 🟢 must · 🟡 if-time · 🔵 stretch.)

```text
FEATURE SPEC — OrchardEye v1

F1 · Camera disease scan 🟢
  F1.1 Capture or import a photo of a leaf/fruit.
  F1.2 Run an INT8 TFLite CV model → label + confidence ("Apple scab — 92%") or
       "Healthy — no disease detected."
  F1.3 If confidence < threshold, show top-2 alternatives.
  F1.4 Plain-language explanation + a "what to do next" tip per class.
  ACCEPT: returns a result in < 3 s offline; handles a non-leaf image gracefully
          (routes to quality gate, not a wrong label).

F2 · NIR quality scan 🟢
  F2.1 Pair with the spectral sensor over BLE (pairing wizard).
  F2.2 Trigger an 18-channel reflectance read (410–940 nm) using the sensor's LEDs.
  F2.3 Run spectral models → ripeness class + estimated Brix.
  F2.4 Average 3 reads; show a stability/confidence indicator.
  ACCEPT: a white/dark reference calibration step exists; reads are reproducible
          within a stated tolerance; claims stay within 410–940 nm.

F3 · Fused verdict 🟢
  F3.1 Combine F1 + F2 into ONE screen.
  F3.2 Verdict spectrum: Diseased → Healthy-but-not-ready → Healthy-&-premium.
  F3.3 Actionable recommendation ("Healthy, ~11 Brix, ripe — pick now").
  ACCEPT: color-coded card (🔴/🟠/🟢); low-confidence path asks for a rescan.

F4 · History & export 🟢
  F4.1 Save each scan (timestamp, optional GPS, image, spectrum, results) locally.
  F4.2 Export CSV for the grower's own records (use the variable dictionary).
  F4.3 (🔵) Map scans by block/location.

F5 · Onboarding & calibration 🟢
  F5.1 First-run BLE pairing wizard.
  F5.2 Variety selector (calibration is variety-specific).
  F5.3 Optional white-reference calibration before a session.

CORE VARIABLES (compute + chart these; see docs/design/feature-list.md)
  A1 disease_class, confidence, is_healthy
  A2 health_score (0–100) from chlorosis_pct, lesion_pct, size_estimate, lifecycle_stage
  A3 health_trend, spread_index, risk_label{infectious|treatable|cosmetic}, urgency
  A4 voice guidance (on-device TTS), weather-adaptive (temp/humidity/precip from weather API)

F6 · Trends & charts 🟡  — per-plant/block time series; flag worsening plants (powers A3).
F7 · Community contribution 🟡 — one-tap confirm/correct verdict; add note/voice/question.

QUALITY GATE (build early; biggest real-world accuracy lever)
  Blur (Laplacian variance), exposure/glare, subject-presence/framing, spectral validity.
  On fail → guide retake with a SPECIFIC voice + on-screen tip. Never silently guess.
```

---

## 3. Phase prompts (run in order — mirror PRD §11 milestones)

**Phase 0 — Scaffold**
```text
Set up the OrchardEye repo: chosen framework app skeleton, folder structure, a stub
TFLite inference service, a BLE service interface (mockable), a local data store for scans,
and the variable dictionary as typed models. Add a fake "sensor" provider so the app runs
end-to-end before hardware exists. Give me run instructions.
```

**Phase 1 — Disease MVP (apple)**
```text
Implement F1 with an apple model: a notebook/script to fine-tune MobileNetV2 on the
PlantVillage apple classes and export an INT8 TFLite model, plus the in-app inference +
result card (F1.1–F1.4) and the image quality gate. Report train/val accuracy and model
size. Include the < 3 s latency check.
```

**Phase 2 — Apple transfer**
```text
Transfer the disease model to apple classes (scab, black rot, cedar apple rust, healthy).
Add a small script to fine-tune on ~100–300 of MY OWN field photos and report BOTH the
public-test accuracy and the real-field accuracy honestly. Keep the "healthy" path solid.
```

**Phase 3 — Sensor bridge**
```text
Write ESP32 firmware that reads the AS7265x over I2C (18 channels, with white/dark
reference) and streams readings over BLE in a documented packet format. Implement the app
side of F2.1–F2.2 to pair, trigger a read, and display the raw spectrum. Provide a static
test dataset so the app can be tested without hardware.
```

**Phase 4 — NIR data + quality models**
```text
Give me (a) a data-collection protocol + logging screen to record {18 channels, Brix,
ripeness label, variety, date} for 50+ fruit per variety, and (b) training scripts for a
ripeness classifier + Brix regressor with leave-one-out / held-out validation. Implement
F2.3–F2.4 in-app. Report ripeness accuracy and Brix R²/RMSE. Keep claims within 410–940 nm.
```

**Phase 5 — Fusion + UX + trends + voice**
```text
Implement F3 decision-level fusion → one verdict screen (F3.1–F3.3), the A2 crop-health
score, A3 trend/risk logic + charts (F6), and A4 on-device voice guidance that adapts to
weather pulled from a free API (cached offline). Add F7 confirm/correct. Polish for
outdoor one-handed use.
```

**Phase 6 — Field test + write-up**
```text
Produce a field-test checklist for 5+ outside testers, a results-logging template, a demo
script (one scan → two answers in < 3 s), a README, and submission text that ties impact to
WA-08's tree-fruit economy. List every claim and the evidence behind it; flag anything
unverified.
```

---

## 4. Guardrail reminder (append to any phase if the model drifts)

```text
Re-check against the HARD CONSTRAINTS: offline-first, on-device < 3 s, spectral claims only
within 410–940 nm (no 1450/2100 nm), no medical/food-safety certification claims,
accessibility (voice + color + large targets). If anything you wrote violates these or
overstates accuracy, fix it and tell me what you changed.
```

---

### Notes
- This prompt is the *driver*; the **specs of record** are [`docs/design/feature-list.md`](../design/feature-list.md) and [`docs/design/ai-pipeline.md`](../design/ai-pipeline.md). Keep them in sync.
- Datasets to point the model at are catalogued in [`docs/research/datasets.md`](../research/datasets.md).
