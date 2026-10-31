import UIKit
import UniformTypeIdentifiers

/// Saves what the user shares into the App Group inbox and says so. It sends
/// nothing anywhere; the app imports the share the next time it is opened.
final class ShareViewController: UIViewController {
  private let messageLabel = UILabel()
  private let doneButton = UIButton(type: .system)

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    layout()
    Task { await save() }
  }

  private func layout() {
    messageLabel.text = NSLocalizedString("share.saving", comment: "")
    messageLabel.font = .preferredFont(forTextStyle: .body)
    messageLabel.adjustsFontForContentSizeCategory = true
    messageLabel.numberOfLines = 0
    messageLabel.textAlignment = .center

    doneButton.setTitle(NSLocalizedString("share.done", comment: ""), for: .normal)
    doneButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
    doneButton.isHidden = true
    doneButton.addTarget(self, action: #selector(finish), for: .touchUpInside)

    let stack = UIStackView(arrangedSubviews: [messageLabel, doneButton])
    stack.axis = .vertical
    stack.spacing = 20
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
    ])
  }

  private func save() async {
    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      .flatMap { $0.attachments ?? [] }
    var saved = false
    do {
      let inbox = try ShareInbox.begin()
      var texts: [String] = []
      var imageNames: [String] = []
      for (index, provider) in providers.enumerated() {
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
          if let name = await copyImage(provider, into: inbox, index: index) {
            imageNames.append(name)
          }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
          if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
            texts.append(url.absoluteString)
          }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
          if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
            texts.append(text)
          }
        }
      }
      let text = Self.joined(texts)
      if text != nil || !imageNames.isEmpty {
        try ShareInbox.commit(text: text, imageNames: imageNames)
        saved = true
      }
    } catch {
      saved = false
    }
    messageLabel.text = NSLocalizedString(saved ? "share.saved" : "share.failed", comment: "")
    doneButton.isHidden = false
  }

  /// Copied as a file, never decoded: iOS stops a share extension that holds
  /// several full-size photos in memory.
  private func copyImage(_ provider: NSItemProvider, into inbox: URL, index: Int) async -> String? {
    await withCheckedContinuation { continuation in
      _ = provider.loadFileRepresentation(for: .image) { url, _, _ in
        // The file only exists until this handler returns.
        guard let url else { return continuation.resume(returning: nil) }
        let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension.lowercased()
        let name = "image-\(index).\(ext)"
        do {
          try FileManager.default.copyItem(at: url, to: inbox.appendingPathComponent(name))
          continuation.resume(returning: name)
        } catch {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  /// A page shared from Safari arrives as its link alone, a post from another
  /// app often as text that already holds the link; keep each piece once.
  static func joined(_ parts: [String]) -> String? {
    var kept: [String] = []
    for part in parts.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !part.isEmpty {
      if kept.contains(where: { $0.contains(part) }) { continue }
      kept.removeAll { part.contains($0) }
      kept.append(part)
    }
    return kept.isEmpty ? nil : kept.joined(separator: "\n")
  }

  @objc private func finish() {
    extensionContext?.completeRequest(returningItems: nil)
  }
}
