---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (23) — foreign_cumulative 실구현, v2 풀링 매수 전환
date: 2026-06-18 22:00:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code
author: Evan
description: 항상 None만 반환하던 외국인·기관 수급 지표를 KIS 종목별 투자자매매동향 API로 실제 구현했다. strategy_v2의 매수 흐름을 슬롯제에서 09시 통합 선정 + 장중 풀링 매수로 바꾸고, 그 과정에서 발견한 TIME LIMIT 오류와 docs stale 정보까지 정리한 6월 18일 후반 작업을 기록한다.
---

**작성일**: 2026년 6월 18일  
**최종 수정**: 2026년 6월 18일  
**분야**: AI Trading, Development  
**난이도**: Advanced  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/volume-rank-pagination-saga/)에서 거래량순위 API 한도를 확인하고 universe 목표치를 60으로 재조정했다. 같은 날 후반에는 **외국인·기관 수급 지표**와 **strategy_v2 매수 흐름 구조** 두 가지를 큰 폭으로 손봤다.

결론부터 말하면, Group B(smart_money) 조건이 의존하던 `get_foreign_net()`이 사실 항상 `None`만 반환하는 placeholder였다는 걸 확인하고 실제 KIS API로 구현했다. 이어서 strategy_v2의 매수 흐름을 그룹별 슬롯 순차 실행 구조에서 09시 통합 선정 + 장중 풀링 매수로 바꿨다. 마지막으로 새 수급 API가 KIS의 시각 제약에 걸리는 문제와 docs에 남아있던 옛 구조 서술을 함께 정리했다.

---

## foreign_cumulative 실구현 — 외국인·기관 20일 누적 순매수

`get_foreign_net()`이 항상 `None`을 반환하는 placeholder라서, Group B(smart_money) 조건이 매번 `fallback_relative_strength`로만 동작하고 있었다. KIS 공식 GitHub 샘플에서 종목코드 단위로 외국인·기관 일별 순매수를 주는 엔드포인트(`FHPTJ04160001`, investor-trade-by-stock-daily)를 확인했다. 거래량순위처럼 랭킹형이 아니라 종목별 일별 시리즈를 주기 때문에 20일 누적 계산이 가능했다.

- `api/api_constants.py`: `TrId.INVESTOR_TRADE_DAILY` + 경로 상수 추가
- `api/kis_api.py`: `get_investor_trade_daily(code, base_date, count=20)` 신규
- `api/dry_run_client.py`: 동일 메서드를 오버라이드해 dry-run 시 빈 리스트 반환
- `strategy_v2/krx_api_client.py`(이후 `market_data_helpers.py`로 이름 변경): `get_foreign_net()` 실제 구현 — 외국인 순매수 거래대금(`frgn_ntby_tr_pbmn`) + 기관계 순매수 거래대금(`orgn_ntby_tr_pbmn`)을 **거래대금(원) 기준**으로 20일 합산(수량 기준은 종목 간 가격 차이로 불공정 비교가 되므로 제외)
- 실패/데이터 없음 시 `None` 반환 원칙은 유지 — Group B의 `fallback_relative_strength` 안전망은 변경하지 않음

신규 테스트 6개 추가, 기존 placeholder 테스트는 실제 동작 검증으로 교체. `pytest tests/` 483개 전체 통과. OCI 실측 검증은 다음 단계로 미뤘다.

곧이어, 실제로 KRX API를 호출하지 않고 `KISApiClient`를 감싸 업종·VKOSPI·수급 보조 데이터를 조회하는 이 모듈의 파일명(`krx_api_client.py`)이 실제 역할과 맞지 않는다는 걸 깨닫고 `market_data_helpers.py`로 이름을 바꿨다(동작 변경 없음, import 경로만 갱신).

---

## strategy_v2 매수 흐름: 09시 4그룹 통합 선정 + 장중 풀링 매수

기존 strategy_v2는 A/B/C/D 4개 그룹이 각각 09:00/09:15/09:30/09:45에 "1차+2차 스크리닝+즉시 매수"를 수행하는 슬롯 구조였다. 이를 다음과 같이 바꿨다.

- 09:00~09:59 사이 **1회** 4개 그룹 전체를 통합 스크리닝해 점수 내림차순 후보 풀을 생성
- 이후 장중(15:30까지) 15분 단위로 그 풀에서 매수만 이어감 — 재스크리닝·점수 재검증 없이, 건전성 조건(현금/보유한도/섹터캡/일일손실한도/공포 하드블록)만 매 시도마다 재확인

```
[기존] 09:00 GroupA 풀스크리닝+매수 → 09:15 GroupB → 09:30 GroupC → 09:45 GroupD
[변경] 09:00~09:59 4그룹 통합 스크리닝 → 후보 풀 1개 생성
       → 09:00~15:30 15분마다 풀에서 건전성 확인 후 매수만 반복
```

- `screening/first_stage_groups.py`: `get_current_slot`/`get_pending_slots`/`mark_slot_executed`/`_SLOT_GROUP_MAP` 제거, `is_selection_window`/`save_candidate_pool`/`load_candidate_pool`/`run_full_screening` 추가
- `run_full_screening()`은 4그룹 결과를 병합한 뒤 `deduplicate()`를 **단 1회만** 적용 — 그룹별로 개별 적용하면 섹터 캡이 그룹 수만큼 중복 허용되는 문제를 방지
- `trading/buy.py`: `run_buy()`를 슬롯 루프 → 후보 풀 기반 흐름으로 재작성
- `strategy_v2/DEVELOPMENT_SPEC.md`에 통합 풀 방식으로 갱신, carry-over 개념 폐기를 명시

`pytest tests/` 488개 전체 통과.

---

## ❌ TIME LIMIT 오류: 새 수급 API가 KIS 시각 제약에 걸림

새로 만든 `foreign_cumulative` 기능을 OCI에서 실측해보니 `FHPTJ04160001` 호출이 유니버스 전체에서 "TIME LIMIT 00:00 ~ 15:40"으로 거부되고 있었다.

`get_foreign_net()`이 `FID_INPUT_DATE_1`에 **오늘 날짜**를 넘긴 게 원인이었다. 당일 투자자매매동향은 장마감 정산(15:40) 전까지 KIS가 조회를 막는 것으로 추정된다. 애초에 사전장에서 "최근 20거래일 누적"을 계산할 때 오늘 데이터가 포함될 수 없으므로, 전 영업일을 기준일로 쓰는 게 의미상으로도 옳았다.

- `utils/time_utils.py`: `previous_business_day()` 신규 — 기준일 이전 가장 최근 평일 반환
- `market_data_helpers.py`: `get_foreign_net()`이 `today_kst()` 대신 `previous_business_day()`로 `FID_INPUT_DATE_1` 계산

OCI 재검증 결과 TIME LIMIT 경고가 사라지고 `foreign_cumulative=60종목`으로 정상 채워졌다(이전엔 항상 0이었음).

---

## docs/전략확인 페이지 stale 정보 정리

슬롯제 → 통합 선정+풀링 매수로 바뀐 만큼, 문서와 화면에 남아있던 옛 구조 서술도 함께 정리했다.

- `docs/TRADING_FLOW.md`: v2 매수 흐름 전체 개정 + 그룹 표 `top_n` 오기(40 → 실제 15) 수정
- `docs/USAGE.md`/`docs/UPDATE.md`: 누락된 v2 cron 항목(`--pre-market`/`--next-pre-market`/`--reconcile`) 추가
- `web/strategy_flow.py`: `build_v2_buy_flow()`가 여전히 구 슬롯제 Mermaid 그래프(SLOTA→SLOTB→SLOTC→SLOTD)를 생성하던 버그 수정
- OCI 실제 `/etc/crontab` 확인 결과 `--pre-market`이 07:00에 실행 중임을 확인 — docs에 "08:00"으로 잘못 적혀 있던 부분을 전체 수정

마지막으로 `build-docs/release-notes-draft-v0.4.4.md`, `v0.5.0.md` 초안을 추가했다. `pytest tests/` 489개 전체 통과.

---

## 정리

| 작업 | 내용 |
|------|------|
| foreign_cumulative | placeholder였던 수급 지표를 KIS 종목별 투자자매매동향 API로 실구현 |
| v2 매수 구조 | 슬롯 순차 실행 → 09시 통합 선정 + 장중 풀링 매수로 전환 |
| TIME LIMIT 버그 | 당일 데이터 조회 시각 제약 → 전 영업일 기준으로 변경 |
| docs 정리 | 슬롯제 잔존 표현·top_n 오기·cron 시각 stale 정보 일괄 수정 |
| 테스트 | `pytest tests/` 489개 전체 통과 |

이번 작업으로 "placeholder인 채로 방치된 지표"와 "구조가 바뀌었는데 문서/화면엔 남아있는 옛 서술" 두 가지 종류의 기술 부채를 같은 날 한 번에 청산했다.

다음 글에서는 6/19에 진행한 **strategy_v2 ATR 필터 hard block 제거**와 **계좌별 원금/평가금액/수익률 표시 기능**을 다룬다.
