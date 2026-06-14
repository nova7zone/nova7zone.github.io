---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (13) — 체결 이력 페이지 전면 개편, 매매설정 파라미터 전체 편집
date: 2026-06-10 16:00:00 +0900
categories: trading development
tags: ai-trading python kis-api
author: Evan
description: 체결 이력 페이지의 렌더링 깨짐을 고치고, 매수 점수·매도 사유·보유상태·매수가·조건별 점수 툴팁을 차례로 추가했다. buy_context로 컬럼명을 정리하고, 매매설정 페이지에서 2차 스크리닝 조건 파라미터를 전체 편집할 수 있게 만든 과정을 기록한다.
---

**작성일**: 2026년 6월 10일  
**최종 수정**: 2026년 6월 10일  
**분야**: AI Trading, Development  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/balance-kosdaq-tick-size-bugfix/)에서 잔고 0원 버그와 호가단위 오류를 고치면서 실제 매수 주문이 들어가기 시작했다. 매수 주문이 쌓이자 자연스럽게 "이 종목은 왜 샀고, 왜 팔았는지"를 한눈에 보고 싶어졌다. 이번 글은 같은 날(6/10) 이어서 진행한 **체결 이력(`/trades`) 페이지 개편** 작업을 정리한다.

결론부터 말하면, 체결 이력 페이지의 렌더링이 깨져 있던 버그를 먼저 고치고, 그 위에 매수 점수·매도 사유·보유상태·매수가·조건별 점수 툴팁을 차례로 쌓아 올렸다. 이 과정에서 DB 컬럼을 `condition_scores` → `buy_context`로 정리했고, 마지막으로 매매설정 페이지에서 2차 스크리닝 조건 파라미터 전체를 웹에서 직접 편집할 수 있도록 만들었다.

---

## ❌ 버그: 체결 이력 페이지 렌더링 깨짐

`/trades` 페이지에 접속하면 Alpine.js 코드가 화면에 텍스트로 그대로 노출되는 문제가 있었다.

### 원인

`web/templates/trades.html`에서 `x-data="{ ... {{ trades | tojson }} ... }"` 형태로 작성되어 있었는데, `tojson`이 출력하는 JSON 문자열에는 큰따옴표(`"`)가 포함된다. 이 큰따옴표가 `x-data="..."` 속성을 감싸는 큰따옴표와 충돌해 HTML이 중간에서 끊기고, 나머지 스크립트가 그대로 화면에 노출됐다.

### 수정

- `x-data` 속성을 작은따옴표(`'...'`)로 변경
- 내부 JS 문자열 리터럴은 큰따옴표로 전환

`pytest tests/` 186개 전체 통과 — 템플릿 변경이라 단위 테스트에는 영향 없음을 확인했다.

---

## 매수 점수 / 매도 사유 표시

체결 이력에서 "이 종목이 왜 선정됐는지", "왜 팔았는지"를 보여주는 컬럼을 추가했다.

- `db/schema.py`: `trades` 테이블에 `score REAL`, `sell_reason TEXT` 컬럼 추가
  - `init_db()`에 `_add_column_if_missing()` 추가 — 기존 DB도 재실행 시 자동 마이그레이션(idempotent)
- `db/repository.py`: `insert_trade()`가 `score`/`sell_reason`도 저장 (`get_trades()`는 `SELECT *`라 자동 반영)
- `trading/order_manager.py`
  - `add_pending_order()`에 `score`, `sell_reason` 파라미터 추가 → `pending_orders.json`에 기록
  - `_on_buy_filled()` / `_on_sell_filled()`에서 `trade_log.json`·DB에 `score`/`sell_reason` 포함
- `trading/buy.py`: `add_pending_order()` 호출 시 2차 스크리닝 점수(`score`) 전달
- `trading/sell.py`: `add_pending_order()` 호출 시 매도 사유(`sell_reason`) 전달
- `web/templates/trades.html`: "점수/사유" 컬럼 추가 — 매수 행은 점수, 매도 행은 매도 사유 표시

테스트는 `tests/test_db.py`(신규, schema 마이그레이션·CRUD)와 `tests/test_trading.py`(score/sell_reason 전파 케이스 2건)를 추가했다. `pytest tests/` 192개 전체 통과.

---

## 보유상태 / 매수가 컬럼 추가

체결 이력만 봐서는 "이 종목을 지금도 들고 있는지", "얼마에 샀는지"를 알 수 없었다. 이를 보완했다.

- `db/schema.py`: `trades` 테이블에 `avg_price INTEGER` 컬럼 추가, `init_db()` 마이그레이션 등록
- `db/repository.py`: `insert_trade()`가 `avg_price`도 저장
- `trading/order_manager.py`: `_on_sell_filled()`의 trade_entry에 `avg_price`(매도 시점 평균매수단가) 포함
- `web/routers/pages.py`: `/trades` 페이지에 `holdings.json` 기준 현재 보유 종목 코드 목록(`held_codes`) 전달
- `web/templates/trades.html`: "상태/매수가" 컬럼 추가
  - 매수 행: 현재 보유 중이면 "보유중", 이미 매도되었으면 "매도완료"
  - 매도 행: `avg_price`(매수가) 표시, 없으면 "—"

`tests/test_db.py`에 `avg_price` 컬럼/CRUD 검증, `tests/test_trading.py`에 전파 검증을 추가했다. `pytest tests/` 192개 전체 통과.

---

## 매수 점수 툴팁 — 조건별 점수 상세

매수 점수가 몇 점인지는 보이지만, "어떤 조건이 얼마나 기여했는지"는 알 수 없었다. 2차 스크리닝의 조건별 점수를 hover 툴팁으로 보여주도록 했다.

- `db/schema.py`: `trades` 테이블에 `condition_scores TEXT` 컬럼 추가 (`init_db()` 마이그레이션 등록)
- `db/repository.py`: `insert_trade()`가 `condition_scores`(JSON 문자열)도 저장
- `trading/order_manager.py`
  - `add_pending_order()`에 `condition_scores: dict | None` 파라미터 추가 → `pending_orders.json`에 기록
  - `_on_buy_filled()`에서 trade_entry에 `condition_scores`를 JSON 문자열로 직렬화해 포함
- `trading/buy.py`: `add_pending_order()` 호출 시 `stock["raw_scores"]`(2차 스크리닝 조건별 0.0~1.0 점수)를 `condition_scores`로 전달
- `web/templates/trades.html`: 매수 행의 점수 텍스트에 `title` 툴팁 추가 — 조건별 점수(한글 라벨 + %)를 hover 시 표시

`tests/test_db.py`, `tests/test_trading.py`에 `condition_scores` 전파 검증을 추가했다. `pytest tests/` 192개 전체 통과.

> 기존 trades 행은 `condition_scores`가 없어 툴팁이 표시되지 않고, 다음 매수 체결부터 정상 기록된다.

---

## 컬럼명 정리: condition_scores → buy_context

조건별 점수 툴팁을 추가하자마자, "이 매수가 어떤 설정(프리셋/임계값/전략)에서 이뤄졌는지"가 더 유용한 정보라는 판단이 들었다. 그래서 같은 컬럼을 재정의해서 사용했다.

- `db/schema.py`: `trades.condition_scores` 컬럼을 `buy_context TEXT`로 변경 — 운영 DB에 아직 반영되지 않은 상태였기 때문에 컬럼명 자체를 교체
- `db/repository.py`: `insert_trade()` 컬럼명 `condition_scores` → `buy_context`
- `trading/order_manager.py`: `add_pending_order()`/`_on_buy_filled()`의 `condition_scores` → `buy_context`로 변경
- `trading/buy.py`: `add_pending_order()` 호출 시 다음 정보를 `buy_context`로 전달
  - `preset`: 현재 매매 프리셋
  - `strategy`: 활성 2차 스크리닝 전략
  - `min_score`: 해당 종목에 적용된 통과 기준점
- `web/templates/trades.html`: 매수 점수 툴팁을 "매매프리셋 / 임계값 / 2차 스크리닝전략" 3줄로 변경
  - 프리셋: 보수적/중립/공격적, 전략: 균형/모멘텀/추세추종/광범위 — 한글 라벨로 매핑

`tests/test_db.py`, `tests/test_trading.py`를 `buy_context` 기준으로 갱신했다. `pytest tests/` 192개 전체 통과.

---

## 매매설정 페이지: 2차 스크리닝 조건 파라미터 전체 편집

[이전 글](/posts/wide-strategy-and-settings-tabs/)에서 추가한 매매설정 탭에서는 조건별 가중치 8개만 편집할 수 있었는데, 실제로는 각 조건마다 기간·임계값 등 세부 파라미터가 더 많다. 이를 전부 웹에서 편집할 수 있도록 확장했다.

- `web/routers/config_router.py`
  - `_PARAM_LABELS` 신규 추가 — 10개 조건 × 17개 세부 파라미터를 한글 라벨로 매핑
  - `get_screening_strategy()`: 기존 8개 고정 `key_params` 대신, 전체 `condition_params`(nested dict)와 `param_labels`를 반환
  - `ScreeningParamsUpdate`를 `min_score: float | None`, `condition_params: dict[str, dict[str, float]] | None`로 일반화 — 기존 8개 고정 필드 제거
  - `update_screening_params()`: `condition_params`를 조건별로 deep-merge 저장, `_PARAM_LABELS`에 정의된 키만 허용
    - 기존 값이 `int`이고 입력값이 정수면 `int`로 저장해 YAML 포맷 보존 (예: `period: 14` → `14.0` 방지)
- `web/templates/settings.html`
  - "핵심 조건 파라미터" 영역을 10개 조건별 그룹으로 재구성 — 각 조건의 모든 파라미터를 입력 필드로 노출
  - `screeningParamEdits`를 `{ min_score, condition_params: {...} }` 구조로 변경, `screeningStrategy.conditions`/`condition_params`/`param_labels`를 기반으로 동적 렌더링

`pytest tests/` 192개 전체 통과(회귀 없음, web 라우터는 기존부터 미커버리지). fastapi가 로컬 환경에 설치되어 있지 않아 엔드포인트 직접 실행 검증은 하지 못했고, OCI에서 `/settings` 매매 설정 탭을 수동으로 확인해야 하는 상태로 남겨두었다.

---

## docs 정리: wide 전략 반영 + 웹 설정 편집 안내

작업 마무리로 문서를 코드와 다시 맞췄다.

- `settings/screen_config/second_stage.yaml`: 주석 표의 `wide` min_score를 `35` → `25`(CHOP+5 보정 후 30)로 수정 — 6/9 wide 완화 작업과 동기화
- `docs/SETTINGS_GUIDE.md`
  - `active_strategy` 주석과 "전략 비교" 표에 `wide` 전략 행 추가 (6/9에 추가했지만 반영이 안 되어 있던 상태)
  - 섹션 6에 "웹 대시보드에서 수정하기" 추가 — `/settings`에서 핵심 조건 파라미터 전체를 편집하는 기능 안내
- `docs/SETTINGS_REFERENCE.md`: "전략 선택" 표에 `wide` 행 추가

`pytest tests/` 192개 전체 통과 — 문서 변경만이라 회귀 없음을 확인했다.

---

## 정리

| 작업 | 내용 |
|------|------|
| 렌더링 버그 수정 | `x-data` 작은따옴표 전환으로 `/trades` 페이지 정상화 |
| 점수/사유 표시 | `score`, `sell_reason` 컬럼 추가, 매수 점수·매도 사유 표시 |
| 보유상태/매수가 | `avg_price` 컬럼 추가, 보유중/매도완료 + 매수가 표시 |
| 조건별 점수 툴팁 | `condition_scores` → 매수 점수 hover 시 조건별 점수 표시 |
| buy_context 정리 | 컬럼을 `buy_context`로 재정의 — 프리셋/임계값/전략 툴팁 |
| 매매설정 전체 편집 | 10개 조건 × 17개 파라미터를 웹에서 직접 편집 |
| docs 정리 | wide 전략 표/주석 반영, 웹 설정 편집 안내 추가 |

다음 글에서는 6월 11일 진행한 **strategy_v1/v2 분리 구조** 설계와, 공유 indicators 패키지 분리부터 strategy_v1 디렉터리 재구성까지의 작업을 다룬다.
