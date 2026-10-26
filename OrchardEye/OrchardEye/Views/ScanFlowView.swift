//
//  ScanFlowView.swift
//  OrchardEye
//
//  The end-to-end scan: capture → quality gate → disease + health + ripeness
//  (all on-device) → fused verdict. Drives ScanViewModel.
//

import SwiftUI
import Observation
import PhotosUI
import UIKit
import AVFoundation

@MainActor
@Observable
final class ScanViewModel {
    enum Step: Equatable { case capture, qualityFail, disease, verdict }

    var step: Step = .capture
    var image: UIImage?
    // @Snapshotable
    var qualityIssues: [String] = []
    var classification: DiseaseClassification?
    var ripeness: RipenessReading?
    var fusion: FusionResult?
    // @Snapshotable
    var isWorking: Bool = false
    // @Snapshotable
    var statusText: String = ""
    // @Snapshotable
    var plantTag: String = "Block 1"
    var savedRecordID: UUID?
    // @Snapshotable
    var reviewNote: String = ""

    // @Snapshotable
    var appleCount: Int = 0

    func reset() {
        step = .capture; image = nil; qualityIssues = []
        classification = nil; ripeness = nil; fusion = nil; appleCount = 0
        isWorking = false; statusText = ""; savedRecordID = nil; reviewNote = ""
    }

    private var scanTask: Task<Void, Never>?

    func useImage(_ img: UIImage, app: AppModel) {
        // Single-flight: cancel any in-flight scan and set isWorking synchronously so
        // the capture UI's .disabled(isWorking) blocks a second scan immediately (the
        // old code set it inside the async Task, leaving a re-entrancy window that
        // interleaved two scans' @Published state).
        scanTask?.cancel()
        isWorking = true
        statusText = "Analyzing on device…"
        scanTask = Task { await run(img, app: app) }
    }

    func retake() {
        scanTask?.cancel()
        image = nil; qualityIssues = []
        withAnimation { step = .capture }
    }

    /// Full scan pipeline. Normalize, quality-gate, classify, ripeness and apple-count
    /// all run OFF the main actor via the nonisolated helpers below; only @Published
    /// state assignment happens here on the main actor — so a full-resolution camera
    /// photo never freezes the UI mid-scan.
    private func run(_ img: UIImage, app: AppModel) async {
        let prepared = await Self.prepare(img)
        if Task.isCancelled { isWorking = false; return }
        image = prepared.image
        guard prepared.passed else {
            qualityIssues = prepared.issues
            isWorking = false
            withAnimation { step = .qualityFail }
            return
        }
        let crop = app.selectedVariety.crop
        let out = await Self.analyze(prepared.image, crop: crop, classifier: app.classifier)
        if Task.isCancelled { isWorking = false; return }
        classification = out.disease
        ripeness = out.ripeness
        appleCount = out.appleCount
        isWorking = false
        withAnimation { step = .disease }
    }

    // Camera / library photos arrive rotated (orientation flag, not pixels). Normalize
    // once so the quality gate, detector and model all see upright pixels. nonisolated
    // → executes off the main actor.
    // Task.detached forces the synchronous pixel work OFF the main actor. A plain
    // nonisolated async func would still run its pre-first-await body on the caller's
    // executor (the main actor here), so `normalizedUp()` + quality gate would have
    // janked the UI despite the `nonisolated` keyword.
    nonisolated private static func prepare(_ img: UIImage) async
        -> (image: UIImage, passed: Bool, issues: [String]) {
        await Task.detached(priority: .userInitiated) {
            let fixed = img.normalizedUp()
            let q = ImageQualityGate.check(fixed)
            return (fixed, q.passed, q.issues)
        }.value
    }

    // One image pass powers both answers: disease (Core ML) + ripeness (colour).
    nonisolated private static func analyze(_ img: UIImage, crop: Crop, classifier: DiseaseClassifier) async
        -> (disease: DiseaseClassification, ripeness: RipenessReading, appleCount: Int) {
        let c = await classifier.classify(image: img, crop: crop)
        return await Task.detached(priority: .userInitiated) {
            var r = RipenessEstimator.estimate(from: ImageAnalysis.stats(for: img), crop: crop)
            // Subject gate is authoritative over ripeness too. Ripeness/fruit is computed
            // from warm colour alone, so a warm non-apple (dog fur, skin, a jersey) was
            // triggering "Fruit detected · N apples". If the subject gate rejected the
            // frame, there is no apple — zero fruit/foliage so nothing downstream claims one.
            if !(c.detection?.subjectValid ?? false) {
                r.fruit = false
                r.foliage = false
            }
            let count = r.fruit ? AppleCounter.count(img) : 0
            return (c, r, count)
        }.value
    }

    func fuse(app: AppModel) async {
        guard let c = classification, let r = ripeness else { return }
        let trend = TrendAnalyzer.summary(for: plantTag, in: app.store.records)
        fusion = FusionEngine.fuse(disease: c, ripeness: r, weather: app.currentWeather,
                                   priorTrend: trend, variety: app.selectedVariety)
        withAnimation { step = .verdict }
    }

    func makeRecord(app: AppModel, confirmed: Bool?) -> ScanRecord? {
        guard let c = classification, let r = ripeness, let f = fusion else { return nil }
        // Don't persist a non-apple mis-scan — it would pollute History, CSV and trends.
        guard (c.detection?.subjectValid ?? false) || r.fruit else { return nil }
        // Trim so "Block 1", "block 1 " etc. don't fragment a plant's trend history.
        let tag = plantTag.trimmingCharacters(in: .whitespacesAndNewlines)
        return ScanRecord(
            plantTag: tag.isEmpty ? "Unlabeled" : tag,
            variety: app.selectedVariety,
            imageData: image.flatMap { ImageAnalysis.thumbnailJPEG($0) },
            disease: c.disease,
            diseaseConfidence: c.confidence,
            alternatives: c.alternatives,
            health: c.health,
            ripeness: r,
            appleCount: appleCount,
            verdict: f.verdict,
            verdictTitle: f.title,
            recommendation: f.recommendation,
            risk: f.risk,
            urgency: f.urgency,
            weather: app.currentWeather,
            userConfirmed: confirmed,
            userCorrectionNote: (confirmed == false && !reviewNote.isEmpty) ? reviewNote : nil)
    }

    func save(app: AppModel, confirmed: Bool?) {
        if let id = savedRecordID, var existing = app.store.records.first(where: { $0.id == id }) {
            existing.userConfirmed = confirmed
            if confirmed == false && !reviewNote.isEmpty { existing.userCorrectionNote = reviewNote }
            app.store.update(existing)
            return
        }
        if let rec = makeRecord(app: app, confirmed: confirmed) {
            app.store.add(rec)
            savedRecordID = rec.id
        }
    }
}

struct ScanFlowView: View {
    @Environment(AppModel.self) private var app
    @Environment(ScanStore.self) private var store
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var vm = ScanViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showCameraDenied = false
    @State private var showPhotoError = false

    /// Hero photo height: taller on regular-width (iPad / landscape) layouts.
    private var photoHeight: CGFloat { hSize == .regular ? 340 : 190 }

    /// Result cards flow into two columns on regular width, one on compact.
    private var resultColumns: [GridItem] {
        hSize == .regular ? [GridItem(.flexible(), spacing: 16, alignment: .top),
                             GridItem(.flexible(), alignment: .top)]
                          : [GridItem(.flexible())]
    }
    private var columnCap: CGFloat { hSize == .regular ? 940 : 660 }

    var body: some View {
        @Bindable var store = store   // local bindable for $store.saveFailed alert
        return NavigationStack {
            ZStack {
                content
                if vm.isWorking { workingOverlay }
            }
            .navigationTitle("OrchardEye")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(trigger: vm.step) { _, new in Self.feedback(for: new) }
            .toolbar {
                if vm.step != .capture {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New") { withAnimation { vm.reset() } }
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker { img in
                    showCamera = false
                    vm.useImage(img, app: app)
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task { @MainActor in
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        vm.useImage(img, app: app)
                    } else {
                        // iCloud-optimized asset failed to download, or unreadable.
                        showPhotoError = true
                    }
                    photoItem = nil
                }
            }
            .alert("Camera access needed", isPresented: $showCameraDenied) {
                Button("Open Settings") {
                    if let u = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(u)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable camera access in Settings to photograph a leaf or fruit. You can still choose a saved photo instead.")
            }
            .alert("Couldn't load photo", isPresented: $showPhotoError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("That photo couldn't be opened. If it's stored in iCloud, wait for it to download and try again.")
            }
            .alert("Couldn't save scan", isPresented: $store.saveFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your device storage may be full — the scan wasn't saved to history.")
            }
        }
    }

    /// Disease card whose headline matches the verdict's flag decision exactly —
    /// a disease name is only asserted when `flagged`; low-confidence reads as
    /// "Possible …", so the card can never contradict a green verdict banner.
    private func diseaseCard(_ c: DiseaseClassification) -> some View {
        let state = diseaseState(isHealthy: c.disease.isHealthy, confidence: c.confidence,
                                 lesionPct: c.health.lesionPct, assessable: true)
        let emoji = state == .flagged ? "🔴" : (state == .suspected ? "🟡" : "🟢")
        let headline = state == .flagged ? c.disease.name
            : state == .suspected ? "Possible \(c.disease.name)"
            : "Healthy — no disease"
        let tint: Color = state == .flagged ? .red : (state == .suspected ? .orange : .green)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text(emoji).accessibilityHidden(true); Text(headline).font(.headline) }
                Text(state == .clear ? DiseaseInfo.healthy.summary : c.disease.summary)
                    .font(.subheadline).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text("Confidence"); Spacer(); Text("\(Int(c.confidence * 100))%") }.font(.caption)
                    ConfidenceBar(value: c.confidence, tint: tint)
                }
                if state == .suspected && !c.alternatives.isEmpty {
                    Text("Also possible: \(c.alternatives.joined(separator: ", "))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Gate the camera behind an authorization check so a denied permission shows a
    /// route to Settings instead of a black frame / silent dead-end.
    private func requestCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { showCamera = true } else { showCameraDenied = true }
                }
            }
        default:
            showCameraDenied = true
        }
    }

    /// Haptic cue for entering a step: a soft success at the verdict, a warning
    /// when the image quality gate asks for a retake.
    private static func feedback(for step: ScanViewModel.Step) -> SensoryFeedback? {
        switch step {
        case .verdict:     return .success
        case .qualityFail: return .warning
        default:           return nil
        }
    }

    @ViewBuilder private var content: some View {
        switch vm.step {
        case .capture:     captureStep
        case .qualityFail: qualityFailStep
        case .disease:     diseaseStep
        case .verdict:     VerdictView(vm: vm, voice: app.voice)
        }
    }

    // MARK: Capture

    private var captureStep: some View {
        @Bindable var vm = vm   // local bindable for $vm.plantTag TextField
        return ScrollView {
            VStack(spacing: 16) {
                headerCard
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("New scan").font(.headline)
                        HStack {
                            Text("Plant / block").foregroundStyle(.secondary)
                            Spacer()
                            TextField("Label", text: $vm.plantTag)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 170)
                        }
                        .font(.subheadline)
                        Divider()
                        Text("Photograph a leaf or fruit")
                            .font(.subheadline).foregroundStyle(.secondary)

                        if CameraPicker.isAvailable {
                            Button { requestCamera() } label: {
                                Label("Take photo", systemImage: "camera.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }

                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Choose photo", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)   // primary capture path (esp. in Simulator)
                        .controlSize(.large)
                        .tint(CameraPicker.isAvailable ? .gray : .accentColor)

                        HStack {
                            Button { vm.useImage(ImageAnalysis.sampleLeaf(healthy: true), app: app) } label: {
                                Text("Example: healthy leaf").frame(maxWidth: .infinity)
                            }.buttonStyle(.bordered)
                            Button { vm.useImage(ImageAnalysis.sampleLeaf(healthy: false), app: app) } label: {
                                Text("Example: diseased leaf").frame(maxWidth: .infinity)
                            }.buttonStyle(.bordered)
                        }

                        Text("No camera handy? Load an example leaf image — it runs through the exact same on-device analysis as your own photos.")
                            .font(.footnote).foregroundStyle(.tertiary)
                    }
                    .disabled(vm.isWorking)   // no re-entrant scan while one's in flight
                }
            }
            .readableColumn()
            .padding()
        }
    }

    private var headerCard: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(app.selectedVariety.crop.emoji)  \(app.selectedVariety.name)")
                        .font(.headline)
                    Text(app.selectedVariety.crop.displayName).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let w = app.currentWeather {
                    VStack(alignment: .trailing, spacing: 4) {
                        Label(w.summary, systemImage: "cloud.sun")
                            .font(.caption).foregroundStyle(.secondary)
                            .labelStyle(.titleAndIcon)
                        Text("disease risk: \(w.diseasePressure)").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: Quality fail

    private var qualityFailStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50)).foregroundStyle(Color.orange)
            Text("Let's retake that").font(.title2.bold())
            VStack(alignment: .leading, spacing: 10) {
                ForEach(vm.qualityIssues, id: \.self) { issue in
                    Label(issue, systemImage: "arrow.right.circle")
                }
            }
            .font(.subheadline)
            Button { vm.retake() } label: {
                Text("Retake").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .readableColumn(max: 480)
        .padding()
    }

    // MARK: Disease result

    private var diseaseStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let img = vm.image {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(height: photoHeight).frame(maxWidth: .infinity).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("The photo you scanned")
                }
                LazyVGrid(columns: resultColumns, spacing: 16) {
                if !(vm.ripeness?.fruit ?? false), let d = vm.classification?.detection {
                    Card {
                        HStack(spacing: 10) {
                            Image(systemName: d.subjectValid ? "checkmark.seal.fill" : "questionmark.diamond.fill")
                                .foregroundStyle(d.subjectValid ? .green : .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.isApple ? "Apple leaf detected"
                                     : d.subjectValid ? "Leaf detected"
                                     : "No apple or leaf clearly detected")
                                    .font(.subheadline).fontWeight(.medium)
                                Text(d.isApple ? "On-device Core ML · apple confirmed"
                                     : d.subjectValid ? "On-device Core ML · leaf/fruit confirmed"
                                     : "On-device Core ML · point at a leaf or fruit")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                if let c = vm.classification {
                    let hasSubject = c.detection?.subjectValid ?? false
                    if vm.ripeness?.fruit == true {
                        Card {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("🍎").accessibilityHidden(true); Text("Fruit detected").font(.headline)
                                    Spacer()
                                    if vm.appleCount > 0 {
                                        Text("~\(vm.appleCount) apple\(vm.appleCount == 1 ? "" : "s")")
                                            .font(.subheadline.weight(.semibold)).foregroundStyle(Color.accentColor)
                                    }
                                }
                                Text("Disease screening needs a leaf photo — showing ripeness only.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    } else if !hasSubject {
                        Card {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "questionmark.diamond.fill")
                                        .foregroundStyle(.orange)
                                    Text("No apple leaf or fruit").font(.headline)
                                }
                                Text("This doesn't look like an apple leaf or an apple, so no disease reading was made. Point the camera at an apple leaf or fruit and scan again.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        diseaseCard(c)
                        Card {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Crop health").font(.headline)
                                HStack {
                                    Text("Score").foregroundStyle(.secondary); Spacer()
                                    Text("\(c.health.score)/100")
                                        .foregroundStyle(c.health.scoreColor).fontWeight(.semibold)
                                }.font(.subheadline)
                                InfoRow(label: "Lesion area", value: String(format: "%.0f%%", c.health.lesionPct))
                                InfoRow(label: "Yellowing", value: String(format: "%.0f%%", c.health.chlorosisPct))
                                InfoRow(label: "Lifecycle stage", value: c.health.lifecycleStage)
                            }
                        }
                    }
                    if hasSubject, let r = vm.ripeness {
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
                                    Text("Estimated on device from fruit colour — no external sensor.")
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
                }
                if let c = vm.classification, (c.detection?.subjectValid ?? false) || vm.ripeness?.fruit == true {
                    Button { Task { await vm.fuse(app: app) } } label: {
                        Label("See verdict", systemImage: "arrow.right").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(vm.isWorking)
                }
            }
            .readableColumn(max: columnCap)
            .padding()
        }
    }

    // MARK: Working overlay

    private var workingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                Text(vm.statusText).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    ScanFlowView().environment(AppModel()).environment(AppModel().store)
}
