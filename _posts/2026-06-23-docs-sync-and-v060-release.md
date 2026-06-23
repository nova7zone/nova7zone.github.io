---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (32) — 문서 전체 점검, docs-sync 19개 문서 재작성, v0.6.0 릴리즈
date: 2026-06-23 23:00:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code
author: Evan
description: 직전에 신설한 docs-sync skill로 docs/ 폴더 19개 문서를 5개 카테고리로 나눠 전부 재작성했다. CLAUDE.md와 AI_PROJECT_PROMPT.md의 stale 정보까지 정정한 뒤, v0.5.2 이후 16건의 PR을 정리해 v0.6.0을 릴리즈하며 6월 23일을 마무리한 과정을 정리한다.
---

**작성일**: 2026년 6월 23일  
**최종 수정**: 2026년 6월 23일  
**분야**: AI Trading, Development  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/broker-sync-and-oci-automation/)에서 본계좌 실시간 잔고 동기화로 234주 phantom position을 정정하고, docs-sync skill을 새로 만들었다. 6월 23일 후반은 그 skill을 실제로 돌려 **docs/ 폴더 19개 문서 전체를 재작성**하는 "문서 전체 점검 + docs-sync + 릴리즈" 5단계 작업으로 마무리했다.

결론부터 말하면, 5개 카테고리(시작하기/설정/매매전략/운영·테스트/안전)로 나눠 19개 문서를 전부 재작성하면서 stale 내용 여러 건을 함께 정정했다. CLAUDE.md/AI_PROJECT_PROMPT.md도 코드와 다시 대조해 테스트 파일 개수, DB 테이블 개수 같은 기본적인 숫자 오기까지 잡았다. 마지막으로 v0.5.2 이후 머지된 PR 16건을 정리해 v0.6.0을 릴리즈했다.

---

## 작은 운영 수정 두 건

본격적인 문서 작업에 들어가기 전에, OCI에서 보고된 작은 문제 두 가지를 먼저 처리했다.

**update_oci.sh 자동 stash 대상 확장**: 사용자가 OCI 서버에서 `scripts/update_oci.sh`를 실행하던 중 `settings/app.yaml` 외에 `strategy_v2/settings/screen_config/second_stage/reversal.yaml`도 로컬 변경 상태라 "추적 파일에 로컬 변경이 있습니다" 에러로 막혔다. 이건 웹 대시보드의 "2차 스크리닝 조건 가중치 변경" 기능으로 서버에서 직접 수정된 정상적인 파일이었는데, 스크립트가 `app.yaml` 하나만 자동 stash 화이트리스트로 허용하고 있던 게 원인이었다. `web/routers/config_router.py::_allowed_yaml_files()`가 정의하고 있는 실제 웹 편집 가능 범위(`strategy_vN/settings/` 트리 전체 포함)를 그대로 스크립트의 `is_web_editable_yaml()`로 옮겨 일반화했다.

**docs cron 시각표 stale 시각 정정**: 사용자가 공유한 실제 crontab을 기준으로 `--update-journal`(15:35→16:15), `--report-daily`(16:00→16:30)를 정정했다. 같은 표가 중복돼 있던 `docs/USAGE.md`, `README.md`, `docs/INSTALL.md`, `docs/UPDATE.md` 4개 파일을 모두 수정했다.

---

## strategy_v1/v2 DEVELOPMENT_SPEC.md 정합성 점검

Explore 서브에이전트로 두 SPEC 문서를 실제 코드와 항목별로 대조했다.

- **v1**: 실질적 stale 내용은 없었다. `balanced.yaml`을 "10개 조건 균등 분산"으로 서술했지만 실제 가중치는 `{12,12,12,10,10,10,10,10,7,7}`로 완전 균등이 아니라는 표현 오차 1건만 수정했다.
- **v2**: 세 가지를 발견·정정했다. (1) 그룹 `top_n` 오기 — §9 다이어그램·YAML 예시·코드 주석 전부 `40`으로 남아있었는데 실제론 6/13에 이미 `15`(합계 60)로 바뀌어 있었다. (2) 슬롯제 잔존 서술 — §9 다이어그램이 여전히 "09:00 GroupA / 09:15 GroupB ..." 식 순차 실행을 암시하고 있었는데, 실제로는 6/18부터 통합 스크리닝+풀링 매수로 바뀐 상태였다. (3) `--reconcile` 시각 오기(16:00 → 실제 15:40) — 두 개 문서에서 동일하게 발견.

---

## docs-sync 카테고리 1~5 — 19개 문서 전체 재작성

전날 만든 `docs-sync` skill로 `docs/` 폴더 전체를 5개 카테고리로 나눠 순서대로 재작성했다. `docs-sync` skill 자체가 `disable-model-invocation: true`라 Skill 도구로 직접 호출하지 못해 `skill.md`를 Read로 읽어 절차를 수동으로 수행했다. 카테고리마다 Explore 서브에이전트를 병렬로 디스패치해 초안+stale 점검 결과를 받고, 직접 코드로 재검증한 뒤 최종 작성하는 방식으로 진행했다.

| 카테고리 | 문서 | 실질 stale 발견·수정 |
|----------|------|----------------------|
| 1. 시작하기 | INSTALL/OCI_QUICKSTART/UPDATE/WEBSERVICE_DEPLOY | `WEBSERVICE_DEPLOY.md`의 "SSH 터널용 127.0.0.1" 서술이 실제론 이미 `0.0.0.0` 고정(PR #49)인데 반영 안 됨 |
| 2. 설정 | APP_SETTINGS/SETTINGS_GUIDE/SETTINGS_REFERENCE/ACCOUNTS_GUIDE | `balanced.yaml` "균등 분산" 표현 정정, `ACCOUNTS_GUIDE.md`에 `sync_broker_holdings()` 누락 보강 |
| 3. 매매전략 | TRADING_FLOW.md → STRATEGY_V1/V2_trading_flow.md 분리, CONDITIONS_GUIDE | v2 전용 조건 10개(adx/aroon/candlestick 등)가 "20개 조건"이라는 제목과 달리 전혀 문서화돼 있지 않았던 콘텐츠 공백 발견·보강 |
| 4. 운영·테스트 | WORKFLOW/TESTING_GUIDE/BACKTEST_GUIDE/BACKTEST_DATA_GUIDE | 테스트 파일 6개 누락 발견, 웹 백테스트 데이터 다운로드(6/22 구현) 기능이 전혀 언급 안 된 콘텐츠 공백 보강 |
| 5. 안전 | AI_CODE_SAFETY_CHECKLIST/TOKEN_BLOCKED | `utils/reconcile.py` API 레이어 제약 목록 누락 추가 |

각 카테고리마다 `docs/README.md`의 체크리스트를 갱신했고, 마지막엔 `docs/*.md` + 루트 `README.md`/`CLAUDE.md`의 마크다운 링크를 스크립트로 전수 검사해 깨진 링크 0건을 확인했다. **이로써 19/19 문서 전체 재작성을 완료**했다. 매 카테고리마다 `pytest tests/` 717개를 재확인했다(문서만 변경이라 당연한 결과였지만, 검증 원칙상 직접 실행).

---

## CLAUDE.md/AI_PROJECT_PROMPT.md 정합성 점검 완료

docs-sync 카테고리4 작업 중 발견했던 "tests/ 37개"라는 오기를 포함해, `CLAUDE.md`/`AI_PROJECT_PROMPT.md` 전체를 코드와 다시 대조했다.

- `tests/` 파일 개수 "37개" → "41개"(실제 `test_*.py` 개수)
- `docs/` 파일 개수 "18개" → "21개"(docs-sync 19개 + README.md + 범위 밖이던 USAGE.md)
- **DB 테이블 개수 오기**: `db/schema.py`를 직접 grep해 실제 `CREATE TABLE` 9개(`data_download_runs` 포함)를 확인했는데, 문서는 "8개"/"7개" 두 곳 모두 다르게 틀려 있었다 — 9개로 통일
- `AI_PROJECT_PROMPT.md`의 "Oracle 서버 배포" 섹션이 잘못된 경로(`~/trader` 누락)로 안내하고 있던 것을 `scripts/update_oci.sh` 사용으로 교체

범위 밖으로 분리한 발견 1건: `docs/USAGE.md`가 docs-sync의 19개 문서 분류에서 빠져 있었다(설계 당시 18→19 집계 누락으로 추정) — 현재 작동엔 문제없어 `next-tasks.md`에 기록만 했다. 코드 변경은 없었다(문서만), `pytest tests/` 영향도 없었다.

---

## PR #67 merge + v0.6.0 릴리즈

"문서 전체 점검 + docs-sync + 릴리즈" 5단계 작업의 1~4단계(cron 시각표 정정, v1/v2 SPEC 점검, docs-sync 19개 문서 재작성, CLAUDE.md/AI_PROJECT_PROMPT.md 점검)를 묶어 PR #67로 master에 squash-merge했다.

`release-notes` skill 절차로 v0.5.2 이후 머지된 PR #52~#67(16건)을 조사해 초안을 작성했다. 버전 번호는 신규 기능 다수 + 운영 안정성 핵심 변경(주문체결 판단 전면 교체, 본계좌 실시간 잔고 동기화) + 실거래 동작 변경(1주 예외매수)을 근거로 `v0.5.3`(patch) 대신 `v0.6.0`(minor)을 제안해 사용자 확인을 받았다.

`build-docs/release-notes-draft-v0.6.0.md`를 9개 주제로 정리(주문체결 판단 전환, 본계좌 잔고 동기화, 1주 예외매수, 웹 백테스트, v2 동적 국면전환 백테스트, 데이터 다운로드 버그 3건, OCI 자동화, extra_05+sold 고착 버그, docs-sync)한 뒤, 태그 생성·push·`gh release create`로 릴리즈를 발행했다. 발행 후 릴리즈 노트 본문 제목이 초안 파일 제목 그대로 `# v0.6.0 (draft)`로 남아있는 걸 발견해, `gh release edit --notes-file`로 본문 제목만 `# v0.6.0`으로 정정했다.

---

## 정리

| 작업 | 내용 |
|------|------|
| 운영 수정 2건 | update_oci.sh stash 범위 확장, cron 시각표 stale 정정 |
| SPEC 점검 | v1 표현 오차 1건, v2 top_n·슬롯제 서술·reconcile 시각 3건 |
| docs-sync | 19개 문서 5개 카테고리 전체 재작성, 링크 무결성 0건 깨짐 확인 |
| CLAUDE.md 정합성 | 테스트 37→41개, DB 테이블 통일 9개, 배포 경로 정정 |
| v0.6.0 릴리즈 | PR #52~#67(16건) 정리, minor 버전 격상 |

6/15부터 6/23까지 9일간 이어진 이 시리즈는 거래량순위 API 한도 추적, IRP 평가금액 보정, 매수 무한반복 사고와 holdings-diff 전환, 그리고 문서 전체 재정비까지 — 기능 추가보다 **운영하면서 드러난 구조적 문제를 추적해 고치는 작업**이 점점 더 큰 비중을 차지했던 기간이었다. v0.6.0 릴리즈로 이번 시리즈를 마무리한다.
