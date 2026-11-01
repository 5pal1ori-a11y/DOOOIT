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

const PROMPT = `이 사진은 한국 수학 문제집/시험지의 문제입니다. 검은색으로 인쇄된 문제를 그대로 옮겨 적어주세요.

규칙:
- 검은색 인쇄 글자만 옮깁니다. 빨간·파란 펜, 연필 풀이, 동그라미·체크 같은 채점 표시, 낙서는 전부 무시합니다.
- 문제를 풀지 마세요. 사진에 없는 내용을 추가하지 마세요.
- 기울어진(이탤릭) 변수 x, y, a, b, c, n, k 를 숫자나 다른 글자로 착각하지 마세요.
- 작은 위첨자(지수)를 놓치지 마세요: x², x³, x⁴, (x+1)², aⁿ. 아래첨자: aₙ, a₁, x₁, log₂.
- 수식 표기: 루트 √(x+1), 세제곱근 ³√x, 분수 (분자)/(분모), 곱하기 ×, 나누기 ÷, 부등호 ≤ ≥ ≠ < >, ±, π, α β θ, ∠, △, ⊥, °, 절댓값 |x|, 극한 lim(x→1), 미분 f'(x), 적분 ∫, 합 Σ, 순열·조합 ₙPᵣ ₙCᵣ, 집합 ∈ ⊂ ∪ ∩ ∅.
- 범위가 애매하면 괄호로 분명히 씁니다. 예: √(3x+1), (x+1)/(x-2).
- 선택지 ①②③④⑤ 는 한 줄에 하나씩, 보기 ㄱ. ㄴ. ㄷ. 도 한 줄에 하나씩 씁니다.
- 배점 [3점] 등은 남기고, 출처·쪽 번호는 뺍니다.
- 그림/그래프가 있으면 그 자리에 [그림] 이라고만 씁니다.

title: 문제 번호 없이 핵심만 20자 이내 (예: "삼차방정식 허근", "이차함수 접선")
text: 옮겨 적은 문제 전체 (문제 번호는 빼고)
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

type ImageInput = { data: string; mediaType?: string };

function imageBlocks(images: unknown): Anthropic.ImageBlockParam[] {
  if (!Array.isArray(images)) return [];
  return images.slice(0, 4).flatMap((item): Anthropic.ImageBlockParam[] => {
    const image = item as ImageInput;
    if (typeof image?.data !== "string" || image.data.length === 0) return [];
    if (image.data.length * 0.75 > MAX_IMAGE_BYTES) return [];
    const mediaType = (MEDIA_TYPES as readonly string[]).includes(image.mediaType ?? "")
      ? (image.mediaType as MediaType)
      : "image/jpeg";
    return [{ type: "image", source: { type: "base64", media_type: mediaType, data: image.data } }];
  });
}

function textOf(message: Anthropic.Message): string {
  return message.content
    .filter((block): block is Anthropic.TextBlock => block.type === "text")
    .map((block) => block.text)
    .join("");
}

function errorResponse(error: unknown, where: string): Response {
  if (error instanceof Anthropic.RateLimitError) return json({ error: "rate_limited" }, 429);
  if (error instanceof Anthropic.AuthenticationError) {
    console.error("Anthropic API key rejected");
    return json({ error: "server_key_invalid" }, 502);
  }
  if (error instanceof Anthropic.BadRequestError) {
    console.error(where, "bad request", error.message);
    return json({ error: "bad_request" }, 400);
  }
  if (error instanceof Anthropic.APIError) {
    console.error(where, "Anthropic API error", error.status, error.message);
    return json({ error: "upstream_error" }, 502);
  }
  console.error(where, "failed", error);
  return json({ error: "internal_error" }, 500);
}

/** 문제 사진 읽기 (오답노트) */
async function readProblem(body: { image?: unknown; mediaType?: unknown }, client: Anthropic, model: string): Promise<Response> {
  const images = imageBlocks([{ data: body.image, mediaType: body.mediaType }]);
  if (images.length === 0) return json({ error: "bad_request" }, 400);
  const message = await client.messages.create({
    model,
    max_tokens: 2048,
    output_config: { format: { type: "json_schema", schema: SCHEMA } },
    messages: [{ role: "user", content: [...images, { type: "text", text: PROMPT }] }],
  });
  if (message.stop_reason === "refusal") return json({ error: "refused" }, 422);
  const parsed = JSON.parse(textOf(message)) as { title?: string; text?: string; answer?: string };
  return json({
    title: (parsed.title ?? "").trim(),
    text: (parsed.text ?? "").trim(),
    answer: (parsed.answer ?? "").trim(),
  });
}

/** 한 번 묻고 답하기: schema가 있으면 그 JSON 형태로, 없으면 글로 */
async function generate(
  body: { system?: unknown; prompt?: unknown; schema?: unknown; images?: unknown; maxTokens?: unknown },
  client: Anthropic,
  model: string,
): Promise<Response> {
  if (typeof body.prompt !== "string" || body.prompt.length === 0 || body.prompt.length > 20_000) {
    return json({ error: "bad_request" }, 400);
  }
  const schema = body.schema && typeof body.schema === "object" ? (body.schema as Record<string, unknown>) : undefined;
  const maxTokens = typeof body.maxTokens === "number" ? Math.min(Math.max(body.maxTokens, 256), 8000) : 4000;
  const message = await client.messages.create({
    model,
    max_tokens: maxTokens,
    system: typeof body.system === "string" ? body.system.slice(0, 8000) : undefined,
    ...(schema ? { output_config: { format: { type: "json_schema" as const, schema } } } : {}),
    messages: [{ role: "user", content: [...imageBlocks(body.images), { type: "text", text: body.prompt }] }],
  });
  if (message.stop_reason === "refusal") return json({ error: "refused" }, 422);
  const text = textOf(message);
  if (schema) return json({ result: JSON.parse(text) });
  return json({ text: text.trim() });
}

/** 두잇 AI 대화: 앱이 보낸 대화와 도구 정의를 그대로 Claude에 넘기고, 응답 블록을 돌려줌 (도구 실행은 앱에서) */
async function chat(
  body: { system?: unknown; messages?: unknown; tools?: unknown },
  client: Anthropic,
  model: string,
): Promise<Response> {
  if (!Array.isArray(body.messages) || body.messages.length === 0 || body.messages.length > 60) {
    return json({ error: "bad_request" }, 400);
  }
  const tools = Array.isArray(body.tools) ? (body.tools.slice(0, 20) as Anthropic.Tool[]) : undefined;
  const message = await client.messages.create({
    model,
    max_tokens: 2048,
    system: typeof body.system === "string" ? body.system.slice(0, 12000) : undefined,
    tools,
    messages: body.messages as Anthropic.MessageParam[],
  });
  if (message.stop_reason === "refusal") return json({ error: "refused" }, 422);
  return json({ content: message.content, stop_reason: message.stop_reason });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/health") return json({ ok: true });
    const routes = ["/read-problem", "/generate", "/chat"];
    if (!routes.includes(url.pathname)) return json({ error: "not_found" }, 404);
    if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

    if (!env.APP_KEY || !safeEqual(request.headers.get("x-dooit-key") ?? "", env.APP_KEY)) {
      return json({ error: "unauthorized" }, 401);
    }
    if (!env.ANTHROPIC_API_KEY) return json({ error: "server_not_configured" }, 500);

    let body: Record<string, unknown>;
    try {
      body = (await request.json()) as Record<string, unknown>;
    } catch {
      return json({ error: "bad_request" }, 400);
    }

    const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY, maxRetries: 2 });
    const model = env.MODEL || "claude-sonnet-5-5";
    try {
      switch (url.pathname) {
        case "/read-problem":
          return await readProblem(body, client, model);
        case "/generate":
          return await generate(body, client, model);
        default:
          return await chat(body, client, model);
      }
    } catch (error) {
      return errorResponse(error, url.pathname);
    }
  },
};
