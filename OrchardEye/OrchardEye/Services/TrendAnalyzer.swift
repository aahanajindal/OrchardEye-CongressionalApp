//
//  TrendAnalyzer.swift
//  OrchardEye
//
//  Stage 6 (trends). Turns a plant's scan history into a trajectory:
//  improving / stable / worsening, a spread index, and a "suspicious" flag —
//  the signal that distinguishes a spreading (infectious) problem from a
//  static (cosmetic/treatable) one.
//

import Foundation

enum TrendDirection: String, Codable {
    case improving, stable, worsening
}

struct TrendPoint: Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var healthScore: Int
    var lesionPct: Double
    var ripenessScore: Double
    var foliage: Bool = false
    var fruit: Bool = false

    var diseaseAssessed: Bool { !fruit }    // leaf-trained model → skip fruit scans
    var ripenessApplies: Bool { !foliage }  // ripeness is fruit-only
}

struct TrendSummary {
    var direction: TrendDirection
    var spreadIndex: Double     // 0–1, how fast lesions are growing
    var flagged: Bool           // worsening enough to warrant attention
    var points: [TrendPoint]
}

enum TrendAnalyzer {

    static func points(for plantTag: String, in records: [ScanRecord]) -> [TrendPoint] {
        records
            .filter { $0.plantTag == plantTag }
            .sorted { $0.date < $1.date }
            .map { TrendPoint(date: $0.date, healthScore: $0.health.score,
                              lesionPct: $0.health.lesionPct, ripenessScore: $0.ripeness.score,
                              foliage: $0.ripeness.foliage, fruit: $0.ripeness.fruit) }
    }

    static func summary(for plantTag: String, in records: [ScanRecord]) -> TrendSummary {
        let pts = points(for: plantTag, in: records)
        // Disease trajectory is meaningful only across leaf scans — a fruit scan's
        // lesion/health are artifacts, so they must not drive "worsening/spreading".
        let dpts = pts.filter { $0.diseaseAssessed }
        guard dpts.count >= 2, let first = dpts.first, let last = dpts.last else {
            return TrendSummary(direction: .stable, spreadIndex: 0, flagged: false, points: pts)
        }

        // Least-squares slope over elapsed days, not first-vs-last: a plant that
        // spiked then recovered reads ~flat (as it should), and a single noisy point
        // can't flip the whole trajectory.
        let t0 = first.date
        let xs = dpts.map { $0.date.timeIntervalSince(t0) / 86_400 }   // days from first scan
        let healthSlope = slope(xs, dpts.map { Double($0.healthScore) })  // pts/day
        let lesionSlope = slope(xs, dpts.map { $0.lesionPct })            // %/day
        let span = max(xs.last! - xs.first!, 0)                           // observed window, days
        let healthDelta = healthSlope * max(span, 1.0 / 24.0)
        let lesionDelta = lesionSlope * max(span, 1.0 / 24.0)

        let direction: TrendDirection
        if healthDelta <= -10 || lesionDelta >= 10 {
            direction = .worsening
        } else if healthDelta >= 10 || lesionDelta <= -10 {
            direction = .improving
        } else {
            direction = .stable
        }

        // Spread is meaningless below ~3 h of separation — two rescans minutes apart
        // would otherwise make measurement noise read as explosive spread.
        let spreadIndex = span >= 3.0 / 24.0 ? max(0, min(1, lesionSlope / 5.0)) : 0
        let flagged = direction == .worsening && last.lesionPct > 15

        return TrendSummary(direction: direction, spreadIndex: spreadIndex, flagged: flagged, points: pts)
    }

    /// Least-squares slope of y over x; 0 when x has no spread (e.g. all same timestamp).
    private static func slope(_ x: [Double], _ y: [Double]) -> Double {
        let n = Double(x.count)
        let sx = x.reduce(0, +), sy = y.reduce(0, +)
        let sxx = zip(x, x).map(*).reduce(0, +)
        let sxy = zip(x, y).map(*).reduce(0, +)
        let denom = n * sxx - sx * sx
        return abs(denom) < 1e-9 ? 0 : (n * sxy - sx * sy) / denom
    }
}
