---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (30) — 매수 무한반복 사고, 체결판단 holdings-diff 전환
date: 2026-06-22 20:00:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code
author: Evan
description: 같은 종목 매수 주문이 15분마다 반복 시도되는 로그를 발견했다. 추적해보니 실제로는 매번 체결되고 있었는데 KIS 모의투자 체결조회 API 한계로 봇이 이를 인지하지 못해 234주가 통제 밖에 쌓여 있었다. 체결판단을 holdings-diff 방식으로 전환하고 같은 날 발견한 extra_05 계좌 버그까지 잡은 과정을 기록한다.
---

**작성일**: 2026년 6월 22일  
**최종 수정**: 2026년 6월 22일  
**분야**: AI Trading, Development  
**난이도**: Advanced  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/web-backtest-implementation-and-bugfixes/)에서 웹 백테스트 기능을 완성하고 30거래일 하드캡의 진짜 원인을 찾았다. 6월 22일은 가벼운 절차 수정과 기능 추가로 시작했지만, 후반에 `logs/trader.log`를 들여다보다가 그 무엇보다 심각한 사고를 발견했다.

결론부터 말하면, SK네트웍스 9주 매수 주문이 09:00~15:30 동안 15분마다 26번 반복 시도되고 있었다. 실제 KIS 모의투자 계좌를 직접 조회해보니 매번 정상 체결되어 **234주가 이미 쌓여 있었다** — 봇 자신의 `holdings.json`만 이걸 전혀 모르고 있었다. 체결판단 로직을 holdings-diff 방식으로 전면 교체하고, 비슷한 시기에 보고된 또 다른 계좌 버그까지 같은 날 잡았다.

---

## work-start 절차의 git rebase를 merge로 변경

작업을 시작하면서 `/work-start`의 `git rebase master`가 `work-log.md`/`next-tasks.md`에서 충돌을 일으켰다. 확인해보니 `feature/build`가 이미 머지 커밋으로 master를 흡수한 상태였는데, rebase가 squash 머지로 이미 흡수된 `feature/build`의 개별 커밋들을 재생하려다 충돌이 난 것이었다. 사실 6/21에 `work-end` 절차는 같은 원인으로 이미 rebase→merge로 수정해뒀는데, `work-start`만 누락돼 있었다. 두 skill을 동일하게 merge 방식으로 맞췄다.

---

## 웹 백테스트 데이터 다운로드 기능 추가 (8-Task)

직전(PR #52)에서 웹 백테스트 실행 기능을 실사용하면서, 백테스트용 CSV 데이터(`data/backtest/*.csv`)를 받는 과정이 여전히 `scripts/download_backtest_data.py` CLI 전용이라는 한계가 보였다. 이것도 웹에서 받을 수 있게 했다.

핵심 설계 결정 네 가지:

1. `backtest/data_downloader.py` 신규 모듈에 다운로드 로직을 모아 CLI와 웹이 공용으로 사용(`download_backtest_data.py`는 272줄 → thin wrapper로 축소)
2. **증분(gap-fill) 다운로드** — 종목별 CSV에 이미 데이터가 있으면 보유 범위 밖(과거+미래 양방향)만 API로 받고, 요청 범위가 이미 전부 있으면 해당 종목은 API 호출 없이 건너뜀
3. **장중 실행 경고는 active mode가 live일 때만 표시** — `get_daily_candles_until()`이 모드 무관 항상 live APP KEY를 쓰는데, active mode가 live면 토큰 캐시 파일을 다운로드와 정확히 공유해 실거래 cron과 레이트리밋이 경쟁한다는 걸 코드로 직접 확인 후 사용자의 최초 가정(반대 방향)을 정정했다
4. 데이터 다운로드 동시 1건 제한은 백테스트 실행 동시 1건 제한과 **독립**(별도 테이블 `data_download_runs`, 별도 폴링 엔드포인트)

`data_download_runs` 테이블 + CRUD 6함수, `POST/GET /api/backtest/data-download/*`, `/backtest/data/{run_id}` 상세 페이지를 추가했다. `pytest tests/` 653개 전체 통과, 최종 리뷰 Critical/Important 0건.

---

## 현상: 같은 종목이 15분마다 반복 매수된다

`logs/trader.log`를 직접 확인하다가 같은 종목 매수가 계속 시도되는 줄을 발견했다.

- SK네트웍스(001740) 9주 매수 주문이 매 15분 cron마다 새로 접수됨
- 다음 cron 사이클에는 항상 "주문 취소/거부 확인"으로 처리되어 `holdings.json`에 반영되지 않음
- 이 패턴이 하루 종일(09:00~15:30) 26회 반복

systematic-debugging으로 KIS 모의투자 계좌를 직접(읽기 전용) 조회해보니 결과가 정반대였다.

- 실제 계좌에는 SK네트웍스 **234주**(9주 × 26회) 보유 중
- 즉 매수는 매번 실제로 체결되고 있었는데, 봇이 전혀 인지하지 못한 것

## ❌ 원인: KIS 모의투자 체결조회 API가 작동하지 않는다

기존 체결판단 함수 `check_order_status()`는 두 가지 KIS API에 의존하고 있었다.

- 미체결조회(`VTTC8036R`) → 모의투자 계좌에서 "해당기능 미지원" 에러
- 당일체결내역(`VTTC8001R`) → 주문번호(ODNO)로 특정해도 항상 "조회조건에 일치하는 자료 없음" 반환

두 조회가 모두 실패하면 기존 로직은 "거래소 취소"로 간주하도록 설계되어 있었다. 그래서 실제로는 체결된 주문도 매번 CANCELLED로 오판했고, 매수 로직은 "아직 보유 안 함"으로 잘못 인식해 무한 재매수를 반복했다.

> 바로 전날(6/21) 발견했던 holdings.json 불일치를 "모의투자 계좌의 주기적 리셋"으로 추정하고 넘어갔는데, 이번에 거의 같은 모양의 불일치가 다시 나타나면서 그 추정이 틀렸다는 게 드러났다. 진짜 원인은 체결조회 API 자체였다.

---

## ✅ 수정: 체결판단을 holdings-diff 방식으로 전환

KIS의 미체결조회/당일체결내역 API에 더 이상 의존하지 않기로 했다. 대신 주문 접수 시점에 캡처한 보유수량과, 다음 cron 시점의 실시간 보유수량을 비교(diff)해서 체결 수량을 판단하는 방식으로 바꿨다.

- 매수/매도 주문 접수 시 `get_balance()`로 조회한 **주문 전 실제 보유수량**(`qty_before`)을 함께 기록
- 다음 cron에서 같은 종목의 실제 보유수량과 `qty_before`를 비교해 체결 수량 산출(live/paper 공통)
- "거래소가 취소했다"는 판단은 더 이상 하지 않음 — 타임아웃 후 우리가 직접 `cancel_order()`를 호출했을 때만 CANCELLED로 처리
- 부분체결로 수량이 남으면 같은 주문번호로 재등록해 계속 추적, 동일 종목에 pending 주문이 여러 건이면 오래된 주문부터 우선 배분
- 더 이상 쓰지 않는 `check_order_status()`/`FillStatus`는 제거

```python
# 기존: KIS 체결조회 API 응답에 의존
status = check_order_status(order_id)  # 모의투자에서 항상 신뢰 불가

# 변경: 보유수량 diff로 직접 판단
qty_filled = current_qty - qty_before
```

설계 과정에서 부분체결 시 잔여 수량을 재등록하는 동작과, 컨트롤러가 작성한 초안 코드가 서로 모순되는 부분을 implementer 서브에이전트가 정확히 짚어내 BLOCKED로 보고했고, 계획을 바로 수정한 뒤 다시 진행했다. 최종 리뷰에서는 부분체결 재등록 시 주문 시각(`ordered_at`)을 갱신하지 않는 게 "조용한 버그"처럼 보일 수 있다는 지적이 나왔는데, 취소 대기시간(14분)이 cron 주기(15분)보다 짧아 갱신 여부와 무관하게 동일 cron 사이클에 취소가 트리거된다는 걸 산술로 확인하고 의도를 주석으로 남겼다.

`pytest tests/` 657개 전체 통과. 실제 계좌에 남아있는 SK네트웍스 234주를 `holdings.json`에 동기화하는 작업은 이번 범위에서 제외했다 — 그 이야기는 다음 글에서 이어진다.

---

## extra_05 웹 500 + position_registry 재매수 sold 고착 버그

같은 날, 계좌 관리 메뉴에서 extra_05(일반개인연금) 보유종목 조회 시 Internal Server Error가 난다는 별도 보고가 들어와 추적했다.

**버그 1**: extra_02(IRP)와 extra_05가 `.env`상 APP_KEY/SECRET/계좌번호가 완전히 동일한데(같은 KIS 계좌의 상품코드만 다름), `build_extra_api_client()`가 토큰 캐시를 `account_id` 기준으로 분리해 같은 APP_KEY로 하루 두 번 토큰을 발급받으려다 KIS 403("1일 1회 한도 초과")을 맞고 있었다. `TokenBlockedError`가 의도적으로 `BaseException`을 상속하고 있어 곳곳의 `except Exception`을 통과해버려 웹 페이지에서도 안 잡혀 500이 났다 — 게다가 조회 전용 계좌 문제로 "오늘 자동매매가 중단됩니다"라는 텔레그램 오탐 알림까지 발송되고 있었다.

- `_token_cache_path_for_app_key()` 추가 — 토큰 캐시 파일명을 `account_id` 대신 APP_KEY 해시 기준으로 만들어 같은 APP_KEY 계좌끼리 토큰을 공유
- 추가계좌 reconcile 루프 + 웹 라우터에 `TokenBlockedError`를 별도로 잡는 except 추가 — 토큰 차단된 계좌는 500 대신 "—" 표시

**버그 2**: 별도 신고("보유 현황엔 모의투자 보유종목이 있는데 계좌 현황엔 없음")를 조사한 결과, `upsert_position_registry()`가 `INSERT OR IGNORE`라서 한 번 팔아 `status='sold'`인 행이 있으면 같은 종목을 다시 사도 INSERT가 무시돼 영구히 'sold'로 남는 버그였다. 추가 계좌엔 6/20에 이미 같은 클래스 버그를 고친 REVIVE 함수가 있었는데, 본계좌/v2 경로엔 대응 함수가 없었다.

- `revive_position_registry()`(v1)/`revive_position_registry_v2()`(v2) 추가
- 매수체결과 본계좌 reconcile에 `status='sold'` 분기를 추가해 revive 호출

사용자가 복사해준 실제 DB로 검증 — 027740(마니커) 종목이 정확히 이 버그로 `holdings.json`엔 148주 보유, DB엔 'sold'로 남아있던 것을 revive 수정으로 복구되는 것을 직접 확인했다. `pytest tests/` 675개 통과(기존 결함 1건은 베이스라인에서도 동일하게 실패함을 확인). PR #59 머지 후 OCI 배포까지 완료했다.

---

## 정리

| 작업 | 내용 |
|------|------|
| work-start 정비 | rebase → merge (work-end와 일관성) |
| 웹 백테스트 데이터 다운로드 | 증분(gap-fill) 다운로드, live 모드 한정 경고 |
| 매수 무한반복 사고 | 체결판단 KIS API → holdings-diff(보유수량 비교) 방식으로 전환 |
| extra_05 버그 | 동일 APP_KEY 토큰 중복발급 500 + position_registry sold 고착 |
| 테스트 | `pytest tests/` 657~675개 통과 |

체결판단 로직을 고쳤다고 해서 이미 쌓여 있던 SK네트웍스 234주가 저절로 사라지지는 않는다. 이 phantom position을 실제로 어떻게 회복시켰는지는 다음 날(6/23) 작업이다.

다음 글에서는 6/23 진행한 **본계좌 실시간 잔고 동기화, v2 백테스트 동적 국면전환, OCI 업데이트 자동화, 1주 예외매수**를 다룬다.
