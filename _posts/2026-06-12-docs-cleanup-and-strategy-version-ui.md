---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (15) — 문서 정리, work-start/end skill화, 전략 버전 선택 UI
date: 2026-06-12 18:00:00 +0900
categories: trading development
tags: ai-trading python claude-code
author: Evan
description: strategy_v1 개발명세서를 분리하고 CLAUDE.md/AI_PROJECT_PROMPT.md의 중복을 정리했다. 작업 시작/종료 절차를 skill로 만들고, 설정 페이지에 전략 버전 선택 드롭박스와 시장필터·1차 스크리닝 편집 카드를 추가한 과정을 기록한다.
---

**작성일**: 2026년 6월 12일  
**최종 수정**: 2026년 6월 12일  
**분야**: AI Trading, Development  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/strategy-version-restructure/)에서 코드를 `strategy_v1`/`strategy_v2` 구조로 재배치했다. 코드는 옮겼지만, 그동안 누적된 문서(`CLAUDE.md`, `AI_PROJECT_PROMPT.md`)에는 strategy_v1 전용 내용과 공용 내용이 뒤섞여 있었다. 이번 글은 6월 12일 진행한 **문서 구조 정리**와, 그 위에서 진행한 **전략 버전 선택 UI** 추가 작업을 다룬다.

결론부터 말하면, strategy_v1 전용 개발 정보를 `strategy_v1/DEVELOPMENT_SPEC.md`로 분리하고 `CLAUDE.md`/`AI_PROJECT_PROMPT.md`의 중복 섹션을 정리했다. 작업 시작/종료 절차는 `/work-start`, `/work-end` skill로 만들어 CLAUDE.md를 가볍게 했다. 그 다음 설정 페이지 매매설정 탭에 **전략 버전 선택 드롭박스**와 **시장필터·1차 스크리닝 설정 편집 카드**를 추가했다.

---

## strategy_v1 개발명세서 분리

`CLAUDE.md`와 `AI_PROJECT_PROMPT.md`에 strategy_v1 전용 정보(디렉토리 구조, 매수/매도 흐름, 조건 모듈 인터페이스 등)가 그대로 남아있어서, 공용 문서와 버전별 문서의 경계가 흐려져 있었다. 이를 분리했다.

- 신규 `strategy_v1/DEVELOPMENT_SPEC.md` — strategy_v1 전용 개발 정보를 한곳에 집중
  - 디렉토리 구조, 설정 로드 순서·프리셋·2차 스크리닝 전략 표
  - 매수 흐름(`buy.py`)/매도 우선순위(`sell.py`)/2차 스크리닝 점수 계산
  - 스크리닝 조건 모듈 인터페이스 + `_CONDITION_REGISTRY` 10개 + 새 조건 추가 절차
  - 전략/프리셋 전환 방법, strategy_v1 관련 테스트·주의사항
- `CLAUDE.md`: strategy_v1 전용 섹션 제거, 프로젝트 구조의 strategy_v1 블록을 요약 + 명세서 링크로 대체. 설정 로드 순서도 공용 메커니즘(`active_strategy_version` 기반)만 남기고 세부 표는 명세서로 이동
- `AI_PROJECT_PROMPT.md`: 중복·구버전 strategy_v1 섹션(스크리닝 조건 인터페이스, 매도 5가지 우선순위, 새 조건 추가/전략 전환/프리셋 전환 패턴, KIS API 조회 한도) 제거 후 명세서 링크로 대체. `token_cache.json`(이미 stale)을 `token_cache_{live,paper}.json`으로 수정

코드 변경은 없어서 `pytest` 영향도 없었다.

---

## CLAUDE.md/AI_PROJECT_PROMPT.md 중복 정리 + 작업 시작/종료 절차 skill화

`AI_PROJECT_PROMPT.md`는 애초에 `CLAUDE.md`와 거의 100% 중복된 내용(프로젝트 개요, 전체 파일 구조, 설정 로드 순서, 핵심 인터페이스, 개발 규칙, 테스트 작성 규칙, 작업 시작 체크리스트, 알려진 제약사항)을 담고 있었다. 이를 정리했다.

- `AI_PROJECT_PROMPT.md`: 위 중복 섹션을 모두 제거하고, `CLAUDE.md`에 없는 보충 정보(데이터 파일 보충 — `alert_history.json`, `runner.lock`, GitHub 저장소 정보, Oracle 서버 배포 절차)만 남기는 "보충 자료" 문서로 재구성
- `CLAUDE.md`: 상단에 `AI_PROJECT_PROMPT.md` 참고 안내 추가, 데이터 레이어 표에 보충 데이터 파일 포인터 추가
- `CLAUDE.md`의 작업 시작 절차 1·3단계에 있던 `main` → `master` 오기를 수정 (`git branch -a`로 실제 기본 브랜치가 `master`임을 확인)
- 신규: `.claude/skills/work-start/skill.md`, `.claude/skills/work-end/skill.md` — `CLAUDE.md`의 작업 시작/종료 절차를 `/work-start`, `/work-end` skill로 실행 가능하게 만듦

---

## CLAUDE.md 작업 시작/종료 절차 섹션 축약

skill을 만들고 나니, `CLAUDE.md`에 절차 전체를 다시 적어둘 필요가 없어졌다.

- 작업 시작/종료 절차의 1~6단계 상세 목록을 제거하고, 핵심 흐름 한 줄 요약 + `/work-start`, `/work-end` skill 참고 안내로 대체
- 상세 단계는 `.claude/skills/work-start/skill.md`, `.claude/skills/work-end/skill.md`에만 유지 — 항상 로드되는 `CLAUDE.md`와 명시적 호출 시에만 로드되는 skill 파일 간 중복을 제거

이 역시 코드 변경이 없어 `pytest` 영향 없음을 확인했다.

---

## /simplify 리뷰 결과 반영

문서 정리 커밋들에 `/simplify` 리뷰를 적용해 다음 항목을 정리했다.

- `strategy_v1/DEVELOPMENT_SPEC.md`: "캔들 순서(`candles[0]`이 미완성봉)" 설명이 중복돼 있던 것을 제거하고, `CLAUDE.md`의 "알려진 주의사항"을 참고하도록 변경
- `.claude/skills/work-start/skill.md`, `.claude/skills/work-end/skill.md`: `allowed-tools`에 `Read`/`Write`/`Edit`가 빠져 있어서, `work-log.md`/`next-tasks.md` 같은 md 파일을 읽고 쓰는 단계가 차단되던 문제 수정
- `build-docs/next-tasks.md`: "완료" 표시된 작업 항목의 과거 서술을 제거(이미 `work-log.md`와 중복) — 앞으로 할 작업(skill 동작 검증, `AI_PROJECT_PROMPT.md` staleness 검토)만 남기고 축약

코드 변경 없음, `pytest` 영향 없음.

---

## 설정 페이지에 전략 버전 선택 UI 추가

문서 정리를 마친 뒤, 본격적으로 설정 페이지에 **전략 버전 선택** 기능을 추가했다. `strategy_v2`가 생기면 코드 수정 없이 자동으로 선택지에 나타나도록 설계했다.

- `web/routers/config_router.py`: 기존에 `strategy_v1/...`로 하드코딩되어 있던 경로를 `active_strategy_version` 기준으로 파라미터화. `strategy_v*/settings/presets`가 실제로 존재하는 버전만 자동 감지하는 `_list_strategy_versions()` 추가. `GET/POST /api/config/strategy-version` 신규 엔드포인트로 활성 버전을 조회·변경
- `web/routers/pages.py`: `/settings` 페이지의 초기 프리셋 목록을 `active_strategy_version` 기준 디렉토리에서 로드
- `web/templates/settings.html`: 매매설정 탭에 전략 버전 선택 카드 추가. 매매 프리셋 목록을 Jinja 서버 렌더에서 Alpine `x-for` 동적 렌더로 전환. 버전 변경 시 프리셋·시장필터·2차 스크리닝·YAML 편집기 목록을 모두 재조회
- `settings/app.yaml`: `active_strategy_version` 주석에 설정 페이지에서 변경하는 경로 안내 추가

현재는 `strategy_v1`만 존재해서 드롭다운에는 v1만 표시되지만, 추후 `strategy_v2/settings/...`가 생성되면 코드 수정 없이 자동으로 선택 가능한 구조다. `pytest tests/` 192개 전체 통과(영향 없음 확인). web 라우터는 fastapi가 설치되지 않은 로컬 환경이라 단위 테스트가 불가능해 OCI에서 수동 검증이 필요한 상태로 남겨두었다.

---

## docs 폴더 strategy_v1 경로/전략 버전 선택 UI 최신화

새로 추가된 `strategy_v1/` 경로와 전략 버전 선택 UI를 문서에도 반영했다.

- `HOW_TO_ADD_CONDITION.md`: 레지스트리 등록 경로를 `strategy_v1/screening/second_stage.py`로 명시
- `SETTINGS_GUIDE.md`, `SETTINGS_REFERENCE.md`: 파일 구조 다이어그램에 `strategy_v1/settings/` 레벨 추가 (presets·screen_config가 `settings/` 바로 아래에 있는 것처럼 잘못 표기되던 부분 수정), `active_strategy_version` 변수 설명과 전환 가이드 추가
- `TRADING_FLOW.md`, `WORKFLOW.md`: `buy.py`/`sell.py`/`market_filter.py`/`first_stage.py`/`second_stage.py`/`atr_filter.py`/`market_regime.py` 등 모듈 참조에 `strategy_v1/trading|screening/` 경로 보강, `/api/config/strategy-version` 엔드포인트 안내 추가
- `USAGE.md`: 프리셋 전환 섹션에 전략 버전 선택 UI(`/settings` 매매설정 탭) 안내 추가
- 나머지 9개 문서(`AI_CODE_SAFETY_CHECKLIST`, `BACKTEST_*`, `CONDITIONS_GUIDE`, `INSTALL`, `OCI_QUICKSTART`, `TOKEN_BLOCKED`, `UPDATE`, `WEBSERVICE_DEPLOY`)는 staleness 없음을 확인

---

## 매매설정 탭: 전략버전 드롭박스 설명 + 시장필터·1차 스크리닝 변수 편집

마지막으로, 매매설정 탭의 전략 버전 선택을 버튼 그룹에서 드롭박스로 바꾸고, 시장필터/1차 스크리닝 설정을 직접 편집할 수 있는 카드를 추가했다. (설계: `docs/superpowers/specs/2026-06-12-trading-settings-strategy-detail-design.md`)

- `_STRATEGY_VERSION_DESCRIPTIONS` dict 신설, `strategy_version_descriptions` 필드를 `/api/config` 응답에 포함
- 시장필터 GET/PATCH를 `enabled`/`ma_period`/`block_below_ma`/`block_threshold_pct` 4개 필드로 확장 — `MarketFilterThresholdUpdate` → `MarketFilterUpdate`로 교체, 기존 `POST /market-filter/threshold`를 `PATCH /market-filter`로 대체
- 1차 스크리닝(`first_stage.yaml`) 설정 `GET/PATCH /api/config/first-stage` 신설 — `target_market` enum, `max_candidates≥1`, `min_trade_volume≥0`, `min_price<max_price` 검증
- 1차 스크리닝 `min/max_price` 검증 기본값을 GET 응답 기본값(`1000`/`500000`)과 일치시키는 버그 수정
- 전략 버전 선택 UI를 버튼 그룹 → `<select>`로 변경, 선택된 버전의 설명을 `strategyVersionDescriptions`에서 표시
- 시장필터 카드를 4개 필드 전체 편집 가능하도록 확장 — `marketFilterEdits`/`saveMarketFilter()`로 통합
- "1차 스크리닝 필터" 카드 신설 — `target_market`/`max_candidates`/`min_price`/`max_price`/`min_trade_volume`/`exclude_suspended` 편집, 전략 버전 변경 시 자동 재조회
- 전략 버전 변경 확인 메시지에 1차 스크리닝 설정도 함께 바뀐다는 안내 추가

**검증**: `pytest tests/` 192개 전체 통과(회귀 없음). uvicorn 구동 후 `/api/config`, `/api/config/market-filter`(GET/PATCH), `/api/config/first-stage`(GET/PATCH, 검증 에러 케이스 포함)를 라우터 함수 직접 호출로 동작 확인(TOTP 인증 미설정 상태라 HTTP 레벨 호출은 401). `market_filter.yaml`/`first_stage.yaml`은 검증 후 원래 값으로 복원했다.

> 브라우저로 직접 보는 시각 확인은 TOTP 인증 설정이 필요해 이번에는 하지 못했다. 다음 세션에서 OCI 또는 로컬 `/setup`을 완료한 뒤 `/settings` 매매설정 탭에서 드롭박스/시장필터/1차스크리닝 카드 3종을 수동으로 확인해야 한다.

---

## 정리

| 작업 | 내용 |
|------|------|
| 명세서 분리 | strategy_v1 전용 정보를 `strategy_v1/DEVELOPMENT_SPEC.md`로 분리 |
| 문서 중복 정리 | `AI_PROJECT_PROMPT.md`를 CLAUDE.md 보충 자료로 재구성 |
| skill화 | `/work-start`, `/work-end` skill 신규 추가, CLAUDE.md 절차 축약 |
| /simplify 반영 | 중복 설명 제거, skill `allowed-tools` 누락 수정 |
| 전략 버전 UI | 드롭다운으로 v1/v2 전환, 자동 버전 감지 |
| 설정 편집 확장 | 시장필터 4개 필드, 1차 스크리닝 6개 필드 웹 편집 |
| 미완료 | 브라우저 시각 확인은 TOTP 설정 후 다음 세션으로 보류 |

다음 글에서는 6월 13일 진행한 **strategy_v2 개발** — position_registry 신설부터 다중 계좌 reconcile까지의 작업을 다룬다.
