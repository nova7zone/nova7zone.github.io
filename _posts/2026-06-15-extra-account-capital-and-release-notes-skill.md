---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (18) — 추가 계좌 투자원금 입력 기능, 릴리즈 노트 작성 skill
date: 2026-06-15 09:00:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code
author: Evan
description: 조회 전용 추가 계좌(KIS_EXTRA_01~10)에 투자원금을 입력·저장하는 기능을 추가해 향후 수익률 계산의 기준값을 마련했다. 이어서 릴리즈마다 반복하던 릴리즈 노트 작성 절차를 별도 skill로 표준화한 6월 15일 작업을 정리한다.
---

**작성일**: 2026년 6월 15일  
**최종 수정**: 2026년 6월 15일  
**분야**: AI Trading, Development  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/v2-settings-api-and-security-hardening/)에서 매매설정 v2 API와 보안 점검을 마쳤다. 6월 15일은 매매 로직보다는 **운영 편의 기능 두 가지**에 집중했다.

결론부터 말하면, 조회 전용 추가 계좌(`KIS_EXTRA_01~10`)에 투자원금을 입력·저장하는 기능을 추가해 앞으로 수익률을 계산할 기준값을 마련했다. 그리고 릴리즈마다 매번 손으로 정리하던 릴리즈 노트 작성 절차를 별도 skill로 표준화했다.

---

## 추가 계좌 투자원금 입력/저장 기능

추가 계좌(`accounts` 테이블의 `managed_by='manual'`)는 봇이 직접 매매하지 않고 조회만 하는 계좌다. 지금까지는 보유 종목만 동기화했는데, 수익률을 계산하려면 "처음에 얼마를 넣었는지"가 필요하다. 이번 작업은 그 투자원금을 입력·저장하는 기능까지만 다루고, 실제 수익률 계산·표시는 다음 작업으로 미뤘다.

- `db/schema.py`: `accounts.initial_capital REAL` 컬럼 추가 — `_add_column_if_missing()`으로 재배포 시 `init_db()` 호출만으로 자동 마이그레이션
- `db/repository.py`: `upsert_account()`에 **seed-once 정책** 적용 — `COALESCE(accounts.initial_capital, excluded.initial_capital)`로, DB에 이미 값이 있으면 `.env` 재시드로 덮어쓰지 않음(웹에서 수정한 값 보존). `update_account_capital()` 함수 신규 추가
- `utils/config_loader.py`: `load_extra_accounts()`가 `KIS_EXTRA_NN_INITIAL_CAPITAL` 환경변수를 파싱해 `initial_capital` 키로 반환(미설정/파싱 실패 시 `None`)
- `utils/reconcile.py`: 추가 계좌 등록 시 `initial_capital`을 `upsert_account()`로 함께 전달
- `web/routers/config_router.py`: `GET /api/config/extra-accounts`(목록+투자원금 조회), `POST /api/config/extra-accounts/{account_id}/capital`(수정) API 신규
- `web/templates/settings.html`: "추가 계좌 투자원금" 카드 신설 — 계좌별 입력칸+저장 버튼, 미등록 시 안내 문구

설계(`docs/superpowers/specs/2026-06-15-extra-account-initial-capital-design.md`) → 계획(`docs/superpowers/plans/2026-06-15-extra-account-initial-capital.md`)을 거쳐 `subagent-driven-development`로 8개 Task를 순차 진행했고, 각 Task는 spec 적합성+코드 품질 2단계 리뷰를 모두 통과했다.

`pytest tests/` 417개 전체 통과. 단, 로컬은 TOTP(`/setup`) 미설정 상태라 `/settings` 페이지에서 카드 표시·저장·재조회가 실제로 잘 되는지 브라우저로는 검증하지 못했고, OCI 또는 `/setup` 완료 후 확인이 필요하다는 점을 기록해뒀다.

---

## 릴리즈 노트 작성 skill 추가

직전까지 릴리즈를 만들 때마다 "마지막 태그 이후 머지된 PR 모아 정리"를 매번 손으로 했다. 이 절차를 `.claude/skills/release-notes/skill.md`로 표준화했다.

- `work-end`/`work-start` skill과 같은 frontmatter 형식, `disable-model-invocation: true`로 설정(Skill 도구로 직접 호출하지 않고 Read로 절차만 참고하는 방식)
- 절차: 마지막 릴리즈 태그 확인 → 그 이후 master에 머지된 PR 조사(`gh pr view`) → 다음 버전 번호는 사용자에게 확인 → 기존 `release-notes-draft-v0.4.3.md` 형식(What's Changed/개요/주요 변경사항/테스트/다음 단계)으로 초안 작성 → 태그/푸시/Release 생성은 사용자가 지시할 때만 진행

이 skill은 이번 세션에서 만들기만 했고, 실제 동작 검증은 다음 릴리즈를 만들 때(이미 `work-start`/`work-end`도 같은 방식으로 신설 후 검증했던 패턴) 확인하기로 남겨뒀다.

---

## 정리

| 작업 | 내용 |
|------|------|
| 추가 계좌 투자원금 | `accounts.initial_capital` 컬럼 + seed-once 저장 정책 + 설정 페이지 입력 카드 |
| 적용 범위 | `KIS_EXTRA_01~10`(조회 전용 계좌) — 입력/저장까지만, 수익률 계산은 후속 작업 |
| 릴리즈 노트 skill | 마지막 태그 이후 PR 조사 → 초안 작성까지 표준 절차화 |
| 검증 | `pytest tests/` 417개 통과, 브라우저 검증은 TOTP 설정 후 별도 확인 필요 |

다음 글에서는 같은 날 이어서 진행한 **전략확인(Trading Flow Chart) 페이지 신설**과, 그 과정에서 발견한 Mermaid 렌더링 버그 두 건을 다룬다.
