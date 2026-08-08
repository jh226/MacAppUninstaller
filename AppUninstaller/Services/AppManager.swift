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
    private let fileManager = FileManager.default
    private let sizeQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 8
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
            var errors: [String] = []
            var successCount = 0

            // 관련 파일 삭제
            let selectedFiles = self.relatedFiles.filter(\.isSelected)
            for file in selectedFiles {
                let url = URL(fileURLWithPath: file.path)
                guard self.fileManager.fileExists(atPath: file.path) else {
                    successCount += 1
                    continue
                }
                if self.fileManager.isDeletableFile(atPath: file.path) {
                    do {
                        try self.fileManager.trashItem(at: url, resultingItemURL: nil)
                        successCount += 1
                    } catch {
                        // 휴지통 실패 시 직접 삭제 시도
                        do {
                            try self.fileManager.removeItem(at: url)
                            successCount += 1
                        } catch {
                            errors.append("\(file.path)")
                        }
                    }
                } else {
                    // 권한 없는 파일은 AppleScript로 관리자 권한 삭제 시도
                    if self.deleteWithPrivilege(path: file.path) {
                        successCount += 1
                    } else {
                        errors.append("\(file.path)")
                    }
                }
            }

            // 앱 번들 삭제
            if includeApp {
                let appUrl = URL(fileURLWithPath: app.path)
                if self.fileManager.fileExists(atPath: app.path) {
                    do {
                        try self.fileManager.trashItem(at: appUrl, resultingItemURL: nil)
                        successCount += 1
                    } catch {
                        do {
                            try self.fileManager.removeItem(at: appUrl)
                            successCount += 1
                        } catch {
                            if self.deleteWithPrivilege(path: app.path) {
                                successCount += 1
                            } else {
                                errors.append("\(app.path)")
                            }
                        }
                    }
                } else {
                    successCount += 1
                }
            }

            DispatchQueue.main.async {
                if errors.isEmpty {
                    self.deleteComplete = true
                    self.installedApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
                    self.selectedAppId = nil
                    self.relatedFiles = []
                } else if successCount > 0 {
                    self.deleteError = "일부 파일 삭제 실패 (\(errors.count)개):\n\(errors.joined(separator: "\n"))\n\n나머지 \(successCount)개 파일은 삭제되었습니다."
                    self.installedApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
                    self.selectedAppId = nil
                    self.relatedFiles = []
                } else {
                    self.deleteError = "삭제 실패:\n\(errors.joined(separator: "\n"))\n\n시스템 환경설정 > 개인정보 보호 > 전체 디스크 접근 권한에 AppUninstaller를 추가해주세요."
                }
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
