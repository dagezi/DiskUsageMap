import SwiftUI

struct TreemapCell: View {
    let node: FSNode
    let rect: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(color(for: node))
            Rectangle()
                .stroke(Color.black.opacity(0.25), lineWidth: 1)

            if rect.width > 40 && rect.height > 20 {
                VStack(alignment: .leading, spacing: 1) {
                    Text(node.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(ByteFormatter.string(node.size))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(4)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .help("\(node.url.path)\n\(ByteFormatter.string(node.size))")
    }

    private func color(for node: FSNode) -> Color {
        if node.errorDescription != nil {
            return Color.gray.opacity(0.4)
        }
        if node.isDirectory {
            return Color.accentColor.opacity(0.55)
        }
        return colorForExtension(node.url.pathExtension.lowercased())
    }

    private func colorForExtension(_ ext: String) -> Color {
        switch ext {
        case "jpg", "jpeg", "png", "heic", "gif", "raw", "tiff", "webp":
            return .purple.opacity(0.6)
        case "mp4", "mov", "avi", "mkv", "m4v":
            return .pink.opacity(0.6)
        case "mp3", "wav", "aac", "flac", "m4a":
            return .orange.opacity(0.6)
        case "zip", "dmg", "tar", "gz", "pkg", "bz2":
            return .brown.opacity(0.6)
        case "app":
            return .blue.opacity(0.6)
        case "pdf", "doc", "docx", "pages", "txt", "md", "key", "numbers":
            return .teal.opacity(0.6)
        default:
            return .gray.opacity(0.5)
        }
    }
}
