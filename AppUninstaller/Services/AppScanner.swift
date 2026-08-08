import Foundation
import AppKit

class AppScanner {
    private let fileManager = FileManager.default

    func scanInstalledApps() -> [AppInfo] {
        var apps: [AppInfo] = []
        var seenPaths = Set<String>()
        var seenBundleIds = Set<String>()

        let appDirectories = [
            "/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        for directory in appDirectories {
            scanDirectory(directory, apps: &apps, seenPaths: &seenPaths, seenBundleIds: &seenBundleIds)
        }

        let spotlightApps = searchAllAppsWithSpotlight()
        for path in spotlightApps {
            guard !isNestedApp(path) else { continue }
            let resolved = (path as NSString).resolvingSymlinksInPath
            guard !seenPaths.contains(resolved) else { continue }
            if let appInfo = getAppInfo(at: path) {
                guard !seenBundleIds.contains(appInfo.bundleIdentifier) else { continue }
                apps.append(appInfo)
                seenPaths.insert(resolved)
                seenBundleIds.insert(appInfo.bundleIdentifier)
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func isNestedApp(_ path: String) -> Bool {
        let components = path.components(separatedBy: "/")
        var appCount = 0
        for component in components where component.hasSuffix(".app") {
            appCount += 1
            if appCount > 1 { return true }
        }
        return false
    }

    private func scanDirectory(_ directory: String, apps: inout [AppInfo], seenPaths: inout Set<String>, seenBundleIds: inout Set<String>) {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else { return }

        for item in contents where item.hasSuffix(".app") {
            let appPath = (directory as NSString).appendingPathComponent(item)
            let resolved = (appPath as NSString).resolvingSymlinksInPath
            guard !seenPaths.contains(resolved) else { continue }
            if let appInfo = getAppInfo(at: appPath) {
                guard !seenBundleIds.contains(appInfo.bundleIdentifier) else { continue }
                apps.append(appInfo)
                seenPaths.insert(resolved)
                seenBundleIds.insert(appInfo.bundleIdentifier)
            }
        }
    }

    private func searchAllAppsWithSpotlight() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["kMDItemContentType == 'com.apple.application-bundle'"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.components(separatedBy: "\n").filter { !$0.isEmpty }
            }
        } catch {}

        return []
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

        let isSystemApp = path.hasPrefix("/System/") || path.hasPrefix("/Library/")

        return AppInfo(
            name: name,
            bundleIdentifier: bundleId,
            path: path,
            icon: icon,
            size: 0,
            isSystemApp: isSystemApp
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
