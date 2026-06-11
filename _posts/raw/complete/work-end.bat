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
