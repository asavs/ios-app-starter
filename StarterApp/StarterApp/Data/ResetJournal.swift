import Foundation

/// A note to the next launch that Erase Local Data was under way: which phase it reached, so an
/// erase the app didn't finish (a crash, a kill, a thrown step) is completed instead of leaving some
/// stores empty and others full. Kept as a small file under Application Support, outside the
/// database being erased and outside the defaults the erase wipes.
///
/// Phases run in order and each is recorded before it starts: `records` (the database), then `files`
/// (the attachment originals and caches). Settings, secrets and tips are wiped before the journal
/// opens; they are idempotent and the next launch's recovery doesn't need them.
struct ResetJournal: Sendable {
    enum Phase: String, Codable, Sendable, CaseIterable {
        case records, files
    }

    struct Entry: Codable, Equatable, Sendable {
        var startedAt: Date
        var phase: Phase
    }

    let url: URL

    /// The app's journal, beside the store under Application Support; a UI-test launch keeps it under
    /// the launch's own directory.
    static var standard: ResetJournal {
        let directory = UITestLaunch.current.map { _ in UITestLaunch.directory }
            ?? URL.applicationSupportDirectory
        return ResetJournal(url: directory.appending(path: "erase-in-progress.json"))
    }

    init(url: URL) {
        self.url = url
    }

    /// The unfinished erase, if the last one didn't complete.
    var pending: Entry? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Entry.self, from: data)
    }

    /// Record that `phase` is about to run.
    func begin(_ phase: Phase, at date: Date = .now) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let entry = Entry(startedAt: pending?.startedAt ?? date, phase: phase)
        try JSONEncoder().encode(entry).write(to: url, options: .atomic)
    }

    /// Every phase ran and was verified: nothing is owed.
    func finish() throws {
        if FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// The phases still owed by an unfinished erase, from the one it was in.
    var owedPhases: [Phase] {
        guard let pending else { return [] }
        return Array(Phase.allCases.drop { $0 != pending.phase })
    }
}
