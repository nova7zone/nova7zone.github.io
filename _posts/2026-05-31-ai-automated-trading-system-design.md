---
layout: post
title: AI 를 이용한 자동매매 프로그램 작성(1) - 시스템 설계 & 프롬프트 전략
date: 2026-05-31 14:30:00 +0900
categories: trading
tags: ai-trading kiwoom-api system-design prompt-engineering python
author: Evan
description: Claude/ChatGPT/Gemini를 활용한 자동매매 시스템 요구사항 분석과 프롬프트 최적화 전략
---

## 메타데이터

| 항목 | 내용 |
|------|------|
| **작성일** | 2026-05-31 |
| **최종 수정일** | 2026-05-31 |
| **분야** | AI Trading System Design |
| **난이도** | Advanced |
| **상태** | Draft - 시스템 설계 단계 |

---

## 들어가며

자동매매 시스템을 AI로 구현하려던 처음 시도에서 Claude 만으로는 토큰이 부족했다. 

전략과 구현의 모든 세부사항을 한 번에 다루기에는 컨텍스트 윈도우가 좁았고, 반복적인 수정이 필요했다. 그래서 선택한 방법이 **다중 AI 도구의 강점을 조합**하는 것이었다.

- **Claude**: 초기 아이디어와 기본 구조
- **ChatGPT**: 프롬프트 최적화 및 영문 기술 문서 기반 설명
- **Gemini**: 한글로 된 상세한 구현 가이드 및 실명세 반영

이 글은 두 개의 최종 프롬프트(ChatGPT 버전, Gemini 버전)가 **무엇을 어떻게 요구하는지**, 그리고 그 차이가 **시스템 설계에 어떤 의미**를 가지는지 분석한다.

---

## Part 1: 자동매매 시스템의 핵심 요구사항

키움증권 REST API를 기반으로 하는 자동매매 시스템을 설계할 때, 가장 먼저 결정해야 할 것은 **실행 모델**이다.

### 1.1 Cron 기반 vs 데몬 구조

| 선택지 | Cron 기반 | 데몬 구조 |
|--------|---------|---------|
| **실행 방식** | 5분 주기 진입점(runner.py) | while True + sleep 루프 |
| **상태 관리** | Stateless (매 실행마다 초기화) | Stateful (메모리 유지) |
| **실패 복구** | 다음 cron 실행 대기 | 자체 복구 로직 필요 |
| **메모리 누수 위험** | 낮음 (프로세스 종료) | 높음 (지속 실행) |
| **서버 리소스** | 효율적 | 상대적으로 높음 |
| **디버깅** | 간편 (매 실행 독립적) | 복잡 (상태 추적 필요) |

우리가 선택한 **Cron 기반 모델**의 장점:

```
✅ 장기간 무인 운영에 적합
✅ 메모리 누수 문제 최소화
✅ 장애 발생 시 다음 실행에서 자동 복구
✅ 로그 분석 및 디버깅 용이
✅ Oracle Cloud 무료 티어의 제한된 리소스에 최적
```

### 1.2 실행 흐름

매 5분마다 실행되는 `runner.py`는 다음 순서로 동작한다:

```
1. 설정 로드 (settings.yaml)
2. 인증 토큰 확인 (OAuth2 토큰 갱신)
3. 1차 스크리닝 (유동성, 거래대금)
4. 2차 스크리닝 (조건별 점수 산출)
5. 매수 의사결정
6. 현재 보유 종목 검토
7. 매도 의사결정
8. 주문 실행
9. 리포트 생성
10. 프로세스 종료
```

**핵심**: 매 실행이 **독립적**이어야 하며, 이전 상태에 의존하지 않아야 한다.

---

## Part 2: ChatGPT 프롬프트 분석 (Production-Grade Architecture)

ChatGPT에서 생성된 `ultimate_p-1.txt`는 **아키텍처 원칙**에 중점을 두었다.

### 2.1 핵심 요구사항 (17개 섹션)

| 섹션 | 강조점 |
|------|--------|
| **1. Core Objective** | Cron 5분 주기, 단일 진입점(runner.py), 즉시 종료 |
| **3. Execution Model** | NO infinite loop, NO sleep, stateless |
| **4. Project Structure** | 기능별 폴더 분리 (api/, trading/, screening/) |
| **6. Screening & Scoring** | 조건 = 독립 Python 파일, evaluate() 함수 표준화 |
| **7. Preset System** | conservative/neutral/aggressive 프리셋 |
| **8. Buy Logic** | 최고 점수 종목만 선택, 중복 매수 방지 |
| **9. Sell Logic** | Stop-loss, Take-profit, 최대 보유 기간 |
| **10. Kiwoom API** | API 로직은 api/kiwoom_api.py에만 |
| **17. AI Failure Prevention** | 하드코딩, 무한 루프, 하드코딩된 시크릿 금지 |

### 2.2 프로젝트 구조 (ChatGPT 버전)

```
kiwoom-auto-trading-bot/
├── runner.py                    # 단일 진입점
├── requirements.txt
├── api/
│   └── kiwoom_api.py           # API 호출만
├── trading/
│   ├── buy.py
│   └── sell.py
├── screening/
│   ├── first_stage.py
│   └── conditions/
│       ├── __init__.py
│       ├── volume_spike.py
│       ├── ma_cross.py
│       └── (추가 조건)
├── backtest/
│   └── backtest_runner.py
├── report/
│   ├── daily_report.py
│   └── monthly_report.py
├── settings/
│   ├── settings.yaml
│   ├── secrets.yaml            # .gitignore에 포함
│   └── secrets.py
└── utils/
    └── time_utils.py
```

### 2.3 점수 시스템의 표준화

가장 중요한 설계 원칙:

```python
# conditions/ma_cross.py 예시
def evaluate(stock_data) -> int:
    """
    이동평균 교차 조건 평가
    - 조건 만족 시: 양수 점수 반환
    - 미충족 시: 0 반환
    """
    if stock_data['ma_20'] > stock_data['ma_50']:
        return 10  # 점수
    return 0
```

**이 표준화가 중요한 이유**:
- 조건 파일을 독립적으로 추가/제거 가능
- runner.py는 조건 로직 몰라도 됨
- 각 조건의 가중치를 settings.yaml에서만 관리

---

## Part 3: Gemini 프롬프트 분석 (구현 세부사항)

Gemini에서 생성된 `KIWOOM_AUTO_TRADING_PROMPT_ADVANCED-1-1.txt`는 **구현 수준의 세부사항**을 강조한다.

### 3.1 한글 프롬프트의 추가 요구사항

| 항목 | 요구사항 |
|------|---------|
| **코드 품질** | 모듈 docstring, 함수별 상세 주석, type hint 필수 |
| **테스트** | unittest/pytest, 실제 주문은 mock 처리 |
| **API 실명세** | OAuth2 토큰 자동 갱신, 재시도 로직 |
| **에러 처리** | 로그 기록(logs/), API 타임아웃 재시도 |
| **백테스트** | mode: live/paper/backtest 전환 가능 |
| **리포트** | 월별 수익률, MDD, 승률, 거래 횟수 |

### 3.2 Gemini가 강조한 파일 구조

```
project/
├── runner.py
├── settings/
│   ├── settings.yaml        # 전략 설정
│   ├── presets/
│   │   ├── conservative.yaml
│   │   ├── neutral.yaml
│   │   └── aggressive.yaml
│   └── secrets.yaml         # .gitignore 포함
├── api/
│   ├── kiwoom_api.py        # OAuth2, 재시도 로직
│   └── base.py              # 추상 클래스
├── screening/
│   ├── first_stage.py
│   └── conditions/
│       ├── bollinger_band.py     # 새로 추가
│       ├── stochastic.py         # 새로 추가
│       └── (기타)
├── tests/                       # 테스트 폴더
│   ├── test_api.py
│   ├── test_screening.py
│   └── test_trading.py
├── logs/                        # 실행 로그
│   └── app.log
└── docs/                        # 문서
    ├── INSTALL.md
    ├── USAGE.md
    └── README.md
```

### 3.3 Gemini 프롬프트의 핵심 추가사항

**1) OAuth2 토큰 관리**
```
- access token 자동 발급
- 토큰 만료 시 자동 재발급
- 토큰 갱신 실패 시 로그 기록 후 종료
```

**2) 재시도 로직**
```
API 호출 실패 시 최대 3회 재시도
- 1차: 즉시
- 2차: 1초 대기 후
- 3차: 2초 대기 후
- 3회 실패 시 로그 + 종료
```

**3) 테스트 기반 개발**
```python
# tests/test_screening.py
class TestScreening(unittest.TestCase):
    def test_ma_cross_condition(self):
        # 실제 데이터 대신 fixture 사용
        mock_data = {...}
        result = evaluate(mock_data)
        self.assertEqual(result, 10)
```

---

## Part 4: 두 프롬프트의 차이점과 의미

### 4.1 비교 분석

| 구분 | ChatGPT | Gemini | 의미 |
|------|---------|--------|------|
| **언어** | 영문 | 한글 | 국제 vs 로컬 표준 |
| **추상화 수준** | 아키텍처 | 구현 세부 | 개념 vs 실행 |
| **API 처리** | 기본 설명 | 실명세(OAuth2) | 이론 vs 실전 |
| **테스트** | 언급 없음 | unittest/pytest 필수 | 문서 vs 검증 |
| **에러 처리** | 기본 | 재시도 + 로그 | 심플 vs 견고 |
| **문서** | README, USAGE | README, INSTALL, USAGE | 소수 vs 상세 |

### 4.2 왜 두 프롬프트를 모두 사용하나?

```
ChatGPT 프롬프트 역할:
├─ ✅ "시스템을 어떻게 설계할 것인가"
├─ ✅ "폴더 구조는 어떻게 할 것인가"
└─ ✅ "아키텍처 원칙은 무엇인가"

Gemini 프롬프트 역할:
├─ ✅ "각 파일에서 구체적으로 무엇을 구현하는가"
├─ ✅ "API 호출 시 실제로 어떻게 처리하는가"
└─ ✅ "테스트와 에러 처리는 어떻게 하는가"

결론: 상위 설계(ChatGPT) + 하위 구현(Gemini) = 완성도 높은 시스템
```

---

## Part 5: 시스템 아키텍처 선택의 이유

### 5.1 왜 Cron + Stateless인가?

**키움증권의 제약사항**:
- REST API는 세션 기반이 아님
- 매 요청마다 OAuth2 토큰으로 인증
- 토큰은 시간 제한이 있음

**우리의 선택**:
```
매 5분마다 새로운 프로세스 시작
├─ 토큰 재발급 자동 처리
├─ 상태 초기화 (메모리 누수 X)
├─ 장애 자동 복구
└─ 로그 분석 용이
```

### 5.2 왜 조건을 독립 파일로 분리하나?

```python
# 운영 중 새 조건 추가 (runner.py 수정 없음)

# 1단계: 새 파일 생성
screening/conditions/rsi_divergence.py
def evaluate(stock_data) -> int:
    ...

# 2단계: settings.yaml 업데이트
conditions:
  - name: rsi_divergence
    weight: 8
    enabled: true

# 3단계: 다음 cron 실행부터 자동 적용
# runner.py는 변경 없음!
```

이 구조의 장점:
- 코드 배포 없이 조건 추가 가능
- 서버 재시작 불필요
- 프로덕션 환경에서 즉시 테스트 가능

### 5.3 프리셋 시스템의 의미

```yaml
# presets/aggressive.yaml
strategy:
  name: aggressive
  conditions:
    - ma_cross: 10
    - volume_spike: 8
    - bollinger_band: 6
  min_score: 15           # 보수적(25) < 중립(20) < 공격적(15)
  max_positions: 5
  capital_per_trade: 2000000
  stop_loss_pct: 2.0
  take_profit_pct: 5.0
```

**프리셋을 사용하는 이유**:
- 시장 상황에 따라 전략 전환 (settings.yaml 한 줄 변경)
- 조건 가중치 조정 (코드 수정 없음)
- A/B 테스트 가능 (보수 vs 공격)
- 백테스트에서 최적 프리셋 찾기 가능

---

## Part 6: 투자 일지 관리 구조

매수/매도 시 자동으로 업데이트할 투자 일지의 구조:

### 6.1 매수 기록

```
일시: 2026-06-01 10:15:00
종목: 삼성전자 (005930)
수량: 10주
매수가: 70,000원
총액: 700,000원
매수 조건:
  - MA(20) > MA(50): ✓ (가중치 10)
  - 거래량 급증: ✓ (가중치 8)
  - 볼린저 밴드 하단: ✓ (가중치 6)
  - 종합 점수: 24점 (threshold: 20)
초기 투자비용: 700,000원
```

### 6.2 매도 기록

```
일시: 2026-06-05 14:45:00
종목: 삼성전자 (005930)
수량: 10주
매도가: 72,500원
총액: 725,000원
보유 기간: 4일
매도 이유:
  - Take-profit 5% 도달 (설정값: 5.0%)
  - 예상 수익률: +3.57%
매도 수익금: 25,000원
수익률: 3.57%
```

### 6.3 자동화 흐름

```python
# report/investment_journal.py
def record_buy(symbol, quantity, price, conditions_met):
    """매수 기록"""
    entry = {
        'timestamp': datetime.now(),
        'symbol': symbol,
        'action': 'BUY',
        'conditions': conditions_met,
        'initial_cost': quantity * price
    }
    write_to_csv('investment_journal.csv', entry)

def record_sell(symbol, quantity, price, hold_days, reason):
    """매도 기록"""
    entry = {
        'timestamp': datetime.now(),
        'symbol': symbol,
        'action': 'SELL',
        'hold_days': hold_days,
        'sell_reason': reason,
        'profit_pct': (price - buy_price) / buy_price * 100
    }
    write_to_csv('investment_journal.csv', entry)
```

---

## Part 7: 다음 단계 (시리즈 예정)

이 글(Part 1)은 **시스템 설계와 요구사항 분석**을 다루었다.

다음 포스트들의 로드맵:

```
(2) Python 환경 구성
    - venv 가상환경 (이전 포스트 참고)
    - requirements.txt 상세 설명
    - Oracle Cloud Ubuntu 22.04 설정

(3) 프로젝트 구조 & 설정 파일
    - settings.yaml 상세 해석
    - secrets.yaml 보안 관리
    - presets 프리셋 설계

(4) 1차/2차 스크리닝 구현
    - 유동성 필터 (1차)
    - MA 교차 (2차)
    - 볼린저 밴드, 스톡캐스틱 (2차)

(5) 실제 매매 로직
    - buy.py 구현
    - sell.py 구현
    - Stop-loss / Take-profit

(6) API 통합 & OAuth2
    - Kiwoom REST API 인증
    - 토큰 관리
    - 주문 실행

(7) 테스트 & 백테스트
    - unittest/pytest 작성
    - CSV 기반 백테스트
    - 성과 분석 (수익률, MDD, 승률)

(8) 배포 & 운영
    - Crontab 설정
    - 로그 관리
    - 모니터링 & 알림
```

---

## 마무리

AI로 자동매매 시스템을 설계할 때, **단일 도구로는 부족**했다. 

ChatGPT의 깔끔한 아키텍처와 Gemini의 실명세 구현 가이드를 결합함으로써, 프로덕션 수준의 시스템을 설계할 수 있었다.

다음 포스트부터는 **실제 코드 구현**으로 들어간다. 두 프롬프트가 요구하는 기준을 만족하면서도, Oracle Cloud의 제한된 리소스 내에서 안정적으로 동작하는 시스템을 만드는 것이 목표다.

---

## 📥 프롬프트 다운로드

이 포스트에서 사용된 원본 AI 프롬프트 파일들입니다.

| 파일명 | 생성 도구 | 용도 |
|--------|---------|------|
| **ultimate_p-1.txt** | ChatGPT | 영문 아키텍처 프롬프트 |
| **KIWOOM_AUTO_TRADING_PROMPT_ADVANCED-1-1.txt** | Gemini | 한글 구현 가이드 프롬프트 |

**저장 위치**: `repository/downloads/prompts/` 폴더

**다운로드 방법** (모바일):
1. GitHub 저장소 접속 → nova7zone/nova7zone.github.io
2. Code 탭 → downloads → prompts 폴더 이동
3. 각 `.txt` 파일 클릭 → 우상단 **Raw** 버튼 클릭
4. 길게 누르기 → 저장 또는 복사

**사용 방법**:
- 각 프롬프트를 해당 AI 도구(ChatGPT, Gemini)에 입력
- 실제 프로젝트 구현 시 설계 기준으로 활용
- 조건 추가, 프리셋 수정 등에 참고

---

## 참고자료

### 공식 문서
- [Kiwoom REST API 문서](https://openapidocs.kiwoom.com/)
- [Python unittest](https://docs.python.org/3/library/unittest.html)
- [YAML 문법](https://yaml.org/spec/1.2/spec.html)
- [OAuth 2.0](https://oauth.net/2/)

### 이전 포스트
- [Oracle Cloud 무료 티어 인스턴스 운영하기](https://nova7zone.github.io/2026/05/29/oracle-cloud-server-setup.html)

```
🔵 (1) 시스템 설계 & 프롬프트 전략
   ├─ 요구사항 분석
   ├─ 아키텍처 설계
   ├─ 두 프롬프트의 역할
   └─ [현재 글]

🔲 (2) Python 환경 구성
   ├─ venv 가상환경
   ├─ requirements.txt
   └─ Ubuntu 22.04 설정

🔲 (3) 프로젝트 구조 & 설정
   ├─ 폴더 구조 생성
   ├─ settings.yaml 상세 해석
   └─ secrets.yaml 보안 관리

🔲 (4) 1차/2차 스크리닝 구현
   ├─ 유동성 필터
   ├─ MA 교차, 거래량 급증
   └─ 볼린저 밴드, 스톡캐스틱

🔲 (5) 실제 매매 로직
   ├─ buy.py 구현
   ├─ sell.py 구현
   └─ Stop-loss / Take-profit

🔲 (6) API 통합 & OAuth2
   ├─ Kiwoom REST API 인증
   ├─ 토큰 관리
   └─ 주문 실행

🔲 (7) 테스트 & 백테스트
   ├─ unittest/pytest
   ├─ CSV 백테스트
   └─ 성과 분석

🔲 (8) 배포 & 운영
   ├─ Crontab 설정
   ├─ 로그 관리
   └─ 모니터링
```
