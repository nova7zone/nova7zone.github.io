---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (20) — pre-market API 최적화, 주문 체결 검증 개선 (PR #29)
date: 2026-06-16 18:00:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code
author: Evan
description: pre-market 실행 시 모의투자 API 제약을 우회하고 KOSPI 지수 일봉을 영구 캐시로 전환해 API 호출을 줄였다. 이어서 주문 체결 검증 로직에 CANCELLED 처리와 2단계 fallback 조회를 추가해 더 정확하게 판단하도록 개선한 PR #29 작업을 정리한다.
---

**작성일**: 2026년 6월 16일  
**최종 수정**: 2026년 6월 16일  
**분야**: AI Trading, Development  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/strategy-flow-page-and-mermaid-bugfixes/)에서 전략확인 페이지를 만들고 OCI 검증 중 발견한 버그 두 건을 고쳤다. 6월 16일은 **pre-market 실행 성능**과 **주문 체결 판단 로직**, 두 가지를 손봤다.

결론부터 말하면, pre-market 단계에서 모의투자 서버의 데이터 제약을 우회하고 KOSPI 지수 일봉을 영구 캐시로 바꿔 API 호출을 크게 줄였다. 그리고 주문 체결 검증(PR #29)에 CANCELLED 처리와 2단계 fallback 조회를 추가해, 체결 여부를 더 정확하게 판단하도록 개선했다.

---

## pre-market API 최적화

- `--pre-market` 실행 시 VTS(모의투자) 서버의 데이터 제한을 우회하기 위해 live API를 강제로 사용하도록 변경
- `get_index_daily_candles()`에 페이지네이션을 추가해 MA200(200일 이동평균) 계산이 가능해짐 — 기존엔 한 번에 받아오는 캔들 수가 부족해 200일치를 채울 수 없었음
- KOSPI 지수 일봉을 **영구 캐시**로 구현(`strategy_v2/cache_manager.py::build_index_candle_cache`) — pre-market마다 반복 호출하던 API 콜을 5회 → 1회로 절감
- pre-market 캐시 빌드 시 live `universe_size=2000`을 강제 적용해 충분한 후보군을 확보

이 네 가지는 모두 작은 단위 커밋으로 나눠 진행했는데, 공통된 방향은 "모의투자 서버의 한계를 공개 시세성 데이터에 대해서는 live 엔드포인트로 우회한다"는 패턴이다. 바로 전날 `get_stock_sector()`에 적용했던 것과 같은 접근이다.

---

## 주문 체결 검증 개선 (PR #29)

체결 여부 판단을 더 정확하게 다듬었다.

- `api/api_constants.py`: `FillStatus.CANCELLED = "09"` 추가
- `tests/test_trading.py`: CANCELLED·부분체결·`avg_prvs` 파싱 실패 케이스 3개 추가
- `trading/order_manager.py`: CANCELLED 핸들러 추가 + `avg_prvs` 파싱 실패 시 WARNING 로그
- `api/dry_run_client.py`: `check_order_status()` 오버라이드 추가 — `--dry-run` 중에는 실제 HTTP 호출을 차단
- `api/kis_api.py`: `check_order_status()`의 2단계 fallback 로직을 전면 수정
  - 미체결 목록에 없으면 당일 체결내역 API(`TTTC8001R`/`VTTC8001R`)를 직접 조회
  - API 호출 자체가 실패 → UNFILLED(재시도)
  - 체결내역에서 발견 + 수량>0 → FILLED
  - 발견 + 수량=0 → CANCELLED(거부)
  - 체결내역에도 없음 → CANCELLED(취소)

```python
# 변경 후 흐름 (개념)
if order_id in unfilled_orders:
    return UNFILLED
filled = query_fill_history(order_id)
if filled is None:
    return UNFILLED  # API 실패는 재시도
if filled.qty > 0:
    return FILLED
return CANCELLED
```

`pytest tests/` 429개 전체 통과 후 PR #29 생성(feature/build → master), `build-docs/release-notes-draft-v0.4.3.md` 초안도 함께 추가했다.

> 이 체결 판단 로직은 "미체결 목록"과 "당일 체결내역" 두 KIS API가 정상 동작한다는 전제 위에 세워져 있다. 6일 뒤(6/22) 이 전제 자체가 모의투자 환경에서는 성립하지 않는다는 게 드러나면서, 체결 판단 방식 전체를 다시 손보게 된다 — 그 이야기는 뒤에서 다룬다.

---

## 정리

| 작업 | 내용 |
|------|------|
| pre-market 최적화 | live API 강제 사용, MA200 페이지네이션, 지수 캐시 영구화(API 5→1회), universe_size=2000 |
| 주문 체결 검증 | `FillStatus.CANCELLED` 추가, 미체결→당일체결내역 2단계 fallback, dry-run 오버라이드 |
| 테스트 | `pytest tests/` 429개 전체 통과 |
| 결과물 | PR #29 생성, v0.4.3 릴리즈 노트 초안 |

다음 글에서는 6/17에 진행한 **매매설정 탭의 v2 전용 카드 확장(3·4단계)**과 **next-pre-market 캐시 분리** 작업을 다룬다.
