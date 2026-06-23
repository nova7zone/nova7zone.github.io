---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (31) — 본계좌 실시간 잔고 동기화, v2 백테스트 국면전환, OCI 자동화
date: 2026-06-23 12:00:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code
author: Evan
description: v2 백테스트에 시장국면 기반 동적 전략전환 시뮬레이션을 추가하고, OCI 서버 업데이트를 자동화하는 스크립트를 만들었다. 전날 사고로 쌓여있던 234주 phantom position을 본계좌 실시간 잔고 동기화 기능으로 직접 정정한 6월 23일 전반 작업을 정리한다.
---

**작성일**: 2026년 6월 23일  
**최종 수정**: 2026년 6월 23일  
**분야**: AI Trading, Development  
**난이도**: Advanced  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/order-fill-holdings-diff-bug/)에서 매수 무한반복 사고를 발견하고 체결판단을 holdings-diff 방식으로 전환했다. 하지만 그 수정은 이미 쌓여있던 SK네트웍스 234주를 자동으로 회복시켜주진 않는다. 6월 23일은 그 phantom position을 실제로 정정하는 작업으로 마무리되는데, 그 전에 v2 백테스트 기능 확장과 OCI 운영 자동화도 진행했다.

결론부터 말하면, v2 백테스트에 시장국면(bull/chop/bear)에 따라 전략 프로파일이 날짜별로 바뀌는 동적 국면전환 시뮬레이션을 추가했다. OCI 서버 업데이트를 자동화하는 스크립트를 만들어 실제로 검증했다. 그리고 `sync_broker_holdings()`를 새로 만들어 매 cron마다 실제 KIS 잔고와 자동 대조하도록 했고, 직접 실행해서 234주가 정확히 정정되는 것을 확인했다. 마지막으로 매수 수량이 0이 되어 스킵되던 케이스에 1주 예외매수를 추가했다.

---

## v2 백테스트 동적 국면전환(시장 regime 기반) 시뮬레이션 추가 (6-Task)

v1 백테스트는 `second_stage` 프로필을 미리 선택해야 그 선택에 따른 수익률을 확인할 수 있는데(정상 동작), v2는 실거래에서 시장국면에 따라 `second_stage`가 날짜마다 동적으로 바뀌는데도 백테스트 엔진은 처음 로드된 정적 설정 하나로만 전체 기간을 도는 근본적 한계가 있었다.

brainstorming으로 범위를 확정했다 — 4그룹 스크리닝·VKOSPI 공포 필터·동적 손절·Hysteresis 매도는 백테스트용 데이터(VKOSPI 히스토리·섹터 매핑·수급 데이터)가 없어 이번 범위에서 제외하고, **KOSPI 지수 기반 시장국면(bull/chop/bear) 감지**로 trend_following/momentum/balanced 프로파일을 날짜별로 전환하는 것까지만 구현했다.

- `backtest/data_downloader.py`: `download_index_candles()` 추가 — KOSPI 지수 캔들을 종목 캔들과 동일한 CSV 스키마로 저장
- `backtest/v2_regime_screening.py` 신규 — 순수 계산 헬퍼. `strategy_v2/screening/{market_regime,second_stage,atr_filter}.py`의 실거래 공식을 직접 import해 재사용(해당 파일들은 한 글자도 수정하지 않음 — 읽기 전용 의존)
- `backtest_runner.py::run_backtest()`에 `strategy_version` 파라미터 추가 — v2는 매 시뮬레이션일마다 KOSPI 종가로 국면을 재감지해 프로파일을 전환하며 매수 평가
- 매수 거래 레코드에 `regime`/`target_strategy` 필드 추가, 웹 `/backtest/{run_id}` 상세 페이지에 국면/프로파일 분포 표시 추가

구현 중 기존 결함도 하나 발견해 함께 수정했다 — `test_renders_with_no_history` 테스트가 `_load_app_yaml`을 mock하지 않아 실제 `data/trading.db`(기존 백테스트 이력 포함)를 읽어버려 "이력 없음" 분기가 트리거되지 않고 실패하던 테스트 격리 누락 버그였다.

`pytest tests/` 691개 전체 통과. 로컬엔 실제 KIS API 키·백테스트 CSV가 없어 unit/통합 테스트로만 검증했고, OCI 배포 후 실데이터 기준 확인이 필요한 항목으로 남겼다.

---

## OCI 서버 업데이트 자동화 스크립트 추가 (7-Task)

`docs/UPDATE.md`/`docs/WEBSERVICE_DEPLOY.md`에 문서화된 OCI 서버 수동 업데이트 절차(venv 확인, 의존성 확인, git pull, kis-web 재시작, DB 확인)를 하나의 쉘스크립트로 자동화했다.

brainstorming으로 범위를 확정했다 — pull 브랜치는 master만, `app.yaml` 충돌은 자동 stash, DB 확인은 파일존재+integrity_check, 의존성은 매번 무조건 설치, `kis-web.service` 변경은 자동 감지·적용, 실패 시 즉시 중단, 텔레그램 알림은 없음.

`scripts/update_oci.sh`를 함수 단위로 구성했다(`check_branch`, `check_venv`, `check_local_changes_and_stash`, `do_git_pull`, `install_dependencies`, `sync_service_file_if_changed`, `restart_web_service`, `verify_db_integrity` 등). `UPDATE_OCI_REPO_ROOT` 환경변수로 `REPO_ROOT`를 오버라이드할 수 있게 해 로컬에서 임시 git 저장소로 테스트할 수 있도록 설계했다.

최종 리뷰에서 Important 1건을 발견했다 — `verify_db_integrity()`가 `set -euo pipefail` 하에서 sqlite3가 비정상 종료(DB 손상 시 흔한 패턴)하면 "DB 손상은 경고만 하고 절대 스크립트를 중단하지 않는다"는 설계 원칙을 깨고 스크립트 전체가 죽어버리는 버그였다. `result="$(sqlite3 ... 2>&1 || true)"`로 수정 후 재리뷰 "Ready to merge: Yes".

이 스크립트는 sudo/systemctl/git을 직접 다뤄 pytest 대상이 아니다 — `bash -n` 문법 검사 + 스텁(sudo/systemctl/sqlite3/pip) 기반 임시 git 저장소 시나리오 테스트로 검증했다. `pytest tests/` 691개는 이 작업과 무관하게 통과(회귀 없음). `docs/UPDATE.md`에 "자동화 스크립트(권장)" 섹션을 추가했다.

---

## ✅ 본계좌 실시간 KIS 잔고 동기화 (4-Task, PR #63 merge)

전날(6/22)의 매수 무한반복 사고로 holdings-diff 전환은 끝냈지만, 어제저녁 `--reconcile` 실행 후 봇 대시보드(마니커 148주)와 실제 KIS 모의투자 계좌(SK네트웍스 234주)가 다르다는 보고가 있었다. systematic-debugging으로 다시 조사했다.

로그·DB·`get_balance()` 직접 조회로 원인을 확정했다 — 6/22 마니커 손절매도와 SK네트웍스 26회 매수 시도 전부 실제로는 체결됐으나 구버전 체결판단 로직이 매번 오판해 `holdings.json`이 갱신되지 않았던 것이다. 같은 날 holdings-diff 전환으로 재발 방지는 됐지만, **"봇 자신의 계좌는 KIS 실제 잔고 대조 장치가 없다"는 공백**(6/21에 기록해뒀던 운영 안정성 공백 2건 중 하나)은 여전히 미해결로 남아있던 구조적 원인이었다.

brainstorming → 설계 → 계획(4 Task) → 구현했다.

- `utils/reconcile.py`에 v1/v2 라우팅 헬퍼(`_upsert_holding`/`_close_holding`) 추가, 기존 `run()`의 누락/복구/초과 종목 처리를 헬퍼 사용으로 교체
- `sync_broker_holdings()` 신규 — 매 15분 cron마다 `get_balance()`로 실제 KIS 잔고와 `holdings.json`/`position_registry`를 대조해 자동 보정, 드리프트 발견 시 텔레그램 알림
- `runner.py`에 연동(미확인 주문 처리 직후, `--dry-run` 가드 포함)
- 부수 발견: 본계좌 reconcile 경로가 `active_strategy_version`(v1/v2)과 무관하게 항상 v1 스키마로 기록하던 별도 버그도 같은 라우팅 헬퍼로 해결

최종 whole-branch 리뷰 "Ready to merge: Yes". **직접 실행해 실제 효과를 확인**했다(서브에이전트가 아니라 컨트롤러가 직접 수행 — 실제 데이터/텔레그램 영향 때문):

- `--dry-run` → `holdings.json` 무변화 확인
- 실제 `python runner.py` 1회 → `holdings.json`이 실제 KIS 잔고(SK네트웍스 234주)와 정확히 일치하도록 자동 정정됨
- 정정 직후 봇이 정상적으로 "연속 하락 7일" 조건을 인식해 234주 매도 주문을 접수(주문번호 0000034405)

`pytest tests/` 704/704 통과. PR #63 머지 후 `feature/build`를 master에 동기화했다.

---

## OCI 업데이트 자동화 스크립트 실서버 실행 검증 2/3 완료

`scripts/update_oci.sh`를 OCI 서버에서 직접 실행해 브랜치/venv 사전점검·`git pull`(fast-forward)·`app.yaml` 자동 stash/복원·의존성 설치·서비스 재시작(active 확인)·DB 무결성 확인(ok)까지 전체 단계가 에러 없이 정상 완료됨을 확인했다. 미검증 1건은 남았다 — 이번 실행은 `kis-web.service` 파일 변경이 없는 PR이었어서, 서비스 파일이 실제로 바뀐 PR을 반영할 때 systemd 갱신이 의도대로 동작하는지는 다음에 해당 파일을 바꾸는 PR이 머지되면 확인하기로 했다.

---

## docs-sync skill 신설 (2-Task)

`docs/` 폴더 18개 문서의 양식·점검순서·전략버전별 분리 기준이 제각각이라 통일하고 싶다는 요청이 있었다. brainstorming으로 "문서 구조 설계 먼저, 자동화 skill은 그 다음" 두 단계로 분리했다.

- 설계: 카테고리 5개(시작하기/설정/매매전략/운영·테스트/안전) + 추천 읽기순서, 공통 메타(최종업데이트/대상독자/한줄요약/관련문서), `TRADING_FLOW.md` → `STRATEGY_V1/V2_trading_flow.md` 분리, 기존 문서는 `docs/archive/`에 보관
- Task 1: `docs/README.md` 19개 문서 체크리스트 골격 + `docs/archive/` 폴더
- Task 2: `.claude/skills/docs-sync/skill.md` — 문서별 읽기전용 서브에이전트 디스패치 → 컨트롤러 검토·최종작성 → 원본 아카이브 → README 체크 갱신 → 링크 무결성 점검 절차

사용자 피드백으로 stale 점검 시 코드만 보지 말고 `work-log.md`(최근 변경 맥락)·설계문서(설계 의도)도 함께 참고하도록 skill.md에 보강했다. 실제 18→19개 문서 재작성 실행은 이번 범위 밖으로, skill을 호출해 별도 세션에서 진행하기로 했다(다음 글에서 다룬다).

---

## 매수 수량 0 — 1주 예외매수 + 로그 정확도 개선 (2-Task)

`logs/trader.log` 점검 중 "매수 수량 0 — 잔고 부족 스킵" 로그가 반복 발견됐다(예: 잔고 761만원인데 삼성전자 34만9500원 1주를 "잔고 부족"으로 스킵). 추적 결과 실제 원인은 계좌 잔고가 아니라 **종목당 매수예산**(`buy_amount_per_stock`, neutral 기준 30만원)이 1주 가격보다 작아서 `actual_buy // price`가 0이 되는 것이었다.

brainstorming으로 동작을 결정했다 — 1주 예외매수는 계좌 사용가능금액 이내일 때만, 종목당 매수예산의 2배까지만 허용.

- `_calc_qty()`가 `int` 단일 반환 대신 `(qty, reason)` 튜플 반환 — `reason`: `"ok"`/`"insufficient_balance"`/`"single_share_override"`/`"budget_exceeded"`
- `strategy_v1/trading/buy.py`, `strategy_v2/trading/buy.py` 양쪽에 독립적으로 동일하게 적용(공유 모듈로 묶지 않음)

최종 whole-branch 리뷰(opus) "Ready to merge: Yes" — v1/v2가 공유 코드 없이도 4가지 사유 문자열·임계값 로직·경계값 처리가 한 줄씩 동일함을 확인했다. **이전엔 예산보다 비싸면 그냥 스킵되던 종목이 이제(예산~2배 사이일 때) 실제로 1주 매수 주문이 나가는, 실거래 동작이 바뀌는 변경**이다. 배포 후 하루 정도 실제로 이 1주 매수가 의도대로 발동하는지 관찰하기로 했다.

`pytest tests/` 717/717 통과.

---

## 정리

| 작업 | 내용 |
|------|------|
| v2 백테스트 국면전환 | KOSPI 기반 bull/chop/bear 감지로 프로파일 날짜별 전환 시뮬레이션 |
| OCI 자동화 스크립트 | 브랜치/venv/git pull/stash/재시작/DB확인 전체 자동화, 실서버 2/3 검증 |
| 본계좌 잔고 동기화 | `sync_broker_holdings()` — 234주 phantom position 직접 정정 확인 |
| docs-sync skill | 18개 문서 통일 재작성 절차 신설(실행은 다음 작업) |
| 1주 예외매수 | 매수예산보다 비싼 종목도 2배 이내면 1주 매수 허용 |
| 테스트 | `pytest tests/` 717/717 통과 |

다음 글에서는 같은 날 진행한 **문서 전체 점검, docs-sync 5개 카테고리 19개 문서 재작성, v0.6.0 릴리즈**까지를 다룬다.
