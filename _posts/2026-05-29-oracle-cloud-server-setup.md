---
layout: post
title: Oracle Cloud 무료 티어 인스턴스 운영하기
date: 2026-05-29 09:43:00 +0900
categories: infrastructure
tags: oracle-cloud ai-trading cloud-setup ubuntu server sftp
author: Evan
description: OCI 무료 티어 서버 필수 설정 - 고정IP, 메모리, SFTP
---

# Oracle Cloud 무료 티어 인스턴스 운영하기: 고정 IP와 가상 메모리 설정

**작성일**: 2026년 5월 29일  
**최종 수정**: 2026년 6월 7일  
**분야**: Infrastructure  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

자동화된 주식 거래 시스템을 구축할 때 **안정적인 서버 환경**은 필수입니다. Oracle Cloud의 무료 티어는 훌륭한 선택이지만, 그대로 사용하면 두 가지 문제에 직면합니다:

1. **IP가 변경된다** - 외부에서 접속할 수 없게 됨
2. **메모리 부족** - 특히 AMD 1GB 기본 사양에서 거래 봇이 뻗을 수 있음

이 글에서는 이 두 문제를 단계별로 해결하는 방법을 다룹니다.

---

## Part 1: Reserved Public IP 설정하기

거래 시스템을 구축하다 보면 IP 주소가 **일정하게 유지**되어야 합니다. API 접근 제어, 방화벽 규칙, DNS 레코드 등이 모두 고정 IP에 의존하기 때문입니다.

### 1단계: IPv4 Addresses 접근

1. Oracle Cloud 콘솔에서 **Instances**로 이동
2. 대상 인스턴스를 선택 후 **Attached VNICs** 섹션에서 **IPv4 Addresses** 클릭

### 2단계: 기존 IP 제거

먼저 **이전의 공개 IP를 삭제**해야 합니다. (Reserved IP로 새로 할당하기 위해)

1. "더보기" 버튼(⋯) 클릭
2. **Edit** 선택
3. **NO PUBLIC IP** 선택
4. **Update** 버튼 클릭

이제 Public IP가 사라집니다. 이건 정상입니다.

### 3단계: Reserved IP 새로 생성

1. **더보기** 버튼 다시 클릭
2. **Edit** 선택
3. **RESERVED PUBLIC IP** 선택
4. **CREATE NEW RESERVED IP ADDRESS** 클릭
5. IP 주소의 이름 설정 (예: `stock-trading-bot-ip`)
6. Compartment에서 **Oracle** 선택
7. **Assign** 클릭

### 4단계: 확인

IP 목록에서 해당 주소 옆에 **"Reserved"** 표시가 보이면 완료입니다. 이제 이 IP는 변경되지 않으며, 외부에서 안정적으로 접속할 수 있습니다.

---

## Part 2: Ubuntu에 초기 접속 및 권한 설정

### SSH 키 변환 (Windows PUTTY 사용자)

Oracle Cloud에서 다운로드한 `.key` 파일을 PUTTY가 인식하는 `.ppk` 형식으로 변환해야 합니다.

1. **PUTTYgen** 실행
2. "Load" 클릭 후 다운로드한 `.key` 파일 선택
3. "Save private key" 클릭
4. 비밀번호 설정 (보안을 위해 필수)
5. `.ppk` 파일로 저장

### 초기 접속

```
호스트: ubuntu@[Reserved IP 주소]
포트: 22
인증: 위에서 생성한 .ppk 파일
```

### Root 계정 설정

보안상 Ubuntu 계정으로 접속하지만, 관리 작업을 위해 root 비밀번호를 설정합니다.

```bash
# 초기 접속 후
sudo passwd root
# 새로운 root 비밀번호 입력

# root 계정으로 전환
su root
```

---

## Part 3: 가상 메모리(Swap) 추가하기

**가장 중요한 부분입니다.** Oracle Cloud 무료 티어(RAM 1GB)에서 거래 봇을 운영하면 메모리 부족으로 프로세스가 강제 종료될 수 있습니다. 가상 메모리를 추가해 이를 방지합니다.

### 현재 메모리 상태 확인

```bash
free -h
```

**Swap이 0B이거나 매우 작으면** 아래 단계를 진행하세요.

```
               total        used        free      shared  buff/cache   available
Mem:           956Mi       217Mi        95Mi       1.0Mi       643Mi       590Mi
Swap:             0B          0B          0B
# ↑ 이렇게 나오면 설정 필요
```

### 4GB Swap 생성 및 활성화

**1단계: Swap 파일 생성**

```bash
sudo fallocate -l 4G /swapfile
```

⚠️ **fallocate가 실패하는 경우** (일부 시스템):

```bash
sudo dd if=/dev/zero of=/swapfile bs=1M count=4096
```

**2단계: 권한 설정 (보안)**

```bash
sudo chmod 600 /swapfile
```

이 단계를 건너뛰면 보안 경고가 발생합니다. 루트 계정만 접근할 수 있도록 제한합니다.

**3단계: Swap 포맷 및 활성화**

```bash
sudo mkswap /swapfile
sudo swapon /swapfile
```

**4단계: 부팅 시 자동 적용 (중요)**

재부팅 후에도 Swap이 유지되도록 설정합니다.

```bash
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 최종 확인

```bash
free -h
```

**완료 기준**: Swap 부분에 4.0Gi가 표시되면 성공입니다.

```
               total        used        free      shared  buff/cache   available
Mem:           956Mi       217Mi        95Mi       1.0Mi       643Mi       590Mi
Swap:          4.0Gi          0B       4.0Gi
# ✅ Swap이 4.0Gi로 잡혔음
```

---

## Part 4: FileZilla로 SFTP 접속 설정하기

서버에 파일을 업로드하고 관리하려면 FTP/SFTP 클라이언트가 필수입니다. **FileZilla**는 무료이면서도 SFTP 키 인증을 완벽하게 지원합니다.

### FileZilla 설치

Windows에서는 **무설치 버전(Portable)**을 권장합니다.

1. [FileZilla 공식 사이트](https://filezilla-project.org/)에서 `filezilla-3.67.0` 이상 다운로드
2. 압축 해제 후 `filezilla.exe` 실행 (설치 불필요)

### SFTP 사이트 설정

**1단계: 사이트 관리자 열기**

```
FileZilla 메뉴 → 파일 → 사이트 관리자 (또는 Ctrl+S)
```

**2단계: 새 사이트 추가**

- "새사이트" 클릭
- 이름: `nova_lab` (또는 본인이 원하는 이름)

**3단계: 연결 정보 입력**

| 항목 | 값 |
|------|-----|
| **프로토콜** | SFTP - SSH File Transfer Protocol |
| **호스트** | 168.110.107.113 (Reserved IP) |
| **포트** | 22 |
| **로그온 유형** | 키 파일 |
| **사용자** | ubuntu |
| **키 파일** | PUTTYgen에서 생성한 `.key` 파일 |
| **비밀번호** | 키 파일 생성 시 설정한 비밀번호 (예: 23692390) |

**4단계: 비밀번호 저장 설정**

- "비밀번호 저장" 체크
- 다음 접속부터 자동으로 인증됨

**5단계: 연결 테스트**

- "연결" 버튼 클릭
- 정상 연결되면 원격 서버의 파일 목록이 보임

### 파일 업로드 후 소유권 확인

FileZilla를 통해 업로드한 파일의 소유자는 자동으로 **ubuntu**로 설정됩니다.

```bash
# 서버에서 확인
ls -l /path/to/uploaded/file

# 결과 예시
-rw-r--r-- 1 ubuntu ubuntu 1024 May 29 10:30 myfile.py
```

거래 봇 코드를 업로드할 때는 파일 권한에 주의하세요:

```bash
# 스크립트 실행 권한 추가
chmod +x /path/to/trading_bot.py

# 로그 파일 쓰기 권한 (디렉토리)
chmod 755 /path/to/logs
```

---

## 이제 준비 완료

이 네 가지 설정으로:

✅ **고정 IP** - 외부에서 안정적으로 접속 가능  
✅ **충분한 메모리** - 거래 봇이 메모리 부족으로 뻗지 않음  
✅ **SSH 접근** - 터미널로 서버 관리 가능  
✅ **파일 전송** - FileZilla로 편리하게 파일 관리  
✅ **자동 복구** - 서버 재부팅 후에도 모든 설정이 유지됨  

다음 단계는 Python 환경 구성과 거래 시스템 배포입니다. 막히는 부분이 있으면 언제든 말씀해 주세요.

---

## 참고 자료

- [Oracle Cloud 공식 문서](https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/managingpublicips.htm)
- [Ubuntu Swap 설정 가이드](https://help.ubuntu.com/community/SwapFaq)
