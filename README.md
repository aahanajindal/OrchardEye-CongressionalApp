# 🍎 OrchardEye

**A dual-sensor apple health & quality scanner for Washington's 8th Congressional District.**

One scan of a fruit or leaf → two answers:
1. **Is it diseased?** — on-device computer vision classifies visible disease (or "healthy").
2. **Is it good?** — a low-cost clip-on near-infrared (NIR) sensor estimates ripeness and sugar (Brix) — internal quality the camera can't see.

…then **fuses** both into one plain-language verdict, speaks it aloud (weather-aware voice guidance), and tracks each plant's trend over the season — all on **sub-$130 hardware** that works **offline in the field**.

> Built for the **Congressional App Challenge — WA-08** (tree-fruit country: Wenatchee, Chelan, Leavenworth). One crop, done properly: **apple**, the district's and the state's defining tree fruit.
>
> **Pitch:** *"OrchardEye puts a $3,000 lab capability into a $100 phone attachment so the small apple growers who power my district can pick at peak quality and catch disease early — turning waste into income."*

> ⚠️ **Status:** v0.1. The planning artifacts (PRD, research, designs, build prompt) are in [`docs/`](docs/), and a **buildable native-iOS app** is in [`OrchardEye/`](OrchardEye/) — full UX with the disease model and BLE sensor stubbed behind protocols (see [the app README](OrchardEye/README.md)).

---

## 📱 The app

A complete **native iOS (SwiftUI)** v1 lives in **[`OrchardEye/`](OrchardEye/)** — it builds in
**Xcode 16+** and runs the full scan → quality gate → disease + crop-health → NIR ripeness/Brix →
**fused verdict** → voice + trends + confirm/correct flow, all on-device.

```bash
open OrchardEye/OrchardEye.xcodeproj   # ⌘R on an iPhone simulator
```
It's Simulator-friendly: tap a **sample leaf** and **Scan fruit** (the camera/NIR are simulated)
to walk the whole pipeline. The disease model and BLE sensor are clean **stubs** behind protocols
(`DiseaseClassifier`, `SpectralSensor`) ready for a real Core ML model and an AS7265x. See
**[`OrchardEye/README.md`](OrchardEye/README.md)** for build notes and the real-vs-stubbed map.

## 🌐 Landing page

A self-contained marketing site lives in **[`web/`](web/)**. Plain HTML/CSS/JS, with a
tiny root build script for Vercel that copies `web/` to `dist/`. Same brand palette
as the app (orchard green + ripe amber).

```bash
cd web && python3 -m http.server 8000   # → http://localhost:8000
```
Build/deploy notes for Vercel and GitHub Pages: **[web/README.md](web/README.md)**.

## 📚 Documentation index

| Doc | What's inside |
|---|---|
| **[🌐 Landing page](web/README.md)** | Self-contained marketing site (hero → problem → how-it-works → sensors → pilot). Deploys to Vercel or GitHub Pages. |
| **[📱 iOS app](OrchardEye/README.md)** | The buildable SwiftUI v1 (Xcode 16+): full scan→verdict→trends flow, on-device. |
| **[PRD](docs/PRD.md)** | Full product requirements: goals, users, features, architecture, BOM, ML plan, milestones, risks, CAC alignment. |
| **[AI Pipeline](docs/design/ai-pipeline.md)** | The end-to-end flow: quality gate → preprocess → quantized on-device models → fusion → report/trends → community loop (with a Mermaid flowchart + feedback loops). |
| **[Feature List & Variables](docs/design/feature-list.md)** | The four core variables (disease, crop-health score, trend/risk detection, voice guidance) + supporting features + the variable dictionary. |
| **[Community & Voice Vision](docs/vision/community-knowledge-and-voice.md)** | The "matured" layer: weather-adaptive voice guidance, farmer-wisdom corpus, and community-owned localized AI. |
| **[v1 Build Prompt](docs/prompts/v1-build-prompt.md)** | A comprehensive, copy-paste prompt (master + phase prompts) to drive Claude/ChatGPT while building v1. |
| **[Research · Disease Loss](docs/research/disease-loss-statistics.md)** | Apple-loss-to-disease statistics across US, WA, and WA-08. |
| **[Research · Competitors](docs/research/market-competitor-analysis.md)** | What already exists: disease-ID apps, NIR/Brix tools, food-spoilage apps, retail grading — and where OrchardEye fits. |
| **[Research · Datasets](docs/research/datasets.md)** | Public apple datasets for training (PlantVillage apple, PlantDoc, Plant Pathology 2020/2021) + the spectral gap. |

---

## 🧠 How it works (30-second version)

```
   📷 camera ─┐                                    ┌─→ 🦠 disease + crop-health score
              ├─→ quality gate → preprocess → quantized on-device models → 🧠 fusion ─→ 🟢/🟠/🔴 verdict + 🔊 voice
   🔬 NIR ────┘     (offline, < 3 s)                └─→ 🍎 ripeness + Brix          + 📈 trend chart
```

Full detail with feedback loops: **[docs/design/ai-pipeline.md](docs/design/ai-pipeline.md)**.

## 🔩 Hardware (~$118 BOM)

AS7265x spectral sensor (18 ch, 410–940 nm) + ESP32 (BLE bridge) + Brix refractometer (ground-truth) + 3D-printed dark shroud. Full list in [PRD §8](docs/PRD.md#8-hardware--bill-of-materials).

> **Honest-claims rule:** the AS7265x tops out near 940 nm — great for ripeness, chlorophyll, surface chemistry. We do **not** claim deep sugar/water bands (1450 nm), which need far pricier sensors. Rigor is the point.

## ✅ v1 success targets

| | Target |
|---|---|
| Disease accuracy (public test) | ≥ 90% |
| Disease accuracy (own field photos) | ≥ 75% *(honest domain gap)* |
| Ripeness classification | ≥ 85% |
| Brix regression | R² ≥ 0.80, RMSE ≈ 1 °Brix |
| Capture → verdict | < 3 s, on-device |
| Hardware BOM | < $130 |

---

## 🗺️ Roadmap

Apple disease MVP → sensor/BLE bridge → NIR calibration set + quality models → fusion + voice + trends → field test → demo & submission. See the [milestone table](docs/PRD.md#11-milestones--timeline).

*Working name "OrchardEye" is a placeholder. Verify the current CAC deadlines, district boundaries, and representative before submission.*
