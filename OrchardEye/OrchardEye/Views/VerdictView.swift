//
//  VerdictView.swift
//  OrchardEye
//
//  Stage 6: the single fused verdict (F3), spoken aloud (A4), saved to history,
//  and confirmed/corrected by the grower (F7).
//

import SwiftUI

struct VerdictView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var hSize
    @Bindable var vm: ScanViewModel
    @ObservedObject var voice: VoiceGuide

    @State private var showCorrect = false
    @State private var reviewState = 0   // 0 none · 1 confirmed · 2 corrected

    /// Cards pair up on regular width, stack on compact.
    private var cardColumns: [GridItem] {
        hSize == .regular ? [GridItem(.flexible(), spacing: 16, alignment: .top),
                             GridItem(.flexible(), alignment: .top)]
                          : [GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            if let f = vm.fusion {
                VStack(spacing: 16) {
                    banner(f)
                    recommendationCard(f)
                    LazyVGrid(columns: cardColumns, spacing: 16) {
                        qualityCard
                        detailsCard(f)
                    }
                    reviewCard
                    Button { withAnimation { vm.reset() } } label: {
                        Label("New scan", systemImage: "plus.viewfinder").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                }
                .readableColumn(max: hSize == .regular ? 940 : 660)
                .padding()
            }
        }
        .onAppear {
            if vm.savedRecordID == nil { vm.save(app: app, confirmed: nil) }
        }
        .sensoryFeedback(.success, trigger: reviewState) { _, new in new != 0 }
        .sheet(isPresented: $showCorrect) { correctionSheet }
    }

    // MARK: Banner

    private func banner(_ f: FusionResult) -> some View {
        VStack(spacing: 8) {
            Text(f.verdict.emoji).font(.system(size: 44))
                .accessibilityHidden(true)
            Text(f.title).font(.title.bold()).foregroundStyle(.white)
            HStack(spacing: 8) {
                bannerPill(f.risk.displayName)
                bannerPill(f.urgency.displayName)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LinearGradient(colors: f.verdict.bannerColors,
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(f.title). \(f.risk.displayName). \(f.urgency.displayName).")
    }

    /// High-contrast chip for the coloured banner: white text on a dark scrim
    /// reads on every verdict colour (the old white-on-white pill washed out).
    private func bannerPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.black.opacity(0.22), in: Capsule())
            .foregroundStyle(.white)
    }

    // MARK: Recommendation + voice

    private func recommendationCard(_ f: FusionResult) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("What to do").font(.headline)
                Text(f.recommendation).font(.body)
                Button {
                    if voice.isSpeaking { voice.stop() } else { voice.speak(f.spoken) }
                } label: {
                    Label(voice.isSpeaking ? "Stop" : "Hear it",
                          systemImage: voice.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    // MARK: Quality

    @ViewBuilder private var qualityCard: some View {
        if let r = vm.ripeness {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Ripeness").font(.headline)
                        Spacer()
                        if !r.foliage { Pill(text: r.ripeness.displayName, color: r.ripeness.color) }
                    }
                    if r.foliage {
                        Text("N/A — this looks like a leaf. Ripeness is measured on the fruit.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        RipenessMeter(score: r.score, tint: r.ripeness.color)
                        Text("On-device colour estimate · no external sensor")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: Details

    private func detailsCard(_ f: FusionResult) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Details").font(.headline)
                if let c = vm.classification {
                    InfoRow(label: "Disease",
                            value: diseaseDisplayName(isHealthy: c.disease.isHealthy, name: c.disease.name,
                                                      confidence: c.confidence, lesionPct: c.health.lesionPct,
                                                      assessable: f.showDisease))
                    if f.showDisease {
                        InfoRow(label: "Confidence", value: "\(Int(c.confidence * 100))%")
                        InfoRow(label: "Health score", value: "\(c.health.score)/100")
                    }
                }
                if !f.showDisease && vm.appleCount > 0 {
                    InfoRow(label: "Apples (approx)", value: "~\(vm.appleCount)")
                }
                InfoRow(label: "Plant / block",
                        value: vm.plantTag.trimmingCharacters(in: .whitespacesAndNewlines))
                InfoRow(label: "Variety", value: app.selectedVariety.displayName)
                if let w = app.currentWeather {
                    InfoRow(label: "Weather", value: w.summary)
                }
            }
        }
    }

    // MARK: Review (F7)

    private var reviewCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Was this right?").font(.headline)
                Text("Your feedback trains OrchardEye for your orchard and varieties.")
                    .font(.caption).foregroundStyle(.secondary)
                if reviewState == 0 {
                    HStack {
                        Button {
                            vm.save(app: app, confirmed: true)
                            reviewState = 1
                        } label: {
                            Label("Confirm", systemImage: "checkmark.circle").frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered).tint(.green)
                        Button {
                            showCorrect = true
                        } label: {
                            Label("Correct", systemImage: "pencil").frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered).tint(.orange)
                    }
                } else {
                    Label(reviewState == 1 ? "Thanks, confirmed and saved." : "Thanks, correction saved.",
                          systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green).font(.subheadline)
                }
            }
        }
    }

    private var correctionSheet: some View {
        NavigationStack {
            Form {
                Section("What was it actually?") {
                    TextField("e.g. this was sunburn, not scab", text: $vm.reviewNote, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section {
                    Text("Logged locally as community knowledge. Corrections are the highest-value training signal.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Correct verdict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCorrect = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.save(app: app, confirmed: false)
                        reviewState = 2
                        showCorrect = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
