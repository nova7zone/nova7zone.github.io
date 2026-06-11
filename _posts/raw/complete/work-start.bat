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
