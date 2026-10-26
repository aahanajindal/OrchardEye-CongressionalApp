# OrchardEye — Feature List & Output Variables

> **Status:** design draft (v0.1)
> Features are grouped into **(A) the four core "variables"** you outlined, **(B) supporting app features**, and **(C) stretch features**. Each core variable lists *what it is, what it outputs, what it needs, and how we measure it.* "Variable" here = a signal the system computes and can chart over time.

Legend: 🟢 v1 (must-have) · 🟡 v1 if time · 🔵 stretch

---

## A. The four core variables

### A1 · Disease detection 🟢
**What:** classify visible disease on a leaf/fruit image, or return "healthy / no disease."

| Field | Value |
|---|---|
| **Inputs** | Camera image (post quality-gate + preprocessing) |
| **Model** | MobileNetV2 / EfficientNet-Lite, INT8 TFLite, on-device |
| **Output variables** | `disease_class` (e.g., *apple scab*), `confidence` (0–1), `top_2_alternatives[]`, `is_healthy` (bool) |
| **Behavior** | If `confidence < threshold`, surface top-2 instead of one answer; never silently over-claim |
| **Plain-language layer** | Per-class explanation + a "what to do next" tip |
| **Crop** | **Apple** only — pretrained on PlantVillage apple, fine-tuned on field apple imagery |
| **Success metric** | ≥ 90% on public test split; ≥ 75% on our own field photos (honest domain-gap reporting) |

### A2 · Crop health score 🟢 (lifecycle · color · size)
**What:** a single 0–100 health score derived from sub-signals the camera *can* measure, so a grower gets a quick "how is this plant doing" read even when there's no named disease.

| Sub-variable | Signal | How |
|---|---|---|
| **Color / chlorosis** | yellowing, browning, necrosis | color-space analysis (HSV/Lab), % off-healthy-green |
| **Lesion area** | spot/blight coverage | segmentation → % of leaf/fruit affected |
| **Size** | fruit/leaf size estimate | relative size in frame vs. reference (or known sensor distance) |
| **Lifecycle / maturity stage** | bud → leaf → fruit set → ripening | stage classifier (coarse) + ties to ripeness (A3 below) |

| Field | Value |
|---|---|
| **Output variables** | `health_score` (0–100), `chlorosis_pct`, `lesion_pct`, `size_estimate`, `lifecycle_stage` |
| **Use** | Charts over time; an early-warning signal *before* a disease is nameable |
| **Success metric** | Score correlates with human/agronomist rating on a small validation set |

### A3 · Graph / trend detection for suspicious plants 🟢 (infectious? treatable?)
**What:** track each plant/block over repeated scans and detect *trajectories*, not just snapshots — the system's way of answering **"is this spreading (infectious) or static (cosmetic/treatable)?"**

| Field | Value |
|---|---|
| **Inputs** | Scan history for a plant/block (disease, health score, lesion %, Brix), + weather context |
| **Output variables** | `health_trend` (improving/stable/worsening), `spread_index`, `risk_label` {infectious · treatable · cosmetic}, `urgency` (low/med/high) |
| **Logic** | Worsening lesion % across scans + favorable weather (warm/humid) ⇒ infectious/urgent; static minor spotting ⇒ cosmetic/treatable |
| **Charts** | Health-over-time line, Brix-curve-to-harvest, spread index, "flagged plants" list |
| **Feeds** | The fusion stage's risk reasoning (see [ai-pipeline.md](ai-pipeline.md) §2.5) |
| **Success metric** | Correctly flags a worsening plant earlier than a single-snapshot scan would |

### A4 · Voice guidance 🟢 (on-device · weather-adaptive)
**What:** speak the verdict and the recommended action, adapted to current/forecast weather — designed for hands-busy, eyes-on-the-tree, low-literacy-friendly field use.

| Field | Value |
|---|---|
| **Inputs** | Fused verdict + recommendation + weather (fetched via weather API; cached offline) |
| **Engine** | On-device TTS (and on-device ML for any phrasing/intent), so it works with no signal |
| **Output** | Spoken verdict + action; weather-aware timing ("rain tonight — spray this afternoon") |
| **Languages** | English v1; Spanish high-priority next (large share of orchard workforce) |
| **Why** | Accessibility + the "matured" community vision (see [community doc](../vision/community-knowledge-and-voice.md)) |
| **Success metric** | Field testers can complete + understand a scan **without reading the screen** |

> **Weather source:** a free weather API (OpenWeatherMap / Open-Meteo). Variables consumed: `temp`, `humidity`, `precip_recent`, `precip_forecast`, `leaf_wetness_proxy`. Always cache the last value so voice guidance still works offline.

---

## B. Supporting app features (from PRD §6)

| ID | Feature | Tier | Notes |
|---|---|---|---|
| **F1** | Camera disease scan | 🟢 | Capture/import → label + confidence → tip |
| **F2** | NIR quality scan | 🟢 | BLE pair → 18-ch read → ripeness + Brix; average 3 reads |
| **F3** | Fused verdict screen | 🟢 | One color-coded card + recommendation |
| **F4** | History & CSV export | 🟢 | Local store; GPS optional; map = stretch |
| **F5** | Onboarding & calibration | 🟢 | Pairing wizard, variety selector, white-reference step |
| **F6** | Trends & charts dashboard | 🟡 | Per-plant/block time series (powers A3) |
| **F7** | Community contribution UI | 🟡 | Confirm/correct verdict, add notes/questions |

---

## C. Stretch features 🔵

- **Feature-level sensor fusion** — one model over image embeddings + spectral features (vs. decision-level).
- **Geo-tagged scan map** — track blocks/orchards across a season.
- **Cherry & pear calibration** — extend beyond apple.
- **Pre-symptomatic stress detection** — NIR signal *before* visible disease.
- **Cloud dashboard** — season-long grower trends, optional sync.
- **Federated community model** — local corpus improves a community-owned model (see vision doc).

---

## D. Master variable dictionary (for the data model & CSV export)

| Variable | Type | Source stage | Unit / range |
|---|---|---|---|
| `disease_class` | enum | A1 | class label |
| `confidence` | float | A1 | 0–1 |
| `is_healthy` | bool | A1 | — |
| `health_score` | int | A2 | 0–100 |
| `chlorosis_pct` | float | A2 | 0–100% |
| `lesion_pct` | float | A2 | 0–100% |
| `size_estimate` | float | A2 | relative / mm |
| `lifecycle_stage` | enum | A2 | bud…ripening |
| `ripeness_class` | enum | A3 input | unripe/ripe/overripe |
| `brix_estimate` | float | A3 input | °Brix |
| `health_trend` | enum | A3 | improving/stable/worsening |
| `spread_index` | float | A3 | 0–1 |
| `risk_label` | enum | A3 | infectious/treatable/cosmetic |
| `urgency` | enum | A3 / fusion | low/med/high |
| `verdict` | enum | fusion | 🔴/🟠/🟢 |
| `recommendation` | text | fusion | plain language |
| `weather_temp` / `_humidity` / `_precip` | float | metadata | API values |
| `gps_lat` / `gps_lon` | float | metadata | optional |
| `variety` | enum | onboarding | cultivar |
| `timestamp` | datetime | capture | — |

This dictionary is the contract between the pipeline, the trends/charts, the CSV export, and the community corpus.
