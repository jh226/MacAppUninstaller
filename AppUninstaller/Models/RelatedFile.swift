import Foundation

struct RelatedFile: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let size: Int64
    var isSelected: Bool = true

    var fileName: String {
        (path as NSString).lastPathComponent
    }

    var category: FileCategory {
        if path.contains("/Caches/") { return .cache }
        if path.contains("/Preferences/") { return .preferences }
        if path.contains("/Application Support/") { return .applicationSupport }
        if path.contains("/Logs/") { return .logs }
        if path.contains("/Containers/") { return .containers }
        if path.contains("/Saved Application State/") { return .savedState }
        if path.contains("/Cookies/") { return .cookies }
        if path.contains("/WebKit/") { return .webData }
        if path.contains("/Crash Reporter/") || path.contains("/DiagnosticReports/") { return .crashReports }
        return .other
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RelatedFile, rhs: RelatedFile) -> Bool {
        lhs.id == rhs.id
    }
}

enum FileCategory: String, CaseIterable {
    case cache = "캐시"
    case preferences = "설정 파일"
    case applicationSupport = "앱 지원 파일"
    case logs = "로그"
    case containers = "컨테이너"
    case savedState = "저장된 상태"
    case cookies = "쿠키"
    case webData = "웹 데이터"
    case crashReports = "충돌 리포트"
    case other = "기타"
}
