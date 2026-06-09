---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (1)(2) — Claude·ChatGPT·Gemini 협업으로 프롬프트 완성
date: 2026-05-31 01:24:00 +0900
categories: trading
tags: ai-trading prompt-engineering claude chatgpt gemini kiwoom python
author: Evan
description: Claude로 시작해서 토큰이 부족하면 ChatGPT와 Gemini로 넘기는 다중 AI 협업 방식으로 자동매매 프롬프트를 완성한 과정. Claude Pro 가입 후 V3 프롬프트 실행까지 기록한다.
---

**작성일**: 2026년 5월 31일  
**최종 수정**: 2026년 5월 31일  
**분야**: AI Trading, Prompt Engineering  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

자동매매 프로그램을 AI로 만들기로 했다. 처음에는 Claude 하나로 시작했지만, 작업량이 커지면서 토큰이 부족해졌다. 해결책은 **AI를 분업**시키는 것이었다.

- **Claude**: 초기 설계와 코드 작성
- **ChatGPT**: 프롬프트 최적화 및 영문 문서 기반 설명
- **Gemini**: 프롬프트 최종 검토 및 개선

---

## AI를 이용한 자동매매 프로그램 작성 (1) — 프롬프트 생성

### 진행 과정

1. Claude를 이용하여 시작
2. 토큰이 부족하여 Claude에서 작성된 프로그램을 바탕으로 ChatGPT, Gemini를 오가며 수정
3. 최종 프로그램 작성을 위한 프롬프트 생성 요청
4. 첨부 프롬프트 파일 `ultimate_p.txt`는 **ChatGPT**에서 작성
5. 첨부 프롬프트 파일 `KIWOOM_AUTO_TRADING_PROMPT_ADVANCED-1.txt`는 **Gemini**에서 작성

### Claude에 요청한 프롬프트 내용

2개의 프롬프트 파일을 첨부하고 아래 요구사항으로 업데이트된 한글·영문 스크립트 파일 생성을 요청했다.

**시스템 환경:**
- 서버: Oracle Cloud
- 운영체제: Ubuntu 22.04
- 구조: 기능별 하위 폴더로 구성

**주요 요청 사항:**
- Project structure 첨부 파일 참조
- Buy logic, sell logic 참조
- 2차 스크리닝 조건에 볼린저 밴드, 스토캐스틱 등 최근 많이 쓰이는 조건 추가
- 첨부파일 검토 후 제시된 7개 개선 방향 반영
- 추가 개선 사항 검토 후 반영

**문서 생성 요청:**
- 시스템 요구 사항 MD 파일
- `settings.yaml` 세부 설명 MD 파일
- 2차 스크리닝 조건 추가 방법 설명 MD 파일
- 각 스크리닝 조건 설명 MD 파일 (해당 폴더 내)
- 백테스트 시 CSV 파일 작성 방법 MD 파일
- 프로그램 실행 후 검토 사항 MD 파일
- AI가 만든 코드 위험성 검증 실전 점검표

**투자 일지 요청:**
- 매수·매도 발생 시 장 종료 후 투자 일지 파일 자동 업데이트
- **매수 시** 확인 내용: 보유 종목 종가 기준 수익률, 매수 조건 기록
- **매도 시** 확인 내용: 매도 이유 / 보유 기간 / 수익 금액 / 수익률

**최종 결과물:**
- 파이썬으로 제작된 프로그램을 하나의 압축 파일로 생성

---

### 첨부 파일

아래 파일들은 이 단계에서 생성된 프롬프트 파일이다.

- [ultimate_p.txt](/downloads/prompts/ultimate_p.txt) — ChatGPT에서 작성한 통합 프롬프트
- [KIWOOM_AUTO_TRADING_PROMPT_ADVANCED-1.txt](/downloads/prompts/KIWOOM_AUTO_TRADING_PROMPT_ADVANCED-1.txt) — Gemini에서 작성한 고급 프롬프트

---

## AI를 이용한 자동매매 프로그램 작성 (2) — Claude Pro 첫 실행

### 진행 과정

1. **Claude Pro 가입** — 토큰 한도 문제 해결을 위해 유료 플랜으로 전환
2. 작성(1)에서 완성한 프롬프트 실행
3. 한글·영문 프롬프트 파일 다운로드
4. 검토 후 crontab 실행 시간을 **15분**으로 변경
5. 영문 프롬프트에 MD 파일 및 코드 주석에 **한글 사용** 추가
6. 영문 프롬프트 파일을 이용해 프로그램 제작 요청
7. 한 번에 제작이 되지 않아 **프롬프트 파일을 순차 작업이 가능하도록 10개 파일로 분리** 요청

### 핵심 변경 내용

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| crontab 주기 | 5분 | **15분** |
| 코드 주석 | 영문 | **한글** |
| MD 파일 | 영문 | **한글** |
| 파일 구성 | 단일 프롬프트 | **10개 분리 파일** |

### 한 번에 생성이 안 되는 이유

30개가 넘는 파이썬 파일과 마크다운 문서를 한 번에 생성하면 AI의 출력 토큰 한도에 걸려 코드가 중간에 끊기거나 품질이 저하된다. 프롬프트를 10개 파일로 나눠 순차적으로 실행하는 방식으로 해결했다.

---

### 첨부 파일

- [KIWOOM_TRADING_PROMPT_V3_KR.txt](/downloads/prompts/KIWOOM_TRADING_PROMPT_V3_KR.txt) — 한글 프롬프트 V3
- [KIWOOM_TRADING_PROMPT_V3_EN.txt](/downloads/prompts/KIWOOM_TRADING_PROMPT_V3_EN.txt) — 영문 프롬프트 V3

---

## 다음 단계

다음 글에서는 Gemini의 프롬프트 검토 결과를 바탕으로 증권사 API를 한국투자증권(KIS)으로 확정하고, V4 프롬프트를 완성하는 과정을 기록한다.
