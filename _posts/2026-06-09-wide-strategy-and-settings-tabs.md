---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (11) — wide 전략 도입과 매매설정 페이지 개편
date: 2026-06-09 20:00:00 +0900
categories: trading development
tags: ai-trading python kis-api
author: Evan
description: 로그 포맷 버그·매도 sector 누락·dead code 등 잔여 버그를 정리하고, 시장필터 차단 임계값을 설정 가능하게 만들었다. 기존보다 진입 기준을 완화한 wide 2차 스크리닝 전략을 추가하고, 매매설정 페이지를 탭으로 나눠 전략·파라미터를 직접 편집할 수 있게 개편한 과정을 기록한다.
---

**작성일**: 2026년 6월 9일  
**최종 수정**: 2026년 6월 9일  
**분야**: AI Trading, Development  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/kospi-index-bugfix/)에서 매매가 전혀 발생하지 않던 KOSPI 지수 조회 버그를 고쳤다. 이번 글부터는 `build-docs/work-log.md`에 남긴 커밋 단위 작업 기록을 기반으로, 하루치 작업을 한 편씩 정리한다.

결론부터 말하면, 6월 9일에는 잔여 버그 4건을 정리하고, 기존 전략보다 진입 기준을 크게 낮춘 **wide 2차 스크리닝 전략**을 새로 추가했다. 그리고 매매설정 페이지를 **메인/매매/서버 설정 3개 탭**으로 나누고, 2차 스크리닝 전략과 시장 필터 임계값을 웹에서 직접 편집할 수 있도록 개편했다.

---

## 잔여 버그 4건 정리

### 로그 포맷 버그 (`%,.2f`)

`screening/market_filter.py`의 `logger.info()`에서 `%,.2f` 포맷을 사용하고 있었는데, Python의 `%` 스타일 로깅은 이 포맷을 지원하지 않아 `ValueError: unsupported format character ','`가 발생하고 있었다.

- `%,.2f` → `%s` + f-string(`f"{value:,.2f}"`) 방식으로 수정 (차단·통과 로그 2곳)
- OCI 서버 `cron.log`에서 반복 출력되던 `--- Logging error ---` 트레이스백 해결

### 매도 체결 시 sector 누락

`trading/sell.py`에서 `add_pending_order()` 호출 시 `sector` 파라미터를 전달하지 않아, 매도 체결 기록의 sector 필드가 항상 공백이었다.

```python
sector=holding.get("sector", "")
```

이 한 줄을 추가해 매도 체결 기록에도 섹터 정보가 남도록 수정했다.

### dead code 정리

`screening/first_stage.py`의 `_is_valid_stock()` 함수가 정의는 되어 있지만 `run_first_stage()` 루프에서는 호출되지 않고, 동일한 로직이 루프 안에 인라인으로 중복 구현되어 있었다.

- 루프 내부의 인라인 필터 로직을 제거하고 `_is_valid_stock()` 호출로 교체
- 로그 메시지를 `통과=%d | 제외=%d` 형태로 단순화

### 초기자금 수동 재설정 기능

[이전 글](/posts/report-gdrive-sync-and-config-toggle/)에서 초기자금을 자동 추적하도록 했는데, 최초 1회만 저장되다 보니 수동으로 재설정할 방법이 없었다. 이를 추가했다.

- `web/routers/config_router.py`: `CapitalUpdate` 모델 + `POST /api/config/capital` 엔드포인트 추가
  - `from_balance: true` 요청 시 `KISApiClient.get_balance()`로 현재 잔고를 자동 조회해 저장
  - `amount` 직접 지정 시 10,000원 이상인지 검증 후 저장
  - 현재 활성 모드(`app.yaml`의 `mode`)에 해당하는 값만 `data/initial_capital.json`에 갱신
- `web/templates/settings.html`: 설정 페이지에 초기자금 카드 추가
  - 현재 초기자금·설정일 표시 (페이지 로드 시 `GET /api/config/capital` 자동 조회)
  - "잔고 자동조회로 재설정" 버튼(confirm → `POST {from_balance: true}`)
  - 직접 입력 필드 + 저장 버튼(confirm → `POST {amount: N}`)

`pytest tests/` 164개 전체 통과를 확인했다.

---

## 시장 필터 매수 차단 임계값 설정화

기존에는 KOSPI가 이동평균선 아래로 떨어지면 즉시 매수를 차단했는데, 약간의 이탈만으로 차단되는 것이 너무 보수적이었다. `block_threshold_pct`라는 임계값을 설정 페이지에서 직접 조정할 수 있도록 만들었다.

- 설정 페이지에 "시장 필터 매수 차단 임계값" 카드 추가 (초기자금 카드 아래)
- 현재값 표시, 숫자 입력(-20 ~ 0, 0.5 단위), 저장 버튼
- 페이지 로드 시 `GET /api/config/market-filter` 자동 조회

---

## wide 2차 스크리닝 전략 추가

기존 `balanced`/`momentum`/`trend_following` 전략은 진입 기준이 비교적 엄격해서, 시장 데이터가 충분히 쌓이지 않은 모의투자 환경에서는 통과 종목이 거의 없었다. 그래서 기준을 크게 완화한 `wide` 전략을 추가했다.

- `min_score = 35` (기존 `balanced = 50` 대비 대폭 완화)
- 모든 조건 임계값 완화
  - RSI 과매도: 30 → 40
  - 거래량 배율: 1.5 → 1.2
  - 볼린저 std: 2.0 → 1.5
  - 스토캐스틱 과매도: 20 → 35
  - CCI 과매도: -100 → -70
  - 모멘텀 기간: 10 → 5일
  - 신고가 기간: 52 → 26주
- 가중치는 `balanced`와 동일하게 유지

API와 설정 페이지도 함께 보강했다.

- `GET /api/config` 응답에 `preset_details` 추가 (프리셋별 손절%, 익절%, 최대종목, 보유기간)
- `GET /api/config/screening-strategy` 신규 — 활성 전략의 조건별 가중치 반환
- 설정 페이지 프리셋 카드에 손절%·익절%·최대종목·보유기간 표시
- "2차 스크리닝 전략" 카드 추가 — 활성 전략명, min_score, 10개 조건 가중치를 막대 그래프로 시각화

---

## 매매설정 페이지 3분할 + 직접 편집

설정 페이지를 **메인 / 매매 / 서버** 3개 탭으로 나눴다.

| 탭 | 내용 |
|------|------|
| 메인 설정 | 실행모드, 초기자금 |
| 매매 설정 | 시장 필터 임계값, 매매 프리셋, 2차 스크리닝 전략 |
| 서버 설정 | Google Drive 동기화, YAML 편집기 |

매매 설정 탭에서는 2차 스크리닝 전략 선택과 조건 파라미터 편집이 가능하다.

- 전략 선택 버튼: `balanced` / `momentum` / `trend_following` / `wide`
- 8개 조건 파라미터 인라인 편집 (RSI 과매도, 거래량 배율, 볼린저 std, 스토캐스틱, CCI, 모멘텀 기간, 신고가 기간 등)
- `POST /api/config/screening-strategy` — 활성 전략 변경
- `PATCH /api/config/screening-strategy/params` — 조건 파라미터 저장 (`yaml.dump` 기반)
- 가중치 막대 그래프는 최대값 기준 비례 계산으로 overflow 방지

아울러 `wide` 전략의 ATR 필터도 함께 완화했다.

- `hard_block_pct: 5.0 → 15.0`
- `soft_block_pct: 3.0 → 8.0`
- `min_score_penalty: 20 → 10`

배경은, 5% 기준으로는 후보로 올라온 24개 종목(삼성전자 포함)이 전부 ATR 필터에 걸려 차단되고 있었기 때문이다.

---

## 2차 스크리닝 탈락 로그 강화 + min_score 추가 완화

- `screening/second_stage.py`: 탈락 로그를 `logger.debug` → `logger.info`로 상향, 탈락 시 상위 3개 조건 점수를 함께 출력 (예: `moving_average=0.85 obv=0.72 volume_surge=0.50`) — 다음 cron부터 종목별 점수를 로그에서 바로 확인 가능
- `wide` 전략 `min_score`를 35 → **25**로 추가 완화 (CHOP 시장 +5 보정 후 실효 기준 30점)
  - 배경: 모의투자 서버의 데이터가 부족(50/203일)해서 시장 국면이 항상 CHOP으로 판정되고, ETF 위주 후보들에서 평균회귀 신호(RSI<40 등)가 거의 발동되지 않아 40점 기준으로는 전 종목이 탈락하고 있었다
- YAML 편집기의 화이트리스트에서 `settings/app.yaml` 제거 — 모드·프리셋·시크릿 등 앱 핵심 설정은 전용 API로만 변경하도록 제한

`pytest tests/` 164개 전체 통과를 확인했다.

---

## 정리

| 작업 | 내용 |
|------|------|
| 버그 수정 4건 | 로그 포맷 / 매도 sector 누락 / dead code / 초기자금 재설정 |
| 시장필터 임계값 | `block_threshold_pct`를 설정 페이지에서 직접 조정 |
| wide 전략 | min_score 35(→25 추가 완화), 8개 조건 임계값 대폭 완화, ATR 완화 |
| 설정 페이지 | 메인/매매/서버 3탭 + 2차 스크리닝 전략·파라미터 편집 UI |
| 로그 개선 | 2차 스크리닝 탈락 시 상위 3개 조건 점수 INFO 로그 |
| 보안 정리 | YAML 편집기에서 `app.yaml` 제거 |

다음 글에서는 거래량 순위 조회(KOSDAQ) 오류와 호가단위 오류 같은 실거래 버그를 수정하고, CLAUDE.md 작업 절차를 다시 정비하는 과정을 다룬다.
