"""정밀 인식 비교용: 파이썬 mlx-vlm으로 같은 사진을 읽음 (비교 실험 read.py와 같은 설정: "OCR:", 온도 0)

  python read.py <cases 폴더> <ids.json> <모델 폴더> <출력 python.json>
"""

import json
import os
import sys
import time


def main():
    cases_dir, ids_path, model_path, out_path = sys.argv[1:5]
    from mlx_vlm import generate, load
    from mlx_vlm.prompt_utils import apply_chat_template

    model, processor = load(model_path)
    prompt = apply_chat_template(processor, model.config, "OCR:", num_images=1)
    print("프롬프트", repr(prompt), flush=True)
    with open(os.path.join(cases_dir, "cases.json")) as f:
        specs = {s["id"]: s for s in json.load(f)}
    with open(ids_path) as f:
        ids = json.load(f)
    out = {"meta": {"backend": "python mlx-vlm"}, "cases": []}
    for k, case_id in enumerate(ids):
        image = os.path.join(cases_dir, specs[case_id]["image"])
        t0 = time.time()
        rec = {"id": case_id, "text": "", "seconds": 0.0}
        try:
            r = generate(model=model, processor=processor, prompt=prompt, image=[image],
                         max_tokens=1024, temperature=0.0, verbose=False)
            rec["text"] = r.text
            rec["promptTokens"] = int(r.prompt_tokens)
            rec["generationTokens"] = int(r.generation_tokens)
        except Exception as e:  # noqa: BLE001
            rec["error"] = f"{type(e).__name__}: {e}"
        rec["seconds"] = time.time() - t0
        out["cases"].append(rec)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=1)
        print(f"[{k + 1}/{len(ids)}] {case_id} {rec['seconds']:.1f}s {rec.get('promptTokens')}→{rec.get('generationTokens')} "
              + (rec.get("error") or rec["text"].replace("\n", " ⏎ "))[:300], flush=True)


if __name__ == "__main__":
    main()
