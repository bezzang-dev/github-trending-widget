# GitHub Trending 위젯 (macOS)

[English](README.md) | **한국어**

macOS 알림 센터 / 데스크톱에 [github.com/trending](https://github.com/trending) 상위 레포를 보여주는 WidgetKit 위젯입니다.
SwiftUI + WidgetKit + AppIntents만 사용하고 외부 라이브러리는 없습니다.

- macOS 14(Sonoma) 이상
- 크기: **중간(systemMedium)** 한 줄 압축(최대 7개, 6개 이상이면 글자 축소), **대형(systemLarge)** 설명·언어·스타·포크 포함 (7개는 설명까지, 10개는 한 줄 압축)
- 위젯 편집에서 **언어 / 기간 / 사용 언어 / 표시 개수(3·5·7·10) / 갱신 주기 / 표시 언어** 선택
- 표시 언어: 시스템 설정 / 한국어 / English (위젯 본문 문구와 시각 포맷에 적용)
- 성공 시 설정한 갱신 주기(기본 1시간, 15분~12시간), 실패 시 최대 15분 뒤 재시도. 실패하면 마지막 성공 결과(캐시) + ⚠️ 아이콘 표시
- 각 행을 클릭하면 브라우저에서 해당 레포가 열림

## 구조

```
.
├── project.yml                  # XcodeGen 설정. .xcodeproj는 여기서 생성됨 (git 미포함)
├── Signing.example.xcconfig     # 팀 ID 설정 예시 → Signing.xcconfig로 복사해서 사용
├── App/
│   └── GitHubTrendingApp.swift  # 호스트 앱: 안내 화면 + 위젯 클릭 URL을 브라우저로 전달
├── Widget/                      # 위젯 익스텐션 타깃 (TrendingWidget.appex)
│   ├── TrendingIntent.swift     # 설정 옵션 AppEnum + WidgetConfigurationIntent + URL 생성
│   ├── TrendingStrings.swift    # 위젯 본문 문구 테이블 (표시 언어별 한/영)
│   ├── TrendingModels.swift     # TrendingRepo / TrendingSnapshot + 샘플 데이터
│   ├── TrendingParser.swift     # HTML 파서. GitHub 구조가 바뀌면 이 파일만 수정
│   ├── TrendingService.swift    # 요청(Safari UA) → 파싱 → UserDefaults 캐시
│   └── TrendingWidget.swift     # Entry, Provider(타임라인), 뷰, Widget, WidgetBundle, #Preview
└── Tests/
    ├── Fixtures/*.html          # curl로 받아 둔 실제 Trending 페이지
    ├── ParserTests.swift        # 파서 테스트
    └── run_parser_tests.sh      # 테스트 실행 스크립트 (Xcode 없이 Command Line Tools만으로 동작)
```

### 위젯 동작 방식

위젯은 상시 실행되는 프로그램이 아닙니다. 시스템 데몬(`chronod`)이 필요할 때 익스텐션을 잠깐 깨워
`timeline(for:in:)`을 호출하고, 받은 Entry 목록과 다음 갱신 시각(`.after(date)`)을 저장한 뒤 익스텐션을 종료합니다.
그래서 타이머 대신 **타임라인 정책**으로 갱신 주기를 지정합니다. (시스템이 배터리 등을 고려해 실제 갱신을 조금 늦출 수 있습니다.)

GitHub에는 Trending API가 없어서 페이지 HTML을 직접 파싱합니다. 항상 상위 10개를 받아 캐시하고, 위젯 크기와 표시 개수에 맞게 잘라서 그립니다.

## 실행 방법

### 1. Xcode 준비

```bash
xcode-select -p
```

`/Applications/Xcode.app/Contents/Developer`가 아니라 `/Library/Developer/CommandLineTools`가 나오면 전환합니다.
(Xcode는 App Store에서 설치. 설치 후 한 번 실행해서 추가 구성요소 설치를 끝내야 합니다.)

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

```bash
sudo xcodebuild -license accept
```

### 2. 서명 (Personal Team)

1. Xcode → Settings → Accounts → `+` → Apple ID 로그인 → Personal Team 생성
2. 팀 ID 확인 (Accounts 화면의 팀 항목, 또는 아래 명령의 `OU=` 값)

```bash
security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
```

3. 예시 파일을 복사하고 `DEVELOPMENT_TEAM = ` 뒤에 10자리 팀 ID 입력 (`Signing.xcconfig`는 git에 올라가지 않음)

```bash
cp Signing.example.xcconfig Signing.xcconfig
```

> 번들 ID `com.jmkim.GitHubTrending`이 이미 사용 중이라는 에러가 나면 `project.yml`의 두 `PRODUCT_BUNDLE_IDENTIFIER`를 고유한 값으로 바꾸세요 (위젯 ID는 반드시 앱 ID + `.접미사`).

### 3. 프로젝트 생성 & 빌드

```bash
brew install xcodegen
```

```bash
xcodegen generate
```

```bash
xcodebuild -project GitHubTrending.xcodeproj -scheme GitHubTrending -configuration Debug -derivedDataPath build -allowProvisioningUpdates build
```

### 4. 실행 & 위젯 추가

```bash
open build/Build/Products/Debug/GitHubTrending.app
```

앱을 한 번 실행해야 시스템이 위젯을 등록합니다. 그다음:

1. 메뉴 막대 오른쪽의 **날짜/시계**를 클릭 → 알림 센터 열기
2. 맨 아래 **위젯 편집…** 클릭 (또는 데스크톱 우클릭 → 위젯 편집…)
3. 왼쪽 목록에서 **GitHubTrending** 선택 → 중간/대형 위젯을 끌어다 놓기
4. 위젯 **우클릭 → "위젯 편집"** 에서 언어·기간·사용 언어·표시 개수·갱신 주기·표시 언어 선택

> 앱을 `/Applications`로 복사해 두면 재부팅 후에도 위젯이 안정적으로 유지됩니다.
> 단, 이후에는 **빌드할 때마다 다시 복사**해야 합니다. 그렇지 않으면 시스템이 `/Applications`의 옛 버전을 계속 실행합니다.
>
> ```bash
> rm -rf /Applications/GitHubTrending.app && cp -R build/Build/Products/Debug/GitHubTrending.app /Applications/
> ```

### 파서 테스트

```bash
./Tests/run_parser_tests.sh
```

실제 페이지를 다시 받아 구조가 바뀌지 않았는지 확인하려면:

```bash
./Tests/run_parser_tests.sh --refresh
```

## 자주 나는 문제

### 위젯 목록에 안 뜸 / 수정한 코드가 반영 안 됨

1. 앱을 한 번 실행했는지 확인 (실행해야 등록됨)
2. 같은 앱이 여러 위치(`build/`, DerivedData, `/Applications`)에 있으면 옛 버전이 실행될 수 있습니다. 실제로 실행 중인 위젯 프로세스의 경로를 확인하세요.

```bash
ps -axo command | grep TrendingWidget.appex | grep -v grep
```

   `/Applications` 쪽이 옛 버전이면 위의 복사 명령으로 교체하거나, 하나만 남기고 지운 뒤 Launch Services 등록을 갱신합니다.

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted build/Build/Products/Debug/GitHubTrending.app
```

3. 위젯 관련 프로세스 재시작 (자동으로 다시 뜸)

```bash
killall TrendingWidget NotificationCenter chronod
```

4. 시스템이 익스텐션을 인식했는지 확인 (`+`가 붙어 있으면 활성)

```bash
pluginkit -mAvvv -p com.apple.widgetkit-extension | grep -i -A3 trending
```

5. 그래도 안 되면 위젯을 제거했다가 다시 추가, 최후에는 로그아웃/재부팅.

### 위젯이 "불러오지 못했어요"만 표시

- 위젯 entitlements에 `com.apple.security.network.client`가 있는지 확인 (없으면 샌드박스가 네트워크 차단)

```bash
codesign -d --entitlements - build/Build/Products/Debug/GitHubTrending.app/Contents/PlugIns/TrendingWidget.appex
```

- 로그 확인: Console.app에서 `TrendingWidget` 프로세스로 필터
- GitHub HTML 구조가 바뀌었을 수 있음 → `./Tests/run_parser_tests.sh --refresh`로 확인 후 `TrendingParser.swift` 수정

### 헤더에 ⚠️ 아이콘

마지막 갱신이 실패해서 캐시된 결과를 보여주는 중입니다. 15분(갱신 주기가 더 짧으면 그 주기) 뒤 자동 재시도합니다.

### 서명 에러 (`No Account for Team`, `requires a development team`)

`Signing.xcconfig`에 팀 ID를 넣고 `xcodegen generate`를 다시 실행하세요. Xcode에 Apple ID가 로그인되어 있어야 합니다.

### Swift 6 동시성 에러

이 프로젝트는 `SWIFT_VERSION = 6.0`(엄격한 동시성 검사)입니다. 자주 만나는 것:

- **`static var ... is not concurrency-safe`**: 가변 전역 상태는 금지됩니다. 바꿀 일이 없으면 `static let`으로 (AppEnum의 `caseDisplayRepresentations` 등).
- **`Main actor-isolated ... cannot be referenced from a nonisolated context`**: SwiftUI `View`는 MainActor에 묶여 있습니다. Provider처럼 백그라운드에서 도는 코드와 공유할 로직은 View 밖의 `Sendable` 타입으로 빼세요.
- **`Non-sendable type ... crossing actor boundary`**: 동시성 경계를 넘는 값은 `Sendable`이어야 합니다. 이 프로젝트는 Intent를 그대로 넘기지 않고 `TrendingQuery`(Sendable struct)로 변환해서 넘깁니다.

### Xcode 캔버스에서 #Preview가 안 보임

`TrendingWidget.swift`를 열고 캔버스에서 스킴을 **TrendingWidget**으로 선택하세요. 프리뷰는 `#if DEBUG` 안에 있어 Debug 구성에서만 컴파일됩니다.
