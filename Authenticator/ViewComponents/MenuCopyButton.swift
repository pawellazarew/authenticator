import SwiftUI

struct MenuCopyButton: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Button {
            UIPasteboard.general.string = text
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
    }
}
