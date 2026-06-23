---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (19) — 전략확인 페이지 신설, Mermaid 렌더링 버그 2건
date: 2026-06-15 20:00:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code
author: Evan
description: v1/v2 전략의 매수·매도 흐름을 Mermaid 플로우차트로 보여주는 전략확인 페이지를 신설했다. 이어서 OCI 실행 중 발견한 모의투자 API 500 오류와, 비교연산자 때문에 다이어그램이 깨지던 렌더링 버그 두 건을 같은 날 바로 수정한 과정을 기록한다.
---

**작성일**: 2026년 6월 15일  
**최종 수정**: 2026년 6월 15일  
**분야**: AI Trading, Development  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/extra-account-capital-and-release-notes-skill/)에서 추가 계좌 투자원금 입력 기능을 마쳤다. 이어서 같은 날, 웹 대시보드에 **전략확인 페이지**를 새로 만들고 바로 OCI에서 검증하면서 버그 두 건을 추가로 잡았다.

결론부터 말하면, v1/v2 전략의 매수·매도 흐름을 Mermaid 플로우차트로 시각화하는 `/strategy` 페이지를 신설했다. 그런데 만들어놓고 보니 모의투자 서버가 특정 API를 지원하지 않아 pre-market 실행이 지연되는 문제와, 다이어그램에 들어간 비교연산자(`<=`, `>=` 등)가 HTML 태그로 잘못 해석돼 렌더링이 깨지는 문제가 차례로 발견됐다. 둘 다 같은 날 바로 수정했다.

---

## 전략확인 메뉴 & 전략별 Trading Flow Chart 페이지

전략 버전(v1/v2)별로 매수/매도 로직이 점점 복잡해지면서, 설정값을 코드로만 확인하기 어려워졌다. 그래서 실제 YAML 설정값을 읽어 Mermaid 플로우차트로 그려주는 페이지를 새로 만들었다.

- `web/strategy_flow.py` 신규: `build_v1_buy_flow`/`build_v1_sell_flow`/`build_v2_buy_flow`/`build_v2_sell_flow` — 각 전략의 실제 YAML 설정값(가중치, threshold, hold_days 등)을 읽어 Mermaid 노드 라벨에 동적으로 삽입. 설정 파일이 없거나 파싱 오류가 나도 예외를 전파하지 않고 경고 로그 + `"?"` 폴백값으로 표시
- `web/templates/strategy.html` 신규: Alpine.js 탭(v1/v2 버전 × 매수/매도) + 현재 운용 중인 버전과 일치하는 탭에 "● 운용 중" 배지 + 범례
- `web/routers/pages.py`: `/strategy` 라우트 추가, 4개 빌더 함수 결과를 템플릿 컨텍스트로 전달
- `web/templates/layout.html`: 사이드바에 "전략확인" 메뉴(스크리닝↔보유 현황 사이) + Mermaid.js CDN(`mermaid@10`) 추가

설계(`docs/superpowers/specs/2026-06-15-strategy-flow-page-design.md`) → 계획(`docs/superpowers/plans/2026-06-15-strategy-flow-page.md`)을 거쳐 구현했다. 신규 테스트는 `tests/test_strategy_flow.py`(7개) + `tests/test_web_pages.py`(1개) — 동적 값 삽입과 설정 누락 시 폴백을 검증. `pytest tests/` 425개 전체 통과.

로컬은 TOTP 미설정이라 실제 브라우저 렌더링은 확인하지 못했고, 라우트 함수를 직접 호출해 4개 다이어그램과 핵심 라벨이 만들어지는 것만 검증했다.

---

## ❌ 버그: get_stock_sector — 모의투자에서 CTPF1002R이 항상 500

전략확인 페이지를 만든 김에 OCI에서 strategy_v2 `--pre-market`(paper 모드)을 실행해봤는데, 종목기본정보 조회(`CTPF1002R`)가 모의투자(VTS) 서버에서 매번 `500 Internal Server Error`를 반환하고 있었다. `cache_manager.build()`가 universe 40종목마다 3회씩 재시도(약 12초)를 거치면서 pre-market 실행이 수분씩 지연되고 있었다.

`get_stock_sector()`로 조회하는 업종명은 계정과 무관한 공개 시세성 정보다. 그래서 paper 모드에서도 **live 베이스URL/앱키/토큰으로 요청**하도록 바꿨다.

- `api/kis_api.py`: `_get_token`/`_build_headers`/`_request`에 `use_live` 옵션 추가, `get_stock_sector()`는 `use_live=True`로 호출
- `utils/config_loader.py`: 모드와 무관하게 `config["secrets_live"]`(`KIS_LIVE_APP_KEY`/`SECRET`, 누락 시 빈 문자열)와 `config["paths"]["token_cache_live"]`(`data/token_cache_live.json`)를 항상 주입
- live 앱키가 없는 환경에서는 API 호출 없이 즉시 `""` 반환 — 불필요한 재시도 방지

단순히 paper 모드에서 호출을 스킵하는 방식은 택하지 않았다. `first_stage_groups.py`의 섹터 중복 필터(`sector_max_count`)는 모든 후보가 `"unknown"`이면 사실상 상위 N종목만 통과시켜버려 그룹 스크리닝 자체를 무력화하기 때문이다. live 라우팅으로 실제 업종명을 받아오는 쪽으로 해결했다.

`pytest tests/` 426개 전체 통과(회귀 없음).

---

## ❌ 버그: Mermaid 비교연산자가 HTML 태그로 오해석됨

전략확인 페이지를 OCI에서 열어보니 v1 매수/매도, v2 매도 플로우차트가 "Syntax error in text mermaid version 10.9.6"으로 렌더링 실패했다. v2 매수만 정상이었다.

원인은 `web/strategy_flow.py`의 노드 라벨 문자열에 들어간 `<=`/`>=`/`<`/`>` 비교 연산자였다. Mermaid 10.x가 이걸 HTML 태그 시작으로 잘못 해석한 것이다. v2 매수 흐름만 비교 연산자가 없어서 우연히 정상 렌더링됐던 것과 정확히 일치했다.

- `<=` → `&le;`, `>=` → `&ge;`, `<` → `&lt;`, `>` → `&gt;` HTML 엔티티로 치환
- `build_v1_buy_flow`/`build_v1_sell_flow`/`build_v2_sell_flow`의 손절·목표수익·보유기간·VKOSPI 임계값·전략별 매도 트리거 라벨에 적용
- `tests/test_strategy_flow.py`의 `VKOSPI>=50` 단언도 `VKOSPI&ge;50`으로 갱신

`pytest tests/` 426개 전체 통과. OCI/브라우저에서 v1 매수·매도, v2 매도 다이어그램이 정상 렌더링되는지는 다음 확인이 필요한 항목으로 남겨뒀다.

---

## 정리

| 작업 | 내용 |
|------|------|
| 전략확인 페이지 | `/strategy` 신설 — v1/v2 매수·매도 흐름을 YAML 설정값 기반 Mermaid로 시각화 |
| 버그 1 | 모의투자에서 `CTPF1002R`(종목기본정보) 500 → 공개 정보이므로 live 엔드포인트로 라우팅 |
| 버그 2 | 비교연산자가 Mermaid에서 HTML 태그로 오해석 → HTML 엔티티로 치환 |
| 테스트 | `pytest tests/` 426개 전체 통과 |

새 페이지를 만들자마자 실제 운영 환경(OCI)에서 두 가지 문제가 동시에 드러난 셈인데, 둘 다 "로컬 mock 테스트만으로는 보이지 않는" 종류의 버그였다. 모의투자 서버의 API 지원 범위, 그리고 외부 라이브러리(Mermaid)의 문자열 해석 방식 — 둘 다 실제 환경에서 실행해봐야 드러나는 디테일이었다.

다음 글에서는 그 다음 날(6/16) 진행한 **pre-market API 최적화와 주문 체결 검증 개선(PR #29)**을 다룬다.
