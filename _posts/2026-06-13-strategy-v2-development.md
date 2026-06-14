---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (16) — strategy_v2 개발, position_registry와 다중 계좌 reconcile
date: 2026-06-13 20:00:00 +0900
categories: trading development
tags: ai-trading python claude-code
author: Evan
description: 새 매매 전략 strategy_v2 개발을 3단계로 나눠 진행했다. v1 매매 흐름에 position_registry를 추가 연동하고, strategy_v2 전용 buy/sell 모듈과 사전 평가 cron을 만들고, 마지막으로 추가 계좌를 조회 전용으로 reconcile하는 다중 계좌 기능을 추가한 과정을 기록한다.
---

**작성일**: 2026년 6월 13일  
**최종 수정**: 2026년 6월 13일  
**분야**: AI Trading, Development  
**난이도**: Advanced  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/docs-cleanup-and-strategy-version-ui/)에서 `strategy_v1`/`strategy_v2`가 공존할 수 있는 구조와 전략 버전 선택 UI를 준비했다. 이번 글은 그 구조 위에서 진행한 **strategy_v2 본격 개발**을 다룬다.

결론부터 말하면, 6월 13일은 **Phase 1 → Phase 2 → Phase 3** 3단계로 나눠 진행했다. Phase 1에서는 v1의 매매 흐름에 영향을 주지 않으면서 포지션을 추적하는 `position_registry` 테이블과 정합성 점검(`--reconcile`)을 추가했다. Phase 2에서는 strategy_v2 전용 매수/매도 모듈과 장 시작 전 사전 평가(`--pre-market`) cron을 만들었다. Phase 3에서는 봇이 관리하지 않는 추가 계좌를 조회 전용으로 동기화하는 다중 계좌 기능을 추가했다. 세 단계 모두 기존 v1 로직은 건드리지 않고 **추가적(additive)**으로만 구현해서, 매 단계마다 `pytest` 전체 통과로 회귀 없음을 확인했다.

---

## Phase 1: position_registry 신설 + v1 DB 연동

명세: `strategy_v2/specs/20_phase1_v1_db_migration_spec.md`, `21_phase1_implementation_plan.md`

strategy_v2가 슬롯·전략·손절가 등을 추적하려면, v1에는 없던 포지션 단위의 영속 데이터가 필요했다. 이를 위해 `position_registry` 테이블을 신설하고, v1 매매 흐름에 "추가만" 하는 훅을 연결했다.

### 스키마 + repository

- `db/schema.py`: `position_registry`/`position_strategy_history` 테이블 신설
  - PK는 `(code, account_id)`, `account_id`는 `{mode}_main` 형태
  - 진입/청산/MFE·MAE/손절가 등 약 35개 컬럼 + 인덱스(`idx_pr_status/sector/strategy/date/mode`)
  - `init_db()`와 `_connect()`에 `PRAGMA foreign_keys = ON` 추가
- `db/repository.py`: position_registry 헬퍼 8개 추가
  - `upsert_position_registry`(INSERT OR IGNORE — 재진입 시 최초 진입가 유지)
  - `close_position_registry`(SQL로 `profit_pct`/`profit_amount`/`hold_days` 계산)
  - `update_mfe_mae`, `update_stop_price`(역행 방지 WHERE), `update_sector`
  - `get_holding_codes`, `get_all_holding_registry`, `get_sector_counts`
  - 모두 `(db_path, mode, ...)` 시그니처로 기존 `insert_trade` 패턴과 통일

### v1 매도 사유 코드 분리

- `strategy_v1/trading/sell.py`의 `_check_sell_signal` 반환형을 `Optional[str]` → `Optional[tuple[str, str]]`(reason_code, message)로 변경
  - `reason_code`(영문, `position_registry.sell_reason`용): `stop_loss`/`target_reached`/`intraday_close`/`time_stop`/`consecutive_down`/`trend_break`
  - `message`(한글, `trades.sell_reason`용)는 기존 그대로 — UI/동작에는 변화 없음

### 매수/매도 체결 시 훅 연결

- `trading/order_manager.py`/`strategy_v1/trading/sell.py`에 position_registry 연동 훅을 추가했다. 모두 `try/except` + `logger.warning`으로 감싸서, 실패해도 매매 흐름은 멈추지 않는다(`insert_trade`와 동일한 failure-isolation 패턴).
  - `_on_buy_filled`: 매수 체결 시 `upsert_position_registry` 호출 — `stop_price = entry_price * (1 + stop_loss_pct)`, `stop_pct = stop_loss_pct * 100`
  - `_on_sell_filled`: 매도 체결 시 `close_position_registry` 호출 — `sell_reason`은 `add_pending_order`로 전달된 `sell_reason_code`
  - `run_sell()` 보유 루프에서는 매도 판정 전 `update_mfe_mae` 호출

### 마이그레이션 + 정합성 점검

- `utils/migrate_position_registry.py` 신규 — `data/holdings.json` → `position_registry` 1회 초기 마이그레이션
  - `python -m utils.migrate_position_registry --mode paper`
  - 이미 holding 데이터가 있으면 스킵(멱등)
- `utils/reconcile.py` 신규 + `runner.py --reconcile` 플래그 추가
  - `holdings.json` ↔ `position_registry` 정합성 점검 — 누락 종목은 삽입, 초과 종목은 `status='sold', sell_reason='manual'`로 종료(손익 NULL), `sector='unknown'` 종목은 `get_stock_sector()`로 보강
  - 장 마감 후 cron 추가 예정: `0 16 * * 1-5 cd /path/to/bot && python runner.py --reconcile`
- `api/kis_api.py`에 `get_stock_sector(code)` 추가 — `api_constants.py`에 등록되어 있던 미사용 상수(`STOCK_INFO_PATH`/`TrId.STOCK_INFO`)를 활용, `search-stock-info` 응답의 `bstp_kor_isnm` 반환

**테스트**: `tests/test_position_registry.py` 신규(26개) — 스키마/FK, repository 헬퍼 8개, 마이그레이션(신규/멱등/빈 holdings/db_path 미설정), order_manager 훅(매수 upsert/매도 close/MFE·MAE/DB 실패 시 failure isolation), reconcile(누락삽입/초과종료/섹터갱신/멱등) 전체를 커버한다.

**검증**: `pytest tests/` 218개 전체 통과(기존 192개 + 신규 26개, 회귀 없음). `python runner.py --dry-run`은 로컬 `.env` 미설정으로 환경변수 검증 단계에서 종료되는데, 이는 기존과 동일하며 OCI/`.env` 설정 환경에서만 통과 가능하다.

---

## Phase 2: strategy_v2/trading/{buy,sell}.py + runner.py --pre-market

명세: `strategy_v2/DEVELOPMENT_SPEC.md` §11(구현 우선순위), §10-3/10-4(매수/매도 흐름)

Phase 1로 DB 기반이 갖춰진 뒤, strategy_v2의 매수/매도 본체를 **v1과 완전히 독립된 파일**로 구현했다.

### strategy_v2/trading/buy.py

- 슬롯 게이팅(`get_pending_slots()`) → 시장필터/레짐/공포단계 평가 → 일일손실한도·보유한도 체크 → 캐시 로드
- 슬롯별 그룹(A/B/C/D)에서 `_select_target_strategy`로 2차 스크리닝 프로파일 선택 → `run_group_screening()` 호출(레짐/공포/필터 delta·scale 전달)
- 주문 접수 + `position_registry.upsert()`로 `entry_strategy`/`entry_group`/`entry_score`/`stop_price` 등 v2 메타 기록 + `mark_slot_executed()`
- v1 헬퍼(`_get_holdings`, `_calc_qty`, `_order_type_code`, `_calc_limit_price` 등)는 독립적으로 복제 — `strategy_v1` 파일은 미수정

### strategy_v2/trading/sell.py

- 매도 우선순위: ① `stop_price` 이탈(직접 처리) → ②~⑥ `strategy_sell.evaluate()`
- VKOSPI 강제 fear_driven 전환: `fear_level`이 `extreme_fear`/`crisis_rising`이면, `fear_driven`이 아닌 모든 보유 종목을 무조건 `position_registry.update_strategy(..., reason="vkospi_crisis")`로 전환 (전환 자체는 매도 신호가 아니다)
- 매도 체결 시 `position_registry.close()`에 `exit_regime`/`exit_vkospi`/`exit_score` 기록

### runner.py --pre-market

- `--pre-market` 플래그 추가 — `active_strategy_version != "v2"`면 스킵
- `strategy_v2.daily_reeval.run()` 실행 후 `cache_manager.build()` → `save()`로 당일 캐시를 영속화 (08:00 cron 용도)
- `active_strategy_version` 분기에 v2 추가: `v1` → `strategy_v1.trading.{buy,sell}`, `v2` → `strategy_v2.trading.{buy,sell}`, 그 외는 `ValueError`

**테스트**: `tests/test_v2_trading.py` 신규(25개) — `_calc_qty`/`_order_type_code`/`_select_target_strategy`/`_load_profile` 단위 테스트, `run_buy`의 슬롯/한도/공포 게이팅 5종, 전체 흐름(주문 접수 + position_registry 메타 기록 검증) 3종, `run_sell`의 게이팅 2종 + `stop_price` 이탈 2종 + VKOSPI 강제전환 1종.

**검증**: `pytest tests/` 393개 전체 통과(기존 368개 + 신규 25개, 회귀 없음). v1 스크리닝/매수/매도/`order_manager` 파일은 미수정 — strategy_v2는 모두 독립 파일로 구현했다.

이 시점에서 `strategy_v2/DEVELOPMENT_SPEC.md` §11의 Phase 2 1~13단계 코드가 모두 완료됐다. 남은 14단계(OCI 배포: `0 8 * * 1-5 python runner.py --pre-market` cron 추가 + `settings/app.yaml`의 `active_strategy_version: "v2"` 전환)는 OCI 서버에서 수동으로 진행해야 한다.

---

## Phase 3: 다중 계좌(조회 전용) reconcile 통합

명세: `strategy_v2/specs/90_multi_account_spec.md`

봇이 직접 관리하지 않는 **추가 계좌**(가족 계좌 등)의 잔고도 같은 DB에서 조회할 수 있도록, 조회 전용 다중 계좌 reconcile을 추가했다.

- `db/schema.py`: `accounts` 테이블 신설(`account_id` PK, `cano`/`acnt_prdt_cd`/`label`/`mode`/`managed_by`/`env_prefix`/`is_active`) + `trades.account_id` 컬럼 추가
  - `position_registry`는 Phase 1에서 이미 PK `(code, account_id)`로 설계해뒀기 때문에 마이그레이션이 불필요했다
- `db/repository.py`: `*_by_account` 함수 신설 — `get_all_holding_registry_by_account`, `upsert_position_registry_by_account`, `close_position_registry_by_account`, `update_sector_by_account` + `accounts` CRUD(`get_accounts`, `upsert_account`). 봇 경로(live_main/paper_main)의 mode 기반 함수는 시그니처 변경 없음
- `utils/config_loader.py`: `load_extra_accounts()` 신규 — `KIS_EXTRA_01~10_*` 환경변수 중 `APP_KEY`가 등록된 슬롯만 감지해 `config["extra_accounts"]`에 주입 (`load_config()` 마지막 단계)
- `utils/reconcile.py`: 봇 관리 계좌 reconcile 이후 `_register_accounts()`로 `accounts` 테이블에 등록(봇 계좌는 `managed_by='bot'`, 추가 계좌는 `managed_by='manual'`) + 추가 계좌별로 `_reconcile_extra_account()`를 호출해 KIS API 잔고조회 → `position_registry(account_id=extra_NN)` INSERT/CLOSE/섹터보강. 한 계좌가 실패해도 다른 계좌·전체 처리를 막지 않도록 `try/except`로 격리
- `api/token_manager.py`는 변경이 필요 없었다 — 기존 `get_access_token(..., token_cache_path=...)`가 이미 계좌별 토큰 캐시 분리를 지원해서, 추가 계좌는 `KISApiClient` 인스턴스를 새로 만들어 `paths.token_cache=data/token_cache_extra_NN.json`만 지정하면 된다

**테스트**: `tests/test_multi_account.py` 신규(10개) — `load_extra_accounts` 4종, `accounts` 테이블 등록(봇/추가 계좌) 2종, 추가 계좌 reconcile(INSERT/CLOSE/섹터보강/계좌별 실패 격리) 4종.

**검증**: `pytest tests/` 403개 전체 통과(기존 393개 + 신규 10개, 회귀 없음). `strategy_v1/buy/sell`, `trading/order_manager.py` 등 봇 매매 경로는 수정하지 않았다 — 추가 계좌는 조회 전용이라 buy/sell 흐름에 진입하지 않는다.

남은 작업(명세 §11 8~9단계, 코드 외):

- 실제 `APP_KEY` 등록 후 추가 계좌 reconcile 실거래 검증 (OCI)
- 대시보드에 `accounts` 테이블 노출 (별도 작업)

---

## 정리

| Phase | 내용 | 테스트 |
|------|------|--------|
| Phase 1 | `position_registry`/`position_strategy_history` 신설, v1 매수/매도 체결 시 추가 기록 훅, 마이그레이션 + `--reconcile` | 218개 (+26) |
| Phase 2 | `strategy_v2/trading/{buy,sell}.py` 신규(독립 구현), `runner.py --pre-market` + v2 분기 | 393개 (+25) |
| Phase 3 | `accounts` 테이블, 추가 계좌 조회 전용 reconcile, `KIS_EXTRA_NN_*` 환경변수 자동 감지 | 403개 (+10) |

세 단계 모두 v1 핵심 로직은 변경하지 않고 추가적으로만 구현했기 때문에, 기존 매매 흐름에 대한 회귀 위험 없이 진행할 수 있었다. 다음 글에서는 6월 14일 진행한 매매설정 API의 버전 분기 처리, 매매설정 v2 카드 프론트엔드, 세션 보안 강화와 코드 보안 점검 작업을 다룬다.
