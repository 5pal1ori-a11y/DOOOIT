import Anthropic from "@anthropic-ai/sdk";

/**
 * DOOOIT 문제 읽기 서버 (Cloudflare Worker)
 * POST /read-problem  { image: base64, mediaType: "image/jpeg" }
 * 헤더 x-dooit-key 가 APP_KEY 와 같아야 함
 * 응답 { title, text, answer }
 */
export interface Env {
  ANTHROPIC_API_KEY: string;
  APP_KEY: string;
  MODEL?: string;
}

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const MEDIA_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
type MediaType = (typeof MEDIA_TYPES)[number];

const PROMPT = `이 사진은 한국 수학 문제집/시험지의 문제 한 개입니다. 인쇄된 문제를 그대로 옮겨 적어주세요.

규칙:
- 인쇄된 글자만 옮깁니다. 손글씨, 풀이 흔적, 낙서, 채점 표시는 무시합니다.
- 문제를 풀지 마세요. 사진에 없는 내용을 추가하지 마세요.
- 기울어진(이탤릭) 변수 x, y, a, b, n 등을 숫자(2, 0, 6, 1)나 J, V로 착각하지 마세요. 문맥상 변수면 변수로 씁니다.
- 수식 표기: 거듭제곱 x², x³ (그 외 x^(n)), 루트 √(x+1), 분수 (a)/(b), 곱하기 ×, 나누기 ÷, 부등호 ≤ ≥ ≠, 파이 π, 각 ∠, 절댓값 |x|.
- 선택지 ①②③④⑤ 는 한 줄에 하나씩 씁니다. 문단 줄바꿈은 원본을 따르세요.
- 그림/그래프가 있으면 그 자리에 [그림] 이라고만 씁니다.

title: 문제 번호와 핵심을 20자 이내로 (예: "12번 이차함수 꼭짓점")
text: 옮겨 적은 문제 전체
answer: 사진에 '정답' 또는 '답'이 인쇄돼 있을 때만 그 값, 없으면 빈 문자열`;

const SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string" },
    text: { type: "string" },
    answer: { type: "string" },
  },
  required: ["title", "text", "answer"],
  additionalProperties: false,
} as const;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

/** 길이가 달라도 시간 차이로 키가 새지 않게 비교 */
function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/health") return json({ ok: true });
    if (url.pathname !== "/read-problem") return json({ error: "not_found" }, 404);
    if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

    if (!env.APP_KEY || !safeEqual(request.headers.get("x-dooit-key") ?? "", env.APP_KEY)) {
      return json({ error: "unauthorized" }, 401);
    }
    if (!env.ANTHROPIC_API_KEY) return json({ error: "server_not_configured" }, 500);

    let image: string;
    let mediaType: MediaType = "image/jpeg";
    try {
      const body = (await request.json()) as { image?: unknown; mediaType?: unknown };
      if (typeof body.image !== "string" || body.image.length === 0) throw new Error("no image");
      image = body.image;
      if (typeof body.mediaType === "string" && (MEDIA_TYPES as readonly string[]).includes(body.mediaType)) {
        mediaType = body.mediaType as MediaType;
      }
    } catch {
      return json({ error: "bad_request" }, 400);
    }
    if (image.length * 0.75 > MAX_IMAGE_BYTES) return json({ error: "image_too_large" }, 413);

    const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY, maxRetries: 2 });

    try {
      const message = await client.messages.create({
        model: env.MODEL || "claude-opus-5-5",
        max_tokens: 2048,
        output_config: { format: { type: "json_schema", schema: SCHEMA } },
        messages: [
          {
            role: "user",
            content: [
              { type: "image", source: { type: "base64", media_type: mediaType, data: image } },
              { type: "text", text: PROMPT },
            ],
          },
        ],
      });

      if (message.stop_reason === "refusal") return json({ error: "refused" }, 422);

      const text = message.content
        .filter((block): block is Anthropic.TextBlock => block.type === "text")
        .map((block) => block.text)
        .join("");
      const parsed = JSON.parse(text) as { title?: string; text?: string; answer?: string };
      return json({
        title: (parsed.title ?? "").trim(),
        text: (parsed.text ?? "").trim(),
        answer: (parsed.answer ?? "").trim(),
      });
    } catch (error) {
      if (error instanceof Anthropic.RateLimitError) return json({ error: "rate_limited" }, 429);
      if (error instanceof Anthropic.AuthenticationError) {
        console.error("Anthropic API key rejected");
        return json({ error: "server_key_invalid" }, 502);
      }
      if (error instanceof Anthropic.APIError) {
        console.error("Anthropic API error", error.status, error.message);
        return json({ error: "upstream_error" }, 502);
      }
      console.error("read-problem failed", error);
      return json({ error: "internal_error" }, 500);
    }
  },
};
