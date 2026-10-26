//
//  TrendsView.swift
//  OrchardEye
//
//  F6 — per-plant trends. Health-over-time, lesion %, and ripeness curve, plus a
//  "flagged / spreading" banner from the trend analyzer.
//

import SwiftUI
import Charts

struct TrendsView: View {
    @Environment(ScanStore.self) private var store
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var selectedTag: String?

    /// Charts pair up on regular width, stack on compact.
    private var chartColumns: [GridItem] {
        hSize == .regular ? [GridItem(.flexible(), spacing: 16, alignment: .top),
                             GridItem(.flexible(), alignment: .top)]
                          : [GridItem(.flexible())]
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.plantTags.isEmpty {
                    ContentUnavailableView("No trends yet", systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Scan the same plant or block more than once to chart its trend."))
                } else {
                    content
                }
            }
            .navigationTitle("Trends")
        }
    }

    private var content: some View {
        // Drop a stale selection whose plant was fully deleted, else the Picker shows blank.
        let tag = selectedTag.flatMap { store.plantTags.contains($0) ? $0 : nil }
            ?? store.plantTags.first ?? ""
        let summary = TrendAnalyzer.summary(for: tag, in: store.records)

        return ScrollView {
            VStack(spacing: 16) {
                Picker("Plant", selection: Binding(get: { tag }, set: { selectedTag = $0 })) {
                    ForEach(store.plantTags, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)

                statusCard(summary)

                if summary.points.count < 2 {
                    Card {
                        Text("Only one scan so far for \(tag). Scan it again later to see a trend.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    // Disease charts use only leaf scans; ripeness uses only fruit
                    // scans — so a mixed history never plots meaningless series.
                    LazyVGrid(columns: chartColumns, spacing: 16) {
                        if summary.points.filter({ $0.diseaseAssessed }).count >= 2 {
                            chartCard(title: "Health score", points: summary.points.filter { $0.diseaseAssessed },
                                      value: { Double($0.healthScore) }, unit: "", domain: 0...100, tint: .green)
                            chartCard(title: "Lesion area (%)", points: summary.points.filter { $0.diseaseAssessed },
                                      value: { $0.lesionPct }, unit: "%", domain: 0...100, tint: .red)
                        }
                        if summary.points.filter({ $0.ripenessApplies }).count >= 2 {
                            chartCard(title: "Ripeness score", points: summary.points.filter { $0.ripenessApplies },
                                      value: { $0.ripenessScore }, unit: "", domain: 0...100, tint: .accentColor)
                        }
                    }
                }
            }
            .readableColumn(max: hSize == .regular ? 940 : 700)
            .padding()
        }
    }

    private func statusCard(_ summary: TrendSummary) -> some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: summary.flagged ? "exclamationmark.triangle.fill" : icon(summary.direction))
                    .font(.title2)
                    .foregroundStyle(summary.flagged ? Color.red : color(summary.direction))
                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.flagged ? "Flagged: appears to be spreading" : "Trend: \(summary.direction.rawValue)")
                        .font(.headline)
                    Text("Spread index \(String(format: "%.2f", summary.spreadIndex)) · \(summary.points.count) scans")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func chartCard(title: String, points: [TrendPoint],
                           value: @escaping (TrendPoint) -> Double, unit: String,
                           domain: ClosedRange<Double>, tint: Color) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Chart(points) { p in
                    LineMark(x: .value("Date", p.date),
                             y: .value(title, value(p)))
                        .foregroundStyle(tint)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", p.date),
                              y: .value(title, value(p)))
                        .foregroundStyle(tint)
                }
                .chartYScale(domain: domain)
                .frame(height: hSize == .regular ? 230 : 150)
            }
        }
    }

    private func icon(_ d: TrendDirection) -> String {
        switch d {
        case .improving: return "arrow.up.right.circle.fill"
        case .stable:    return "equal.circle.fill"
        case .worsening: return "arrow.down.right.circle.fill"
        }
    }
    private func color(_ d: TrendDirection) -> Color {
        switch d {
        case .improving: return .green
        case .stable:    return .secondary
        case .worsening: return .red
        }
    }
}
