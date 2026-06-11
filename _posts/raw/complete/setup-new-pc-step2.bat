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
