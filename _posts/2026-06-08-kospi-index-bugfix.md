---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (10) — 매매가 안 되는 버그, KOSPI 지수 조회 오류 추적과 수정
date: 2026-06-08 19:30:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code google-drive
author: Evan
description: OCI 서버 상태 점검 후 며칠 만에 paper 모드로 자동매매를 돌렸는데 매매가 한 건도 발생하지 않았다. 로그를 추적해 KOSPI 지수 일봉 조회가 개별종목용 엔드포인트를 잘못 사용하고 있던 구조적 버그를 찾아 수정한 과정을 기록한다.
---

**작성일**: 2026년 6월 8일  
**최종 수정**: 2026년 6월 8일  
**분야**: AI Trading, Development  
**난이도**: Intermediate ~ Advanced  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/report-gdrive-sync-and-config-toggle/)에서 리포트 자동화와 설정 편집기를 마무리했다. 이번 글은 6월 7일 서버 상태 점검부터, 6월 8일 실제 운영 중 발견한 핵심 버그 수정까지를 다룬다.

결론부터 말하면, paper 모드로 cron이 정상적으로 돌고 있었음에도 **매매가 단 한 건도 발생하지 않는** 문제가 있었다. 원인은 KOSPI **지수** 일봉 데이터를 조회할 때 **개별 종목용 엔드포인트**를 사용하고 있던 구조적 버그였다. 이 버그를 고치면서 지수 전용 조회 메서드를 새로 만들고, 관련 단위 테스트도 함께 추가했다.

---

## 6월 7일: 저장소 재클론과 상태 점검

새 작업 환경에서 저장소를 다시 클론하고 상태를 확인했다.

- `nova7zone/kis-auto-trading-bot` 저장소를 현재 폴더에 클론
- `git status` 확인 — 상태 깨끗(clean), 브랜치는 `master`/`origin/master`
- `build-docs/work-log.md`에서 이전 작업 이력 확인
- 이날은 변경사항 없이 점검만 하고 작업 종료

이어서 OCI 서버 자체의 동작 상태도 점검했다.

- `cat data/token_cache_paper.json`으로 토큰 발급 상태 확인
- crontab 설정 확인
- paper 모드 초기 자금을 강제로 할당
- `python runner.py --dry-run` 정상 통과 확인

마지막으로 일간/월간 리포트의 Google Drive 동기화 경로(`paths.gdrive_report_remote`)를 한 차례 수정했다.

```yaml
gdrive_report_remote: "gdrive:obsidian/Second Brain/01_inbox/auto_trading_report"
```

---

## 6월 8일: paper 모드인데 매매가 0건

서버를 점검한 다음 날, paper 모드로 자동매매가 cron을 통해 정상적으로 실행되고 있는지 확인했다. 그런데 `trader.log`를 보니 매매가 **전혀 발생하지 않았다**.

```text
2026-06-08 13:45:01 | INFO | __main__ | runner 시작 | 모드=paper | 프리셋=neutral
2026-06-08 13:45:01 | INFO | __main__ | 미확인 주문 처리 시작
2026-06-08 13:45:01 | INFO | __main__ | 장 시간 내 실행 — 매도/매수 시작
2026-06-08 13:45:01 | INFO | trading.sell | 보유 종목 없음 — 매도 로직 스킵
2026-06-08 13:45:01 | INFO | __main__ | 매도 완료 | 주문=0건
2026-06-08 13:45:09 | WARNING | screening.market_filter | KOSPI 일봉 데이터 부족 (0/20일) → 매수 차단
2026-06-08 13:45:09 | INFO | trading.buy | 단기 시장 필터 차단 — 매수 로직 종료
2026-06-08 13:45:09 | INFO | __main__ | 매수 완료 | 주문=0건
2026-06-08 13:45:09 | INFO | __main__ | runner 정상 종료
```

보유 종목이 없어서 매도는 스킵, 그리고 `KOSPI 일봉 데이터 부족 (0/20일) → 매수 차단`으로 매수도 차단됐다. 정상 종료는 되었지만, 결국 **이 한 번의 차단** 때문에 장중 매매가 전혀 일어나지 않은 것이다.

---

## Claude Code 진단: 지수 코드를 개별종목 엔드포인트로 조회

이 로그를 Claude Code에 그대로 전달하고 원인 분석을 요청했다.

### 원인

`screening/market_filter.py`의 `is_market_buyable()`이 KOSPI 지수(`0001`)의 일봉 데이터를 `api_client.get_daily_candles()`로 조회했는데, 0건이 반환되어 "데이터 부족 → 매수 차단"으로 빠진 것이다.

### 왜 0건이 나왔는가

`get_daily_candles()`(`api/kis_api.py`)는 종목 코드 종류와 무관하게 항상 `FID_COND_MRKT_DIV_CODE: "J"`(개별 종목 시장 구분 코드)로, KIS의 **개별종목용 일봉 엔드포인트**(`inquire-daily-itemchartprice`, TR `FHKST03010100`)를 호출한다.

그런데 `market_filter.py`와 `market_regime.py`는 이 함수에 종목 코드가 아닌 **KOSPI 지수 코드(`0001`)**를 넘기고 있었다. 지수의 일봉 시계열은 개별종목 엔드포인트로 조회되지 않고, 별도의 **지수용 엔드포인트**(`inquire-daily-indexchartprice`, TR `FHKUP03500100`)를 `FID_COND_MRKT_DIV_CODE: "U"`로 호출해야 한다. 바로 옆의 `get_index_price()`는 현재가 조회 시 정확히 `"U"`를 쓰고 있어서, 일봉 조회 쪽만 누락된 셈이었다.

즉 "J + 개별종목 엔드포인트"로 지수 코드를 조회하니 KIS 측에서 빈 응답(또는 실패)을 반환했고, `len(candles) == 0` → "KOSPI 일봉 데이터 부족 (0/20일)" → 보수적으로 매수 차단된 것이다.

### 왜 지금까지 발견되지 않았는가

- 일회성 네트워크 문제가 아니라 **구조적 버그**라서, KOSPI 지수 코드로 `get_daily_candles()`를 호출하는 한 항상 0건이 돌아온다.
- `screening/market_regime.py`도 같은 함수를 같은 방식으로 호출하지만, 거기서는 `not candles`일 때 그냥 `"chop"`(횡보)으로 폴백해 조용히 넘어가기 때문에 증상이 드러나지 않았다.
- `tests/test_filters.py`는 `get_daily_candles`를 `MagicMock`으로 대체해서 호출 파라미터와 무관하게 캔들 리스트를 그대로 반환하므로, 이 버그는 **실제 KIS API와 통신할 때만** 드러난다.

---

## ✅ 수정 완료

진단 결과를 바탕으로 다음과 같이 수정했다.

- `api/api_constants.py`: 지수 전용 일봉 엔드포인트 경로(`INDEX_DAILY_CANDLE_PATH`)와 TR ID(`FHKUP03500100`) 상수 추가
- `api/kis_api.py`: `get_index_daily_candles()` 신규 메서드 추가
  - `FID_COND_MRKT_DIV_CODE: "U"`로 지수 전용 엔드포인트(`inquire-daily-indexchartprice`) 호출
  - 날짜 범위(`FID_INPUT_DATE_1`/`FID_INPUT_DATE_2`) 계산해 전달 (KIS 공식 예제·백테스터 코드로 엔드포인트·TR ID·필드명 교차 검증)
- `api/dry_run_client.py`: 동일 시그니처의 mock 메서드 추가
- `screening/market_filter.py`: `get_daily_candles()` → `get_index_daily_candles()`로 교체, 종가 필드를 `stck_clpr`(개별종목용) → `bstp_nmix_prpr`(지수용)로 수정
- `screening/market_regime.py`: 동일하게 `get_index_daily_candles()` 호출로 교체 (`_extract_closes`는 두 필드명을 모두 처리하도록 되어 있어 추가 변경 불필요)
- `tests/conftest.py`: `make_index_candles()` 헬퍼 추가, `mock_api` 픽스처에 `get_index_daily_candles` mock 등록
- `tests/test_filters.py`: `is_market_buyable()` 직접 단위 테스트 5건 신규 추가
  - 지수 전용 엔드포인트 호출 검증
  - 빈 응답 시 차단 확인
  - `bstp_nmix_prpr` 필드 파싱 확인
  - MA 하회 시 차단 확인

`pytest tests/` 164개 전부 통과를 확인했다. 이제부터는 KOSPI 지수 일봉이 정상 조회되어, 시장 필터가 실제 이동평균 기준으로 매수 허용/차단을 판단한다.

---

## 부수 수정: Google Drive 경로 대소문자 오타

작업 중 `settings/app.yaml`의 `paths.gdrive_report_remote` 경로에 대소문자 오타가 있는 것도 함께 발견했다.

- 실제 폴더명은 `01_Inbox`(대문자 I)
- 설정값은 `01_inbox`(소문자)

이 때문에 `rclone`이 기존 폴더를 찾지 못하고 매번 `01_Inbox (1)`이라는 새 폴더를 만들고 있었다. 대소문자를 실제 폴더명과 일치시켜 기존 폴더에 덮어쓰기 동기화되도록 수정했다.

```yaml
gdrive_report_remote: "gdrive:obsidian/Second Brain/01_Inbox/auto_trading_report"
```

---

## 정리

| 항목 | 내용 |
|------|------|
| 증상 | paper 모드 cron 정상 실행되지만 매매 0건 |
| 1차 원인 | KOSPI 지수 코드를 개별종목용 일봉 엔드포인트(J)로 조회 → 빈 응답 |
| 발견 안 된 이유 | market_regime은 폴백 처리로 증상 은폐, 테스트는 MagicMock이라 미검증 |
| 수정 | `get_index_daily_candles()`(엔드포인트 U, TR FHKUP03500100) 신규 추가 |
| 테스트 | `is_market_buyable()` 단위 테스트 5건 추가, 전체 164개 통과 |
| 부수 수정 | Google Drive 리포트 경로 대소문자 오타 수정 |

다음 글부터는 work-log 기반으로, 로그 포맷 버그·매도 sector 누락 같은 잔여 버그 수정과 함께 새로운 **wide 2차 스크리닝 전략** 도입, 설정 페이지 개편 작업을 다룬다.
