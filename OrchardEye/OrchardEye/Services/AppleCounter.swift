//
//  AppleCounter.swift
//  OrchardEye
//
//  On-device approximate apple count for a fruit photo — a rough yield helper.
//  No ML/object-detector (those are stubbed in the Simulator): build a mask of
//  apple-skin-coloured pixels, then count connected blobs above a min size via
//  flood-fill connected-components. Overlapping apples merge (undercount) and cut
//  halves count separately, so it's surfaced as "~N", an estimate.
//

import UIKit

enum AppleCounter {

    /// Approximate number of apples in the frame. 0 when nothing apple-coloured.
    static func count(_ image: UIImage) -> Int {
        let n = 96
        guard let cg = image.cgImage else { return 0 }
        var px = [UInt8](repeating: 0, count: n * n * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        px.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: n, height: n,
                                      bitsPerComponent: 8, bytesPerRow: n * 4, space: cs,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            ctx.interpolationQuality = .low
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
        }

        // Apple-skin mask: warm (red or golden), saturated enough to beat background.
        var mask = [Bool](repeating: false, count: n * n)
        for i in 0..<(n * n) {
            let r = Double(px[i*4]) / 255, g = Double(px[i*4+1]) / 255, b = Double(px[i*4+2]) / 255
            let mx = max(r, max(g, b)), mn = min(r, min(g, b))
            let sat = mx > 0 ? (mx - mn) / mx : 0
            let warm = (r > g + 0.06 && r > b + 0.06) || (r > 0.5 && g > 0.4 && b < 0.42)
            mask[i] = warm && sat > 0.18 && mx > 0.25
        }

        // One dilation pass closes small gaps (highlights, colour variation) so a
        // single apple isn't split into several blobs.
        var dil = mask
        for y in 0..<n {
            for x in 0..<n {
                let i = y*n + x
                if mask[i] { continue }
                if (x > 0 && mask[i-1]) || (x < n-1 && mask[i+1]) ||
                   (y > 0 && mask[i-n]) || (y < n-1 && mask[i+n]) { dil[i] = true }
            }
        }
        mask = dil

        // Connected components (4-neighbour flood fill); count blobs above min area.
        var visited = [Bool](repeating: false, count: n * n)
        let minArea = max(12, n * n / 220)   // ignore specks / stems / reflections
        var stack = [Int](); stack.reserveCapacity(n * n)
        var count = 0
        for start in 0..<(n * n) where mask[start] && !visited[start] {
            var area = 0
            stack.removeAll(keepingCapacity: true)
            stack.append(start); visited[start] = true
            while let p = stack.popLast() {
                area += 1
                let x = p % n, y = p / n
                if x > 0,     mask[p-1], !visited[p-1] { visited[p-1] = true; stack.append(p-1) }
                if x < n-1,   mask[p+1], !visited[p+1] { visited[p+1] = true; stack.append(p+1) }
                if y > 0,     mask[p-n], !visited[p-n] { visited[p-n] = true; stack.append(p-n) }
                if y < n-1,   mask[p+n], !visited[p+n] { visited[p+n] = true; stack.append(p+n) }
            }
            if area >= minArea { count += 1 }
        }
        return count
    }
}
