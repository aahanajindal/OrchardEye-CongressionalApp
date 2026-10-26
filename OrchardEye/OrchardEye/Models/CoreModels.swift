//
//  CoreModels.swift
//  OrchardEye
//
//  The core data types shared across the scan pipeline:
//  capture → quality gate → disease + crop-health → ripeness → fusion → verdict.
//

import Foundation
import SwiftUI

// MARK: - Crop & Variety

enum Crop: String, Codable, CaseIterable, Identifiable {
    case apple

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: return "Apple"
        }
    }

    var emoji: String {
        switch self {
        case .apple: return "🍎"
        }
    }
}

struct Variety: Codable, Hashable, Identifiable {
    var name: String
    var crop: Crop

    var id: String { "\(crop.rawValue)-\(name)" }
    var displayName: String { "\(name) \(crop.displayName.lowercased())" }

    static let apples = ["Cosmic Crisp", "Honeycrisp", "Gala", "Fuji", "Red Delicious",
                         "Granny Smith", "Golden Delicious", "Pink Lady", "McIntosh", "Cortland"]
        .map { Variety(name: $0, crop: .apple) }

    static let all: [Variety] = apples
    static let `default` = apples[0]
}

// MARK: - Disease

/// One disease (or the "healthy" result) with plain-language guidance.
struct DiseaseInfo: Codable, Hashable, Identifiable {
    var name: String
    var isHealthy: Bool
    var infectious: Bool
    var treatable: Bool
    var summary: String   // what it is
    var action: String    // what to do next

    var id: String { name }
}

extension DiseaseInfo {
    static let healthy = DiseaseInfo(
        name: "Healthy — no disease detected", isHealthy: true, infectious: false, treatable: true,
        summary: "No visible disease symptoms were found on this sample.",
        action: "Keep monitoring on your normal schedule.")

    static let appleScab = DiseaseInfo(
        name: "Apple scab", isHealthy: false, infectious: true, treatable: true,
        summary: "A fungal disease (Venturia inaequalis) causing olive-green to brown velvety lesions on leaves and fruit.",
        action: "Remove fallen leaves and apply a protectant fungicide before the next wet period.")
    static let appleBlackRot = DiseaseInfo(
        name: "Black rot", isHealthy: false, infectious: true, treatable: true,
        summary: "A fungal disease causing 'frog-eye' leaf spots and a firm fruit rot, often from cankered wood.",
        action: "Prune out cankers and mummified fruit; protect with fungicide in warm, wet weather.")
    static let appleRust = DiseaseInfo(
        name: "Cedar apple rust", isHealthy: false, infectious: true, treatable: true,
        summary: "Bright orange-yellow leaf spots; needs nearby junipers to complete its life cycle.",
        action: "Remove nearby junipers if possible; apply fungicide from pink bud through early summer.")
    static let fireBlight = DiseaseInfo(
        name: "Fire blight", isHealthy: false, infectious: true, treatable: false,
        summary: "A fast bacterial disease (Erwinia amylovora); shoots wilt into a 'shepherd's crook' and blacken.",
        action: "Cut 30 cm below visible infection in dry weather; sterilize tools between cuts. No cure once systemic.")

    static let applePowderyMildew = DiseaseInfo(
        name: "Powdery mildew", isHealthy: false, infectious: true, treatable: true,
        summary: "Podosphaera leucotricha; white felted growth on shoots and leaves, with russeted fruit later.",
        action: "Prune out silvered shoot tips at dormancy and keep a protectant programme through primary growth.")
    static let bitterRot = DiseaseInfo(
        name: "Bitter rot", isHealthy: false, infectious: true, treatable: true,
        summary: "Colletotrichum species; sunken brown fruit lesions with concentric spore masses, worst in warm, wet summers.",
        action: "Remove mummies and dead wood, and keep cover sprays tight from mid-summer to harvest.")
    static let sootyBlotch = DiseaseInfo(
        name: "Sooty blotch and flyspeck", isHealthy: false, infectious: false, treatable: true,
        summary: "A surface fungal complex leaving smudges and black dots on the skin. Cosmetic — the flesh underneath is sound.",
        action: "Open the canopy for airflow and extend summer cover sprays in a wet season. Fruit is still edible.")

    /// Candidate diseases for a crop (excluding healthy), used by the heuristic classifier.
    static func candidates(for crop: Crop) -> [DiseaseInfo] {
        switch crop {
        case .apple: return [appleScab, appleBlackRot, appleRust, fireBlight,
                             applePowderyMildew, bitterRot, sootyBlotch]
        }
    }
}

// MARK: - Crop health

struct CropHealth: Codable, Hashable {
    var score: Int          // 0–100 overall
    var chlorosisPct: Double // % yellow/off-green
    var lesionPct: Double    // % lesion/spot coverage
    var sizeEstimate: Double // 0–1 relative size in frame
    var lifecycleStage: String

    var scoreColor: Color {
        switch score {
        case 80...:  return .green
        case 55..<80: return .yellow
        default:     return .red
        }
    }
}

// MARK: - Ripeness (on-device, from colour)

enum RipenessClass: String, Codable, CaseIterable {
    case unripe, ripe, overripe

    var displayName: String {
        switch self {
        case .unripe:   return "Not ready"
        case .ripe:     return "Ripe"
        case .overripe: return "Overripe"
        }
    }
    var color: Color {
        switch self {
        case .unripe:   return .orange
        case .ripe:     return .green
        case .overripe: return .brown
        }
    }
}

/// On-device ripeness read, estimated from fruit colour in the camera image —
/// no external NIR sensor. `score` is a 0–100 visual-ripeness index (a proxy for
/// sweetness/readiness), not a lab °Brix measurement.
struct RipenessReading: Codable, Hashable {
    var ripeness: RipenessClass
    var score: Double          // 0–100 visual ripeness from colour
    var confidence: Double     // 0–1, how confidently the frame reads as fruit
    var foliage: Bool = false  // frame looks like a leaf → ripeness is N/A (fruit-only)
    var fruit: Bool = false    // frame looks like whole fruit → disease is N/A (leaf-trained)
}

// MARK: - Fusion outputs

enum Verdict: String, Codable {
    case diseased, notReady, premium

    var title: String {
        switch self {
        case .diseased: return "Diseased"
        case .notReady: return "Healthy — not ready"
        case .premium:  return "Healthy & premium"
        }
    }
    var emoji: String {
        switch self {
        case .diseased: return "🔴"
        case .notReady: return "🟠"
        case .premium:  return "🟢"
        }
    }
    var color: Color {
        switch self {
        case .diseased: return .red
        case .notReady: return .orange
        case .premium:  return .green
        }
    }
    /// Deep two-stop gradient for the verdict banner. Darker than `color` so the
    /// white banner title/pills clear WCAG contrast — plain `.orange`/`.green`
    /// under white text fail (~1.9:1 / ~1.6:1) and wash out in bright sun.
    var bannerColors: [Color] {
        switch self {
        case .diseased: return [Color(red: 0.75, green: 0.15, blue: 0.12),
                                Color(red: 0.55, green: 0.10, blue: 0.09)]
        case .notReady: return [Color(red: 0.70, green: 0.42, blue: 0.03),
                                Color(red: 0.50, green: 0.29, blue: 0.02)]
        case .premium:  return [Color(red: 0.184, green: 0.490, blue: 0.243),
                                Color(red: 0.086, green: 0.188, blue: 0.125)]
        }
    }
}

enum RiskLabel: String, Codable {
    case infectious, treatable, cosmetic, none

    var displayName: String {
        switch self {
        case .infectious: return "Likely infectious"
        case .treatable:  return "Treatable"
        case .cosmetic:   return "Cosmetic"
        case .none:       return "No disease"
        }
    }
}

enum Urgency: String, Codable {
    case low, medium, high

    var displayName: String {
        switch self {
        case .low:    return "Low urgency"
        case .medium: return "Act soon"
        case .high:   return "Act now"
        }
    }
    var color: Color {
        switch self {
        case .low:    return .green
        case .medium: return .orange
        case .high:   return .red
        }
    }
}

struct FusionResult {
    var verdict: Verdict
    var title: String          // banner headline (foliage-aware; falls back to verdict.title)
    var recommendation: String
    var risk: RiskLabel
    var urgency: Urgency
    var spoken: String
    var showRipeness: Bool     // false for leaf/foliage scans (ripeness is fruit-only)
    var showDisease: Bool      // false for whole-fruit scans (disease model is leaf-trained)
}

// MARK: - Weather

struct WeatherSnapshot: Codable, Hashable {
    var tempC: Double
    var humidityPct: Double
    var precipRecentMM: Double
    var precipForecastMM: Double
    var summary: String
    var capturedAt: Date

    var diseasePressure: String {
        // Warm + humid + recent moisture favors fungal/bacterial spread.
        if tempC >= 15 && humidityPct >= 70 { return "high" }
        if tempC >= 10 && humidityPct >= 55 { return "moderate" }
        return "low"
    }
}

// MARK: - Scan record (persisted)

struct ScanRecord: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var plantTag: String           // groups repeat scans of one plant/block (powers trends)
    var variety: Variety
    var imageData: Data?           // downscaled JPEG for history
    var disease: DiseaseInfo
    var diseaseConfidence: Double  // 0–1
    var alternatives: [String]
    var health: CropHealth
    var ripeness: RipenessReading
    var appleCount: Int = 0         // approximate apples in frame (fruit scans only)
    var verdict: Verdict
    var verdictTitle: String = ""   // foliage/suspected-aware banner headline (from fusion)
    var recommendation: String
    var risk: RiskLabel
    var urgency: Urgency
    var weather: WeatherSnapshot?
    var userConfirmed: Bool?       // F7: nil = unreviewed, true = confirmed, false = corrected
    var userCorrectionNote: String?
}
