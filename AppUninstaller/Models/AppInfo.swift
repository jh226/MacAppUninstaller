import Foundation
import AppKit

struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let path: String
    let icon: NSImage?
    var size: Int64
    var isSizeCalculated: Bool = false
    var appDescription: String?
    var isDescriptionLoaded: Bool = false

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.id == rhs.id && lhs.size == rhs.size && lhs.isSizeCalculated == rhs.isSizeCalculated && lhs.appDescription == rhs.appDescription && lhs.isDescriptionLoaded == rhs.isDescriptionLoaded
    }
}
