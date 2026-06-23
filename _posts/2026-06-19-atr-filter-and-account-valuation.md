---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (24) — ATR 필터 hard block 제거, 계좌별 원금/평가금액/수익률 표시
date: 2026-06-19 19:00:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code
author: Evan
description: 매수 후보가 9회 연속 0건이던 원인을 추적해 캐시 만료시간 설정과 ATR 필터의 hard block 설계를 함께 수정했다. 이어서 계좌별 원금·평가금액·수익률을 한눈에 보여주는 표시 기능과 수동 입출금 기능을 추가한 6월 19일 작업을 정리한다.
---

**작성일**: 2026년 6월 19일  
**최종 수정**: 2026년 6월 19일  
**분야**: AI Trading, Development  
**난이도**: Advanced  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/foreign-cumulative-and-pooled-buy-flow/)에서 외국인·기관 수급 지표를 실구현하고 v2 매수 흐름을 풀링 매수로 바꿨다. 6월 19일은 그 변경 직후 **매수 후보가 전혀 안 나오는 현상**을 추적하는 것으로 시작했다.

결론부터 말하면, 원인은 두 가지였다. 캐시 만료시간이 너무 짧아 09시 첫 사용 시점에 이미 캐시가 만료돼 있었고, ATR 필터의 hard block이 fallback 후보 전체를 걸러내고 있었다. 둘 다 고친 뒤, 화면 쪽에서는 계좌별 원금·평가금액·수익률을 보여주는 기능과 수동 입출금 기능을 추가했다.

---

## ❌ 매수 후보 0건 — 캐시 만료 + ATR hard block 이중 원인

`logs/` 점검 중 2026-06-19 09:00~11:00 사이 9회 cron이 전부 매수 후보 0건으로 끝난 것을 발견했다.

**원인 1 — 캐시 만료시간**: `cache_manager.yaml`의 `expiry_hours: 12`가 18:00 캐시 생성 → 09:00 첫 사용(15시간 경과) 시점에 이미 만료돼 있었다. 평일 15시간 + 주말 갭(최대 63시간)까지 커버하도록 `72`로 상향했다.

**원인 2 — ATR 필터 hard block**: Group B fallback 15종목이 전부 ATR hard block(5.0%)에 걸려 탈락하고 있었다. strategy_v2가 내세우는 "비례적 리스크 관리" 설계 원칙에 따라, hard block을 완전히 제거하고 soft penalty(`min_score` 상향)만 적용하도록 변경했다(`strategy_v1`은 변경하지 않음).

부수적으로, 전날(6/18) `next-tasks.md`에 기록해뒀던 근본 수정도 같은 날 처리했다. `tests/test_config_router_v2.py`의 PATCH 테스트가 `_cache_manager_yaml()` 등 실제 파일 경로 함수를 패치하지 않아 유효한 입력값을 쓰면 실제 YAML 파일을 그대로 덮어쓰던 구조적 버그를, `autouse` 픽스처(`tmp_path` 기반 `monkeypatch`)로 수정했다.

마지막으로 `docs/TRADING_FLOW.md`에 `--next-pre-market`(18:00, 캐시 생성)과 `--pre-market`(07:00, 인덱스 캐시·`daily_reeval`)의 흐름을 정확히 분리해 재작성했다.

`pytest tests/` 489개 전체 통과.

---

## 계좌별 원금/평가금액/수익률 표시 + 수동 입출금 기능

화면에서 각 계좌의 수익률을 한눈에 볼 수 있게 만들었다. 설계(`docs/superpowers/specs/2026-06-19-account-valuation-design.md`) → 계획을 거쳐 6개 Task로 `subagent-driven-development` 진행했다.

- 매일 15:40 `--reconcile`이 각 계좌(봇 + 추가 계좌)의 `get_balance()`를 호출해 `accounts.current_eval`/`evaluated_at`에 저장 — 한 계좌가 실패해도 다른 계좌 처리는 계속됨(failure isolation)
- `/accounts` 페이지에서 계좌 ID 컬럼을 제거하고 원금/평가금액/수익률 컬럼 + 전체 합산 요약(원금·평가금액 둘 다 있는 계좌만 합산)을 추가
- `/settings`에 현금 입출금(입금/출금) 입력 추가 — 금액만 입력하면 원금에 즉시 가산/차감(이력 저장은 없음). 자동 입출금 감지는 KIS API 필드 검증이 안 된 상태라 이번 범위에서 제외하고 추후 별도 작업으로 미뤘다

최종 전체 리뷰에서 중요한 위험을 하나 발견했다. `get_balance()`가 예외 없이 `total_eval: 0`을 반환하면 그대로 저장되어 `/accounts`에 **-100% 손실**로 잘못 표시될 위험이 있었다. `total_eval <= 0`이면 저장을 스킵하고 경고 로그만 남기도록 수정했고, `reconcile → get_accounts → _compute_account_display`로 이어지는 실제 round-trip 통합 테스트도 추가했다.

`pytest tests/` 512개 전체 통과(489 → 512, +23 신규 테스트).

---

## 정리

| 작업 | 내용 |
|------|------|
| 매수 후보 0건 원인 1 | 캐시 만료시간 12h → 72h(주말 갭까지 커버) |
| 매수 후보 0건 원인 2 | ATR hard block 제거 → soft penalty(min_score 상향)로 전환 |
| 테스트 격리 버그 | PATCH 테스트가 실제 YAML 파일을 직접 덮어쓰던 문제 → `tmp_path` 모킹으로 수정 |
| 계좌 표시 | `/accounts`에 원금/평가금액/수익률 + 전체 합산 요약 추가 |
| 입출금 | `/settings`에서 금액 입력으로 원금 즉시 조정(이력 없음) |
| 안전장치 | `total_eval<=0` 저장 스킵 — `-100%` 오표시 방지 |
| 테스트 | `pytest tests/` 512개 전체 통과 |

다음 글에서는 6/20에 진행한 **IRP(퇴직연금) 계좌 평가금액 보정** 작업을 3단계로 나눠 다룬다.
