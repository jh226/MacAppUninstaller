import SwiftUI

struct DetailView: View {
    @EnvironmentObject var appManager: AppManager

    var body: some View {
        VStack(spacing: 0) {
            if let app = appManager.selectedApp {
                // 앱 정보 헤더
                AppHeaderView(app: app)

                Divider()

                // 관련 파일 목록
                if appManager.isSearching {
                    Spacer()
                    ProgressView("관련 파일 탐색 중...")
                    Spacer()
                } else if appManager.relatedFiles.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        Text("관련 파일이 없습니다")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    FileListView()
                }

            } else {
                // 앱 미선택 상태
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "trash.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("삭제할 앱을 선택하거나\n.app 파일을 드래그하세요")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct AppHeaderView: View {
    let app: AppInfo
    @EnvironmentObject var appManager: AppManager
    @State private var includeApp = true

    var body: some View {
        HStack(spacing: 14) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 48, height: 48)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                if app.isSizeCalculated {
                    Text("앱 크기: \(app.formattedSize)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("크기 계산 중...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()

            if !appManager.isSearching {
                Button(action: {
                    appManager.showDeleteConfirmation = true
                }) {
                    Label("삭제", systemImage: "trash")
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.red))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $appManager.showDeleteConfirmation) {
                    DeleteConfirmationSheet(includeApp: includeApp)
                        .environmentObject(appManager)
                }
            }
        }
        .padding(16)
    }
}

struct FileListView: View {
    @EnvironmentObject var appManager: AppManager

    var allSelected: Bool {
        !appManager.relatedFiles.isEmpty && appManager.relatedFiles.allSatisfy(\.isSelected)
    }

    var groupedFiles: [(FileCategory, [Int])] {
        var groups: [FileCategory: [Int]] = [:]
        for (index, file) in appManager.relatedFiles.enumerated() {
            groups[file.category, default: []].append(index)
        }
        return FileCategory.allCases.compactMap { category in
            guard let indices = groups[category] else { return nil }
            return (category, indices)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 전체 선택/해제 + 파일 수 정보
            HStack {
                Text("관련 파일 \(appManager.relatedFiles.count)개")
                    .font(.headline)
                Spacer()
                Button(allSelected ? "전체 해제" : "전체 선택") {
                    if allSelected {
                        appManager.deselectAllFiles()
                    } else {
                        appManager.selectAllFiles()
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // 카테고리별 그룹화된 파일 목록
            List {
                ForEach(groupedFiles, id: \.0) { category, indices in
                    Section(header: Text(category.rawValue)) {
                        ForEach(indices, id: \.self) { index in
                            FileRowView(file: $appManager.relatedFiles[index])
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}

struct FileRowView: View {
    @Binding var file: RelatedFile

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $file.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()

            Image(systemName: fileIcon)
                .foregroundColor(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(shortenedPath)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(file.formattedSize)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            // Finder에서 보기 버튼
            Button(action: revealInFinder) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Finder에서 보기")
        }
        .padding(.vertical, 2)
        .opacity(file.isSelected ? 1 : 0.5)
    }

    private var fileIcon: String {
        switch file.category {
        case .cache: return "archivebox"
        case .preferences: return "gearshape"
        case .applicationSupport: return "folder"
        case .logs: return "doc.text"
        case .containers: return "shippingbox"
        case .savedState: return "clock.arrow.circlepath"
        case .cookies: return "birthday.cake"
        case .webData: return "globe"
        case .crashReports: return "exclamationmark.triangle"
        case .other: return "doc"
        }
    }

    private var shortenedPath: String {
        file.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func revealInFinder() {
        NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
    }
}


struct DeleteConfirmationSheet: View {
    @EnvironmentObject var appManager: AppManager
    let includeApp: Bool

    var body: some View {
        VStack(spacing: 20) {
            if let app = appManager.selectedApp {
                // 앱 아이콘 + 이름
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                }

                Text("「\(app.name)」을(를) 삭제하시겠습니까?")
                    .font(.headline)

                // 삭제 요약
                VStack(spacing: 6) {
                    if includeApp {
                        HStack {
                            Image(systemName: "app.fill")
                                .foregroundColor(.secondary)
                            Text("앱 번들")
                            Spacer()
                            Text(app.formattedSize)
                                .foregroundColor(.secondary)
                        }
                        .font(.system(size: 12))
                    }
                    HStack {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.secondary)
                        Text("관련 파일 \(appManager.relatedFiles.filter(\.isSelected).count)개")
                        Spacer()
                        Text(appManager.totalSelectedSizeFormatted)
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 12))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))

                Text("선택된 파일이 휴지통으로 이동됩니다.\n휴지통에서 복구할 수 있습니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 버튼
            HStack(spacing: 12) {
                Button("취소") {
                    appManager.showDeleteConfirmation = false
                }
                .keyboardShortcut(.cancelAction)

                Button(action: {
                    appManager.showDeleteConfirmation = false
                    appManager.deleteSelectedFiles(includeApp: includeApp)
                }) {
                    Text("휴지통으로 이동")
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.red))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
