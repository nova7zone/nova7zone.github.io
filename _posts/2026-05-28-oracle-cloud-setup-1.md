---
layout: post
title: AI 자동 매매 시스템을 위한 Oracle Cloud 인프라 구축기
date: 2026-05-28 15:01:00 +0900
categories: infrastructure devops
tags: oracle-cloud ai-trading cloud-setup
author: Evan
description: Oracle Cloud에서 Free Tier를 활용하여 AI 거래 시스템용 서버를 구축하는 과정. ARM 기반 구축 실패, AMD로의 전환, 최종 성공까지의 전 과정을 다룬다.
---

**작성일**: 2026년 5월 28일  
**최종 수정**: 2026년 5월 28일  
**분야**: Cloud Infrastructure, DevOps  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

AI 기반 자동 주식 거래 시스템을 구축하려면 안정적이고 경제적인 클라우드 인프라가 필수다. 이 글에서는 Oracle Cloud Infrastructure(OCI)를 활용하여 전용 서버를 구축하는 과정과, 그 과정에서 마주쳤던 문제와 해결 방법을 공유한다.

**주요 내용:**
- Oracle Cloud Free Tier 활용
- ARM vs AMD CPU 선택의 중요성
- Out of host capacity 에러 해결 방법
- 완성된 인프라 구축 및 검증

---

## 목표 아키텍처

```
AI Trading System
    ↓
Oracle Cloud Compute Instance (AMD-based)
    ├── OS: Ubuntu 22.04 LTS
    ├── CPU: 4 vCPU (AMD EPYC)
    ├── Memory: 24 GB
    └── Network: Public IP + Private VPC
```

실제 거래 신호 생성, 포지션 관리, 리스크 제어 등의 연산을 24/7 실행할 서버가 필요했고, Oracle Cloud의 Free Tier 리소스를 활용하기로 결정했다.

---

## Phase 1: 초기 구축 시도 및 실패

### 1.1 계획 수립

초기 구축 계획은 다음과 같았다:

- **Availability Domain**: AD 1 (ap-chuncheon-1)
- **Instance Name**: instance-auto
- **Compartment**: nova_lab (root)
- **Image**: Canonical Ubuntu 22.04 LTS
- **Shape**: VM.Standard.A1.Flex (Always Free-eligible)

ARM 기반의 AMPERE CPU를 선택한 이유는 Oracle Cloud의 Always Free Tier에서 제공하는 가장 경제적인 옵션이었기 때문이다.

### 1.2 실패: Out of host capacity 에러

인스턴스 생성을 시도하면 다음 에러가 발생했다:

```
Error: 500-InternalError
Out of host capacity
```

**에러 로그:**
```
ap-chuncheon-1 리전의 인프라 자원이 현재 꽉 찬 상태
해당 Availability Domain에서 요청하는 Shape에 할당할 수 있는 호스트가 없음
```

### 1.3 근본 원인 분석

이 에러의 정체는 다음과 같았다:

1. **지역적 제약**: ap-chuncheon-1(춘천) AD에 ARM 기반 호스트 자원 부족
2. **Shape 인기도**: VM.Standard.A1.Flex는 Free Tier 사용자들 사이에서 매우 인기 있는 옵션
3. **Capacity Planning 문제**: Oracle Cloud가 해당 지역의 수용 능력을 초과한 상태

---

## Phase 2: 해결 전략 및 재구축

### 2.1 문제 해결 방향

여러 해결 방안을 검토했다:

| 방안 | 장점 | 단점 |
|------|------|------|
| 다른 AD 시도 | 리소스 있을 가능성 | 한국 리전 내 다른 AD 부족 |
| 시간 경과 대기 | 자원 확충 대기 | 시간 소비 |
| **CPU 아키텍처 변경** | **즉시 해결 가능** | **CPU 및 저장용량 감소** |

ARM(AMPERE) → AMD(EPYC)로 변경하기로 결정했다.

### 2.2 AMD 기반 구축

**변경 사항:**

```yaml
Shape 변경:
  Before: VM.Standard.A1.Flex (ARM AMPERE)
  After:  VM.Standard.E2.1.Micro (AMD EPYC)

Specifications:
  CPU:       1 vCPU (AMD EPYC, Always Free-eligible)
  Memory:    1 GB
  Network:   0.48 Gbps
  Storage:   Boot volume included
```

### 2.3 상세 구축 프로세스

#### Step 1: 기본 정보 입력

```
Instance Name:    instance-lab
Compartment:      nova_lab (root)
Image:            Canonical Ubuntu 22.04 LTS
Image Build:      2026.04.30-1
Security:         Shielded Instance
```

#### Step 2: 리소스 배치

```
Availability Domain: AD 1 (FGOAE-AP-CHUNCHEON-1-AD-1)
Shape:              VM.Standard.E2.1.Micro
Allocation:         Always Free-eligible
```

#### Step 3: 네트워킹 구성

```
Virtual Cloud Network (VCN):
  Name: vcn-2026/05/28-1454
  CIDR: 10.0.0.0/16

Primary VNIC:
  Name: nova_vnic
  Subnet: subnet-2026/05/28-1454
  IPv4 CIDR: 10.0.0.0/24
```

- **Public IP**: 할당함 (외부 접근 필요)
- **Private IP**: 자동 할당 (VPC 내부)
- **Subnet Configuration**: Private IPv4 주소 자동 할당

#### Step 4: 보안 설정

```
Security Groups:
  - Shielded Instance 활성화
  - Firmware security: Secure Boot + Measured Boot + TPM
  - Platform Module (TPM): Oracle Verified Boot

Management:
  - Instance Metadata Service: Enabled (IMDSv2)
  - Oracle Cloud Agent: Enabled
    └── Custom Logs Monitoring
    └── Compute Instance Monitoring
    └── Cloud Guard Workload Protection
```

#### Step 5: 초기화 스크립트 및 에이전트

```bash
# Oracle Cloud Agent 역할:
# - 플러그인 관리 (Plugins)
# - 성능 메트릭 수집
# - OS 업데이트 및 패치 설치
# - 인스턴스 관리 작업 수행
```

### 2.4 생성 완료 및 검증

```
Instance State:     Running ✓
Public IP:          할당됨
Shape:              VM.Standard.E2.1.Micro
Availability Domain: AD 1
OCPU Count:         1
Memory (GB):        1
```

최종적으로 **2026년 5월 28일 15:01**에 인스턴스 생성 완료.

---

## 보안 구성

### 3.1 인증 및 접근 제어

```
SSH Key Authentication:
  - Key Pair 생성 (OpenSSH format)
  - Public key: Instance에 등록
  - Private key: 로컬 저장

2FA (Two-Factor Authentication):
  - Google Authenticator 적용
  - Recovery codes: Google Keep 백업
```

### 3.2 인스턴스 보안

```
Shielded Instance Features:
  1. Secure Boot: 부팅 프로세스 무결성 검증
  2. Measured Boot: 부팅 이벤트 로깅
  3. Trusted Platform Module (TPM): 암호화 키 저장소
```

### 3.3 네트워크 보안

```
VCN Configuration:
  - 격리된 프라이빗 네트워크
  - Subnet 단위 접근 제어
  - Internet Gateway: 선택적 노출

Security List Rules:
  - 인바운드: SSH(22), HTTP(80), HTTPS(443)만 허용
  - 아웃바운드: 필요한 포트만 개방
```

---

## 성능 고려사항

### 4.1 CPU & 메모리 스펙

| 항목 | 사양 | 용도 |
|------|------|------|
| vCPU | 1 core (AMD EPYC) | 데이터 처리, 모델 추론 |
| RAM | 1 GB | OS + Python + 간단한 모델 |
| Network | 0.48 Gbps | API 호출, 시장 데이터 수신 |
| Storage | 47 GB (root) | OS, 코드, 로그, 캐시 |

### 4.2 병목 지점 및 대응

```
현재 리소스 제약:
  - 메모리: 1GB (중소 모델 실행 가능, 대규모 학습 불가)
  - CPU: 1 vCPU (단일 스레드 작업, 병렬화 어려움)
  - Storage: 47GB (데이터 저장 후 정리 필요)

대응 방안:
  - 경량 알고리즘 사용 (RL 대신 기술적 분석)
  - 데이터 스트리밍 처리 (배치 아닌 실시간)
  - 주기적 로그 로테이션
  - 필요시 스케일업 (더 큰 Shape로 변경)
```

---

## 연결 및 접근 방법

### 5.1 SSH 접근

```bash
# 권한 설정
chmod 600 private_key.pem

# SSH 접속
ssh -i private_key.pem ubuntu@<PUBLIC_IP>

# 접속 확인
$ uname -a
Linux instance-lab 6.1.0-28-generic #49-Ubuntu SMP PREEMPT_DYNAMIC x86_64 GNU/Linux
```

### 5.2 초기 환경 설정

```bash
# 패키지 업데이트
sudo apt update
sudo apt upgrade -y

# Python 및 필수 라이브러리
sudo apt install python3 python3-pip python3-venv -y
pip3 install --upgrade pip

# 시간대 설정 (중요: 거래 시간대 맞추기)
sudo timedatectl set-timezone Asia/Seoul
timedatectl status
```

---

## 비용 분석

### 6.1 Oracle Cloud Always Free Tier

```
월간 비용: 0 USD (Free Tier 범위 내)

포함 사항:
  ✓ VM.Standard.E2.1.Micro: 2개 인스턴스 (1 사용)
  ✓ 1GB RAM
  ✓ 5 Mbps 네트워크
  ✓ 총 200GB 스토리지 (공유)
  ✓ Oracle Autonomous Database: 20GB
  ✓ API 호출, 로드 밸런싱 등

추가 비용 (필요시):
  - 더 큰 Shape: $0.02/hr ~ (온디맨드)
  - 데이터 전송 (아웃바운드): $0.0085/GB (처음 1TB 이후)
  - 추가 스토리지: $0.0255/GB/월
```

### 6.2 예산 최적화

```
전략:
  1. Always Free Tier 최대 활용
  2. 자동 스케일링으로 유휴 리소스 제거
  3. 네트워크 사용량 모니터링
  4. 월간 비용 알림 설정 (Budget Alert)
```

---

## 다음 단계

### 7.1 소프트웨어 스택 구축

```
Trading System Stack:

1. Data Layer
   - 시장 데이터 수집 (API: yfinance, Alpha Vantage)
   - 데이터 저장 (SQLite or PostgreSQL)
   - 기술 지표 계산 (Ta-lib, pandas)

2. Strategy Layer
   - ATRFilter (변동성 필터링)
   - MarketRegimeFilter (시장 국면 감지)
   - 포지션 사이징 로직

3. Execution Layer
   - 브로커 API 통합 (한국 증권사)
   - 주문 실행 및 이행 확인
   - 리스크 관리 (StopLoss, TakeProfit)

4. Monitoring Layer
   - 시스템 헬스 체크
   - 성능 메트릭 (Sharpe Ratio, Drawdown)
   - 알림 (Discord, Email)
```

### 7.2 배포 및 자동화

```
DevOps Pipeline:

Source Code (GitHub)
    ↓ (Push)
GitHub Actions (CI)
    ↓ (Build + Test)
Oracle Cloud Instance (CD)
    ↓ (Deploy)
Systemd Service (Auto-restart)
    ↓ (Monitor)
Cloud Logging + Monitoring
```

### 7.3 성능 최적화

```
모니터링 항목:
  - CPU 사용률 (목표: 70% 이하)
  - 메모리 사용률 (목표: 80% 이하)
  - 네트워크 지연 (목표: <100ms)
  - 거래 실행 지연 (목표: <500ms)
  - 오류율 (목표: <1%)
```

---

## 배운 점 및 결론

### 8.1 주요 교훈

1. **아키텍처 선택이 중요**
   - ARM vs AMD 선택이 배포 성공을 좌우함
   - 지역별 리소스 가용성 사전 확인 필수

2. **Always Free Tier의 한계**
   - 용량 제한이 있음 (특히 인기 있는 Shape)
   - 유연한 대체 방안 준비 필요

3. **보안은 초기부터**
   - Shielded Instance, 2FA, SSH Key 등 기본 설정
   - 처음부터 구축하는 것이 나중에 추가하는 것보다 효율적

4. **모니터링과 로깅의 중요성**
   - Oracle Cloud Agent로 자동 수집
   - 실시간 알림 설정으로 문제 조기 발견

### 8.2 앞으로의 방향

이 인프라를 기반으로:

- ✅ AI 거래 신호 생성 모듈 배포
- ✅ 실시간 시장 데이터 파이프라인 구축
- ✅ 포지션 관리 및 리스크 제어 로직 통합
- ✅ 성능 메트릭 대시보드 개발
- ✅ 24/7 모니터링 및 알림 시스템 운영

---

## 참고 자료

- [Oracle Cloud Infrastructure Documentation](https://docs.oracle.com/en-us/iaas/)
- [Always Free Tier Services](https://www.oracle.com/cloud/free/)
- [OCI Compute Shapes](https://www.oracle.com/cloud/price-list/)
- [Ubuntu 22.04 LTS on OCI](https://ubuntu.com/oracle)

---

## 문의 및 피드백

이 글에서 다룬 내용에 대해 질문이나 개선 사항이 있다면 GitHub Issues나 블로그 댓글로 연락주길 바란다.

**작성자**: Evan  
**최종 수정**: 2026년 5월 28일  
**분야**: Cloud Infrastructure, DevOps  
**난이도**: Intermediate  
**상태**: Production Ready
