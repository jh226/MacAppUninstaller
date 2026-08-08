import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appManager: AppManager

    var body: some View {
        HSplitView {
            // 왼쪽: 앱 목록
            AppListView()
                .frame(minWidth: 280, maxWidth: 350)

            // 오른쪽: 선택된 앱의 관련 파일 상세
            DetailView()
                .frame(minWidth: 450)
        }
        .onAppear {
            appManager.scanApps()
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .alert("삭제 완료", isPresented: $appManager.deleteComplete) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("앱과 관련 파일이 휴지통으로 이동되었습니다.")
        }
        .alert("삭제 오류", isPresented: .init(
            get: { appManager.deleteError != nil },
            set: { if !$0 { appManager.deleteError = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(appManager.deleteError ?? "")
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                if let data = data as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        appManager.handleDroppedApp(url: url)
                    }
                }
            }
        }
        return true
    }
}
