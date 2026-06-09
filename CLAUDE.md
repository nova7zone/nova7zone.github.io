# CLAUDE.md — nova7zone.github.io 블로그 포스트 작성 가이드

## 프로젝트 개요

- **플랫폼**: Jekyll + Chirpy 테마 (GitHub Pages)
- **URL**: https://nova7zone.github.io
- **언어**: 한국어 (lang: ko)
- **작성자**: Evan
- **주제**: AI(Claude Code)를 이용한 프로그램 개발 과정 기록

---

## 포스트 파일 규칙

### 파일 위치 및 이름

```
_posts/YYYY-MM-DD-slug.md
```

- 날짜는 실제 작성일 기준 `YYYY-MM-DD` 형식
- slug는 소문자 영문 + 하이픈, 한국어 미사용
- 예: `2026-05-28-oracle-cloud-setup-1.md`

### 이미지 위치

```
assets/img/{post-slug}/imageN.png
```

- post-slug는 파일명의 날짜를 뺀 부분
- 번호는 1부터 순서대로 (`image1.png`, `image2.png`, ...)
- 마크다운 참조: `![설명](/assets/img/{slug}/imageN.png)`

---

## Front Matter 형식

```yaml
---
layout: post
title: 제목 — 부제목 형식 (em dash 사용)
date: 2026-05-28 15:01:00 +0900
categories: category1 category2
tags: tag1 tag2 tag3
author: Evan
description: SEO용 한 줄 요약. 핵심 내용과 결과를 포함한다.
---
```

### categories (소문자, 공백 구분)

- `infrastructure` — 서버/클라우드 설정
- `devops` — 배포, 운영 자동화
- `trading` — 자동매매 관련
- `development` — 개발 일반

### tags (소문자-하이픈, 공백 구분)

기존 태그 우선 재사용:
`oracle-cloud`, `ubuntu`, `server`, `sftp`, `swap`, `putty`,
`ai-trading`, `kis-api`, `claude-code`, `gemini`, `prompt-engineering`, `python`,
`cloud-setup`, `free-tier`

---

## 포스트 본문 구조

### 1. 메타 헤더 블록 (front matter 직후)

```markdown
**작성일**: YYYY년 M월 D일  
**최종 수정**: YYYY년 M월 D일  
**분야**: 분야1, 분야2  
**난이도**: Beginner / Intermediate / Advanced  
**상태**: Production Ready / In Progress / Draft

---
```

`난이도` 조합 표현: `Beginner ~ Intermediate`처럼 범위로 쓸 수 있다.

### 2. 들어가며 (필수)

- 포스트의 배경과 목적
- **결론을 먼저** 언급 ("결론부터 말하면 ...")
- 이전 글이 있으면 링크로 연결

### 3. 본문 섹션

- 섹션 구분은 `---`
- H2(`##`)로 대주제, H3(`###`)로 소주제
- 스크린샷이 있는 경우 이미지 바로 아래 설명을 bullet으로 나열
- 코드 블록에는 언어 명시 (bash, python, yaml 등)
- 실패/에러가 있으면 ❌, 성공이면 ✅ 이모지 사용

### 4. 정리 / 요약 (필수)

- 표(table)로 핵심 결과 요약하는 방식 선호
- 실패 vs 성공 비교 표 활용
- "다음 글에서는 ..." 형태로 다음 포스트 예고 가능

### 5. 참고 (선택)

외부 링크를 참조했을 경우 마지막에 목록으로 추가.

---

## 문체 규칙

- 문장 종결: **한다 / 이다** 체 (경어체 아님)
- 설명보다 **경험** 중심으로 서술 ("~했다", "~이 발생했다")
- 기술 용어는 영문 그대로 사용 (번역 불필요)
- 강조는 `**볼드**` 사용, 이탤릭 미사용
- 긴 설명보다 짧은 bullet + 코드 조합 선호

---

## 시리즈 포스트 규칙

파일명 끝에 번호 추가: `oracle-cloud-setup-1.md`, `oracle-cloud-setup-2.md`

제목 형식: `주제 (N) — 부제목`
예: `AI를 이용한 자동매매 프로그램 작성 (3) — Gemini 검토 결과, KIS API 확정`

---

## 작업 흐름

1. `_posts/raw/` 폴더 및 하위 자료를 확인 (처리 완료된 자료는 `_posts/raw/complete/` 로 이동)
2. 자료에 추가 될 수 있는 자료 확보 및 post 작성
3. `_posts/YYYY-MM-DD-slug.md` 파일 생성 후 `_posts/draft/` 에 저장
4. 스크린샷은 `assets/img/{slug}/` 폴더에 저장 후 본문에 삽입
5. 로컬 미리보기: `bundle exec jekyll serve` (또는 `tools/run.sh`)
6. post 내용 확인 질문
7. 확인 완료 후 커밋: `feat: add post {slug}` 형식
8. `main` 브랜치 push → GitHub Actions가 자동 배포

---

## 자주 쓰는 마크다운 패턴

### 결과 요약 표

```markdown
| 항목 | 값 |
|------|-----|
| Name | instance-lab |
| State | **Running** |
```

### 비교 표

```markdown
| 항목 | 1차 시도 (실패) | 2차 시도 (성공) |
|------|----------------|----------------|
| CPU  | ARM AMPERE     | AMD EPYC       |
```

### 단계별 명령어 블록

```markdown
**1단계: 파일 생성**

```bash
sudo fallocate -l 4G /swapfile
```
```

### 에러/해결 패턴

```markdown
### ❌ 에러 원인: "에러 메시지"

원인 설명.

**해결 방법:**
1. 방법 1
2. 방법 2
```
