#if os(iOS)
import LinkPresentation
import SwiftUI
import UIKit

/// A link attachment drawn by `LPLinkView` from the store's cached metadata, in the system's
/// familiar card. Nothing is fetched here: the store did that once when the link was added.
public struct LinkPreview: View {
    private let attachment: Attachment
    private let store: any AttachmentStoring
    @State private var archive: Data?

    public init(_ attachment: Attachment, store: any AttachmentStoring) {
        self.attachment = attachment
        self.store = store
    }

    public var body: some View {
        Group {
            if let url = attachment.url {
                LinkCard(url: url, metadata: archive.flatMap(LinkMetadataFetcher.metadata(from:)))
            }
        }
        .task(id: attachment.id) { archive = await store.linkMetadataArchive(for: attachment) }
        .accessibilityIdentifier("attachments.linkPreview")
    }
}

/// `LPLinkView` sized to the width SwiftUI offers.
private struct LinkCard: UIViewRepresentable {
    let url: URL
    let metadata: LPLinkMetadata?

    func makeUIView(context: Context) -> SizedLinkView {
        SizedLinkView(url: url)
    }

    func updateUIView(_ view: SizedLinkView, context: Context) {
        if let metadata { view.metadata = metadata }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView view: SizedLinkView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        return view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }
}

private final class SizedLinkView: LPLinkView {
    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric) }
}
#endif
