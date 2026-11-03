## 앱 그대로 (DoitMind.answer → DoitAutoSolve.parseModel)
| 모델 | 수학 | 과학 | 영어 | 사회 | 국어 | 전체 | 자료·힌트 없는 문제 | 평균 초/문제 | 평균 토큰 | 600토큰에서 잘림 |
|---|---|---|---|---|---|---|---|---|---|---|
| old-dooit2-Qwen3-1.7B | 33 / 40 / 40 | 10 / 15 / 15 | 8 / 15 / 15 | 9 / 15 / 15 | 7 / 15 / 15 | 67 / 100 / 100 | 30 / 46 / 46 | 4.7 | 91 | 0 |
| new-dooit1-Qwen3.5-2B | 11 / 25 / 40 | 6 / 11 / 15 | 7 / 10 / 15 | 9 / 11 / 15 | 7 / 12 / 15 | 40 / 69 / 100 | 19 / 34 / 46 | 4.4 | 104 | 0 |
| new-dooit2-Qwen3.5-4B | 27 / 40 / 40 | 13 / 15 / 15 | 13 / 15 / 15 | 10 / 15 / 15 | 9 / 15 / 15 | 72 / 100 / 100 | 32 / 46 / 46 | 7.8 | 58 | 0 |
(칸: 맞음 / 답함 / 전체 — '답함'은 앱의 parseModel이 정답을 읽어 낸 수)


## 정답 줄을 나눠 읽었을 때 (문장 끝 '… 정답: x'도 읽음)
| 모델 | 수학 | 과학 | 영어 | 사회 | 국어 | 전체 | 자료·힌트 없는 문제 | 평균 초/문제 | 평균 토큰 | 600토큰에서 잘림 |
|---|---|---|---|---|---|---|---|---|---|---|
| old-dooit2-Qwen3-1.7B | 33 / 40 / 40 | 10 / 15 / 15 | 8 / 15 / 15 | 9 / 15 / 15 | 7 / 15 / 15 | 67 / 100 / 100 | 30 / 46 / 46 | 4.7 | 91 | 0 |
| new-dooit1-Qwen3.5-2B | 11 / 25 / 40 | 6 / 11 / 15 | 7 / 10 / 15 | 9 / 11 / 15 | 7 / 12 / 15 | 40 / 69 / 100 | 19 / 34 / 46 | 4.4 | 104 | 0 |
| new-dooit2-Qwen3.5-4B | 27 / 40 / 40 | 13 / 15 / 15 | 13 / 15 / 15 | 10 / 15 / 15 | 9 / 15 / 15 | 72 / 100 / 100 | 32 / 46 / 46 | 7.8 | 58 | 0 |
(칸: 맞음 / 답함 / 전체 — '답함'은 앱의 parseModel이 정답을 읽어 낸 수)

old-dooit2-Qwen3-1.7B	math-0	O	답 9	정답 9
old-dooit2-Qwen3-1.7B	math-7	O	답 6	정답 6
old-dooit2-Qwen3-1.7B	math-15	O	답 12	정답 12
old-dooit2-Qwen3-1.7B	math-22	O	답 x² + x - 6 = 0	정답 x^2+x-6=0
old-dooit2-Qwen3-1.7B	math-30	X	답 4	정답 6
old-dooit2-Qwen3-1.7B	math-37	O	답 2 < x ≤ 6	정답 2 < x <= 6
old-dooit2-Qwen3-1.7B	math-45	O	답 (x - 2)(x - 3)	정답 (x-2)(x-3)
old-dooit2-Qwen3-1.7B	math-52	O	답 3(x + 2)(x - 2)	정답 3(x+2)(x-2)
old-dooit2-Qwen3-1.7B	math-60	O	답 8	정답 8
old-dooit2-Qwen3-1.7B	math-67	O	답 x^10	정답 x^10
old-dooit2-Qwen3-1.7B	math-75	O	답 5√3	정답 5√3
old-dooit2-Qwen3-1.7B	math-82	O	답 4 + 2√3	정답 4+2√3
old-dooit2-Qwen3-1.7B	math-90	O	답 x = 3	정답 x = 3
old-dooit2-Qwen3-1.7B	math-97	O	답 (1, 4)	정답 (1, 4)
old-dooit2-Qwen3-1.7B	math-105	O	답 y = 2x + 3	정답 y=2x+3
old-dooit2-Qwen3-1.7B	math-112	O	답 2	정답 2
old-dooit2-Qwen3-1.7B	math-120	O	답 -2 - 4i	정답 -2-4i
old-dooit2-Qwen3-1.7B	math-127	X	답 6	정답 7
old-dooit2-Qwen3-1.7B	math-135	O	답 20	정답 20
old-dooit2-Qwen3-1.7B	math-142	X	답 8	정답 9
old-dooit2-Qwen3-1.7B	math-150	O	답 2/3	정답 2/3
old-dooit2-Qwen3-1.7B	math-158	O	답 {2, 4, 6}	정답 {2, 4, 6}
old-dooit2-Qwen3-1.7B	math-165	O	답 2x + 1	정답 2x+1
old-dooit2-Qwen3-1.7B	math-173	O	답 59	정답 59
old-dooit2-Qwen3-1.7B	math-180	O	답 120	정답 120
old-dooit2-Qwen3-1.7B	math-188	O	답 6	정답 6
old-dooit2-Qwen3-1.7B	math-195	O	답 1	정답 1
old-dooit2-Qwen3-1.7B	math-203	O	답 3/5	정답 3/5
old-dooit2-Qwen3-1.7B	math-210	O	답 4	정답 4
old-dooit2-Qwen3-1.7B	math-218	X	답 0	정답 -3
old-dooit2-Qwen3-1.7B	math-225	X	답 1/4	정답 1/6
old-dooit2-Qwen3-1.7B	math-233	O	답 85	정답 85
old-dooit2-Qwen3-1.7B	math-240	O	답 150km	정답 150
old-dooit2-Qwen3-1.7B	math-248	O	답 30	정답 30
old-dooit2-Qwen3-1.7B	math-255	X	답 31.4cm	정답 10π
old-dooit2-Qwen3-1.7B	math-263	O	답 13	정답 13
old-dooit2-Qwen3-1.7B	math-270	O	답 -11	정답 -11
old-dooit2-Qwen3-1.7B	math-278	O	답 4/9	정답 4/9
old-dooit2-Qwen3-1.7B	math-285	X	답 (5, 5)	정답 x=5, y=5
old-dooit2-Qwen3-1.7B	math-293	O	답 3	정답 3
old-dooit2-Qwen3-1.7B	과학-0	O	답 3	정답 3
old-dooit2-Qwen3-1.7B	과학-11	O	답 2	정답 2
old-dooit2-Qwen3-1.7B	과학-22	O	답 4	정답 4
old-dooit2-Qwen3-1.7B	과학-34	O	답 4	정답 4
old-dooit2-Qwen3-1.7B	과학-45	O	답 3	정답 3
old-dooit2-Qwen3-1.7B	과학-56	O	답 15Ω	정답 15 Ω
old-dooit2-Qwen3-1.7B	과학-68	O	답 4	정답 4
old-dooit2-Qwen3-1.7B	과학-79	X	답 3	정답 2
old-dooit2-Qwen3-1.7B	과학-90	X	답 기체로 변하는 현상	정답 승화
old-dooit2-Qwen3-1.7B	과학-102	X	답 오르간	정답 산소
old-dooit2-Qwen3-1.7B	과학-113	O	답 1	정답 1
old-dooit2-Qwen3-1.7B	과학-124	O	답 3	정답 3
old-dooit2-Qwen3-1.7B	과학-257	X	답 10	정답 10 W
old-dooit2-Qwen3-1.7B	과학-268	X	답 60 N	정답 6 N
old-dooit2-Qwen3-1.7B	과학-309	O	답 2	정답 2
old-dooit2-Qwen3-1.7B	영어-128	O	답 3	정답 3
old-dooit2-Qwen3-1.7B	영어-134	O	답 3	정답 3
old-dooit2-Qwen3-1.7B	영어-140	O	답 2	정답 2
old-dooit2-Qwen3-1.7B	영어-146	O	답 1	정답 1
old-dooit2-Qwen3-1.7B	영어-152	O	답 3	정답 3
old-dooit2-Qwen3-1.7B	영어-158	X	답 2	정답 1
old-dooit2-Qwen3-1.7B	영어-164	X	답 4	정답 3
old-dooit2-Qwen3-1.7B	영어-170	X	답 4	정답 3
old-dooit2-Qwen3-1.7B	영어-176	X	답 1	정답 3
old-dooit2-Qwen3-1.7B	영어-182	X	답 3	정답 2
old-dooit2-Qwen3-1.7B	영어-189	O	답 1	정답 1
old-dooit2-Qwen3-1.7B	영어-279	X	답 1	정답 2
old-dooit2-Qwen3-1.7B	영어-285	O	답 2	정답 2
old-dooit2-Qwen3-1.7B	영어-291	X	답 3	정답 1
old-dooit2-Qwen3-1.7B	영어-322	O	답 3	정답 3
old-dooit2-Qwen3-1.7B	사회-195	O	답 3	정답 3
old-dooit2-Qwen3-1.7B	사회-199	X	답 이스탄불	정답 앙카라
old-dooit2-Qwen3-1.7B	사회-203	O	답 2	정답 2
old-dooit2-Qwen3-1.7B	사회-207	X	답 이어적기·주격 조사 '이'·모음조화를 확인해요	정답 1446년|1446
old-dooit2-Qwen3-1.7B	사회-211	X	답 3	정답 2
old-dooit2-Qwen3-1.7B	사회-215	O	답 2	정답 2
old-dooit2-Qwen3-1.7B	사회-219	O	답 2	정답 2
old-dooit2-Qwen3-1.7B	사회-223	X	답 대법원	정답 법원
old-dooit2-Qwen3-1.7B	사회-227	O	답 3	정답 3
old-dooit2-Qwen3-1.7B	사회-231	O	답 3	정답 3
old-dooit2-Qwen3-1.7B	사회-235	O	답 4	정답 4
old-dooit2-Qwen3-1.7B	사회-298	O	답 3	정답 3
old-dooit2-Qwen3-1.7B	사회-302	X	답 물가는 수요량이 수공급량보다 많은 때 하락합니다	정답 디플레이션
old-dooit2-Qwen3-1.7B	사회-306	O	답 국회	정답 국회
old-dooit2-Qwen3-1.7B	사회-332	X	답 4	정답 2
old-dooit2-Qwen3-1.7B	국어-237	O	답 1	정답 1
old-dooit2-Qwen3-1.7B	국어-238	O	답 3	정답 3
old-dooit2-Qwen3-1.7B	국어-239	O	답 1	정답 1
old-dooit2-Qwen3-1.7B	국어-240	X	답 2	정답 3
old-dooit2-Qwen3-1.7B	국어-241	X	답 4	정답 3
old-dooit2-Qwen3-1.7B	국어-242	O	답 됐다	정답 됐다
old-dooit2-Qwen3-1.7B	국어-243	X	답 4	정답 2
old-dooit2-Qwen3-1.7B	국어-244	O	답 4	정답 4
old-dooit2-Qwen3-1.7B	국어-245	X	답 3	정답 2
old-dooit2-Qwen3-1.7B	국어-246	O	답 2	정답 2
old-dooit2-Qwen3-1.7B	국어-247	X	답 1	정답 2
old-dooit2-Qwen3-1.7B	국어-248	X	답 부분으로	정답 일부러
old-dooit2-Qwen3-1.7B	국어-307	X	답 1	정답 2
old-dooit2-Qwen3-1.7B	국어-308	X	답 1	정답 4
old-dooit2-Qwen3-1.7B	국어-336	O	답 2	정답 2
new-dooit1-Qwen3.5-2B	math-0	X	답 13/3	정답 9
new-dooit1-Qwen3.5-2B	math-7	X	답 3	정답 6
new-dooit1-Qwen3.5-2B	math-15	O	답 12	정답 12
new-dooit1-Qwen3.5-2B	math-22	O	답 x² + x - 6 = 0	정답 x^2+x-6=0
new-dooit1-Qwen3.5-2B	math-30	X	답 4	정답 6
new-dooit1-Qwen3.5-2B	math-37	-	답 없음	정답 2 < x <= 6
new-dooit1-Qwen3.5-2B	math-45	O	답 (x - 2)(x - 3)	정답 (x-2)(x-3)
new-dooit1-Qwen3.5-2B	math-52	-	답 없음	정답 3(x+2)(x-2)
new-dooit1-Qwen3.5-2B	math-60	X	답 5	정답 8
new-dooit1-Qwen3.5-2B	math-67	X	답 10x	정답 x^10
new-dooit1-Qwen3.5-2B	math-75	O	답 5√3	정답 5√3
new-dooit1-Qwen3.5-2B	math-82	X	답 7 + 2√3	정답 4+2√3
new-dooit1-Qwen3.5-2B	math-90	X	답 4, 8	정답 x = 3
new-dooit1-Qwen3.5-2B	math-97	O	답 (1, 4)	정답 (1, 4)
new-dooit1-Qwen3.5-2B	math-105	-	답 없음	정답 y=2x+3
new-dooit1-Qwen3.5-2B	math-112	O	답 2	정답 2
new-dooit1-Qwen3.5-2B	math-120	O	답 -2 - 4i	정답 -2-4i
new-dooit1-Qwen3.5-2B	math-127	X	답 4"입니다. (이 문제는 항등식 성립 조건을 적용하면 a + b = 4 가 됩니다.)	정답 7
new-dooit1-Qwen3.5-2B	math-135	-	답 없음	정답 20
new-dooit1-Qwen3.5-2B	math-142	X	답 94	정답 9
new-dooit1-Qwen3.5-2B	math-150	O	답 2/3	정답 2/3
new-dooit1-Qwen3.5-2B	math-158	-	답 없음	정답 {2, 4, 6}
new-dooit1-Qwen3.5-2B	math-165	-	답 없음	정답 2x+1
new-dooit1-Qwen3.5-2B	math-173	X	답 99	정답 59
new-dooit1-Qwen3.5-2B	math-180	O	답 120	정답 120
new-dooit1-Qwen3.5-2B	math-188	-	답 없음	정답 6
new-dooit1-Qwen3.5-2B	math-195	-	답 없음	정답 1
new-dooit1-Qwen3.5-2B	math-203	X	답 5/3	정답 3/5
new-dooit1-Qwen3.5-2B	math-210	-	답 없음	정답 4
new-dooit1-Qwen3.5-2B	math-218	-	답 없음	정답 -3
new-dooit1-Qwen3.5-2B	math-225	-	답 없음	정답 1/6
new-dooit1-Qwen3.5-2B	math-233	O	답 85	정답 85
new-dooit1-Qwen3.5-2B	math-240	-	답 없음	정답 150
new-dooit1-Qwen3.5-2B	math-248	-	답 없음	정답 30
new-dooit1-Qwen3.5-2B	math-255	-	답 없음	정답 10π
new-dooit1-Qwen3.5-2B	math-263	O	답 13	정답 13
new-dooit1-Qwen3.5-2B	math-270	X	답 0.25	정답 -11
new-dooit1-Qwen3.5-2B	math-278	X	답 40/9	정답 4/9
new-dooit1-Qwen3.5-2B	math-285	X	답 15	정답 x=5, y=5
new-dooit1-Qwen3.5-2B	math-293	-	답 없음	정답 3
new-dooit1-Qwen3.5-2B	과학-0	X	답 5	정답 3
new-dooit1-Qwen3.5-2B	과학-11	O	답 2	정답 2
new-dooit1-Qwen3.5-2B	과학-22	O	답 4	정답 4
new-dooit1-Qwen3.5-2B	과학-34	O	답 4	정답 4
new-dooit1-Qwen3.5-2B	과학-45	X	답 1	정답 3
new-dooit1-Qwen3.5-2B	과학-56	X	답 15	정답 15 Ω
new-dooit1-Qwen3.5-2B	과학-68	-	답 없음	정답 4
new-dooit1-Qwen3.5-2B	과학-79	O	답 2	정답 2
new-dooit1-Qwen3.5-2B	과학-90	X	답 녹음	정답 승화
new-dooit1-Qwen3.5-2B	과학-102	-	답 없음	정답 산소
new-dooit1-Qwen3.5-2B	과학-113	-	답 없음	정답 1
new-dooit1-Qwen3.5-2B	과학-124	O	답 3	정답 3
new-dooit1-Qwen3.5-2B	과학-257	-	답 없음	정답 10 W
new-dooit1-Qwen3.5-2B	과학-268	O	답 6 N	정답 6 N
new-dooit1-Qwen3.5-2B	과학-309	X	답 4	정답 2
new-dooit1-Qwen3.5-2B	영어-128	O	답 3	정답 3
new-dooit1-Qwen3.5-2B	영어-134	O	답 3	정답 3
new-dooit1-Qwen3.5-2B	영어-140	O	답 2	정답 2
new-dooit1-Qwen3.5-2B	영어-146	-	답 없음	정답 1
new-dooit1-Qwen3.5-2B	영어-152	O	답 3	정답 3
new-dooit1-Qwen3.5-2B	영어-158	X	답 2	정답 1
new-dooit1-Qwen3.5-2B	영어-164	O	답 3	정답 3
new-dooit1-Qwen3.5-2B	영어-170	X	답 2	정답 3
new-dooit1-Qwen3.5-2B	영어-176	X	답 2	정답 3
new-dooit1-Qwen3.5-2B	영어-182	-	답 없음	정답 2
new-dooit1-Qwen3.5-2B	영어-189	-	답 없음	정답 1
new-dooit1-Qwen3.5-2B	영어-279	-	답 없음	정답 2
new-dooit1-Qwen3.5-2B	영어-285	O	답 2	정답 2
new-dooit1-Qwen3.5-2B	영어-291	-	답 없음	정답 1
new-dooit1-Qwen3.5-2B	영어-322	O	답 3	정답 3
new-dooit1-Qwen3.5-2B	사회-195	O	답 3	정답 3
new-dooit1-Qwen3.5-2B	사회-199	-	답 없음	정답 앙카라
new-dooit1-Qwen3.5-2B	사회-203	O	답 2	정답 2
new-dooit1-Qwen3.5-2B	사회-207	-	답 없음	정답 1446년|1446
new-dooit1-Qwen3.5-2B	사회-211	X	답 1	정답 2
new-dooit1-Qwen3.5-2B	사회-215	O	답 2	정답 2
new-dooit1-Qwen3.5-2B	사회-219	O	답 2	정답 2
new-dooit1-Qwen3.5-2B	사회-223	-	답 없음	정답 법원
new-dooit1-Qwen3.5-2B	사회-227	O	답 3	정답 3
new-dooit1-Qwen3.5-2B	사회-231	O	답 3	정답 3
new-dooit1-Qwen3.5-2B	사회-235	O	답 4	정답 4
new-dooit1-Qwen3.5-2B	사회-298	O	답 3	정답 3
new-dooit1-Qwen3.5-2B	사회-302	-	답 없음	정답 디플레이션
new-dooit1-Qwen3.5-2B	사회-306	O	답 국회	정답 국회
new-dooit1-Qwen3.5-2B	사회-332	X	답 4	정답 2
new-dooit1-Qwen3.5-2B	국어-237	X	답 2	정답 1
new-dooit1-Qwen3.5-2B	국어-238	O	답 3	정답 3
new-dooit1-Qwen3.5-2B	국어-239	-	답 없음	정답 1
new-dooit1-Qwen3.5-2B	국어-240	O	답 3	정답 3
new-dooit1-Qwen3.5-2B	국어-241	X	답 2	정답 3
new-dooit1-Qwen3.5-2B	국어-242	X	답 들었다	정답 됐다
new-dooit1-Qwen3.5-2B	국어-243	O	답 2	정답 2
new-dooit1-Qwen3.5-2B	국어-244	X	답 2	정답 4
new-dooit1-Qwen3.5-2B	국어-245	-	답 없음	정답 2
new-dooit1-Qwen3.5-2B	국어-246	O	답 2	정답 2
new-dooit1-Qwen3.5-2B	국어-247	O	답 2	정답 2
new-dooit1-Qwen3.5-2B	국어-248	X	답 일부로	정답 일부러
new-dooit1-Qwen3.5-2B	국어-307	O	답 2	정답 2
new-dooit1-Qwen3.5-2B	국어-308	-	답 없음	정답 4
new-dooit1-Qwen3.5-2B	국어-336	O	답 2	정답 2
new-dooit2-Qwen3.5-4B	math-0	O	답 9	정답 9
new-dooit2-Qwen3.5-4B	math-7	O	답 6	정답 6
new-dooit2-Qwen3.5-4B	math-15	X	답 10	정답 12
new-dooit2-Qwen3.5-4B	math-22	O	답 x²+x-6=0	정답 x^2+x-6=0
new-dooit2-Qwen3.5-4B	math-30	O	답 6마리	정답 6
new-dooit2-Qwen3.5-4B	math-37	X	답 $2 < x \leq 6$	정답 2 < x <= 6
new-dooit2-Qwen3.5-4B	math-45	O	답 (x - 2)(x - 3)	정답 (x-2)(x-3)
new-dooit2-Qwen3.5-4B	math-52	O	답 3(x + 2)(x - 2)	정답 3(x+2)(x-2)
new-dooit2-Qwen3.5-4B	math-60	X	답 10	정답 8
new-dooit2-Qwen3.5-4B	math-67	O	답 x¹⁰	정답 x^10
new-dooit2-Qwen3.5-4B	math-75	O	답 5√3	정답 5√3
new-dooit2-Qwen3.5-4B	math-82	O	답 4 + 2√3	정답 4+2√3
new-dooit2-Qwen3.5-4B	math-90	X	답 x - 3 = 0	정답 x = 3
new-dooit2-Qwen3.5-4B	math-97	O	답 (1, 4)	정답 (1, 4)
new-dooit2-Qwen3.5-4B	math-105	O	답 y = 2x + 3	정답 y=2x+3
new-dooit2-Qwen3.5-4B	math-112	O	답 2	정답 2
new-dooit2-Qwen3.5-4B	math-120	O	답 -2 - 4i	정답 -2-4i
new-dooit2-Qwen3.5-4B	math-127	X	답 1	정답 7
new-dooit2-Qwen3.5-4B	math-135	X	답 10	정답 20
new-dooit2-Qwen3.5-4B	math-142	O	답 9	정답 9
new-dooit2-Qwen3.5-4B	math-150	O	답 2/3	정답 2/3
new-dooit2-Qwen3.5-4B	math-158	O	답 {2, 4, 6}	정답 {2, 4, 6}
new-dooit2-Qwen3.5-4B	math-165	X	답 $2x + 1$	정답 2x+1
new-dooit2-Qwen3.5-4B	math-173	X	답 58	정답 59
new-dooit2-Qwen3.5-4B	math-180	O	답 120	정답 120
new-dooit2-Qwen3.5-4B	math-188	O	답 6	정답 6
new-dooit2-Qwen3.5-4B	math-195	O	답 1	정답 1
new-dooit2-Qwen3.5-4B	math-203	O	답 0.6	정답 3/5
new-dooit2-Qwen3.5-4B	math-210	O	답 4	정답 4
new-dooit2-Qwen3.5-4B	math-218	X	답 2	정답 -3
new-dooit2-Qwen3.5-4B	math-225	O	답 1/6	정답 1/6
new-dooit2-Qwen3.5-4B	math-233	X	답 87.5	정답 85
new-dooit2-Qwen3.5-4B	math-240	O	답 150km	정답 150
new-dooit2-Qwen3.5-4B	math-248	O	답 30	정답 30
new-dooit2-Qwen3.5-4B	math-255	X	답 31.4cm	정답 10π
new-dooit2-Qwen3.5-4B	math-263	X	답 17	정답 13
new-dooit2-Qwen3.5-4B	math-270	X	답 -13	정답 -11
new-dooit2-Qwen3.5-4B	math-278	O	답 4/9	정답 4/9
new-dooit2-Qwen3.5-4B	math-285	O	답 x=5, y=5	정답 x=5, y=5
new-dooit2-Qwen3.5-4B	math-293	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	과학-0	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	과학-11	O	답 2	정답 2
new-dooit2-Qwen3.5-4B	과학-22	O	답 4	정답 4
new-dooit2-Qwen3.5-4B	과학-34	O	답 4	정답 4
new-dooit2-Qwen3.5-4B	과학-45	X	답 2	정답 3
new-dooit2-Qwen3.5-4B	과학-56	X	답 15	정답 15 Ω
new-dooit2-Qwen3.5-4B	과학-68	O	답 4	정답 4
new-dooit2-Qwen3.5-4B	과학-79	O	답 2	정답 2
new-dooit2-Qwen3.5-4B	과학-90	O	답 승화	정답 승화
new-dooit2-Qwen3.5-4B	과학-102	O	답 산소	정답 산소
new-dooit2-Qwen3.5-4B	과학-113	O	답 1	정답 1
new-dooit2-Qwen3.5-4B	과학-124	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	과학-257	O	답 10 W	정답 10 W
new-dooit2-Qwen3.5-4B	과학-268	O	답 6N	정답 6 N
new-dooit2-Qwen3.5-4B	과학-309	O	답 2	정답 2
new-dooit2-Qwen3.5-4B	영어-128	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	영어-134	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	영어-140	O	답 2	정답 2
new-dooit2-Qwen3.5-4B	영어-146	O	답 1	정답 1
new-dooit2-Qwen3.5-4B	영어-152	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	영어-158	O	답 1	정답 1
new-dooit2-Qwen3.5-4B	영어-164	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	영어-170	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	영어-176	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	영어-182	X	답 3	정답 2
new-dooit2-Qwen3.5-4B	영어-189	O	답 1	정답 1
new-dooit2-Qwen3.5-4B	영어-279	O	답 2	정답 2
new-dooit2-Qwen3.5-4B	영어-285	O	답 2	정답 2
new-dooit2-Qwen3.5-4B	영어-291	X	답 3	정답 1
new-dooit2-Qwen3.5-4B	영어-322	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	사회-195	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	사회-199	X	답 안카라	정답 앙카라
new-dooit2-Qwen3.5-4B	사회-203	X	답 1	정답 2
new-dooit2-Qwen3.5-4B	사회-207	X	답 1443 년	정답 1446년|1446
new-dooit2-Qwen3.5-4B	사회-211	X	답 1	정답 2
new-dooit2-Qwen3.5-4B	사회-215	O	답 2	정답 2
new-dooit2-Qwen3.5-4B	사회-219	O	답 2	정답 2
new-dooit2-Qwen3.5-4B	사회-223	O	답 법원	정답 법원
new-dooit2-Qwen3.5-4B	사회-227	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	사회-231	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	사회-235	O	답 4	정답 4
new-dooit2-Qwen3.5-4B	사회-298	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	사회-302	X	답 물가하락	정답 디플레이션
new-dooit2-Qwen3.5-4B	사회-306	O	답 국회	정답 국회
new-dooit2-Qwen3.5-4B	사회-332	O	답 2	정답 2
new-dooit2-Qwen3.5-4B	국어-237	O	답 1	정답 1
new-dooit2-Qwen3.5-4B	국어-238	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	국어-239	X	답 2	정답 1
new-dooit2-Qwen3.5-4B	국어-240	O	답 3	정답 3
new-dooit2-Qwen3.5-4B	국어-241	X	답 1	정답 3
new-dooit2-Qwen3.5-4B	국어-242	X	답 들었다	정답 됐다
new-dooit2-Qwen3.5-4B	국어-243	O	답 2	정답 2
new-dooit2-Qwen3.5-4B	국어-244	O	답 4	정답 4
new-dooit2-Qwen3.5-4B	국어-245	X	답 1	정답 2
new-dooit2-Qwen3.5-4B	국어-246	O	답 2	정답 2
new-dooit2-Qwen3.5-4B	국어-247	O	답 2	정답 2
new-dooit2-Qwen3.5-4B	국어-248	X	답 일부로	정답 일부러
new-dooit2-Qwen3.5-4B	국어-307	O	답 2	정답 2
new-dooit2-Qwen3.5-4B	국어-308	X	답 2	정답 4
new-dooit2-Qwen3.5-4B	국어-336	O	답 2	정답 2
