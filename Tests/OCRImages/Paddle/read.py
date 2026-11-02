"""PaddleOCR-VL로 테스트 사진 읽기 (맥, mlx-vlm): 비교 실험 전용, 앱에는 없음

  python read.py <cases 폴더> <출력 json> --model <HF 저장소> [--prompt "OCR:"] [--filter 이름] [--device auto|gpu|cpu]

- 사진마다 모델이 낸 글을 그대로 저장 (채점은 paddle-score.sh가 앱 코드로)
- 한 장 끝날 때마다 json을 다시 써서, 시간 초과로 끊겨도 읽은 데까지는 남음
"""

import argparse
import json
import os
import platform
import resource
import sys
import time


def dir_size(path):
    total = 0
    for root, _, files in os.walk(path):
        for f in files:
            p = os.path.join(root, f)
            try:
                total += os.path.getsize(os.path.realpath(p))
            except OSError:
                pass
    return total


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cases")
    ap.add_argument("out")
    ap.add_argument("--model", required=True)
    ap.add_argument("--prompt", default="OCR:")
    ap.add_argument("--filter", default="")
    ap.add_argument("--device", default="auto")
    ap.add_argument("--max-tokens", type=int, default=1024)
    ap.add_argument("--spot-kinds", default="words", help="Spotting:(글자+자리)도 읽을 종류 (쉼표, 비우면 안 함)")
    ap.add_argument("--limit", type=int, default=int(os.environ.get("PADDLE_LIMIT") or 0))
    ap.add_argument("--deadline", type=float, default=0, help="이 초가 지나면 남은 사진은 건너뜀")
    args = ap.parse_args()

    started = time.time()
    import mlx.core as mx

    metal = False
    try:
        metal = bool(mx.metal.is_available())
    except Exception as e:  # noqa: BLE001
        print("metal 확인 실패:", e)
    device = args.device
    if device == "auto":
        device = "gpu" if metal else "cpu"
    if device == "cpu":
        mx.set_default_device(mx.cpu)
    print(f"mlx {mx.__version__} · metal={metal} · 사용 장치={device} · {platform.platform()}", flush=True)
    if metal:
        try:
            info = mx.metal.device_info() if hasattr(mx.metal, "device_info") else mx.device_info()
            print("장치 정보:", info, flush=True)
        except Exception as e:  # noqa: BLE001
            print("장치 정보 없음:", e)

    from huggingface_hub import snapshot_download

    t0 = time.time()
    path = snapshot_download(args.model)
    download_s = time.time() - t0
    size = dir_size(path)
    print(f"모델 {args.model} → {path} ({size / 1e9:.2f} GB, {download_s:.0f}s)", flush=True)
    for name in sorted(os.listdir(path)):
        p = os.path.join(path, name)
        print(f"   {name}  {os.path.getsize(os.path.realpath(p)) / 1e6:.1f} MB")
    readme = os.path.join(path, "README.md")
    if os.path.exists(readme):
        print("----- 모델 카드 (앞부분) -----")
        with open(readme, encoding="utf-8", errors="replace") as f:
            print("".join(f.readlines()[:80]))
        print("----- 모델 카드 끝 -----", flush=True)
    quant = ""
    try:
        with open(os.path.join(path, "config.json")) as f:
            cfg = json.load(f)
        q = cfg.get("quantization") or cfg.get("quantization_config")
        quant = json.dumps(q) if q else "없음 (" + str(cfg.get("torch_dtype") or cfg.get("dtype") or "?") + ")"
    except Exception as e:  # noqa: BLE001
        quant = f"? ({e})"
    print("양자화:", quant, flush=True)

    from mlx_vlm import generate, load
    from mlx_vlm.prompt_utils import apply_chat_template
    import mlx_vlm

    t0 = time.time()
    model, processor = load(path)
    load_s = time.time() - t0
    prompt = apply_chat_template(processor, model.config, args.prompt, num_images=1)
    print(f"불러오기 {load_s:.1f}s · 프롬프트 {prompt!r}", flush=True)

    with open(os.path.join(args.cases, "cases.json")) as f:
        specs = [s for s in json.load(f) if args.filter in s["id"]]
    if args.limit and len(specs) > args.limit:
        # 고르게 몇 장만 (빠른 확인용)
        step = len(specs) / args.limit
        specs = [specs[int(k * step)] for k in range(args.limit)]

    meta = {
        "backend": f"mlx-vlm {mlx_vlm.__version__} / mlx {mx.__version__}",
        "device": device,
        "model": args.model,
        "quantization": quant,
        "size_gb": f"{size / 1e9:.2f}",
        "prompt": args.prompt,
        "load_s": f"{load_s:.1f}",
    }
    out = {"meta": meta, "cases": []}

    def save():
        rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        # 맥은 바이트, 리눅스는 KB
        rss_gb = rss / 1e9 if sys.platform == "darwin" else rss / 1e6
        meta["peak_rss_gb"] = f"{rss_gb:.2f}"
        try:
            meta["peak_mlx_gb"] = f"{mx.get_peak_memory() / 1e9:.2f}"
        except Exception:  # noqa: BLE001
            pass
        with open(args.out, "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=1)

    skipped = 0
    spotted = 0
    spot_prompt = apply_chat_template(processor, model.config, "Spotting:", num_images=1)
    for k, spec in enumerate(specs):
        if args.deadline and time.time() - started > args.deadline:
            skipped += 1
            continue
        image = os.path.join(args.cases, spec["image"])
        t0 = time.time()
        rec = {"id": spec["id"], "text": "", "seconds": 0.0}
        try:
            r = generate(model=model, processor=processor, prompt=prompt, image=[image],
                         max_tokens=args.max_tokens, temperature=0.0, verbose=False)
            rec["text"] = r.text
            rec["promptTokens"] = int(r.prompt_tokens)
            rec["generationTokens"] = int(r.generation_tokens)
            rec["peakGB"] = float(r.peak_memory)
        except Exception as e:  # noqa: BLE001
            rec["error"] = f"{type(e).__name__}: {e}"
        rec["seconds"] = time.time() - t0
        # 단어장은 글자 자리(Spotting)도 따로 읽어 둠: 앱의 WordParser는 줄 상자 위치로 단·행을 나눔
        if args.spot_kinds and spec["kind"] in args.spot_kinds.split(","):
            t1 = time.time()
            try:
                r = generate(model=model, processor=processor, prompt=spot_prompt, image=[image],
                             max_tokens=args.max_tokens * 2, temperature=0.0, verbose=False)
                rec["spot"] = r.text
                rec["spotTokens"] = int(r.generation_tokens)
            except Exception as e:  # noqa: BLE001
                rec["spotError"] = f"{type(e).__name__}: {e}"
            rec["spotSeconds"] = time.time() - t1
            if spotted < 3:
                print("   Spotting 원문:", repr(rec.get("spot", rec.get("spotError", "")))[:1500], flush=True)
            spotted += 1
        out["cases"].append(rec)
        save()
        one = rec.get("error") or rec["text"].replace("\n", " ⏎ ")
        print(f"[{k + 1}/{len(specs)}] {spec['id']}  {rec['seconds']:.1f}s  {rec.get('promptTokens', '-')}→{rec.get('generationTokens', '-')} tok  {one[:300]}", flush=True)
    meta["skipped"] = str(skipped)
    save()
    print(f"끝: {len(out['cases'])}장 읽음, {skipped}장 건너뜀, 전체 {time.time() - started:.0f}s · 최대 메모리 RSS {meta['peak_rss_gb']} GB, MLX {meta.get('peak_mlx_gb', '?')} GB")


if __name__ == "__main__":
    main()
