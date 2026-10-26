# OrchardEye — iOS app (SwiftUI)

OrchardEye: an **on-device** apple **disease + ripeness** scanner. One photo, two answers —
*is it diseased, and is it ready?* — with the full pipeline running on the iPhone:

```
capture → quality gate → disease + crop-health → ripeness (colour) → fused verdict
        → voice guidance + per-plant trends + confirm/correct
```

No external sensor, no clip-on hardware, no upload. The camera is the only sensor.

## Requirements
- **Xcode 16 or newer** (file-system–synchronized groups, `objectVersion 77`).
- iOS **17+** Simulator or device.
- No packages, pods, or other tooling — builds with only Apple frameworks
  (SwiftUI, Swift Charts, AVFoundation, PhotosUI, Vision, CoreML, UIKit).

## Build & run
```bash
open OrchardEye/OrchardEye.xcodeproj
```
1. Select the **OrchardEye** scheme and an iPhone Simulator (e.g. iPhone 17).
2. Press **⌘R**.
3. On a device, set your Team under *Signing & Capabilities* first (Simulator needs no signing).

### Try the full flow in the Simulator (no hardware needed)
The Simulator has no camera, so:
- On the **Scan** tab tap **“Sample: healthy”** / **“Sample: diseased”** (a leaf image is
  generated and really analyzed), **or** **“Choose photo”** to pick from the library.
- You get a one-shot result — **disease + crop-health + ripeness** — then tap **See verdict**
  for the fused call, which you can **hear** (on-device TTS), **save**, and **confirm/correct**.
- Scan the same **plant/block label** more than once to populate the **Trends** charts.

> To load real test photos into the Simulator library:
> `xcrun simctl addmedia booted path/to/apple*.jpg`

## What's real vs. stubbed
| Part | Status |
|---|---|
| Full UI/UX, onboarding, history, CSV export | ✅ real |
| Image **quality gate** (blur/exposure/subject) | ✅ real, on-device |
| **Crop-health** signals (greenness/lesion/chlorosis) | ✅ real image analysis |
| **Apple / plant detection** (subject gate) | ✅ real on-device Core ML — Vision `VNClassifyImageRequest` |
| **Disease classification** (apple) | ✅ real, on-device — see two-model note below |
| **Ripeness** (ripe / not-ready / overripe + 0–100 score) | ✅ real, estimated from fruit colour (`RipenessEstimator`) |
| **Fusion, trends, risk/urgency** | ✅ real logic |
| **Voice guidance** (weather-adaptive) | ✅ real `AVSpeechSynthesizer` |
| **Weather** | ✅ real Open-Meteo fetch (next-12h precip), offline fallback + cache |

> Honesty note: ripeness is a **colour proxy** for readiness, not a lab °Brix measurement.
> The trained model covers **apple scab / black rot / cedar apple rust / healthy**. The other apple
> diseases it can name — fire blight, powdery mildew, bitter rot, sooty blotch — come from a
> transparent colour heuristic and are always reported as *suspected*, never confidently flagged.

### Two disease models (and why)
The disease head runs entirely on-device, but which model is used depends on the runtime:
- **Real device:** `CoreMLDiseaseClassifier` — a CreateML scenePrint (rev 2) transfer-learned
  classifier (`AppleDiseaseClassifier.mlmodel`), trained on the full PlantVillage apple set
  (3,171 imgs: scab / black rot / cedar apple rust / healthy). **98.5% on a held-out test split
  of 454 imgs** (99.3% val); per-class recall 0.96 / 0.99 / 1.00 / 0.99.
- **Simulator:** `ColorDiseaseClassifier` — a self-contained logistic-regression head over 12
  colour/texture features (~88% held-out). The iOS **Simulator degrades Vision's scenePrint
  feature extractor**, so the CNN misclassifies there; the colour model is OS-independent and
  behaves identically in sim and on device. Selected via `#if targetEnvironment(simulator)`.

The colour model's weights are trained offline (`scratchpad/train_color.py`, numpy) and its Swift
feature extractor is kept byte-aligned with that script.

## Project layout
```
OrchardEye/
├─ OrchardEye.xcodeproj/            # hand-authored, Xcode-16 synchronized-group project
└─ OrchardEye/
   ├─ OrchardEyeApp.swift           # @main
   ├─ AppleDiseaseClassifier.mlmodel# CreateML apple-disease CNN (used on device)
   ├─ Models/CoreModels.swift       # Crop, Variety, DiseaseInfo, CropHealth, RipenessReading, Verdict, ScanRecord …
   ├─ Services/                     # ImageAnalysis, QualityGate, AppleDetector,
   │                                #   DiseaseClassifier (heuristic), CoreMLDiseaseClassifier, ColorDiseaseClassifier,
   │                                #   RipenessEstimator, FusionEngine, TrendAnalyzer, WeatherProvider,
   │                                #   VoiceGuide, UIImage+Orientation, AppModel/ScanStore
   ├─ Views/                        # RootView, Onboarding, ScanFlow, Verdict, History, Trends, Settings, Components, Theme
   └─ Assets.xcassets/              # AppIcon (1024²), colours
```

## Where to plug in / retrain
- **Disease CNN (device):** drop a new `AppleDiseaseClassifier.mlmodel` (or `.mlmodelc`) into
  `OrchardEye/OrchardEye/`; the synchronized-group project compiles and bundles it automatically.
  `CoreMLDiseaseClassifier` loads it and maps labels (scab / black rot / cedar apple rust / healthy).
- **Disease colour model (sim + device):** edit the feature thresholds identically in
  `ColorDiseaseClassifier.swift` and `scratchpad/train_color.py`, rerun the script, paste the
  emitted `mean` / `std` / `weight` / `bias` constants back into the Swift file.
- **More apple diseases:** add them to `DiseaseInfo.candidates(for:)`. Anything the trained model has
  no class for is served by the colour heuristic, which is capped below the flag threshold.

## Notes
- **Validate disease accuracy on a real device**, not the Simulator — the Simulator's degraded
  Vision path is why a colour model is used there in the first place.
- Everything is local: photos are analyzed on-device and never uploaded. Only weather is fetched
  (Open-Meteo, key-less), with an offline fallback so a scan never depends on the network.
