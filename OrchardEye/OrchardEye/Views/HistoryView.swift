//
//  HistoryView.swift
//  OrchardEye
//
//  F4 — saved scans, detail, and CSV export (share sheet).
//

import SwiftUI
import UIKit

struct HistoryView: View {
    @Environment(ScanStore.self) private var store
    @State private var csvURL: URL?
    @State private var selection: UUID?

    var body: some View {
        // Split view: list + detail side by side on iPad, push navigation on iPhone.
        NavigationSplitView {
            Group {
                if store.records.isEmpty {
                    ContentUnavailableView("No scans yet", systemImage: "leaf",
                        description: Text("Saved scans will appear here. Try a scan to get started."))
                } else {
                    List(selection: $selection) {
                        ForEach(store.records) { record in
                            row(record).tag(record.id)
                        }
                        .onDelete { offsets in
                            let deletedIDs = Set(offsets.map { store.records[$0].id })
                            store.delete(at: offsets)
                            if let sel = selection, deletedIDs.contains(sel) { selection = nil }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !store.records.isEmpty, let url = csvURL {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Export scans as CSV")
                    }
                }
            }
            .task(id: store.revision) {
                csvURL = store.exportCSV()
            }
        } detail: {
            if let id = selection, let record = store.records.first(where: { $0.id == id }) {
                ScanDetailView(record: record)
            } else {
                ContentUnavailableView("Select a scan", systemImage: "leaf",
                    description: Text("Pick a saved scan to see its full verdict."))
            }
        }
    }

    private func row(_ record: ScanRecord) -> some View {
        HStack(spacing: 12) {
            thumbnail(record)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.plantTag).font(.subheadline.weight(.semibold))
                Text(record.verdictTitle.isEmpty ? record.disease.name : record.verdictTitle)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text(record.date, format: .dateTime.month().day().hour().minute())
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            Text(record.verdict.emoji).accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func thumbnail(_ record: ScanRecord) -> some View {
        if let data = record.imageData, let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill))
                .frame(width: 46, height: 46)
                .overlay(Image(systemName: "leaf").foregroundStyle(.secondary))
        }
    }
}

struct ScanDetailView: View {
    let record: ScanRecord
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let data = record.imageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(height: hSize == .regular ? 340 : 200).frame(maxWidth: .infinity).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                HStack {
                    Text(record.verdict.emoji).font(.title)
                    Text(record.verdictTitle.isEmpty ? record.verdict.title : record.verdictTitle)
                        .font(.title3.bold())
                    Spacer()
                    Pill(text: record.urgency.displayName, color: record.urgency.color)
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recommendation").font(.headline)
                        Text(record.recommendation)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Readings").font(.headline)
                        InfoRow(label: "Disease",
                                value: diseaseDisplayName(isHealthy: record.disease.isHealthy, name: record.disease.name,
                                                          confidence: record.diseaseConfidence, lesionPct: record.health.lesionPct,
                                                          assessable: !record.ripeness.fruit))
                        if !record.ripeness.fruit {
                            InfoRow(label: "Confidence", value: "\(Int(record.diseaseConfidence * 100))%")
                            InfoRow(label: "Health score", value: "\(record.health.score)/100")
                            InfoRow(label: "Lesion area", value: String(format: "%.0f%%", record.health.lesionPct))
                        }
                        InfoRow(label: "Ripeness",
                                value: record.ripeness.foliage ? "N/A (leaf)" : record.ripeness.ripeness.displayName)
                        if !record.ripeness.foliage {
                            InfoRow(label: "Ripeness score", value: "\(Int(record.ripeness.score))/100")
                        }
                        if record.ripeness.fruit && record.appleCount > 0 {
                            InfoRow(label: "Apples (approx)", value: "~\(record.appleCount)")
                        }
                        InfoRow(label: "Risk", value: record.risk.displayName)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Context").font(.headline)
                        InfoRow(label: "Plant / block", value: record.plantTag)
                        InfoRow(label: "Variety", value: record.variety.displayName)
                        InfoRow(label: "Date", value: record.date.formatted(date: .abbreviated, time: .shortened))
                        if let w = record.weather { InfoRow(label: "Weather", value: w.summary) }
                        if let confirmed = record.userConfirmed {
                            InfoRow(label: "Review", value: confirmed ? "Confirmed" : "Corrected")
                        }
                        if let note = record.userCorrectionNote {
                            InfoRow(label: "Note", value: note)
                        }
                    }
                }

                if !record.ripeness.foliage {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ripeness").font(.headline)
                            RipenessMeter(score: record.ripeness.score, tint: record.ripeness.ripeness.color)
                        }
                    }
                }
            }
            .readableColumn()
            .padding()
        }
        .navigationTitle(record.plantTag)
        .navigationBarTitleDisplayMode(.inline)
    }
}
