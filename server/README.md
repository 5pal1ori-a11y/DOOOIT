# DOOOIT 문제 읽기 서버 (Claude)

앱이 오답노트 문제 사진을 이 서버로 보내면, 서버가 Claude에게 사진을 읽게 하고 글자만 돌려줍니다.
Anthropic API 키는 **서버에만** 있고 앱에는 들어가지 않습니다.
서버가 없거나 실패하면 앱은 자동으로 기기 안 글자 인식을 씁니다.

## 비용 (문제 1개 기준, 대략)

| MODEL (`wrangler.toml`) | 정확도 | 문제당 |
|---|---|---|
| `claude-opus-5-5` (기본) | 가장 정확 | 약 20~55원 |
| `claude-sonnet-5-5` | 충분히 정확 | 약 10~30원 |
| `claude-haiku-5-5` | 단순한 문제 위주 | 약 0.5~1.5원 |

## 설정 (PC 없이, GitHub 시크릿만)

TestFlight 빌드가 서버를 Cloudflare에 자동으로 배포하고 앱에 연결합니다.

1. **Anthropic API 키**
   - https://console.anthropic.com → API Keys → Create Key (`sk-ant-...`)
   - Billing에서 크레딧 충전 + **월 사용 한도(Spend limit)** 설정
2. **Cloudflare** (무료)
   - https://dash.cloudflare.com 가입
   - 왼쪽 메뉴 **Workers & Pages** 를 한 번 열어 `workers.dev` 하위 도메인을 정하기
   - 오른쪽 위 프로필 → **My Profile → API Tokens → Create Token → "Edit Cloudflare Workers" 템플릿** → 만들기
   - Account ID: Workers & Pages 화면 오른쪽(또는 대시보드 주소 `dash.cloudflare.com/<여기>`)
3. **GitHub** 레포 → Settings → Secrets and variables → Actions → New repository secret

| 이름 | 값 |
|---|---|
| `ANTHROPIC_API_KEY` | 1번의 `sk-ant-...` |
| `CLOUDFLARE_API_TOKEN` | 2번의 토큰 |
| `CLOUDFLARE_ACCOUNT_ID` | 2번의 Account ID |

4. TestFlight 빌드를 다시 돌리면 끝. 빌드 로그의 **Deploy Claude reader server** 단계에 서버 주소가 나옵니다.

앱 키(`APP_KEY`)는 따로 정하지 않아도 Anthropic 키에서 자동으로 만들어집니다. 직접 정하고 싶으면 `DOOOIT_READER_KEY` 시크릿을 추가하세요.

## 꼭 알아둘 것

- 앱 키는 앱 안에 들어가므로, 마음먹고 앱을 분해하면 꺼낼 수 있습니다. 개인·지인용으로는 충분하지만 공개 출시하려면 로그인 기반 인증·사용량 제한이 필요합니다. 그래서 **Spend limit**을 꼭 걸어두세요.
- 키가 샜다고 생각되면 `DOOOIT_READER_KEY` 시크릿을 새 값으로 넣고 다시 빌드하면 바뀝니다.

## PC에서 직접 배포하고 싶을 때

```bash
cd server
npm install
npx wrangler login
npx wrangler deploy
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put APP_KEY
```

그다음 GitHub 시크릿 `DOOOIT_READER_URL`(배포 주소), `DOOOIT_READER_KEY`(APP_KEY와 같은 값)를 넣고 빌드하세요.
