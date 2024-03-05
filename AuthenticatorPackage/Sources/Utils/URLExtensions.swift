import UIKit
import UniformTypeIdentifiers

public extension URL {
    var readText: String? {
        guard let type: UTType = try? resourceValues(forKeys: [.contentTypeKey]).contentType else { return nil }
        if type.conforms(to: .text) {
            guard let content: String = try? String(contentsOf: self) else { return nil }
            guard !content.isEmpty else { return nil }
            return content
        } else if type.conforms(to: .image) {
            guard let pickedImage = UIImage(contentsOfFile: path) else { return nil }
            guard let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else { return nil }
            guard let ciImage = CIImage(image: pickedImage) else { return nil }
            var qrCodeText: String = .empty
            let features: [CIFeature] = detector.features(in: ciImage)
            _ = features.map {
                let newText: String = ($0 as? CIQRCodeFeature)?.messageString ?? .empty
                qrCodeText += newText
            }
            guard !qrCodeText.isEmpty else { return nil }
            return qrCodeText
        } else {
            return nil
        }
    }

    /// tmp/
    static let tmpDirectoryUrl: URL = .init(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
}
