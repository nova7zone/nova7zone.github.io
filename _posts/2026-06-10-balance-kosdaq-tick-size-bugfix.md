---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (12) — 잔고 0원, KOSDAQ 거래량순위, 호가단위 오류 수정
date: 2026-06-10 10:00:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code
author: Evan
description: 매수 후보가 모두 잔고 부족으로 스킵되던 잔고 0원 버그와 KOSDAQ 거래량순위 조회 오류를 수정해 매수 주문이 실제로 들어가게 만들었다. 이어서 호가단위 오류로 거부된 주문을 KRX 호가단위 보정 유틸로 해결하고, CLAUDE.md 작업 절차를 다시 정비한 과정을 기록한다.
---

**작성일**: 2026년 6월 10일  
**최종 수정**: 2026년 6월 10일  
**분야**: AI Trading, Development  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/wide-strategy-and-settings-tabs/)에서 wide 전략을 추가하고 설정 페이지를 개편했다. 이번 글에서는 그 다음 날 진행한 작업 중, **실제 매수 주문이 들어가지 않던 두 가지 버그**를 수정한 과정과 CLAUDE.md 작업 절차 재정비 내용을 정리한다.

결론부터 말하면, `get_balance()`가 항상 0을 반환하는 잘못된 필드를 읽고 있어서 2차 스크리닝을 통과한 종목도 전부 "잔고 부족"으로 매수가 스킵되고 있었다. 이 버그와 KOSDAQ 거래량순위 조회 오류를 함께 고치자 매수 주문이 실제로 접수됐는데, 곧바로 **호가단위 오류**로 거부되는 종목이 나타나서 KRX 호가단위 보정 유틸도 추가했다.

---

## CLAUDE.md 작업 절차 재정비

코드 수정에 들어가기 전에, 작업 절차 문서를 먼저 정비했다.

- 작업 시작 절차에 `git checkout feature/build` 명시, main rebase 단계 유지
- 작업 종료 절차에 md 파일 최신화·PR 요청·작업 기록 단계 추가
- 원격 저장소와 충돌하던 작업 시작 절차 6번 항목을 rebase로 병합
- `build-docs/` 작성 규칙을 구체화 — 코드 작업 착수 전 `build-docs/update/YYYY-MM-DD-{작업명}.md`에 요청사항과 작업 계획(영향 범위, 수정 파일 목록·순서, 테스트 전략)을 먼저 작성하도록 규정
- 블로그용 진행 정리 자료 `build-docs/blog-progress-summary.md` 추가 — 프로젝트 시작부터 현재까지의 커밋 타임라인과 work-log 요약

이 `blog-progress-summary.md`가 사실 지금 이 시리즈 글들을 작성하는 데 쓰이고 있는 자료이기도 하다.

---

## ❌ 버그: 잔고 0원으로 매수 전부 스킵

2차 스크리닝을 통과한 종목이 항상 "잔고=0원"으로 매수가 스킵되는 문제가 있었다.

### 원인

`api/kis_api.py`의 `get_balance()`가 잔고 필드로 `ord_psbl_cash`를 읽고 있었는데, 이 필드는 **KIS 응답에 존재하지 않는 필드**라서 항상 0이 반환되고 있었다.

### 수정

- `ord_psbl_cash` → `prvs_rcdl_excc_amt`(D+2 정산잔고)로 변경

이 한 줄이 "2차 스크리닝 통과 종목이 모두 잔고=0원으로 매수 스킵되던 버그"의 근본 원인이었다.

---

## ❌ 버그: 거래량순위(KOSDAQ) 조회 오류

거래량 순위 조회(`FHPST01710000`)에서 KOSDAQ 종목을 조회할 때 오류가 발생하고 있었다.

### 수정

- `FID_COND_MRKT_DIV_CODE`를 항상 `"J"`로 고정
- 시장 구분은 `FID_INPUT_ISCD`로 지정 (코스피 = `"0001"`, 코스닥 = `"1001"`)
- `api/api_constants.py`의 `MarketCode.VOLUME_RANK_KOSPI`/`VOLUME_RANK_KOSDAQ` 상수 재정의
- `api/kis_api.py`의 `_get_volume_rank()`/`get_stock_list()` 갱신

**검증**: `pytest tests/` 전체 통과 + OCI 서버 실행 로그로 효과 확인

---

## ✅ 효과: 매수 주문 7건 접수 성공

위 두 버그를 수정한 뒤 OCI paper 모드에서 검증한 결과는 다음과 같았다.

- 잔고 인식이 정상화되어 **매수 주문 7건 접수 성공** (GS글로벌, 랩지노믹스, 테크윙, 진양화학, 화신정공, 대원강업, 케이뱅크)
- 1차 후보: 30 → **40종목**
- 1차 통과: 24 → **36종목**
- 2차 통과: 4 → **8종목**

지수 조회 버그, 잔고 조회 버그, 거래량 순위 버그가 차례로 풀리면서 후보군과 통과 종목 수가 모두 늘어났다.

---

## ❌ 새로운 버그: 호가단위 오류로 매수 거부

매수 주문이 들어가기 시작하자, 이번에는 **한화생명(088350)** 매수 주문이 "호가단위 오류"로 거부되는 현상이 나타났다. 주문 가격은 4,837원이었다.

### 원인

한국 주식시장은 가격 구간별로 호가단위가 정해져 있다. 4,837원은 유효한 호가가 아니었다.

### 수정: KRX 호가단위 보정 유틸 추가

`utils/price_utils.py`에 `round_to_tick_size()`를 추가했다.

- 가격 구간별 호가단위(1원/5원/10원/50원/100원/500원/1,000원)에 맞춰 가장 가까운 유효 호가로 보정
- 예: 4,837원 → **4,835원**으로 보정되어 호가단위 오류 해결

매수/매도 지정가를 산출하는 곳에 모두 적용했다.

- `trading/buy.py`의 `_calc_limit_price()` — 기존 TODO였던 호가단위 보정을 구현
- `trading/sell.py`의 매도 지정가 산출부에도 동일하게 적용

**테스트**: `tests/test_price_utils.py` — 구간별 경계값을 포함한 21개 케이스 추가

**검증**: `pytest tests/` 186개 전체 통과

---

## 작업 종료 절차 수정 + CLAUDE.md 구조 동기화

마지막으로 문서 정리도 함께 진행했다.

- 작업 종료 절차에서 **PR 요청 단계 제거** — 기존 "feature/build 브랜치에 push하고 PR 요청" → "push (PR 요청은 사용자가 별도 지시할 때만 진행)"으로 변경, 중복되던 항목 삭제
- 프로젝트 구조 섹션을 실제 코드와 동기화
  - `report/`에 누락되어 있던 `md_writer.py`, `gdrive_sync.py` 추가
  - `utils/`에 신규 `price_utils.py` 추가
  - `settings/screen_config/second_stage/`에 `wide` 전략 추가, 2차 스크리닝 전략 표에 `wide.yaml` 행 추가
  - `tests/` 목록에 `test_price_utils.py`, `test_dry_run.py`, `test_token_blocked.py`, `test_md_writer.py`, `test_md_report_integration.py`, `test_gdrive_sync.py` 추가
- 테스트 미커버리지 목록에서 이미 테스트가 작성된 항목 제거 (`api/token_manager.py`, `api/dry_run_client.py`, `report/daily_report.py`, `report/monthly_report.py`)

---

## 정리

| 버그 | 원인 | 수정 | 효과 |
|------|------|------|------|
| 잔고 0원 | `get_balance()`가 존재하지 않는 필드(`ord_psbl_cash`) 사용 | `prvs_rcdl_excc_amt`로 교체 | 매수 스킵 해소 |
| KOSDAQ 거래량순위 오류 | 시장구분코드 처리 오류 | `FID_INPUT_ISCD` 기준으로 코스피/코스닥 분리 | 1차 후보 30→40종목 |
| 호가단위 오류 | 유효하지 않은 가격(4,837원)으로 주문 | `round_to_tick_size()` 추가 | 매수/매도 주문 정상 접수 |

다음 글에서는 같은 날(6/10) 이어서 진행한 **체결 이력 페이지 개편** — 매수 점수·매도 사유 표시부터 매수 컨텍스트 툴팁까지의 작업을 다룬다.
