//
//  FusionEngine.swift
//  OrchardEye
//
//  Stage 5. Decision-level fusion: combine disease + crop-health + ripeness
//  + weather + this plant's trend into ONE verdict, a risk label, an urgency,
//  and plain-language + spoken recommendations.
//

import Foundation

enum FusionEngine {

    static func fuse(disease: DiseaseClassification,
                     ripeness: RipenessReading,
                     weather: WeatherSnapshot?,
                     priorTrend: TrendSummary?,
                     variety: Variety) -> FusionResult {

        // Subject: disease is only meaningful on a leaf (the model is leaf-trained);
        // ripeness is only meaningful on fruit. One photo answers whichever it shows.
        let foliage = ripeness.foliage
        let fruit = ripeness.fruit
        let assessDisease = !fruit

        // Subject gate: if the frame isn't a plausible apple leaf/fruit, don't fabricate
        // any verdict (the disease heads have no "not-apple" class).
        // Fail closed: no valid apple subject → no verdict. (ripeness.fruit is already
        // subject-gated upstream, so a `|| fruit` escape hatch would only re-admit a
        // non-apple whose detection was nil.)
        let hasSubject = disease.detection?.subjectValid ?? false
        if !hasSubject {
            return FusionResult(
                verdict: .notReady, title: "No apple leaf or fruit detected",
                recommendation: "Point the camera at an apple leaf or an apple, then scan again. This photo didn't look like either.",
                risk: .none, urgency: .low,
                spoken: "No apple leaf or fruit detected. Point the camera at an apple leaf or an apple.",
                showRipeness: false, showDisease: false)
        }

        // One disease decision, shared with the disease card / History / CSV.
        let state = diseaseState(isHealthy: disease.disease.isHealthy, confidence: disease.confidence,
                                 lesionPct: disease.health.lesionPct, assessable: assessDisease)
        let flagged = state == .flagged
        let suspected = state == .suspected
        // A whole fruit can't be named by the leaf model, but heavy browning is worth a rot warning.
        let fruitRot = fruit && disease.health.lesionPct > 40
        let ripeStr = String(format: "%.0f", ripeness.score)

        // --- Verdict + banner title (single source of truth) ---
        let verdict: Verdict
        let title: String
        if flagged {
            verdict = .diseased;  title = verdict.title
        } else if fruitRot {
            verdict = .diseased;  title = "Possible fruit rot"
        } else if fruit {
            verdict = ripeness.ripeness == .ripe ? .premium : .notReady
            title = verdict.title
        } else if suspected {
            verdict = .notReady;  title = "Possible \(disease.disease.name) — low confidence"
        } else if foliage {
            verdict = .premium;   title = "Healthy — no disease"   // healthy leaf → green banner
        } else if ripeness.ripeness == .ripe && disease.health.score >= 80 {
            verdict = .premium;   title = verdict.title
        } else {
            verdict = .notReady;  title = verdict.title
        }

        // --- Risk (only a flagged disease carries risk) ---
        let risk: RiskLabel
        if flagged {
            risk = disease.disease.infectious ? .infectious : (disease.disease.treatable ? .treatable : .cosmetic)
        } else if fruitRot {
            risk = .treatable
        } else {
            risk = .none
        }

        // --- Urgency: infectiousness + weather pressure + worsening trend ---
        var score = 0
        if flagged { score += 1 }
        if flagged && disease.disease.infectious { score += 1 }
        if flagged, let w = weather, w.diseasePressure == "high" { score += 1 }
        if flagged && priorTrend?.direction == .worsening { score += 1 }
        let urgency: Urgency = score >= 3 ? .high : (score == 2 ? .medium : .low)

        // --- Recommendation ---
        var rec: String
        if flagged {
            rec = "\(disease.disease.name) suspected. \(disease.disease.action)"
        } else if fruitRot {
            rec = "Heavy browning on the fruit — possible rot. Remove affected fruit, and photograph a leaf to screen for disease."
        } else if fruit {
            if verdict == .premium {
                rec = "Looks ripe (colour reads ~\(ripeStr)/100). Pick now for premium grade."
            } else if ripeness.ripeness == .unripe {
                rec = "Not ripe yet (colour ~\(ripeStr)/100). Re-check in a few days."
            } else {
                rec = "Ripeness looks borderline (~\(ripeStr)/100). Monitor before harvest."
            }
            rec += " Disease isn't checked on fruit — photograph a leaf to screen for disease."
        } else if suspected {
            rec = "Possible \(disease.disease.name), but confidence is low. Retake from another angle in good light to confirm."
        } else if foliage {
            rec = "No disease detected — this looks like healthy foliage. Ripeness is measured on the fruit."
        } else if verdict == .premium {
            rec = "Healthy and ripe (colour reads ~\(ripeStr)/100). Pick now for premium grade."
        } else if ripeness.ripeness == .unripe {
            rec = "No disease, but not ripe yet (colour ~\(ripeStr)/100). Re-check in a few days."
        } else {
            rec = "No disease, but ripeness looks borderline (~\(ripeStr)/100). Monitor before harvest."
        }

        // Weather / trend nudges apply only to a flagged disease.
        if flagged, let w = weather {
            if w.precipForecastMM > 1 {
                rec += " Rain is expected — if you spray, do it before it arrives."
            } else if w.diseasePressure == "high" && disease.disease.infectious {
                rec += " Warm, humid conditions favor spread — re-check this block within 3 days."
            }
        }
        if flagged && priorTrend?.direction == .worsening {
            rec += " This plant has been getting worse across scans — treat it as spreading."
        }

        let spoken = "\(title). \(rec)"
        return FusionResult(verdict: verdict, title: title, recommendation: rec,
                            risk: risk, urgency: urgency, spoken: spoken,
                            showRipeness: !foliage, showDisease: assessDisease)
    }
}
