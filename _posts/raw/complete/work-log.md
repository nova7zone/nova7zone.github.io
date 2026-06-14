# 작업 이력 (Work Log)

커밋 메시지 기반으로 작업 내용을 기록합니다.
작업 종료 시 커밋 메시지를 아래에 복사해서 추가하세요.

---

## 2026-06-14 (추가5) — next-tasks #1 보류 기록 + crontab 변경 절차 문서화

```
docs: 부분체결 검증(next-tasks #1) 다음 세션 진행 방식 기록
docs: 서버 업데이트 절차에 crontab 항목 추가/변경 섹션 추가
```

- `next-tasks.md`: Critical #1(미체결→체결 판단 시 부분체결 미검증)에 다음 세션
  진행 방식 기록 — `trading/order_manager.py`/`api/kis_api.py` 실계좌 매매 로직
  수정이므로 CLAUDE.md 5단계(clarify→design→plan→code→verify) 준수,
  `superpowers:brainstorming`으로 KIS 주문체결내역조회 API(TR ID) 조사부터 시작.
  이번 세션에서는 착수하지 않고 보류.
- `docs/UPDATE.md`: STEP 5에 "E. crontab 항목 추가/변경" 섹션 신규 추가 —
  `INSTALL.md` 기준 4개 기본 cron 항목 + `active_strategy_version: v2` 전환 시
  필요한 `--pre-market` 항목, 등록 확인 방법, 변경 유형별 추가 작업 표·주의사항에
  crontab 관련 행 보강

---

## 2026-06-14 (추가4) — 전체 점검 Medium 항목 일괄 수정 (5건)

```
fix: JSON/인증 파일 권한 강화, 설정 파일 심볼릭 링크 검증, YAML 치환 안전화
```

- `utils/file_utils.py`: 공용 `apply_secure_permissions()` 추가 — `save_json_locked()`의
  `os.replace()` 직후 `chmod 600` 적용 (holdings.json, pending_orders.json 등 전체) — next-tasks #5
- `web/routers/config_router.py`:
  - `/api/config/file` GET/POST에 `_is_safe_path()` 추가 — `Path.resolve()`로
    프로젝트 루트 밖 심볼릭 링크 우회 차단 — next-tasks #6
  - `_write_*_key`/`_write_top_level_key`의 `re.sub` 치환을 `lambda m: m.group(1) + value`로
    변경 — value의 `\`/`$` 백레퍼런스 오해석 방지 — next-tasks #7
- `web/auth/router.py`: `_save_auth()`에 `apply_secure_permissions()` 적용
  (`data/web_auth.json` TOTP 시크릿 `chmod 600`) — next-tasks #8
- `next-tasks.md` #9(`_is_expired` KST 처리) 재검토 — timezone-aware 비교로 이미
  정상 동작함을 확인, 위험 아님으로 정리
- `pytest tests/` 408개 전체 통과

---

## 2026-06-14 (추가3) — 세션 쿠키 보안 강화 + 로그인 brute-force 방지

```
fix: 세션 쿠키 보안 속성 추가 및 로그인 잠금 정책 적용
```

- `web/main.py`: `SessionMiddleware`에 `same_site="strict"` 적용,
  `https_only`를 `WEB_SESSION_HTTPS_ONLY` 환경변수로 제어(기본 `false`)
- `web/auth/router.py`: `data/web_auth.json`에 `failed_attempts`/`locked_until`
  필드 추가 — 5회 연속 로그인 실패 시 15분 전역 잠금, 성공 시 초기화
- `.env.example`: `WEB_SESSION_HTTPS_ONLY` 추가
- `docs/WEBSERVICE_DEPLOY.md`: Phase 4(nginx+HTTPS) 완료 후
  `WEB_SESSION_HTTPS_ONLY=true` 설정 안내 추가
- `tests/test_web_auth.py` 신규(5개 케이스), `pytest tests/` 408개 전체 통과
- `next-tasks.md` 항목 #3, #4 완료 처리

---

## 2026-06-14 (추가2) — docs 최신화 + 전체 실행/보안 점검

```
docs: 문서 최신화 및 전체 최종 업데이트 시각 기록
```

- docs: `docs/*.md` 18개 파일 전체 최신성 검증 후 수정
  - `AI_CODE_SAFETY_CHECKLIST.md`: API 레이어 경로를 strategy_v1/v2 + order_manager.py로 수정
  - `CONDITIONS_GUIDE.md`: v1/v2 조건 구성 설명 및 HOW_TO_ADD_CONDITION_V1/V2 상호링크 추가
  - `USAGE.md`: `active_strategy_version`이 v1/v2 모두 가능함을 명시
  - `WORKFLOW.md`: v2 설정 경로·엔드포인트(`/api/config/first-stage`, `profile` 파라미터) 보강,
    다이어그램이 v1 기준임을 명시하고 TRADING_FLOW의 v2 섹션 참조 추가
  - 전체 `docs/*.md`의 `> 최종 업데이트`를 날짜+시간(KST) 형식으로 통일 갱신
  - PR #24 작업 일부(`HOW_TO_ADD_CONDITION.md` → V1/V2 분리, `APP_SETTINGS.md`/
    `TESTING_GUIDE.md` 신설, `.env.example`/`README.md` 보강)도 함께 커밋
- GitHub Release `v0.4.2` (Draft, "매매설정 v2 카드 확장 (2단계)") 작성, PR #24 생성

**전체 실행/보안 점검 수행** (코드 변경 없음, 결과는 `next-tasks.md` 참고):
- `runner.py`/`trading/order_manager.py`/`api/kis_api.py` 핵심 실행 경로,
  `web/` 대시보드 보안(인증·세션·설정 API), 시크릿·파일권한 3개 영역을
  Explore 서브에이전트로 병렬 점검
- Critical/High 4건(부분체결 미검증, runner.lock 정체, 세션 쿠키 보안속성,
  로그인 brute-force 미방지) + Medium 5건 발견 — `next-tasks.md`에 우선순위별 기록

## 2026-06-14 (추가) — 매매설정 v2 카드 프론트엔드 + init 연결

```
feat: 매매설정 v2 카드 init 연결 + 작업 이력 갱신
```

- feat: `web/routers/config_router.py`
  - `_PARAM_LABELS`/조건 라벨에 v2 신규 조건 포함 총 20개 조건 한글 라벨 추가
  - `/api/config/screening-strategy` GET/PATCH에 `profile` 쿼리 파라미터 추가 —
    v2의 5개 2차 스크리닝 프로파일(balanced 등) 개별 조회/저장 지원
- feat: `web/templates/settings.html`
  - v2 전용 카드 3종 신설: 시장필터(`levels.*` 4단계), 1차스크리닝(A/B/C/D 4그룹),
    2차스크리닝(5프로파일 선택 편집) — `initMarketFilterV2`/`initFirstStageV2`/
    `initScreeningV2` 메서드와 함께 `x-show`로 v1/v2 카드 분기
  - `init()`/`setStrategyVersion()`에서 중복되던 v1 init 호출부를 공용 헬퍼
    `initStrategyConfigCards()`로 통합 — `strategyVersion`에 따라 v1/v2 init 메서드
    자동 분기 호출

검증:
- `python -c "from jinja2 import ...; env.get_template('settings.html')"` — 템플릿 문법 오류 없음
- `pytest tests/` 403개 전체 통과 (회귀 없음, Python 코드 변경 없음)
- **OCI/로컬 `/setup` 후 수동 검증 필요**: `/settings` → 매매설정 탭에서 v1/v2
  토글 시 카드 전환, v2 카드 3종 표시·저장·재조회 확인 (로컬 TOTP 미설정으로
  브라우저 검증 미진행)
- strategy_v1 내부 파일 미수정 (읽기 전용 원칙 유지)

이로써 `docs/superpowers/plans/2026-06-14-trading-settings-v2-cards.md` 7개 Task 전체 완료.

---

## 2026-06-14 — 매매설정 API v2 시장필터/1차스크리닝 버전 분기 + 개발요청서 DB 참조 보강

```
feat: 매매설정 API에 strategy_v2 시장필터/1차스크리닝 버전 분기 추가

market-filter/first-stage 엔드포인트가 active_strategy_version=v2일 때
levels.*/groups.* 구조(first_stage_groups.yaml)를 읽고 쓰도록 분기 처리하고,
중첩 키 치환용 _write_nested_scalar 헬퍼를 추가해 주석/포맷을 보존한다.
_allowed_yaml_files에 v2 상위 설정 파일 5개도 노출하도록 확장.

v2 웹 설정 확장 개발요청서(DEV_REQUEST_v2_TRADING_SETTINGS.md)를 추가하고
DB 참조 사항(accounts/position_registry) 섹션을 포함했다.
```

- feat: `web/routers/config_router.py`
  - `_write_top_level_key()`, `_write_nested_scalar()` 신설 — 정규식 + 2-space
    들여쓰기 추적 방식으로 최상위/중첩 YAML 스칼라 치환, 주석·포맷 100% 보존
  - `_first_stage_groups_yaml()` / `_load_first_stage_groups_yaml()` 신설
  - `get_market_filter`/`update_market_filter`/`get_first_stage`/`update_first_stage`
    에 v1/v2 버전 분기 추가 — v2는 `market_filter.yaml`의 `levels.*`,
    `first_stage_groups.yaml`의 `groups.*` 구조로 응답/저장 (`MarketFilterUpdate.levels`,
    `FirstStageUpdate`의 v2 전용 필드 신설)
  - `_allowed_yaml_files()` — `strategy_{version}/settings/*.yaml`(상위 5개:
    cache_manager/daily_reeval/dynamic_stop/fear_filter/strategy_sell) glob 추가
- docs: `web/DEV_REQUEST_v2_TRADING_SETTINGS.md` 신설 — v2 매매설정 탭 확장
  개발요청서(§0 사전점검, §2 v2 설정 항목별 상세, §3 신규 카드/페이지, §4 백엔드
  작업목록, §5 주의사항, §6 단계별 진행 제안, §7 DB 참조 사항)

검증:
- `pytest tests/` 403개 전체 통과 (회귀 없음)
- v1/v2 양쪽 GET/PATCH 수동 검증 — 주석/포맷 보존 확인 (`yaml.safe_load` 재파싱 일치)
- strategy_v1 내부 파일 미수정 (읽기 전용 원칙 유지)
- 커밋: `8eb6a83`

---

## 2026-06-13 (추가 2) — strategy_v2 Phase 3: 다중 계좌(조회 전용) reconcile 통합

명세: `strategy_v2/specs/90_multi_account_spec.md`

- feat: `db/schema.py` — `accounts` 테이블 신설(account_id PK, cano/acnt_prdt_cd/
  label/mode/managed_by/env_prefix/is_active) + `trades.account_id` 컬럼 추가
  (`position_registry`는 0단계에서 PK `(code, account_id)`로 선반영 완료 — 마이그레이션 불필요)
- feat: `db/repository.py` — `*_by_account` 함수 신설
  (`get_all_holding_registry_by_account`, `upsert_position_registry_by_account`,
  `close_position_registry_by_account`, `update_sector_by_account`) +
  `accounts` CRUD(`get_accounts`, `upsert_account`). 봇 경로(live_main/paper_main)의
  mode 기반 함수는 시그니처 변경 없음
- feat: `utils/config_loader.py` — `load_extra_accounts()` 신설.
  `KIS_EXTRA_01~10_*` 환경변수 중 APP_KEY가 등록된 슬롯만 감지해
  `config["extra_accounts"]`에 주입 (`load_config()` 마지막 단계)
- feat: `utils/reconcile.py` — 봇 관리 계좌 reconcile 이후
  `_register_accounts()`로 accounts 테이블 등록(봇 계좌 `managed_by='bot'`,
  추가 계좌 `managed_by='manual'`) + 추가 계좌별 `_reconcile_extra_account()`로
  KIS API 잔고조회 → `position_registry(account_id=extra_NN)` INSERT/CLOSE/섹터보강.
  한 계좌 실패가 다른 계좌·전체 처리를 막지 않음(`try/except` 격리)
- feat: `api/token_manager.py`는 변경 불필요 — 기존 `get_access_token(...,
  token_cache_path=...)`가 이미 계좌별 캐시 분리를 지원 (명세 §7과 달리
  추가 계좌는 `KISApiClient` 인스턴스를 새로 만들어 `paths.token_cache=
  data/token_cache_extra_NN.json`만 지정하면 됨)
- test: `tests/test_multi_account.py` 신설(10개) —
  `load_extra_accounts` 4종, accounts 테이블 등록(봇/추가 계좌) 2종,
  추가 계좌 reconcile(INSERT/CLOSE/섹터보강/계좌별 실패 격리) 4종

검증:
- `pytest tests/` 403개 전체 통과 (기존 393개 + 신규 10개, 회귀 없음)
- strategy_v1/buy/sell, trading/order_manager.py 등 봇 매매 경로 미수정 —
  추가 계좌는 조회 전용으로 buy/sell 흐름에 진입하지 않음
- 커밋: `4470de6`

남은 작업(명세 §11 8~9단계, 코드 외):
- 실제 APP_KEY 등록 후 추가 계좌 reconcile 실거래 검증 (OCI)
- 대시보드에 accounts 테이블 노출 (별도 작업)

---

## 2026-06-13 (추가) — strategy_v2 Phase 2 12~13단계: trading/{buy,sell}.py 통합 + runner.py v2 분기 (Phase 2 코드 완료)

명세: `strategy_v2/DEVELOPMENT_SPEC.md` §11(구현 우선순위), §10-3/10-4(매수/매도 흐름)

- feat: `strategy_v2/trading/buy.py` 신설 (커밋 `43d1f2f`)
  - 슬롯 게이팅(`get_pending_slots()`) → 시장필터/레짐/공포단계 평가 →
    일일손실한도·보유한도 체크 → 캐시 로드 → 슬롯별 그룹(A/B/C/D)에서
    `_select_target_strategy`로 2차 스크리닝 프로파일 선택 → `run_group_screening()`
    호출(레짐/공포/필터 delta·scale 전달) → 주문 접수 + `position_registry.upsert()`로
    entry_strategy/entry_group/entry_score/stop_price 등 v2 메타 기록 + `mark_slot_executed()`
  - v1 헬퍼(`_get_holdings`, `_calc_qty`, `_order_type_code`, `_calc_limit_price` 등)는
    독립 복제 — strategy_v1 파일 미수정
- feat: `strategy_v2/trading/sell.py` 신설 (커밋 `43d1f2f`)
  - 매도 우선순위: ①`stop_price` 이탈(직접 처리) → ②~⑥ `strategy_sell.evaluate()`
  - VKOSPI 강제 fear_driven 전환(#9): `fear_level`이 extreme_fear/crisis_rising이면
    fear_driven이 아닌 모든 보유 종목을 무조건 `position_registry.update_strategy(...,
    reason="vkospi_crisis")`로 전환 (전환 자체는 매도 신호 아님)
  - 매도 체결 시 `position_registry.close()`에 exit_regime/exit_vkospi/exit_score 기록
- feat: `runner.py`에 `--pre-market` 플래그 추가 (커밋 `d942701`)
  - `active_strategy_version != "v2"`면 스킵
  - `strategy_v2.daily_reeval.run()` 실행 후 `cache_manager.build()` → `save()`로
    당일 캐시 영속화 (08:00 cron 용도)
  - `active_strategy_version` 분기에 v2 추가: `v1` → `strategy_v1.trading.{buy,sell}`,
    `v2` → `strategy_v2.trading.{buy,sell}`, 그 외 `ValueError`
- test: `tests/test_v2_trading.py` 신설 (25개) — `_calc_qty`/`_order_type_code`/
  `_select_target_strategy`/`_load_profile` 단위 테스트, `run_buy` 슬롯/한도/공포
  게이팅 5종, 전체 흐름(주문 접수 + position_registry 메타 기록 검증) 3종,
  `run_sell` 게이팅 2종 + stop_price 이탈 2종 + VKOSPI 강제전환 1종

검증:
- `pytest tests/` 393개 전체 통과 (기존 368개 + 신규 25개, 회귀 없음)
- v1 스크리닝/매수/매도/order_manager 파일은 미수정 — strategy_v2는 모두 독립 파일로 구현
- `python runner.py --dry-run`은 로컬 `.env` 미설정으로 환경변수 검증 단계에서 종료
  (기존과 동일, OCI에서만 통과)

다음: `strategy_v2/DEVELOPMENT_SPEC.md` §11 Phase 2 1~13단계 코드 완료.
남은 14단계(OCI 배포: `0 8 * * 1-5 python runner.py --pre-market` cron 추가 +
`settings/app.yaml`의 `active_strategy_version: "v2"` 전환)는 OCI 서버에서 수동 진행 필요.

---

## 2026-06-13 — strategy_v2 Phase 1: v1 DB 연동 (position_registry 신설 + 훅/마이그레이션/정합성점검)

명세: `strategy_v2/specs/20_phase1_v1_db_migration_spec.md`,
`strategy_v2/specs/21_phase1_implementation_plan.md`

- feat: `position_registry`/`position_strategy_history` 테이블 신설 (`db/schema.py`)
  - PK `(code, account_id)`, account_id = `{mode}_main`
  - 진입/청산/MFE·MAE/손절가 등 ~35개 컬럼 + 인덱스(idx_pr_status/sector/strategy/date/mode)
  - `init_db()`에 `PRAGMA foreign_keys = ON` 추가, `_connect()`에도 동일 적용
- feat: `db/repository.py`에 position_registry 헬퍼 8개 추가
  - `upsert_position_registry`(INSERT OR IGNORE — 재진입 시 최초 진입가 유지),
    `close_position_registry`(SQL로 profit_pct/profit_amount/hold_days 계산),
    `update_mfe_mae`, `update_stop_price`(역행 방지 WHERE), `update_sector`,
    `get_holding_codes`, `get_all_holding_registry`, `get_sector_counts`
  - 모두 `(db_path, mode, ...)` 시그니처 — 기존 `insert_trade` 패턴과 통일
- fix(C-1): `strategy_v1/trading/sell.py`의 `_check_sell_signal` 반환형을
  `Optional[str]` → `Optional[tuple[str, str]]` (reason_code, message)로 변경
  - reason_code(영문, position_registry.sell_reason용): stop_loss/target_reached/
    intraday_close/time_stop/consecutive_down/trend_break
  - message(한글, trades.sell_reason용)는 기존 그대로 — UI/동작 변경 없음
- feat(C-2/C-3): `trading/order_manager.py`/`strategy_v1/trading/sell.py`에
  position_registry 연동 훅 추가 (모두 try/except + logger.warning — 실패해도
  매매 흐름 중단 없음, `insert_trade`와 동일한 failure-isolation 패턴)
  - `_on_buy_filled`: 매수 체결 시 `upsert_position_registry` (stop_price =
    entry_price * (1 + stop_loss_pct), stop_pct = stop_loss_pct * 100)
  - `_on_sell_filled`: 매도 체결 시 `close_position_registry`
    (sell_reason = `add_pending_order`로 전달된 `sell_reason_code`)
  - `run_sell()` 보유 루프: 매도 판정 전 `update_mfe_mae` 호출 (C-3)
- feat: `utils/migrate_position_registry.py` 신설 — `data/holdings.json` →
  position_registry 1회 초기 마이그레이션 (`python -m utils.migrate_position_registry --mode paper`)
  - 이미 holding 데이터가 있으면 스킵(멱등)
- feat: `utils/reconcile.py` 신설 + `runner.py --reconcile` 플래그 추가
  - holdings.json ↔ position_registry 정합성 점검: 누락 종목 삽입 / 초과 종목
    `status='sold', sell_reason='manual'`로 종료(손익 NULL) / `sector='unknown'`
    종목 `api_client.get_stock_sector()`로 보강
  - 장 마감 후 cron 추가 예정: `0 16 * * 1-5 cd /path/to/bot && python runner.py --reconcile`
- feat: `api/kis_api.py`에 `get_stock_sector(code)` 추가
  (`STOCK_INFO_PATH`/`TrId.STOCK_INFO` — 기존 api_constants.py에 등록되어 있던
  미사용 상수를 활용, search-stock-info 응답의 `bstp_kor_isnm` 반환)
- test: `tests/test_position_registry.py` 신설 (26개) — 스키마/FK, 8개 repository
  헬퍼, 마이그레이션(신규/멱등/빈 holdings/db_path 미설정), order_manager 훅
  (매수 upsert/매도 close/MFE·MAE/DB 실패 시 failure isolation), reconcile
  (누락삽입/초과종료/섹터갱신/멱등) 전체 커버
  - `tests/conftest.py`의 `mock_api`에 `get_stock_sector` 기본 mock 추가

검증:
- `pytest tests/` 218개 전체 통과 (기존 192개 + 신규 26개, 회귀 없음)
- `[M-1]` 단위 환산: 프리셋의 `stop_loss_pct`(-0.05, 비율) 기준 —
  `stop_price = entry_price * (1 + stop_loss_pct)`(/100 아님),
  `stop_pct = stop_loss_pct * 100`(표시용 퍼센트, profit_pct와 단위 통일)
- `python runner.py --dry-run`은 로컬 `.env` 미설정(KIS_PAPER_*, TELEGRAM_*)으로
  환경변수 검증 단계에서 종료 — 본 작업으로 인한 회귀 아님(기존과 동일하게 OCI/.env
  설정 환경에서만 통과 가능)
- 본 작업은 v1 스크리닝/매수/매도 핵심 로직은 변경 없음 — 모두 추가적(additive)
  DB 기록 훅이며 기존 동작에는 영향 없음

다음: `strategy_v2/specs/21_phase1_implementation_plan.md` 기준 Phase 1 회귀
green 확인됨 → Phase 2(strategy_v2 모듈 개발) 착수 가능. OCI에서
`python -m utils.migrate_position_registry --mode paper`(1회) 및
`--reconcile` cron 등록 필요.

## 2026-06-12 (추가7) — 매매설정 탭: 전략버전 드롭박스/설명 + 시장필터·1차스크리닝 변수 편집

설계: `docs/superpowers/specs/2026-06-12-trading-settings-strategy-detail-design.md`
계획: `docs/superpowers/plans/2026-06-12-trading-settings-strategy-detail.md`

- feat: 전략 버전 설명 dict를 /api/config 응답에 추가 (`1e14eb1`)
  - `_STRATEGY_VERSION_DESCRIPTIONS` dict 신설, `strategy_version_descriptions` 필드를
    `/api/config` 응답에 포함
- feat: 시장필터 GET/PATCH를 enabled/ma_period/block_below_ma/block_threshold_pct
  4개 필드로 확장 (`cf07f4e`)
  - `MarketFilterThresholdUpdate` → `MarketFilterUpdate`로 교체, `GET /api/config/market-filter`에
    `block_below_ma` 추가, 기존 `POST /market-filter/threshold`를 `PATCH /market-filter`로 대체
- feat: 1차 스크리닝(first_stage.yaml) 설정 GET/PATCH 엔드포인트 추가 (`1ff10be`)
  - `_first_stage_yaml`/`_load_first_stage_yaml`/`_write_first_stage_key` 헬퍼,
    `FirstStageUpdate` 모델, `GET/PATCH /api/config/first-stage` 신설
    (target_market enum, max_candidates≥1, min_trade_volume≥0, min_price<max_price 검증)
- fix: 1차 스크리닝 min/max_price 검증 기본값을 GET 응답 기본값과 일치시킴 (`ebbb764`)
  - `current.get("min_price", 0)`/`("max_price", 0)` → `1000`/`500000`
- feat: 전략 버전 선택 UI를 드롭박스+설명으로 변경 (`6ef54e8`)
  - 버튼 그룹 → `<select>`, 선택된 버전의 설명을 `strategyVersionDescriptions`에서 표시
- feat: 시장필터 카드를 enabled/ma_period/block_below_ma/block_threshold_pct
  편집 가능하게 확장 (`4e49315`)
  - `marketFilterThreshold`/`marketFilterInput`/`setMarketFilterThreshold()` →
    `marketFilterEdits`/`saveMarketFilter()`로 통합, 4개 필드 전체 편집 UI
- feat: 1차 스크리닝(first_stage.yaml) 설정 편집 카드 신규 추가 (`375b4d6`)
  - "1차 스크리닝 필터" 카드 신설 (target_market/max_candidates/min_price/max_price/
    min_trade_volume/exclude_suspended), `firstStageEdits`/`saveFirstStage()`/`initFirstStage()`,
    `init()`·`setStrategyVersion()`에 `initFirstStage()` 호출 연결
- fix: 전략 버전 변경 확인 메시지에 1차 스크리닝 설정 언급 추가 (`8df23b8`)

검증:
- `pytest tests/` 192개 전체 통과 (회귀 없음)
- uvicorn 구동 후 `/api/config`, `/api/config/market-filter` (GET/PATCH),
  `/api/config/first-stage` (GET/PATCH, 검증 에러 케이스 포함) 직접 함수 호출로 동작 확인
  (TOTP 인증 미설정 상태라 HTTP 레벨 호출은 401 — 라우터 함수 직접 호출로 대체 검증)
- `market_filter.yaml`/`first_stage.yaml` 검증 후 원래 값으로 정상 복원 확인
- **브라우저 시각 확인 미수행** (TOTP 인증 설정 필요) — 다음 세션에서 OCI 또는
  로컬 `/setup` 완료 후 `/settings` 매매설정 탭에서 드롭박스/시장필터/1차스크리닝
  카드 3종 수동 확인 필요

## 2026-06-12 (추가6) — docs 폴더 strategy_v1 경로/전략 버전 선택 UI 최신화

docs: strategy_v1 경로 분리 및 전략 버전 선택 UI를 docs/에 반영

- `HOW_TO_ADD_CONDITION.md`: 레지스트리 등록 경로를 `strategy_v1/screening/second_stage.py`로 명시
- `SETTINGS_GUIDE.md`, `SETTINGS_REFERENCE.md`: 파일 구조 다이어그램에
  `strategy_v1/settings/` 레벨 추가 (presets·screen_config가 settings/ 바로 아래에
  있는 것처럼 보이던 표기 수정), `active_strategy_version` 변수 설명·전환 가이드 추가
- `TRADING_FLOW.md`, `WORKFLOW.md`: `buy.py`/`sell.py`/`market_filter.py`/
  `first_stage.py`/`second_stage.py`/`atr_filter.py`/`market_regime.py` 등
  모듈 참조에 `strategy_v1/trading|screening/` 경로 보강, `/api/config/strategy-version`
  엔드포인트 안내 추가
- `USAGE.md`: 프리셋 전환 섹션에 전략 버전 선택 UI(`/settings` 매매설정 탭) 안내 추가
- 나머지 9개 문서(AI_CODE_SAFETY_CHECKLIST, BACKTEST_*, CONDITIONS_GUIDE, INSTALL,
  OCI_QUICKSTART, TOKEN_BLOCKED, UPDATE, WEBSERVICE_DEPLOY)는 staleness 없음 확인
- 작업 계획: `build-docs/update/2026-06-12-docs-staleness-update.md`

## 2026-06-12 (추가5) — 설정 페이지 전략 버전 선택 UI

feat: 설정 페이지 매매설정 탭에 전략 버전(strategy_vN) 선택 추가

- `web/routers/config_router.py`: `strategy_v1/...` 하드코딩 경로를
  `active_strategy_version` 기준으로 파라미터화. `strategy_v*/settings/presets`가
  존재하는 버전만 자동 감지하는 `_list_strategy_versions()` 추가.
  `GET/POST /api/config/strategy-version` 신규 엔드포인트로 활성 버전 조회·변경
- `web/routers/pages.py`: `/settings` 페이지의 초기 프리셋 목록을
  `active_strategy_version` 기준 디렉토리에서 로드
- `web/templates/settings.html`: 매매설정 탭에 전략 버전 선택 카드 추가.
  매매 프리셋 목록을 Jinja 서버 렌더에서 Alpine `x-for` 동적 렌더로 전환.
  버전 변경 시 프리셋·시장필터·2차 스크리닝·YAML 편집기 목록 재조회
- `settings/app.yaml`: `active_strategy_version` 주석에 설정 페이지 변경 경로 안내 추가
- 현재는 `strategy_v1`만 존재하므로 드롭다운에 v1만 표시됨. 추후
  `strategy_v2/settings/...`가 생성되면 코드 수정 없이 자동으로 선택 가능
- pytest 192개 전체 통과(영향 없음 확인). web/ 라우터는 fastapi 미설치 환경이라
  단위 테스트 불가 — OCI에서 수동 검증 필요
- 작업 계획: `build-docs/update/2026-06-12-strategy-version-selector-ui.md`

## 2026-06-12 (추가4) — /simplify 리뷰 결과 반영

docs: 문서 정리 커밋(HEAD~3..HEAD) /simplify 리뷰 반영

- `strategy_v1/DEVELOPMENT_SPEC.md`: "캔들 순서(candles[0] 미완성봉)" 중복 설명을
  제거하고 CLAUDE.md "알려진 주의사항" 참고로 변경
- `.claude/skills/work-start/skill.md`, `.claude/skills/work-end/skill.md`:
  `allowed-tools`에 `Read`/`Write`/`Edit` 누락 — work-log.md·next-tasks.md 등
  md 파일 읽기/쓰기 단계가 차단되는 문제 수정
- `build-docs/next-tasks.md`: "완료" 표시된 두 작업 항목의 과거 작업 서술을
  제거(work-log.md와 중복) — 향후 작업(skill 동작 검증, AI_PROJECT_PROMPT.md
  staleness 검토)만 남기고 축약
- 코드 변경 없음 — pytest 영향 없음

## 2026-06-12 (추가3) — CLAUDE.md 작업 시작/종료 절차 섹션 축약

docs: CLAUDE.md 작업 시작/종료 절차를 skill 포인터 중심으로 축약

- 작업 시작/종료 절차의 1~6단계 상세 목록을 제거하고, 핵심 흐름 한 줄 요약 +
  `/work-start`, `/work-end` skill 참고 안내로 대체
- 상세 단계는 `.claude/skills/work-start/skill.md`, `.claude/skills/work-end/skill.md`에만
  유지 — CLAUDE.md(항상 로드)와 skill 파일(명시적 호출 시 로드) 간 중복 제거
- 코드 변경 없음 — pytest 영향 없음

---

## 2026-06-12 (추가2) — CLAUDE.md/AI_PROJECT_PROMPT.md 중복 정리 + 작업 시작/종료 절차 skill화

docs: AI_PROJECT_PROMPT.md를 CLAUDE.md 보충 자료로 재구성, 작업 시작/종료 절차 skill 추가

- `AI_PROJECT_PROMPT.md`를 CLAUDE.md와 100% 중복되던 섹션(프로젝트 개요, 전체 파일 구조,
  설정 로드 순서, 핵심 인터페이스, 개발 규칙, 테스트 작성 규칙, 작업 시작 체크리스트,
  현재 알려진 제약사항)을 제거하고, CLAUDE.md에 없는 보충 정보(데이터 파일 보충
  `alert_history.json`/`runner.lock`, GitHub 저장소 정보, Oracle 서버 배포 절차)만
  남기는 "보충 자료" 문서로 재구성
- `CLAUDE.md`: 상단에 AI_PROJECT_PROMPT.md 참고 안내 추가, 데이터 레이어 표에 보충
  데이터 파일 포인터 추가, 작업 시작 절차 1·3단계 `main` → `master` 오기 수정
  (`git branch -a`로 실제 기본 브랜치가 `master`임을 확인)
- 신규: `.claude/skills/work-start/skill.md`, `.claude/skills/work-end/skill.md`
  — CLAUDE.md의 작업 시작/종료 절차를 `/work-start`, `/work-end` skill로 실행 가능하게 함
- 코드 변경 없음 — pytest 영향 없음

---

## 2026-06-12 — CLAUDE.md / AI_PROJECT_PROMPT.md 정리 + strategy_v1 개발명세서 분리

docs: strategy_v1 개발명세서 분리 및 CLAUDE.md/AI_PROJECT_PROMPT.md 공용 내용 정리

- 신규: `strategy_v1/DEVELOPMENT_SPEC.md` — strategy_v1 전용 개발 정보 집중
  - 디렉토리 구조, 설정 로드 순서·프리셋·2차 스크리닝 전략 표
  - 매수 흐름(buy.py)/매도 우선순위(sell.py)/2차 스크리닝 점수 계산
  - 스크리닝 조건 모듈 인터페이스 + `_CONDITION_REGISTRY` 10개 + 새 조건 추가 절차
  - 전략/프리셋 전환 방법, strategy_v1 관련 테스트·주의사항
- `CLAUDE.md`: 위 strategy_v1 전용 섹션 제거, 프로젝트 구조의 strategy_v1 블록을
  요약 + 명세서 링크로 대체, 설정 로드 순서를 공용 메커니즘(`active_strategy_version`
  기반)만 남기고 세부 표는 명세서로 이동
- `AI_PROJECT_PROMPT.md`: 중복·구버전 strategy_v1 섹션(스크리닝 조건 인터페이스, 매도
  5가지 우선순위, 새 조건 추가/전략 전환/프리셋 전환 패턴, KIS API 조회 한도) 제거 후
  명세서 링크로 대체. `token_cache.json`(stale) → `token_cache_{live,paper}.json`로 수정
- 코드 변경 없음 — pytest 영향 없음

---

## 2026-06-11 (추가2) — 전략 버전 분리 구조 Step 3 (strategy_v1/screening/, strategy_v1/trading/ 코드 분리)

`docs/superpowers/plans/2026-06-11-strategy-version-restructure-step3-screening-trading.md` plan을
subagent-driven-development(Task 1~3 구현+리뷰, Task 4 직접 검증, 최종 홀리스틱 리뷰)로 실행 완료.

- **Task 1** (커밋 `bcdb26c`): `screening/{atr_filter,first_stage,market_filter,market_regime,second_stage}.py` → `strategy_v1/screening/`로 `git mv` (history 보존)
  - `strategy_v1/__init__.py`, `strategy_v1/screening/__init__.py` 신규 생성
  - `second_stage.py`의 `atr_filter`/`market_regime` 상호 import 경로를 `strategy_v1.screening.*`로 변경
  - `trading/buy.py`, `tests/test_filters.py`의 `screening.*` import 경로를 `strategy_v1.screening.*`로 변경 (`trading.order_manager`는 변경 없음)
  - pytest 192개 전체 통과
- **Task 2** (커밋 `5b5c838`): `trading/{buy,sell}.py` → `strategy_v1/trading/`로 `git mv` (`order_manager.py`는 `trading/`에 잔류)
  - `strategy_v1/trading/__init__.py` 신규 생성, `trading/__init__.py`를 공통 인프라 패키지 docstring으로 재정의
  - `runner.py`에 `active_strategy_version` 분기 추가 (v1 → `strategy_v1.trading.{buy,sell}` 동적 import, 그 외 ValueError) — v2 추가 시 elif 분기만 추가하면 되도록 설계
  - `tests/test_trading.py`의 `trading.buy`/`trading.sell` import·patch 경로를 `strategy_v1.trading.*`로 변경 (`trading.order_manager`는 변경 없음)
  - pytest 192개 전체 통과, `python runner.py --dry-run` import 단계 정상 (이후 환경변수 누락 종료는 기존과 동일, 회귀 아님)
- **Task 3** (커밋 `dd3a505`): `CLAUDE.md`/`README.md`/`AI_PROJECT_PROMPT.md`의 프로젝트 구조 트리·모듈 표·섹션 헤더·새 조건 추가 절차·superpowers 작업 규칙 경로를 `strategy_v1/screening/`·`strategy_v1/trading/`로 일괄 수정 (`trading/order_manager.py`는 변경 없음)
  - 잔존 경로 참조 grep 확인 — 결과 없음
  - pytest 192개 전체 통과
- **Task 4** (검증, 별도 커밋 없음): pytest 192개 전체 통과, `python runner.py --dry-run` 및 `config_loader` 단독 로드 모두 `strategy_v1.screening.*`/`strategy_v1.trading.*` import 단계까지 정상 진행 후 기존과 동일하게 환경변수 누락으로 종료(회귀 아님), `git status` 클린, `--backtest`는 `screening.*`/`trading.buy`/`trading.sell`을 import하지 않아 영향 없음 확인
- **최종 리뷰** (범위 `d3280d6..dd3a505`): APPROVED — 전 범위 import 참조 일괄 확인, 이동된 7개 파일은 docstring·import 경로 외 로직 변경 없음, `runner.py` 분기 로직 정상, `trading/`은 `order_manager.py`만 잔류 확인. 비어있는 untracked `screening/` 디렉토리 정리.
- **다음 단계**: Step 4(웹 UI 버전 선택)는 v2 실존 전까지 YAGNI로 보류

---

## 2026-06-11 (추가) — 전략 버전 분리 구조 Step 2 (strategy_v1/settings/ 분리)

`docs/superpowers/plans/2026-06-11-strategy-version-restructure-step2-settings.md` plan을
subagent-driven-development(Task 1~3 구현+2단계 리뷰, Task 4 직접 검증, 최종 홀리스틱 리뷰)로 실행 완료.

- **Task 1** (커밋 `9817ab6`): `settings/presets/` → `strategy_v1/settings/presets/`, `settings/screen_config/` → `strategy_v1/settings/screen_config/` (`git mv`, history 보존)
  - `settings/app.yaml`에 `active_strategy_version: "v1"` 추가, 경로 주석 갱신
  - `utils/config_loader.py`: `load_config()`에 `active_strategy_version` 기반 `presets_dir`/`screening_dir` 동적 결정 로직 추가, `_load_screening_configs`의 `second_stage.yaml` 폴백 경로를 `base / "second_stage.yaml"`로 일반화
  - spec/code quality 리뷰 모두 통과 (Ready to merge: Yes)
- **Task 2** (커밋 `db38d12`): `web/routers/config_router.py`(경로 상수 4개 + `_ALLOWED_YAML_FILES` 화이트리스트 10건 `strategy_v1/` 접두), `web/routers/pages.py`(프리셋 목록 glob 경로) 갱신
  - spec/code quality 리뷰 모두 통과 (Ready to merge: Yes)
- **Task 3** (커밋 `4e6cc09`): `docs/{SETTINGS_GUIDE,SETTINGS_REFERENCE,TRADING_FLOW,USAGE,WORKFLOW,HOW_TO_ADD_CONDITION}.md`의 `settings/presets`·`settings/screen_config` 참조를 `strategy_v1/` 접두로 일괄 수정 (32 insertions, 31 deletions), `WORKFLOW.md` 설정 로드 흐름도에 `active_strategy_version` 결정 단계 추가
  - spec/code quality 리뷰 모두 통과 (Ready to merge: Yes)
- **Task 4** (검증, 별도 커밋 없음): `pytest tests/` 192개 전체 통과, config-load 스크립트로 `strategy_v1/settings/screen_config/{market_filter,first_stage}.yaml`·`second_stage`(balanced) 정상 로드 확인, `python runner.py --dry-run`은 새 경로까지 정상 진행 후 기존과 동일하게 `KIS_PAPER_*`/`TELEGRAM_*` 환경변수 누락으로 종료(Step 1 때와 동일, 회귀 아님)
- **최종 리뷰** (범위 `e24a83b..4e6cc09`): Ready to merge: With fixes (minor) — Important로 지적된 두 항목을 후속 커밋으로 즉시 수정:
  - `strategy_v1/settings/presets/*.yaml`(3개) + `strategy_v1/settings/screen_config/**/*.yaml`(7개) 내부 헤더 주석의 `# settings/presets/...`·`# settings/screen_config/...` 경로를 `# strategy_v1/settings/...`로 수정 (git mv 잔여물)
  - `CLAUDE.md`/`README.md`/`AI_PROJECT_PROMPT.md`에 남아있던 `settings/presets`·`settings/screen_config` 참조를 `strategy_v1/settings/...`로 일괄 수정
  - `pytest tests/` 192개 재확인 통과
- **다음 단계**: Step 3(`strategy_v1/screening/`, `strategy_v1/trading/` 코드 분리) — `docs/superpowers/plans/...` 별도 plan 문서 작성 필요

---

## 2026-06-11 — 전략 버전 분리 구조 설계 + Step 1 (indicators/ 공유 패키지 분리)

전체 구조 변경(`strategy_v1`/`strategy_v2` 공존 + 공유 `indicators/`) 설계를 brainstorming으로 확정하고,
spec/plan 문서를 작성한 뒤 Step 1(indicators/ 분리)을 subagent-driven-development로 구현·리뷰·완료.

- **`docs/superpowers/specs/2026-06-11-strategy-version-restructure-design.md`** (커밋 `34b65ea`): 설계 문서
  - strategy_v1/v2 동시 존재 + `active_strategy_version` 설정으로 전환, 단일 활성
  - screening + trading(buy/sell) + preset까지 버전별 분리, 공유 `indicators/`만 최상위 유지
  - 4단계 마이그레이션 계획 (Step1 indicators, Step2 settings 분리, Step3 screening/trading 코드 분리, Step4 web UI)
- **`docs/superpowers/plans/2026-06-11-strategy-version-restructure-step1-indicators.md`** (커밋 `9039749`): Step 1 전용 구현 계획
- **Task 1** (커밋 `0c1c241`): `screening/conditions/` 10개 조건 모듈 + `__init__.py` → `indicators/`로 `git mv`
  - `indicators/__init__.py` 재작성, `screening/second_stage.py`·`backtest/backtest_runner.py`·`tests/test_conditions.py` import 경로를 `indicators`로 변경
  - spec/code quality 리뷰 모두 통과 (Ready to merge: Yes)
- **Task 2** (커밋 `13e37a9`): `docs/HOW_TO_ADD_CONDITION.md` 경로 안내를 `indicators/` 기준으로 갱신, `indicators/cond_*.py` 10개 파일의 docstring 2번째 줄 경로 주석 보정
  - spec/code quality 리뷰 모두 통과 (Ready to merge: Yes)
- **최종 리뷰** (베이스 `9039749`, 헤드 `13e37a9`): Step 1 전체 변경사항 Ready to merge: Yes — `pytest tests/` 192개 전체 통과, `_CONDITION_REGISTRY` 양쪽 모두 정상 참조
- **`CLAUDE.md`/`AI_PROJECT_PROMPT.md`** (커밋 `4ea4151`): 최종 리뷰에서 발견된 잔존 `screening/conditions` 경로 참조를 `indicators/`로 일괄 수정 (프로젝트 구조 트리, 조건 모듈 인터페이스 예시, 새 조건 추가 절차)
- **검증**: `pytest tests/` 192개 전체 통과 (회귀 없음, 순수 이동 + import 경로 변경)
- **다음 단계**: Step 2(`strategy_v1/settings/` 분리), Step 3(`strategy_v1/screening|trading/` 코드 분리)는 별도 plan 문서로 추후 작성

---

## 2026-06-10 (추가 11) — docs 폴더 wide 전략 반영 + 웹 설정 편집 안내 추가

- **`settings/screen_config/second_stage.yaml`**: 주석 표 `wide` min_score `35` → `25`(CHOP+5 보정 후 30)로 수정 (06-10 wide.yaml 완화 작업과 동기화)
- **`docs/SETTINGS_GUIDE.md`**:
  - `active_strategy` 주석과 "전략 비교" 표에 `wide` 전략 행 추가 (06-09 추가 후 미반영 상태였음)
  - 섹션 6에 "웹 대시보드에서 수정하기" 추가 — `/settings` 핵심 조건 파라미터 전체 편집 기능(추가 10) 안내
- **`docs/SETTINGS_REFERENCE.md`**: "전략 선택" 표에 `wide` 행 추가
- **검증**: `pytest tests/` 192개 전체 통과 (문서 변경만, 회귀 없음)

---

## 2026-06-10 (추가 10) — 매매설정 페이지 핵심 조건 파라미터 전체 편집 지원

- **`web/routers/config_router.py`**:
  - `_PARAM_LABELS` 신규 추가 — 10개 조건 × 17개 세부 파라미터 → 한글 라벨 매핑
  - `get_screening_strategy()`: 8개 고정 `key_params` 대신 전체 `condition_params`(nested dict) + `param_labels` 반환
  - `ScreeningParamsUpdate`를 `min_score: float | None`, `condition_params: dict[str, dict[str, float]] | None`로 일반화 (기존 8개 고정 필드 제거)
  - `update_screening_params()`: `condition_params`를 조건별로 deep-merge 저장, `_PARAM_LABELS`에 정의된 키만 허용
    - 기존 값이 `int`이고 입력값이 정수면 `int`로 저장해 YAML 포맷 보존 (예: `period: 14` → `14.0` 방지)
- **`web/templates/settings.html`**:
  - "핵심 조건 파라미터" 영역을 10개 조건별 그룹으로 재구성 — 각 조건의 모든 파라미터를 입력 필드로 노출
  - `screeningParamEdits`를 `{ min_score, condition_params: {...} }` 구조로 변경, `screeningStrategy.conditions`/`condition_params`/`param_labels`를 기반으로 동적 렌더링
- **검증**: `pytest tests/` 192개 전체 통과 (회귀 없음, web 라우터는 기존부터 미커버리지)
- fastapi가 로컬 환경에 미설치되어 엔드포인트 직접 실행 검증은 불가 — OCI에서 `/settings` 매매 설정 탭 수동 확인 필요

---

## 2026-06-10 (추가 9) — 매수 점수 툴팁 내용을 매매프리셋/임계값/2차 스크리닝전략으로 변경

- **`db/schema.py`**: `trades.condition_scores` 컬럼을 `buy_context TEXT`로 변경 (운영 DB에 미반영 상태였으므로 컬럼명 교체)
- **`db/repository.py`**: `insert_trade()` 컬럼명 `condition_scores` → `buy_context`
- **`trading/order_manager.py`**: `add_pending_order()`/`_on_buy_filled()`의 `condition_scores` → `buy_context`로 변경
- **`trading/buy.py`**: `add_pending_order()` 호출 시 `buy_context={"preset": active_preset, "strategy": active_second_stage, "min_score": stock["min_score_used"]}` 전달
- **`web/templates/trades.html`**: 매수 점수 툴팁을 "매매프리셋 / 임계값 / 2차 스크리닝전략" 3줄로 변경
  - 프리셋: 보수적/중립/공격적, 전략: 균형/모멘텀/추세추종/광범위 한글 라벨 매핑
- **테스트**: `tests/test_db.py`, `tests/test_trading.py`를 buy_context 기준으로 갱신
- **검증**: `pytest tests/` 192개 전체 통과
- 기존 trades 행은 buy_context가 없어 툴팁 미표시, 다음 매수 체결부터 정상 기록

---

## 2026-06-10 (추가 8) — 체결 이력 페이지 매수 점수 툴팁 (조건별 점수 상세)

- **`db/schema.py`**: `trades` 테이블에 `condition_scores TEXT` 컬럼 추가 (`init_db()` 마이그레이션 등록)
- **`db/repository.py`**: `insert_trade()`가 `condition_scores`(JSON 문자열)도 저장
- **`trading/order_manager.py`**:
  - `add_pending_order()`에 `condition_scores: dict | None` 파라미터 추가 → pending_orders.json에 기록
  - `_on_buy_filled()`에서 trade_entry에 `condition_scores`를 JSON 문자열로 직렬화해 포함
- **`trading/buy.py`**: `add_pending_order()` 호출 시 `stock["raw_scores"]`(2차 스크리닝 조건별 0.0~1.0 점수)를 `condition_scores`로 전달
- **`web/templates/trades.html`**: 매수 행의 점수 텍스트에 `title` 툴팁 추가 — 조건별 점수(한글 라벨 + %)를 hover 시 표시
- **테스트 추가**: `tests/test_db.py`, `tests/test_trading.py`에 condition_scores 전파 검증
- **검증**: `pytest tests/` 192개 전체 통과
- 기존 trades 행은 condition_scores가 없어 툴팁 미표시, 다음 매수 체결부터 정상 기록
- (다음 작업에서 `condition_scores` → `buy_context`로 컬럼명 교체됨, 추가 9 참고)

---

## 2026-06-10 (추가 7) — 체결 이력 페이지에 보유상태/매수가 컬럼 추가

- **`db/schema.py`**: `trades` 테이블에 `avg_price INTEGER` 컬럼 추가, `init_db()` 마이그레이션 등록
- **`db/repository.py`**: `insert_trade()`가 `avg_price`도 저장 (`get_trades()`는 `SELECT *`라 자동 반영)
- **`trading/order_manager.py`**: `_on_sell_filled()`의 trade_entry에 `avg_price`(매도 시점 평균매수단가) 포함
- **`web/routers/pages.py`**: `/trades` 페이지에 `holdings.json` 기준 현재 보유 종목 코드 목록(`held_codes`) 전달
- **`web/templates/trades.html`**: "상태/매수가" 컬럼 추가
  - 매수 행: 현재 보유 중이면 "보유중", 이미 매도되었으면 "매도완료"
  - 매도 행: `avg_price`(매수가) 표시, 없으면 "—"
- **테스트 추가**: `tests/test_db.py`에 avg_price 컬럼/CRUD 검증, `tests/test_trading.py`에 avg_price 전파 검증
- **검증**: `pytest tests/` 192개 전체 통과

---

## 2026-06-10 (추가 6) — 체결 이력 페이지에 매수 점수 / 매도 사유 표시

- **`db/schema.py`**: `trades` 테이블에 `score REAL`, `sell_reason TEXT` 컬럼 추가
  - `init_db()`에 `_add_column_if_missing()` 추가 — 기존 DB도 재실행 시 자동 마이그레이션 (idempotent)
- **`db/repository.py`**: `insert_trade()`가 `score`/`sell_reason`도 저장 (`get_trades()`는 `SELECT *`라 자동 반영)
- **`trading/order_manager.py`**:
  - `add_pending_order()`에 `score`, `sell_reason` 파라미터 추가 → pending_orders.json에 기록
  - `_on_buy_filled()` / `_on_sell_filled()`에서 trade_log.json·DB에 `score`/`sell_reason` 포함
- **`trading/buy.py`**: `add_pending_order()` 호출 시 2차 스크리닝 점수(`score`) 전달
- **`trading/sell.py`**: `add_pending_order()` 호출 시 매도 사유(`sell_reason`) 전달
- **`web/templates/trades.html`**: "점수/사유" 컬럼 추가 — 매수 행은 점수, 매도 행은 매도 사유 표시
- **테스트 추가**: `tests/test_db.py`(신규, schema 마이그레이션·CRUD), `tests/test_trading.py`에 score/sell_reason 전파 케이스 2건
- **검증**: `pytest tests/` 192개 전체 통과

---

## 2026-06-10 (추가 5) — 체결 이력 페이지 렌더링 깨짐 수정

- **`/trades` 페이지에서 Alpine.js 코드가 텍스트로 노출되는 문제 수정** (`web/templates/trades.html`):
  - `x-data="{ ... {{ trades | tojson }} ... }"` — `tojson`이 출력하는 JSON의 큰따옴표(`"`)가
    `x-data="..."` 속성의 닫는 따옴표와 충돌해 HTML이 깨지고 스크립트 일부가 화면에 그대로 노출됨
  - `x-data` 속성을 작은따옴표(`'...'`)로 변경, 내부 JS 문자열 리터럴은 큰따옴표로 전환하여 해결
- **검증**: `pytest tests/` 186개 전체 통과 (web 템플릿 변경, 단위 테스트 영향 없음)

---

## 2026-06-10 (추가 4) — 작업 종료 절차 수정 + CLAUDE.md 구조 동기화

- **작업 종료 절차에서 PR 요청 단계 제거** (`CLAUDE.md`):
  - 기존 6번 "feature/build 브랜치에 push 하고 PR 요청" → "push (PR 요청은 사용자가 별도 지시할 때만 진행)"
  - 중복되던 7번 항목 삭제
- **프로젝트 구조 섹션을 실제 코드와 동기화** (`CLAUDE.md`):
  - `report/`에 누락되어 있던 `md_writer.py`, `gdrive_sync.py` 추가
  - `utils/`에 신규 `price_utils.py` 추가
  - `settings/screen_config/second_stage/`에 `wide` 전략 추가, 2차 스크리닝 전략 표에 `wide.yaml` 행 추가
  - `tests/` 목록에 `test_price_utils.py`, `test_dry_run.py`, `test_token_blocked.py`, `test_md_writer.py`, `test_md_report_integration.py`, `test_gdrive_sync.py` 추가
  - 테스트 미커버리지 목록에서 이미 테스트가 작성된 `api/token_manager.py`, `api/dry_run_client.py`, `report/daily_report.py`, `report/monthly_report.py` 제거

---

## 2026-06-10 (추가 3) — 호가단위 오류 수정

- **OCI paper 모드 검증 결과 (187a45d 적용 후)**:
  - 잔고 인식 정상화 → 매수 주문 7건 접수 성공 (GS글로벌, 랩지노믹스, 테크윙, 진양화학, 화신정공, 대원강업, 케이뱅크)
  - 1차 후보 30→40종목, 통과 24→36종목, 2차 통과 4→8종목으로 증가 확인
  - 신규 발견: 한화생명(088350) 매수 주문이 "호가단위 오류"로 거부 (가격=4837원)

- **KRX 호가단위 보정 유틸 추가** (`utils/price_utils.py`):
  - `round_to_tick_size()` — 가격 구간별 호가단위(1/5/10/50/100/500/1,000원)에 맞춰 가장 가까운 유효 호가로 보정
  - 4837원 → 4835원으로 보정되어 호가단위 오류 해결

- **매수/매도 지정가 산출에 호가단위 보정 적용**:
  - `trading/buy.py`의 `_calc_limit_price()` — TODO였던 호가단위 보정 구현
  - `trading/sell.py` 매도 지정가 산출부에도 동일 적용

- **테스트 추가**: `tests/test_price_utils.py` — 구간별 경계값 포함 21개 케이스
- **검증**: `pytest tests/` 186개 전체 통과

---

## 2026-06-10 (추가 2) — 잔고 0원 + 거래량순위 KOSDAQ 조회 오류 수정

- **`get_balance()` 잔고 필드 수정** (`api/kis_api.py`):
  - `ord_psbl_cash`(존재하지 않는 필드, 항상 0 반환) → `prvs_rcdl_excc_amt`(D+2 정산잔고)
  - 2차 스크리닝 통과 종목이 모두 "잔고=0원"으로 매수 스킵되던 버그의 근본 원인
- **거래량순위(`FHPST01710000`) KOSDAQ 조회 오류 수정** (`api/api_constants.py`, `api/kis_api.py`):
  - `FID_COND_MRKT_DIV_CODE`를 항상 `"J"`로 고정, 시장 구분은 `FID_INPUT_ISCD`(코스피="0001"/코스닥="1001")로 지정
  - `MarketCode.VOLUME_RANK_KOSPI`/`VOLUME_RANK_KOSDAQ` 상수 재정의, `_get_volume_rank()`/`get_stock_list()` 갱신
- **검증**: `pytest tests/` 전체 통과 + OCI 서버 실행 로그로 효과 확인 (위 항목 참고)

---

## 2026-06-10 — CLAUDE.md 작업 절차 정비

- **작업 시작/종료 절차 보강** (`CLAUDE.md`):
  - 작업 시작 절차: `git checkout feature/build` 명시, main rebase 단계 유지
  - 작업 종료 절차: md 파일 최신화, PR 요청, 작업 기록 단계 추가
  - 원격(`42a287b`)과의 충돌 항목(작업 시작 절차 6번)을 rebase로 병합
- **build-docs/update 작성 규칙 구체화** (`CLAUDE.md`):
  - 코드 작업 착수 전 `build-docs/update/YYYY-MM-DD-{작업명}.md`에 요청사항 + 작업 계획(영향 범위, 수정 파일 목록·순서, 테스트 전략) 작성하도록 규정
- **블로그용 진행 정리 자료 추가** (`build-docs/blog-progress-summary.md`)
  - 프로젝트 시작부터 현재까지 커밋 타임라인 + work-log 요약 정리

---

## 2026-06-09 (추가 4) — 2차 스크리닝 탈락 로그 개선 + wide min_score 완화 + YAML 편집기 app.yaml 제거

- **2차 스크리닝 탈락 로그 INFO 레벨 상향** (`screening/second_stage.py`):
  - 기존 `logger.debug` → `logger.info` 로 변경
  - 탈락 시 상위 3개 조건 점수 함께 출력 (예: `moving_average=0.85 obv=0.72 volume_surge=0.50`)
  - 다음 cron 실행부터 종목별 점수를 로그에서 직접 확인 가능

- **wide 전략 min_score 완화** (`settings/screen_config/second_stage/wide.yaml`):
  - `min_score: 35 → 25` (CHOP 시장 +5 보정 후 실효 기준 30점)
  - 배경: 모의투자 서버 데이터 부족(50/203일)으로 market_regime이 CHOP 판정, ETF 다수 종목에서
    평균회귀 신호(RSI<40 등)가 발동되지 않아 40점 기준 전 종목 탈락하던 문제 해결

- **YAML 편집기에서 `settings/app.yaml` 제거** (`web/routers/config_router.py`):
  - `_ALLOWED_YAML_FILES`에서 `settings/app.yaml` 삭제
  - 앱 핵심 설정(모드, 경로, 시크릿 등)은 전용 API를 통해서만 변경하도록 제한

- **검증**: `pytest tests/` 164개 전체 통과

---

## 2026-06-09 (추가 3) — 설정 페이지 탭 분리 + 2차 스크리닝 편집 + ATR 완화

- **설정 페이지 탭 3분할** (`web/templates/settings.html`):
  - 메인 설정 탭: 실행모드, 초기자금
  - 매매 설정 탭: 시장 필터 임계값, 매매 프리셋(파라미터 표시), 2차 스크리닝 전략
  - 서버 설정 탭: 구글 드라이브 동기화, YAML 편집기

- **2차 스크리닝 전략 선택 + 파라미터 편집** (`web/templates/settings.html`, `web/routers/config_router.py`):
  - 전략 선택 버튼(balanced / momentum / trend_following / wide)
  - 8개 조건 파라미터 인라인 편집 (RSI 과매도, 거래량 배율, 볼린저 std, 스토캐스틱, CCI, 모멘텀 기간, 신고가 기간)
  - `POST /api/config/screening-strategy` — 활성 전략 변경
  - `PATCH /api/config/screening-strategy/params` — 조건 파라미터 저장 (yaml.dump 기반)
  - 가중치 막대 그래프 최대값 기준 비례 계산 (overflow 방지)

- **wide 전략 ATR 완화** (`settings/screen_config/second_stage/wide.yaml`):
  - `hard_block_pct: 5.0 → 15.0`, `soft_block_pct: 3.0 → 8.0`, `min_score_penalty: 20 → 10`
  - 배경: 5% 기준으로 모든 24개 후보 종목(삼성전자 포함) ATR 차단

- **검증**: `pytest tests/` 164개 전체 통과

---

## 2026-06-09 (추가 2) — wide 2차 스크리닝 전략 + 설정 페이지 프리셋/스크리닝 UI 개선

- **`wide` 2차 스크리닝 전략 추가** (`settings/screen_config/second_stage/wide.yaml`):
  - min_score=35 (기존 balanced=50 대비 대폭 완화)
  - 모든 조건 임계값 완화: RSI 과매도 30→40, 거래량 배율 1.5→1.2, 볼린저 std 2.0→1.5, 스토캐스틱 과매도 20→35, CCI 과매도 -100→-70, 모멘텀 10→5일, 신고가 52→26주
  - 가중치는 balanced와 동일 유지
  - `settings/screen_config/second_stage.yaml` 테이블에 wide 항목 추가

- **API 확장** (`web/routers/config_router.py`):
  - `GET /api/config` 응답에 `preset_details` 추가 (프리셋별 stop_loss_pct, take_profit_pct, max_holding_count, max_holding_days)
  - `GET /api/config/screening-strategy` 신규 엔드포인트 (활성 전략 조건별 가중치 반환)
  - `_ALLOWED_YAML_FILES` 에 `wide.yaml` 추가

- **설정 페이지 UI 개선** (`web/templates/settings.html`):
  - 프리셋 카드: 각 버튼 아래에 손절%, 익절%, 최대종목, 보유기간 표시
  - "2차 스크리닝 전략" 카드 추가: 활성 전략명, min_score, 10개 조건 가중치 막대 시각화

- **검증**: `pytest tests/` 164개 전체 통과

## 2026-06-09 (추가) — 시장 필터 매수 차단 임계값 추가 + 웹 설정 페이지 연동

- **`block_threshold_pct` 도입** (`screening/market_filter.py`):
  - 기존: KOSPI < MA이면 즉시 차단
  - 변경: `ratio <= block_threshold_pct` 일 때만 차단 (기본 -1.0%)
  - 소폭 이탈(예: 오늘 cron.log의 -0.49%)은 허용하고, 임계값 초과 시만 차단
  - 통과 로그에도 비율(%) 출력 추가

- **`block_threshold_pct: -1.0` 설정 추가** (`settings/screen_config/market_filter.yaml`):
  - YAML 수정만으로 다음 cron 실행 시 자동 반영
  - 예: `-1.0` → MA 대비 1% 이탈까지 허용 / `0.0` → 기존 동작 (즉시 차단)

- **시장 필터 API 2개 추가** (`web/routers/config_router.py`):
  - `GET  /api/config/market-filter` — enabled, ma_period, block_threshold_pct 반환
  - `POST /api/config/market-filter/threshold` — 임계값 변경 (0 이하, -20 이상 검증)

- **설정 페이지 카드 추가** (`web/templates/settings.html`):
  - "시장 필터 매수 차단 임계값" 카드 (초기자금 카드 아래)
  - 현재값 표시, 숫자 입력(-20~0, step=0.5), 저장 버튼
  - 페이지 로드 시 `GET /api/config/market-filter` 자동 조회

- **검증**: `pytest tests/` 164개 전체 통과

---

## 2026-06-09 — 로그 포맷 버그 수정·매도 sector 누락 수정·dead code 정리·초기자금 재설정 기능 구현

- **로그 포맷 버그 수정** (`screening/market_filter.py`):
  - `%,.2f` 포맷은 Python `%` 스타일 로깅에서 지원하지 않아 `ValueError: unsupported format character ','` 발생
  - `logger.info()`의 `%,.2f` → `%s` + f-string(`f"{value:,.2f}"`) 방식으로 수정 (차단·통과 로그 2곳)
  - OCI 서버 cron.log에서 `--- Logging error ---` 트레이스백이 반복 출력되던 문제 해결

- **매도 체결 sector 누락 수정** (`trading/sell.py`):
  - `add_pending_order()` 호출 시 `sector` 파라미터가 미전달되어 매도 체결 기록에 sector 필드 공백이었음
  - `sector=holding.get("sector", "")` 추가로 수정

- **`_is_valid_stock` dead code 정리** (`screening/first_stage.py`):
  - `_is_valid_stock()` 함수가 정의됐으나 `run_first_stage()` 루프에서 호출되지 않고 동일 로직이 중복 구현됨
  - 루프 내부 인라인 필터 로직을 제거하고 `_is_valid_stock()` 호출로 교체
  - 로그 메시지를 `통과=%d | 제외=%d` 단순화

- **초기자금 수동 재설정 기능 신규 구현**:
  - `web/routers/config_router.py`: `CapitalUpdate` Pydantic 모델 + `POST /api/config/capital` 엔드포인트 추가
    - `from_balance: true` 요청 시 `load_config()` + `KISApiClient.get_balance()` 로 현재 잔고 자동조회
    - `amount` 직접 지정 시 10,000원 이상 검증 후 저장
    - 현재 활성 모드(`app.yaml mode`)만 `data/initial_capital.json`에 갱신 (`save_json_locked` 사용)
  - `web/templates/settings.html`: 설정 페이지에 초기자금 카드 추가
    - 현재 초기자금·설정일 표시 (페이지 로드 시 `GET /api/config/capital` 자동 조회)
    - "잔고 자동조회로 재설정" 버튼 (confirm → `POST {from_balance: true}`)
    - 직접 입력 필드 + 저장 버튼 (confirm → `POST {amount: N}`)
    - Alpine.js 상태: `capital`, `capitalInput`, `capitalSaving`

- **검증**: `pytest tests/` 164개 전체 통과 (기존 테스트 변경 없음)

---

## 2026-06-08 — KOSPI 시장 필터 매수 차단 버그 수정 + Google Drive 경로 오타 수정

- **증상**: 장중 로그에서 `KOSPI 일봉 데이터 부족 (0/20일) → 매수 차단`이 반복 출력되며 매매가 전혀 발생하지 않음.
  실제 API 호출 로그를 보면 `TR=FHKST03010100`(개별종목 일봉 조회)으로 KOSPI 지수 코드(`0001`)를 조회하다 `500 Internal Server Error` 발생.
- **원인**: `get_daily_candles()`(api/kis_api.py)는 `FID_COND_MRKT_DIV_CODE=J`(개별종목 전용) 엔드포인트(`inquire-daily-itemchartprice`)만 사용하는데,
  `screening/market_filter.py`·`screening/market_regime.py`가 KOSPI **지수 코드**를 이 메서드로 조회 — 지수는 별도의 업종 전용 엔드포인트(`inquire-daily-indexchartprice`, TR `FHKUP03500100`, `FID_COND_MRKT_DIV_CODE=U`)와 다른 응답 필드(`bstp_nmix_prpr` 등)를 사용해야 함.
- **수정**:
  - `api/api_constants.py`: `INDEX_DAILY_CANDLE_PATH`, `TrId.INDEX_DAILY_CANDLE`(`FHKUP03500100`) 상수 추가
  - `api/kis_api.py`: 지수 전용 `get_index_daily_candles()` 메서드 신규 추가 (올바른 엔드포인트·시장구분코드·날짜범위 사용)
  - `api/dry_run_client.py`: 동일 시그니처 mock 메서드 추가
  - `screening/market_filter.py`: `get_daily_candles()` → `get_index_daily_candles()`로 교체, 종가 필드를 `stck_clpr` → `bstp_nmix_prpr`로 수정
  - `screening/market_regime.py`: 동일하게 `get_index_daily_candles()` 호출로 교체
  - `tests/conftest.py`: `make_index_candles()` 헬퍼 추가, `mock_api`에 `get_index_daily_candles` mock 등록
  - `tests/test_filters.py`: `is_market_buyable()` 직접 단위 테스트 5건 신규 추가 (이전엔 이 함수에 대한 테스트가 전혀 없어 버그가 발견되지 못했음)
- **부수 수정**: `settings/app.yaml`의 `paths.gdrive_report_remote` 경로 오타 수정 — 기존 폴더명이 `01_Inbox`(대문자 I)인데 설정값은 `01_inbox`(소문자)로 되어 있어 rclone이 기존 폴더를 찾지 못하고 새 폴더(`01_Inbox (1)`)를 생성한 문제. 대소문자를 실제 폴더명과 일치시켜 기존 폴더에 덮어쓰기 동기화되도록 수정
  - `gdrive:obsidian/Second Brain/01_Inbox/auto_trading_report`
- **검증**: `pytest tests/` 164개 전체 통과 (신규 테스트 5건 포함)

---

## 2026-06-07 (추가) — Google Drive 리포트 경로 수정

- `settings/app.yaml`의 `paths.gdrive_report_remote` 값을 아래로 변경
  - `gdrive:obsidian/Second Brain/01_inbox/auto_trading_report`
- 일간/월간 리포트 자동 Google Drive 동기화 대상 경로 업데이트

---

## 2026-06-07 (추가) — OCI 상태 점검

- OCI 서버의 runner.py 동작상태 점검
- 토큰 발급 확인 `cat data/token_cache_paper.json`
- crontab 설정 확인
- `paper` 모드시 초기 자금 강제 할당
- `--dry-run` 통과

---

## 2026-06-07 — 리포지토리 클론 및 상태 점검

- GitHub `nova7zone/kis-auto-trading-bot` 저장소를 현재 폴더에 클론
- `git status` 확인: 상태 깨끗, 브랜치 `master`/`origin/master`
- `build-docs/work-log.md` 존재 확인 및 이전 작업 이력 참조
- 작업 종료: 오늘 변경 사항 없음

---

## 2026-06-05 (추가) — CLAUDE.md 작업 종료 절차 6단계 항목 수정

- 6단계 마크다운 형식 수정

---

## 2026-06-05 (추가) — CLAUDE.md 작업 종료 절차 업데이트

- 작업 종료 절차 순서 조정 (push 위치 변경)
- 6단계 추가: PR 요청

---

## 2026-06-05 — 4가지 기능 추가 + 버그 수정 + 문서 정합성

### fix: token_manager.py 이중 락 데드락 수정
- `get_access_token()`: 외부 FileLock이 `token_cache_paper.json.lock`을 보유한 채
  내부 `save_json_locked()`가 동일 lock 파일 재획득 시도 → 10초 타임아웃 → 캐시 저장 실패
  → 두 번째 토큰 발급 → 403 한도 초과 → 당일 자동매매 중단 버그 수정
- `invalidate_token_cache()`: 동일한 이중 락 패턴 제거

### feat: 구글 드라이브 동기화 on/off 토글
- `settings/app.yaml`: `gdrive_enabled: true` 최상위 키 추가
- `web/routers/config_router.py`: `POST /api/config/gdrive` 엔드포인트 추가
- `report/daily_report.py` + `monthly_report.py`: `gdrive_enabled` 체크 추가
- `web/templates/settings.html`: 구글 드라이브 토글 카드 + Alpine.js `setGdrive()` 추가

### feat: 스크리닝 로그 DB 기록 및 웹 표시
- `trading/buy.py`: 1·2차 스크리닝 후 `insert_screening_log()` 호출 (1차 0개도 기록)
- `screening/second_stage.py`: 선정 종목명·점수 INFO 로그 강화
- `db/repository.py`: `get_screening_logs()` 함수 추가
- `web/routers/api.py`: `GET /api/screening-logs` 엔드포인트 추가
- `web/routers/pages.py`: `GET /screening` 페이지 라우트 추가
- `web/templates/screening.html`: 신규 생성 (날짜·시장국면·1차/2차 갯수·종목명 표시)
- `web/templates/layout.html`: 사이드바 스크리닝 메뉴 추가

### feat: 초기자금 자동 추적
- `settings/app.yaml`: `paths.initial_capital: "data/initial_capital.json"` 추가
- `runner.py`: `_ensure_initial_capital()` 추가 — 최초 실행 시 잔고를 초기자금으로 저장
  (backtest·dry-run 제외)
- `web/routers/config_router.py`: `GET /api/config/capital` 엔드포인트 추가
- `web/templates/dashboard.html`: 초기자금·누적 수익률(%) 카드 추가

### docs: 설치 가이드 python3/pip3 통일
- `docs/INSTALL.md`, `docs/UPDATE.md`, `docs/OCI_QUICKSTART.md`,
  `docs/WEBSERVICE_DEPLOY.md`, `README.md`: 셸 명령어 `python` → `python3`, `pip` → `pip3`

### fix: 정합성 수정
- `/api/config/capital` 엔드포인트를 `api_router` → `config_router`로 이동
- `_ensure_initial_capital`: dry-run 모드 제외 조건 추가
- `buy.py`: 1차 스크리닝 0개여도 screening_log DB 기록

### docs: CLAUDE.md 코드-문서 정합성 수정
- 라우터 표: 6개 신규 라우터 추가
- 주요 명령어: `--dry-run` 추가
- 프로젝트 구조: `api/dry_run_client.py`, `web/templates/` 반영
- 실행 흐름: `_ensure_initial_capital`, `--dry-run` 반영
- 데이터 레이어: `data/initial_capital.json` 추가
- 알려진 주의사항: `insert_screening_log 미호출` 삭제 (수정 완료)
- 테스트 미커버리지: `api/dry_run_client.py` 추가

---

## 2026-06-04 (추가) — 웹 설정 YAML 편집기 + 변경 확인·로그

- `web/routers/config_router.py`: `/api/config/files`, `/api/config/file` (GET/POST) 엔드포인트 추가
  - 화이트리스트 10개 YAML 파일만 접근 허용 (경로 조작 차단)
  - POST 시 `yaml.safe_load()` 문법 검증 후 저장, 오류 시 400 반환
  - 모드·프리셋·파일 저장 성공 시 `[WEB]` 태그 + IP 포함 로그 기록
- `web/templates/settings.html`: 설정 파일 편집 카드 추가
  - 파일 선택 드롭다운 → textarea 로드 → 저장 버튼
  - 미저장 변경사항 표시 + 다른 파일 선택 시 confirm 경고
  - 실행 모드·매매 프리셋·YAML 저장 각각 confirm() 확인 팝업 추가

---

## 2026-06-04 (추가) — Google Drive 보고서 동기화

- `report/gdrive_sync.py` 신규 생성: rclone copy 실행 + 실패 시 Telegram 알림
- `report/daily_report.py` + `monthly_report.py`: MD 저장 후 gdrive 자동 동기화
- `settings/app.yaml`: `paths.report_dir` + `paths.gdrive_report_remote` 추가
- `tests/test_gdrive_sync.py`: 15개 단위 테스트
- `tests/test_md_report_integration.py`: 4개 통합 테스트 추가 (총 10개)
- gdrive_report_remote 비어있으면 동기화 스킵 (opt-in)

---

## 2026-06-04 (추가) — MD 리포트 파일 생성

- `report/md_writer.py` 신규 생성: 일간/월간 MD 빌드·저장 4개 함수
- `report/daily_report.py`: 16:00 리포트 실행 시 `report/daily/YYYY-MM.md` 누적 저장
- `report/monthly_report.py`: 마지막 영업일 `report/monthly/YYYY-MM.md` 생성
- MD 저장 실패는 Telegram 발송에 영향 없음 (try/except 분리)
- `tests/test_md_writer.py`(28개) + `tests/test_md_report_integration.py`(6개): 34개 테스트

---

## 2026-06-04 (추가) — 토큰 403 차단 처리

- `api/token_manager.py`: `TokenBlockedError(BaseException)` + 차단 플래그 함수 + HTTP 403 감지
- `runner.py`: 시작 시 차단 플래그 확인 (조용히 종료) + 첫 403 시 텔레그램 알림 1회
- `tests/test_token_blocked.py`: 13개 단위 테스트 (전체 106개 통과)
- 동작: 당일 첫 403 → 텔레그램 발송 + 종료. 이후 cron → 조용히 종료.

---

## 2026-06-04 (추가) — dry-run 옵션

- `api/dry_run_client.py` 신규 생성: 토큰 발급·API 호출 없는 `DryRunKISApiClient`
- `runner.py`: `--dry-run` 플래그 추가 (API/주문/텔레그램 없이 전체 흐름 점검)
- `tests/test_dry_run.py`: 21개 단위 테스트 (전체 93개 통과)
- 사용법: `python runner.py --dry-run`

---

## 2026-06-04 — 문서 전체 최신화

- OCI_QUICKSTART.md: 10개 중복 구간 출처 표기(📌) + 읽기 순서에 UPDATE.md·WORKFLOW.md 추가 + 참고 문서 7개 섹션
- WORKFLOW.md: 신규 생성 — Mermaid 시스템 구조·데이터 흐름 + ASCII 실행·설정 로드 흐름
- SETTINGS_GUIDE.md: settings/screening/ → settings/screen_config/ 전체 교체
- SETTINGS_REFERENCE.md: KIS_APP_KEY → KIS_LIVE/PAPER_APP_KEY 모드별 분리 + WEB_SESSION_SECRET 추가
- USAGE.md: token_cache.json → 모드별 파일명(live/paper) 수정
- README.md: env 변수명 live/paper 분리 + token_cache + WORKFLOW.md 링크 추가

---

## 2026-05-30 — 브랜치 초기화

- feature/build 브랜치 생성
- build-docs/ 디렉토리 초기화 (work-log.md, next-tasks.md, branches.md)
- CLAUDE.md 작업 시작/종료 절차 추가
