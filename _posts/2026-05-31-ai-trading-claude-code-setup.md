---
layout: post
title: AI를 이용한 자동매매 프로그램 작성 (4) — Claude Code 환경 구축과 멀티 PC 동기화 자동화
date: 2026-05-31 11:48:00 +0900
categories: trading devops
tags: ai-trading claude-code github git automation python
author: Evan
description: Claude Code의 클라우드 저장소 연동은 실패했지만, 로컬 프로젝트와 Git 동기화 배치 파일 4종을 조합해 여러 PC에서 이어서 작업할 수 있는 개발 환경을 구축한 과정을 기록한다.
---

**작성일**: 2026년 5월 31일  
**최종 수정**: 2026년 5월 31일  
**분야**: AI Trading, DevOps  
**난이도**: Beginner ~ Intermediate  
**상태**: Production Ready

---

## 들어가며

[이전 글](/posts/ai-trading-kis-api/)에서 V4 프롬프트를 완성했으니, 이제 이 프롬프트를 Claude Code에 넘겨 실제 프로그램을 작성할 차례다.

결론부터 말하면, Claude Code에서 저장소를 클라우드로 바로 연동하는 것은 실패했다. 대신 **로컬 프로젝트 폴더 + Git 동기화 배치 파일** 조합으로 여러 컴퓨터를 오가며 작업을 이어갈 수 있는 환경을 만들었다.

---

## Claude Desktop 설치 및 Claude Code 실행

Claude 데스크탑을 설치하고, 실제 코드 작업은 Claude Code로 진행하기로 했다.

### ❌ 클라우드 저장소 연동 — 실패

Claude Code에서 저장소를 클라우드로 설정하고 새로 가입한 GitHub과 연동을 시도했으나 되지 않았다.

**해결 방법:**
1. 일단 로컬에 프로젝트 폴더를 만들고 프롬프트 파일을 저장
2. 로컬로 지정하니 **Git for Windows**가 필요하다는 안내가 나와서 설치
3. 설치 후 Claude Desktop 재시작

> Claude Code Pro에는 가입되어 있는데, Claude Code 실행 시 별도 과금이 있는지는 추후 확인이 필요하다.

---

## Gemini에게 "어떻게 시켜야 하는지" 물어보기

Claude Code에 작업을 어떤 식으로 지시해야 할지 감이 안 잡혀서, Gemini에게 먼저 질의했다.

**Gemini의 답변 (Claude Code에 입력할 프롬프트):**

```text
현재 폴더에 있는 KIS_TRADING_PROMPT_V4_EN.txt 파일을 꼼꼼히 읽고,
명세서에 맞춰 프로젝트 구축을 시작해 줘.

특히 파일 마지막의 SECTION 19 [AI 에이전트를 위한 필수 지시사항]을
엄격하게 지켜야 해. 절대 한 번에 모든 코드를 짜지 말고,
가장 먼저 1단계(핵심 프로젝트 구조 생성, requirements.txt,
.gitignore, 기본 설정 파일 작성)만 수행해 줘.

1단계 작성이 끝나면 터미널에서 git add . 와
git commit -m "chore: initial project setup"을 실행해서
작업 상태를 저장하고, 다음 단계(API 통신 로직 등)로 넘어갈지
나에게 물어봐. 답변은 한글로 해줘
```

**진행 팁 (Gemini):**

> 이렇게 지시를 내리면 Claude Code가 폴더 구조를 예쁘게 만들고 기본 파일들을 생성한 뒤, 커밋까지 스스로 마칠 것이다. 에이전트가 멈추고 다음 작업을 물어보면, "완벽해! 이제 2단계인 API 클라이언트 부분(kis_api.py, token_manager.py)을 만들어줘" 하는 식으로 대화하듯 이어나가면 된다.

이 방식대로 **단계별 지시 + 단계마다 커밋**하는 패턴으로 작업을 진행했다.

---

## 멀티 PC 동기화 환경 구축

작업을 여러 컴퓨터에서 이어서 할 수 있도록, 다음 두 가지를 완료했다.

1. Claude Code와 GitHub 연동 완료
2. 새 컴퓨터에서 환경을 자동으로 세팅하는 배치 파일 4종 작성

새로운 컴퓨터에서는 아래 순서로 진행하면 이전 작업을 그대로 이어갈 수 있다.

```text
1. setup-new-pc.bat 실행         → 도구 설치 (winget)
2. 터미널 완전히 닫고 새로 열기  → PATH 적용
3. setup-new-pc-step2.bat 실행   → git 설정, GitHub 로그인, 클론, venv
```

### 1단계: 도구 설치 — `setup-new-pc.bat`

`winget`으로 Git, GitHub CLI, Python, Node.js를 한 번에 설치한다. PATH가 적용되려면 새 터미널을 열어야 하므로 여기서 한 번 끊어준다.

```batch
@echo off
chcp 65001 > nul
echo.
echo ╔══════════════════════════════════════════════════╗
echo ║     KIS 자동매매봇 개발환경 최초 설정             ║
echo ║     (새 컴퓨터 최초 1회만 실행)                   ║
echo ╚══════════════════════════════════════════════════╝
echo.

:: ── 1단계: 필수 도구 설치 ──────────────────────────────
echo [1/5] 필수 도구 설치 중...
echo       (이미 설치된 항목은 자동으로 건너뜁니다)
echo.

winget install Git.Git -e --silent
winget install GitHub.cli -e --silent
winget install Python.Python.3.11 -e --silent
winget install OpenJS.NodeJS.LTS -e --silent

echo.
echo  ⚠  설치 완료. PATH 적용을 위해 새 터미널이 필요합니다.
echo     이 창을 닫고, 새 cmd 창을 열어서 아래 파일을 실행하세요:
echo.
echo     setup-new-pc-step2.bat
echo.
pause
```

### 2단계: Git/GitHub 설정 및 클론 — `setup-new-pc-step2.bat`

Git 사용자 정보 입력, `gh auth login`으로 GitHub 로그인, 저장소 클론, 가상환경(venv) 생성 및 패키지 설치, 마지막으로 Claude Code 설치까지 한 번에 처리한다.

```batch
@echo off
chcp 65001 > nul
echo.
echo ╔══════════════════════════════════════════════════╗
echo ║     KIS 자동매매봇 개발환경 설정 2단계            ║
echo ╚══════════════════════════════════════════════════╝
echo.

:: ── GitHub CLI PATH 확인 ───────────────────────────────
set GH_PATH=C:\Program Files\GitHub CLI
if exist "%GH_PATH%\gh.exe" (
    set PATH=%PATH%;%GH_PATH%
) else (
    echo  ✗ GitHub CLI를 찾을 수 없습니다. setup-new-pc.bat 을 먼저 실행하세요.
    pause & exit /b 1
)

:: ── 2단계: Git 사용자 설정 ─────────────────────────────
echo [2/5] Git 사용자 설정
echo.
set /p GIT_NAME=GitHub 사용자 이름 입력 (예: Evan-ai-pro):
set /p GIT_EMAIL=GitHub 이메일 입력:
git config --global user.name "%GIT_NAME%"
git config --global user.email "%GIT_EMAIL%"
echo  ✓ Git 사용자 설정 완료
echo.

:: ── 3단계: GitHub 로그인 ───────────────────────────────
echo [3/5] GitHub 로그인 (브라우저가 열립니다)
echo.
"%GH_PATH%\gh.exe" auth login
echo.

:: ── 4단계: 저장소 클론 ────────────────────────────────
echo [4/5] 저장소 클론
echo.
set /p CLONE_DIR=저장소를 저장할 폴더 경로 입력 (예: C:\dev):
if not exist "%CLONE_DIR%" mkdir "%CLONE_DIR%"
cd /d "%CLONE_DIR%"
git clone https://github.com/Evan-ai-pro/kis-auto-trading-bot
cd kis-auto-trading-bot
echo  ✓ 클론 완료: %CLONE_DIR%\kis-auto-trading-bot
echo.

:: ── 5단계: Python 가상환경 및 패키지 설치 ─────────────
echo [5/5] Python 가상환경 및 패키지 설치
echo.
python -m venv venv
call venv\Scripts\activate.bat
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet
echo  ✓ 패키지 설치 완료
echo.

:: ── Claude Code 설치 ───────────────────────────────────
echo [+] Claude Code 설치
npm install -g @anthropic-ai/claude-code --silent
echo  ✓ Claude Code 설치 완료
echo.

:: ── 테스트 실행으로 환경 검증 ─────────────────────────
echo [검증] pytest 실행으로 환경 확인 중...
pytest tests/ -q
echo.

echo ╔══════════════════════════════════════════════════╗
echo ║  설정 완료! 이후 작업 시작 전에는               ║
echo ║  scripts\work-start.bat 을 실행하세요.          ║
echo ╚══════════════════════════════════════════════════╝
echo.
pause
```

---

## 작업 시작/종료 자동화

새 컴퓨터 설정이 끝나면, 매번 작업을 시작하고 끝낼 때마다 아래 두 스크립트만 실행하면 된다.

```bash
# 1. 저장소 폴더로 이동
cd C:\my_project\claude\kis-auto-trading-bot

# 2. 동기화 (work-start.bat 실행)
scripts\work-start.bat

# 3. Claude Code 시작
claude
```

### 작업 시작 — `work-start.bat`

`master` 브랜치를 최신화하고, 이어서 작업할 브랜치를 선택한 뒤, 가상환경까지 자동으로 활성화한다.

```batch
@echo off
chcp 65001 > nul

:: 저장소 루트로 이동 (이 스크립트가 scripts\ 안에 있으므로 한 단계 위로)
cd /d "%~dp0.."

echo.
echo ╔══════════════════════════════════════════════════╗
echo ║     작업 시작 전 동기화                           ║
echo ╚══════════════════════════════════════════════════╝
echo.

:: ── GitHub CLI PATH 설정 ───────────────────────────────
set GH_PATH=C:\Program Files\GitHub CLI
if exist "%GH_PATH%\gh.exe" set PATH=%PATH%;%GH_PATH%

:: ── 현재 상태 표시 ────────────────────────────────────
echo [현재 상태]
git status --short
echo.

:: ── GitHub에서 최신 정보 가져오기 ─────────────────────
echo [동기화 중] GitHub에서 최신 코드 가져오는 중...
git fetch --all --quiet
echo  ✓ fetch 완료
echo.

:: ── master 최신화 ─────────────────────────────────────
echo [master 업데이트]
git checkout master --quiet
git pull origin master
echo.

:: ── 이어서 할 브랜치 확인 ─────────────────────────────
echo [브랜치 목록] (원격 포함)
git branch -a
echo.

set /p BRANCH=이어서 작업할 브랜치 이름 입력 (master면 그냥 Enter):
if "%BRANCH%"=="" (
    echo  → master 브랜치에서 작업합니다.
) else (
    git checkout %BRANCH% 2>nul || git checkout -b %BRANCH% --track origin/%BRANCH% 2>nul
    git pull origin %BRANCH% 2>nul
    echo  ✓ 브랜치 전환 완료: %BRANCH%
)
echo.

:: ── 가상환경 활성화 ────────────────────────────────────
if exist "venv\Scripts\activate.bat" (
    call venv\Scripts\activate.bat
    echo  ✓ 가상환경 활성화 완료
) else (
    echo  ⚠ 가상환경 없음. setup-new-pc-step2.bat 을 먼저 실행하세요.
)
echo.

echo ╔══════════════════════════════════════════════════╗
echo ║  동기화 완료. Claude Code를 시작하려면:          ║
echo ║  claude                                          ║
echo ╚══════════════════════════════════════════════════╝
echo.
cmd /k
```

### 작업 종료 — `work-end.bat`

변경사항을 확인하고, 커밋 → push → (필요하면) PR 생성까지 한 번에 처리한다. PR 생성 시 본문에는 `gh pr create`로 바로 "Generated with Claude Code" 문구가 들어간 템플릿이 채워진다.

```batch
@echo off
chcp 65001 > nul

:: 저장소 루트로 이동
cd /d "%~dp0.."

echo.
echo ╔══════════════════════════════════════════════════╗
echo ║     작업 종료 — GitHub 저장 및 PR                ║
echo ╚══════════════════════════════════════════════════╝
echo.

:: ── GitHub CLI PATH 설정 ───────────────────────────────
set GH_PATH=C:\Program Files\GitHub CLI
if exist "%GH_PATH%\gh.exe" set PATH=%PATH%;%GH_PATH%

:: ── 현재 브랜치 확인 ──────────────────────────────────
for /f %%i in ('git branch --show-current') do set CURRENT_BRANCH=%%i
echo [현재 브랜치] %CURRENT_BRANCH%
echo.

:: ── 변경사항 확인 ─────────────────────────────────────
echo [변경된 파일]
git status --short
echo.

:: ── 미저장 변경사항 커밋 여부 확인 ────────────────────
git diff --quiet && git diff --cached --quiet
if %errorlevel% neq 0 (
    set /p DO_COMMIT=커밋할 변경사항이 있습니다. 커밋하시겠습니까? [Y/n]:
    if /i not "%DO_COMMIT%"=="n" (
        set /p COMMIT_MSG=커밋 메시지 입력 (예: feat: 매수 로직 개선):
        git add -A
        git commit -m "%COMMIT_MSG%"
        echo  ✓ 커밋 완료
    )
) else (
    echo  → 커밋할 변경사항 없음
)
echo.

:: ── GitHub에 Push ──────────────────────────────────────
set /p DO_PUSH=현재 브랜치(%CURRENT_BRANCH%)를 GitHub에 push하시겠습니까? [Y/n]:
if /i "%DO_PUSH%"=="n" goto DONE

git push origin %CURRENT_BRANCH%
if %errorlevel% neq 0 (
    git push --set-upstream origin %CURRENT_BRANCH%
)
echo  ✓ push 완료
echo.

:: ── PR 생성 여부 확인 ─────────────────────────────────
if "%CURRENT_BRANCH%"=="master" goto DONE

set /p DO_PR=PR을 생성하시겠습니까? [y/N]:
if /i not "%DO_PR%"=="y" goto DONE

set /p PR_TITLE=PR 제목 입력:
"%GH_PATH%\gh.exe" pr create --title "%PR_TITLE%" --body "## Summary%0a- %PR_TITLE%%0a%0a## Test plan%0a- [ ] CI 녹색 확인%0a%0a🤖 Generated with Claude Code" --web
echo  ✓ PR 생성 완료 (브라우저에서 확인하세요)
echo.

:DONE
echo.
echo ╔══════════════════════════════════════════════════╗
echo ║  완료. 다음 작업 시작 전에는                     ║
echo ║  scripts\work-start.bat 을 실행하세요.          ║
echo ╚══════════════════════════════════════════════════╝
echo.
pause
```

---

## 정리

| 항목 | 내용 |
|------|------|
| Claude Code ↔ GitHub 클라우드 직접 연동 | ❌ 실패 (로컬 프로젝트 방식으로 우회) |
| 작업 지시 방식 | 단계별 지시 + 단계마다 git commit (Gemini 제안) |
| 새 PC 환경 설정 | `setup-new-pc.bat` → 새 터미널 → `setup-new-pc-step2.bat` |
| 작업 시작 | `scripts\work-start.bat` (fetch, master 동기화, 브랜치 선택, venv 활성화) |
| 작업 종료 | `scripts\work-end.bat` (commit, push, 선택적 PR 생성) |

이렇게 어떤 컴퓨터에서든 동일한 명령 두 줄(`work-start.bat`, `claude`)로 작업을 이어갈 수 있는 환경이 만들어졌다.

다음 글에서는 Claude Code에 V4 프롬프트를 전달하고 실제로 프로젝트 구조를 생성하는 단계부터 이어서 기록한다.
