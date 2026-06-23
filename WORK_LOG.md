# 작업 로그 (세션 인계용)

새 세션을 시작할 때 이 파일을 먼저 읽고, 어디까지 진행됐는지 파악한 뒤 이어서 작업한다.
작업을 종료할 때는 이 파일의 "현재 상태"와 "다음에 할 일"을 갱신한다.

---

## 2026-06-23 세션 — 자동매매 봇 개발기 시리즈 #18~#32 (15편) 작성

### 배경

`kis-auto-trading-bot` 프로젝트(별도 레포)의 개발 기록을 블로그 시리즈로 옮기는 작업.
마지막으로 발행된 시리즈 글은 `_posts/2026-06-14-v2-settings-api-and-security-hardening.md`(#17, 6/14 작업분)였고,
그 이후 6/15~6/23 사이 쌓인 작업이 아직 블로그에 반영되지 않은 상태였음.

소스 자료(원본 레포, 이 블로그 레포가 아님):
- `H:\개인자료\github\kis-auto-trading-bot\build-docs\work-log.md` (1~2148번째 줄, 6/15~6/23 구간) — **1차 소스**
- `H:\개인자료\github\kis-auto-trading-bot\build-docs\blog-progress-summary.md`는 6/7자 이후 갱신 안 됨, 참고하지 않음

### 한 일

work-log.md의 6/15~6/23 구간(약 65개 작업 항목)을 시간순으로 15편으로 나눠 작성.
사용자가 처음엔 "한 편으로" 요청했으나 "그건 아니다, 시간순으로 15개로 나눠 작성해달라"고 정정 → 분량 배분 표를 먼저 제시해 승인받은 뒤 작성.

**모두 `_posts/draft/`에 작성 완료, 아직 `_posts/`로 옮기지 않음. 아직 review 전.**

| # | 파일명 | 날짜 | 제목(부제) | 본문 글자수 |
|---|--------|------|------------|------------|
| 18 | 2026-06-15-extra-account-capital-and-release-notes-skill.md | 6/15 | 추가 계좌 투자원금 입력 기능, 릴리즈 노트 작성 skill | 2,798 |
| 19 | 2026-06-15-strategy-flow-page-and-mermaid-bugfixes.md | 6/15 | 전략확인 페이지 신설, Mermaid 렌더링 버그 2건 | 3,758 |
| 20 | 2026-06-16-premarket-optimization-and-order-fill-pr29.md | 6/16 | pre-market API 최적화, 주문 체결 검증 개선 (PR #29) | 2,519 |
| 21 | 2026-06-17-v2-settings-cards-and-next-premarket-split.md | 6/17 | 매매설정 v2 카드 확장(3·4단계), next-pre-market 분리 | 4,078 |
| 22 | 2026-06-18-volume-rank-pagination-saga.md | 6/18 | 거래량순위 페이지네이션 추적기, universe 60 확정까지 | 4,083 |
| 23 | 2026-06-18-foreign-cumulative-and-pooled-buy-flow.md | 6/18 | foreign_cumulative 실구현, v2 풀링 매수 전환 | 4,386 |
| 24 | 2026-06-19-atr-filter-and-account-valuation.md | 6/19 | ATR 필터 hard block 제거, 계좌별 원금/평가금액/수익률 표시 | 2,743 |
| 25 | 2026-06-20-irp-pension-valuation-fix.md | 6/20 | IRP 퇴직연금 평가금액 보정 3단계 | 4,110 |
| 26 | 2026-06-20-account-sync-revive-and-v051-release.md | 6/20 | 추가계좌 오삭제 방지, REVIVE 로직, v0.5.1 릴리즈 | 4,362 |
| 27 | 2026-06-21-oci-infra-fixes-and-db-browser.md | 6/21 | OCI 운영 인프라 결함 2건, DB 조회 페이지 신설 | 4,461 |
| 28 | 2026-06-21-web-backtest-investigation-and-v052-release.md | 6/21 | 웹 백테스트 사전조사, 모의투자 매도 실패 분석, v0.5.2 릴리즈 | 3,565 |
| 29 | 2026-06-21-web-backtest-implementation-and-bugfixes.md | 6/21 | 웹 백테스트 구현(PR #52), 경로탈출 수정, 30일 하드캡 추적기 | 5,430 |
| 30 | 2026-06-22-order-fill-holdings-diff-bug.md | 6/22 | 매수 무한반복 사고, 체결판단 holdings-diff 전환 | 5,665 |
| 31 | 2026-06-23-broker-sync-and-oci-automation.md | 6/23 | 본계좌 실시간 잔고 동기화, v2 백테스트 국면전환, OCI 자동화 | 6,696 |
| 32 | 2026-06-23-docs-sync-and-v060-release.md | 6/23 | 문서 전체 점검, docs-sync 19개 문서 재작성, v0.6.0 릴리즈 | 5,212 |

각 글은 `[이전 글](/posts/{slug}/)` / `다음 글에서는 ...`로 서로 연결되어 있고, #18은 기존 #17(v2-settings-api-and-security-hardening)을 이어받음.

### 현재 상태 (2026-06-24 세션에서 갱신)

- **게시 완료.** 후속 세션에서 `_posts/`와 `_posts/draft/` 간 중복 내용 점검(중복 없음 확인) 후, 15편 전체를 `_posts/draft/` → `_posts/`로 이동.
- `bundle exec jekyll build`로 빌드 에러 없음 확인(35개 글 전체 정상 생성, 신규 15개 슬러그 포함) → 커밋 `63589c5`(`feat: add posts (18)-(32) for AI trading bot development series`) → `main` push → GitHub Actions(`Build and Deploy`, run `28061850275`) **success** 확인.
- #31(6,696자), #32(5,212자) 분량 축소는 결국 진행하지 않고 원문 그대로 게시함(사용자가 별도 축소 요청 없이 게시 진행 승인).
- 스크린샷/이미지 추가는 없었음 (코드/로그 기반 시리즈라 이미지 불필요).

### 다음에 할 일

1. work-log.md(`H:\개인자료\github\kis-auto-trading-bot\build-docs\work-log.md`)에서 6/23 이후 새로 쌓인 작업이 있으면 그 다음 시리즈(#33~)로 이어서 작성
2. `_posts/raw/complete/Upbit_auto_rading.md`(별도 프로젝트, Upbit 가상화폐 봇) 처리 필요 여부 확인 — 아직 untracked 상태로 방치 중

### 참고 메모

- `_posts/raw/complete/Upbit_auto_rading.md`는 이번 시리즈와 무관한 별도 프로젝트(Upbit 가상화폐 봇) 컨텍스트 문서 — 아직 untracked 상태로 남아있음, 처리 필요 여부는 별도 확인 필요.
