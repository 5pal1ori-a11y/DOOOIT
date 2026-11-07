---
title: Friends and groups: CloudKit schema
---

# 친구 · 그룹: CloudKit 스키마 올리기 (개발자가 한 번 해야 해요)

친구 · 그룹은 서버 없이 CloudKit **공용(Public) 데이터베이스**(컨테이너 `iCloud.com.donghyeon.moti`)를 써요.
앱이 쓰는 기록 종류 네 개(`MotiProfile`, `StudyGroup`, `GroupMember`, `MotiReport`)는 `Config/CloudKitSchema.ckdb` 맨 아래에 이미 들어 있어요.
이 파일을 CloudKit에 올리지 않으면 앱의 친구 · 그룹 화면은 "지금은 친구 기능을 쓸 수 없어요"라고 보여요 (앱은 멈추지 않아요).

## 올리는 방법

1. https://icloud.developer.apple.com/dashboard 에서 `iCloud.com.donghyeon.moti` 컨테이너를 열어요.
2. 위쪽 환경이 **Development**인지 확인하고 왼쪽 **Schema → Import Schema** (또는 Schema 화면의 Import) 를 눌러 `Config/CloudKitSchema.ckdb` 파일을 골라요.
   (예전에 올렸던 같은 파일이에요. 기존 `CD_…` 종류는 그대로고 새 종류 네 개만 늘어나요.)
3. Record Types에 `MotiProfile`, `StudyGroup`, `GroupMember`, `MotiReport`가 보이는지 확인해요.
4. 왼쪽 위 **Deploy Schema Changes…** → **Deploy to Production**을 눌러요. 이걸 해야 TestFlight · 앱스토어 빌드에서 동작해요 (Development 환경은 Xcode로 직접 실행한 빌드에서만 보여요).
5. (선택) **Indexes**에서 `MotiProfile.friendCode`, `MotiProfile.invitedBy`, `StudyGroup.inviteCode`, `StudyGroup.ownerProfileID`, `GroupMember.groupID`, `GroupMember.profileID`가 Queryable로 되어 있는지 봐요. 파일에 이미 들어 있어요.

가져오기에서 문법 오류가 나면 오류 문구를 알려 주세요. 같은 내용을 Console에서 손으로 만들 수도 있어요: 기록 종류마다 위 필드를 만들고, Security Roles에서 `_world` 읽기 · `_icloud` 만들기 · `_creator` 쓰기를 주면 돼요 (`MotiReport`는 `_icloud` 만들기만).

## 보안 모양

- 읽기는 누구나(`_world`), 쓰기 · 지우기는 기록을 만든 사람만(`_creator`).
- 기록 이름(recordName)은 일부러 Queryable로 열지 않아서, 프로필 목록을 훑을 수 없고 **친구 코드를 아는 사람만** 찾을 수 있어요.
- `MotiReport`(신고)는 만들기만 되고 앱에서는 읽을 수 없어요. 개발자는 Console의 Public Database → Records에서 `MotiReport`를 열어 읽어요.
- 부적절한 프로필은 Console에서 해당 `MotiProfile` 기록을 지우면 돼요 (친구 목록에서는 "불러오지 못했어요"로 보여요).

## 확인하지 못한 것

이 스키마와 앱의 CloudKit 호출은 CloudKit에 연결할 수 없는 환경에서 만들었어요. 스키마 문법 · 권한(특히 `MotiReport`의 만들기 전용) · 쿼리 인덱스는 실제로 올려서 두 기기로 확인해야 해요.
