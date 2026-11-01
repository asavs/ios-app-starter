import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A picked photo or movie received as a file, not as bytes in memory: the importer copies the
/// picker's file to a temporary location of our own, which the model then copies into the store
/// and deletes. Apple's note: files received this way are the app's to manage.
struct ImportedFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            ImportedFile(url: try Self.stage(received.file))
        }
        FileRepresentation(importedContentType: .movie) { received in
            ImportedFile(url: try Self.stage(received.file))
        }
    }

    private static func stage(_ file: URL) throws -> URL {
        let staging = URL.temporaryDirectory.appending(path: "Attachments-Imports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let copy = staging.appending(path: "\(UUID().uuidString).\(file.pathExtension)")
        try FileManager.default.copyItem(at: file, to: copy)
        return copy
    }
}
