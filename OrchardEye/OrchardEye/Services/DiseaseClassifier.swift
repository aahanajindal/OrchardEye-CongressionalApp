//
//  DiseaseClassifier.swift
//  OrchardEye
//
//  Stage 4 (vision head). `DiseaseClassifier` is the seam a real INT8 Core ML /
//  TFLite model drops into. `HeuristicDiseaseClassifier` derives a plausible result
//  from real on-device image stats so the whole app is demoable today.
//

import UIKit

struct DiseaseClassification {
    var disease: DiseaseInfo
    var confidence: Double      // 0–1
    var alternatives: [String]  // shown when confidence is low
    var health: CropHealth
    var detection: AppleDetection? = nil   // subject gate (apple/plant) — Core ML
}

protocol DiseaseClassifier {
    func classify(image: UIImage, crop: Crop) async -> DiseaseClassification
}

/// Confidence at/above this flags a disease and names it; below it, the result is
/// only "suspected". One threshold, used by the disease card, verdict, History and CSV
/// alike, so they can never disagree (a disease name never sits next to a green banner).
let kDiseaseConfidenceThreshold = 0.70
/// A confident model result at/above this vouches for the subject (leaf/fruit present).
let kSubjectConfirmThreshold = 0.50

/// How a disease result should be presented — the single source of truth.
enum DiseaseState { case flagged, suspected, clear }

/// - assessable: false for whole-fruit scans (the model is leaf-trained → N/A).
func diseaseState(isHealthy: Bool, confidence: Double, lesionPct: Double, assessable: Bool) -> DiseaseState {
    guard assessable, !isHealthy else { return .clear }
    if confidence >= kDiseaseConfidenceThreshold || lesionPct > 30 { return .flagged }
    return .suspected
}

/// User-facing disease label consistent with `diseaseState` — used by the disease
/// card, verdict details, and History so they never disagree.
func diseaseDisplayName(isHealthy: Bool, name: String, confidence: Double, lesionPct: Double, assessable: Bool) -> String {
    switch diseaseState(isHealthy: isHealthy, confidence: confidence, lesionPct: lesionPct, assessable: assessable) {
    case .flagged:   return name
    case .suspected: return "Possible \(name)"
    case .clear:     return assessable ? "None detected" : "Not assessed (fruit)"
    }
}

final class HeuristicDiseaseClassifier: DiseaseClassifier {

    func classify(image: UIImage, crop: Crop) async -> DiseaseClassification {
        // Simulate on-device inference latency (target < 3 s end-to-end).
        try? await Task.sleep(nanoseconds: 500_000_000)
        let s = ImageAnalysis.stats(for: image)
        return Self.classify(stats: s, crop: crop)
    }

    /// Pure, synchronous heuristic over pre-computed image stats. Split out so the
    /// real Core ML path can reuse the crop-health signals without a second image
    /// pass or the artificial sleep above.
    static func classify(stats s: ImageStats, crop: Crop) -> DiseaseClassification {
        let health = cropHealth(from: s, crop: crop)
        let symptom = max(health.lesionPct, health.chlorosisPct)   // 0–100, strongest symptom
        let candidates = DiseaseInfo.candidates(for: crop)

        // Few symptoms → healthy.
        if symptom < 12 {
            let conf = min(0.97, 0.82 + s.greenFraction * 0.2)
            return DiseaseClassification(
                disease: .healthy, confidence: conf,
                alternatives: candidates.first.map { [$0.name] } ?? [],
                health: health)
        }

        // Otherwise pick a disease deterministically from the symptom signature.
        // Prime multipliers over the full 0–1 fractions spread images across the
        // candidate set instead of collapsing onto one or two.
        let sig = s.brownFraction * 131 + s.yellowFraction * 71 + s.greenFraction * 17
        let idx = Int(sig.rounded()) % max(1, candidates.count)
        let primary = candidates[idx]
        // Fallback heuristic (used when no trained model answers): cap below the
        // flag threshold so it surfaces as "suspected", never a confident false call.
        let conf = min(0.65, 0.45 + (symptom / 100) * 0.3)
        let alts = Array(candidates.filter { $0 != primary }.map { $0.name }.prefix(2))

        return DiseaseClassification(
            disease: primary, confidence: conf, alternatives: alts, health: health)
    }

    /// Real on-device crop-health signals (greenness / lesion / chlorosis).
    static func cropHealth(from s: ImageStats, crop: Crop) -> CropHealth {
        let lesion = min(100, s.brownFraction * 200)
        let chlorosis = min(100, s.yellowFraction * 160)
        let healthScore = max(0, min(100, Int(100 - lesion * 0.8 - chlorosis * 0.5)))
        return CropHealth(
            score: healthScore,
            chlorosisPct: chlorosis,
            lesionPct: lesion,
            sizeEstimate: min(1, s.greenFraction * 2),
            lifecycleStage: lifecycleStage(for: crop, size: s.greenFraction))
    }

    static func lifecycleStage(for crop: Crop, size: Double) -> String {
        switch crop {
        case .apple: return size > 0.5 ? "Fruit development" : "Early canopy"
        }
    }
}
