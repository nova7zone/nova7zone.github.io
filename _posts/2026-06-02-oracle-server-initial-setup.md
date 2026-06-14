---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (6) — Oracle 서버 초기 설정과 Github Private 저장소 Clone
date: 2026-06-02 11:00:00 +0900
categories: infrastructure development
tags: oracle-cloud ubuntu python putty kis-api claude-code git cloud-setup
author: Evan
description: Putty로 Oracle Cloud 서버에 접속해 Python 3.11 환경을 구축하고, 타임존 설정과 venv 오류를 해결한 뒤 Github private 저장소를 토큰으로 clone했다. 동시에 새 PC에서는 VS Code 확장으로 작업환경을 갖추고 KIS API 키를 발급받아 웹서비스 구축 계획을 세운 과정을 기록한다.
---

**작성일**: 2026년 6월 2일  
**최종 수정**: 2026년 6월 2일  
**분야**: Infrastructure, AI Trading  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/ai-trading-program-v1-complete/)에서 프로그램을 1차 완성하고 멀티 PC 작업 환경까지 정리했다. 이번에는 실제로 자동매매가 돌아갈 운영 서버, Oracle Cloud Infrastructure(OCI)에 접속해서 환경을 구축하는 과정을 기록한다.

결론부터 말하면, putty로 OCI 서버에 접속해 Python 3.11 환경을 구성하고 Github private 저장소를 personal access token으로 clone했다. 중간에 타임존 미설정, venv 생성 오류 등 몇 가지 문제를 만났지만 모두 해결했다. 동시에 새 PC에서는 VS Code + Claude Code 확장으로 작업환경을 갖추고, KIS API 키(모의투자/실전투자)를 발급받아 다음 단계인 웹서비스 구축 계획까지 세웠다.

---

## Oracle Cloud 서버 패키지 설치

putty로 OCI 서버의 일반 계정에 접속한 뒤, `INSTALL.md` 문서를 따라 기본 패키지를 설치했다.

```bash
sudo apt update
sudo apt install -y git
sudo apt upgrade -y
```

이어서 Python 3.11과 관련 패키지를 설치했다.

```bash
sudo apt install -y python3.11 python3.11-venv python3.11-dev \
    python3-pip git curl wget nano build-essential

sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

python3 --version  # Python 3.11.x 확인
```

`python3 --version` 결과로 **Python 3.11.0**이 정상 설치된 것을 확인했다.

---

## ❌ 문제: 타임존이 설정되지 않음

INSTALL.md의 다음 단계(타임존 설정)를 진행하려고 했는데, 일반 계정에서는 타임존이 설정되지 않았다.

**해결 방법:**
- root 계정으로 전환한 뒤 타임존을 `Asia/Seoul`로 변경
- 변경 후 정상적으로 한국 시간(KST)으로 설정된 것을 확인

자동매매 봇은 KST 기준으로 장 시작/종료 시간을 판단하기 때문에, 서버 타임존이 맞지 않으면 cron 실행 시각이 전부 어긋난다. 초기 설정 단계에서 미리 잡아둔 게 다행이었다.

---

## 방화벽 1차 설정

INSTALL.md의 방화벽 설정 단계(1-3)도 함께 진행했다. SSH 접속이 끊기지 않도록 22번 포트를 먼저 확인한 뒤 나머지 규칙을 적용했다. 웹서버용 포트 개방은 다음 글에서 다룬다.

---

## ❌ 문제: Github Private 저장소 Clone 시 Authentication Failed

자동매매 프로그램이 들어있는 Github 저장소를 clone하려고 했다.

```bash
git clone https://github.com/Evan-ai-pro/kis-auto-trading-bot.git
```

저장소가 **Private**이라서 `Authentication Failed` 오류가 발생했다.

**해결 방법:**

1. Github에서 **Personal Access Token**을 발급
2. 자격증명을 저장하도록 설정

   ```bash
   git config --global credential.helper store
   ```

3. URL에 토큰을 직접 포함하지 않고, clone 시도 후 안내에 따라 입력

   ```bash
   git clone https://github.com/Evan-ai-pro/kis-auto-trading-bot.git
   # Username: Evan-ai-pro
   # Password: <발급받은 personal access token>
   ```

4. 입력한 토큰은 `credential.helper store` 설정에 의해 이후 자동으로 재사용됨

토큰의 유효기간을 30일로 설정했는데, 계속 사용하려면 만료 전에 갱신하거나 기간을 더 길게 설정해야 한다는 점을 기록해두었다.

> ⚠️ Personal Access Token은 비밀번호와 동일한 수준의 민감 정보다. 코드나 문서, 커밋 로그에 평문으로 남기지 않도록 주의가 필요하다.

---

## ❌ 문제: venv 생성 시 apt-pkg 모듈 오류

이후 폴더를 삭제하고 다시 clone(이번엔 username/password 입력 없이 자동 진행)한 뒤, 가상환경을 만들려고 했다.

```bash
python3 -m venv venv
```

그런데 `apt-pkg` 모듈이 없다는 오류가 발생했다.

**해결 과정:**
- `python3-apt`를 재설치하려고 시도하는 과정에서 커널 업데이트가 감지되어 재부팅 진행

```bash
sudo apt install --reinstall python3-apt
sudo apt install -y python3 python3-pip python3-venv
```

재부팅 후 다시 시도하니 정상적으로 가상환경이 생성됐다.

```bash
cd kis-auto-trading-bot
python3 -m venv venv
source venv/bin/activate
```

활성화 후 프롬프트가 `(venv) ubuntu@nova-vnic:~/trader/kis-auto-trading-bot$` 형태로 바뀐 것을 확인했다.

---

## 새 PC 환경 구성: VS Code + Claude Code

다른 컴퓨터에서는 VS Code 기반으로 작업환경을 갖췄다.

- VS Code 업데이트 실행
- VS Code 확장에서 **Claude Code for VS Code** 설치
- 백테스트용 CSV 파일 생성 스크립트 작성 요청

데스크탑 앱이 아니라 VS Code 확장을 쓰면, 코드 편집과 Claude Code 대화창을 같은 화면에서 바로 오갈 수 있어 효율이 좋았다.

---

## KIS API 키 발급 및 웹서비스 구축 계획

한국투자증권(KIS) API 키를 **모의투자**와 **실전투자** 양쪽 모두 발급받았다.

- `.env` 파일에 모의투자 키와 실전투자 키를 모두 입력
- `app.yaml` 설정값에 따라 어떤 키를 사용할지 선택할 수 있도록 구성

작업 중에 매수 로직에서 시장 상황에 따른 분기 로직이 중복되는 부분을 발견해서 정리 요청을 했다.

또한 모의투자/실전투자 매매 로그를 기반으로 성과를 분석할 수 있는 **웹서비스** 구축을 계획했다.

- **로그인 방식**: Google Authenticator를 이용한 OTP 로그인으로 결정
- DB 구축 방법과 웹서버 구축 방법을 설명하는 문서 작성 요청
- OCI에 최초 배포할 때 어떤 문서를 어떤 순서로 봐야 하는지 안내하는 문서를 요청 (각 첨부 문서 링크 포함)

---

## 정리

| 항목 | 내용 |
|------|------|
| OS / Python | Ubuntu 22.04, Python 3.11.0 |
| 타임존 | root 계정에서 Asia/Seoul로 수정 |
| Github clone | Private 저장소 → Personal Access Token으로 인증 |
| venv 오류 | python3-apt 재설치 + 재부팅으로 해결 |
| 새 PC | VS Code + Claude Code 확장 |
| KIS API | 모의투자/실전투자 키 모두 발급, `.env` + `app.yaml`로 선택 |
| 다음 계획 | 매매 로그 분석용 웹서비스 (Google Authenticator 로그인) |

다음 글에서는 Claude Code 작업 방식을 체계화하기 위한 **superpowers 플러그인** 도입과, 서버 설치를 이어가 웹서버를 외부에서 접속 가능하게 만드는 과정을 다룬다.
