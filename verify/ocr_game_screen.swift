// macOS verification helper: read actual rendered labels, not game state.
import Foundation
import Vision
import AppKit
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(contentsOf: url)!
var rect = CGRect(origin: .zero, size: image.size)
let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
try VNImageRequestHandler(cgImage: cg).perform([request])
let rows: [[String: Any]] = (request.results ?? []).compactMap { row in
    guard let text = row.topCandidates(1).first?.string else { return nil }
    let b = row.boundingBox
    return ["text": text, "x": b.midX * Double(cg.width),
            "y": (1-b.midY) * Double(cg.height),
            "width": b.width * Double(cg.width), "height": b.height * Double(cg.height)]
}
print(String(data: try JSONSerialization.data(withJSONObject: rows), encoding: .utf8)!)
