import Foundation

// NEIS 열린 데이터 실제 응답 (CI에서 받은 것, 키 없이 받은 앞 5줄). 학교 이름 · 코드는 공개 정보예요.

private let fxElsWeek = #"{"elsTimetable":[{"head":[{"list_total_count":21},{"RESULT":{"CODE":"INFO-000","MESSAGE":"정상 처리되었습니다."}}]},{"row":[{"ATPT_OFCDC_SC_CODE":"D10","ATPT_OFCDC_SC_NM":"대구광역시교육청","SD_SCHUL_CODE":"7271066","SCHUL_NM":"남대구초등학교","AY":"2025","SEM":"2","ALL_TI_YMD":"20251013","GRADE":"1","CLASS_NM":"1","PERIO":"1","ITRT_CNTNT":"국어","LOAD_DTM":"20251019"},{"ATPT_OFCDC_SC_CODE":"D10","ATPT_OFCDC_SC_NM":"대구광역시교육청","SD_SCHUL_CODE":"7271066","SCHUL_NM":"남대구초등학교","AY":"2025","SEM":"2","ALL_TI_YMD":"20251013","GRADE":"1","CLASS_NM":"1","PERIO":"2","ITRT_CNTNT":"수학","LOAD_DTM":"20251019"},{"ATPT_OFCDC_SC_CODE":"D10","ATPT_OFCDC_SC_NM":"대구광역시교육청","SD_SCHUL_CODE":"7271066","SCHUL_NM":"남대구초등학교","AY":"2025","SEM":"2","ALL_TI_YMD":"20251013","GRADE":"1","CLASS_NM":"1","PERIO":"3","ITRT_CNTNT":"슬기로운생활","LOAD_DTM":"20251019"},{"ATPT_OFCDC_SC_CODE":"D10","ATPT_OFCDC_SC_NM":"대구광역시교육청","SD_SCHUL_CODE":"7271066","SCHUL_NM":"남대구초등학교","AY":"2025","SEM":"2","ALL_TI_YMD":"20251013","GRADE":"1","CLASS_NM":"1","PERIO":"4","ITRT_CNTNT":"즐거운생활","LOAD_DTM":"20251019"},{"ATPT_OFCDC_SC_CODE":"D10","ATPT_OFCDC_SC_NM":"대구광역시교육청","SD_SCHUL_CODE":"7271066","SCHUL_NM":"남대구초등학교","AY":"2025","SEM":"2","ALL_TI_YMD":"20251014","GRADE":"1","CLASS_NM":"1","PERIO":"1","ITRT_CNTNT":"수학","LOAD_DTM":"20251019"}]}]}"#

private let fxMealEls = #"{"mealServiceDietInfo":[{"head":[{"list_total_count":5},{"RESULT":{"CODE":"INFO-000","MESSAGE":"정상 처리되었습니다."}}]},{"row":[{"ATPT_OFCDC_SC_CODE":"D10","ATPT_OFCDC_SC_NM":"대구광역시교육청","SD_SCHUL_CODE":"7271066","SCHUL_NM":"남대구초등학교","MMEAL_SC_CODE":"2","MMEAL_SC_NM":"중식","MLSV_YMD":"20251013","MLSV_FGR":234.0,"DDISH_NM":"옥수수밥 <br/>쇠고기미역국 (5.6.16)<br/>메추리알조림 (1.5.6.13)<br/>진미간장조림 (5.6.13.17)<br/>치즈떡볶이 (1.2.5.6.10.12.15.16)<br/>김구이 <br/>배추김치(1) (9)<br/>우유 (2)","ORPLC_INFO":"쇠고기(종류) : 국내산(한우)<br/>쇠고기 식육가공품 : 국내산<br/>돼지고기 : 국내산<br/>돼지고기 식육가공품 : 국내산<br/>닭고기 : 국내산<br/>닭고기 식육가공품 : 국내산<br/>오리고기 : 국내산<br/>오리고기 가공품 : 국내산<br/>양고기 : 사용안함<br/>쌀 : 국내산<br/>배추 : 국내산<br/>고춧가루 : 국내산<br/>콩 : 국내산<br/>넙치 : 사용안함<br/>조피볼락 : 사용안함<br/>참돔 : 국내산<br/>미꾸라지 : 국내산<br/>뱀장어 : 국내산<br/>낙지 : 국내산<br/>명태 : 외국산(러시아)<br/>고등어 : 국내산<br/>갈치 : 국내산<br/>오징어 : 국내산<br/>꽃게 : 국내산<br/>참조기 : 국내산<br/>다랑어 : 원양산<br/>아귀 : 국내산<br/>주꾸미 : 국내산<br/>가리비 : 국내산<br/>우렁쉥이 : 국내산<br/>전복 : 국내산<br/>방어 : 국내산<br/>부세 : 사용안함<br/>비고 : ","CAL_INFO":"696.8 Kcal","NTR_INFO":"탄수화물(g) : 95.3<br/>단백질(g) : 29.0<br/>지방(g) : 20.7<br/>비타민A(R.E) : 232.0<br/>티아민(mg) : 0.3<br/>리보플라빈(mg) : 0.6<br/>비타민C(mg) : 11.9<br/>칼슘(mg) : 251.9<br/>철분(mg) : 2.9","MLSV_FROM_YMD":"20251013","MLSV_TO_YMD":"20251013","LOAD_DTM":"20251020"},{"ATPT_OFCDC_SC_CODE":"D10","ATPT_OFCDC_SC_NM":"대구광역시교육청","SD_SCHUL_CODE":"7271066","SCHUL_NM":"남대구초등학교","MMEAL_SC_CODE":"2","MMEAL_SC_NM":"중식","MLSV_YMD":"20251014","MLSV_FGR":125.0,"DDISH_NM":"보리밥 <br/>두부된장국 (5.6)<br/>시금치무침 (5.6)<br/>바싹불고기샐러드 (1.2.3.5.6.11.13.16)<br/>버섯김치전 (5.6.9)<br/>사과깍두기 (9.13)<br/>우유 (2)<br/>과일주스(망고) (13)","ORPLC_INFO":"쇠고기(종류) : 국내산(한우)<br/>쇠고기 식육가공품 : 국내산<br/>돼지고기 : 국내산<br/>돼지고기 식육가공품 : 국내산<br/>닭고기 : 국내산<br/>닭고기 식육가공품 : 국내산<br/>오리고기 : 국내산<br/>오리고기 가공품 : 국내산<br/>양고기 : 사용안함<br/>쌀 : 국내산<br/>배추 : 국내산<br/>고춧가루 : 국내산<br/>콩 : 국내산<br/>넙치 : 사용안함<br/>조피볼락 : 사용안함<br/>참돔 : 국내산<br/>미꾸라지 : 국내산<br/>뱀장어 : 국내산<br/>낙지 : 국내산<br/>명태 : 외국산(러시아)<br/>고등어 : 국내산<br/>갈치 : 국내산<br/>오징어 : 국내산<br/>꽃게 : 국내산<br/>참조기 : 국내산<br/>다랑어 : 원양산<br/>아귀 : 국내산<br/>주꾸미 : 국내산<br/>가리비 : 국내산<br/>우렁쉥이 : 국내산<br/>전복 : 국내산<br/>방어 : 국내산<br/>부세 : 사용안함<br/>비고 : ","CAL_INFO":"646.8 Kcal","NTR_INFO":"탄수화물(g) : 100.2<br/>단백질(g) : 25.1<br/>지방(g) : 15.7<br/>비타민A(R.E) : 203.6<br/>티아민(mg) : 0.4<br/>리보플라빈(mg) : 0.6<br/>비타민C(mg) : 34.7<br/>칼슘(mg) : 318.9<br/>철분(mg) : 3.9","MLSV_FROM_YMD":"20251014","MLSV_TO_YMD":"20251014","LOAD_DTM":"20251021"},{"ATPT_OFCDC_SC_CODE":"D10","ATPT_OFCDC_SC_NM":"대구광역시교육청","SD_SCHUL_CODE":"7271066","SCHUL_NM":"남대구초등학교","MMEAL_SC_CODE":"2","MMEAL_SC_NM":"중식","MLSV_YMD":"20251015","MLSV_FGR":170.0,"DDISH_NM":"흰찰밥 <br/>흑임자삼계탕 (15)<br/>연근강정 (5.6.13)<br/>낙지떡간장볶음 (6.12.13.15)<br/>배추김치(1) (9)<br/>우유 (2)<br/>샤인머스캣 ","ORPLC_INFO":"쇠고기(종류) : 국내산(한우)<br/>쇠고기 식육가공품 : 국내산<br/>돼지고기 : 국내산<br/>돼지고기 식육가공품 : 국내산<br/>닭고기 : 국내산<br/>닭고기 식육가공품 : 국내산<br/>오리고기 : 국내산<br/>오리고기 가공품 : 국내산<br/>양고기 : 사용안함<br/>쌀 : 국내산<br/>배추 : 국내산<br/>고춧가루 : 국내산<br/>콩 : 국내산<br/>넙치 : 사용안함<br/>조피볼락 : 사용안함<br/>참돔 : 국내산<br/>미꾸라지 : 국내산<br/>뱀장어 : 국내산<br/>낙지 : 국내산<br/>명태 : 외국산(러시아)<br/>고등어 : 국내산<br/>갈치 : 국내산<br/>오징어 : 국내산<br/>꽃게 : 국내산<br/>참조기 : 국내산<br/>다랑어 : 원양산<br/>아귀 : 국내산<br/>주꾸미 : 국내산<br/>가리비 : 국내산<br/>우렁쉥이 : 국내산<br/>전복 : 국내산<br/>방어 : 국내산<br/>부세 : 사용안함<br/>비고 : ","CAL_INFO":"693.7 Kcal","NTR_INFO":"탄수화물(g) : 111.6<br/>단백질(g) : 33.8<br/>지방(g) : 10.7<br/>비타민A(R.E) : 98.5<br/>티아민(mg) : 0.4<br/>리보플라빈(mg) : 0.4<br/>비타민C(mg) : 16.0<br/>칼슘(mg) : 211.9<br/>철분(mg) : 3.7","MLSV_FROM_YMD":"20251015","MLSV_TO_YMD":"20251015","LOAD_DTM":"20251022"},{"ATPT_OFCDC_SC_CODE":"D10","ATPT_OFCDC_SC_NM":"대구광역시교육청","SD_SCHUL_CODE":"7271066","SCHUL_NM":"남대구초등학교","MMEAL_SC_CODE":"2","MMEAL_SC_NM":"중식","MLSV_YMD":"20251016","MLSV_FGR":234.0,"DDISH_NM":"영양밥 <br/>동태국 (5.6)<br/>우엉땅콩조림 (5.6.13)<br/>목살허브구이 (10)<br/>알타리무김치 (9.13)<br/>골드키위 <br/>우유 (2)<br/>야채쌈(쌈장) (5.6.13)","ORPLC_INFO":"쇠고기(종류) : 국내산(한우)<br/>쇠고기 식육가공품 : 국내산<br/>돼지고기 : 국내산<br/>돼지고기 식육가공품 : 국내산<br/>닭고기 : 국내산<br/>닭고기 식육가공품 : 국내산<br/>오리고기 : 국내산<br/>오리고기 가공품 : 국내산<br/>양고기 : 사용안함<br/>쌀 : 국내산<br/>배추 : 국내산<br/>고춧가루 : 국내산<br/>콩 : 국내산<br/>넙치 : 사용안함<br/>조피볼락 : 사용안함<br/>참돔 : 국내산<br/>미꾸라지 : 국내산<br/>뱀장어 : 국내산<br/>낙지 : 국내산<br/>명태 : 외국산(러시아)<br/>고등어 : 국내산<br/>갈치 : 국내산<br/>오징어 : 국내산<br/>꽃게 : 국내산<br/>참조기 : 국내산<br/>다랑어 : 원양산<br/>아귀 : 국내산<br/>주꾸미 : 국내산<br/>가리비 : 국내산<br/>우렁쉥이 : 국내산<br/>전복 : 국내산<br/>방어 : 국내산<br/>부세 : 사용안함<br/>비고 : ","CAL_INFO":"622.3 Kcal","NTR_INFO":"탄수화물(g) : 77.6<br/>단백질(g) : 36.6<br/>지방(g) : 17.1<br/>비타민A(R.E) : 139.6<br/>티아민(mg) : 0.8<br/>리보플라빈(mg) : 0.7<br/>비타민C(mg) : 68.7<br/>칼슘(mg) : 314.8<br/>철분(mg) : 4.2","MLSV_FROM_YMD":"20251016","MLSV_TO_YMD":"20251016","LOAD_DTM":"20251023"},{"ATPT_OFCDC_SC_CODE":"D10","ATPT_OFCDC_SC_NM":"대구광역시교육청","SD_SCHUL_CODE":"7271066","SCHUL_NM":"남대구초등학교","MMEAL_SC_CODE":"2","MMEAL_SC_NM":"중식","MLSV_YMD":"20251017","MLSV_FGR":234.0,"DDISH_NM":"홍미밥 <br/>근대된장국 (5.6.9)<br/>납작만두구이/양파장 (1.5.6.13)<br/>혼합멸치볶음 (5.6.9.13)<br/>오리불고기 (5.6.13)<br/>배추김치(1) (9)<br/>우유 (2)","ORPLC_INFO":"쇠고기(종류) : 국내산(한우)<br/>쇠고기 식육가공품 : 국내산<br/>돼지고기 : 국내산<br/>돼지고기 식육가공품 : 국내산<br/>닭고기 : 국내산<br/>닭고기 식육가공품 : 국내산<br/>오리고기 : 국내산<br/>오리고기 가공품 : 국내산<br/>양고기 : 사용안함<br/>쌀 : 국내산<br/>배추 : 국내산<br/>고춧가루 : 국내산<br/>콩 : 국내산<br/>넙치 : 사용안함<br/>조피볼락 : 사용안함<br/>참돔 : 국내산<br/>미꾸라지 : 국내산<br/>뱀장어 : 국내산<br/>낙지 : 국내산<br/>명태 : 외국산(러시아)<br/>고등어 : 국내산<br/>갈치 : 국내산<br/>오징어 : 국내산<br/>꽃게 : 국내산<br/>참조기 : 국내산<br/>다랑어 : 원양산<br/>아귀 : 국내산<br/>주꾸미 : 국내산<br/>가리비 : 국내산<br/>우렁쉥이 : 국내산<br/>전복 : 국내산<br/>방어 : 국내산<br/>부세 : 사용안함<br/>비고 : ","CAL_INFO":"715.9 Kcal","NTR_INFO":"탄수화물(g) : 84.7<br/>단백질(g) : 27.9<br/>지방(g) : 27.8<br/>비타민A(R.E) : 148.8<br/>티아민(mg) : 0.4<br/>리보플라빈(mg) : 0.6<br/>비타민C(mg) : 8.0<br/>칼슘(mg) : 374.8<br/>철분(mg) : 3.0","MLSV_FROM_YMD":"20251017","MLSV_TO_YMD":"20251017","LOAD_DTM":"20251024"}]}]}"#

private let fxSchoolList = #"{"schoolInfo":[{"head":[{"list_total_count":651},{"RESULT":{"CODE":"INFO-000","MESSAGE":"정상 처리되었습니다."}}]},{"row":[{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"       ","SCHUL_NM":"(가칭)서울산빛초등학교","ENG_SCHUL_NM":"Seoul Sanbit Elementary School ","SCHUL_KND_SC_NM":"초등학교","LCTN_SC_NM":"서울특별시","JU_ORG_NM":"서울특별시강동송파교육지원청","FOND_SC_NM":"공립","ORG_RDNZC":"05791 ","ORG_RDNMA":"서울특별시 송파구 위례서이로 10","ORG_RDNDA":"(거여동)","ORG_TELNO":"02-3434-4353","HMPG_ADRES":"http://","COEDU_SC_NM":"남여공학","ORG_FAXNO":null,"HS_SC_NM":null,"INDST_SPECL_CCCCL_EXST_YN":"N","HS_GNRL_BUSNS_SC_NM":null,"SPCLY_PURPS_HS_ORD_NM":null,"ENE_BFE_SEHF_SC_NM":"전기","DGHT_SC_NM":"주간","FOND_YMD":"20270301","FOAS_MEMRD":"20270301","LOAD_DTM":"20261004"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7132131","SCHUL_NM":"남서울중학교","ENG_SCHUL_NM":"Namseoul Middle School","SCHUL_KND_SC_NM":"중학교","LCTN_SC_NM":"서울특별시","JU_ORG_NM":"서울특별시동작관악교육지원청","FOND_SC_NM":"공립","ORG_RDNZC":"08773 ","ORG_RDNMA":"서울특별시 관악구 남부순환로172길 97","ORG_RDNDA":", 남서울중학교 (신림동)","ORG_TELNO":"02-855-9832","HMPG_ADRES":"https://namseoul.sen.ms.kr","COEDU_SC_NM":"남여공학","ORG_FAXNO":"02-851-0637","HS_SC_NM":null,"INDST_SPECL_CCCCL_EXST_YN":"N","HS_GNRL_BUSNS_SC_NM":"일반계","SPCLY_PURPS_HS_ORD_NM":null,"ENE_BFE_SEHF_SC_NM":"전기","DGHT_SC_NM":"주간","FOND_YMD":"19641112","FOAS_MEMRD":"19640501","LOAD_DTM":"20260423"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7011469","SCHUL_NM":"덜위치칼리지서울영국학교","ENG_SCHUL_NM":"Dulwich College Seoul British School","SCHUL_KND_SC_NM":"외국인학교","LCTN_SC_NM":"서울특별시","JU_ORG_NM":"서울특별시교육청","FOND_SC_NM":"사립","ORG_RDNZC":"06504 ","ORG_RDNMA":"서울특별시 서초구 신반포로15길 6","ORG_RDNDA":"(반포동)","ORG_TELNO":"02-3015-8500","HMPG_ADRES":"http://www.dulwich-seoul.kr","COEDU_SC_NM":"남여공학","ORG_FAXNO":"02-501-9748","HS_SC_NM":null,"INDST_SPECL_CCCCL_EXST_YN":"N","HS_GNRL_BUSNS_SC_NM":null,"SPCLY_PURPS_HS_ORD_NM":null,"ENE_BFE_SEHF_SC_NM":"전기","DGHT_SC_NM":"주간","FOND_YMD":"20101020","FOAS_MEMRD":"20101020","LOAD_DTM":"20260423"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7051183","SCHUL_NM":"북서울중학교","ENG_SCHUL_NM":"Bukseoul Middle School","SCHUL_KND_SC_NM":"중학교","LCTN_SC_NM":"서울특별시","JU_ORG_NM":"서울특별시북부교육지원청","FOND_SC_NM":"공립","ORG_RDNZC":"01305 ","ORG_RDNMA":"서울특별시 도봉구 도봉로169가길 33","ORG_RDNDA":"(도봉동)","ORG_TELNO":"02-956-1004","HMPG_ADRES":"https://bukseoul.sen.ms.kr","COEDU_SC_NM":"남여공학","ORG_FAXNO":"02-955-8290","HS_SC_NM":null,"INDST_SPECL_CCCCL_EXST_YN":"N","HS_GNRL_BUSNS_SC_NM":"일반계","SPCLY_PURPS_HS_ORD_NM":null,"ENE_BFE_SEHF_SC_NM":"전기","DGHT_SC_NM":"주간","FOND_YMD":"19841208","FOAS_MEMRD":"19851208","LOAD_DTM":"20260423"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010721","SCHUL_NM":"서서울생활과학고등학교","ENG_SCHUL_NM":"Seoseoul Life Science High School","SCHUL_KND_SC_NM":"고등학교","LCTN_SC_NM":"서울특별시","JU_ORG_NM":"서울특별시교육청","FOND_SC_NM":"사립","ORG_RDNZC":"08248 ","ORG_RDNMA":"서울특별시 구로구 오리로 1355-10","ORG_RDNDA":", 서서울생활과학고등학교 (궁동)","ORG_TELNO":"02-2613-5273","HMPG_ADRES":"http://ssls.sen.hs.kr","COEDU_SC_NM":"남여공학","ORG_FAXNO":"02-2612-0554","HS_SC_NM":"특성화고","INDST_SPECL_CCCCL_EXST_YN":"N","HS_GNRL_BUSNS_SC_NM":"전문계","SPCLY_PURPS_HS_ORD_NM":null,"ENE_BFE_SEHF_SC_NM":"전기","DGHT_SC_NM":"주간","FOND_YMD":"19720305","FOAS_MEMRD":"19720331","LOAD_DTM":"20260423"}]}]}"#

private let fxSchoolHigh = #"{"schoolInfo":[{"head":[{"list_total_count":1},{"RESULT":{"CODE":"INFO-000","MESSAGE":"정상 처리되었습니다."}}]},{"row":[{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010083","SCHUL_NM":"서울고등학교","ENG_SCHUL_NM":"Seoul High School","SCHUL_KND_SC_NM":"고등학교","LCTN_SC_NM":"서울특별시","JU_ORG_NM":"서울특별시교육청","FOND_SC_NM":"공립","ORG_RDNZC":"06669 ","ORG_RDNMA":"서울특별시 서초구 효령로 197","ORG_RDNDA":"(서초동,서울고등학교)","ORG_TELNO":"02-582-8151","HMPG_ADRES":"http://seoul.sen.hs.kr","COEDU_SC_NM":"남","ORG_FAXNO":"02-587-3933","HS_SC_NM":"일반고","INDST_SPECL_CCCCL_EXST_YN":"N","HS_GNRL_BUSNS_SC_NM":"일반계","SPCLY_PURPS_HS_ORD_NM":null,"ENE_BFE_SEHF_SC_NM":"후기","DGHT_SC_NM":"주간","FOND_YMD":"19460201","FOAS_MEMRD":"19460201","LOAD_DTM":"20260423"}]}]}"#

private let fxErrNoData = #"{"RESULT":{"CODE":"INFO-200","MESSAGE":"해당하는 데이터가 없습니다."}}"#

private let fxErrKey = #"{"RESULT":{"CODE":"ERROR-290","MESSAGE":"인증키가 유효하지 않습니다. 인증키가 없는 경우, 홈페이지에서 인증키를 신청하십시오."}}"#

private let fxErrParam = #"{"RESULT":{"CODE":"ERROR-300","MESSAGE":"필수 값이 누락되어 있습니다. 요청인자를 참고 하십시오."}}"#

private let fxErrService = #"{"RESULT":{"CODE":"ERROR-310","MESSAGE":"해당하는 서비스를 찾을 수 없습니다. 요청인자 중 SERVICE를 확인하십시오."}}"#

private let fxHisDupes = #"{"hisTimetable":[{"head":[{"list_total_count":454},{"RESULT":{"CODE":"INFO-000","MESSAGE":"정상 처리되었습니다."}}]},{"row":[{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010278","SCHUL_NM":"서울공업고등학교","AY":"2025","SEM":"2","ALL_TI_YMD":"20251013","DGHT_CRSE_SC_NM":"주간","ORD_SC_NM":"공업계","DDDEP_NM":"그래픽아트과","GRADE":"1","CLRM_NM":"1","CLASS_NM":"1","PERIO":"1","ITRT_CNTNT":"* 조색","LOAD_DTM":"20251019"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010278","SCHUL_NM":"서울공업고등학교","AY":"2025","SEM":"2","ALL_TI_YMD":"20251013","DGHT_CRSE_SC_NM":"주간","ORD_SC_NM":"공업계","DDDEP_NM":"그래픽아트과","GRADE":"1","CLRM_NM":"1","CLASS_NM":"1","PERIO":"1","ITRT_CNTNT":"* 조색","LOAD_DTM":"20251019"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010278","SCHUL_NM":"서울공업고등학교","AY":"2025","SEM":"2","ALL_TI_YMD":"20251013","DGHT_CRSE_SC_NM":"주간","ORD_SC_NM":"공업계","DDDEP_NM":"그래픽아트과","GRADE":"1","CLRM_NM":"1","CLASS_NM":"1","PERIO":"2","ITRT_CNTNT":"* 조색","LOAD_DTM":"20251019"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010278","SCHUL_NM":"서울공업고등학교","AY":"2025","SEM":"2","ALL_TI_YMD":"20251013","DGHT_CRSE_SC_NM":"주간","ORD_SC_NM":"공업계","DDDEP_NM":"그래픽아트과","GRADE":"1","CLRM_NM":"1","CLASS_NM":"1","PERIO":"2","ITRT_CNTNT":"* 조색","LOAD_DTM":"20251019"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010278","SCHUL_NM":"서울공업고등학교","AY":"2025","SEM":"2","ALL_TI_YMD":"20251013","DGHT_CRSE_SC_NM":"주간","ORD_SC_NM":"공업계","DDDEP_NM":"그래픽아트과","GRADE":"1","CLRM_NM":"1","CLASS_NM":"1","PERIO":"3","ITRT_CNTNT":"* 배색","LOAD_DTM":"20251019"}]}]}"#

private let fxHisElective = #"{"hisTimetable":[{"head":[{"list_total_count":8},{"RESULT":{"CODE":"INFO-000","MESSAGE":"정상 처리되었습니다."}}]},{"row":[{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261104","DGHT_CRSE_SC_NM":"주간","ORD_SC_NM":"일반계","DDDEP_NM":"과학과","GRADE":"2","CLRM_NM":"1","CLASS_NM":"1","PERIO":"5","ITRT_CNTNT":"R&E","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261104","DGHT_CRSE_SC_NM":"주간","ORD_SC_NM":"일반계","DDDEP_NM":"과학과","GRADE":"2","CLRM_NM":"1","CLASS_NM":"1","PERIO":"6","ITRT_CNTNT":"R&E","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261104","DGHT_CRSE_SC_NM":"주간","ORD_SC_NM":"일반계","DDDEP_NM":"과학과","GRADE":"2","CLRM_NM":"1","CLASS_NM":"1","PERIO":"7","ITRT_CNTNT":"R&E","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261106","DGHT_CRSE_SC_NM":"주간","ORD_SC_NM":"일반계","DDDEP_NM":"과학과","GRADE":"2","CLRM_NM":"1","CLASS_NM":"1","PERIO":"6","ITRT_CNTNT":"자율활동","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261107","DGHT_CRSE_SC_NM":"주간","ORD_SC_NM":"일반계","DDDEP_NM":"과학과","GRADE":"2","CLRM_NM":"1","CLASS_NM":"1","PERIO":"1","ITRT_CNTNT":"토요휴업일","LOAD_DTM":"20261107"}]}]}"#

private let fxHisHoliday = #"{"hisTimetable":[{"head":[{"list_total_count":34},{"RESULT":{"CODE":"INFO-000","MESSAGE":"정상 처리되었습니다."}}]},{"row":[{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261102","DGHT_CRSE_SC_NM":"주간","ORD_SC_NM":"일반계","DDDEP_NM":"과학과","GRADE":"1","CLRM_NM":"1","CLASS_NM":"1","PERIO":"1","ITRT_CNTNT":"재량휴업일","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261102","DGHT_CRSE_SC_NM":"주간","ORD_SC_NM":"일반계","DDDEP_NM":"과학과","GRADE":"1","CLRM_NM":"1","CLASS_NM":"1","PERIO":"2","ITRT_CNTNT":"재량휴업일","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261102","DGHT_CRSE_SC_NM":"주간","ORD_SC_NM":"일반계","DDDEP_NM":"과학과","GRADE":"1","CLRM_NM":"1","CLASS_NM":"1","PERIO":"3","ITRT_CNTNT":"재량휴업일","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261102","DGHT_CRSE_SC_NM":"주간","ORD_SC_NM":"일반계","DDDEP_NM":"과학과","GRADE":"1","CLRM_NM":"1","CLASS_NM":"1","PERIO":"4","ITRT_CNTNT":"재량휴업일","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261102","DGHT_CRSE_SC_NM":"주간","ORD_SC_NM":"일반계","DDDEP_NM":"과학과","GRADE":"1","CLRM_NM":"1","CLASS_NM":"1","PERIO":"5","ITRT_CNTNT":"재량휴업일","LOAD_DTM":"20261107"}]}]}"#

private let fxMealBreakfast = #"{"mealServiceDietInfo":[{"head":[{"list_total_count":14},{"RESULT":{"CODE":"INFO-000","MESSAGE":"정상 처리되었습니다."}}]},{"row":[{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","MMEAL_SC_CODE":"1","MMEAL_SC_NM":"조식","MLSV_YMD":"20251013","MLSV_FGR":240.0,"DDISH_NM":"옥수수스프(과학고) (2.5.6.13.16)<br/>토스트+ 딸기잼,땅콩버터(과학고) (2.4.5.6.13)<br/>*시져샐러드(과) (1.2.5.6.10.12)<br/>*치킨스테이크(과) (1.2.5.6.10.15.16)<br/>*케이준감자튀김(과) (5.6.12)<br/>*사과(과) <br/>시리얼 (2.5.6)<br/>모듬피클(과) ","ORPLC_INFO":"쇠고기(종류) : 국내산(한우)<br/>쇠고기 식육가공품 : 국내산<br/>돼지고기 : 국내산<br/>돼지고기 식육가공품 : 외국산(립)<br/>닭고기 : 국내산<br/>닭고기 식육가공품 : 국내산<br/>오리고기 : 국내산<br/>오리고기 가공품 : 국내산<br/>쌀 : 국내산<br/>배추 : 국내산<br/>고춧가루 : 국내산<br/>콩 : 국내산<br/>콩 가공품 : 국내산<br/>낙지 : 국내산or 중국or베트남<br/>명태 : 러시아<br/>고등어 : 국내산<br/>갈치 : 국내산or세네갈<br/>오징어 : 국내산<br/>꽃게 : 국내산<br/>참조기 : 국내산<br/>주꾸미 : 국내산or베트남","CAL_INFO":"651.0 Kcal","NTR_INFO":"탄수화물(g) : 71.0<br/>단백질(g) : 20.1<br/>지방(g) : 32.2<br/>비타민A(R.E) : 124.7<br/>티아민(mg) : 2.2<br/>리보플라빈(mg) : 0.4<br/>비타민C(mg) : 11.6<br/>칼슘(mg) : 229.9<br/>철분(mg) : 1.0","MLSV_FROM_YMD":"20251013","MLSV_TO_YMD":"20251013","LOAD_DTM":"20251020"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","MMEAL_SC_CODE":"1","MMEAL_SC_NM":"조식","MLSV_YMD":"20251014","MLSV_FGR":240.0,"DDISH_NM":"*찹쌀밥 <br/>*순대국/양념장(과) (2.5.6.9.10.13.16)<br/>*돼지고기메추리알장조림(과) (1.5.6.10.13)<br/>*영양부추무침(과) (5.6.13)<br/>*새송이버섯전 (1.5.6.13)<br/>*깍두기 (9)<br/>크림브륄레 (1.2.6)<br/>*우유 (2)","ORPLC_INFO":"쇠고기(종류) : 국내산(한우)<br/>쇠고기 식육가공품 : 국내산<br/>돼지고기 : 국내산<br/>돼지고기 식육가공품 : 외국산(립)<br/>닭고기 : 국내산<br/>닭고기 식육가공품 : 국내산<br/>오리고기 : 국내산<br/>오리고기 가공품 : 국내산<br/>쌀 : 국내산<br/>배추 : 국내산<br/>고춧가루 : 국내산<br/>콩 : 국내산<br/>콩 가공품 : 국내산<br/>낙지 : 국내산or 중국or베트남<br/>명태 : 러시아<br/>고등어 : 국내산<br/>갈치 : 국내산or세네갈<br/>오징어 : 국내산<br/>꽃게 : 국내산<br/>참조기 : 국내산<br/>주꾸미 : 국내산or베트남","CAL_INFO":"756.7 Kcal","NTR_INFO":"탄수화물(g) : 99.5<br/>단백질(g) : 32.1<br/>지방(g) : 24.0<br/>비타민A(R.E) : 185.1<br/>티아민(mg) : 0.6<br/>리보플라빈(mg) : 2.0<br/>비타민C(mg) : 4.4<br/>칼슘(mg) : 298.4<br/>철분(mg) : 4.1","MLSV_FROM_YMD":"20251014","MLSV_TO_YMD":"20251014","LOAD_DTM":"20251021"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","MMEAL_SC_CODE":"1","MMEAL_SC_NM":"조식","MLSV_YMD":"20251015","MLSV_FGR":240.0,"DDISH_NM":"*찹쌀밥 <br/>*옹심이수제비국 (1.5.6)<br/>*돈등뼈김치찜(과) (5.6.9.10.13)<br/>*열무무침- (5.6.13)<br/>해물완자전(과학고) (1.2.5.6.8.9.12.16.17.18)<br/>*배추김치 (9)<br/>*요구르트 (2)<br/>*피칸파이 (1.2.5.6.14)","ORPLC_INFO":"쇠고기(종류) : 국내산(한우)<br/>쇠고기 식육가공품 : 국내산<br/>돼지고기 : 국내산<br/>돼지고기 식육가공품 : 외국산(립)<br/>닭고기 : 국내산<br/>닭고기 식육가공품 : 국내산<br/>오리고기 : 국내산<br/>오리고기 가공품 : 국내산<br/>쌀 : 국내산<br/>배추 : 국내산<br/>고춧가루 : 국내산<br/>콩 : 국내산<br/>콩 가공품 : 국내산<br/>낙지 : 국내산or 중국or베트남<br/>명태 : 러시아<br/>고등어 : 국내산<br/>갈치 : 국내산or세네갈<br/>오징어 : 국내산<br/>꽃게 : 국내산<br/>참조기 : 국내산<br/>주꾸미 : 국내산or베트남","CAL_INFO":"715.6 Kcal","NTR_INFO":"탄수화물(g) : 120.9<br/>단백질(g) : 25.3<br/>지방(g) : 14.3<br/>비타민A(R.E) : 117.6<br/>티아민(mg) : 0.7<br/>리보플라빈(mg) : 0.5<br/>비타민C(mg) : 12.6<br/>칼슘(mg) : 163.8<br/>철분(mg) : 2.6","MLSV_FROM_YMD":"20251015","MLSV_TO_YMD":"20251015","LOAD_DTM":"20251022"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","MMEAL_SC_CODE":"1","MMEAL_SC_NM":"조식","MLSV_YMD":"20251016","MLSV_FGR":240.0,"DDISH_NM":"*알리오올리오(과) (1.2.5.6.13.15)<br/>모닝빵+잼,버터 (1.2.5.6.13)<br/>*큐브스테이크 (2.5.6.10.12.13.15.16)<br/>단호박스프(과학고) (2.5.6.13.16)<br/>*골드키위(반개) <br/>시리얼 (2.5.6)<br/>우유(조) (2)<br/>블루베리샐러드(과학고) (2.13)<br/>모듬피클(과) ","ORPLC_INFO":"쇠고기(종류) : 국내산(한우)<br/>쇠고기 식육가공품 : 국내산<br/>돼지고기 : 국내산<br/>돼지고기 식육가공품 : 외국산(립)<br/>닭고기 : 국내산<br/>닭고기 식육가공품 : 국내산<br/>오리고기 : 국내산<br/>오리고기 가공품 : 국내산<br/>쌀 : 국내산<br/>배추 : 국내산<br/>고춧가루 : 국내산<br/>콩 : 국내산<br/>콩 가공품 : 국내산<br/>낙지 : 국내산or 중국or베트남<br/>명태 : 러시아<br/>고등어 : 국내산<br/>갈치 : 국내산or세네갈<br/>오징어 : 국내산<br/>꽃게 : 국내산<br/>참조기 : 국내산<br/>주꾸미 : 국내산or베트남","CAL_INFO":"921.3 Kcal","NTR_INFO":"탄수화물(g) : 100.9<br/>단백질(g) : 20.5<br/>지방(g) : 48.4<br/>비타민A(R.E) : 293.6<br/>티아민(mg) : 0.3<br/>리보플라빈(mg) : 0.8<br/>비타민C(mg) : 67.7<br/>칼슘(mg) : 405.9<br/>철분(mg) : 2.6","MLSV_FROM_YMD":"20251016","MLSV_TO_YMD":"20251016","LOAD_DTM":"20251023"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","MMEAL_SC_CODE":"1","MMEAL_SC_NM":"조식","MLSV_YMD":"20251017","MLSV_FGR":240.0,"DDISH_NM":"간장계란밥 (1.2.5.6)<br/>돈육김치찌개(과) (5.6.9.10)<br/>*시금치나물- (5.6)<br/>*김자반멸치볶음(과) (5)<br/>*미니돈까스 (1.5.6.10.12.13.18)<br/>*깍두기 (9)<br/>*우유 (2)<br/>*망고와플 (1.2.5.6.13)","ORPLC_INFO":"쇠고기(종류) : 국내산(한우)<br/>쇠고기 식육가공품 : 국내산<br/>돼지고기 : 국내산<br/>돼지고기 식육가공품 : 외국산(립)<br/>닭고기 : 국내산<br/>닭고기 식육가공품 : 국내산<br/>오리고기 : 국내산<br/>오리고기 가공품 : 국내산<br/>쌀 : 국내산<br/>배추 : 국내산<br/>고춧가루 : 국내산<br/>콩 : 국내산<br/>콩 가공품 : 국내산<br/>낙지 : 국내산or 중국or베트남<br/>명태 : 러시아<br/>고등어 : 국내산<br/>갈치 : 국내산or세네갈<br/>오징어 : 국내산<br/>꽃게 : 국내산<br/>참조기 : 국내산<br/>주꾸미 : 국내산or베트남","CAL_INFO":"708.5 Kcal","NTR_INFO":"탄수화물(g) : 71.5<br/>단백질(g) : 30.6<br/>지방(g) : 32.9<br/>비타민A(R.E) : 276.5<br/>티아민(mg) : 0.5<br/>리보플라빈(mg) : 0.8<br/>비타민C(mg) : 9.4<br/>칼슘(mg) : 365.5<br/>철분(mg) : 4.1","MLSV_FROM_YMD":"20251017","MLSV_TO_YMD":"20251017","LOAD_DTM":"20251024"}]}]}"#

private let fxMealDay = #"{"mealServiceDietInfo":[{"head":[{"list_total_count":2},{"RESULT":{"CODE":"INFO-000","MESSAGE":"정상 처리되었습니다."}}]},{"row":[{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010083","SCHUL_NM":"서울고등학교","MMEAL_SC_CODE":"2","MMEAL_SC_NM":"중식","MLSV_YMD":"20261103","MLSV_FGR":1295.0,"DDISH_NM":"쌀밥 <br/>게살스프 (1.5.6.8)<br/>바오번고추잡채 (5.6.10.13.18)<br/>마파두부 (5.6.10.12.13.18)<br/>배추김치 (9)<br/>궁채절임 (5.6.13)","ORPLC_INFO":"쇠고기(종류) : 국내산(한우)<br/>쇠고기 식육가공품 : 국내산<br/>돼지고기 : 국내산<br/>돼지고기 식육가공품 : 국내산<br/>닭고기 : 국내산<br/>닭고기 식육가공품 : 국내산<br/>오리고기 : 국내산<br/>오리고기 가공품 : 국내산<br/>쌀 : 국내산<br/>배추 : 국내산<br/>고춧가루 : 국내산<br/>콩 : 국내산<br/>낙지 : 국내산<br/>고등어 : 국내산<br/>갈치 : 국내산<br/>오징어 : 국내산<br/>꽃게 : 국내산<br/>참조기 : 국내산<br/>비고 : ","CAL_INFO":"594.3 Kcal","NTR_INFO":"탄수화물(g) : 72.1<br/>단백질(g) : 29.9<br/>지방(g) : 20.9<br/>비타민A(R.E) : 52.7<br/>티아민(mg) : 0.8<br/>리보플라빈(mg) : 0.4<br/>비타민C(mg) : 24.2<br/>칼슘(mg) : 190.8<br/>철분(mg) : 2.9","MLSV_FROM_YMD":"20261103","MLSV_TO_YMD":"20261103","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010083","SCHUL_NM":"서울고등학교","MMEAL_SC_CODE":"3","MMEAL_SC_NM":"석식","MLSV_YMD":"20261103","MLSV_FGR":250.0,"DDISH_NM":"김밥볶음밥 (1.2.5.6.10.13.15.16)<br/>김치어묵우동 (1.5.6.9.13)<br/>크림치즈파이 (2.5.6)<br/>멕시칸샐러드 (1.2.5.6.10.13.15.16)<br/>닭꼬치 (5.6.13.15)<br/>깍두기 (9)","ORPLC_INFO":"쇠고기(종류) : 국내산(한우)<br/>쇠고기 식육가공품 : 국내산<br/>돼지고기 : 국내산<br/>돼지고기 식육가공품 : 국내산<br/>닭고기 : 국내산<br/>닭고기 식육가공품 : 국내산<br/>오리고기 : 국내산<br/>오리고기 가공품 : 국내산<br/>쌀 : 국내산<br/>배추 : 국내산<br/>고춧가루 : 국내산<br/>콩 : 국내산<br/>낙지 : 국내산<br/>고등어 : 국내산<br/>갈치 : 국내산<br/>오징어 : 국내산<br/>꽃게 : 국내산<br/>참조기 : 국내산<br/>비고 : ","CAL_INFO":"858.3 Kcal","NTR_INFO":"탄수화물(g) : 93.5<br/>단백질(g) : 34.2<br/>지방(g) : 40.2<br/>비타민A(R.E) : 207.1<br/>티아민(mg) : 0.5<br/>리보플라빈(mg) : 0.9<br/>비타민C(mg) : 20.3<br/>칼슘(mg) : 142.5<br/>철분(mg) : 11.4","MLSV_FROM_YMD":"20261103","MLSV_TO_YMD":"20261103","LOAD_DTM":"20261107"}]}]}"#

private let fxMealThree = #"{"mealServiceDietInfo":[{"head":[{"list_total_count":3},{"RESULT":{"CODE":"INFO-000","MESSAGE":"정상 처리되었습니다."}}]},{"row":[{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","MMEAL_SC_CODE":"1","MMEAL_SC_NM":"조식","MLSV_YMD":"20261103","MLSV_FGR":240.0,"DDISH_NM":"*발아현미밥 <br/>미니생크림케이크 (1.2.5.6)<br/>*순대국/양념장(과) (2.5.6.9.10.13.16)<br/>돼지고기메추리알장조림(조)(과학고) (1.5.6.10.13)<br/>*아삭이고추무침-(과) (5.6)<br/>애호박새우살전 (5.6.9.13.18)<br/>*깍두기 (9)<br/>*우유 (2)","ORPLC_INFO":"쇠고기(종류) : 국내산(한우)<br/>쇠고기 식육가공품 : 국내산<br/>돼지고기 : 국내산<br/>돼지고기 식육가공품 : 외국산(립)<br/>닭고기 : 국내산<br/>닭고기 식육가공품 : 국내산<br/>오리고기 : 국내산<br/>오리고기 가공품 : 국내산<br/>쌀 : 국내산<br/>배추 : 국내산<br/>고춧가루 : 국내산<br/>콩 : 국내산<br/>콩 가공품 : 국내산<br/>미꾸라지 : 국내산<br/>낙지 : 중국 or 베트남<br/>명태 : 러시아<br/>고등어 : 국내산<br/>갈치 : 세네갈<br/>오징어 : 국내산 or 원양산<br/>꽃게 : 국내산<br/>참조기 : 국내산<br/>아귀 : 국내산<br/>주꾸미 : 중국 or 베트남<br/>전복 : 국내산","CAL_INFO":"824.5 Kcal","NTR_INFO":"탄수화물(g) : 137.8<br/>단백질(g) : 19.5<br/>지방(g) : 21.2<br/>비타민A(R.E) : 142.6<br/>티아민(mg) : 0.3<br/>리보플라빈(mg) : 0.5<br/>비타민C(mg) : 9.5<br/>칼슘(mg) : 232.2<br/>철분(mg) : 4.1","MLSV_FROM_YMD":"20261103","MLSV_TO_YMD":"20261103","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","MMEAL_SC_CODE":"2","MMEAL_SC_NM":"중식","MLSV_YMD":"20261103","MLSV_FGR":471.0,"DDISH_NM":"*혼합잡곡밥 (5)<br/>홍합미역국(과) (5.6.18)<br/>*수육&마늘소스(과) (2.5.6.10)<br/>*콩나물파채무침(과) (5.13)<br/>*보쌈김치((과) (9)<br/>*에그타르트 (1.2.5.6)<br/>*야채쌈/쌈장(과) (5.6)","ORPLC_INFO":"쇠고기(종류) : 국내산(한우)<br/>쇠고기 식육가공품 : 국내산<br/>돼지고기 : 국내산<br/>돼지고기 식육가공품 : 외국산(립)<br/>닭고기 : 국내산<br/>닭고기 식육가공품 : 국내산<br/>오리고기 : 국내산<br/>오리고기 가공품 : 국내산<br/>쌀 : 국내산<br/>배추 : 국내산<br/>고춧가루 : 국내산<br/>콩 : 국내산<br/>콩 가공품 : 국내산<br/>미꾸라지 : 국내산<br/>낙지 : 중국 or 베트남<br/>명태 : 러시아<br/>고등어 : 국내산<br/>갈치 : 세네갈<br/>오징어 : 국내산 or 원양산<br/>꽃게 : 국내산<br/>참조기 : 국내산<br/>아귀 : 국내산<br/>주꾸미 : 중국 or 베트남<br/>전복 : 국내산","CAL_INFO":"938.2 Kcal","NTR_INFO":"탄수화물(g) : 114.0<br/>단백질(g) : 41.1<br/>지방(g) : 33.4<br/>비타민A(R.E) : 112.8<br/>티아민(mg) : 1.0<br/>리보플라빈(mg) : 0.4<br/>비타민C(mg) : 9.9<br/>칼슘(mg) : 219.0<br/>철분(mg) : 4.7","MLSV_FROM_YMD":"20261103","MLSV_TO_YMD":"20261103","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7010084","SCHUL_NM":"서울과학고등학교","MMEAL_SC_CODE":"3","MMEAL_SC_NM":"석식","MLSV_YMD":"20261103","MLSV_FGR":300.0,"DDISH_NM":"현미밀쌀밥(중) (6)<br/>*육개장(과) (2.5.6.13.16)<br/>참나물무침 (5.6.13)<br/>수제소시지버섯볶음 (2.5.6.10.12.13.15.16.18)<br/>가자미빵가루튀김.양파드레싱 (1.2.5.6)<br/>*깍두기 (9)<br/>*포도 ","ORPLC_INFO":"쇠고기(종류) : 국내산(한우)<br/>쇠고기 식육가공품 : 국내산<br/>돼지고기 : 국내산<br/>돼지고기 식육가공품 : 국내산<br/>닭고기 : 국내산<br/>닭고기 식육가공품 : 국내산<br/>오리고기 : 국내산<br/>오리고기 가공품 : 국내산<br/>쌀 : 국내산<br/>배추 : 국내산<br/>고춧가루 : 국내산<br/>콩 : 국내산<br/>미꾸라지 : 국내산<br/>낙지 : 국내산/중국산/베트남산<br/>명태 : 러시아산<br/>고등어 : 국내산<br/>갈치 : 국내산/세네갈<br/>오징어 : 국내산/국내산수급불가시수입산<br/>꽃게 : 국내산<br/>참조기 : 국내산<br/>주꾸미 : 국내산/베트남산<br/>비고 : ","CAL_INFO":"996.7 Kcal","NTR_INFO":"탄수화물(g) : 142.9<br/>단백질(g) : 44.7<br/>지방(g) : 25.9<br/>비타민A(R.E) : 353.6<br/>티아민(mg) : 1.1<br/>리보플라빈(mg) : 1.0<br/>비타민C(mg) : 68.2<br/>칼슘(mg) : 272.7<br/>철분(mg) : 5.2","MLSV_FROM_YMD":"20261103","MLSV_TO_YMD":"20261103","LOAD_DTM":"20261107"}]}]}"#

private let fxMisDay = #"{"misTimetable":[{"head":[{"list_total_count":6},{"RESULT":{"CODE":"INFO-000","MESSAGE":"정상 처리되었습니다."}}]},{"row":[{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7132131","SCHUL_NM":"남서울중학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261103","DGHT_CRSE_SC_NM":"주간","GRADE":"1","CLASS_NM":"1","PERIO":"1","ITRT_CNTNT":"사회","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7132131","SCHUL_NM":"남서울중학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261103","DGHT_CRSE_SC_NM":"주간","GRADE":"1","CLASS_NM":"1","PERIO":"2","ITRT_CNTNT":"음악","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7132131","SCHUL_NM":"남서울중학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261103","DGHT_CRSE_SC_NM":"주간","GRADE":"1","CLASS_NM":"1","PERIO":"3","ITRT_CNTNT":"수학","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7132131","SCHUL_NM":"남서울중학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261103","DGHT_CRSE_SC_NM":"주간","GRADE":"1","CLASS_NM":"1","PERIO":"4","ITRT_CNTNT":"체육","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7132131","SCHUL_NM":"남서울중학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261103","DGHT_CRSE_SC_NM":"주간","GRADE":"1","CLASS_NM":"1","PERIO":"5","ITRT_CNTNT":"국어","LOAD_DTM":"20261107"}]}]}"#

private let fxMisDayP6 = #"{"misTimetable":[{"head":[{"list_total_count":1},{"RESULT":{"CODE":"INFO-000","MESSAGE":"정상 처리되었습니다."}}]},{"row":[{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7132131","SCHUL_NM":"남서울중학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261103","DGHT_CRSE_SC_NM":"주간","GRADE":"1","CLASS_NM":"1","PERIO":"6","ITRT_CNTNT":"기술·가정","LOAD_DTM":"20261107"}]}]}"#

private let fxMisSat = #"{"misTimetable":[{"head":[{"list_total_count":4},{"RESULT":{"CODE":"INFO-000","MESSAGE":"정상 처리되었습니다."}}]},{"row":[{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7132131","SCHUL_NM":"남서울중학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261107","DGHT_CRSE_SC_NM":"주간","GRADE":"1","CLASS_NM":"1","PERIO":"1","ITRT_CNTNT":"토요휴업일","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7132131","SCHUL_NM":"남서울중학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261107","DGHT_CRSE_SC_NM":"주간","GRADE":"1","CLASS_NM":"1","PERIO":"2","ITRT_CNTNT":"토요휴업일","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7132131","SCHUL_NM":"남서울중학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261107","DGHT_CRSE_SC_NM":"주간","GRADE":"1","CLASS_NM":"1","PERIO":"3","ITRT_CNTNT":"토요휴업일","LOAD_DTM":"20261107"},{"ATPT_OFCDC_SC_CODE":"B10","ATPT_OFCDC_SC_NM":"서울특별시교육청","SD_SCHUL_CODE":"7132131","SCHUL_NM":"남서울중학교","AY":"2026","SEM":"2","ALL_TI_YMD":"20261107","DGHT_CRSE_SC_NM":"주간","GRADE":"1","CLASS_NM":"1","PERIO":"4","ITRT_CNTNT":"토요휴업일","LOAD_DTM":"20261107"}]}]}"#


// MARK: - 도우미

private func data(_ text: String) -> Data { Data(text.utf8) }

/// ISO 시각 → Date
private func at(_ iso: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: iso) ?? Date(timeIntervalSince1970: 0)
}

private func thrown(_ body: () throws -> Void) -> NeisError? {
    do { try body() } catch { return error as? NeisError }
    return nil
}

private let mis = School(officeCode: "B10", schoolCode: "7132131", name: "남서울중학교", kindName: "중학교", region: "서울특별시", address: "")
private let els = School(officeCode: "D10", schoolCode: "7271066", name: "남대구초등학교", kindName: "초등학교", region: "대구광역시", address: "")
private let his = School(officeCode: "B10", schoolCode: "7010278", name: "서울공업고등학교", kindName: "고등학교", region: "서울특별시", address: "", highSchoolType: "특성화고")
private let sps = School(officeCode: "B10", schoolCode: "1342099", name: "서울농학교", kindName: "특수학교", region: "서울특별시", address: "")

func runNeisCases() {
    runNeisParserPageCases()
    runNeisSchoolCases()
    runNeisTimetableCases()
    runNeisMealCases()
    runNeisDateCases()
    runNeisAPICases()
    runNeisCacheCases()
}

// MARK: - 겉 모양 · 오류

private func runNeisParserPageCases() {
    // 정상: 총 개수와 줄
    if let p = try? NeisParser.page(data(fxElsWeek), service: "elsTimetable") {
        check("정상 응답: 총 21줄", p.total == 21, "\(p.total)")
        check("정상 응답: 키 없이는 5줄만", p.rows.count == 5, "\(p.rows.count)")
        check("정상 응답: 값이 글자로", p.rows.first?["ITRT_CNTNT"] == "국어" && p.rows.first?["PERIO"] == "1")
    } else {
        check("정상 응답 읽기", false)
    }
    // 숫자 · null 값은 글자로
    if let p = try? NeisParser.page(data(fxMealEls), service: "mealServiceDietInfo") {
        check("숫자 값(MLSV_FGR)이 글자로", p.rows.first?["MLSV_FGR"] == "234.0", "\(p.rows.first?["MLSV_FGR"] ?? "nil")")
    } else {
        check("급식 응답 읽기", false)
    }
    if let p = try? NeisParser.page(data(fxSchoolList), service: "schoolInfo") {
        check("null 값은 빈 글자", p.rows.contains { $0["SPCLY_PURPS_HS_ORD_NM"] == "" || $0["SPCLY_PURPS_HS_ORD_NM"] == nil })
    }
    // 데이터 없음 (INFO-200): 빈 쪽, 오류 아님
    var emptyPage: NeisParser.Page?
    let e200 = thrown { emptyPage = try NeisParser.page(data(fxErrNoData), service: "schoolInfo") }
    check("INFO-200은 오류가 아님", e200 == nil)
    check("INFO-200은 빈 쪽", emptyPage == NeisParser.Page(total: 0, rows: []), "\(String(describing: emptyPage))")
    // 서비스 키 안에 INFO-200이 들어온 경우
    let inner = #"{"mealServiceDietInfo":[{"head":[{"list_total_count":0},{"RESULT":{"CODE":"INFO-200","MESSAGE":"해당하는 데이터가 없습니다."}}]}]}"#
    var innerPage: NeisParser.Page?
    let eInner = thrown { innerPage = try NeisParser.page(data(inner), service: "mealServiceDietInfo") }
    check("head 안 INFO-200도 빈 쪽", eInner == nil && innerPage?.rows.isEmpty == true)
    // 오류 코드
    check("ERROR-290 → 인증키 오류", thrown { _ = try NeisParser.page(data(fxErrKey), service: "mealServiceDietInfo") } == .badKey("인증키가 유효하지 않습니다. 인증키가 없는 경우, 홈페이지에서 인증키를 신청하십시오."))
    check("ERROR-300 → 요청 값 오류", { if case .badRequest? = thrown({ _ = try NeisParser.page(data(fxErrParam), service: "mealServiceDietInfo") }) { return true }; return false }())
    check("ERROR-310 → 요청 값 오류(서비스 없음)", { if case .badRequest? = thrown({ _ = try NeisParser.page(data(fxErrService), service: "x") }) { return true }; return false }())
    func code(_ c: String) -> NeisError? { NeisError.from(code: c, message: "m") }
    check("INFO-000은 오류 없음", code("INFO-000") == nil)
    check("INFO-200 → noData", code("INFO-200") == .noData)
    check("INFO-100 → badKey", code("INFO-100") == .badKey("m"))
    check("INFO-290 → badKey", code("INFO-290") == .badKey("m"))
    check("INFO-300 → limited", code("INFO-300") == .limited("m"))
    check("ERROR-337 → limited (일일 트래픽)", code("ERROR-337") == .limited("m"))
    check("ERROR-336 → badRequest (1000건 초과)", code("ERROR-336") == .badRequest("m"))
    check("ERROR-333 → badRequest", code("ERROR-333") == .badRequest("m"))
    check("ERROR-500 → server", code("ERROR-500") == .server("m"))
    check("ERROR-600 → server", code("ERROR-600") == .server("m"))
    check("ERROR-601 → server", code("ERROR-601") == .server("m"))
    check("모르는 ERROR-999 → server", code("ERROR-999") == .server("m"))
    check("모르는 코드는 badRequest", code("WARN-1") == .badRequest("m"))
    // 망가진 응답
    check("JSON이 아니면 malformed", thrown { _ = try NeisParser.page(data("<html>502</html>"), service: "schoolInfo") } == .malformed)
    check("빈 응답은 malformed", thrown { _ = try NeisParser.page(Data(), service: "schoolInfo") } == .malformed)
    check("서비스 키가 없으면 malformed", thrown { _ = try NeisParser.page(data(#"{"other":[]}"#), service: "schoolInfo") } == .malformed)
    check("배열 최상위는 malformed", thrown { _ = try NeisParser.page(data("[1,2]"), service: "schoolInfo") } == .malformed)
    // row 없이 head만 (정상 0건)
    var headOnly: NeisParser.Page?
    _ = thrown { headOnly = try NeisParser.page(data(#"{"schoolInfo":[{"head":[{"list_total_count":0},{"RESULT":{"CODE":"INFO-000","MESSAGE":"ok"}}]}]}"#), service: "schoolInfo") }
    check("head만 있으면 빈 쪽", headOnly?.rows.isEmpty == true && headOnly?.total == 0)
}

// MARK: - 학교

private func runNeisSchoolCases() {
    if let p = try? NeisParser.page(data(fxSchoolHigh), service: "schoolInfo") {
        let schools = NeisParser.schools(p.rows)
        check("학교 1곳", schools.count == 1)
        if let s = schools.first {
            check("학교 이름", s.name == "서울고등학교")
            check("학교 id (교육청/학교코드)", s.id == "B10/7010083", s.id)
            check("학교급 고등학교", s.kind == .high)
            check("고등학교 구분(일반고)", s.highSchoolType == "일반고")
            check("지역 줄임 서울", s.shortRegion == "서울", s.shortRegion)
            check("주소에 도로명이 들어감", s.address.contains("효령로 197"), s.address)
            check("시간표 API는 hisTimetable", s.kind.timetableEndpoint == "hisTimetable")
        }
    } else {
        check("학교 검색 응답 읽기", false)
    }
    if let p = try? NeisParser.page(data(fxSchoolList), service: "schoolInfo") {
        check("학교 검색: 총 651건인데 5줄", p.total == 651 && p.rows.count == 5, "\(p.total) \(p.rows.count)")
        let schools = NeisParser.schools(p.rows)
        check("코드가 빈 (가칭) 학교는 뺌", schools.count == 4 && !schools.contains { $0.name.contains("가칭") }, "\(schools.map(\.name))")
        check("남서울중학교는 중학교", schools.first { $0.name == "남서울중학교" }?.kind == .middle)
        check("일반고 구분이 비면 빈 글자", schools.first { $0.name == "남서울중학교" }?.highSchoolType == "")
    }
    // 같은 학교가 두 번 오면 한 번만
    let dup: [NeisParser.Row] = [
        ["ATPT_OFCDC_SC_CODE": "B10", "SD_SCHUL_CODE": "1", "SCHUL_NM": "가", "SCHUL_KND_SC_NM": "초등학교"],
        ["ATPT_OFCDC_SC_CODE": "B10", "SD_SCHUL_CODE": "1", "SCHUL_NM": "가", "SCHUL_KND_SC_NM": "초등학교"],
        ["ATPT_OFCDC_SC_CODE": "C10", "SD_SCHUL_CODE": "1", "SCHUL_NM": "가", "SCHUL_KND_SC_NM": "초등학교"],
        ["ATPT_OFCDC_SC_CODE": "", "SD_SCHUL_CODE": "2", "SCHUL_NM": "나", "SCHUL_KND_SC_NM": "초등학교"],
        ["ATPT_OFCDC_SC_CODE": "B10", "SD_SCHUL_CODE": "3", "SCHUL_NM": "  ", "SCHUL_KND_SC_NM": "초등학교"]
    ]
    check("중복·빈 값 학교 걸러냄 (교육청이 다르면 다른 학교)", NeisParser.schools(dup).map(\.id) == ["B10/1", "C10/1"], "\(NeisParser.schools(dup).map(\.id))")
    // 학교급
    check("초등학교 학년 1~6", SchoolKind.elementary.grades == 1...6)
    check("중학교 학년 1~3", SchoolKind.middle.grades == 1...3)
    check("고등학교 학년 1~3", SchoolKind.high.grades == 1...3)
    check("특수학교는 other (시간표 API 없음)", SchoolKind(neisName: "특수학교") == .other && SchoolKind.other.timetableEndpoint == nil)
    check("시간표 API 이름", SchoolKind.elementary.timetableEndpoint == "elsTimetable" && SchoolKind.middle.timetableEndpoint == "misTimetable")
    check("지역 줄임", ["경기도", "충청북도", "강원특별자치도", "제주특별자치도", "세종특별자치시"].map(NeisText.shortRegion) == ["경기", "충북", "강원", "제주", "세종"])
    check("모르는 지역은 그대로", NeisText.shortRegion("해외") == "해외")
    check("교육청 17곳", NeisOffice.all.count == 17 && NeisOffice.name("D10") == "대구" && NeisOffice.name("ZZZ") == nil)
    // 선택 저장
    let sel = SchoolSelection(school: mis, grade: 2, classNum: 7)
    if let json = sel.encoded() {
        check("선택 저장·읽기 왕복", SchoolSelection.decode(json) == sel)
        check("선택 글자", sel.classLabel == "2학년 7반")
    } else {
        check("선택 저장", false)
    }
    check("빈 글자는 선택 없음", SchoolSelection.decode("") == nil)
    check("망가진 글자는 선택 없음", SchoolSelection.decode("{not json") == nil)
    var bad = sel; bad.grade = 0
    check("학년 0은 읽지 않음", bad.encoded().flatMap(SchoolSelection.decode) == nil)
    var noCode = sel; noCode.school.schoolCode = ""
    check("학교 코드가 비면 읽지 않음", noCode.encoded().flatMap(SchoolSelection.decode) == nil)
    // 학과 필드가 없는 예전 저장도 읽음
    let legacy = #"{"school":{"officeCode":"B10","schoolCode":"7132131","name":"남서울중학교","kindName":"중학교","region":"서울특별시","address":"","highSchoolType":""},"grade":1,"classNum":2}"#
    check("학과 없는 저장도 읽음", SchoolSelection.decode(legacy)?.department == "")
}

// MARK: - 시간표

private func runNeisTimetableCases() {
    // 초등 (앞 5줄)
    if let p = try? NeisParser.page(data(fxElsWeek), service: "elsTimetable") {
        let week = NeisParser.timetable(p.rows, weekStart: "20251013")
        check("초등: 칸 5개", week.cells.count == 5)
        check("초등: 월요일 1교시 국어", week.subject("20251013", period: 1) == "국어")
        check("초등: 월요일 3교시 슬기로운생활", week.subject("20251013", period: 3) == "슬기로운생활")
        check("초등: 화요일 1교시 수학", week.subject("20251014", period: 1) == "수학")
        check("초등: 없는 칸은 빈 글자", week.subject("20251014", period: 5) == "")
        check("초등: 월요일은 4교시까지", week.day("20251013").map(\.period) == [1, 2, 3, 4])
        check("초등: 최대 교시 4", week.maxPeriod == 4, "\(week.maxPeriod)")
        check("초등: 토요일 없음", !week.hasSaturday)
        check("초등: 학과 없음", week.departments.isEmpty && week.classNames == ["1"])
        check("초등: 비어 있지 않음", !week.isEmpty)
    }
    // 중학교 하루 5줄 + 6교시 필터 1줄 → 6교시
    if let a = try? NeisParser.page(data(fxMisDay), service: "misTimetable"),
       let b = try? NeisParser.page(data(fxMisDayP6), service: "misTimetable") {
        check("중학교 하루: 총 6줄 중 5줄", a.total == 6 && a.rows.count == 5)
        check("남은 교시 계산: 5, 6교시", NeisChunker.missingPeriods(rows: a.rows, total: a.total) == [5, 6], "\(NeisChunker.missingPeriods(rows: a.rows, total: a.total))")
        let merged = NeisChunker.merge(a.rows, b.rows)
        check("교시 필터로 이어 받으면 6줄", merged.count == 6)
        check("같은 줄을 또 받아도 늘지 않음", NeisChunker.merge(merged, b.rows + a.rows).count == 6)
        let week = NeisParser.timetable(merged, weekStart: "20261102")
        check("중학교: 화요일 6교시까지", week.day("20261103").map(\.period) == [1, 2, 3, 4, 5, 6])
        check("중학교: 1교시 사회, 6교시는 합친 줄", week.subject("20261103", period: 1) == "사회" && !week.subject("20261103", period: 6).isEmpty)
        check("다 받았으면 남은 교시 없음", NeisChunker.missingPeriods(rows: merged, total: 6).isEmpty)
    }
    check("남은 교시: 줄이 없으면 없음", NeisChunker.missingPeriods(rows: [], total: 7).isEmpty)
    check("남은 교시: 한도(12교시)를 넘지 않음", NeisChunker.missingPeriods(rows: [["PERIO": "10"]], total: 30, maxPeriod: 12) == [10, 11, 12])
    // 토요휴업일
    if let p = try? NeisParser.page(data(fxMisSat), service: "misTimetable") {
        let week = NeisParser.timetable(p.rows, weekStart: "20261102")
        check("토요휴업일: 4칸", week.cells.count == 4 && week.subject("20261107", period: 1) == "토요휴업일")
        check("토요휴업일: 쉬는 날로 봄", week.isHolidayDay("20261107") && week.holidayText("20261107") == "토요휴업일")
        check("토요휴업일뿐이면 토요 수업 없음", !week.hasSaturday)
        check("토요휴업일뿐이면 시간표 비어 있음", week.isEmpty && week.maxPeriod == 0)
    }
    // 재량휴업일 (월요일 전체)
    if let p = try? NeisParser.page(data(fxHisHoliday), service: "hisTimetable") {
        let week = NeisParser.timetable(p.rows, weekStart: "20261102")
        check("재량휴업일: 그날은 쉬는 날", week.isHolidayDay("20261102") && week.holidayText("20261102") == "재량휴업일")
        check("재량휴업일: 학과 이름 읽음", week.departments == ["과학과"], "\(week.departments)")
        check("재량휴업일: 과목 아님(휴업 글)", NeisParser.isHolidayText("재량휴업일"))
    }
    // 특성화고: 겹친 줄 · "* " 표시 · 학과
    if let p = try? NeisParser.page(data(fxHisDupes), service: "hisTimetable") {
        check("특성화고: 총 454줄 중 5줄", p.total == 454 && p.rows.count == 5)
        let week = NeisParser.timetable(p.rows, weekStart: "20251013")
        check("특성화고: '* ' 표시를 뺌", week.subject("20251013", period: 1) == "조색", week.subject("20251013", period: 1))
        check("특성화고: 같은 교시 겹친 줄은 한 칸", week.cells.count == 3 && week.subject("20251013", period: 3) == "배색", "\(week.cells.count)")
        check("특성화고: 학과", week.departments == ["그래픽아트과"])
        check("특성화고: 학과 하나면 합치지 않음", !week.cells.contains { $0.subject.contains(" / ") })
    }
    // 과학고: 선택과목형
    if let p = try? NeisParser.page(data(fxHisElective), service: "hisTimetable") {
        let week = NeisParser.timetable(p.rows, weekStart: "20261102")
        check("과학고: R&E 5~7교시", week.day("20261104").map(\.subject) == ["R&E", "R&E", "R&E"])
        check("과학고: 금요일 6교시 자율활동", week.subject("20261106", period: 6) == "자율활동")
        check("과학고: 토요 칸은 휴업일 글", week.holidayText("20261107") == "토요휴업일" && !week.hasSaturday)
        check("과학고: 최대 교시 7", week.maxPeriod == 7, "\(week.maxPeriod)")
    }
    // 합성 경우
    let multi: [NeisParser.Row] = [
        ["ALL_TI_YMD": "20260302", "PERIO": "1", "ITRT_CNTNT": "수학", "DDDEP_NM": "일반학과", "CLASS_NM": "3"],
        ["ALL_TI_YMD": "20260302", "PERIO": "1", "ITRT_CNTNT": "영어", "DDDEP_NM": "인문학과", "CLASS_NM": "3"],
        ["ALL_TI_YMD": "20260302", "PERIO": "2", "ITRT_CNTNT": "  ", "CLASS_NM": "3"],
        ["ALL_TI_YMD": "20260302", "PERIO": "x", "ITRT_CNTNT": "무시"],
        ["ALL_TI_YMD": "20260230", "PERIO": "1", "ITRT_CNTNT": "무시"],
        ["ALL_TI_YMD": "20260302", "PERIO": "0", "ITRT_CNTNT": "무시"],
        ["ALL_TI_YMD": "20260302", "PERIO": " 3 ", "ITRT_CNTNT": "국어&amp;문학"]
    ]
    let w = NeisParser.timetable(multi, weekStart: "20260302")
    check("한 칸에 여러 과목은 ' / '로", w.subject("20260302", period: 1) == "수학 / 영어", w.subject("20260302", period: 1))
    check("여러 학과가 보이면 학과 목록", w.departments == ["일반학과", "인문학과"], "\(w.departments)")
    check("빈 과목은 빈 칸", w.subject("20260302", period: 2) == "" && w.day("20260302").map(\.period) == [1, 3])
    check("교시 글자가 이상하거나 0이면 무시", w.cells.count == 3, "\(w.cells.count)")
    check("잘못된 날짜(2월 30일)는 무시", w.subject("20260230", period: 1) == "")
    check("HTML 글자 풀이 &amp;", w.subject("20260302", period: 3) == "국어&문학", w.subject("20260302", period: 3))
    check("공백 교시 ' 3 '도 읽음", w.maxPeriod == 3)
    check("과목 정리", NeisParser.cleanSubject("  * 조색  ") == "조색" && NeisParser.cleanSubject("**") == "" && NeisParser.cleanSubject("과학  탐구") == "과학 탐구")
    check("쉬는 날 글 판별", ["토요휴업일", "재량휴업일", "여름방학", "개교기념일", "공휴일", "대체공휴일"].allSatisfy(NeisParser.isHolidayText))
    check("과목은 쉬는 날 글이 아님", !["국어", "체육", "창의적 체험활동", "진로활동", "R&E"].contains(where: NeisParser.isHolidayText))
    // 토요일 수업이 실제로 있는 경우
    let sat = NeisParser.timetable([["ALL_TI_YMD": "20260307", "PERIO": "1", "ITRT_CNTNT": "창체"]], weekStart: "20260302")
    check("토요일 수업이 있으면 hasSaturday", sat.hasSaturday && !sat.isHolidayDay("20260307"))
    let none = TimetableWeek(weekStart: "20260302", cells: [])
    check("칸이 없으면 비어 있음", none.isEmpty && none.maxPeriod == 0 && !none.hasSaturday)
    // 키 없이 받아 일부만 받은 표시는 옛 저장에도 없어도 읽힘
    check("incomplete 없는 저장도 읽음", (try? JSONDecoder().decode(TimetableWeek.self, from: data(#"{"weekStart":"20260302","cells":[],"departments":[],"classNames":[]}"#)))?.incomplete == nil)
}

// MARK: - 급식

private func runNeisMealCases() {
    // 이름 + 알레르기
    func d(_ s: String) -> (String, [Int]) { let x = NeisParser.dish(s); return (x.name, x.allergies) }
    check("새우볶음밥(5.6.9.18)", d("새우볶음밥(5.6.9.18)") == ("새우볶음밥", [5, 6, 9, 18]), "\(d("새우볶음밥(5.6.9.18)"))")
    check("미역국 (5.6.16) 공백", d("미역국 (5.6.16)") == ("미역국", [5, 6, 16]))
    check("(5.6.13) 번호만", d("(5.6.13)") == ("", [5, 6, 13]))
    check("번호 없음", d("흑미밥 ") == ("흑미밥", []))
    check("배추김치(1) (9): 이름 속 번호는 이름", d("배추김치(1) (9)") == ("배추김치(1)", [9]), "\(d("배추김치(1) (9)"))")
    check("*표시 빼기 + (과) 이름 유지", d("*사과(과) ") == ("사과(과)", []), "\(d("*사과(과) "))")
    check("*순대국/양념장(과) (2.5.6.9.10.13.16)", d("*순대국/양념장(과) (2.5.6.9.10.13.16)") == ("순대국/양념장(과)", [2, 5, 6, 9, 10, 13, 16]))
    check("(과학고) 뒤 번호", d("옥수수스프(과학고) (2.5.6.13.16)") == ("옥수수스프(과학고)", [2, 5, 6, 13, 16]))
    check("번호 중복 · 순서", d("가(5.1.5.2)") == ("가", [1, 2, 5]))
    check("끝점 (5.6.)", d("나물(5.6.)") == ("나물", [5, 6]))
    check("쉼표 (5, 6)", d("나물 (5, 6)") == ("나물", [5, 6]))
    check("19 넘는 번호는 이름의 일부 (20)", d("행사식(20)") == ("행사식(20)", []))
    check("0 번호는 이름의 일부 (0)", d("행사식(0)") == ("행사식(0)", []))
    check("19번 잣", d("잣죽(19)") == ("잣죽", [19]))
    check("괄호가 끝이 아니면 이름의 일부", d("토스트(2)+딸기잼") == ("토스트(2)+딸기잼", []))
    check("글자 괄호는 그대로", d("보쌈김치((과) (9)") == ("보쌈김치((과)", [9]), "\(d("보쌈김치((과) (9)"))")
    check("토스트+ 딸기잼,땅콩버터(과학고) (2.4.5.6.13)", d("토스트+ 딸기잼,땅콩버터(과학고) (2.4.5.6.13)") == ("토스트+ 딸기잼,땅콩버터(과학고)", [2, 4, 5, 6, 13]))
    check("빈 줄", d("") == ("", []) && d("   ") == ("", []))
    // <br/> 나누기
    check("<br/> 나누기", NeisParser.splitBreaks("밥<br/>국 (5)<br/>김치") == ["밥", "국 (5)", "김치"])
    check("<br /> · <BR> · 줄바꿈", NeisParser.splitBreaks("a<br />b<BR>c\nd\r\ne") == ["a", "b", "c", "d", "e"])
    check("빈 조각 버림", NeisParser.splitBreaks("<br/>a<br/><br/> <br/>b<br/>") == ["a", "b"])
    check("&amp; 풀이", NeisParser.splitBreaks("수육&amp;마늘소스 (2)") == ["수육&마늘소스 (2)"])
    check("dishes: 번호만 있는 줄은 버림", NeisParser.dishes("밥<br/>(5.6)<br/>국 (5)").map(\.name) == ["밥", "국"])
    // 알레르기 표
    check("알레르기 19가지", Allergen.names.count == 19 && Allergen.legend.count == 19)
    check("알레르기 1 난류 · 2 우유 · 5 대두 · 6 밀", Allergen.name(1) == "난류" && Allergen.name(2) == "우유" && Allergen.name(5) == "대두" && Allergen.name(6) == "밀")
    check("알레르기 10 돼지고기 · 18 조개류 · 19 잣", Allergen.name(10) == "돼지고기" && Allergen.name(18) == "조개류(굴,전복,홍합 포함)" && Allergen.name(19) == "잣")
    check("알레르기 0, 20은 없음", Allergen.name(0) == nil && Allergen.name(20) == nil)
    check("알레르기 표는 번호 순", Allergen.legend.map(\.number) == Array(1...19))
    check("알레르기 7 고등어 · 8 게 · 9 새우 · 13 아황산류", [7, 8, 9, 13].compactMap(Allergen.name) == ["고등어", "게", "새우", "아황산류"])
    // 영양
    let n = NeisParser.nutrients("탄수화물(g) : 95.3<br/>단백질(g) : 29.0<br/>지방(g) : 20.7<br/>이상한줄<br/>칼슘(mg) : ")
    check("영양 3줄만 (빈 값 · 콜론 없는 줄 제외)", n.map(\.label) == ["탄수화물(g)", "단백질(g)", "지방(g)"] && n.map(\.value) == ["95.3", "29.0", "20.7"], "\(n)")
    // 실제 초등 급식
    if let p = try? NeisParser.page(data(fxMealEls), service: "mealServiceDietInfo") {
        check("급식: 5일 5줄", p.rows.count == 5 && p.total == 5)
        let days = NeisParser.mealDays(p.rows)
        check("급식: 5일, 날짜 순", days.map(\.ymd) == ["20251013", "20251014", "20251015", "20251016", "20251017"])
        let lunch = days.first?.meal(.lunch)
        check("급식: 월요일 중식", lunch != nil && days.first?.meal(.breakfast) == nil && days.first?.meal(.dinner) == nil)
        check("급식: 월요일 요리 8개", lunch?.dishes.count == 8, "\(lunch?.dishes.count ?? -1)")
        check("급식: 옥수수밥은 번호 없음", lunch?.dishes.first == Dish(name: "옥수수밥", allergies: []), "\(String(describing: lunch?.dishes.first))")
        check("급식: 메추리알조림 (1.5.6.13)", lunch?.dishes[2] == Dish(name: "메추리알조림", allergies: [1, 5, 6, 13]))
        check("급식: 치즈떡볶이 8개 번호", lunch?.dishes[4].allergies == [1, 2, 5, 6, 10, 12, 15, 16])
        check("급식: 김구이는 번호 없음", lunch?.dishes[5] == Dish(name: "김구이", allergies: []))
        check("급식: 배추김치(1) (9)", lunch?.dishes[6] == Dish(name: "배추김치(1)", allergies: [9]))
        check("급식: 열량", lunch?.calories == "696.8 Kcal")
        check("급식: 영양 9줄 중 탄수화물 95.3", lunch?.nutrients.count == 9 && lunch?.nutrients.first == NutrientLine(label: "탄수화물(g)", value: "95.3"))
        check("급식: 전체 알레르기 번호 합침", lunch?.allAllergies == [1, 2, 5, 6, 9, 10, 11 - 11 + 12, 13, 15, 16, 17].filter { $0 != 0 }.sorted(), "\(lunch?.allAllergies ?? [])")
        check("급식: 수요일 샤인머스캣은 번호 없음", days[2].meal(.lunch)?.dishes.last == Dish(name: "샤인머스캣", allergies: []))
        check("급식: 원산지 줄은 쓰지 않음(모델에 없음)", !(lunch?.dishes.contains { $0.name.contains("쇠고기(종류)") } ?? true))
    }
    // 조식 (과학고)
    if let p = try? NeisParser.page(data(fxMealBreakfast), service: "mealServiceDietInfo") {
        let days = NeisParser.mealDays(p.rows)
        check("조식: 5일 모두 조식", days.count == 5 && days.allSatisfy { $0.meals.count == 1 && $0.meals[0].kind == .breakfast })
        let b = days[0].meals[0]
        check("조식: * 표시를 뺀 이름", b.dishes.contains(Dish(name: "시져샐러드(과)", allergies: [1, 2, 5, 6, 10, 12])), "\(b.dishes.map(\.name))")
        check("조식: 땅콩버터 번호 4", b.dishes[1].allergies.contains(4) && b.allAllergies.contains(4))
        check("조식: 번호 없는 요리 (*사과(과))", b.dishes.contains(Dish(name: "사과(과)", allergies: [])))
    }
    // 하루 중식 + 석식
    if let p = try? NeisParser.page(data(fxMealDay), service: "mealServiceDietInfo") {
        let days = NeisParser.mealDays(p.rows)
        check("하루: 중식 · 석식", days.count == 1 && days[0].meals.map(\.kind) == [.lunch, .dinner])
        check("하루: 석식 열량", days[0].meal(.dinner)?.calories == "858.3 Kcal")
        check("하루: 게살스프 (1.5.6.8)", days[0].meal(.lunch)?.dishes[1] == Dish(name: "게살스프", allergies: [1, 5, 6, 8]))
    }
    if let p = try? NeisParser.page(data(fxMealThree), service: "mealServiceDietInfo") {
        let days = NeisParser.mealDays(p.rows)
        check("하루: 조식 · 중식 · 석식 순서", days.first?.meals.map(\.kind) == [.breakfast, .lunch, .dinner])
        check("하루 3끼: 이름 속 이중 괄호", days.first?.meal(.lunch)?.dishes.contains { $0.name.hasPrefix("보쌈김치") && $0.allergies == [9] } == true)
        check("하루 3끼: 점 있는 이름 (가자미빵가루튀김.양파드레싱)", days.first?.meal(.dinner)?.dishes.contains { $0.name.hasPrefix("가자미빵가루튀김.양파드레싱") } == true)
    }
    // 합성
    let rows: [NeisParser.Row] = [
        ["MLSV_YMD": "20260303", "MMEAL_SC_CODE": "3", "MMEAL_SC_NM": "석식", "DDISH_NM": "밥<br/>국 (5)", "CAL_INFO": "700 Kcal"],
        ["MLSV_YMD": "20260303", "MMEAL_SC_CODE": "2", "MMEAL_SC_NM": "중식", "DDISH_NM": "빵 (1.6)"],
        ["MLSV_YMD": "20260303", "MMEAL_SC_CODE": "2", "MMEAL_SC_NM": "중식", "DDISH_NM": "또 빵"],
        ["MLSV_YMD": "20260303", "MMEAL_SC_CODE": "9", "MMEAL_SC_NM": "간식", "DDISH_NM": "과자"],
        ["MLSV_YMD": "20260303", "MMEAL_SC_CODE": "1", "MMEAL_SC_NM": "조식", "DDISH_NM": ""],
        ["MLSV_YMD": "2026-03-03", "MMEAL_SC_CODE": "2", "DDISH_NM": "날짜 이상"],
        ["MLSV_YMD": "20260302", "MMEAL_SC_NM": "중식", "DDISH_NM": "코드 없이 이름만"]
    ]
    let days = NeisParser.mealDays(rows)
    check("합성: 날짜 오름차순", days.map(\.ymd) == ["20260302", "20260303"])
    check("합성: 코드 없이 이름만 있어도 중식", days[0].meal(.lunch)?.dishes.first?.name == "코드 없이 이름만")
    check("합성: 같은 끼니 중복은 앞엣것", days[1].meal(.lunch)?.dishes.first?.name == "빵" && days[1].meals.count == 2)
    check("합성: 모르는 끼니 · 빈 메뉴 · 잘못된 날짜 제외", !days[1].meals.contains { $0.dishes.first?.name == "과자" } && days[1].meal(.breakfast) == nil)
    check("합성: 순서 중식 → 석식", days[1].meals.map(\.kind) == [.lunch, .dinner])
    check("끼니 이름", MealKind.allCases.map(\.title) == ["조식", "중식", "석식"] && MealKind(neisCode: " 2 ") == .lunch && MealKind(neisCode: "7") == nil)
    check("끼니 코드 글자", MealKind(neisCode: "x") == nil)
    // 범위 찾기
    let range = MealRange(fromYMD: "20260302", toYMD: "20260308", days: days)
    check("범위에서 날짜 찾기", range.day("20260303")?.meals.count == 2 && range.day("20260304") == nil)
}

// MARK: - 날짜

private func runNeisDateCases() {
    func ws(_ iso: String) -> String { NeisDate.weekStart(containing: at(iso)) }
    // 한국 시간 기준: 2026-11-07(토) 낮 → 그 주 월요일 11-02
    check("토요일 → 그 주 월요일", ws("2026-11-07T03:00:00Z") == "20261102", ws("2026-11-07T03:00:00Z"))
    check("월요일 → 자기 자신", ws("2026-11-02T01:00:00Z") == "20261102")
    check("일요일 → 그 주 월요일 (다음 주 아님)", ws("2026-11-08T05:00:00Z") == "20261102")
    check("월요일 새벽 한국 시간(전날 UTC)도 그 주", ws("2026-11-01T15:30:00Z") == "20261102", ws("2026-11-01T15:30:00Z"))
    check("일요일 밤 한국 시간(UTC로는 같은 날 낮)", ws("2026-11-08T14:59:00Z") == "20261102")
    check("월 경계: 2026-03-01(일) → 02-23", ws("2026-03-01T03:00:00Z") == "20260223", ws("2026-03-01T03:00:00Z"))
    check("연 경계: 2027-01-01(금) → 2026-12-28", ws("2027-01-01T03:00:00Z") == "20261228", ws("2027-01-01T03:00:00Z"))
    check("연 경계: 2025-12-31(수) → 12-29", ws("2025-12-31T03:00:00Z") == "20251229")
    check("윤년: 2024-03-01(금) → 02-26", ws("2024-03-01T03:00:00Z") == "20240226", ws("2024-03-01T03:00:00Z"))
    check("윤년 아님: 2025-03-01(토) → 02-24", ws("2025-03-01T03:00:00Z") == "20250224")
    // 한국 시간 날짜
    check("UTC 15:00은 한국 다음 날", NeisDate.ymd(at("2026-11-06T15:00:00Z")) == "20261107")
    check("UTC 14:59는 한국 같은 날", NeisDate.ymd(at("2026-11-06T14:59:00Z")) == "20261106")
    check("요일 번호 월0 … 일6", (0..<7).map { NeisDate.weekdayIndex(at("2026-11-0\($0 + 2)T03:00:00Z")) } == [0, 1, 2, 3, 4, 5, 6])
    check("요일 번호(글자)", NeisDate.weekdayIndex(ymd: "20261107") == 5 && NeisDate.weekdayIndex(ymd: "20261102") == 0 && NeisDate.weekdayIndex(ymd: "bad") == nil)
    // 날짜 더하기
    check("연말 +1", NeisDate.addDays("20261231", 1) == "20270101")
    check("윤년 2월 +2", NeisDate.addDays("20240228", 2) == "20240301")
    check("평년 2월 말 +1", NeisDate.addDays("20250228", 1) == "20250301")
    check("-1일 월 경계", NeisDate.addDays("20250301", -1) == "20250228")
    check("+7일", NeisDate.addDays("20261228", 7) == "20270104")
    check("-7일 연 경계", NeisDate.addDays("20270104", -7) == "20261228")
    check("잘못된 날짜 nil", NeisDate.addDays("20260230", 1) == nil && NeisDate.addDays("2026-11-07", 1) == nil && NeisDate.addDays("", 1) == nil)
    check("유효성", NeisDate.isValid("20240229") && !NeisDate.isValid("20250229") && !NeisDate.isValid("20261301") && !NeisDate.isValid("2026110") && !NeisDate.isValid("abcdefgh") && !NeisDate.isValid("18991231"))
    // 주 범위
    check("평일 목록 (연 경계)", NeisDate.weekDays(start: "20261228") == ["20261228", "20261229", "20261230", "20261231", "20270101"])
    check("토요일 포함 6일", NeisDate.weekDays(start: "20261228", includeSaturday: true).last == "20270102" && NeisDate.weekDays(start: "20261228", includeSaturday: true).count == 6)
    check("시간표 범위 월~토", NeisDate.timetableRange(weekStart: "20261228") == ("20261228", "20270102"))
    check("급식 범위 월~일", NeisDate.mealRange(weekStart: "20261228") == ("20261228", "20270103"))
    check("월 경계 평일 (2월→3월)", NeisDate.weekDays(start: "20260223") == ["20260223", "20260224", "20260225", "20260226", "20260227"])
    check("월 경계 일요일까지 (3월 1일)", NeisDate.mealRange(weekStart: "20260223").to == "20260301")
    let now = at("2026-11-07T03:00:00Z")
    check("이번 주 / 다음 주 / 지난 주", NeisDate.weekStart(offset: 0, from: now) == "20261102" && NeisDate.weekStart(offset: 1, from: now) == "20261109" && NeisDate.weekStart(offset: -1, from: now) == "20261026")
    check("주 이동 연 경계", NeisDate.weekStart(offset: 8, from: now) == "20261228" && NeisDate.weekStart(offset: 9, from: now) == "20270104")
    check("날짜 ↔ Date 왕복", NeisDate.date("20261107").map(NeisDate.ymd) == "20261107" && NeisDate.date("20240229").map(NeisDate.ymd) == "20240229")
    check("일 숫자", NeisDate.dayNumber("20261107") == 7 && NeisDate.dayNumber("20261031") == 31 && NeisDate.dayNumber("x") == nil)
    check("요일 글자", NeisDate.weekdayShort == ["월", "화", "수", "목", "금", "토", "일"])
    check("학년도: 1·2월은 전년도", NeisDate.academicYear(at("2026-01-15T03:00:00Z")) == 2025 && NeisDate.academicYear(at("2026-02-28T03:00:00Z")) == 2025)
    check("학년도: 3월부터 올해", NeisDate.academicYear(at("2026-03-02T03:00:00Z")) == 2026 && NeisDate.academicYear(at("2026-12-31T03:00:00Z")) == 2026)
    // 지금 몇 교시
    func cur(_ h: Int, _ m: Int, _ kind: SchoolKind = .middle, max: Int = 7) -> Int? { NeisPeriodClock.currentPeriod(minute: h * 60 + m, kind: kind, maxPeriod: max) }
    check("교시: 등교 전", cur(7, 0) == nil && cur(8, 30) == nil)
    check("교시: 중학교 8:45는 1교시 직전(1교시로)", cur(8, 45) == 1)
    check("교시: 중학교 9:00은 1교시, 9:40(쉬는 시간)은 2교시", cur(9, 0) == 1 && cur(9, 40) == 2)
    check("교시: 중학교 4교시 11:40", cur(11, 40) == 4)
    check("교시: 점심은 다음(5교시)로", cur(12, 40) == 5 && cur(13, 0) == 5)
    check("교시: 중학교 7교시 15:20, 16:30은 끝", cur(15, 20) == 7 && cur(16, 30) == nil)
    check("교시: 초등학교 1교시 9:10, 2교시 10:00", cur(9, 10, .elementary, max: 6) == 1 && cur(10, 0, .elementary, max: 6) == 2)
    check("교시: 고등학교 8:50은 1교시, 8교시 16:40", cur(8, 50, .high, max: 8) == 1 && cur(16, 40, .high, max: 8) == 8)
    check("교시: 시작 시각 증가", (1...8).map { NeisPeriodClock.startMinute(period: $0, kind: .high) } == [520, 580, 640, 700, 820, 880, 940, 1000])
    check("교시: 중학교 5교시는 점심 뒤 13:10", NeisPeriodClock.startMinute(period: 5, kind: .middle) == 13 * 60 + 10)
    check("교시: 최대 0이면 nil", NeisPeriodClock.currentPeriod(minute: 600, kind: .middle, maxPeriod: 0) == nil)
    check("하루 중 분", NeisPeriodClock.minuteOfDay(at("2026-11-07T03:30:00Z")) == 12 * 60 + 30)
}

// MARK: - 주소 만들기

private func runNeisAPICases() {
    let sel = SchoolSelection(school: mis, grade: 2, classNum: 3)
    let u = NeisAPI.timetable(selection: sel, fromYMD: "20261102", toYMD: "20261107", key: nil, pSize: 5)?.absoluteString ?? ""
    check("시간표 주소: 중학교 API", u.hasPrefix("https://open.neis.go.kr/hub/misTimetable?"), u)
    check("시간표 주소: 필수 값", u.contains("ATPT_OFCDC_SC_CODE=B10") && u.contains("SD_SCHUL_CODE=7132131") && u.contains("GRADE=2") && u.contains("CLASS_NM=3") && u.contains("TI_FROM_YMD=20261102") && u.contains("TI_TO_YMD=20261107"), u)
    check("시간표 주소: JSON · 쪽 · 키 없음", u.contains("Type=json") && u.contains("pIndex=1") && u.contains("pSize=5") && !u.contains("KEY="), u)
    check("시간표 주소: https", u.hasPrefix("https://"))
    let uk = NeisAPI.timetable(selection: sel, fromYMD: "20261102", toYMD: "20261107", key: "abc123", pIndex: 2, pSize: 1000)?.absoluteString ?? ""
    check("키가 있으면 KEY가 맨 앞", uk.contains("?KEY=abc123&Type=json&pIndex=2&pSize=1000"), uk)
    let ue = NeisAPI.timetable(selection: SchoolSelection(school: els, grade: 6, classNum: 1), fromYMD: "20261102", toYMD: "20261107", key: nil, pSize: 5)?.absoluteString ?? ""
    check("초등학교는 elsTimetable", ue.contains("/elsTimetable?") && ue.contains("GRADE=6"))
    let uh = NeisAPI.timetable(selection: SchoolSelection(school: his, grade: 1, classNum: 1, department: "그래픽아트과"), fromYMD: "20261102", toYMD: "20261102", key: nil, pSize: 5)?.absoluteString ?? ""
    check("고등학교는 hisTimetable + 학과(퍼센트 인코딩)", uh.contains("/hisTimetable?") && uh.contains("DDDEP_NM=%EA%B7%B8%EB%9E%98%ED%94%BD%EC%95%84%ED%8A%B8%EA%B3%BC"), uh)
    let un = NeisAPI.timetable(selection: SchoolSelection(school: his, grade: 1, classNum: 1), fromYMD: "20261102", toYMD: "20261102", key: nil, pSize: 5)?.absoluteString ?? ""
    check("학과가 없으면 DDDEP_NM 없음", !un.contains("DDDEP_NM"))
    let ux = NeisAPI.timetable(selection: SchoolSelection(school: mis, grade: 1, classNum: 1, department: "무시"), fromYMD: "20261102", toYMD: "20261102", key: nil, pSize: 5)?.absoluteString ?? ""
    check("중학교는 학과를 보내지 않음", !ux.contains("DDDEP_NM"))
    let up = NeisAPI.timetable(selection: sel, fromYMD: "20261103", toYMD: "20261103", period: 6, key: nil, pSize: 5)?.absoluteString ?? ""
    check("교시 필터", up.contains("PERIO=6") && up.contains("TI_FROM_YMD=20261103") && up.contains("TI_TO_YMD=20261103"), up)
    check("특수학교는 시간표 주소 없음", NeisAPI.timetable(selection: SchoolSelection(school: sps, grade: 1, classNum: 1), fromYMD: "20261102", toYMD: "20261107", key: nil, pSize: 5) == nil)
    // 학교 찾기
    let us = NeisAPI.schoolSearch(name: " 서울고등학교 ", key: nil, pSize: 5)?.absoluteString ?? ""
    check("학교 찾기: 한글 인코딩 + 공백 정리", us.contains("SCHUL_NM=%EC%84%9C%EC%9A%B8%EA%B3%A0%EB%93%B1%ED%95%99%EA%B5%90") && !us.contains("%20"), us)
    check("학교 찾기: 빈 값은 보내지 않음", !us.contains("ATPT_OFCDC_SC_CODE") && !us.contains("SCHUL_KND_SC_NM"))
    let us2 = NeisAPI.schoolSearch(name: "서울", office: "B10", kindName: "초등학교", key: nil, pSize: 5)?.absoluteString ?? ""
    check("학교 찾기: 교육청 · 학교급 좁히기", us2.contains("ATPT_OFCDC_SC_CODE=B10") && us2.contains("SCHUL_KND_SC_NM=%EC%B4%88%EB%93%B1%ED%95%99%EA%B5%90"), us2)
    // 급식
    let um = NeisAPI.meals(school: mis, fromYMD: "20261102", toYMD: "20261108", key: nil, pSize: 5)?.absoluteString ?? ""
    check("급식 주소: 기간", um.contains("/mealServiceDietInfo?") && um.contains("MLSV_FROM_YMD=20261102") && um.contains("MLSV_TO_YMD=20261108") && !um.contains("MLSV_YMD"), um)
    let ud = NeisAPI.meals(school: mis, fromYMD: "x", toYMD: "x", ymd: "20261103", key: nil, pSize: 5)?.absoluteString ?? ""
    check("급식 주소: 하루", ud.contains("MLSV_YMD=20261103") && !ud.contains("MLSV_FROM_YMD"), ud)
    let uj = NeisAPI.majors(school: his, key: nil, pSize: 5)?.absoluteString ?? ""
    check("학과 목록 주소", uj.contains("/schoolMajorinfo?") && uj.contains("SD_SCHUL_CODE=7010278"), uj)
    // 값 인코딩
    let uv = NeisAPI.url(endpoint: "x", params: [("A", "a+b&c=d e")], key: "k+/=", pSize: 5)?.absoluteString ?? ""
    check("값 안의 + & = 공백 인코딩", uv.contains("A=a%2Bb%26c%3Dd%20e") && uv.contains("KEY=k%2B%2F%3D"), uv)
    check("pIndex·pSize는 1 이상", (NeisAPI.url(endpoint: "x", params: [], pIndex: 0, pSize: 0)?.absoluteString ?? "").contains("pIndex=1&pSize=1"))
    // 키
    check("키: 없음/빈/공백/자리표시/sample은 키 아님", [nil, "", "  ", "$(NEIS_KEY)", "sample", "SAMPLE"].allSatisfy { NeisAPI.sanitizedKey($0) == nil })
    check("키: 앞뒤 공백 제거", NeisAPI.sanitizedKey(" abc \n") == "abc")
    // 쪽 나누기
    check("키 없으면 5줄, 있으면 1000줄", NeisAPI.pageSize(hasKey: false) == 5 && NeisAPI.pageSize(hasKey: true) == 1000)
    check("다음 쪽: 모자라면 +1", NeisAPI.nextPage(received: 1000, total: 2500, currentIndex: 1) == 2 && NeisAPI.nextPage(received: 2000, total: 2500, currentIndex: 2) == 3)
    check("다음 쪽: 다 받았으면 없음", NeisAPI.nextPage(received: 2500, total: 2500, currentIndex: 3) == nil && NeisAPI.nextPage(received: 5, total: 5, currentIndex: 1) == nil)
    check("요청 수: 2500줄 / 1000 = 3, 21줄 / 5 = 5, 0줄 = 0", NeisAPI.pageCount(total: 2500, pageSize: 1000) == 3 && NeisAPI.pageCount(total: 21, pageSize: 5) == 5 && NeisAPI.pageCount(total: 0, pageSize: 5) == 0 && NeisAPI.pageCount(total: 5, pageSize: 0) == 0)
    check("키 없이 한 주 시간표: 하루씩 6번 (월~토)", NeisChunker.timetableDays(weekStart: "20261102") == ["20261102", "20261103", "20261104", "20261105", "20261106", "20261107"])
    check("학교 찾기 나누기: 초 · 중 · 고", NeisChunker.schoolKinds == ["초등학교", "중학교", "고등학교"])
}

// MARK: - 저장

private func runNeisCacheCases() {
    let saved = Date(timeIntervalSince1970: 1_800_000_000)
    let sel = SchoolSelection(school: mis, grade: 2, classNum: 3)
    // 시간표 왕복
    let week = NeisParser.timetable([["ALL_TI_YMD": "20261102", "PERIO": "1", "ITRT_CNTNT": "국어", "DDDEP_NM": "일반학과"]], weekStart: "20261102")
    if let blob = NeisCache.encode(week, savedAt: saved), let back = NeisCache.decode(TimetableWeek.self, from: blob) {
        check("시간표 저장·읽기 왕복", back.payload == week && back.savedAt == saved)
    } else {
        check("시간표 저장", false)
    }
    // 급식 왕복
    if let p = try? NeisParser.page(data(fxMealDay), service: "mealServiceDietInfo") {
        let range = MealRange(fromYMD: "20261102", toYMD: "20261108", days: NeisParser.mealDays(p.rows))
        if let blob = NeisCache.encode(range, savedAt: saved), let back = NeisCache.decode(MealRange.self, from: blob) {
            check("급식 저장·읽기 왕복", back.payload == range && back.payload.day("20261103")?.meal(.dinner)?.dishes.count == 6)
        } else {
            check("급식 저장", false)
        }
    }
    // 일부만 받은 표시도 왕복
    var partial = week; partial.incomplete = true
    check("일부만 받은 표시 왕복", NeisCache.encode(partial, savedAt: saved).flatMap { NeisCache.decode(TimetableWeek.self, from: $0) }?.payload.incomplete == true)
    // 버전이 다르거나 망가진 파일은 버림
    check("다른 버전 파일은 버림", NeisCache.decode(TimetableWeek.self, from: data(#"{"version":99,"savedAt":1,"payload":{"weekStart":"20261102","cells":[]}}"#)) == nil)
    check("망가진 파일은 버림", NeisCache.decode(TimetableWeek.self, from: data("garbage")) == nil && NeisCache.decode(TimetableWeek.self, from: Data()) == nil)
    check("모양이 다른 파일은 버림", NeisCache.decode(MealRange.self, from: NeisCache.encode(week, savedAt: saved) ?? Data()) == nil)
    // 유효 시간
    func fresh(_ age: TimeInterval, _ ttl: TimeInterval) -> Bool { NeisCache.isFresh(savedAt: saved, now: saved.addingTimeInterval(age), ttl: ttl) }
    check("시간표 6시간: 방금 · 5시간 59분은 새로움", fresh(0, NeisCache.timetableTTL) && fresh(5 * 3600 + 59 * 60, NeisCache.timetableTTL))
    check("시간표 6시간: 딱 6시간은 오래됨", !fresh(6 * 3600, NeisCache.timetableTTL) && !fresh(7 * 3600, NeisCache.timetableTTL))
    check("급식 12시간: 11시간 59분은 새로움, 12시간은 오래됨", fresh(11 * 3600 + 59 * 60, NeisCache.mealTTL) && !fresh(12 * 3600, NeisCache.mealTTL))
    check("시계가 거꾸로 가면(저장이 미래) 새롭지 않음", !fresh(-60, NeisCache.timetableTTL))
    check("유효 시간 값", NeisCache.timetableTTL == 21_600 && NeisCache.mealTTL == 43_200)
    check("30일 넘으면 정리 대상", !NeisCache.isStale(savedAt: saved, now: saved.addingTimeInterval(29 * 86_400)) && NeisCache.isStale(savedAt: saved, now: saved.addingTimeInterval(31 * 86_400)))
    // 마지막 업데이트 표시
    func age(_ s: TimeInterval) -> NeisCache.Age { NeisCache.age(savedAt: saved, now: saved.addingTimeInterval(s)) }
    check("방금", age(0) == .justNow && age(59) == .justNow && age(-100) == .justNow)
    check("분 · 시간 · 일", age(60) == .minutes(1) && age(3599) == .minutes(59) && age(3600) == .hours(1) && age(23 * 3600 + 3599) == .hours(23) && age(86_400) == .days(1) && age(3 * 86_400 + 5) == .days(3))
    // 파일 이름
    let f1 = NeisCache.timetableFile(sel, weekStart: "20261102")
    check("시간표 파일 이름", f1 == "tt-B10-7132131-2-3-20261102.json", f1)
    check("급식 파일 이름", NeisCache.mealFile(mis, weekStart: "20261102") == "meal-B10-7132131-20261102.json")
    let a = NeisCache.timetableFile(SchoolSelection(school: his, grade: 1, classNum: 1, department: "건축과"), weekStart: "20261102")
    let b = NeisCache.timetableFile(SchoolSelection(school: his, grade: 1, classNum: 1, department: "전기과"), weekStart: "20261102")
    check("한글 학과가 달라도 파일 이름이 겹치지 않음", a != b && a.hasSuffix(".json") && a.unicodeScalars.allSatisfy { $0.isASCII }, "\(a) \(b)")
    check("안전한 이름: 경로 글자 막음", NeisCache.safe("../a/b c") == "_2e_2e_2fa_2fb_20c" && !NeisCache.safe("../x").contains("/"))
    check("다른 학년/반은 다른 파일", NeisCache.timetableFile(SchoolSelection(school: mis, grade: 1, classNum: 3), weekStart: "20261102") != f1)
    check("다른 주는 다른 파일", NeisCache.timetableFile(sel, weekStart: "20261109") != f1)
}
