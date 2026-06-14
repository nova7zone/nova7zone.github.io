---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (7) — superpowers 플러그인 도입과 웹서버 외부 접속 성공
date: 2026-06-02 15:30:00 +0900
categories: infrastructure devops
tags: oracle-cloud claude-code ubuntu server cloud-setup python
author: Evan
description: Claude Code 작업 방식을 체계화하기 위해 superpowers·Context7 플러그인을 도입하고, OCI 보안목록과 ufw·iptables 설정을 거쳐 자동매매 웹서버를 외부에서 접속 가능하게 만든 과정을 기록한다.
---

**작성일**: 2026년 6월 2일  
**최종 수정**: 2026년 6월 2일  
**분야**: Infrastructure, DevOps  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/oracle-server-initial-setup/)에서 OCI 서버에 Python 환경을 구축하고 저장소를 clone했다. 이번 글은 같은 날 진행한 두 가지 작업을 묶었다.

결론부터 말하면, Claude Code의 작업 방식을 체계화하기 위해 **superpowers**, **Context7 MCP** 등의 플러그인을 검토·도입했고, 동시에 서버 설치를 이어가 OCI 보안목록과 ufw·iptables 설정을 거쳐 **자동매매 웹서버를 외부에서 접속 가능한 상태**까지 만들었다.

---

## Harness Engineering — CLAUDE.md 개선

실거래 자동매매 봇은 코드 한 줄의 실수가 바로 손실로 이어질 수 있다. 그래서 "일단 코딩하고 보자" 식의 작업 방식을 막기 위해, **clarify → design → plan → code → verify** 5단계 규율을 CLAUDE.md에 반영하기로 했다.

이를 위해 Claude Code 플러그인 마켓에서 몇 가지 플러그인을 설치하고, 각각이 이 프로젝트에 실제로 어떤 가치를 주는지 평가했다.

---

## 플러그인 평가

| 플러그인 | 평가 | 비고 |
|------|------|------|
| **superpowers** | ★★★ 필수 | clarify→design→plan→code→verify 5단계 규율 강제. 실거래 봇에서 "일단 코딩" 실패 패턴을 막아줌. 매매 로직 수정 전에 설계를 먼저 검토하게 됨 |
| **claude-hud** | ★★ 있으면 좋음 | 컨텍스트 사용량·툴 활동을 터미널에 실시간 표시. 긴 세션에서 컨텍스트가 꽉 찰 때를 미리 파악 가능. 기능 개발보다 모니터링 목적 |
| **harness (claude-code-harness)** | ★★ 선택적 | `/harness-plan`, `/harness-work`, `/harness-review` 슬래시 커맨드 제공. 이미 CLAUDE.md로 harness 구조를 만들어둬서 중복되는 부분이 있음. 팀 작업이라면 가치 있지만, 혼자라면 superpowers로 충분 |
| **Context7 MCP** | ★★★ 필수 | 실시간 최신 문서를 컨텍스트에 주입. FastAPI 라우터 작성, SQLite 쿼리 작성, KIS REST API 스펙 확인 시 직접적으로 유용 |

최종적으로 **superpowers**와 **Context7 MCP**를 핵심으로 도입하고, claude-hud는 모니터링 보조용으로 함께 사용하기로 했다. harness 플러그인은 이미 CLAUDE.md에 비슷한 절차를 만들어둔 상태라 제외했다.

---

## 서버 설치 이어서 진행

[이전 글](/posts/oracle-server-initial-setup/)에서 만든 가상환경을 활성화하고, 패키지 설치를 이어갔다.

```bash
# 1. 프로젝트 폴더로 이동
cd ~/trader/kis-auto-trading-bot

# 2. 가상환경 활성화
source venv/bin/activate

# 3. 최신 코드 받아오기
git pull origin master

# 4. 패키지 설치
pip install -r ./requirements.txt
```

이어서 다음 작업을 진행했다.

- `.env` 파일 생성 (KIS API 키, 텔레그램 봇 토큰 등 입력)
- crontab 수정 및 `/etc/crontab` 저장

---

## 웹서비스 구축

매매 로그를 웹에서 확인할 수 있도록 웹서버 패키지를 설치했다.

```bash
pip install -r requirements-web.txt
```

세션 암호화를 위한 시크릿 코드를 `.env`에 추가한 뒤 웹서버를 임시 실행했는데, 곧바로 에러가 발생했다.

### ❌ 에러: 웹서버 임시 실행 시 모듈 누락

**해결 방법:**

```bash
pip install itsdangerous fastapi starlette
```

필요한 패키지를 추가 설치하니 웹서버가 정상적으로 임시 실행됐다.

---

## OCI 보안목록 + 방화벽 설정

웹서버를 외부에서 접속하려면 OCI 클라우드 단계와 서버 단계 양쪽에서 포트를 열어야 했다.

### 1. OCI Security List 설정

OCI 콘솔의 VCN → Security List에서 인그레스 규칙을 추가했다.

| 항목 | 값 |
|------|-----|
| Stateless | 체크 해제 |
| Source Type | CIDR |
| Source CIDR | 본인 IP/32 |
| IP Protocol | TCP |
| Source Port Range | All |
| Dest Port Range | 8080 |

### 2. ufw 방화벽 설정

```bash
# 1. SSH 포트 먼저 열기 (접속 끊김 방지!)
sudo ufw allow 22/tcp

# 2. 8080 포트 열기
sudo ufw allow 8080/tcp

# 3. ufw 활성화
sudo ufw enable
```

### ❌ 에러: 설정 후에도 접속 불가 — 미들웨어 문제로 추정

처음에는 웹서버의 미들웨어 문제로 보고 `web/main.py`를 전면 수정했다. 하지만 실제 원인은 다른 곳에 있었다.

### ✅ 진짜 원인: iptables

OCI Security List와 ufw를 모두 열었는데도 접속이 안 됐던 진짜 원인은 **iptables**였다.

```bash
sudo iptables -I INPUT 1 -p tcp --dport 8080 -j ACCEPT
sudo iptables -I INPUT 1 -p tcp --dport 80 -j ACCEPT
```

이 두 규칙을 추가하자 비로소 외부에서 웹서버 접속이 가능해졌다.

---

## 외부 접속 성공 ✅

브라우저에서 `http://<서버 IP>:8080/`로 접속하니 KIS 트레이딩 웹서비스의 **초기 설정 화면**이 정상적으로 나타났다.

- Google Authenticator 앱으로 QR 코드를 스캔하거나 수동 입력 코드로 OTP 등록
- 비밀번호 설정(8자 이상) + 비밀번호 확인
- 앱에 표시된 6자리 코드를 입력해 설정 완료

`OCI_QUICKSTART.md`의 4-3 단계까지 정상적으로 완료했다.

> ⚠️ OTP 수동 입력 코드와 서버 IP는 로그인 정보에 준하는 민감 정보이므로, 화면을 캡처해 공유할 때는 반드시 가린 뒤 공유해야 한다.

---

## 정리

| 체크리스트 | 상태 |
|------|------|
| Oracle Cloud VM 설정 | ✅ |
| GitHub Private 저장소 clone | ✅ |
| Python venv 가상환경 구성 | ✅ |
| 패키지 설치 (requirements.txt, requirements-web.txt) | ✅ |
| 웹서버 모듈 누락 해결 (itsdangerous, fastapi, starlette) | ✅ |
| OCI Security List 포트 개방 | ✅ |
| ufw 방화벽 설정 | ✅ |
| iptables 설정 (실제 접속 차단 원인) | ✅ |
| 웹서버 외부 접속 성공 | ✅ |

다음 글에서는 웹서버를 systemd로 상시 실행 등록하고, nginx+HTTPS를 검토한 뒤 CLAUDE.md 작업 절차를 다시 정비하고 crontab으로 실제 자동매매를 등록하는 과정을 다룬다.
