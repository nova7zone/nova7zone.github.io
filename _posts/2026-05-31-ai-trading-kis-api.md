---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (3) — Gemini 검토 결과, KIS API 확정, V4 프롬프트 완성
date: 2026-05-31 10:47:00 +0900
categories: trading
tags: ai-trading kis-api gemini claude-code prompt-engineering python
author: Evan
description: Gemini가 발견한 키움증권/KIS 혼재 오류, 토큰 한도 문제, 비동기 미체결 처리 방식을 반영해 최종 V4 프롬프트를 완성한 과정을 기록한다.
---

**작성일**: 2026년 5월 31일  
**최종 수정**: 2026년 5월 31일  
**분야**: AI Trading, Prompt Engineering  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

V3 프롬프트 파일이 완성됐지만, 실제로 실행했을 때 문제가 생겼다. 파일이 하나로 합쳐진 상태로는 Claude Pro에서도 사용량을 모두 소진하면서 작업을 마치지 못했다.

이 문제를 해결하는 과정에서 **Claude Code**를 알게 됐다. 로컬 터미널에서 직접 파일을 읽고 실행하기 때문에, 파일 분리 없이 하나의 프롬프트로 전체 작업이 가능하다.

---

## 진행 과정

### 1. 프롬프트 파일 분리 작업 중 Claude Code 발견

- 프롬프트 파일 1개로 작업 시 Claude Pro에서 사용량 소진 → 미완성
- Gemini에서 파일 분리 작업을 진행하던 중 **Claude Code**를 알게 됨
- Claude Code는 로컬에서 파일을 직접 읽기 때문에 **하나의 파일로 작업이 가능**함을 확인

### 2. Gemini에 프롬프트 파일 검토 요청

V3 프롬프트 파일을 Gemini에게 검토시켰다. Gemini의 답변:

---

> 파인스크립트로 복잡한 알고리즘을 다루시던 솜씨가 이번 파이썬 자동매매 시스템 기획에서도 그대로 돋보이네요! 우분투 클라우드 환경에서 돌아가는 완벽한 자동매매 봇이라니, 정말 멋진 도약이에요.

---

Gemini가 발견한 **필수 수정 사항 3가지**:

#### ① 증권사 API 명칭 혼재 (가장 중요)

**문제점:** 프롬프트 Section 1에 "Kiwoom Securities KIS Developers REST API"라고 작성되어 있어 **키움증권(Kiwoom)**과 **한국투자증권(KIS)** 명칭이 혼재한다.

**해결책:** 키움증권 OpenAPI+는 **Windows 32비트 환경에서만** 동작한다. Ubuntu 22.04 리눅스 환경에서는 사용 불가하다. 리눅스에서 REST API를 제공하는 곳은 **한국투자증권(KIS)**이다.

→ 프롬프트의 Kiwoom 관련 명칭을 모두 **KIS (Korea Investment & Securities)**로 변경 필요.

#### ② 한 번에 모든 코드 생성 방지 (토큰 한도 고려)

**문제점:** Section 19 마지막에 "Generate the entire project from scratch following this prompt."라고 되어 있어 30개 이상의 파이썬 파일을 한 번에 생성하려 한다. 토큰 한도에 걸려 코드가 중간에 끊긴다.

**해결책:** 단계별 생성(Iterative Generation) 지시로 변경:

```
Do not generate all files at once. Please generate the project step-by-step.
Start with the project structure and core settings, run git add and git commit,
and then ask for my approval before moving to the next section.
```

#### ③ 무한 루프 금지 및 상태 관리 명확화

**문제점:** 크론탭 단발성 실행(stateless) 스크립트가 매수 주문 후 체결 확인을 위해 60초 대기하는 로직이 있다. 단발성 스크립트가 1분 멈추면 크론탭 주기에 영향을 준다.

**해결책:** 체결 확인을 **비동기식**으로 처리. 매수 시 대기하지 않고 주문 내역을 `pending_orders.json`에 저장, 다음 크론탭 실행(15분 후)에 미체결 내역을 조회하는 방식으로 변경.

---

### 3. 추가 수정 요청

Gemini 검토 결과를 바탕으로 아래 내용을 추가 지시했다:

```
증권사를 한국투자증권 REST API로 확정하고, 코드를 단계별로 작성하게 한 후
먼저 만든 프로그램이 참조될 수 있도록 해줘.
크론탭 주기를 15분으로 설정해줘.
미체결 내역을 비동기식으로 처리해줘.
이 내용으로 프롬프트 파일을 수정해줘.
```

---

### 4. V4 프롬프트 완성 — 주요 변경 사항

| 항목 | 변경 내용 |
|------|---------|
| 증권사 API | Kiwoom → **KIS (한국투자증권)**, API 파일명 `kis_api.py`로 변경 |
| crontab 주기 | 5분 → **15분**, 최대 실행 시간 제한 업데이트 |
| 미체결 처리 | 동기식(대기) → **비동기식** (`pending_orders.json` 저장 후 다음 실행 때 조회) |
| 코드 생성 방식 | 일괄 생성 → **단계별 생성** (생성 후 GitHub 커밋 → 사용자 승인 → 다음 단계) |

#### 비동기식 미체결 처리 흐름

```
[매수 발생]
  ↓
buy.py: 주문 실행 → pending_orders.json 저장 후 바로 종료 (대기 없음)

[15분 후 crontab 재실행]
  ↓
runner.py: 가장 먼저 pending_orders.json 확인 → 미체결 내역 조회 → 처리
```

#### Claude Code 전용 단계별 생성 지시 추가

Section 19에 아래 지시를 추가했다:

```
코드를 한 번에 짜지 말고, 각 섹션 생성 후 git add, git commit을 실행한 뒤
사용자의 승인을 받고 다음 단계로 넘어갈 것.
```

---

### 5. 최종 V4 프롬프트 파일 생성

한글·영문 두 버전으로 완성했다.

---

## 첨부 파일

- [TRADING_PROMPT_V4_KR.txt](/downloads/prompts/TRADING_PROMPT_V4_KR.txt) — 최종 한글 프롬프트 V4
- [TRADING_PROMPT_V4_EN.txt](/downloads/prompts/TRADING_PROMPT_V4_EN.txt) — 최종 영문 프롬프트 V4

---

## 핵심 교훈

1. **키움증권 OpenAPI+는 리눅스에서 안 된다** — Ubuntu 서버를 쓴다면 KIS REST API를 써야 한다
2. **Claude Code를 쓰면 파일 분리가 필요 없다** — 로컬 파일을 직접 읽어서 처리하기 때문
3. **단계별 생성 지시가 필수다** — 일괄 생성은 토큰 한도에 걸려 중간에 끊긴다
4. **미체결 처리는 비동기가 맞다** — 크론탭 환경에서 동기식 대기는 다음 실행 주기에 영향을 준다
