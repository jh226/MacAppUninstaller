import Foundation
import AppKit

class AppScanner {
    private let fileManager = FileManager.default

    func scanInstalledApps() -> [AppInfo] {
        var apps: [AppInfo] = []
        let appDirectories = [
            "/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        for directory in appDirectories {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else { continue }

            for item in contents where item.hasSuffix(".app") {
                let appPath = (directory as NSString).appendingPathComponent(item)
                if let appInfo = getAppInfo(at: appPath) {
                    apps.append(appInfo)
                }
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func getAppInfo(at path: String) -> AppInfo? {
        let plistPath = (path as NSString).appendingPathComponent("Contents/Info.plist")

        guard fileManager.fileExists(atPath: plistPath),
              let plist = NSDictionary(contentsOfFile: plistPath),
              let bundleId = plist["CFBundleIdentifier"] as? String else {
            return nil
        }

        let name = plist["CFBundleName"] as? String
            ?? plist["CFBundleDisplayName"] as? String
            ?? ((path as NSString).lastPathComponent as NSString).deletingPathExtension

        let icon = NSWorkspace.shared.icon(forFile: path)

        return AppInfo(
            name: name,
            bundleIdentifier: bundleId,
            path: path,
            icon: icon,
            size: 0
        )
    }

    func calculateDirectorySize(path: String) -> Int64 {
        let localFM = FileManager()
        let url = URL(fileURLWithPath: path)
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = localFM.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let size = values.totalFileAllocatedSize else { continue }
            totalSize += Int64(size)
        }
        return totalSize
    }
}
