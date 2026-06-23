---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (22) — 거래량순위 페이지네이션 추적기, universe 60 확정까지
date: 2026-06-18 11:00:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code
author: Evan
description: 거래량순위 조회가 1페이지(30건)만 받고 멈추는 문제를 페이지네이션 구현, 응답 헤더 대소문자 버그 수정까지 두 번 고친 끝에 결국 KIS API 자체의 시장당 30건 하드 리밋이라는 결론에 도달해 universe 목표치를 60으로 재조정한 과정을 정리한다.
---

**작성일**: 2026년 6월 18일  
**최종 수정**: 2026년 6월 18일  
**분야**: AI Trading, Development  
**난이도**: Advanced  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/v2-settings-cards-and-next-premarket-split/)에서 pre-market 캐시를 18:00으로 분리하고 매매설정 v2 카드를 채워나갔다. 6월 18일은 그 캐시가 채우는 **거래량순위(universe) 후보군이 목표치에 한참 못 미치는 문제**를 추적하면서 시작됐는데, 한 번 고쳤다고 끝나지 않고 세 단계를 거쳤다.

결론부터 말하면, 처음엔 "페이지네이션을 안 구현해서"인 줄 알고 구현했는데 여전히 1페이지(30건)에서 멈췄다. 알고 보니 응답 헤더의 대소문자 처리 버그였고, 그것도 고치고 나니 진짜 원인이 드러났다 — **KIS 거래량순위 API 자체가 시장당 정확히 30건으로 하드 리밋이 걸려 있었다.** 결국 API 한도에 맞춰 universe 목표치를 60(KOSPI+KOSDAQ 30씩)으로 재조정해야 했다.

---

## 1차 시도: tr_cont 페이지네이션 구현

`cron_next_pre.log`를 분석해보니 `universe=40종목(요청=2000)`으로, 1차 스크리닝 4그룹이 필요로 하는 160종목에 한참 못 미치고 있었다.

원인으로 보인 것:
- KIS 거래량순위(`FHPST01710000`) 응답의 `tr_cont` 연속조회 헤더를 전혀 처리하지 않아 1페이지만 받고 끝남
- `FID_VOL_CNT`를 "건수"로 오용
- `get_stock_list()`에 인위적인 40건 캡이 남아있음

```python
# api/kis_api.py
# _build_headers에 tr_cont 추가, _request를 _request_full(헤더 포함 반환)로 분리
# _get_volume_rank에 tr_cont 연속조회 루프 구현
```

- `api/api_constants.py`: `MAX_VOLUME_RANK_COUNT` 제거, `VOLUME_RANK_MAX_PAGES(10)` 추가
- `universe_size`/`universe_size_mock`: 2000/500 → 160(4그룹 top_n 합)
- `max_calls_per_run`: 200 → 400
- `tests/test_kis_api_volume_rank.py` 신규 6개, `pytest tests/` 465개 전체 통과

## 부수 작업: cron.log/trader.log 중복 제거

같은 날 로그를 더 깔끔하게 보기 위해 로깅도 정리했다.

- `runner.py`의 떠돌이 `logging.basicConfig()` 호출이 `setup_logging()`과 함께 루트 로거에 핸들러를 중복 부착해, `cron.log`에 모든 메시지가 포맷만 다르게 두 번씩 찍히던 버그 수정
- `utils/logger.py`에 `_TradingLogFilter` 추가 — `trader.log`는 매매/스크리닝 로거(`trading.order_manager`, `strategy_v1/v2.trading`, `strategy_v1/v2.screening`, `strategy_v2.daily_reeval`)만 남기도록 축소. `cron.log`는 필터 없이 그대로 유지
- `tests/test_logger.py` 신규 10개, `pytest tests/` 475개 전체 통과

---

## ❌ 2차 시도: 여전히 1페이지에서 멈춤 — 응답 헤더 대소문자 버그

PR #32 머지 후 OCI에서 다시 실행해보니 `universe=60(요청=160)`으로, KOSPI/KOSDAQ 각각 딱 한 페이지(30건)에서 멈췄다.

원인은 `_request_full()`이 `requests.Response.headers`(대소문자 무관 `CaseInsensitiveDict`)를 `dict()`로 변환하는 순간 그 보장이 사라지는 것이었다. `_get_volume_rank()`는 `headers.get("tr_cont")`로 소문자 키만 조회하는데, 서버가 다른 대소문자로 응답하면 항상 `None`을 받아 다음 페이지가 있어도 즉시 루프를 끝내버렸다.

```python
# 수정 전
headers = dict(resp.headers)
# 수정 후
headers = {k.lower(): v for k, v in resp.headers.items()}
```

기존 테스트 6개의 mock 응답 헤더 키를 `"Tr_cont"`(대소문자 혼합)로 바꿔서 이 버그를 재현했다 — 수정 전 코드로는 실패, 수정 후엔 통과하는 것을 직접 확인했다. `pytest tests/` 475개 전체 통과.

---

## ❌ 진짜 원인: KIS 거래량순위 API 자체가 시장당 30건 하드 리밋

헤더 버그까지 고쳤는데도 OCI 실측에서 `output=30`, `tr_cont=''`(연속조회 불가)이 똑같이 재현됐다. 헤더 대소문자, 공식 샘플 파라미터 정렬 두 가설을 각각 적용해 재실행했지만 둘 다 기각됐다 — 결국 **API 자체의 하드 리밋**이라는 결론에 도달했다.

목표치를 API 한도에 맞춰 재조정했다.

- `strategy_v2/settings/screen_config/first_stage_groups.yaml`: 4그룹 `top_n` 40 → 15(합계 60)
- `strategy_v2/settings/cache_manager.yaml`: `universe_size`/`universe_size_mock` 160 → 60
- `web/routers/config_router.py`, `web/templates/settings.html`: `universe_size` 검증 하한 100/50 → 10/10

이 과정에서 부수적인 사고도 하나 있었다. `tests/test_config_router_v2.py`의 PATCH 테스트가 실제 `strategy_v2/settings/*.yaml` 파일을 모킹 없이 직접 수정하고 있었는데, 검증 하한을 바꾸는 작업 중 경계값 테스트(`universe_size=99`)가 우연히 새 범위에서 "유효한 값"이 되어버려 `cache_manager.yaml`을 `99/49`로 덮어써버렸다. 수동으로 복구하고, 근본 수정(테스트가 `tmp_path` 등으로 파일 경로를 모킹해야 한다는 것)은 `next-tasks.md`에 기록해뒀다.

`pytest tests/` 전체 475개 통과.

---

## ✅ OCI 검증 완료: universe=60 정확히 채워짐

PR #34 머지 후 OCI에서 `python3 runner.py --next-pre-market`을 재실행한 결과:

```
캐시 생성 시작 | universe=60종목 (요청=60)
캐시 생성 완료 | avg_volume=60종목 | rsi=59종목 | foreign_cumulative=0종목 | sector_top40=40종목
```

"universe 크기 부족" 경고가 더 이상 발생하지 않고, 요청한 60건이 정확히 채워지는 것을 확인했다.

---

## 정리

| 단계 | 가설 | 결과 |
|------|------|------|
| 1차 | tr_cont 페이지네이션 미구현 | 구현했으나 여전히 1페이지(30건)에서 멈춤 |
| 2차 | 응답 헤더 대소문자 처리 누락 | 수정했으나 동일 증상 재현 |
| 3차 | KIS API 자체의 시장당 30건 하드 리밋 | 확정 — universe 목표를 160 → 60으로 재조정 |
| 검증 | OCI `--next-pre-market` 재실행 | universe=60 정확히 충족 확인 |

세 단계를 거치면서 매번 "이번엔 진짜 원인이겠지" 했는데, 두 번은 실제로 존재하는 별개의 버그였고 세 번째가 진짜 근본 원인이었다. 페이지네이션 구현과 헤더 대소문자 수정 둘 다 무의미한 작업은 아니었던 셈이다 — 둘 다 고치고 나서야 "이래도 안 되네"라는 확신을 갖고 API 한도라는 결론에 도달할 수 있었다.

다음 글에서는 같은 날 이어서 진행한 **foreign_cumulative(외국인·기관 수급) 실구현**과 **strategy_v2 매수 흐름의 풀링 매수 전환**을 다룬다.
