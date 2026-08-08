import Foundation
import SwiftUI

class AppManager: ObservableObject {
    @Published var installedApps: [AppInfo] = []
    @Published var selectedApp: AppInfo?
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

    // 설치된 앱 목록 스캔
    func scanApps() {
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = self?.scanner.scanInstalledApps() ?? []
            DispatchQueue.main.async {
                self?.installedApps = apps
                self?.isScanning = false
            }
        }
    }

    // 앱 선택 시 관련 파일 탐색
    func selectApp(_ app: AppInfo) {
        selectedApp = app
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

            // 관련 파일 삭제
            let selectedFiles = self.relatedFiles.filter(\.isSelected)
            for file in selectedFiles {
                do {
                    try self.fileManager.trashItem(at: URL(fileURLWithPath: file.path), resultingItemURL: nil)
                } catch {
                    errors.append("\(file.path): \(error.localizedDescription)")
                }
            }

            // 앱 번들 삭제
            if includeApp {
                do {
                    try self.fileManager.trashItem(at: URL(fileURLWithPath: app.path), resultingItemURL: nil)
                } catch {
                    errors.append("\(app.path): \(error.localizedDescription)")
                }
            }

            DispatchQueue.main.async {
                if errors.isEmpty {
                    self.deleteComplete = true
                    self.installedApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
                    self.selectedApp = nil
                    self.relatedFiles = []
                } else {
                    self.deleteError = errors.joined(separator: "\n")
                }
            }
        }
    }
}
