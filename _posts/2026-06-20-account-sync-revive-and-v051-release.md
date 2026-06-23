---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (26) — 추가계좌 오삭제 방지, REVIVE 로직, v0.5.1 릴리즈
date: 2026-06-20 21:00:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code
author: Evan
description: API 호출 실패와 진짜 빈 보유종목을 구분하지 못해 정상 보유종목이 통째로 삭제되던 버그를 고치고, 한 번 sold로 잘못 기록된 종목이 영구히 되살아나지 못하던 REVIVE 버그까지 잡았다. 문서 전체 최신화와 v0.5.1 릴리즈로 6월 20일 작업을 마무리한 과정을 정리한다.
---

**작성일**: 2026년 6월 20일  
**최종 수정**: 2026년 6월 20일  
**분야**: AI Trading, Development  
**난이도**: Advanced  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/irp-pension-valuation-fix/)에서 IRP 계좌 평가금액을 3단계에 걸쳐 보정했다. 같은 날 이어서, 그 IRP 매뉴얼 입력 기능을 실거래로 검증하던 중 **보유종목이 통째로 사라지는 현상**을 발견했고, 추적 끝에 두 가지 버그를 더 잡았다.

결론부터 말하면, API 호출이 실패한 응답과 진짜로 보유종목이 0개인 정상 응답을 구분하지 못해 정상 보유종목 전체가 조용히 삭제되던 버그를 고쳤다. 그리고 한 번 `sold`로 잘못 기록된 종목이 다시 사도 영원히 되살아나지 못하던 REVIVE 버그도 함께 해결했다. 마지막으로 문서 전체를 최신화하고 v0.5.1을 릴리즈했다.

---

## ❌ 버그: API 실패와 "진짜 빈 보유종목"을 구분 못 해 오삭제

IRP 매뉴얼 입력 기능(PR #44)을 실거래로 검증하던 중, `/accounts/extra_02` 보유종목이 16:12엔 정상 6건이 삽입돼 있었는데 18:15 직전 조회에서는 0건으로 사라지는 현상을 발견했다.

추적해보니 `_reconcile_extra_account()`의 "케이스 2: DB에 있고 실계좌에 없음 → CLOSE" 로직이, `get_balance()`(`TTTC8434R`)의 **API 호출 실패 응답**(`{'holdings': [], ...}`)과 **진짜로 보유종목이 0개인 정상 응답**을 구분하지 못하고 있었다. 이 계좌에서 이번 세션 내내 관찰되던 간헐적 500 에러가 한 번이라도 나면, 정상 보유종목 전체가 경고 로그 없이 CLOSE되는 걸 실제로 재현해 확인했다.

평가금액(`total_eval`) 저장 쪽엔 이미 "0 이하면 스킵+경고" 안전장치가 있었지만, 보유종목 동기화 쪽엔 같은 안전장치가 없었던 게 근본 원인이었다.

- `get_balance()` 반환에 `success: bool` 추가(기존 3개 키는 그대로, 순수 추가 — 다른 8개 호출부에 영향 없음)
- `_reconcile_extra_account()`에서 `success=False`면 보유종목 동기화(INSERT/CLOSE/섹터갱신) 전체를 스킵하고 기존 DB 상태를 보존

최종 리뷰에서 진짜 전량매도 시 CLOSE가 정상 동작하는지는 별도 회귀 테스트로 다시 확인했다. `pytest tests/` 555개 전체 통과(549 → 555, +6).

---

## ❌ 버그: sold 상태에서 다시 사도 영원히 sold로 남음 (REVIVE)

위 수정을 배포한 뒤에도 `/accounts/extra_02` 보유종목이 여전히 "없음"으로 표시되는 재발 보고가 들어왔다. DB를 직접 조회해보니 6개 종목 모두 `status='sold'`, `entry_date='2026-06-18'`로 남아 있었다. 직전 수정은 정상 동작했지만, **그 적용 이전에 이미 잘못 sold로 박힌 과거 데이터를 복구하는 경로가 코드에 없었던 것**이 진짜 원인이었다.

근본 원인: `_reconcile_extra_account()`가 `status='holding'`인 행만 조회해 비교하기 때문에, `sold` 행은 "DB에 없음"으로 오인되어 매번 `upsert_position_registry_by_account()`(`INSERT OR IGNORE`)를 호출하지만 PK(`code`+`account_id`)가 이미 `sold`로 존재해서 매번 조용히 무시됐다. 로그는 "INSERT 성공"으로 찍히는데 DB는 한 번도 바뀌지 않는 상황이었다.

- `db/repository.py`에 `get_all_registry_codes_by_account()`(상태 무관 전체 조회), `revive_position_registry_by_account()`(sold 행을 holding으로 복구 + entry_* 최신화 + sell_* NULL 초기화, `WHERE status='sold'` 가드) 추가
- `_reconcile_extra_account()`에 REVIVE 분기 삽입(`holding_codes & sold_codes`)

최종 리뷰에서는 버그가 end-to-end로 닫혔는지(sold → broker 재보유 보고 → REVIVE 도달 확인), 봇 관리 계좌 경로에 동일한 잠재적 결함이 있는지(있지만 트리거 원인이 달라 범위 밖이 맞음), 진짜 매도 후 재매수를 "한 번도 안 팔았던 것"으로 오인할 위험(조회 전용 계좌라 실현손익 이벤트가 없어 무해)까지 점검했다.

`pytest tests/` 559개 전체 통과(555 → 559, +4). PR #46 머지 후 OCI에서 `/accounts/extra_02` 보유종목이 정상 표시되는 것을 직접 확인했다.

---

## 문서·코드 주석 전체 최신화 (병렬 서브에이전트 감사 8 Task)

며칠간 strategy_v2, 다중 계좌, IRP 기능이 빠르게 쌓이면서 문서가 따라가지 못하고 있었다. 4개 영역(설치·배포 / 설정·매매흐름 / 조건·백테스트 / 테스트·토큰·안전·워크플로우)을 병렬로 감사한 뒤 정리했다.

- `docs/ACCOUNTS_GUIDE.md` 신규 작성(계좌 관리/IRP/현금입출금/reconcile 가이드)
- `docs/` 8개 파일의 stale 정보 정정(디렉토리 경로, `max_calls_per_run` 기본값, `universe_size`, `market_filter` 허용폭, 테스트 파일 목록, `--reconcile` 등 cron 모드)
- `CLAUDE.md` 전체 재작성 — strategy_v2/다중계좌/IRP/DB 7개 테이블/웹 라우터 반영, "v1 단일" 등 stale 서술 제거
- `README.md` 최신화 — 매도 4단계로 정정, 전략 4종(wide 추가), v2/다중계좌 안내 추가
- 코드 주석 4개 영역 병렬 감사 후 실제 오류 7건 정정(`cache_manager.py`/`daily_reeval.py` 트리거 시각, `cond_macd.py` 점수 기준, `runner.py` `--reconcile` 누락, `daily_report.py`의 존재하지 않는 갱신 경로 주장 등)

별도로 기록만 해둔 발견: `daily_stats.total_eval`이 갱신 경로 없이 항상 0으로 기록되는 dead 컬럼이라는 것을 발견했다. 화면에 노출되지 않아 영향이 적어 주석만 정정하고 수정은 보류했다.

매번 `pytest tests/`를 실행해 동작 무변경을 확인했다(559개 통과).

---

## v0.5.1 릴리즈 (PR #38~#47)

마지막 태그 `v0.5.0`(6/18) 이후 머지된 PR #38~#47(10건 — 계좌 관리 기능 신설, IRP 지원, reconcile 안정화, 문서·주석 전수 정정)을 정리해 릴리즈했다.

- `release-notes` skill 절차로 `build-docs/release-notes-draft-v0.5.1.md` 작성
- 버전 번호는 추천했던 `v0.6.0` 대신 사용자가 패치 레벨(`v0.5.1`)을 선택
- `git tag -a v0.5.1` → push → `gh release create v0.5.1` 완료
- `feature/build` → `master` fast-forward 머지로 동기화 유지

---

## 정리

| 버그 | 원인 | 수정 | 효과 |
|------|------|------|------|
| 보유종목 오삭제 | API 실패 응답과 정상 빈 응답을 구분 못 함 | `get_balance()`에 `success` 플래그 추가 | 실패 시 동기화 스킵, DB 보존 |
| REVIVE 누락 | sold 행은 INSERT OR IGNORE로 영원히 무시됨 | `revive_position_registry_by_account()` 신규 | 재매수 시 sold→holding 정상 복구 |
| 문서 stale | strategy_v2/다중계좌/IRP 반영 안 됨 | 8개 docs + CLAUDE.md + README.md 전체 재작성 | 코드-문서 정합성 회복 |
| 릴리즈 | PR #38~#47(10건) | v0.5.1 태그·릴리즈 게시 | — |

같은 클래스의 버그(API 실패를 "정상 빈 상태"로 오인)가 두 단계(보유종목 오삭제, 이후 REVIVE 누락)에 걸쳐 연쇄적으로 드러난 하루였다. "0이거나 비어 있는 응답"을 다룰 때는 그게 진짜 0인지, 호출 자체가 실패한 결과인지부터 구분해야 한다는 교훈을 다시 확인했다.

다음 글에서는 6/21에 진행한 **IRP 디폴트옵션 표시 버그와 OCI 운영 인프라 결함 2건**, **DB 조회 전용 페이지** 신설을 다룬다.
