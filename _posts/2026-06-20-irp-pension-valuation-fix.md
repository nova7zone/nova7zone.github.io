---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (25) — IRP 퇴직연금 평가금액 보정 3단계
date: 2026-06-20 12:00:00 +0900
categories: trading development
tags: ai-trading kis-api python claude-code
author: Evan
description: IRP 계좌는 일반 잔고조회로는 예수금과 디폴트옵션 평가금액을 알 수 없어 화면에 실제보다 낮게 표시되고 있었다. KIS 퇴직연금 전용 API를 연동하고, 그 과정에서 만난 output2 인덱싱 버그와 만료 토큰 500 응답을 거쳐 결국 디폴트옵션 자산은 KIS API 자체가 제공하지 않는다는 결론에 도달해 수동 입력 기능으로 마무리한 과정을 정리한다.
---

**작성일**: 2026년 6월 20일  
**최종 수정**: 2026년 6월 20일  
**분야**: AI Trading, Development  
**난이도**: Advanced  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/atr-filter-and-account-valuation/)에서 계좌별 원금/평가금액/수익률 표시 기능을 추가했다. 6월 20일은 그 기능을 IRP(개인형퇴직연금) 계좌에 적용하면서 시작된 **세 단계짜리 추적기**였다.

결론부터 말하면, IRP 계좌는 일반 국내주식잔고조회로는 예수금과 디폴트옵션(펀드) 평가금액을 알 수 없어 화면에 실제보다 낮은 금액이 표시되고 있었다. KIS 퇴직연금 전용 API를 연동해 1차 보정을 했는데, 곧 인덱싱 버그를 만났고, 그걸 고친 뒤에도 디폴트옵션 자산만은 여전히 반영되지 않았다. 끝까지 추적한 결과 **KIS Open API 자체가 디폴트옵션 자산 정보를 제공하지 않는다**는 구조적 한계로 결론이 났고, 결국 수동 입력 기능으로 마무리했다.

---

## 1단계: IRP 계좌 평가금액 보정 + 계좌별 보유종목 상세 페이지

IRP 계좌는 일반 잔고조회(`TTTC8434R`)로는 예수금·디폴트옵션 평가금액을 조회할 수 없어 `/accounts`의 평가금액이 실제보다 낮게 표시되고 있었다. KIS 퇴직연금 전용 API 2개(잔고조회 036/`TTTC2208R` 예수금, 체결기준잔고 032/`TTTC2202R` 디폴트옵션 포함 보유상품 평가금액 합계)를 묶은 `KISApiClient.get_pension_balance()`를 추가해 두 값을 더한 정확한 총평가금액을 산출하도록 했다.

- `utils/reconcile.py::_reconcile_extra_account()`에 `acnt_prdt_cd == "29"`(IRP) 분기 추가 — 보유종목 동기화는 기존 `get_balance()` 그대로, 평가금액 저장 값만 `get_pension_balance()` 결과로 교체
- 태스크 리뷰에서 `get_pension_balance()`가 `self.mode` 확인 없이 호출되면 paper 모드 클라이언트가 실전 전용 TR을 paper 호스트로 잘못 보낼 수 있다는 걸 발견 — `self.mode != "live"`면 즉시 0-디폴트를 반환하는 가드 추가
- `/accounts` 계좌 레이블 클릭 시 `/accounts/{account_id}`로 이동하는 신규 페이지 추가 — DB의 매수가/매수량/매수금액에 KIS 실시간 시세를 더해 현재가/평가금액/수익률 계산, 종목 단위 조회 실패는 해당 행만 "—" 처리

`pytest tests/` 525개 전체 통과(519 → 525, +6).

---

## ❌ 2단계: get_pension_balance() output2 인덱싱 버그

PR #40 머지 후 OCI에서 `--reconcile`을 실행한 로그에 `IRP 평가금액 조회 실패 (무시) | extra_02 | 0`이 찍혀 있었다. `str(KeyError(0)) == "0"`과 정확히 일치하는 데 착안해 추적했다.

KIS 공식 샘플코드를 확인해보니 퇴직연금 잔고조회(036)는 `pd.DataFrame(output2, index=[0])`로 **output2가 단일 dict**임을 명시하고 있었다. 그런데 `get_pension_balance()`는 체결기준잔고(032, output2가 실제 배열)와 똑같이 `summary1[0]` 배열 인덱싱을 적용해서, dict에 정수 키 `0`으로 접근하다 `KeyError(0)`이 발생하고 있었다. 이 예외는 메서드의 `except (ValueError, TypeError, IndexError)`에 포함되지 않아 전파되다 `reconcile.py` 상위 `except Exception`에서 잡혀 `total_eval=0`으로 떨어진 것이었다(크래시는 없었지만, 보정 기능 자체가 매번 무효화되고 있었다).

- 036 파싱만 dict 직접 접근으로 수정(032는 원래도 정상이라 변경 없음)
- 내부 `except` 튜플에 `KeyError` 추가(방어적 보강)
- 운영 환경의 실제 응답 모양을 재현하는 회귀 테스트 추가 + 기존 mock 응답도 실제 구조로 교정

`pytest tests/` 526개 전체 통과(525 → 526, +1).

---

## 3단계: 디폴트옵션은 수동 입력으로 — KIS API의 구조적 한계

1·2단계 수정을 적용했는데도 "디폴트옵션으로 매수된 자산은 반영 안 됨" 재보고가 들어왔다. 추적해보니 더 깊은 문제가 있었다.

- **진단 로그 추가 후 재현 시도**: `TTTC8434R`/`TTTC2208R` 둘 다 500 에러가 발생했는데, 응답 본문을 직접 확인해보니 `{"rt_cd":"1","msg_cd":"EGW00123","msg1":"기간이 만료된 token 입니다."}` — **KIS가 만료된 토큰을 401이 아니라 500으로도 응답한다**는 걸 처음 발견했다. `_request_full()`은 401만 토큰 재발급 트리거로 인식해서, 무효한 토큰으로 3회 재시도만 반복하고 있었다. 이 부분은 별도 수정(PR #43, 회귀 테스트 3개)으로 먼저 처리했다.
- **수정 배포 후 032(체결기준잔고) 실제 응답 확보**: 보유종목 6건 전부 `잔고구분='사용자'`(일반 ETF)였고, 디폴트옵션 펀드는 행 자체가 없었다. KIS 퇴직연금 API 5종(036/032/033/034/035) 전체를 공식 샘플코드와 대조한 결과, **어느 것도 디폴트옵션 자산을 제공하지 않는다**는 게 확인됐다. 파싱 버그가 아니라 KIS Open API 자체의 구조적 한계였다.

그래서 수동 입력 기능을 만들기로 했다. brainstorming → 설계(`docs/superpowers/specs/2026-06-20-irp-manual-asset-eval-design.md`) → 계획 → 5개 Task로 `subagent-driven-development` 진행했다.

- `accounts` 테이블에 `manual_asset_eval`/`manual_asset_updated_at` 컬럼 추가
- `compute_irp_total_eval()` 공용 함수로 cash(036) + ETF(032) + 수동입력값을 합산, `reconcile.py` 일일 배치(평일 15:40)에 연동
- `POST /api/config/extra-accounts/{account_id}/manual-asset` API — 저장 직후 즉시 재계산해 배치 주기와 무관하게 `/accounts`에 바로 반영
- `/accounts/{account_id}` 페이지에 모든 계좌 공통 예수금 표시 + IRP 계좌에만 디폴트옵션 입력 폼 추가

최종 리뷰에서 기록만 해둔 사실 하나: `get_pension_balance()`가 실제로는 예외를 던지지 않고 항상 zero-default를 반환해서, "예외 전파 → 웹 500"이라는 기존 설계 의도가 운영에서는 한 번도 발동하지 않고 있었다. 정확성에는 무해해서 수정 없이 기록만 남겼다.

`pytest tests/` 549개 전체 통과(526 → 549, +23).

---

## 정리

| 단계 | 발견 | 조치 |
|------|------|------|
| 1단계 | IRP는 일반 잔고조회로 예수금/디폴트옵션 확인 불가 | 퇴직연금 전용 API(036/032) 연동 |
| 2단계 | output2 dict를 배열처럼 인덱싱 → KeyError(0) | dict 직접 접근으로 수정 |
| 3단계 | 디폴트옵션 자산은 KIS API 5종 어디에도 없음(API 자체 한계) | 수동 입력 기능으로 대체 |
| 부수 발견 | KIS가 만료 토큰을 500으로도 응답 | 500 응답도 토큰 재발급 트리거로 인식하도록 수정 |

세 단계 모두 "고쳤다고 끝나지 않고 다음 증상이 나온" 케이스였는데, 마지막엔 "버그가 아니라 API 자체의 한계"라는 결론에 도달해서야 끝났다. 코드만 들여다봐서는 알 수 없고, 실제 KIS 공식 샘플과 대조해야 확인할 수 있는 종류의 한계였다.

다음 글에서는 같은 날 이어서 진행한 **추가 계좌 오삭제 방지, position_registry REVIVE 로직, 문서 전체 최신화, v0.5.1 릴리즈**를 다룬다.
