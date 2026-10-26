# OrchardEye — Public Dataset Catalog for Plant-Disease CV & Fruit-Quality Spectroscopy

*Compiled 2026-06-19, revised for the apple-only scope. Crop of interest: apple; plus NIR/spectral fruit-quality data. Figures are cross-checked across ≥2 independent sources where possible; anything not confirmable from a primary/authoritative source is marked **[unverified]**. Many publisher pages (ScienceDirect, arXiv, Kaggle, Mendeley, PMC) returned HTTP 403 to automated fetch, so several numbers rest on corroborating search snippets + data-paper text rather than a single primary-page load.*

---

## 1. Master catalog table

| Dataset | Year | # Images | Crops / Classes | Annotation | Conditions | License | URL |
|---|---|---|---|---|---|---|---|
| **PlantVillage** | 2015–16 | **54,306** | 14 crops / **38 classes**; **Apple = 4** (scab, black rot, cedar apple rust, healthy) | Image-level labels only | **Lab** (uniform background) | CC0 on Mendeley mirror; not stated on GitHub → **[unverified/varies]** | [GitHub](https://github.com/spMohanty/PlantVillage-Dataset) |
| **PlantDoc** | 2020 | **2,598** | 13 species / **27 classes**, apple among them | **Bounding boxes** (8,851 boxes) + cropped-classification version | **Field** (in-the-wild) | CC BY 4.0 | [GitHub](https://github.com/pratikkayal/PlantDoc-Dataset) |
| **Plant Pathology 2020 (FGVC7)** | 2020 | 3,651 (paper) / **3,642** released (1,821 train + 1,821 test) | **Apple**; 4 (healthy, scab, cedar rust, multiple/"complex") | Image-level labels (single-label) | **Field** orchard (Cornell AgriTech, NY) | Kaggle comp. data; string **[unverified]** | [Kaggle](https://www.kaggle.com/c/plant-pathology-2020-fgvc7) |
| **Plant Pathology 2021 (FGVC8)** | 2021 | **18,632** | **Apple**; 6 (scab, rust, powdery mildew, frog-eye leaf spot, complex, healthy) | Image-level, **multi-label** | **Field** orchard | Kaggle comp. data; string **[unverified]** | [Kaggle](https://www.kaggle.com/c/plant-pathology-2021-fgvc8) |
| **DeepHS-Fruit** (Varga et al.) | 2021 | **~5,000** recordings **[exact unverified]** | Avocado, kiwi, mango, kaki, papaya; ripeness stages (+ firmness, sugar) | Hyperspectral cubes + destructive ground-truth labels | Lab (Specim FX10, Corning microHSI 410, INNO-SPEC RedEye) | Not stated **[unverified]** | [GitHub](https://github.com/cogsys-tuebingen/deephs_fruit) |
| **Multispectral apples — ripeness/Brix/variety** (Mendeley) | 2025 | **32,463** (Brix-labeled subset **1,620**) | **Apple**; Brix 10–15%, ripeness (18-day), 5–6 varieties | 8-band multispectral images; Brix via handheld refractometer | **Low-cost custom 8-band imaging chamber** | Mendeley default CC BY 4.0 → **[unverified]** | [Mendeley](https://data.mendeley.com/datasets/y5h6v8w6ms/2) |
| **Mango DMC + NIR spectra** (Anderson, Walsh, Subedi) | 2020 | thousands (~11k spectra **[unverified]**) | Mango; dry-matter content (maturity proxy, not Brix) | NIR absorbance spectra, **309–1149 nm** | Lab/handheld NIR (Felix F-750-class **[unverified]**) | **CC BY 4.0** | [Mendeley](https://data.mendeley.com/datasets/46htwnp833/4) / [GitHub mirror](https://github.com/spectral-datasets/mango-dmc) |

---

## 2. Per-dataset notes for OrchardEye

**PlantVillage** — The backbone for pretraining. Confirmed: **38 classes / 14 crops / 54,306 images**. **Apple = 4 classes** (`Apple___Apple_scab`, `Apple___Black_rot`, `Apple___Cedar_apple_rust`, `Apple___healthy`). The fatal caveat: it is **lab imagery on uniform backgrounds**, so models overfit to background and transfer poorly to field/greenhouse. Use it to pretrain, never as your only data. License is **CC0 on the Mendeley mirror** but unstated on the GitHub repo — treat as **varies/[unverified]** and pin it down before commercial use.

**PlantDoc** — The best **field**-condition complement with boxes: it covers apple in real conditions, under a clean **CC BY 4.0** license. Small (2,598 images), but ideal for domain-adapting a detector off PlantVillage pretraining. (Author surname correction: the team is Singh, Jain, Jain, Kayal, **Kumawat**, Batra — not "Kumar.")

**Apple — Plant Pathology 2020/2021 (FGVC)** — The strongest **apple-specific, field-condition** resource. 2020 is 4-class single-label (~3.6k); **2021 scales to 18,632 multi-label images** and adds powdery mildew + frog-eye leaf spot. Both are **image-level only (no boxes)** and image-classification oriented. Excellent for an apple foliar-disease classifier; pair with a detector trained elsewhere if you need localization. License strings are **[unverified]** (Kaggle pages blocked) — confirm Kaggle competition terms before redistribution.

**Apple — the honest gap** — Apple is well covered for *foliar* disease in *field* conditions (Plant Pathology 2020/2021), and that is the strongest part of this catalog. What is missing is **apple fruit** imagery: PlantVillage apple is leaf-only, Plant Pathology is leaf-only, and the summer and storage rots that matter commercially — **bitter rot, sooty blotch and flyspeck, blue and grey mould** — have **no public labelled set**. A leaf-trained model is therefore honestly out of distribution on a whole-fruit photo, which is why the app reports disease as *not assessed* on fruit scans instead of guessing. Closing this means collecting our own fruit imagery.

**NIR / spectral fruit quality — the other honest gap** — Public spectral fruit-quality data is dominated by **expensive lab instruments**: **DeepHS-Fruit** (hyperspectral, Specim FX10 / Corning microHSI / INNO-SPEC; ~5,000 recordings; avocado/kiwi/mango/kaki/papaya — **no apple**) and the **Anderson mango DMC NIR** set (309–1149 nm, CC BY 4.0, but DMC not Brix, and mango). The closest to apple-Brix is a **2025 Mendeley multispectral-apple** set (32,463 images, **1,620 Brix-labeled**) built with a **low-cost custom 8-band imaging chamber** — promising, but it's **multispectral imaging, not point spectroscopy**, and not your sensor. **Critically: there is no large public dataset captured with the AS7265x (or any comparable cheap ~410–940 nm point sensor) for fruit Brix/ripeness.** AS7265x-based studies (e.g., "SweetFruit," portable fruit-ripeness work) consistently **keep their data private**. If OrchardEye standardizes on the AS7265x, you will almost certainly **need to build your own spectral calibration dataset** (fruit + refractometer Brix ground-truth); public data can at best inform method choice, not be dropped in directly.

---

## 3. Recommended starting point

1. **Apple disease (foliar):** pretrain on **PlantVillage apple** (volume, clean labels) → fine-tune on **Plant Pathology 2021 (FGVC8)** (18,632 field images, 6 classes, adds powdery mildew and frog-eye leaf spot). Add boxes from **PlantDoc** if localization is needed. This is the path the shipped `AppleDiseaseClassifier.mlmodel` already took.
2. **Apple disease (fruit):** **build your own.** No public set covers bitter rot, sooty blotch/flyspeck or storage rots on fruit. Until one exists, fruit scans stay out of the disease head.
3. **Spectral/Brix:** treat as a **build-your-own** track. Use **DeepHS-Fruit** and the **mango DMC** set to choose modeling methods (PLS/CNN on spectra), but plan an **AS7265x + refractometer** calibration campaign — no matched public dataset exists.

---

## Sources

- https://github.com/spMohanty/PlantVillage-Dataset
- https://www.frontiersin.org/journals/plant-science/articles/10.3389/fpls.2016.01419/full
- https://pmc.ncbi.nlm.nih.gov/articles/PMC5032846/
- https://arxiv.org/abs/1511.08060
- https://www.tensorflow.org/datasets/catalog/plant_village
- https://data.mendeley.com/datasets/tywbtsjrjv/1
- https://github.com/pratikkayal/PlantDoc-Dataset
- https://arxiv.org/abs/1911.10317
- https://dl.acm.org/doi/10.1145/3371158.3371196
- https://public.roboflow.com/object-detection/plantdoc
- https://www.kaggle.com/c/plant-pathology-2020-fgvc7
- https://arxiv.org/abs/2004.11958
- https://bsapubs.onlinelibrary.wiley.com/doi/10.1002/aps3.11390
- https://www.kaggle.com/c/plant-pathology-2021-fgvc8
- https://vision.cornell.edu/se3/wp-content/uploads/2021/09/029.pdf
- https://arxiv.org/pdf/2210.00298
- https://link.springer.com/article/10.1007/s00530-023-01158-y
- https://github.com/cogsys-tuebingen/deephs_fruit
- https://cogsys.cs.uni-tuebingen.de/webprojects/DeepHS-Fruit-2023-Datasets/
- https://data.mendeley.com/datasets/y5h6v8w6ms/2
- https://www.sciencedirect.com/science/article/pii/S2352340925005906
- https://data.mendeley.com/datasets/46htwnp833/4
- https://github.com/spectral-datasets/mango-dmc
- https://www.frontiersin.org/journals/plant-science/articles/10.3389/fpls.2025.1634785/full
- https://arxiv.org/html/2606.01231v1

---

**Key callouts:**
- **Apple foliar data is in good shape**: PlantVillage apple for volume, Plant Pathology 2021 (18,632 field, multi-label) for realism. The shipped model is trained on the PlantVillage apple set and tests at 98.5% on a held-out split — a lab number, not a field number.
- **Apple fruit disease is the real gap**: nothing public covers bitter rot, sooty blotch/flyspeck or storage rots on fruit, which is why the app declines to diagnose whole-fruit scans.
- **No public AS7265x / cheap-sensor Brix dataset exists** — the spectral track will require your own calibration data; public spectral sets are all lab hyperspectral/FT-NIR and cover other fruits.
- License strings for most Kaggle/Roboflow sets are **[unverified]** because those pages blocked automated fetch — confirm them manually before any commercial use.
