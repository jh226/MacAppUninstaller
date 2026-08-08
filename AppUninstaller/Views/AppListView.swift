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
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(app.formattedSize)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
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
