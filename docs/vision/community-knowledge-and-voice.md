# OrchardEye — Community Knowledge & Voice Guidance

> **Status:** vision draft (v0.1)
> This is the "matured / overall-perspective" layer of OrchardEye: the part that turns a scanner into a **community-owned advisor**. It covers (1) **voice guidance**, (2) **farmer wisdom feeding a local knowledge corpus**, and (3) **community ownership of the model**. It is written as a roadmap — v1 ships a thin slice; the full vision is multi-season.

---

## Why this layer exists

A disease classifier alone is a *tool*. What makes OrchardEye matter to **WA-08's growers** is that it can become **theirs** — speaking their language, learning their varieties, and capturing the wisdom that already lives in the orchard. Two design beliefs drive this:

1. **The expert is often the farmer.** Decades of local, hands-on knowledge ("on this slope, scab shows up after the first warm rain") rarely make it into any dataset. We should *capture and amplify* it, not replace it.
2. **Accessibility is a feature, not a nicety.** Hands are busy, eyes are on the tree, signal is weak, and the orchard workforce is multilingual. Voice-first, offline-first design is what makes the tool usable where it's needed.

---

## 1. Voice guidance

**Goal:** a grower can complete a scan and act on it **without reading the screen**.

### What it does
- **Speaks the verdict** ("Healthy, about 11 Brix — ripe, pick now") and the **next action**.
- **Guides capture** during the quality gate ("Move a little closer," "Too much glare").
- **Adapts to weather** pulled from a free weather API and cached offline:
  - *"Rain expected tonight — if you plan to spray, do it this afternoon."*
  - *"Warm and humid this week — scab pressure is rising; re-check this block in 3 days."*
- Runs **on-device** (TTS + any intent handling), so it works with no signal in the field.

### Accessibility & inclusion
- **Multilingual:** English in v1; **Spanish a top priority** next, given the orchard workforce. Local/Indigenous language support is a long-term aim.
- **Low-literacy friendly:** spoken output + color-coded cards (🔴/🟠/🟢) + icons reduce reliance on reading.
- **One-handed, outdoor:** large tap targets, high contrast, voice prompts — see PRD §10.

### v1 scope
- Speak the final verdict + recommendation, and the quality-gate retake prompts.
- Weather-aware phrasing using cached weather variables.
- (Later) two-way voice — ask a question, get a spoken answer from the local corpus.

---

## 2. Farmer wisdom → local knowledge corpus

**Goal:** every scan is a chance for the grower to *teach* the system, and for that knowledge to help the next grower nearby.

### How knowledge is captured
- **Confirm / correct the verdict.** After a result, a one-tap "Was this right?" → ✅ / ✏️ correct it. Corrections are the highest-value training signal and also measure real-world accuracy honestly.
- **Add wisdom.** Free-text or **voice notes**: what the grower saw, what they did, what worked. Local names for problems ("we call this…").
- **Ask questions.** Questions that the corpus can't yet answer are logged — they become the roadmap for what knowledge to gather next, and can be routed to WSU Extension / a local agronomist.

### What the corpus becomes
- A **localized knowledge base** for *this* community's varieties, microclimates, and practices — the context a generic model never has.
- Tied to **structured scan data** (the variable dictionary in [feature-list.md](../design/feature-list.md)) so wisdom is searchable by crop, disease, season, and location.
- A feedback source that periodically **fine-tunes the on-device model** and **re-weights fusion** for local conditions (see pipeline Stage 7).

### "Encourage them to contribute and have their voice heard"
- **Low friction:** contributing is one tap or one spoken sentence — never a form.
- **Visible value:** show contributors *"3 growers near you confirmed this works"*; let them see the local corpus improve.
- **Credit & voice:** attribute community knowledge (opt-in); surface grower tips alongside model output. The farmer is a co-author of the guidance, not just a user.
- **Reciprocity:** the more a community contributes, the better *their* localized guidance gets — the benefit is local and immediate.

---

## 3. Community ownership of the AI

**Principle:** the localized model and corpus should be **owned and governed by the local growing community**, not extracted from it.

| Topic | Stance for OrchardEye |
|---|---|
| **Data ownership** | Growers own their scans and contributions; local-first storage, explicit opt-in to share. |
| **Where it lives** | On-device first; community aggregation is opt-in and, ideally, **federated** (share model improvements, not raw private data). |
| **Governance** | A community/Extension partner (e.g., WSU Tree Fruit Research & Extension Center) can steward the shared corpus. |
| **Privacy** | GPS and images are sensitive (farm operations); sharing is granular and revocable. |
| **No lock-in** | CSV export of one's own data, always. |

This is deliberately scoped as **vision/future-work** — v1 demonstrates the *thin slice* (confirm/correct + local notes + voice), and the write-up is honest that full federated, community-governed AI is a roadmap, not a v1 claim.

---

## 4. How this maps to v1 vs. later

| Capability | v1 | Later |
|---|---|---|
| Spoken verdict + retake prompts | ✅ | — |
| Weather-adaptive voice phrasing | ✅ (cached) | richer forecasting |
| Spanish | 🎯 next | more languages |
| Confirm/correct verdict | ✅ | — |
| Voice notes / wisdom capture | 🟡 if time | structured, searchable corpus |
| Question logging → Extension routing | 🟡 | two-way Q&A from corpus |
| On-device fine-tuning from local data | 🔵 | periodic, federated |
| Community-governed shared model | 🔵 | with Extension partner |

---

## 5. Why judges should care (Congressional App Challenge)

This layer is where OrchardEye stops being "another disease classifier" and becomes a **community institution**:
- **Impact / local relevance:** built *with* and *for* WA-08 growers; amplifies their voice and knowledge.
- **Equity & access:** voice-first, multilingual, offline — works for the people doing the work.
- **Sustainability:** localized guidance reduces waste and unnecessary spraying.
- **Honesty:** we ship a real thin slice and clearly label the rest as roadmap — rigor reads as strength.

> One line for the demo: *"OrchardEye doesn't just tell farmers what's wrong — it learns from them, speaks their language, and gives the knowledge back to the community that grew it."*
