//
//  AppModel.swift
//  OrchardEye
//
//  App-wide state + service wiring (injected via @EnvironmentObject), plus the
//  local scan store (JSON persistence + CSV export, F4).
//

import Foundation
import SwiftUI
import Observation

// MARK: - JSON helpers (ISO-8601 dates)

extension JSONEncoder {
    static var orchard: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}
extension JSONDecoder {
    static var orchard: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

// MARK: - Scan store

/// Decodes to `nil` instead of throwing, so one corrupt/legacy record can't wipe
/// the whole history array on load after a schema change.
private struct FailableRecord: Decodable {
    let record: ScanRecord?
    init(from decoder: Decoder) throws {
        record = try? decoder.singleValueContainer().decode(ScanRecord.self)
    }
}

@MainActor
@Observable
final class ScanStore {
    private(set) var records: [ScanRecord] = []
    /// Set true when the last write failed (e.g. disk full) so the UI can warn
    /// instead of silently losing the scan the user just took.
    // @Snapshotable
    var saveFailed: Bool = false

    /// Cap history so scans.json can't grow without bound — each record carries a
    /// ~600px JPEG thumbnail, and the whole file is decoded into memory on launch.
    /// Oldest scans drop first.
    static let maxRecords = 500

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("scans.json")
    }()
    private let writer = ScanDiskWriter()

    init() { load() }

    func add(_ record: ScanRecord) {
        records.insert(record, at: 0)
        if records.count > Self.maxRecords {
            records.removeLast(records.count - Self.maxRecords)
        }
        save()
    }

    func update(_ record: ScanRecord) {
        if let i = records.firstIndex(where: { $0.id == record.id }) {
            records[i] = record
            save()
        }
    }

    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        save()
    }

    var plantTags: [String] {
        Array(Set(records.map { $0.plantTag })).sorted()
    }

    func records(forPlant tag: String) -> [ScanRecord] {
        records.filter { $0.plantTag == tag }.sorted { $0.date < $1.date }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder.orchard
        // Fast path: the whole array decodes cleanly.
        if let decoded = try? decoder.decode([ScanRecord].self, from: data) {
            records = decoded.sorted { $0.date > $1.date }
            return
        }
        // Salvage path: keep every record that still decodes, drop only the broken
        // ones (a schema change or a single corrupt entry no longer nukes history).
        if let salvaged = try? decoder.decode([FailableRecord].self, from: data) {
            records = salvaged.compactMap(\.record).sorted { $0.date > $1.date }
        }
    }

    /// Bumped on every mutation. Views key `.task(id:)` on this so derived output (CSV)
    /// refreshes after an in-place `update` too — `records.count` is unchanged by a
    /// confirm/correct edit, so counting alone missed those.
    private(set) var revision = 0

    private var saveGeneration = 0
    private func save() {
        revision += 1
        // Encode + write off the main actor (ScanDiskWriter serializes writes) so a
        // large record set with embedded JPEG thumbnails never blocks the UI. A
        // monotonic generation token lets the writer drop a stale snapshot — unstructured
        // Tasks are NOT guaranteed to resume in enqueue order, so without it a rapid
        // add→confirm could let the older array overwrite the newer one on disk.
        saveGeneration += 1
        let gen = saveGeneration
        let snapshot = records
        Task { [writer, fileURL] in
            do {
                try await writer.write(snapshot, to: fileURL, generation: gen)
                saveFailed = false
            } catch {
                saveFailed = true
                #if DEBUG
                print("OrchardEye: scan save failed — \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: CSV export (F4)

    func exportCSV() -> URL? {
        let header = ["date", "plant_tag", "variety", "crop", "subject", "disease", "confidence",
                      "is_healthy", "health_score", "chlorosis_pct", "lesion_pct",
                      "lifecycle_stage", "ripeness", "ripeness_score", "apple_count", "verdict", "risk", "urgency",
                      "recommendation", "weather_temp_c", "weather_humidity_pct", "user_confirmed"]
        let df = ISO8601DateFormatter()

        var lines = [header.joined(separator: ",")]
        for r in records.sorted(by: { $0.date < $1.date }) {
            // Blank the columns that don't apply to this scan's subject, so the CSV
            // doesn't carry the "not assessed / N/A" values the app suppresses.
            let assessDisease = !r.ripeness.fruit
            let showRipeness = !r.ripeness.foliage
            let subject = r.ripeness.fruit ? "fruit" : (r.ripeness.foliage ? "leaf" : "unknown")
            let row: [String] = [
                df.string(from: r.date),
                r.plantTag,
                r.variety.name,
                r.variety.crop.displayName,
                subject,
                assessDisease ? r.disease.name : "",
                assessDisease ? String(format: "%.2f", r.diseaseConfidence) : "",
                assessDisease ? (r.disease.isHealthy ? "yes" : "no") : "",
                assessDisease ? String(r.health.score) : "",
                assessDisease ? String(format: "%.1f", r.health.chlorosisPct) : "",
                assessDisease ? String(format: "%.1f", r.health.lesionPct) : "",
                assessDisease ? r.health.lifecycleStage : "",
                showRipeness ? r.ripeness.ripeness.rawValue : "",
                showRipeness ? String(format: "%.0f", r.ripeness.score) : "",
                r.ripeness.fruit ? String(r.appleCount) : "",
                r.verdict.rawValue,
                r.risk.rawValue,
                r.urgency.rawValue,
                r.recommendation,
                r.weather.map { String(format: "%.1f", $0.tempC) } ?? "",
                r.weather.map { String(format: "%.0f", $0.humidityPct) } ?? "",
                r.userConfirmed.map { $0 ? "confirmed" : "corrected" } ?? ""
            ]
            lines.append(row.map(Self.csvEscape).joined(separator: ","))
        }

        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("OrchardEye-scans.csv")
        do {
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func csvEscape(_ field: String) -> String {
        var f = field
        // Neutralize spreadsheet formula injection: a field a user typed (plant tag,
        // correction note) starting with = + - @ or a control char runs as a formula
        // when the CSV is opened in Excel / Sheets. Prefix with an apostrophe — but NOT
        // a legitimate negative number (e.g. a sub-zero temperature), which would then
        // import as text and break the column.
        if let first = f.first, "=+-@\t\r".contains(first), Double(f) == nil { f = "'" + f }
        if f.contains(",") || f.contains("\"") || f.contains("\n") || f.contains("\r") {
            return "\"" + f.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return f
    }
}

/// Serializes history writes off the main actor so encoding a large record set
/// (with embedded JPEG thumbnails) never blocks the UI.
private actor ScanDiskWriter {
    private var lastWritten = 0
    /// Serial, ordered writes. A snapshot older than one already written is dropped
    /// (out-of-order Task resumption can't clobber newer data). `lastWritten` advances
    /// only on success, so a failed write doesn't block a retry at the same generation.
    func write(_ records: [ScanRecord], to url: URL, generation: Int) throws {
        guard generation >= lastWritten else { return }
        let data = try JSONEncoder.orchard.encode(records)
        try data.write(to: url, options: .atomic)
        lastWritten = generation
    }
}

// MARK: - App model

@MainActor
@Observable
final class AppModel {
    // @Snapshotable
    var hasOnboarded: Bool
    var selectedVariety: Variety
    var currentWeather: WeatherSnapshot?

    let store = ScanStore()
    let voice = VoiceGuide()
    // The Simulator degrades Vision's scenePrint feature extractor, so the CreateML
    // model misclassifies there. Use the OS-independent colour model in the sim and
    // the higher-accuracy Core ML CNN on real hardware.
    #if targetEnvironment(simulator)
    let classifier: DiseaseClassifier = ColorDiseaseClassifier()
    #else
    let classifier: DiseaseClassifier = CoreMLDiseaseClassifier()
    #endif
    let weatherProvider = WeatherProvider()

    private let onboardKey = "hasOnboarded"
    private let varietyKey = "selectedVariety"

    init() {
        let d = UserDefaults.standard
        hasOnboarded = d.bool(forKey: onboardKey)
        if let data = d.data(forKey: varietyKey),
           let v = try? JSONDecoder().decode(Variety.self, from: data) {
            selectedVariety = v
        } else {
            selectedVariety = .default
        }
    }

    func completeOnboarding(variety: Variety) {
        selectedVariety = variety
        hasOnboarded = true
        persist()
    }

    func setVariety(_ v: Variety) {
        selectedVariety = v
        persist()
    }

    func resetOnboarding() {
        hasOnboarded = false
        persist()
    }

    func refreshWeather() async {
        currentWeather = await weatherProvider.current()
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(hasOnboarded, forKey: onboardKey)
        if let data = try? JSONEncoder().encode(selectedVariety) {
            d.set(data, forKey: varietyKey)
        }
    }
}
