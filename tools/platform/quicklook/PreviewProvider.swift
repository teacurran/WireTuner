import Quartz
import Foundation

/// QuickLook preview provider for .wiretuner files.
///
/// Provides macOS Finder with thumbnail previews by:
/// 1. Extracting artboard data from .wiretuner file
/// 2. Generating PNG thumbnail via WireTuner CLI
/// 3. Returning image for QuickLook display
///
/// ## Architecture
///
/// This extension integrates with macOS QuickLook framework (QLPreviewProvider)
/// and delegates thumbnail generation to the WireTuner app's thumbnail service.
///
/// Flow:
/// - Finder requests preview for .wiretuner file
/// - Extension extracts document metadata
/// - CLI command generates thumbnail: `wiretuner --generate-thumbnail <file> <output>`
/// - Extension loads PNG and returns to Finder
///
/// ## Installation
///
/// Built as App Extension and bundled with WireTuner.app.
/// Registered in Info.plist with UTI: com.wiretuner.document
///
/// Related: FR-047 (macOS Platform Integration)
@objc(PreviewProvider)
class PreviewProvider: QLPreviewProvider {

    /// Provides preview for a QuickLook request.
    ///
    /// - Parameters:
    ///   - request: The QuickLook preview request
    ///   - handler: Handler to call with the preview or error
    override func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL

        // Generate thumbnail via CLI
        let thumbnailURL = try await generateThumbnail(for: fileURL)

        // Load thumbnail image
        guard let image = NSImage(contentsOf: thumbnailURL) else {
            throw PreviewError.thumbnailLoadFailed
        }

        // Create reply with image
        let reply = QLPreviewReply(
            dataOfContentType: .image,
            contentSize: image.size
        ) { (replyHandler: QLPreviewReply.Reply) in
            if let tiffData = image.tiffRepresentation {
                let bitmap = NSBitmapImageRep(data: tiffData)
                let pngData = bitmap?.representation(using: .png, properties: [:])
                replyHandler(pngData, nil)
            } else {
                replyHandler(nil, PreviewError.imageConversionFailed)
            }
        }

        return reply
    }

    /// Generates a thumbnail for a .wiretuner file.
    ///
    /// Calls WireTuner CLI to render first artboard thumbnail.
    /// Returns URL to cached PNG file.
    private func generateThumbnail(for fileURL: URL) async throws -> URL {
        let cacheDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wiretuner-thumbnails", isDirectory: true)

        // Create cache directory if needed
        try? FileManager.default.createDirectory(
            at: cacheDir,
            withIntermediateDirectories: true
        )

        // Generate cache key from file path and modification time
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let modTime = fileAttributes[.modificationDate] as? Date ?? Date()
        let cacheKey = "\(fileURL.lastPathComponent)-\(modTime.timeIntervalSince1970)"
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "thumbnail"

        let outputURL = cacheDir.appendingPathComponent("\(cacheKey).png")

        // Check if cached thumbnail exists and is fresh
        if FileManager.default.fileExists(atPath: outputURL.path) {
            return outputURL
        }

        // Find WireTuner CLI executable
        // In production, this would be bundled with the app
        let cliURL = findWireTunerCLI()

        guard let cli = cliURL else {
            // Fallback: generate placeholder thumbnail
            return try generatePlaceholder(at: outputURL)
        }

        // Execute CLI to generate thumbnail
        let process = Process()
        process.executableURL = cli
        process.arguments = [
            "--generate-thumbnail",
            fileURL.path,
            outputURL.path,
            "--size", "512"
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw PreviewError.thumbnailGenerationFailed
        }

        return outputURL
    }

    /// Finds WireTuner CLI executable.
    ///
    /// Searches in:
    /// 1. App bundle Resources
    /// 2. Parent app bundle (if running as extension)
    /// 3. System PATH
    private func findWireTunerCLI() -> URL? {
        // Check bundle resources
        if let bundleURL = Bundle.main.url(
            forResource: "wiretuner-cli",
            withExtension: nil
        ) {
            return bundleURL
        }

        // Check parent app bundle
        if let parentURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent("wiretuner-cli") {
            if FileManager.default.fileExists(atPath: parentURL.path) {
                return parentURL
            }
        }

        // Check PATH
        let paths = [
            "/usr/local/bin/wiretuner",
            "/opt/homebrew/bin/wiretuner",
            NSHomeDirectory() + "/.local/bin/wiretuner"
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        return nil
    }

    /// Generates a placeholder thumbnail.
    ///
    /// Used when CLI is unavailable or thumbnail generation fails.
    /// Shows WireTuner icon with file name.
    private func generatePlaceholder(at outputURL: URL) throws -> URL {
        let size = CGSize(width: 512, height: 512)

        let image = NSImage(size: size)
        image.lockFocus()

        // Background
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        // Icon placeholder (simple vector graphic)
        NSColor.systemBlue.setFill()
        let iconRect = NSRect(x: 156, y: 206, width: 200, height: 200)
        NSBezierPath(ovalIn: iconRect).fill()

        // Text
        let text = "WireTuner"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: 120,
            width: textSize.width,
            height: textSize.height
        )
        (text as NSString).draw(in: textRect, withAttributes: attrs)

        image.unlockFocus()

        // Save as PNG
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw PreviewError.placeholderGenerationFailed
        }

        try png.write(to: outputURL)
        return outputURL
    }
}

/// Errors that can occur during preview generation.
enum PreviewError: Error {
    case thumbnailGenerationFailed
    case thumbnailLoadFailed
    case imageConversionFailed
    case placeholderGenerationFailed
}
