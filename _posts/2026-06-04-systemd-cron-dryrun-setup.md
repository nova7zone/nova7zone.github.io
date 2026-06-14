---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (8) — systemd 상시 실행, crontab 등록, dry-run 모드 도입
date: 2026-06-04 10:00:00 +0900
categories: infrastructure devops
tags: oracle-cloud server systemd cron claude-code python
author: Evan
description: 웹서버를 systemd로 상시 실행 등록하고 CLAUDE.md 작업 절차를 다시 정비한 뒤, crontab으로 실제 자동매매를 등록했다. app.yaml 경로 오류와 KIS 토큰 1일 1회 발급 제한 문제를 만나면서 dry-run 모드와 토큰 차단 처리 로직을 추가한 과정을 기록한다.
---

**작성일**: 2026년 6월 4일  
**최종 수정**: 2026년 6월 4일  
**분야**: Infrastructure, DevOps  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/superpowers-and-webserver-access/)에서 웹서버를 외부에서 접속 가능한 상태까지 만들었다. 이번 글에서는 그 웹서버를 **상시 실행** 상태로 등록하고, 자동매매 본체를 **crontab**에 올려 실제로 동작시키는 과정을 정리한다.

결론부터 말하면, systemd로 웹서버를 상시 실행 등록했고, CLAUDE.md 작업 절차를 다시 정비했다. crontab에 자동매매·리포트·투자일지 작업을 모두 등록했지만, `app.yaml`을 찾지 못하는 경로 문제와 KIS 토큰 1일 1회 발급 제한 문제를 차례로 만났다. 이를 해결하면서 **dry-run 모드**와 **토큰 차단(403) 처리 로직**을 추가했다.

---

## systemd 서비스 등록

웹서버를 매번 수동으로 실행하지 않도록 systemd 서비스로 등록했다.

```bash
sudo systemctl start kis-web
```

### ❌ 에러: 서비스 시작 실패

`/etc/systemd/system/kis-web.service`에 적힌 실행 경로가 실제 프로젝트 경로와 일치하지 않아 오류가 발생했다.

**해결 방법:**

1. `kis-web.service`의 경로를 실제 프로젝트 경로로 수정
2. 데몬 재설정 후 재시작

```bash
sudo systemctl daemon-reload
sudo systemctl restart kis-web
sudo systemctl status kis-web
```

`status` 결과 `active (running)`으로 정상 동작하는 것을 확인했다.

---

## nginx + HTTPS (선택, Phase 4)

`WEBSERVICE_DEPLOY.md`의 Phase 4 단계인 nginx + HTTPS 설정도 검토했다.

- nginx 설치
- 도메인이 없는 상태이므로, **IP 직접 접근** 방식으로 우선 진행
- `OCI_QUICKSTART.md`의 Step 5는 다음 작업으로 남겨둠

HTTPS 인증서는 도메인이 있어야 발급이 수월하기 때문에, 일단 IP+포트 접근으로 운영하면서 도메인 연결은 추후 과제로 미뤄두었다.

---

## CLAUDE.md 작업 절차 재정비

서버 설치 작업과 별개로, Claude Code 작업 절차 문서도 다시 정리했다. 그날의 할 일을 다음과 같이 전달했다.

- `OCI_QUICKSTART.md`에서 설치 관련 문서를 확인하고, 순서상 이전 문서와 중복되는 내용은 **문서 출처 + 중복 표기**
- `OCI_QUICKSTART.md`의 문서 읽기 순서 섹션에 나머지 모든 문서의 링크 추가 (서버 설치와 무관한 문서는 "참고 문서"로 별도 분류)
- 모든 설명 문서(md 파일) 최신화
- 현재 프로그램의 **워크플로우** 정리 요청

워크플로우를 시각적으로 보여줄 필요가 있어서, 이 과정에서 Claude Code 플러그인(superpowers)이 자동으로 추가 설치되기도 했다.

---

## crontab 등록

### ❌ 문제: cron으로 실행해도 로그가 기록되지 않음

서버의 로그 기록을 확인했는데, cron으로 실행한 자동매매가 동작하지 않았다.

**원인:** crontab에 적힌 프로젝트 폴더명이 실제 폴더명과 다르게 되어 있었다.

**해결:** crontab을 아래와 같이 수정했다.

```bash
# 15분마다 매매 실행 (평일 09:00~15:30)
*/15 9-15 * * 1-5 ubuntu /home/ubuntu/trader/kis-auto-trading-bot/venv/bin/python3 /home/ubuntu/trader/kis-auto-trading-bot/runner.py >> /home/ubuntu/trader/kis-auto-trading-bot/logs/cron.log 2>&1

# 16:00 일간 리포트
0 16 * * 1-5 ubuntu /home/ubuntu/trader/kis-auto-trading-bot/venv/bin/python3 /home/ubuntu/trader/kis-auto-trading-bot/runner.py --report-daily >> /home/ubuntu/trader/kis-auto-trading-bot/logs/cron.log 2>&1

# 17:00 월간 리포트 (마지막 영업일에만 발송)
0 17 * * 1-5 ubuntu /home/ubuntu/trader/kis-auto-trading-bot/venv/bin/python3 /home/ubuntu/trader/kis-auto-trading-bot/runner.py --check-monthly >> /home/ubuntu/trader/kis-auto-trading-bot/logs/cron.log 2>&1

# 15:35 투자일지 보유현황 업데이트
35 15 * * 1-5 ubuntu /home/ubuntu/trader/kis-auto-trading-bot/venv/bin/python3 /home/ubuntu/trader/kis-auto-trading-bot/runner.py --update-journal >> /home/ubuntu/trader/kis-auto-trading-bot/logs/cron.log 2>&1
```

수정 후 일단 수동으로 임시 실행해서 동작하는 것을 확인했다.

```bash
/home/ubuntu/trader/kis-auto-trading-bot/venv/bin/python3 /home/ubuntu/trader/kis-auto-trading-bot/runner.py
```

---

## ❌ 에러: app.yaml을 찾지 못함

crontab으로 실행하면 작업 디렉토리가 사용자의 홈 디렉토리(`~`)가 되기 때문에, 상대 경로로 작성된 `settings/app.yaml`을 찾지 못하는 오류가 발생했다.

**해결 방법:** `runner.py` 시작 부분에서 스크립트 파일이 있는 위치로 작업 디렉토리를 강제로 변경했다.

```python
import os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
```

이 한 줄로 cron 환경에서도 항상 프로젝트 루트 기준으로 설정 파일을 읽도록 고정했다.

---

## ❌ 문제: KIS 토큰 1일 1회 발급 제한

cron이 정상적으로 동작하기 시작했지만, 이번엔 **KIS 서버의 토큰 발급 제한**(1일 1회)에 걸려 실행이 안 되는 상황을 만났다. 당일에는 더 이상 토큰을 받을 수 없어서, 다음 날 다시 확인이 필요했다.

이 문제를 겪으면서 두 가지를 함께 정리했다.

### dry-run 모드 추가

토큰 발급 문제로 실거래 흐름을 확인할 수 없을 때를 대비해, **API 호출·주문·텔레그램 알림 없이 전체 흐름만 점검**할 수 있는 모드를 추가했다.

- `api/dry_run_client.py` 신규 생성 — 토큰 발급·API 호출이 없는 `DryRunKISApiClient`
- `runner.py`에 `--dry-run` 플래그 추가

```bash
python runner.py --dry-run
```

단위 테스트 21개를 추가했고, 전체 93개 테스트가 통과했다.

### 토큰 403 차단 처리

KIS 토큰 발급이 막혔을 때(HTTP 403), 매번 같은 알림이 반복 발송되지 않도록 처리 로직을 추가했다.

- `api/token_manager.py`에 `TokenBlockedError(BaseException)` + 차단 플래그 함수 + HTTP 403 감지 추가
- `runner.py`: 시작 시 차단 플래그를 확인해 조용히 종료, **첫 403 발생 시에만** 텔레그램으로 1회 알림
- 단위 테스트 13개 추가, 전체 106개 통과

동작 방식은 이렇다.

| 상황 | 동작 |
|------|------|
| 당일 첫 403 발생 | 텔레그램 알림 발송 후 종료 |
| 이후 같은 날 cron 실행 | 조용히 종료 (중복 알림 없음) |

---

## 정리

| 작업 | 결과 |
|------|------|
| 웹서버 상시 실행 | systemd 서비스(`kis-web`) 등록, 경로 오류 수정 후 정상 동작 |
| nginx + HTTPS | IP 직접 접근으로 우선 진행, 도메인 연결은 추후 과제 |
| CLAUDE.md / 문서 | OCI_QUICKSTART.md 문서 읽기 순서·중복 표기 정리 요청 |
| crontab | 매매(15분 주기)·일간/월간 리포트·투자일지 4개 작업 등록 |
| app.yaml 경로 오류 | `runner.py`에서 `os.chdir`로 작업 디렉토리 고정 |
| 토큰 발급 제한 | `--dry-run` 모드 + 403 차단 처리 로직 추가 |

다음 글에서는 일간/월간 리포트를 md 파일로 저장하고 Google Drive와 동기화하는 기능, 그리고 웹에서 설정 파일을 직접 편집할 수 있는 YAML 편집기를 추가하는 과정을 다룬다.
