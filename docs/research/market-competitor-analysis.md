# OrchardEye — Market & Competitor Research

*Compiled 2026-06-19. Scope: existing apps/products across four categories — (1) crop disease-ID apps, (2) NIR/Brix fruit-quality tools, (3) food-spoilage/freshness detectors, (4) retail/B2B produce grading — plus a gap analysis of where OrchardEye fits. Prices marked "quote/unknown" where no public figure was confirmable; claims are attributed inline and listed in **Sources**.*

> **Headline finding:** the market splits cleanly into **two camps that don't overlap** — (a) **disease-ID apps** (mostly free, cloud, phone-camera, generic, *no quality/ripeness*) and (b) **fruit-quality/NIR tools** (accurate but **$5,000+ handhelds** or **six-figure packing-line sorters**, *no disease ID*, B2B). **No consumer/grower-priced tool does BOTH disease + internal quality from one scan.** That intersection — plus *offline on-device* operation and a *hyper-local, community-owned* model — is OrchardEye's white space.

---

## 1. Crop disease-detection apps (phone camera + AI)

| Product | Maker | What it does | Platform | On-device? | Price | Notes / gaps |
|---|---|---|---|---|---|---|
| **Plantix** | PEAT GmbH (Germany) | Photo diagnosis of disease/pest/deficiency across ~30 crops; community + dealer marketplace | Android (iOS limited) | Cloud (mostly) | Free (B2B/dealer revenue) | Market leader; claims ~98% on 30 crops. Generic, not WA-specific; **no quality/ripeness**; needs signal. |
| **PlantVillage Nuru** ⭐ | Penn State + FAO/IITA/CIMMYT | Object-detection diagnosis of crop disease/pest; expert advice in local languages | Android | **Yes — runs offline on-device** | Free (public good) | **Closest philosophical cousin:** offline, free, multilingual, community/extension-linked, ~2× more accurate than extension workers in field tests. But **disease-only, no NIR/quality**, and built for African staples (cassava, maize) — not WA tree fruit. |
| **Agrio** | Agrio (Saillog) | ID of 100+ diseases/pests + agronomy alerts, scouting | iOS / Android | Cloud | Freemium | Fast, actionable; generic; no internal-quality. |
| **Plant.id / Plantis** | Kindwise | Fast plant + disease ID via API | iOS / Android / API | Cloud | Freemium / API | Built for speed; "casual use," less pro depth; no quality. |
| **Leaf Doctor** | Univ. of Hawaii | Quantifies % leaf area diseased (severity) | iOS | On-device (image math) | Free | Severity *measurement*, not classification; useful as a model for our lesion-% sub-feature. |
| **PictureThis / PlantNet / Google Lens** | Glority / consortium / Google | Plant ID, some disease hints | iOS / Android | Cloud | Free/paid | Consumer/hobby; shallow disease depth; no quality. |
| **Taranis, Cropin, FarmRise** | various agtech | Aerial/field scouting, advisory at scale | App + cloud/drone | Cloud | Enterprise | B2B broad-acre; not handheld single-fruit; no consumer NIR. |

**Takeaway:** disease-ID is a **crowded, mature** space, and a generic leaf-disease classifier alone is *over-done* (a known risk in [PRD §12](../PRD.md#12-risks--mitigations)). The category is almost entirely **cloud-dependent, disease-only, and generic**. Only **Nuru** shares OrchardEye's offline/community/public-good DNA — and it has **no quality/NIR dimension**.

---

## 2. NIR / Brix fruit-quality tools (the "is it good?" side)

| Product | Maker | What it does | Form factor | On-device app? | Price | Notes / gaps |
|---|---|---|---|---|---|---|
| **F-750 Produce Quality Meter** | Felix Instruments (CID Bio-Science) | Handheld **NIR** (≈285–1200 nm) → Brix/TSS, dry matter, titratable acidity, color; build your own models | Handheld unit | Self-contained | **~$5,000+** (quote-based; ~€5,140 cited) | The research-grade benchmark. **No disease ID.** Far out of a small grower's budget — *this is the $3,000+ gap OrchardEye targets.* |
| **SCiO** | Consumer Physics (Israel) | Pocket molecular sensor, **740–1070 nm** → TSS/dry-matter via cloud models | Pocket + phone (BLE) | Cloud models | ~$250–300 (consumer ed.) | Closest to "cheap phone NIR," but **cloud-dependent**, consumer line de-emphasized/pivoted to enterprise; **no disease ID**; 740–1070 nm. |
| **trinamiX / Spectral Engines / clip-on NIR** | trinamiX (BASF), others | Mobile NIR modules for material/food sensing | OEM module + phone | Varies | OEM/enterprise | Reference designs, not a finished grower app; not retail-priced. |
| **Digital Brix refractometer** | Atago, Hanna, generic | Destructive sugar (°Brix) from juice | Handheld | No | ~$18 (analog) – $300+ (digital) | **Destructive** (must cut/juice fruit); ground-truth only — exactly what OrchardEye uses to *train* its non-destructive model. |

**Takeaway:** accurate internal-quality sensing today is either **research-grade and expensive (F-750, ~$5k+)**, **cloud-tethered (SCiO)**, or **destructive (refractometer)**. None pair quality with disease, and none are an *offline, affordable, grower-owned* package. OrchardEye's AS7265x (18 ch, 410–940 nm) deliberately sits in the **cheap-and-honest** band (see [PRD §8 sensor note](../PRD.md#8-hardware--bill-of-materials)).

---

## 3. Food-spoilage / freshness detector apps & devices

| Product / tech | Type | What it does | Maturity | Notes / gaps |
|---|---|---|---|---|
| **Gas-sensor + smartphone labels** (e.g., ammonia/TMA sensors; "sniff" tags) | Hardware sensor + app | Detect spoilage gases off meat/fish; phone reads a paper/label sensor | Research / early product | Targets **protein spoilage**, not produce disease; needs a consumable sensor/label. |
| **FOODsniffer** (historic), **Quantum-Nose**, IoT freshness fusion | Handheld e-nose / IoT | Volatile-compound "freshness" read | Mostly prototypes / niche | Consumer e-noses have struggled commercially; accuracy & calibration are hard; not crop-disease. |
| **Smart-label / time-temperature indicators** | Passive packaging | Color-change freshness/expiry cue | Deployed in some supply chains | Coarse (freshness proxy), not a diagnosis; B2B packaging. |
| **Fridge/expiry inventory apps** (NoWaste, Kitche) | Consumer app | Track expiry dates to cut waste | Mature, consumer | **No sensing at all** — manual logging; unrelated to disease/ripeness. |

**Takeaway:** the "spoilage detector" space is **gas-sensing hardware for animal protein** or **passive smart-labels**, plus manual fridge-inventory apps. It is **post-purchase, consumer/retail, hardware-dependent**, and **not about field disease or harvest-timing**. Little overlap with OrchardEye except the shared theme of *reducing waste through better information*.

---

## 4. Retail / B2B produce-grading systems

| Product | Maker | What it does | Scale | Price | Notes / gaps |
|---|---|---|---|---|---|
| **Intello Labs** (IntelloSort, IntelloTrack) | Intello Labs | AI/CV objective grading of fruit/veg/spices; sorting up to ~40× manual | Procurement, warehouse, packhouse | Enterprise (raised ~$5.9M) | B2B quality grading; **no disease etiology, no NIR Brix on a phone**; not for a 5-acre grower. |
| **Clarifruit** | Clarifruit | Cloud CV grades size/color in ~2 s; standardizes QC | Distributor/QC teams | SaaS (unknown) | Speeds inspection 50–60%; **external** quality; cloud; B2B. |
| **AgShift / Hydra** | AgShift | Autonomous bulk visual inspection | Distributor scale | Enterprise | Bulk inspection; not handheld single-fruit + disease. |
| **TOMRA Spectrim + Inspectra²** | TOMRA Food | Packing-line optical sorting (LUCAi deep learning) + **NIR internal Brix/dry-matter** | Industrial packhouse | Six-figure+ capEx | The "gold standard" that *does* combine external defects + **internal NIR** — but as a **packing-line machine**, not a $100 field tool. Proof the disease+quality fusion is valuable; OrchardEye democratizes it. |

**Takeaway:** the B2B world **already proves the value of combining visual defects + internal NIR quality** (TOMRA Inspectra²) and of CV grading (Intello, Clarifruit) — but only as **expensive, fixed, packhouse/distributor infrastructure**. Nothing here serves the **small grower in the field, pre-harvest, offline, for ~$100**.

---

## 5. Gap analysis & OrchardEye positioning

| Capability | Disease apps (Plantix/Nuru) | NIR tools (F-750/SCiO) | Spoilage apps | B2B grading (TOMRA/Intello) | **OrchardEye** |
|---|:--:|:--:|:--:|:--:|:--:|
| Visible **disease ID** | ✅ | ❌ | ❌ | partial (defects) | ✅ |
| **Internal quality** (ripeness/Brix) | ❌ | ✅ | partial | ✅ | ✅ |
| **One scan → both answers** | ❌ | ❌ | ❌ | ✅ (line only) | ✅ |
| **Offline / on-device** | only Nuru | partial | ❌ | n/a | ✅ |
| **Affordable for a small grower** (≈$100) | ✅ (free) | ❌ ($5k+) | varies | ❌ (6-figure) | ✅ (~$118 BOM) |
| **Hyper-local** (WA tree fruit) | ❌ generic | ❌ | ❌ | ❌ | ✅ |
| **Community-owned / voice / wisdom loop** | partial (Nuru) | ❌ | ❌ | ❌ | ✅ |

### Where OrchardEye wins (the white space)
1. **The intersection nobody serves at consumer price:** *disease detection **and** internal quality from a single scan.* TOMRA proves the fusion is valuable; OrchardEye delivers it for **~$118**, not six figures.
2. **Offline-first, on-device:** like Nuru (and unlike Plantix/SCiO/Clarifruit), a scan completes with **no signal** — essential in orchards.
3. **Hyper-local to WA-08 tree fruit:** apple-specific, tied to WSU Wenatchee and the district's fire-blight and bitter-rot realities — not a generic global classifier.
4. **Community-owned knowledge + voice guidance:** extends Nuru's public-good/multilingual ethos into a *farmer-wisdom corpus* and weather-adaptive voice (see [vision doc](../vision/community-knowledge-and-voice.md)). No quality tool does this.

### Honest competitive risks
- **Disease-ID is saturated** — the novelty is **not** "another classifier" but the **disease + NIR fusion**, the **WA framing**, and the **community layer**. Lead with those.
- **Plantix/Nuru are free and polished** — OrchardEye must justify its hardware add-on via the *quality* answer they can't give.
- **SCiO already tried "cheap phone NIR"** and pulled back from consumers — a caution that calibration + UX, not just the sensor, decide success. OrchardEye's variety-specific calibration discipline ([PRD §9](../PRD.md#9-data--ml-plan)) is the response.

---

## Sources

**Disease-ID apps**
- [Best Plant Disease ID apps 2025 — Farmonaut](https://farmonaut.com/blogs/best-plant-disease-identification-app-2025-free-powerful)
- [7 Best Plant Disease ID Apps (2025), accuracy-tested — Plant Doctor News](https://blog.plantdoctor.app/tips/best-plant-disease-id-apps-2025-tested)
- [Nuru: AI assistant for African farmers — IITA](https://www.iita.org/news-item/african-farmers-get-new-help-against-cassava-diseases-nuru-their-artificially-intelligent-assistant/)
- [PlantVillage Nuru — CGIAR Big Data Platform](https://bigdata.cgiar.org/digital-intervention/plantvillage-nuru-pest-and-disease-monitoring-using-ai/)
- [Accuracy of PlantVillage Nuru in identifying cassava viral diseases — PMC, 2021](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7775399/)
- [How an XPRIZE-winning group built an AI assistant for African farmers — Penn State](https://agsci.psu.edu/safes/news/how-an-xprize-winning-group-developed-an-ai-assistant-to-help-african-farmers-increase-their-crops-and-adapt-to-the-climate-crisis)

**NIR / Brix quality tools**
- [F-750 Produce Quality Meter — Felix Instruments](https://felixinstruments.com/food-science-instruments/portable-nir-analyzers/f-750-produce-quality-meter/)
- [F-750 — SelectScience product page](https://www.selectscience.net/product/f-750-produce-quality-meter-from-felix-instruments)
- [F-750 — QA Supplies (US listing)](https://qasupplies.com/f-750-produce-quality-meter/)
- [Performance of two portable spectrometers (F-750 & SCiO; SCiO 740–1070 nm) — MDPI Agronomy, 2020](https://www.mdpi.com/2073-4395/10/1/148)
- [SCiO molecular sensor (Consumer Physics) consumer pricing — NoCamels, 2019](https://nocamels.com/2019/03/scio-kickstarter-darling-promises-molecular-sensor/)

**Food-spoilage / freshness**
- [Tiny sensor detects food spoilage, sends data to phone — New Atlas](https://newatlas.com/technology/sensor-detects-food-spoilage-real-time/)
- [Spoilage-sniffing sensor + food-distribution app — Maryland Today (UMD)](https://today.umd.edu/a-spoilage-sniffing-sensor-and-food-distribution-app-to-fight-hunger)
- [Food-freshness sensors could replace use-by dates — ScienceDaily, 2019](https://www.sciencedaily.com/releases/2019/06/190605100401.htm)
- [Smartphone app reads paper-based food-package sensors — New Science Report, 2020](https://newsciencereport.com/2020-03-02-smartphone-app-helps-reduce-waste-food-poisoning.html)

**Retail / B2B grading**
- [Intello Labs raises $5.9M for AI food grading — The Spoon](https://thespoon.tech/intello-labs-raises-5-9m-for-its-ai-based-food-grading/)
- [Intello Labs — company site](https://www.intellolabs.com/)
- [Clarifruit seeks to automate quality inspection — The Packer](https://www.thepacker.com/news/packer-tech/clarifruit-seeks-automate-quality-inspection-process)
- [TOMRA apple sorting & grading](https://www.tomra.com/food/categories/fruit/apples)
- [TOMRA Inspectra² — non-destructive internal (NIR Brix/dry matter) inspection](https://www.tomra.com/food/machines/inspectra2)
- [Sorting & grading solutions for apple packhouses — Food Engineering](https://www.foodengineeringmag.com/articles/100366-todays-sorting-and-grading-solutions-help-apple-packhouses-meet-operational-challneges)

*Pricing note: Felix F-750 and TOMRA systems are quote-based; figures shown are the best public estimates (F-750 ~$5,000+ / ~€5,140; TOMRA lines are six-figure capital equipment). SCiO consumer pricing (~$250–300) reflects its 2019 consumer edition before Consumer Physics shifted toward enterprise. Verify current pricing with vendors before citing in a submission.*
