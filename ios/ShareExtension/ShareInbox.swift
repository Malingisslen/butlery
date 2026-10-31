import Foundation

/// The hand-over between the share extension and the app, in the App Group
/// container both can reach. Compiled into both targets so the two sides
/// cannot disagree on the format.
///
/// Apple gives a share extension no supported way to open its app, so the
/// extension leaves the share here and the app takes it the next time it
/// starts or comes to the foreground.
enum ShareInbox {
  static let appGroup = "group.se.butlery.app"
  private static let manifestName = "inbox.json"

  private struct Manifest: Codable {
    var text: String?
    var images: [String]
  }

  struct Taken {
    var text: String?
    var imagePaths: [String]
  }

  private static var directory: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
      .appendingPathComponent("SharedInbox", isDirectory: true)
  }

  /// Empties the inbox and returns it, ready for a new share's files. A share
  /// the app has not taken yet is dropped: the user means the latest one,
  /// which is also what the app does with two shares in a row.
  static func begin() throws -> URL {
    guard let dir = directory else { throw CocoaError(.fileNoSuchFile) }
    let fm = FileManager.default
    if fm.fileExists(atPath: dir.path) {
      try fm.removeItem(at: dir)
    }
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  /// Written last and atomically, so the app never reads a half-copied share.
  static func commit(text: String?, imageNames: [String]) throws {
    guard let dir = directory else { throw CocoaError(.fileNoSuchFile) }
    let data = try JSONEncoder().encode(Manifest(text: text, images: imageNames))
    try data.write(to: dir.appendingPathComponent(manifestName), options: .atomic)
  }

  /// Takes the waiting share, moving its images into [destination] so they
  /// outlive the inbox. Nil when nothing is waiting.
  static func take(movingImagesTo destination: URL) -> Taken? {
    guard let dir = directory else { return nil }
    let fm = FileManager.default
    // No manifest means no share, or one the extension is still copying,
    // so the folder is left alone.
    guard let data = try? Data(contentsOf: dir.appendingPathComponent(manifestName))
    else { return nil }
    defer { try? fm.removeItem(at: dir) }
    guard let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
    else { return nil }

    var paths: [String] = []
    for name in manifest.images {
      let target = destination.appendingPathComponent("shared_\(UUID().uuidString)_\(name)")
      if (try? fm.moveItem(at: dir.appendingPathComponent(name), to: target)) != nil {
        paths.append(target.path)
      }
    }
    let text = manifest.text?.trimmingCharacters(in: .whitespacesAndNewlines)
    if paths.isEmpty && (text ?? "").isEmpty { return nil }
    return Taken(text: text, imagePaths: paths)
  }
}
