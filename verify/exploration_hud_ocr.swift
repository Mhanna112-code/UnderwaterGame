import Foundation
import Vision
import AppKit
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(contentsOf: url)!
var rect = NSRect(origin: .zero, size: image.size)
let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
try VNImageRequestHandler(cgImage: cg).perform([request])
let rows = (request.results ?? []).compactMap { item -> [String: Any]? in
    guard let text = item.topCandidates(1).first?.string else { return nil }
    let b = item.boundingBox
    return ["text": text, "x": b.midX * Double(cg.width), "y": (1 - b.midY) * Double(cg.height)]
}
let data = try JSONSerialization.data(withJSONObject: rows)
print(String(data: data, encoding: .utf8)!)
