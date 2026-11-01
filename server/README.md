# DOOOIT 문제 읽기 서버 (Claude)

앱이 오답노트 문제 사진을 이 서버로 보내면, 서버가 Claude에게 사진을 읽게 하고 글자만 돌려줍니다.
Anthropic API 키는 **서버에만** 있고 앱에는 들어가지 않습니다.

## 비용 (문제 1개 기준, 대략)

| MODEL | 정확도 | 문제당 |
|---|---|---|
| `claude-opus-5-5` (기본) | 가장 정확 | 약 20~55원 |
| `claude-sonnet-5-5` | 충분히 정확 | 약 10~30원 |
| `claude-haiku-5-5` | 단순한 문제 위주 | 약 0.5~1.5원 |

바꾸려면 `wrangler.toml`의 `MODEL` 값을 고치고 다시 배포하세요.

## 설치 (PC에서 한 번만)

준비물: Node.js 20 이상, [Cloudflare 계정](https://dash.cloudflare.com/sign-up)(무료), [Anthropic API 키](https://console.anthropic.com/)

```bash
cd server
npm install
npx wrangler login
```

```bash
npx wrangler secret put ANTHROPIC_API_KEY
```
(Anthropic 콘솔에서 받은 `sk-ant-...` 키 붙여넣기)

```bash
npx wrangler secret put APP_KEY
```
(앱과 서버가 공유할 아무 긴 문자열. 예: 비밀번호 생성기로 만든 32자)

```bash
npx wrangler deploy
```

배포가 끝나면 `https://dooit-reader.<내계정>.workers.dev` 주소가 나옵니다.
브라우저에서 `/health`를 열어 `{"ok":true}`가 보이면 성공입니다.

## 앱에 연결

GitHub 레포 → Settings → Secrets and variables → Actions 에 두 개 추가:

| 이름 | 값 |
|---|---|
| `DOOOIT_READER_URL` | 위 주소 (`https://...workers.dev`, 끝에 `/` 없이) |
| `DOOOIT_READER_KEY` | 위에서 정한 `APP_KEY`와 같은 값 |

그다음 TestFlight 빌드를 다시 돌리면, 오답노트에 **Claude로 정확하게 읽기** 버튼이 나오고
새 문제를 찍을 때도 Claude가 먼저 읽습니다. (서버가 안 되면 자동으로 기기 안 인식으로 돌아갑니다)

## 꼭 알아둘 것

- **지출 한도 설정**: Anthropic 콘솔 → Billing → 월 사용 한도를 정해두세요.
- `APP_KEY`는 앱 안에 들어가므로, 마음먹고 앱을 분해하면 꺼낼 수 있습니다. 혼자/지인끼리 쓰는 용도로는 충분하지만,
  공개 출시하려면 로그인 기반 인증이나 사용자별 사용량 제한을 추가해야 합니다.
  키가 샜다고 생각되면 `npx wrangler secret put APP_KEY`로 바꾸고 GitHub 시크릿도 같이 바꾼 뒤 다시 빌드하세요.
- 서버 로그 보기: `npx wrangler tail`
