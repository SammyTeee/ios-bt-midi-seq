import SwiftUI
import UniformTypeIdentifiers

final class SessionStore: ObservableObject {
    @Published var song = Song() { didSet { save() } }
    @Published var error: String?
    private let url: URL

    init() {
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("session.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do { song = try Song.decode(Data(contentsOf: url)) }
            catch { self.error = "Could not restore the saved session: \(error.localizedDescription)" }
        }
    }

    private func save() {
        do { try JSONEncoder().encode(song).write(to: url, options: .atomic) }
        catch { self.error = "Could not save: \(error.localizedDescription)" }
    }

    func load(_ file: URL) {
        let access = file.startAccessingSecurityScopedResource()
        defer { if access { file.stopAccessingSecurityScopedResource() } }
        do { song = try Song.decode(Data(contentsOf: file)) }
        catch { self.error = error.localizedDescription }
    }
}

struct SessionDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var song: Song
    init(song: Song) { self.song = song }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw SongError.invalid }
        song = try Song.decode(data)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(song))
    }
}
