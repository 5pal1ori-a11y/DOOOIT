# DOOOIT — 공부 플래너 (iOS 26 · Liquid Glass)

SwiftUI + SwiftData로 만든 iOS 공부 플래너 앱입니다. 화면은 iOS 26 **Liquid Glass**(`glassEffect`, `.glass` 버튼, 글라스 탭바)로 구성했고, 이모지 대신 SF Symbols 아이콘을 사용합니다.

## 기능

| 영역 | 기능 |
|---|---|
| 실행 화면 | `D O O O I T` 글자가 하나씩 나타난 뒤, 세 개의 O가 하나로 합쳐지는 애니메이션 |
| 로그인 | Apple로 계속하기 / 이메일 회원가입·로그인, 닉네임 설정 |
| 홈 | 날짜·D-Day + 시간대별 인사말(6시~12시, 12시~1시, 1시~6시, 6시~7시, 7시~0시, 0시~6시), 주간 달력(누르면 그날 타임라인), 집중 패널(오늘 공부 시간·연속 공부·플랜·복습할 오답), 타임라인형 오늘의 플랜(3개 초과 시 전체 보기), 메모지 모양 단어 카드, 원형 바로가기, 주간 차트 |
| 공부 › 영어 단어 | 단어장 촬영(문서 스캐너)/앨범 → 기기 내 OCR(Vision)로 단어·뜻 자동 추출 → 확인·수정 → 저장. 하루 목표 개수 설정. 학습: ① 메모지에 단어+뜻 보기 → ② 뜻 가리고 쓰기 → 틀린 단어 복습 후 재시험(모두 맞을 때까지) → ③ 단어 가리고 쓰기(같은 방식) → **오늘의 단어목표 성공!** 틀린 단어 모아 복습, 전체 단어 목록 |
| 공부 › 수학 오답노트 | 문제 촬영 → 글자 인식 + 사진을 모눈 노트에 배치. 펜·형광펜·지우개·올가미·텍스트, 색상/굵기, 실행 취소. 정답 자동 인식(사진에 "정답: ○" 표기가 있을 때) + 자동 채점, 안 되면 O/X 수동 채점. 여러 문제 등록·필터 |
| 공부 › 메모장 | 검색, 고정, 공유, 자동 저장 |
| 플래너 | 월간 캘린더 / 하루 타임라인(시간 눈금, 현재 시각 선, 겹치는 일정 나란히 표시), 반복(매일·매주·매달·매년, 종료일). **일반 플랜**: 카테고리 + 플랜별 알림(없음·정시·5/10/30/60분 전). **공부 플랜**: 과목(기본 국어·영어·수학, 추가 가능) + 자동 타이머 + **다른 앱 잠금**. 시간은 휠에서 고른 뒤 "완료"를 눌러야 반영 |
| 통계 | 일간/주간/월간, 총 집중 시간, 과목별 비율 막대와 목록, 이전 기간 대비 증감, 6개 기간 추이 그래프, 시간대별 집중 분포 |
| 공부 타이머 | 공부 카테고리 일정 N분 전 → 다이나믹 아일랜드/잠금화면에 남은 시간 표시, 시작 시각 → 타이머 자동 실행. 탭바 위 미니 플레이어, 일시정지/종료, 기록 저장 |
| 계정 | 프로필·이름 변경, 통계, 단어/공부 목표, D-Day, 알림·다이나믹 아일랜드·자동 시작 설정, 카테고리 관리, 화면 모드, 로그아웃, 계정 삭제(데이터 전체 삭제) |

## 앱 잠금 켜기 (공부 플랜의 "다른 앱 잠금")

앱 잠금은 Apple의 스크린 타임 API(FamilyControls · ManagedSettings · DeviceActivity)를 씁니다.
이 권한은 **Apple 승인이 있어야 TestFlight/App Store 빌드에 넣을 수 있어서**, 기본값은 꺼져 있습니다(꺼져 있으면 토글을 켤 때 안내 문구가 나오고 나머지 기능은 정상 동작).

1. https://developer.apple.com/contact/request/family-controls-distribution 에서 Family Controls (Distribution) 사용을 신청합니다. 앱(`com.bravekoon.dooit`)과 잠금 익스텐션(`com.bravekoon.dooit.activitymonitor`) 둘 다 필요합니다.
2. 승인되면 Xcode → 프로젝트 → Build Settings에서 `DOOOIT_APPLOCK_SUFFIX` 값을 `-AppLock`으로 바꿉니다. (두 타깃이 `*-AppLock.entitlements`를 쓰게 됩니다)
   - 승인 전에도 실기기 개발 빌드에서는 같은 방법으로 시험해볼 수 있습니다(Development 권한).
3. 동작 방식
   - 플랜 저장 시 앞으로 7일간의 잠금 공부 플랜(최대 15개)을 DeviceActivity 일정으로 등록 → 앱이 꺼져 있어도 시작 시각에 잠기고 종료 시각에 풀립니다(`DOOOITActivityMonitor` 익스텐션).
   - 15분보다 짧은 플랜은 iOS 제한으로 예약이 안 되어, 앱이 켜져 있을 때 타이머 시작과 함께 잠급니다.
   - 타이머를 중간에 끝내면 잠금도 해제됩니다.
   - **실기기에서 꼭 확인할 것**: 잠금 상태에서 DOOOIT 자체는 열리는지. 만약 DOOOIT까지 잠기면 알려주세요(제외 목록 방식으로 바꿔야 합니다).

## 실행 방법

필요한 것: **Mac + Xcode 26 이상**, TestFlight 배포에는 **Apple Developer Program(유료) 가입**이 필요합니다.

1. `DOOOIT.xcodeproj`를 Xcode로 엽니다.
   (열리지 않으면 `brew install xcodegen` 후 이 폴더에서 `xcodegen generate`)
2. 프로젝트 → **DOOOIT** 타깃 → *Signing & Capabilities*
   - Team: 본인 개발자 계정 선택
   - Bundle Identifier: `com.bravekoon.dooit` → 본인만의 값으로 변경 (예: `com.내이름.dooit`)
3. **DOOOITWidgetsExtension**, **DOOOITActivityMonitor** 타깃도 같은 Team을 선택합니다. (Bundle ID는 `com.bravekoon.dooit.widgets`, `com.bravekoon.dooit.activitymonitor`)
4. 실제 iPhone을 연결해 실행합니다. (다이나믹 아일랜드, 문서 스캐너, Apple 로그인은 실기기에서 확인하는 것이 정확합니다)

## TestFlight 업로드

1. [App Store Connect](https://appstoreconnect.apple.com) → 나의 앱 → **+ 신규 앱** → 위에서 정한 Bundle ID로 생성
2. Xcode 상단 실행 대상을 **Any iOS Device (arm64)** 로 선택
3. **Product → Archive**
4. Organizer 창에서 **Distribute App → App Store Connect → Upload**
5. 처리 완료(보통 10~30분) 후 App Store Connect → **TestFlight** 탭에서 테스터 추가
   - 다시 올릴 때는 `CURRENT_PROJECT_VERSION`(빌드 번호)을 1씩 올려야 합니다.
   - 수출 규정(암호화) 질문은 `ITSAppUsesNonExemptEncryption = NO`로 미리 설정해 두었습니다.

## 알아두어야 할 제한 사항

- **빌드 미검증**: 이 프로젝트는 Mac이 아닌 환경에서 작성되어 Xcode로 컴파일해 보지 못했습니다. Swift 구문 검사만 통과한 상태라, 첫 빌드에서 타입 오류가 몇 개 나올 수 있습니다. 오류 메시지를 알려주시면 바로 고치겠습니다.
- **계정은 기기 안에만 저장**됩니다(Keychain). 서버가 없어서 기기 간 동기화가 되지 않고, 앱을 지우면 데이터도 지워집니다. 실제 서비스로 운영하려면 Firebase Auth / Supabase 같은 백엔드 연동이 필요합니다. Apple 로그인 토큰 철회(revoke)도 서버가 있어야 완전히 처리됩니다.
- **다이나믹 아일랜드 자동 시작**: iOS 정책상, 앱이 완전히 종료된 상태에서는 푸시 서버 없이 Live Activity를 새로 띄울 수 없습니다. 그래서
  - 앱이 실행 중이거나 최근에 열려 있었으면 → 다이나믹 아일랜드 카운트다운과 타이머 자동 시작이 동작하고,
  - 앱이 꺼져 있으면 → **N분 전 / 시작 시각에 알림**이 오며, 알림을 누르면 타이머가 자동으로 시작되고 다이나믹 아일랜드가 켜집니다.
  - 완전한 백그라운드 자동 시작을 원하면 APNs 푸시 서버(push-to-start)가 필요합니다.
- **수학 자동 채점**은 정답이 입력되어 있거나 사진 속에 "정답/답" 표기가 있을 때 내 답과 비교하는 방식입니다. 문제를 직접 풀어서 채점하지는 않습니다(AI 연동 필요). 그 외에는 O/X 수동 채점을 사용합니다.
- **OCR 정확도**: 인쇄된 단어장은 잘 읽지만, 손글씨나 복잡한 배치는 틀릴 수 있어 저장 전 확인·수정 화면을 두었습니다. 수식은 일반 텍스트 수준으로만 인식됩니다.

## 폴더 구조

```
DOOOIT/
├─ DOOOIT.xcodeproj
├─ project.yml                 # XcodeGen 백업
├─ Config/                     # Info.plist, entitlements(Apple 로그인)
├─ Shared/                     # 앱·위젯 공용 Live Activity 모델
├─ DOOOITWidgets/              # 다이나믹 아일랜드 / 잠금화면 Live Activity
├─ DOOOITActivityMonitor/      # 공부 플랜 시간에 다른 앱을 잠그고 푸는 익스텐션
└─ DOOOIT/
   ├─ App/                     # 앱 진입점, 루트/탭
   ├─ Design/                  # Liquid Glass 테마, 공용 컴포넌트
   ├─ Models/                  # SwiftData 모델 (플랜, 카테고리, 단어, 오답노트, 메모, 공부기록)
   ├─ Services/                # 로그인, OCR, 단어 파서, 채점, 알림, Live Activity, 타이머, 일정 감시
   ├─ Utilities/               # 날짜, 스캐너/사진 선택
   └─ Features/                # Splash, Auth, Home, Study(Words/Math/Memo), Planner, Stats, Account, Timer, Shared
```
