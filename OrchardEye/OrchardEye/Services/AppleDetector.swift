//
//  AppleDetector.swift
//  OrchardEye
//
//  Stage 3.5 (subject gate). Real on-device Core ML apple / plant detection using
//  Vision's built-in image classifier (`VNClassifyImageRequest`) — a Core ML model
//  Apple ships in the OS, so this runs TODAY with no bundled model file. Confirms
//  the frame actually contains an apple / fruit / leaf before the disease head runs.
//

import Vision
import UIKit

/// What the on-device classifier saw in the frame.
struct AppleDetection: Hashable {
    var isApple: Bool          // an apple / crabapple is present
    var isPlant: Bool          // leaf / foliage / tree / fruit — a valid scan subject
    var topLabel: String       // best-matching subject label
    var confidence: Double     // 0–1 confidence for `topLabel`
    var labels: [String]       // top matches ("label 87%") for debugging / UI

    /// True when the frame holds something worth running the disease head on.
    var subjectValid: Bool { isApple || isPlant }

    static let none = AppleDetection(isApple: false, isPlant: false,
                                     topLabel: "nothing recognized", confidence: 0, labels: [])

    /// Promote to a valid subject when a downstream model vouches for the frame.
    func confirming(label: String, confidence: Double) -> AppleDetection {
        AppleDetection(isApple: isApple,
                       isPlant: true,
                       topLabel: topLabel == "nothing recognized" ? label : topLabel,
                       confidence: max(self.confidence, confidence),
                       labels: labels)
    }
}

enum AppleDetector {

    // Vision taxonomy identifiers grouped by what they mean for us.
    private static let appleTerms = ["apple", "crabapple"]
    // Vision has no apple-only label, and it regularly calls an apple a cherry or a
    // tomato — so those stay in as apple lookalikes, not as supported crops.
    // ("food" is deliberately absent: it matches "dog food" and the like.)
    private static let fruitTerms = ["fruit", "produce", "berry", "cherry", "tomato"]
    private static let plantTerms = ["leaf", "leaves", "foliage", "plant", "tree",
                                     "branch", "orchard", "flower", "blossom",
                                     "vegetation", "flora", "shrub", "crop",
                                     "greenery", "botany", "garden", "herb", "grass"]

    /// Run Vision's built-in classifier and decide whether we're looking at an
    /// apple / fruit / plant. Pure on-device Core ML; no network, no bundled model.
    static func detect(_ image: UIImage) async -> AppleDetection {
        guard let cg = image.cgImage else { return .none }

        return await withCheckedContinuation { (cont: CheckedContinuation<AppleDetection, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNClassifyImageRequest()
                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    cont.resume(returning: .none)
                    return
                }

                // Keep only labels Vision will stand behind, strongest first. The old
                // 0.02 confidence escape hatch let near-noise labels through; require a
                // meaningful recall/precision or a 0.10 floor.
                let observations = (request.results ?? [])
                    .filter { $0.hasMinimumRecall(0.1, forPrecision: 0.3) || $0.confidence > 0.10 }
                    .sorted { $0.confidence > $1.confidence }

                cont.resume(returning: summarize(observations))
            }
        }
    }

    private static func summarize(_ obs: [VNClassificationObservation]) -> AppleDetection {
        guard !obs.isEmpty else { return .none }

        func firstMatch(_ terms: [String]) -> VNClassificationObservation? {
            obs.first { o in terms.contains { o.identifier.lowercased().contains($0) } }
        }

        let apple = firstMatch(appleTerms)
        let fruit = firstMatch(fruitTerms)
        let plant = firstMatch(plantTerms)

        // Headline label = the highest-confidence subject match, not a hard
        // apple>plant>fruit precedence (which let a 3%-confidence "apple" beat a
        // 90%-confidence "leaf").
        let subject = [apple, plant, fruit].compactMap { $0 }.max { $0.confidence < $1.confidence }
        let labels = obs.prefix(5).map { "\($0.identifier) \(Int($0.confidence * 100))%" }

        return AppleDetection(
            isApple: apple != nil,
            isPlant: (plant != nil) || (fruit != nil),
            topLabel: subject?.identifier ?? obs[0].identifier,
            confidence: Double(subject?.confidence ?? obs[0].confidence),
            labels: Array(labels))
    }
}
