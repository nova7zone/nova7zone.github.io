---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (27) — OCI 운영 인프라 결함 2건, DB 조회 페이지 신설
date: 2026-06-21 10:00:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code
author: Evan
description: IRP 디폴트옵션 표시 버그를 추적하다가 6일째 dead 상태였던 웹 서비스와 외부 접속이 막혀있던 호스트 바인딩 설정, 두 가지 운영 인프라 결함을 발견해 수정했다. DB 조회 전용 페이지 신설과 README 전략 설명 정리까지 6월 21일 전반 작업을 정리한다.
---

**작성일**: 2026년 6월 21일  
**최종 수정**: 2026년 6월 21일  
**분야**: AI Trading, Development  
**난이도**: Advanced  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/account-sync-revive-and-v051-release/)에서 추가계좌 오삭제 버그와 REVIVE 로직을 고치고 v0.5.1을 릴리즈했다. 6월 21일은 단순한 화면 표시 버그를 추적하다가 **6일간 방치돼 있던 서비스 인프라 결함 두 건**을 발견하는 것으로 시작됐다.

결론부터 말하면, IRP 디폴트옵션 값이 안 보인다는 보고를 추적하다가, 사실은 6/13 디렉터리 이동 이후 `kis-web.service`가 옛 경로를 참조하고 있어서 6일째 죽어 있었고, 그동안 수동으로 `nohup uvicorn`을 직접 띄워서 써왔다는 걸 알게 됐다. 호스트 바인딩 문제까지 함께 고친 뒤, DB 조회 전용 페이지를 새로 만들고 README의 전략 설명도 정리했다.

---

## IRP 디폴트옵션 표시 버그 + OCI 운영 인프라 결함 2건 (PR #48, #49)

사용자 보고는 "IRP 계좌 보유종목 페이지에 디폴트옵션 수동 입력값이 안 보인다"였다. systematic-debugging으로 단계별 추적했다.

**1차 원인**: 표시 위치가 도움말 문구 끝에 작은 회색 글씨로 붙어 있어서, 실제로는 정상 렌더링되고 있었는데 사용자가 보지 못하고 지나친 것이었다. `account_holdings.html`에서 입력칸 아래 줄에 굵은 글씨로 분리해 표시하도록 수정했다.

디버깅하는 과정에서 전혀 별개인 운영 인프라 결함 두 건을 더 발견했다.

**결함 1 — kis-web.service가 6일째 dead 상태**: `kis-web.service`가 6/13 디렉터리 이동(`~/kis-auto-trading-bot` → `~/trader/kis-auto-trading-bot`) 이전 경로(`WorkingDirectory`, `EnvironmentFile`, `ExecStart`)를 그대로 참조하고 있었다. 6/14 10:14에 정상 종료됐는데, `Restart=on-failure` 설정 때문에 크래시가 아닌 정상 종료는 자동 재기동이 안 됐다. 이후 6일간 dead 상태였고, `systemctl restart`도 존재하지 않는 경로라 조용히 실패하고 있었다. 그래서 그동안 수동으로 `nohup uvicorn`을 직접 띄워서 써왔던 것이다.

```
[6/13] 디렉터리 이동: ~/kis-auto-trading-bot → ~/trader/kis-auto-trading-bot
[6/14 10:14] kis-web.service 정상 종료 (경로 불일치) → 자동 재기동 안 됨
[6/14~6/20] 6일간 dead 상태, 수동 nohup uvicorn으로 우회 운영
[6/21] kis-web.service + 배포 문서 6개 경로 정정
```

`crontab -l`로 재확인한 실제 운영 경로를 기준으로 `kis-web.service`와 배포 문서 6개(`README.md`, `docs/{INSTALL,BACKTEST_DATA_GUIDE,UPDATE,WEBSERVICE_DEPLOY,OCI_QUICKSTART}.md`)를 모두 정정했다. 6/20 문서 정리 때 README의 cron 경로를 반대 방향(`~/trader` → `~/kis-auto-trading-bot`)으로 잘못 "정정"했던 것도 이번에 함께 바로잡았다.

**결함 2 — 호스트 바인딩이 SSH 터널 전용으로 고정**: 결함 1을 고치고 재기동했는데도 외부 IP 접속이 안 된다는 재보고가 들어왔다. 서비스 파일이 SSH 터널 전용 `--host 127.0.0.1`로 바인딩돼 있어서, 평소 쓰던 외부 IP 직접 접속(OCI 보안그룹 IP 제한 방식)이 막혀 있었다. `--host 0.0.0.0`으로 변경하고, `docs/WEBSERVICE_DEPLOY.md`의 "IP 직접 접근" 섹션에 바인딩 설정 필요성을 안내로 추가했다.

부수적으로, 로컬 origin(`nova7zone`)과 OCI 서버 origin(`Evan-ai-pro`)이 다른 줄 알았는데 GitHub repo rename으로 인한 자동 리다이렉트일 뿐 동일 저장소라는 것도 확인했다. PR #48(`feature/build`→`master`), PR #49 모두 사용자가 직접 머지하고, OCI에서 화면 표시·사이트 접속 모두 최종 확인을 완료했다.

---

## DB 조회 전용 페이지(/db-browser) 신규 구현

`next-tasks.md`에 남아있던 "DB 내용 조회용 웹 페이지" 요청을 구체화했다. brainstorming으로 범위를 확정(7개 테이블 전체, 원본 컬럼 그대로, 50행 페이징, mode 드롭다운 필터, 신규 "DB 조회" 메뉴)한 뒤 설계 → 계획 → 4개 Task로 구현했다.

- `db/repository.py`: `TABLE_LABELS`(7개 테이블 화이트리스트, SQL Injection 방지 겸용), `get_table_columns`/`get_table_row_count`/`get_table_page` 범용 함수 추가 — 정렬은 `created_at`이 있으면 DESC, 없으면(`position_strategy_history`만 해당) `id DESC`
- `web/routers/pages.py`: `GET /db-browser`(테이블 카드 목록 + 행 수), `GET /db-browser/{table_name}`(페이징·mode 필터, 화이트리스트에 없는 테이블명은 404)
- `web/templates/db_browser.html`, `db_browser_table.html` 신규, 사이드바에 "DB 조회" 메뉴 추가

Task별 구현→리뷰 루프가 모두 1회에 통과했고(재작업 없음), 최종 전체 브랜치 리뷰도 Critical/Important 없이 승인됐다("Ready to merge: Yes", Minor 6건만 기록). `pytest tests/` 575개 전체 통과. uvicorn을 기동해 신규 라우트가 기존 페이지와 동일하게 인증 미들웨어에 걸려 `/login`으로 307 리다이렉트되는지(500 없음), 실제 `data/trading.db`로 라우트 함수를 직접 호출해 렌더링이 정상인지 확인했다. TOTP 로그인 후 실제 클릭 확인은 사용자가 직접 필요한 항목으로 남겼다.

---

## README.md v1/v2 전략 설명 축소·정리

"README.md에 매매전략 v1, v2 내용이 정리가 안 된 듯하다"는 보고가 있었다. 실제 코드와 대조해봤지만 README/CLAUDE.md 자체에 사실 오류는 없었다 — 대신 `docs/SETTINGS_REFERENCE.md`, `docs/TRADING_FLOW.md`에 v1+v2 모두 더 상세하고 최신으로 정리된 동일 내용이 이미 있어서, README가 그 내용을 중복 보유하고 있던 게 근본 원인이었다.

사용자 요청대로 "전략 v1/v2는 간단 소개만, 세부 운영은 docs 폴더 문서로" 방향으로 정리했다.

- README.md에 "매매 전략: strategy_v1 / strategy_v2" 섹션 신설(각 버전 4줄 요약 + 관련 문서 링크)
- `market_filter`/`first_stage`/`second_stage` 설정 섹션 전체 제거
- "거래 설정" preset 표는 한 단락 요약 + 링크로 축소

점검 중 별도로 발견한 오기도 정정했다 — 실행 흐름 다이어그램과 핵심 모듈 표에 "5가지 매도 우선순위"라는 옛 표기가 남아 있었는데, 실제로는 4단계로 바뀐 지 한참이었다.

README.md가 436줄에서 약 80줄 줄었다(41 insertions, 121 deletions). 코드 변경은 없었다(문서만).

---

## 정리

| 항목 | 발견 | 조치 |
|------|------|------|
| IRP 표시 버그 | 회색 글씨라 안 보였을 뿐, 실제론 정상 렌더링 | 입력칸 아래 굵은 글씨로 분리 표시 |
| 운영 인프라 결함 1 | `kis-web.service`가 옛 경로 참조 → 6일간 dead | 서비스 파일 + 문서 6개 경로 정정 |
| 운영 인프라 결함 2 | `--host 127.0.0.1`로 외부 IP 접속 차단 | `--host 0.0.0.0`으로 변경 |
| DB 조회 페이지 | DB 내용을 직접 볼 방법이 없었음 | `/db-browser` 신설(7개 테이블, 페이징, mode 필터) |
| README 정리 | v1/v2 전략 설명이 docs와 중복 | 4줄 요약 + 링크로 축소(436→약350줄) |

화면에 안 보이는 값을 추적하다가 운영 서버가 6일간 죽어 있었다는 걸 알게 된 셈인데, "수동으로 우회해서 잘 쓰고 있었다"는 사실이 진짜 문제를 더 오래 가려준 경우였다.

다음 글에서는 같은 날 이어서 진행한 **웹 백테스트 기능 사전조사부터 v0.5.2 릴리즈까지**를 다룬다.
