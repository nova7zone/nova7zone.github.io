---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (17) — 매매설정 v2 API/카드, 전체 보안 점검과 수정
date: 2026-06-14 21:00:00 +0900
categories: trading development
tags: ai-trading python claude-code
author: Evan
description: 매매설정 API와 화면에 strategy_v2 전용 시장필터·1차/2차 스크리닝 카드를 추가했다. 이어서 실행 경로와 웹 대시보드 보안을 전체 점검해 세션 쿠키·로그인 brute-force·파일 권한·심볼릭 링크 등 Medium 이상 항목을 수정하고, 남은 Critical 항목은 다음 세션 진행 방식을 기록한 과정을 정리한다.
---

**작성일**: 2026년 6월 14일  
**최종 수정**: 2026년 6월 14일  
**분야**: AI Trading, Development  
**난이도**: Advanced  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/strategy-v2-development/)에서 strategy_v2의 핵심 매매 로직(position_registry, buy/sell, 다중 계좌 reconcile)을 완성했다. 이번 글은 그 위에 **웹에서 v2 설정을 직접 다룰 수 있는 API/카드**를 추가하고, 프로젝트 전체에 대한 **실행/보안 점검**을 진행한 6월 14일 작업을 정리한다.

결론부터 말하면, 매매설정 API의 시장필터/1차 스크리닝 엔드포인트에 v1/v2 버전 분기를 추가하고, 설정 페이지에 v2 전용 카드 3종(시장필터/1차/2차 스크리닝)을 신설했다. 이어서 실행 경로와 웹 대시보드를 Explore 서브에이전트로 점검해 Critical/High 4건, Medium 5건을 발견했다. 이 중 세션 쿠키 보안·로그인 brute-force 방지·Medium 5건은 이번 세션에서 모두 수정했고, 실거래 로직을 건드리는 Critical 항목(부분체결 미검증)은 다음 세션에 별도 설계 과정을 거쳐 진행하기로 기록해두었다.

---

## 매매설정 API v2 버전 분기 + DB 참조 보강

먼저 매매설정 API의 시장필터/1차 스크리닝 엔드포인트가 strategy_v1과 v2에서 서로 다른 YAML 구조를 다루도록 분기 처리를 추가했다.

- `web/routers/config_router.py`
  - `_write_top_level_key()`, `_write_nested_scalar()` 신설 — 정규식 + 2-space 들여쓰기 추적 방식으로 최상위/중첩 YAML 스칼라를 치환, 주석·포맷을 100% 보존
  - `_first_stage_groups_yaml()` / `_load_first_stage_groups_yaml()` 신설
  - `get_market_filter`/`update_market_filter`/`get_first_stage`/`update_first_stage`에 v1/v2 버전 분기 추가
    - v2는 `market_filter.yaml`의 `levels.*`, `first_stage_groups.yaml`의 `groups.*` 구조로 응답/저장 (`MarketFilterUpdate.levels`, `FirstStageUpdate`의 v2 전용 필드 신설)
  - `_allowed_yaml_files()` — `strategy_{version}/settings/*.yaml`(상위 5개: `cache_manager`/`daily_reeval`/`dynamic_stop`/`fear_filter`/`strategy_sell`) glob 추가
- docs: `web/DEV_REQUEST_v2_TRADING_SETTINGS.md` 신설 — v2 매매설정 탭 확장 개발요청서(§0 사전점검, §2 v2 설정 항목별 상세, §3 신규 카드/페이지, §4 백엔드 작업목록, §5 주의사항, §6 단계별 진행 제안, §7 DB 참조 사항)
  - 이 개발요청서는 Claude Code가 아니라 **Claude 채팅**으로 먼저 작성했다. 코드 전체를 끌고 가지 않고도, v2에서 새로 추가된 설정 구조를 정리해 "다음에 무엇을 만들어야 하는지"를 문서로 먼저 뽑아내는 용도로는 채팅 쪽이 더 가벼웠다

**검증**: `pytest tests/` 403개 전체 통과(회귀 없음). v1/v2 양쪽 GET/PATCH를 수동 검증해 주석·포맷이 보존되는지(`yaml.safe_load` 재파싱 일치) 확인했다. `strategy_v1` 내부 파일은 미수정 — strategy_v1을 읽기 전용으로 유지하는 원칙을 계속 지켰다.

---

## 매매설정 v2 카드 프론트엔드 + init 연결

API가 준비된 뒤, 설정 페이지에 v2 전용 카드를 실제로 붙였다. (`docs/superpowers/plans/2026-06-14-trading-settings-v2-cards.md`의 7개 Task를 모두 완료)

- `web/routers/config_router.py`
  - `_PARAM_LABELS`/조건 라벨에 v2 신규 조건을 포함해 총 20개 조건의 한글 라벨 추가
  - `/api/config/screening-strategy` GET/PATCH에 `profile` 쿼리 파라미터 추가 — v2의 5개 2차 스크리닝 프로파일(balanced 등)을 개별로 조회/저장
- `web/templates/settings.html`
  - v2 전용 카드 3종 신설: 시장필터(`levels.*` 4단계), 1차 스크리닝(A/B/C/D 4그룹), 2차 스크리닝(5프로파일 선택 편집) — `initMarketFilterV2`/`initFirstStageV2`/`initScreeningV2` 메서드와 `x-show`로 v1/v2 카드 분기
  - `init()`/`setStrategyVersion()`에서 중복되던 v1 init 호출부를 공용 헬퍼 `initStrategyConfigCards()`로 통합 — `strategyVersion`에 따라 v1/v2 init 메서드를 자동 분기 호출

**검증**: 템플릿 문법 오류 없음 확인, `pytest tests/` 403개 전체 통과(Python 코드 변경 없음). OCI 또는 로컬 `/setup` 완료 후 `/settings` 매매설정 탭에서 v1/v2 토글 시 카드 전환과 v2 카드 3종의 표시·저장·재조회를 수동으로 확인해야 하는 상태로 남겨두었다(로컬 TOTP 미설정으로 브라우저 검증 미진행).

---

## docs 최신화 + 전체 실행/보안 점검

API/카드 작업을 마친 뒤, 전체 문서를 최신화하고 프로젝트의 실행 경로와 보안을 점검했다.

### docs 18개 파일 최신성 검증

- `AI_CODE_SAFETY_CHECKLIST.md`: API 레이어 경로를 `strategy_v1/v2` + `order_manager.py`로 수정
- `CONDITIONS_GUIDE.md`: v1/v2 조건 구성 설명 및 `HOW_TO_ADD_CONDITION_V1/V2` 상호링크 추가
- `USAGE.md`: `active_strategy_version`이 v1/v2 모두 가능함을 명시
- `WORKFLOW.md`: v2 설정 경로·엔드포인트(`/api/config/first-stage`, `profile` 파라미터) 보강, 다이어그램이 v1 기준임을 명시하고 `TRADING_FLOW`의 v2 섹션 참조 추가
- 전체 `docs/*.md`의 `> 최종 업데이트`를 날짜+시간(KST) 형식으로 통일 갱신
- 이전 PR 작업 일부(`HOW_TO_ADD_CONDITION.md` → V1/V2 분리, `APP_SETTINGS.md`/`TESTING_GUIDE.md` 신설, `.env.example`/`README.md` 보강)도 함께 커밋

GitHub Release `v0.4.2`(Draft, "매매설정 v2 카드 확장 (2단계)")를 작성하고 PR #24를 생성했다.

### 전체 실행/보안 점검

코드 변경 없이, 다음 3개 영역을 Explore 서브에이전트로 병렬 점검했다.

- `runner.py`/`trading/order_manager.py`/`api/kis_api.py` 핵심 실행 경로
- `web/` 대시보드 보안 (인증·세션·설정 API)
- 시크릿·파일 권한

그 결과 **Critical/High 4건**(부분체결 미검증, `runner.lock` 정체, 세션 쿠키 보안속성 미흡, 로그인 brute-force 미방지)과 **Medium 5건**을 발견했고, `next-tasks.md`에 우선순위별로 기록했다.

---

## ✅ 세션 쿠키 보안 강화 + 로그인 brute-force 방지

발견된 High 항목 중 두 가지를 바로 수정했다.

- `web/main.py`: `SessionMiddleware`에 `same_site="strict"` 적용, `https_only`를 `WEB_SESSION_HTTPS_ONLY` 환경변수로 제어(기본 `false`)
- `web/auth/router.py`: `data/web_auth.json`에 `failed_attempts`/`locked_until` 필드를 추가 — 5회 연속 로그인 실패 시 15분 전역 잠금, 성공 시 초기화
- `.env.example`: `WEB_SESSION_HTTPS_ONLY` 추가
- `docs/WEBSERVICE_DEPLOY.md`: Phase 4(nginx+HTTPS) 완료 후 `WEB_SESSION_HTTPS_ONLY=true` 설정 안내 추가

`tests/test_web_auth.py` 신규(5개 케이스), `pytest tests/` 408개 전체 통과. `next-tasks.md` 항목 #3, #4를 완료 처리했다.

---

## ✅ 전체 점검 Medium 항목 일괄 수정 (5건)

남은 Medium 5건도 한 번에 정리했다.

- `utils/file_utils.py`: 공용 `apply_secure_permissions()` 추가 — `save_json_locked()`의 `os.replace()` 직후 `chmod 600` 적용(`holdings.json`, `pending_orders.json` 등 전체) — next-tasks #5
- `web/routers/config_router.py`
  - `/api/config/file` GET/POST에 `_is_safe_path()` 추가 — `Path.resolve()`로 프로젝트 루트 밖 심볼릭 링크 우회를 차단 — next-tasks #6
  - `_write_*_key`/`_write_top_level_key`의 `re.sub` 치환을 `lambda m: m.group(1) + value`로 변경 — value에 포함된 `\`/`$`가 백레퍼런스로 잘못 해석되는 것을 방지 — next-tasks #7
- `web/auth/router.py`: `_save_auth()`에 `apply_secure_permissions()` 적용(`data/web_auth.json`의 TOTP 시크릿을 `chmod 600`) — next-tasks #8
- `next-tasks.md` #9(`_is_expired`의 KST 처리)는 재검토 결과 timezone-aware 비교로 이미 정상 동작함을 확인 — 위험 아님으로 정리

`pytest tests/` 408개 전체 통과.

---

## 보류: next-tasks #1 진행 방식 기록 + crontab 문서화

마지막으로, 가장 중요한 Critical 항목인 **부분체결 미검증**(미체결→체결 판단 시 부분체결을 검증하지 않는 문제)은 이번 세션에서 손대지 않고, 다음 세션 진행 방식만 기록했다.

- `next-tasks.md`: Critical #1에 다음 세션 진행 방식을 기록 — `trading/order_manager.py`/`api/kis_api.py`는 실계좌 매매 로직이므로 CLAUDE.md의 5단계(clarify→design→plan→code→verify)를 준수하고, `superpowers:brainstorming`으로 KIS **주문체결내역조회 API**(TR ID) 조사부터 시작
- `docs/UPDATE.md`: STEP 5에 "E. crontab 항목 추가/변경" 섹션 신규 추가 — `INSTALL.md` 기준 4개 기본 cron 항목 + `active_strategy_version: v2` 전환 시 필요한 `--pre-market` 항목, 등록 확인 방법, 변경 유형별 추가 작업 표·주의사항에 crontab 관련 행 보강

---

## 정리

| 작업 | 내용 |
|------|------|
| 매매설정 API v2 분기 | 시장필터/1차 스크리닝 엔드포인트에 v1/v2 버전별 YAML 구조 분기, 주석/포맷 보존 |
| v2 카드 프론트엔드 | 시장필터/1차/2차 스크리닝 v2 전용 카드 3종, v1/v2 init 자동 분기 |
| 전체 점검 | Critical/High 4건, Medium 5건 발견 (next-tasks.md 기록) |
| 즉시 수정 | 세션 쿠키(`same_site`/`https_only`), 로그인 brute-force 잠금 |
| Medium 5건 수정 | 파일 권한 `chmod 600`, 심볼릭 링크 검증, YAML 치환 안전화 |
| 보류 | Critical #1(부분체결 미검증)은 다음 세션, KIS API 조사부터 brainstorming |

6월 14일까지의 작업으로 strategy_v1/v2 공존 구조, position_registry 기반 추적, 다중 계좌 reconcile, 웹 설정 v1/v2 카드, 그리고 전체 보안 점검까지 한 사이클이 마무리됐다. 다음 글에서는 next-tasks #1(부분체결 검증) 설계 과정부터 이어서 다룬다.
