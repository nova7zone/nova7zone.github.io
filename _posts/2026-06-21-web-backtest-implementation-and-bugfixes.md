---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (29) — 웹 백테스트 구현(PR #52), 경로탈출 수정, 30일 하드캡 추적기
date: 2026-06-21 18:00:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code
author: Evan
description: 웹에서 백테스트를 실행하고 결과를 확인하는 기능을 9개 Task로 구현했다. 재검토 중 발견한 preset 경로탈출 취약점을 막고, 백테스트 데이터 다운로드의 무한 페이지네이션과 모의투자 30거래일 하드캡을 두 번에 걸쳐 추적해 진짜 원인(빈 시작일 파라미터)을 찾아낸 6월 21일 마지막 작업을 정리한다.
---

**작성일**: 2026년 6월 21일  
**최종 수정**: 2026년 6월 21일  
**분야**: AI Trading, Development  
**난이도**: Advanced  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/web-backtest-investigation-and-v052-release/)에서 웹 백테스트 사전조사를 마치고 v0.5.2를 릴리즈했다. 같은 날 마지막으로, 그 사전조사를 바탕으로 **웹 백테스트 실행+결과확인 기능을 실제로 구현**했고, 곧이어 보안 취약점 한 건과 데이터 다운로드 버그 두 건을 연달아 추적했다.

결론부터 말하면, 9개 Task로 웹 백테스트 기능을 구현하고 PR #52로 머지했다. 재검토 과정에서 직전 리뷰가 "위험 없음"으로 판단했던 preset 경로탈출 취약점이 실제로는 위험하다는 걸 재현해 막았다. 이어서 데이터 다운로드 스크립트의 무한 페이지네이션을 고치고, 모의투자 30거래일 하드캡을 두 차례 진단 끝에 진짜 원인(빈 시작일 파라미터)까지 찾아냈다.

---

## 웹 백테스트 실행+결과확인 기능 구현 완료 (PR #52)

설계 → 계획(9개 Task) → 사용자 승인을 거쳐 구현했다. 실행 방식은 두 접근법(인프로세스 스레드+DB 상태기록 / `runner.py --backtest` 서브프로세스 위임) 중 전자로 결정했다 — 추가 의존성(Celery/Redis) 없이 `backtest_runs` 테이블의 `status='running'` 행 존재 여부로 동시 1건 제한을 구현했다.

- Task 1~2: `db/schema.py`에 `backtest_runs` 테이블 + `db/repository.py` CRUD 6함수
- Task 3: `utils/config_loader.py::load_config()`에 전략버전/프리셋 오버라이드 파라미터 추가(기본 동작 byte-identical 유지 확인)
- Task 4: `backtest_runner.py::run_backtest()` 반환값에 `equity_curve` 추가
- Task 5~6: `web/routers/backtest_router.py` 신규 — `POST /api/backtest/run`(검증+동시성+백그라운드 스레드 실행), `GET /api/backtest/{run_id}`(폴링)
- Task 7~9: 라우터 등록 + 고아 `running` 행 정리 startup 훅, `web/routers/pages.py` + 템플릿 2개(실행 폼+이력 목록, 결과 상세 — 요약 카드·Chart.js 자산추이 차트·거래내역)

9개 Task 모두 spec 적합성+코드 품질 리뷰를 통과했고, 최종 whole-branch 리뷰는 "Ready to merge: Yes" 판정이었다. Minor 4건 중 2건(startup 훅이 `init_db()`를 직접 호출하지 않아 배포 직후 좁은 시간창에 테이블 없음 500 가능성, `initial_capital`/날짜 형식 검증 누락)은 사용자 승인을 받아 추가 수정 커밋으로 반영했다. `@app.on_event("startup")` deprecation 경고(FastAPI가 `lifespan` 방식 권장)는 plan-mandated 발견으로 보고받았지만, 사용자가 "현재대로 수용"으로 결정했다.

`pytest tests/` 608개 전체 통과, PR #52 생성.

---

## ❌ PR #52 후속: preset 경로탈출(Path Traversal) 취약점

사용자가 "PR #52 백테스트 기능 전체적으로 문제 없는지 다시 확인"을 요청해서 관련 파일들을 직접 재검토했다(서브에이전트 위임 없이). 관련 테스트 82건도 재실행해 전부 통과를 확인했다.

재검토 중 **`preset` 입력값 경로탈출 취약점**을 발견했다. PR #52의 최종 리뷰는 "프리셋 경로 traversal 모양이나 실질 위험 없음"으로 판단해 수정 불필요로 종료했는데, 실제로 `preset="../../../settings/app"`을 보내면 `strategy_v1/settings/presets/../../../settings/app.yaml`로 탈출해 `settings/app.yaml`이 그대로 읽혀 `load_config()`에 병합되는 것을 직접 재현했다. **당시 판단이 틀렸던 것으로 정정했다.**

인증(TOTP+비밀번호) 뒤에 있어서 외부 비인증 공격자는 접근할 수 없지만, 인증된 세션 하나로 서버가 읽을 수 있는 임의의 `.yaml` 파일 내용이 백테스트 응답에 노출되는 정보유출 경로였다.

```python
# 수정 전: 존재 여부만 확인
path = Path(presets_dir) / f"{preset}.yaml"
if path.exists(): ...

# 수정 후: 실제 존재하는 프리셋 stem 집합과 정확히 일치하는지 확인
if preset not in _valid_presets():
    raise HTTPException(400)
```

회귀 테스트(`test_path_traversal_preset_returns_400`)를 추가했다. `pytest tests/` 609개 전체 통과. 동시성 체크의 TOCTOU 레이스와 백그라운드 스레드의 GIL 점유는 기록만 하고 수정하지 않기로 했다(1인 운영 환경 기준 실질 위험 낮음, 설계 단계에서 받아들인 트레이드오프).

---

## ❌ 백테스트 데이터 다운로드 — 비표준 종목코드 + 무한 페이지네이션

OCI에서 `scripts/download_backtest_data.py --top-n 100`을 실행하던 중 종목코드 `0165X0`에서 `TR=FHKST03010100` 500 오류가 반복 출력되며 멈추지 않아 Ctrl+C로 중단해야 했다.

근본 원인 두 가지:
1. `_get_codes_from_volume_rank()`가 거래량순위 응답의 종목코드를 형식 검증 없이 그대로 사용 — `0165X0`처럼 6자리 숫자가 아닌 코드(ELW/ETN 추정)가 섞여 들어왔고, 개별종목 전용 일봉 엔드포인트는 이런 코드를 지원하지 않아 500을 반복
2. `download_candles()`의 페이지네이션 `while True` 루프에 반복 횟수 상한도, `current_end`가 실제로 과거로 진행하는지 검증하는 안전장치도 없어서 API가 비정상 응답을 주면 멈출 방법이 없었음

- `^\d{6}$` 형식이 아닌 코드는 사전 필터링
- `next_end >= current_end`(과거로 진행하지 않음)면 경고 로그 남기고 즉시 중단 + 종목당 최대 페이지 수 상한(50) 추가

신규 테스트 3건(코드 필터링, 비정상 응답 시 중단, 정상 종료) — 무한 루프를 직접 재현하는 테스트로 회귀를 방지했다. `pytest tests/` 612개 전체 통과.

---

## ❌❌ 모의투자 30거래일 하드캡 — 두 번의 진단, 진짜 원인은 빈 시작일

페이지네이션 무한루프를 고치고 재실행했더니 무한루프는 해결됐지만, 58개 종목 전부가 정확히 "30일치"만 수집되는 새 증상이 나타났다.

**1차 진단**: 모의투자(openapivts) 서버가 `inquire-daily-itemchartprice`에서 `FID_INPUT_DATE_2`를 무시하고 항상 최근 ~30거래일만 반환하는 것으로 추정했다. `get_daily_candles_until()`에 `use_live=True`를 추가해 모의투자 모드에서도 항상 live 엔드포인트로 요청하도록 바꿨다. `pytest tests/` 613개 통과.

**❌ 2차 재현**: 머지 후 OCI에서 재실행했는데도 여전히 58개 종목 전부 정확히 "30일치"만 수집됐다. **live 엔드포인트로 바꿔도 증상이 그대로라는 사실 자체가 1차 진단이 틀렸다는 직접적인 반증**이었다.

재조사 끝에 진짜 원인을 찾았다. 같은 파일의 `get_index_daily_candles()`(지수 일봉)는 항상 실제 계산된 시작일을 `FID_INPUT_DATE_1`에 넘기는데, `get_daily_candles_until()`만 유일하게 `FID_INPUT_DATE_1=""`로 보내고 있었다. 시작일이 비어 있으면 서버가 종료일(`FID_INPUT_DATE_2`)을 무시하고 항상 오늘 기준 최근 데이터만 반환하는 것이었다(모드 무관 — live에서도 동일).

```python
# 수정 전
FID_INPUT_DATE_1=""   # 비워두면 서버가 종료일을 무시함

# 수정 후
start_date = end_date - timedelta(days=200)
FID_INPUT_DATE_1=start_date.strftime("%Y%m%d")
```

`use_live=True`는 그대로 유지했다(공개 시세성 조회 모드 무관 원칙 자체는 유효하고, 모의투자 쪽 간헐적 500 회피에도 도움이 됨). 회귀 테스트로 `FID_INPUT_DATE_1`이 비거나 종료일보다 크지 않은지 검증하는 케이스를 추가했다. `pytest tests/` 614개 전체 통과. PR 머지 후 OCI 재실행에서 58개 종목 전부 "585일치"(2024-01-01~2026-05-31) 정상 수집을 확인했다.

---

## 부수 작업: work-end 절차에 동기화 단계 추가

같은 날 PR #53/#54/#55를 연달아 올리면서 매번 `work-log.md`/`next-tasks.md`에서 충돌이 반복됐다. squash 머지 방식 특성상 머지될 때마다 새 커밋 해시가 생기는데, `feature/build`를 그 위에 갱신하지 않고 다음 PR을 올리면 git이 공통 조상을 옛 시점으로 보고 충돌을 띄우는 것이었다. `CLAUDE.md`와 `work-end` skill에 "PR 머지 확인 후 반드시 `git fetch origin master && git merge origin/master`로 `feature/build` 동기화" 단계를 추가했다.

---

## 정리

| 작업 | 내용 |
|------|------|
| 웹 백테스트 구현 | `/backtest` 실행 폼 + 결과 상세 페이지, 동시 1건 제한 (PR #52) |
| 경로탈출 수정 | preset 입력값 allow-list 검증으로 정보유출 경로 차단 |
| 다운로드 버그 1 | 비표준 종목코드 미필터링 + 무한 페이지네이션 → 형식 검증 + 상한 추가 |
| 다운로드 버그 2 | 30일 하드캡 — live 전환으로는 해결 안 됨 → 빈 `FID_INPUT_DATE_1`이 진짜 원인 |
| 테스트 | `pytest tests/` 614개 전체 통과 |

같은 증상(30일치만 수집)에 대해 첫 번째 가설(모의투자 서버 제약)로 고쳤는데도 증상이 그대로였던 게 오히려 중요한 신호였다 — "고쳤는데 안 됐다"는 사실 자체가 가설이 틀렸다는 증거였고, 거기서 다시 출발해야 진짜 원인을 찾을 수 있었다.

다음 글에서는 6/22에 벌어진 **매수 무한반복 사고** — 체결판단을 holdings-diff 방식으로 전환하게 된 계기를 다룬다.
