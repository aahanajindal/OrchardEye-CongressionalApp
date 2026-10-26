//
//  CoreMLDiseaseClassifier.swift
//  OrchardEye
//
//  Stage 4 (vision head), real path. Runs the on-device apple / plant detector as a
//  subject gate, then a Core ML disease model when one is bundled. With no trained
//  model present it degrades to the same honest image-stat heuristic classifier —
//  so the app runs today and sharpens the moment a `.mlmodelc` is dropped in.
//
//  Drop-in: export a PlantVillage-style apple classifier to Core ML and add
//  `AppleDiseaseClassifier.mlmodelc` / `.mlpackage` (Xcode compiles `.mlmodel`) to the
//  app bundle. Output labels are matched fuzzily — e.g. "Apple___Apple_scab",
//  "Black rot", "Cedar apple rust", "Apple___healthy".
//

import Vision
import CoreML
import UIKit

final class CoreMLDiseaseClassifier: DiseaseClassifier {

    /// Compiled-model names searched for in the app bundle.
    private static let modelNames = ["AppleDiseaseClassifier", "PlantDisease", "OrchardEyeDisease"]

    private let vnModel: VNCoreMLModel? = CoreMLDiseaseClassifier.loadModel()
    private let heuristic = HeuristicDiseaseClassifier()

    /// True when a real trained Core ML disease model was found and loaded.
    var usingRealModel: Bool { vnModel != nil }

    func classify(image: UIImage, crop: Crop) async -> DiseaseClassification {
        // 1) Subject gate — built-in Vision classifier (weak; unreliable on tight
        //    leaf close-ups, and differs between OS versions).
        var detection = await AppleDetector.detect(image)

        // 2) Disease head: trained Core ML model if bundled, else honest heuristic.
        var result: DiseaseClassification
        if let vnModel, let cg = image.cgImage,
           let ml = await runCoreML(vnModel, cg: cg, image: image, crop: crop) {
            result = ml
        } else {
            result = await heuristic.classify(image: image, crop: crop)
        }

        // 3) Subject gate — colour-based apple leaf/fruit plausibility, authoritative and
        //    Simulator-safe. Neither the trained head nor the colour head has a
        //    "not-apple" class, so a confident disease result is NOT subject evidence
        //    (that hallucinated "leaf detected" on non-apple frames). Vision's own apple
        //    hit can still confirm. A rejected frame gets its confidence capped so no
        //    verdict is claimed on a wall / screen / building.
        let stats = ImageAnalysis.stats(for: image)
        let subjectOK = ImageAnalysis.appleSubjectValid(stats) || detection.isApple
        if !subjectOK {
            detection = .none
            result.confidence = min(result.confidence, 0.35)
        } else if !detection.subjectValid {
            detection = detection.confirming(label: "\(crop.displayName.lowercased()) leaf/fruit",
                                             confidence: max(detection.confidence, usingRealModel ? result.confidence : 0.6))
        }
        result.detection = detection
        return result
    }

    // MARK: Core ML inference

    private func runCoreML(_ model: VNCoreMLModel, cg: CGImage,
                           image: UIImage, crop: Crop) async -> DiseaseClassification? {
        let label: (id: String, conf: Double)? = await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let req = VNCoreMLRequest(model: model)
                req.imageCropAndScaleOption = .centerCrop
                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                do {
                    try handler.perform([req])
                    if let top = (req.results as? [VNClassificationObservation])?
                        .max(by: { $0.confidence < $1.confidence }) {
                        cont.resume(returning: (top.identifier, Double(top.confidence)))
                    } else {
                        cont.resume(returning: nil)
                    }
                } catch { cont.resume(returning: nil) }
            }
        }
        guard let label else { return nil }

        let disease = Self.map(label: label.id, crop: crop)
        // Real crop-health signals from a single image pass (no second classify /
        // no artificial heuristic latency on the model path).
        let health = HeuristicDiseaseClassifier.cropHealth(from: ImageAnalysis.stats(for: image), crop: crop)
        let candidates = DiseaseInfo.candidates(for: crop)
        let alts = Array(candidates.filter { $0 != disease }.map { $0.name }.prefix(2))

        return DiseaseClassification(
            disease: disease,
            confidence: label.conf,
            alternatives: disease.isHealthy ? [] : alts,
            health: health)
    }

    // MARK: Label → DiseaseInfo

    static func map(label raw: String, crop: Crop) -> DiseaseInfo {
        let l = raw.lowercased().replacingOccurrences(of: "_", with: " ")
        if l.contains("healthy") || l.contains("normal")   { return .healthy }
        if l.contains("scab")                              { return .appleScab }
        if l.contains("black") && l.contains("rot")        { return .appleBlackRot }
        if l.contains("rust")                              { return .appleRust }
        if l.contains("fire") && l.contains("blight")      { return .fireBlight }
        // Closest candidate-name match, else assume healthy.
        let candidates = DiseaseInfo.candidates(for: crop)
        if let hit = candidates.first(where: { l.contains($0.name.lowercased()) }) { return hit }
        return .healthy
    }

    // MARK: Model loading

    private static func loadModel() -> VNCoreMLModel? {
        let cfg = MLModelConfiguration()
        cfg.computeUnits = .all
        for name in modelNames {
            for ext in ["mlmodelc", "mlpackage"] {
                if let url = Bundle.main.url(forResource: name, withExtension: ext),
                   let ml = try? MLModel(contentsOf: url, configuration: cfg),
                   let vn = try? VNCoreMLModel(for: ml) {
                    return vn
                }
            }
        }
        return nil
    }
}
