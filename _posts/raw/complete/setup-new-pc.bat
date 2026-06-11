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
