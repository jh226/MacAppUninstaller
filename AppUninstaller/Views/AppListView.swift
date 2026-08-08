import SwiftUI

struct AppListView: View {
    @EnvironmentObject var appManager: AppManager

    var body: some View {
        VStack(spacing: 0) {
            // 검색 바
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("앱 검색...", text: $appManager.searchText)
                    .textFieldStyle(.plain)
                if !appManager.searchText.isEmpty {
                    Button(action: { appManager.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))

            HStack {
                Toggle("시스템 앱 포함", isOn: $appManager.showSystemApps)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { appManager.scanApps() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .disabled(appManager.isScanning)
                .help("앱 목록 재스캔")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)

            Divider()

            // 앱 목록
            if appManager.isScanning {
                Spacer()
                ProgressView("앱 스캔 중...")
                Spacer()
            } else if appManager.filteredApps.isEmpty {
                Spacer()
                Text("앱을 찾을 수 없습니다")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(appManager.filteredApps, selection: Binding<AppInfo?>(
                    get: { appManager.selectedApp },
                    set: { app in
                        if let app = app {
                            appManager.selectApp(app)
                        }
                    }
                )) { app in
                    AppRowView(app: app)
                        .tag(app)
                }
                .listStyle(.sidebar)
            }

            Divider()

            // 드래그 앤 드롭 안내
            DropZoneView()
        }
    }
}

struct AppRowView: View {
    let app: AppInfo

    var body: some View {
        HStack(spacing: 10) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.fill")
                    .font(.title)
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if app.isSystemApp {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    if let desc = app.appDescription {
                        Text(desc)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                if app.isSizeCalculated {
                    Text(app.formattedSize)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("계산 중...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct DropZoneView: View {
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.down.app")
                .font(.title2)
                .foregroundColor(.secondary)
            Text(".app 파일을 여기에 드롭")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundColor(isTargeted ? .accentColor : .secondary.opacity(0.3))
        )
        .padding(8)
    }
}
