---
layout: post
title: AI 를 이용한 자동매매 프로그램 작성(4) - Claude Desktop & Claude Code 첫 실행
date: 2026-05-31 17:48:00 +0900
categories: trading coding
tags: claude-code claude-desktop github git ai-trading
author: Evan
description: Claude Desktop 설치부터 Claude Code로 첫 명령을 내리기까지 - 막힌 곳마다 AI에게 물어보며 돌파한 기록
---

**작성일**: 2026년 5월 31일  
**최종 수정**: 2026년 5월 31일  
**분야**: AI Trading, Development Setup  
**난이도**: Beginner  
**상태**: Production Ready

---

## 들어가며

설계 문서도 완성했고, 프롬프트도 다듬었다. 이제 실제로 코드를 만들어야 할 차례다.  
도구는 Claude Code — 터미널에서 Claude에게 직접 코딩을 시키는 CLI 도구다.

문제는 처음 써보는 도구라는 것이었다. 설치부터 첫 명령까지, 막히는 곳마다 다른 AI에게 물어보면서 전진했다.

**주요 내용:**
- Claude Desktop 설치 및 Claude Code 실행
- GitHub 연동 시도와 실패, 그리고 로컬 방식으로 전환
- Git for Windows 설치
- Gemini를 통해 Claude Code 사용법 습득
- 첫 프롬프트 실행 결과

---

## Phase 1: Claude Desktop 설치

[Anthropic 공식 사이트](https://claude.ai/download)에서 Claude Desktop을 설치했다.  
설치 자체는 단순했다. 다운로드 → 실행 → 완료.

이후 Claude Code를 실행하려면 터미널에서 `claude` 명령어를 입력하면 된다.

```bash
claude
```

### 1.1 Claude Code Pro 과금 문제

Claude Code를 처음 실행하면서 한 가지 의문이 생겼다.

> "Claude Pro에 가입되어 있는데, Claude Code 실행 시 별도 과금이 있는지?"

확인이 필요한 사항이었다. Claude Code는 API 토큰을 소비하는 방식으로 동작하므로, Pro 구독과는 별개로 사용량에 따라 추가 비용이 발생할 수 있다. 실제 프로젝트를 시작하기 전에 반드시 확인해야 할 부분이다.

---

## Phase 2: GitHub 연동 시도 — 그리고 실패

Claude Code에서 저장소를 **클라우드(GitHub)로 직접 설정**하고 새로 가입한 GitHub 계정과 연동을 시도했다.

결과는 **실패**였다.

연동 방식이 직관적이지 않았고, 처음 접근한 방법으로는 진행이 되지 않았다.  
방향을 바꿔서 **로컬 방식**으로 전환했다.

### 2.1 로컬 프로젝트 폴더 생성

일단 로컬에 프로젝트 폴더를 만들고, 앞서 준비한 프롬프트 파일(`KIS_TRADING_PROMPT_V4_EN.txt`)을 그 안에 저장했다.

```
C:\my_project\claude\kis-auto-trading-bot\
└── KIS_TRADING_PROMPT_V4_EN.txt
```

### 2.2 Git for Windows 설치

로컬 저장소로 지정하자마자 Claude Desktop이 경고를 띄웠다.

> "Git for Windows가 필요합니다."

[Git 공식 사이트](https://git-scm.com/download/win)에서 설치 후 Claude Desktop을 재시작하면 된다.

```bash
# 설치 확인
git --version
```

---

## Phase 3: Claude Code 사용법을 Gemini에게 묻다

설치는 됐는데, Claude Code에 **어떻게 작업을 시킬지** 막막했다.  
그래서 Gemini에게 물어봤다.

### 3.1 Gemini의 답변 — 첫 번째 프롬프트 명령어

Gemini가 제안한 첫 번째 명령어는 다음과 같다.

```
현재 폴더에 있는 KIS_TRADING_PROMPT_V4_EN.txt 파일을 꼼꼼히 읽고,
명세서에 맞춰 프로젝트 구축을 시작해 줘.

특히 파일 마지막의 SECTION 19 [AI 에이전트를 위한 필수 지시사항]을
엄격하게 지켜야 해. 절대 한 번에 모든 코드를 짜지 말고,
가장 먼저 1단계(핵심 프로젝트 구조 생성, requirements.txt, .gitignore,
기본 설정 파일 작성)만 수행해 줘.

1단계 작성이 끝나면 터미널에서
git add . 와 git commit -m "chore: initial project setup"을 실행해서
작업 상태를 저장하고, 다음 단계(API 통신 로직 등)로 넘어갈지 나에게 물어봐.
답변은 한글로 해줘
```

### 3.2 핵심 전략: 단계별 진행

Gemini가 강조한 포인트는 **"한 번에 다 짜지 말 것"** 이었다.

AI에게 코딩을 시킬 때 가장 흔한 실수가 전체를 한꺼번에 요청하는 것이다.  
컨텍스트가 넘치면 코드 품질이 떨어지고, 중간에 맥락을 잃는다.

대신 이렇게 접근하라고 했다.

> 1단계 완료 → commit → "2단계인 API 클라이언트 부분(kis_api.py, token_manager.py)을 만들어줘" → commit → 반복

각 단계가 끝날 때마다 commit을 남기는 것도 중요하다.  
AI가 실수를 했을 때 언제든 특정 시점으로 돌아갈 수 있기 때문이다.

---

## Phase 4: 첫 명령 실행 결과

위 프롬프트를 Claude Code에 입력했다.  
결과는 기대 이상이었다.

하루 만에 프로젝트의 핵심 골격이 전부 완성됐다.

| 단계 | 내용 | 커밋 |
|------|------|------|
| 초기 구조 | 폴더 구조, requirements.txt, .gitignore, 설정 파일 | `chore: initial project setup` |
| 유틸 | logger, file_utils, time_utils, config_loader | `feat(utils): add logger and utils` |
| API 클라이언트 | token_manager, kis_api (KIS REST API 연결) | `feat(api): add token_manager, kis_api client` |
| 스크리닝 | market_filter, 1·2차 스크리닝, 조건 모듈 10개 | `feat(screening): add market_filter and conditions` |
| 매매 엔진 | order_manager, buy, sell (5우선순위 매도 로직) | `feat(trading): add order_manager, buy, sell` |
| 리포트 | Telegram 발송, 일간/월간 리포트, Excel 투자일지 | `feat(report): add telegram, daily/monthly report` |
| 백테스트 | 백테스트 엔진 + survivorship bias 경고 포함 | `feat(backtest): add backtest engine` |
| 실행 진입점 | runner.py (cron 5분 주기 실행) | `feat(runner): add runner entrypoint` |
| 테스트/문서 | pytest 테스트 스위트, README, USAGE | `feat(tests,docs): add pytest suite and docs` |

이후 PR #1~#10을 통해 버그 수정, CI(pytest) 워크플로 추가, ATR/시장국면 필터 추가까지 이어졌다.

---

## 배운 점 및 결론

### 주요 교훈

1. **막히면 다른 AI에게 물어봐라**  
   Claude Code 사용법을 Claude에게 물어보는 것보다, Gemini에게 물어보는 게 오히려 더 명확한 답을 얻었다. 도구마다 강점이 다르다.

2. **단계별 commit 전략은 필수**  
   AI가 코드를 짤 때 한 번에 너무 많이 맡기면 품질이 떨어진다. 작은 단위로 쪼개고, 각 단계마다 commit을 남기는 것이 결과적으로 빠르다.

3. **로컬 저장소가 먼저**  
   처음부터 클라우드 연동을 시도하다 막혔다. 로컬에서 먼저 안정적으로 돌아가게 만들고, GitHub 연동은 나중에 해도 늦지 않는다.

4. **SECTION 19 같은 AI 지시사항을 진지하게 써라**  
   프롬프트 파일에 "AI 에이전트를 위한 필수 지시사항"을 명시해두면, Claude Code가 그 규칙을 꽤 잘 지킨다. 무한 루프 금지, 하드코딩 금지 같은 원칙을 명문화하는 것이 중요하다.

### 다음 방향

- Claude Code와 GitHub 정식 연동 (다음 포스트에서 다룸)
- 여러 컴퓨터에서 동기화하기 위한 배치파일 생성
- 새 PC에서 환경을 복원하는 setup 스크립트 작성

---

## 참고자료

- [Claude Desktop 다운로드](https://claude.ai/download)
- [Git for Windows](https://git-scm.com/download/win)
- [Claude Code 공식 문서](https://docs.anthropic.com/en/docs/claude-code)

### 이전 포스트

- [AI 를 이용한 자동매매 프로그램 작성(1) - 시스템 설계 & 프롬프트 전략](/2026/05/31/ai-automated-trading-system-design)

### 다음 포스트

- AI 를 이용한 자동매매 프로그램 작성(5) - Claude Code & GitHub 연동, 멀티 PC 동기화
