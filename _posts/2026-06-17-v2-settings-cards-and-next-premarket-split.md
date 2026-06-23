---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (21) — 매매설정 v2 카드 확장(3·4단계), next-pre-market 분리
date: 2026-06-17 21:00:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code
author: Evan
description: 거래량순위 API가 장 개시 전엔 빈 응답을 준다는 걸 발견해 pre-market 캐시 빌드를 18:00 next-pre-market으로 분리했다. 이어서 매매설정 탭에 v2 전용 카드 4종과 캐시 매니저·계좌 관리 페이지를 추가한 6월 17일 작업을 정리한다.
---

**작성일**: 2026년 6월 17일  
**최종 수정**: 2026년 6월 17일  
**분야**: AI Trading, Development  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/premarket-optimization-and-order-fill-pr29/)에서 pre-market 성능 최적화와 주문 체결 검증을 개선했다. 6월 17일은 그 pre-market 캐시 자체에 구조적 문제가 있다는 걸 발견하면서 시작됐고, 이어서 매매설정 탭에 v2 전용 카드들을 채워나갔다.

결론부터 말하면, `--pre-market`(07:00)이 만드는 거래량순위 캐시가 장 개시 전엔 KIS API가 빈 응답만 줘서 항상 텅 비어 있었다. 캐시 생성 단계를 18:00 실행되는 `--next-pre-market`으로 분리해 해결했다. 이어서 매매설정 탭에 v2 전용 카드 4종(동적손절/일일재평가/공포필터/전략별매도)과 캐시 매니저 카드, 계좌 관리 페이지(`/accounts`)를 추가했다.

---

## ❌ 문제: pre-market 거래량순위 캐시가 항상 비어 있음

`logs/cron_pre.log`를 분석하다가 07:00 pre-market 로그에서 `지수 일봉 캐시 초기 구축 ✓`, `daily_reeval 완료 ✓`는 정상인데 거래량순위(volume-rank) KOSPI/KOSDAQ 응답이 둘 다 **84바이트(빈 응답)**라서 `universe=0종목`으로 떨어지는 걸 발견했다.

원인은 단순했다. KIS API는 **장 개시(09:00) 전에는 거래량순위 데이터를 제공하지 않는다.** 07:00에 캐시를 만들려는 시도 자체가 구조적으로 성립하지 않았던 것이다.

### 수정: --next-pre-market 신설

- `runner.py`: `--next-pre-market` 플래그 추가 — 18:00 실행 전용 블록
  - v2 전용(`active_strategy_version != v2`면 스킵)
  - live API 우선 사용(`secrets_live` 키가 있으면), 없으면 폴백
  - `build_cache()` + `save_cache()` 실행 후 종료
- `--pre-market`(07:00): `build_cache`/`save_cache` 제거 — 지수 캐시 + `daily_reeval`만 수행

전날 밤 만들어둔 캐시를 다음날 아침에 그대로 쓰는 구조로 바꾼 것이다.

---

## ❌ 부수 발견: 전략확인 페이지 Mermaid 다이어그램이 가끔 깨짐

같은 날 전략확인 페이지를 다시 들여다보니 Mermaid 렌더링이 또 불안정했다. 원인은 Alpine.js(`defer`)가 `DOMContentLoaded` 전에 `x-show`로 패널을 숨기는데, Mermaid의 `startOnLoad`(같은 `DOMContentLoaded` 핸들러)가 숨겨진 요소를 렌더링하려고 시도하면서 "Syntax error in text"를 내는 것이었다.

- `strategy.html`: `startOnLoad: false`로 바꾸고 `renderMermaid()` 함수를 Alpine `init()` 훅에서 직접 호출
- `$watch('version'/'tab', () => $nextTick(renderMermaid))` — 탭을 전환할 때마다 현재 보이는 다이어그램만 다시 렌더링
- v2 매도 흐름 다이어그램의 이중 엣지·쉼표 포함 라벨·중첩 다이아몬드 구조도 함께 정리

`pytest tests/` 429개 전체 통과.

---

## 매매설정 탭 3단계: v2 전용 카드 4종 + API 8개

매매설정 페이지에 v2 전용 설정 카드를 4종 추가했다.

- `web/routers/config_router.py`: `_write_inline_dict_field(path, line_key, field, value)` 신규 헬퍼 — `key: { field: val, ... }` 형태의 인라인 dict YAML 줄에서 특정 필드만 교체(주석·다른 필드는 보존)
- Pydantic 모델 8종, GET+PATCH 엔드포인트 4쌍(v2 전용, v1 요청 시 404):
  - `/api/config/dynamic-stop` — 전략별 기본 손절폭, ATR/국면 배율
  - `/api/config/daily-reeval` — hysteresis_threshold, min_score, no_strategy_max_cycles
  - `/api/config/fear-filter` — 6개 국면 인라인 dict + crisis_rising_rule
  - `/api/config/strategy-sell` — 5개 전략 인라인 dict + opportunity_cost_stop
- `settings.html`에 카드 4종 + 각각의 init/save 메서드 추가

`tests/test_config_router_v2.py`에 신규 21개 케이스(v1 404, v2 정상 반환, 입력 검증 400, `_write_inline_dict_field` 단위 테스트) 추가. `pytest tests/` 450개 전체 통과.

## 매매설정 탭 4단계: 캐시 매니저 카드 + 계좌 관리 페이지

- `config_router.py`: `CacheManagerUpdate` Pydantic 모델, `GET/PATCH /api/config/cache-manager`(v2 전용, `expiry_hours`/`universe_size`/`universe_size_mock` 검증 후 갱신), `GET /api/config/accounts`(전체 계좌, `cano` 앞 4자리+`****` 마스킹)
- `web/templates/accounts.html` 신규 — 요약 카드(전체/봇운용/조회전용 계수) + 계좌 테이블(account_id, 레이블, 마스킹된 계좌번호, mode/managed_by 배지, 활성 여부, 갱신일시) + 빈 상태 안내
- `layout.html` 사이드바에 "계좌 관리"(`/accounts`) 링크 추가

`tests/test_config_router_v2.py`에 9개 추가(캐시 매니저 7개 + 계좌 목록 2개) → 총 30개, `pytest tests/` 459개 전체 통과.

---

## OCI 운영 검증 + next-tasks 정리

마지막으로 OCI에서 실제 동작을 확인했다.

- `--pre-market` 정상 동작 확인(KOSPI BULL, daily_reeval 6종목, API 8회)
- `/strategy` 페이지 Mermaid 다이어그램 4종 브라우저 렌더링 이상 없음
- 설정 페이지 전략 드롭다운이 현재 선택값을 표시하지 않던 문제 수정
- `active_strategy_version=v2`, `preset=neutral`, `mode=paper`가 의도한 대로 유지되고 있음을 확인
- `--reconcile` cron(15:40) 등록 확인, `--next-pre-market` cron(18:00) 경로 수정(`/path/to/bot` → 실제 경로, `python` → `python3`)

`next-tasks.md`에서 완료된 항목을 모두 제거하고, 신규 작업 5개(스크리닝 로그 정리, cron·trader 로그 역할 분리, docs 정리, 추가 계좌 수익률 분석, 대시보드 재구성)를 새로 기록했다.

---

## 정리

| 작업 | 내용 |
|------|------|
| pre-market 캐시 버그 | 거래량순위가 장 개시 전엔 빈 응답 → 캐시 빌드를 18:00 `--next-pre-market`으로 이전 |
| Mermaid 렌더링 | Alpine `x-show` + `startOnLoad` 충돌 → 수동 렌더링 트리거로 전환 |
| 매매설정 v2 카드 | 동적손절/일일재평가/공포필터/전략별매도 4종 + 캐시 매니저 카드 |
| 계좌 관리 페이지 | `/accounts` 신규 — 전체 계좌 마스킹 목록 |
| 테스트 | `pytest tests/` 459개 전체 통과 |

다음 글에서는 6/18에 진행한 **거래량순위 페이지네이션 추적기** — tr_cont 헤더 버그부터 universe 60 확정까지 이어진 일련의 수정을 다룬다.
