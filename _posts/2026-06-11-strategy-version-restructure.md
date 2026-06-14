---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (14) — strategy_v1/v2 분리 구조 설계와 3단계 이동
date: 2026-06-11 18:00:00 +0900
categories: trading development
tags: ai-trading python claude-code
author: Evan
description: 새 매매 전략(v2)을 추가할 자리를 만들기 위해 코드 전체를 strategy_v1/strategy_v2 구조로 재설계했다. 공유 indicators 패키지 분리부터 설정·스크리닝·매매 코드 이동까지 3단계로 나눠 subagent-driven-development로 진행한 과정을 기록한다.
---

**작성일**: 2026년 6월 11일  
**최종 수정**: 2026년 6월 11일  
**분야**: AI Trading, Development  
**난이도**: Advanced  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/trades-page-revamp/)에서 체결 이력 페이지를 개편하고 매매설정 파라미터 전체 편집을 추가했다. 지금까지는 매매 전략이 `screening/`·`trading/` 폴더에 단일 버전으로만 존재했는데, 곧 새로운 전략(v2)을 추가할 계획이라 **여러 전략 버전이 공존할 수 있는 구조**가 필요해졌다.

결론부터 말하면, 전체 코드를 `strategy_v1/`과 `strategy_v2/`로 분리하고 공유 로직만 최상위에 남기는 구조로 재설계했다. brainstorming으로 설계를 확정한 뒤, **Step 1(indicators 공유 패키지 분리) → Step 2(설정 분리) → Step 3(스크리닝/매매 코드 분리)** 3단계로 나눠 subagent-driven-development 방식으로 구현했다. 각 단계마다 `pytest tests/` 192개 전체 통과를 확인하며 진행했고, 로직 변경 없이 순수하게 파일 이동과 import 경로 수정만 했다.

---

## 설계: strategy_v1 / strategy_v2 + 공유 indicators

brainstorming으로 구조 변경 설계를 확정하고 spec 문서(`docs/superpowers/specs/2026-06-11-strategy-version-restructure-design.md`)로 정리했다.

- `strategy_v1`/`strategy_v2`가 동시에 존재하고, `active_strategy_version` 설정값으로 어느 한쪽만 활성화
- screening + trading(buy/sell) + preset까지 **버전별로 완전히 분리**
- 여러 버전에서 공통으로 쓰는 지표 계산 로직(`indicators/`)만 최상위에 유지
- 4단계 마이그레이션 계획
  1. `indicators/` 공유 패키지 분리
  2. `strategy_v1/settings/` 분리
  3. `strategy_v1/screening/`, `strategy_v1/trading/` 코드 분리
  4. 웹 UI 버전 선택 (v2가 실제로 생기기 전까지는 YAGNI로 보류)

---

## Step 1: indicators/ 공유 패키지 분리

`docs/superpowers/plans/2026-06-11-strategy-version-restructure-step1-indicators.md` 계획에 따라 진행했다.

- **Task 1**: `screening/conditions/`의 조건 모듈 10개 + `__init__.py`를 `indicators/`로 `git mv` (history 보존)
  - `indicators/__init__.py` 재작성
  - `screening/second_stage.py`, `backtest/backtest_runner.py`, `tests/test_conditions.py`의 import 경로를 `indicators`로 변경
- **Task 2**: `docs/HOW_TO_ADD_CONDITION.md` 경로 안내를 `indicators/` 기준으로 갱신, 각 조건 파일 docstring의 경로 주석도 보정
- **최종 리뷰**: Ready to merge — `pytest tests/` 192개 통과, `_CONDITION_REGISTRY`가 양쪽에서 정상 참조됨을 확인
- 최종 리뷰에서 발견된 `screening/conditions` 잔존 경로(`CLAUDE.md`, `AI_PROJECT_PROMPT.md`)도 일괄 수정

**검증**: `pytest tests/` 192개 전체 통과 — 순수 이동 + import 경로 변경이라 회귀 없음.

---

## Step 2: strategy_v1/settings/ 분리

`docs/superpowers/plans/2026-06-11-strategy-version-restructure-step2-settings.md` 계획을 subagent-driven-development(구현+2단계 리뷰+직접 검증+최종 리뷰)로 진행했다.

- **Task 1**: `settings/presets/` → `strategy_v1/settings/presets/`, `settings/screen_config/` → `strategy_v1/settings/screen_config/`로 `git mv`
  - `settings/app.yaml`에 `active_strategy_version: "v1"` 추가
  - `utils/config_loader.py`: `active_strategy_version`에 따라 `presets_dir`/`screening_dir`을 동적으로 결정하도록 수정
- **Task 2**: `web/routers/config_router.py`의 경로 상수 4개와 화이트리스트 10건, `web/routers/pages.py`의 프리셋 목록 glob 경로를 모두 `strategy_v1/` 접두로 갱신
- **Task 3**: `docs/{SETTINGS_GUIDE,SETTINGS_REFERENCE,TRADING_FLOW,USAGE,WORKFLOW,HOW_TO_ADD_CONDITION}.md`의 경로 참조 일괄 수정 (32 insertions, 31 deletions), `WORKFLOW.md` 설정 로드 흐름도에 `active_strategy_version` 결정 단계 추가
- **Task 4(검증)**: `pytest tests/` 192개 통과, config-load 스크립트로 새 경로의 YAML이 정상 로드되는지 확인. `python runner.py --dry-run`은 새 경로까지 정상 진행 후 기존과 동일하게 환경변수 누락으로 종료(회귀 아님)

### 최종 리뷰에서 발견된 잔여 항목

최종 리뷰 결과는 "Ready to merge: With fixes (minor)"였고, 다음 두 항목을 후속 커밋으로 즉시 수정했다.

- `strategy_v1/settings/presets/*.yaml`(3개), `strategy_v1/settings/screen_config/**/*.yaml`(7개) 헤더 주석에 남아있던 옛 경로(`# settings/presets/...`, `# settings/screen_config/...`)를 `# strategy_v1/settings/...`로 수정 — `git mv` 잔여물
- `CLAUDE.md`/`README.md`/`AI_PROJECT_PROMPT.md`에 남아있던 `settings/presets`·`settings/screen_config` 참조를 `strategy_v1/settings/...`로 일괄 수정

수정 후 `pytest tests/` 192개를 재확인했다.

---

## Step 3: strategy_v1/screening/, strategy_v1/trading/ 코드 분리

`docs/superpowers/plans/2026-06-11-strategy-version-restructure-step3-screening-trading.md` 계획을 동일한 방식(Task 1~3 구현+리뷰, Task 4 직접 검증, 최종 홀리스틱 리뷰)으로 실행했다.

- **Task 1**: `screening/{atr_filter,first_stage,market_filter,market_regime,second_stage}.py`를 `strategy_v1/screening/`로 `git mv`
  - `strategy_v1/__init__.py`, `strategy_v1/screening/__init__.py` 신규 생성
  - `second_stage.py`의 `atr_filter`/`market_regime` 상호 import, `trading/buy.py`와 `tests/test_filters.py`의 `screening.*` import를 `strategy_v1.screening.*`로 변경 (`trading.order_manager`는 변경 없음)
  - `pytest tests/` 192개 통과
- **Task 2**: `trading/{buy,sell}.py`를 `strategy_v1/trading/`로 `git mv` (`order_manager.py`는 `trading/`에 그대로 남김)
  - `strategy_v1/trading/__init__.py` 신규 생성, `trading/__init__.py`는 공통 인프라 패키지 docstring으로 재정의
  - `runner.py`에 `active_strategy_version` 분기 추가 — v1이면 `strategy_v1.trading.{buy,sell}`을 동적 import, 그 외는 `ValueError`. v2를 추가할 때는 `elif` 분기만 추가하면 되는 구조로 설계
  - `tests/test_trading.py`의 import·patch 경로를 `strategy_v1.trading.*`로 변경
  - `pytest tests/` 192개 통과, `python runner.py --dry-run`도 import 단계까지 정상 진행 확인
- **Task 3**: `CLAUDE.md`/`README.md`/`AI_PROJECT_PROMPT.md`의 프로젝트 구조 트리·모듈 표·새 조건 추가 절차·superpowers 작업 규칙 경로를 일괄 수정, 잔존 경로 참조 grep으로 재확인 (결과 없음)
- **Task 4(검증)**: `pytest tests/` 192개 통과, `--dry-run`/`config_loader` 단독 로드 모두 정상, `git status` 클린, `--backtest`는 이번에 옮긴 모듈을 import하지 않아 영향 없음 확인
- **최종 리뷰**: APPROVED — 이동된 7개 파일은 docstring·import 경로 외 로직 변경 없음, `runner.py` 분기 로직 정상, `trading/`에는 `order_manager.py`만 남음을 확인. 빈 채로 남은 untracked `screening/` 디렉토리도 정리

---

## 정리

| 단계 | 내용 |
|------|------|
| 설계 | `strategy_v1`/`strategy_v2` 공존 + 공유 `indicators/` 구조로 spec 확정 |
| Step 1 | `screening/conditions/` 10개 모듈 → `indicators/`로 분리 |
| Step 2 | `settings/presets`·`settings/screen_config` → `strategy_v1/settings/`로 이동, `active_strategy_version` 설정 추가 |
| Step 3 | `screening/*`·`trading/{buy,sell}.py` → `strategy_v1/{screening,trading}/`로 이동, `runner.py`에 버전 분기 추가 |
| 검증 | 매 단계 `pytest tests/` 192개 전체 통과, 순수 이동이라 회귀 없음 |
| 보류 | Step 4(웹 UI 버전 선택)는 v2가 실제로 생기기 전까지 YAGNI로 보류 |

이번 작업으로 `runner.py`의 `elif` 분기 하나만 추가하면 새 전략 버전을 끼워넣을 수 있는 구조가 만들어졌다. 다음 글에서는 6월 12일 진행한 strategy_v1 명세서 분리, 작업 시작/종료 절차의 skill화, 전략 버전 선택 UI 추가 작업을 다룬다.
