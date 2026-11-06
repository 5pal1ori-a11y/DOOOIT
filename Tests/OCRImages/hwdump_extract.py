#!/usr/bin/env python3
"""gh run view <id> --log 로 받은 로그에서 HWDUMP 줄을 모아 dump.jsonl로 (한 줄 = 사진 한 장)
   사용: python3 hwdump_extract.py <로그> >> dump.jsonl"""
import sys, re, json
chunks = {}
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    i = line.find("HWDUMP\t")
    if i < 0:
        continue
    parts = line.rstrip("\n")[i:].split("\t", 3)
    if len(parts) < 4:
        continue
    _, cid, seq, body = parts
    k, n = map(int, seq.split("/"))
    chunks.setdefault(cid, {})[k] = (n, body)
for cid, c in sorted(chunks.items()):
    n = next(iter(c.values()))[0]
    if len(c) != n:
        print(f"# 덜 받음: {cid} {len(c)}/{n}", file=sys.stderr)
        continue
    text = "".join(c[k][1] for k in range(1, n + 1))
    try:
        json.loads(text)
    except Exception as e:
        print(f"# 깨짐: {cid} {e}", file=sys.stderr)
        continue
    print(text)
