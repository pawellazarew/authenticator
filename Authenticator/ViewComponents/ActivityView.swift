import SwiftUI

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let completion: () -> Void

    private func completionHandler(activityType _: UIActivity.ActivityType?, completed _: Bool, returnedItems _: [Any]?, activityError _: Error?) {
        completion()
    }

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.excludedActivityTypes = [.saveToCameraRoll]
        controller.completionWithItemsHandler = completionHandler
        return controller
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

struct DocumentExporter: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context _: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        return controller
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}
}
