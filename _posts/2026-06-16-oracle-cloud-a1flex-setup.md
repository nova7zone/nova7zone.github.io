---
layout: post
title: Oracle Cloud Free Tier — A1.Flex 업그레이드와 기본 환경 세팅
date: 2026-06-16 18:00:00 +0900
categories: infrastructure
tags: oracle-cloud ubuntu server swap putty cloud-setup free-tier
author: Evan
description: A1.Flex 인스턴스 확보 후 PuTTY 접속 설정, 1 OCPU/6GB에서 4 OCPU/24GB로 스펙 업그레이드, 스왑·자동회수 방지·방화벽까지 기본 환경을 구성한 과정을 기록한다.
---

**작성일**: 2026년 6월 16일  
**최종 수정**: 2026년 6월 16일  
**분야**: Cloud Infrastructure  
**난이도**: Beginner ~ Intermediate  
**상태**: Production Ready

---

## 들어가며

결론부터 말하면, A1.Flex 인스턴스를 확보한 뒤 PuTTY 접속 설정 → 4 OCPU/24GB 업그레이드 → 스왑·자동회수 방지·방화벽까지 기본 환경 세팅을 마쳤다.

이전 글 [Oracle Cloud Free Tier — E2에서 A1.Flex까지, 11일간의 기록](/posts/oracle-cloud-a1flex-acquisition)에서 3,310번의 시도 끝에 A1.Flex 인스턴스를 확보했다. 이 글은 그 다음 단계 — 접속, 업그레이드, 환경 구성 — 을 기록한다.

---

## 1. 확보된 인스턴스 정보

| 인스턴스 | Public IP | Private IP | 초기 스펙 |
|---|---|---|---|
| a1-flex-instance | (서버 IP) | 10.0.0.253 | 1 OCPU / 6GB |
| instance-lab (E2) | (서버 IP) | 10.0.0.130 | 1 OCPU / 1GB |

두 인스턴스는 같은 VCN(`10.0.0.0/24`) 안에 있어 Private IP로 내부 통신이 가능하다.

---

## 2. SSH 접속 설정 (PuTTY)

Windows 환경에서 PuTTY로 접속한다.

### 기존 E2 키 재사용

A1 스크립트 생성 시 E2의 `authorized_keys`를 그대로 복사했기 때문에 **기존 E2용 `.ppk` 파일을 그대로 사용**할 수 있다.

### PuTTY 세션 추가

1. PuTTY 실행
2. 기존 E2 세션 선택 → **Load**
3. **Host Name** → A1 인스턴스의 Public IP로 변경
4. **Session** 이름 → `a1-flex` 로 입력 후 **Save**
5. **Open** → `login as: ubuntu`

---

## 3. 스펙 업그레이드 — 1/6 → 4/24

생성 직후 스펙은 1 OCPU / 6GB다. Free Tier 한도인 4 OCPU / 24GB로 업그레이드한다.

```bash
# 접속 후 현재 스펙 확인
nproc && free -h
# 1 / 5.8Gi
```

### OCI 콘솔에서 업그레이드

인스턴스를 Stop한 후 Shape을 변경해야 한다.

1. OCI 콘솔 → Compute → Instances
2. `a1-flex-instance` 클릭 (⚠️ E2 인스턴스를 실수로 선택하지 않도록 주의)
3. 우상단 **Actions → Stop**
4. Stopped 상태 확인 후 **Actions → Edit**
5. **VM.Standard.A1.Flex** 행 클릭하여 펼치기
6. Number of OCPUs: `4`, Amount of memory: `24` GB 설정
7. **Save changes**
8. 변경 완료 후 **Start**

> **주의**: Stop 직후 바로 Start를 누르면 "Instance is currently being modified" 오류가 뜰 수 있다. 1~2분 기다린 후 새로고침하면 자동으로 풀린다.

### 업그레이드 완료 확인

```bash
nproc && free -h
```

```
4
               total        used        free      shared  buff/cache   available
Mem:            23Gi       590Mi        22Gi       5.3Mi       817Mi        22Gi
Swap:             0B          0B          0B
```

4 OCPU / 24GB 확인 완료.

---

## 4. 기본 환경 세팅

### 4-1. 시스템 업데이트

```bash
sudo apt update && sudo apt upgrade -y
```

### 4-2. 필수 패키지 설치

```bash
sudo apt install -y python3 python3-pip python3-venv git curl wget htop net-tools unzip
```

### 4-3. 스왑 설정 (4GB)

24GB RAM이라 당장 필수는 아니지만 안정성을 위해 설정한다.

```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 재부팅 후에도 유지
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 확인
free -h
```

```
               total        used        free      shared  buff/cache   available
Mem:            23Gi       613Mi        21Gi       5.3Mi       1.3Gi        22Gi
Swap:          4.0Gi          0B       4.0Gi
```

### 4-4. OCI 자동회수 방지

OCI는 CPU 사용률이 지속적으로 10% 미만이면 인스턴스를 자동회수할 수 있다. `stress-ng`로 주기적으로 CPU를 활성화한다.

```bash
# stress-ng 설치
sudo apt install -y stress-ng

# 크론탭 설정
crontab -e
```

아래 내용을 추가한다. (매시간 :50분에 60초간 실행)

```
50 * * * * /usr/bin/stress-ng --cpu 1 --timeout 60s
```

> **핵심**: 반드시 user crontab(`crontab -e`)을 사용해야 한다. system crontab(`/etc/crontab`)은 username 필드가 필요해 설정이 다르다.

### 4-5. 타임존 설정

```bash
sudo timedatectl set-timezone Asia/Seoul
timedatectl
```

### 4-6. 방화벽 설정

```bash
sudo apt install -y ufw

# 기본 정책
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH 허용
sudo ufw allow 22/tcp

# 활성화
sudo ufw enable

# 확인
sudo ufw status
```

```
Status: active
To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
22/tcp (v6)                ALLOW       Anywhere (v6)
```

---

## 5. 최종 인프라 구성

| 서버 | 스펙 | 역할 |
|---|---|---|
| instance-lab (E2) | 1 OCPU / 1GB RAM | 자동매매 스크립트 전담 |
| a1-flex-instance (A1) | **4 OCPU / 24GB RAM** | Hermes Agent / LLM 서비스 |

---

## 정리

| 항목 | 상태 |
|---|---|
| PuTTY 접속 설정 | ✅ |
| 스펙 업그레이드 (1/6 → 4/24) | ✅ |
| 시스템 업데이트 및 필수 패키지 | ✅ |
| 스왑 4GB 설정 | ✅ |
| OCI 자동회수 방지 크론탭 | ✅ |
| 타임존 (Asia/Seoul) | ✅ |
| 방화벽 (SSH만 허용) | ✅ |

다음 글에서는 이 A1 인스턴스에 Hermes Agent를 올리고, OpenRouter와 Telegram을 연동해 24시간 AI 비서를 만드는 과정을 정리한다.

---

## 참고

- [Oracle Cloud Free Tier — E2에서 A1.Flex까지, 11일간의 기록](/posts/oracle-cloud-a1flex-acquisition)
