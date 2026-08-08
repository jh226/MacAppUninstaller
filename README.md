# App Uninstaller

macOS 앱과 관련 잔여 파일을 깔끔하게 삭제하는 네이티브 유틸리티 앱입니다.

## 기능

- **앱 스캔** — `/Applications` 폴더에서 설치된 앱 자동 탐지
- **관련 파일 탐색** — Bundle ID 기반으로 `~/Library` 하위 잔여 파일 탐색 (캐시, 설정, 로그, 컨테이너 등)
- **Spotlight 연동** — `mdfind`를 활용한 추가 파일 검색
- **카테고리별 분류** — 캐시, 설정 파일, 로그, 컨테이너 등 9개 카테고리로 그룹화
- **선택적 삭제** — 체크박스로 파일별 삭제 여부 선택
- **드래그 앤 드롭** — `.app` 파일을 창에 드롭하면 바로 삭제 플로우 시작
- **안전한 삭제** — 영구 삭제가 아닌 휴지통으로 이동 (복구 가능)

## 스크린샷

> TODO: 스크린샷 추가

## 요구 사항

- macOS 13.0 (Ventura) 이상
- Xcode 15.0 이상

## 빌드 및 실행

```bash
# Xcode에서 열기
open AppUninstaller.xcodeproj

# 또는 CLI로 빌드
xcodebuild -project AppUninstaller.xcodeproj -scheme AppUninstaller -configuration Debug build
```

## 기술 스택

- **Swift 5** + **SwiftUI**
- macOS 네이티브 API (`FileManager`, `NSWorkspace`, `mdfind`)

## 프로젝트 구조

```
AppUninstaller/
├── AppUninstallerApp.swift     # 앱 진입점
├── Models/
│   ├── AppInfo.swift           # 앱 정보 모델
│   └── RelatedFile.swift       # 관련 파일 모델 + 카테고리
├── Views/
│   ├── ContentView.swift       # 메인 레이아웃 (좌우 분할)
│   ├── AppListView.swift       # 앱 목록 + 검색 + 드롭존
│   └── DetailView.swift        # 파일 상세 + 삭제 버튼
└── Services/
    ├── AppScanner.swift        # /Applications 스캔
    ├── FileSearcher.swift      # Bundle ID 기반 관련 파일 탐색
    └── AppManager.swift        # 상태 관리 (ViewModel)
```

## 라이선스

MIT License
