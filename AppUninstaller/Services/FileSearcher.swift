import Foundation

class FileSearcher {
    private let fileManager = FileManager.default

    // Bundle ID를 기반으로 ~/Library 하위에서 관련 파일/폴더를 탐색
    func findRelatedFiles(for app: AppInfo) -> [RelatedFile] {
        var files: [RelatedFile] = []
        let homeDir = NSHomeDirectory()
        let bundleId = app.bundleIdentifier
        let appName = (app.path as NSString).lastPathComponent
        let appNameNoExt = (appName as NSString).deletingPathExtension

        // Bundle ID 기반으로 탐색할 경로들
        let searchPaths: [(String, String)] = [
            ("\(homeDir)/Library/Application Support", bundleId),
            ("\(homeDir)/Library/Application Support", appNameNoExt),
            ("\(homeDir)/Library/Caches", bundleId),
            ("\(homeDir)/Library/Caches", appNameNoExt),
            ("\(homeDir)/Library/Preferences", bundleId),
            ("\(homeDir)/Library/Logs", bundleId),
            ("\(homeDir)/Library/Logs", appNameNoExt),
            ("\(homeDir)/Library/Containers", bundleId),
            ("\(homeDir)/Library/Saved Application State", "\(bundleId).savedState"),
            ("\(homeDir)/Library/Cookies", bundleId),
            ("\(homeDir)/Library/WebKit", bundleId),
            ("\(homeDir)/Library/HTTPStorages", bundleId),
            ("\(homeDir)/Library/Group Containers", bundleId),
        ]

        for (basePath, searchTerm) in searchPaths {
            findMatchingItems(in: basePath, matching: searchTerm, results: &files)
        }

        // plist 파일 검색 (com.developer.appname.plist 패턴)
        let preferencesPath = "\(homeDir)/Library/Preferences"
        if let contents = try? fileManager.contentsOfDirectory(atPath: preferencesPath) {
            for item in contents where item.contains(bundleId) {
                let fullPath = (preferencesPath as NSString).appendingPathComponent(item)
                if !files.contains(where: { $0.path == fullPath }) {
                    let size = getItemSize(at: fullPath)
                    files.append(RelatedFile(path: fullPath, size: size))
                }
            }
        }

        // mdfind(Spotlight)로 추가 파일 검색 (허용 경로 내만)
        let spotlightFiles = searchWithSpotlight(bundleId: bundleId)
        for path in spotlightFiles {
            let resolved = (path as NSString).resolvingSymlinksInPath
            let isAllowed = resolved.hasPrefix("\(homeDir)/Library/") ||
                            resolved.hasPrefix("/Applications/") ||
                            resolved.hasPrefix("\(homeDir)/Applications/")
            if isAllowed && !files.contains(where: { $0.path == path }) && path != app.path {
                let size = getItemSize(at: path)
                files.append(RelatedFile(path: path, size: size))
            }
        }

        return files.sorted { $0.path < $1.path }
    }

    private func findMatchingItems(in basePath: String, matching searchTerm: String, results: inout [RelatedFile]) {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: basePath) else { return }

        for item in contents {
            if item.localizedCaseInsensitiveContains(searchTerm) {
                let fullPath = (basePath as NSString).appendingPathComponent(item)
                if !results.contains(where: { $0.path == fullPath }) {
                    let size = getItemSize(at: fullPath)
                    results.append(RelatedFile(path: fullPath, size: size))
                }
            }
        }
    }

    private func searchWithSpotlight(bundleId: String) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["kMDItemCFBundleIdentifier == '\(bundleId)'"]

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

    private func getItemSize(at path: String) -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else { return 0 }

        if isDirectory.boolValue {
            return calculateDirectorySize(path: path)
        } else {
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                return size
            }
            return 0
        }
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
