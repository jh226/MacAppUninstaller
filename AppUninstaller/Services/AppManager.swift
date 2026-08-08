import Foundation
import SwiftUI

class AppManager: ObservableObject {
    @Published var installedApps: [AppInfo] = []
    @Published var selectedAppId: UUID?

    var selectedApp: AppInfo? {
        guard let id = selectedAppId else { return nil }
        return installedApps.first { $0.id == id }
    }
    @Published var relatedFiles: [RelatedFile] = []
    @Published var isScanning = false
    @Published var isSearching = false
    @Published var searchText = ""
    @Published var showDeleteConfirmation = false
    @Published var deleteComplete = false
    @Published var deleteError: String?

    private let scanner = AppScanner()
    private let searcher = FileSearcher()
    private let descriptionFetcher = AppDescriptionFetcher()
    private let fileManager = FileManager.default
    private let sizeQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 8
        queue.qualityOfService = .utility
        return queue
    }()
    private let descQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 4
        queue.qualityOfService = .utility
        return queue
    }()

    var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return installedApps
        }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var totalSelectedSize: Int64 {
        relatedFiles.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    var totalSelectedSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)
    }

    // 설치된 앱 목록 스캔 (2단계: 목록 즉시 표시 → 크기 비동기 계산)
    func scanApps() {
        isScanning = true
        sizeQueue.cancelAllOperations()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let apps = self.scanner.scanInstalledApps()

            DispatchQueue.main.async {
                self.installedApps = apps
                self.isScanning = false
                self.calculateSizesAsync()
                self.fetchDescriptionsAsync()
            }
        }
    }

    private func calculateSizesAsync() {
        let scanner = self.scanner
        for index in installedApps.indices {
            let path = installedApps[index].path
            sizeQueue.addOperation { [weak self] in
                let size = scanner.calculateDirectorySize(path: path)
                DispatchQueue.main.async {
                    guard let self = self, index < self.installedApps.count,
                          self.installedApps[index].path == path else { return }
                    self.installedApps[index].size = size
                    self.installedApps[index].isSizeCalculated = true
                }
            }
        }
    }

    private func fetchDescriptionsAsync() {
        let fetcher = self.descriptionFetcher
        for index in installedApps.indices {
            let bundleId = installedApps[index].bundleIdentifier
            let name = installedApps[index].name
            let path = installedApps[index].path
            descQueue.addOperation { [weak self] in
                let desc = fetcher.fetchDescription(bundleId: bundleId, appName: name, appPath: path)
                DispatchQueue.main.async {
                    guard let self = self, index < self.installedApps.count,
                          self.installedApps[index].bundleIdentifier == bundleId else { return }
                    self.installedApps[index].appDescription = desc
                    self.installedApps[index].isDescriptionLoaded = true
                }
            }
        }
    }

    // 앱 선택 시 관련 파일 탐색
    func selectApp(_ app: AppInfo) {
        selectedAppId = app.id
        isSearching = true
        deleteComplete = false
        deleteError = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let files = self?.searcher.findRelatedFiles(for: app) ?? []
            DispatchQueue.main.async {
                self?.relatedFiles = files
                self?.isSearching = false
            }
        }
    }

    // 드래그 앤 드롭으로 .app 파일 받기
    func handleDroppedApp(url: URL) {
        guard url.pathExtension == "app" else { return }
        if let appInfo = scanner.getAppInfo(at: url.path) {
            selectApp(appInfo)
        }
    }

    // 파일 선택/해제 토글
    func toggleFile(at index: Int) {
        guard index < relatedFiles.count else { return }
        relatedFiles[index].isSelected.toggle()
    }

    func selectAllFiles() {
        for i in relatedFiles.indices {
            relatedFiles[i].isSelected = true
        }
    }

    func deselectAllFiles() {
        for i in relatedFiles.indices {
            relatedFiles[i].isSelected = false
        }
    }

    // 선택된 파일 + 앱 삭제 실행
    func deleteSelectedFiles(includeApp: Bool = true) {
        guard let app = selectedApp else { return }
        deleteError = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // 1단계: 삭제 가능 여부 사전 체크
            var undeletable: [String] = []
            let selectedFiles = self.relatedFiles.filter(\.isSelected)

            for file in selectedFiles {
                guard self.fileManager.fileExists(atPath: file.path) else { continue }
                if !self.fileManager.isDeletableFile(atPath: file.path) {
                    undeletable.append(file.path)
                }
            }

            if includeApp && self.fileManager.fileExists(atPath: app.path) {
                if !self.fileManager.isDeletableFile(atPath: app.path) {
                    undeletable.append(app.path)
                }
            }

            if !undeletable.isEmpty {
                DispatchQueue.main.async {
                    self.deleteError = "다음 파일에 대한 권한이 없어 삭제할 수 없습니다:\n\(undeletable.joined(separator: "\n"))\n\n시스템 설정 > 개인정보 보호 > 전체 디스크 접근 권한에 AppUninstaller를 추가해주세요."
                }
                return
            }

            // 2단계: 전부 삭제 가능 → 삭제 실행
            for file in selectedFiles {
                let url = URL(fileURLWithPath: file.path)
                guard self.fileManager.fileExists(atPath: file.path) else { continue }
                do {
                    try self.fileManager.trashItem(at: url, resultingItemURL: nil)
                } catch {
                    try? self.fileManager.removeItem(at: url)
                }
            }

            if includeApp {
                let appUrl = URL(fileURLWithPath: app.path)
                if self.fileManager.fileExists(atPath: app.path) {
                    do {
                        try self.fileManager.trashItem(at: appUrl, resultingItemURL: nil)
                    } catch {
                        try? self.fileManager.removeItem(at: appUrl)
                    }
                }
            }

            DispatchQueue.main.async {
                self.deleteComplete = true
                self.installedApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
                self.selectedAppId = nil
                self.relatedFiles = []
            }
        }
    }

    // AppleScript를 통해 관리자 권한으로 파일 삭제
    private func deleteWithPrivilege(path: String) -> Bool {
        let escapedPath = path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"rm -rf \\\"\(escapedPath)\\\"\" with administrator privileges"
        guard let appleScript = NSAppleScript(source: script) else { return false }
        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)
        return error == nil
    }
}
