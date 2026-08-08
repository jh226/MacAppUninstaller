import Foundation
import AppKit

class AppScanner {
    private let fileManager = FileManager.default

    // /Applications 폴더에서 설치된 앱 목록을 스캔
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

    // .app 번들에서 앱 정보를 추출
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
        let size = calculateDirectorySize(path: path)

        return AppInfo(
            name: name,
            bundleIdentifier: bundleId,
            path: path,
            icon: icon,
            size: size
        )
    }

    private func calculateDirectorySize(path: String) -> Int64 {
        var totalSize: Int64 = 0
        guard let enumerator = fileManager.enumerator(atPath: path) else { return 0 }

        while let file = enumerator.nextObject() as? String {
            let fullPath = (path as NSString).appendingPathComponent(file)
            if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
               let fileSize = attrs[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        return totalSize
    }
}
