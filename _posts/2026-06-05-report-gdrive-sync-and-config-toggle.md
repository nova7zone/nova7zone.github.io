---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (9) — 리포트 MD 저장, Google Drive 동기화, 웹 설정 편집기
date: 2026-06-05 11:00:00 +0900
categories: trading development
tags: ai-trading google-drive python kis-api claude-code
author: Evan
description: 일간·월간 리포트를 MD 파일로 저장하고 Google Drive와 동기화하는 기능, 웹에서 설정 YAML을 직접 수정하는 편집기를 추가했다. 이어서 토큰 캐시 이중 락 데드락, 스크리닝 로그 DB 기록, 초기자금 자동 추적 기능까지 정리한 과정을 기록한다.
---

**작성일**: 2026년 6월 5일  
**최종 수정**: 2026년 6월 5일  
**분야**: AI Trading, Development  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/systemd-cron-dryrun-setup/)에서 crontab으로 자동매매를 등록하고 dry-run/토큰 차단 처리까지 마쳤다. 이번 글은 6월 4일 후반부터 6월 5일까지 진행한 작업을 정리한다.

결론부터 말하면, 일간/월간 리포트를 **MD 파일**로 저장하고 **Google Drive**와 자동 동기화하는 기능을 추가했고, 웹 설정 페이지에서 YAML 파일을 직접 수정할 수 있는 편집기를 만들었다. 이어서 토큰 캐시의 **이중 락 데드락 버그**를 수정하고, 스크리닝 결과를 DB에 기록해 웹에서 조회할 수 있게 했으며, 초기자금을 자동으로 추적하는 기능을 추가했다.

---

## 일간/월간 리포트 MD 파일 저장

기존에는 리포트가 텔레그램 메시지로만 발송되어, 과거 기록을 한눈에 모아보기 어려웠다. 그래서 리포트를 MD 파일로도 저장하도록 했다.

- `report/md_writer.py` 신규 생성 — 일간/월간 MD 빌드·저장 함수 4개
- `report/daily_report.py`: 16:00 리포트 실행 시 `report/daily/YYYY-MM.md`에 누적 저장
- `report/monthly_report.py`: 마지막 영업일에 `report/monthly/YYYY-MM.md` 생성
- MD 저장이 실패해도 텔레그램 발송에는 영향이 없도록 `try/except`로 분리

테스트는 `tests/test_md_writer.py`(28개) + `tests/test_md_report_integration.py`(6개), 총 34개를 추가했다.

---

## Google Drive 리포트 동기화

저장한 MD 리포트를 Obsidian Vault와 연동된 Google Drive 폴더로 자동 동기화하도록 했다.

- `report/gdrive_sync.py` 신규 생성 — `rclone copy` 실행, 실패 시 텔레그램 알림
- `daily_report.py` / `monthly_report.py`: MD 저장 후 Google Drive 자동 동기화
- `settings/app.yaml`에 `paths.report_dir`, `paths.gdrive_report_remote` 추가
- `gdrive_report_remote`가 비어있으면 동기화를 건너뜀(opt-in 방식)
- `tests/test_gdrive_sync.py`(15개), `tests/test_md_report_integration.py`(통합 4개 추가, 총 10개)

---

## 웹 설정 YAML 편집기

설정 변경을 매번 서버에 ssh로 접속해서 직접 파일을 수정하는 대신, 웹 설정 페이지에서 바로 수정할 수 있는 편집기를 추가했다.

- `web/routers/config_router.py`: `/api/config/files`, `/api/config/file`(GET/POST) 엔드포인트 추가
  - **화이트리스트 10개 YAML 파일**만 접근 허용 (경로 조작 차단)
  - POST 시 `yaml.safe_load()`로 문법 검증 후 저장, 오류 시 400 응답
  - 모드·프리셋·파일 저장 성공 시 `[WEB]` 태그 + 요청 IP를 포함한 로그 기록
- `web/templates/settings.html`: 설정 파일 편집 카드 추가
  - 파일 선택 드롭다운 → textarea에 내용 로드 → 저장 버튼
  - 저장하지 않은 변경사항이 있을 때 다른 파일로 전환하면 confirm 경고
  - 실행 모드·매매 프리셋·YAML 저장 각각에 confirm() 확인 팝업 추가

이렇게 해두면 서버에 직접 접속하지 않고도 설정값을 안전하게 바꿀 수 있다.

---

## 문서 전체 최신화

코드가 빠르게 바뀌면서 문서가 따라가지 못하는 부분을 정리했다.

- `OCI_QUICKSTART.md`: 중복 구간 10곳에 출처 표기(📌), 읽기 순서에 `UPDATE.md`·`WORKFLOW.md` 추가, 참고 문서 섹션 7개 추가
- `WORKFLOW.md`: 신규 생성 — Mermaid 시스템 구조도·데이터 흐름 + ASCII 실행/설정 로드 흐름
- `SETTINGS_GUIDE.md`: `settings/screening/` → `settings/screen_config/` 경로 전체 교체
- `SETTINGS_REFERENCE.md`: `KIS_APP_KEY` → 모의/실전 모드별 키(`KIS_LIVE_*`/`KIS_PAPER_*`) 분리 + `WEB_SESSION_SECRET` 추가
- `USAGE.md`: `token_cache.json` → 모드별 파일명(`token_cache_live.json`/`token_cache_paper.json`)으로 수정
- `README.md`: 환경변수 live/paper 분리 + `WORKFLOW.md` 링크 추가

---

## ❌ 버그: 토큰 캐시 이중 락 데드락

운영 중 당일 자동매매가 갑자기 멈추는 현상이 있었는데, 원인은 `token_manager.py`의 **이중 락(double lock)** 문제였다.

- `get_access_token()`이 외부 `FileLock`으로 `token_cache_paper.json.lock`을 보유한 상태에서
- 내부의 `save_json_locked()`가 **같은 lock 파일을 다시 획득**하려고 시도
- 10초 타임아웃 → 캐시 저장 실패 → 토큰을 다시 발급받으려 시도 → KIS 토큰 발급 한도(403) 초과 → **당일 자동매매 중단**

**해결**: `get_access_token()`과 `invalidate_token_cache()`에서 동일한 이중 락 패턴을 제거했다. 락을 한 번만 획득하도록 정리하니 더 이상 타임아웃이 발생하지 않았다.

---

## Google Drive 동기화 on/off 토글

리포트 동기화를 항상 켜둘 필요는 없으므로, 설정 페이지에서 켜고 끌 수 있는 토글을 추가했다.

- `settings/app.yaml`에 최상위 키 `gdrive_enabled: true` 추가
- `web/routers/config_router.py`: `POST /api/config/gdrive` 엔드포인트 추가
- `report/daily_report.py`, `monthly_report.py`: `gdrive_enabled` 값을 확인하도록 수정
- `web/templates/settings.html`: 구글 드라이브 토글 카드 + Alpine.js `setGdrive()` 추가

---

## 스크리닝 로그 DB 기록 및 웹 표시

매매가 발생하지 않을 때 "왜 매수 후보가 없었는지"를 나중에 확인할 수 있도록, 스크리닝 결과를 DB에 남기고 웹에서 볼 수 있게 했다.

- `trading/buy.py`: 1차/2차 스크리닝 후 `insert_screening_log()` 호출 (1차 통과 0개여도 기록)
- `screening/second_stage.py`: 선정된 종목명·점수를 INFO 레벨로 강화 로깅
- `db/repository.py`: `get_screening_logs()` 추가
- `web/routers/api.py`: `GET /api/screening-logs` 엔드포인트 추가
- `web/routers/pages.py` + `web/templates/screening.html`: `/screening` 페이지 신규 추가 (날짜·시장국면·1차/2차 통과 수·종목명 표시)
- `web/templates/layout.html`: 사이드바에 스크리닝 메뉴 추가

---

## 초기자금 자동 추적

수익률을 계산하려면 "처음에 얼마로 시작했는지"가 기준이 되어야 하는데, 이 값이 없었다.

- `settings/app.yaml`에 `paths.initial_capital: "data/initial_capital.json"` 추가
- `runner.py`: `_ensure_initial_capital()` 추가 — 최초 실행 시 잔고를 초기자금으로 저장 (backtest·dry-run은 제외)
- `web/routers/config_router.py`: `GET /api/config/capital` 엔드포인트 추가
- `web/templates/dashboard.html`: 초기자금·누적 수익률(%) 카드 추가

---

## 문서/코드 정합성 정리

- `/api/config/capital` 엔드포인트를 `api_router`에서 `config_router`로 이동
- `_ensure_initial_capital`에 dry-run 모드 제외 조건 추가
- `buy.py`: 1차 스크리닝 통과가 0개여도 screening_log를 DB에 기록하도록 수정
- 셸 명령어 안내를 `python`/`pip` → `python3`/`pip3`로 통일 (`INSTALL.md`, `UPDATE.md`, `OCI_QUICKSTART.md`, `WEBSERVICE_DEPLOY.md`, `README.md`)
- CLAUDE.md: 라우터 표에 신규 라우터 6개 추가, `--dry-run` 명령어 추가, 프로젝트 구조에 `api/dry_run_client.py`·`web/templates/` 반영, 데이터 레이어에 `data/initial_capital.json` 추가

---

## CLAUDE.md 작업 종료 절차 업데이트

작업 종료 절차의 순서와 항목도 다시 손봤다.

- push 위치를 절차상 더 적절한 순서로 조정
- 6단계로 **PR 요청** 단계 추가
- 6단계 항목의 마크다운 형식 수정

---

## 정리

| 기능 | 내용 |
|------|------|
| 리포트 MD 저장 | 일간/월간 리포트를 `report/daily/`, `report/monthly/`에 누적 저장 |
| Google Drive 동기화 | `rclone copy` 기반, opt-in + on/off 토글 |
| 웹 YAML 편집기 | 화이트리스트 10개 파일, 문법 검증 후 저장 |
| 토큰 이중 락 | `token_manager.py` 데드락 수정 → 403 한도초과 재발 방지 |
| 스크리닝 로그 | DB 기록 + `/screening` 페이지에서 조회 |
| 초기자금 추적 | 최초 실행 시 잔고 자동 저장, 대시보드에 누적 수익률 표시 |

다음 글에서는 며칠 뒤(6/7~6/8) 서버 상태를 점검하던 중 발견한 **KOSPI 지수 조회 버그** — 매매가 전혀 발생하지 않던 문제를 추적하고 해결한 과정을 다룬다.
