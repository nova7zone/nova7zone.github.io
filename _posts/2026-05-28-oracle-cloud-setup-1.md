---
layout: post
title: Oracle Cloud 서버 구축기 — ARM 실패, AMD로 성공
date: 2026-05-28 15:01:00 +0900
categories: infrastructure devops
tags: oracle-cloud ai-trading cloud-setup free-tier
author: Evan
description: Oracle Cloud Free Tier로 AI 자동매매 서버를 구축하면서 ARM 용량 부족 에러를 만나고 AMD로 전환해 최종 성공한 과정을 스크린샷과 함께 기록한다.
---

**작성일**: 2026년 5월 28일  
**최종 수정**: 2026년 5월 28일  
**분야**: Cloud Infrastructure, DevOps  
**난이도**: Beginner ~ Intermediate  
**상태**: Production Ready

---

## 들어가며

AI 자동매매 시스템을 24/7 돌리려면 서버가 필요하다. 집 PC를 켜두는 건 현실적이지 않고, 유료 클라우드는 비용 부담이 있다. Oracle Cloud의 Always Free Tier는 말 그대로 평생 무료로 쓸 수 있는 서버를 제공하기 때문에 첫 번째 선택지로 골랐다.

결론부터 말하면 **첫 시도는 실패**했다. ARM 기반 인스턴스를 만들려다 "Out of host capacity" 에러를 만났고, AMD로 바꿔서 재시도해 성공했다. 이 글은 그 과정을 스크린샷과 함께 기록한 것이다.

---

## 1차 시도: ARM (AMPERE) 기반 구축 — 실패

### 인스턴스 기본 정보 입력

Oracle Cloud 콘솔에서 **Compute > Instances > Create Instance** 로 진입한다.

![인스턴스 기본 정보 설정](/assets/img/oracle-cloud-setup-1/image1.png)

- **Name**: `instance-auto`
- **Compartment**: `nova_lab (root)`
- **Availability Domain**: AD 1 (FGOE:AP-CHUNCHEON-1-AD-1) — 춘천 리전

### OS 이미지 선택

![OS 이미지 선택 — Ubuntu 22.04](/assets/img/oracle-cloud-setup-1/image2.png)

- **Operating system**: Canonical Ubuntu 22.04
- **Image build**: 2026.04.30-1
- **Security**: Shielded instance

### Shape 선택 — AMPERE ARM

![Shape 선택 — VM.Standard.A1.Flex](/assets/img/oracle-cloud-setup-1/image3.png)

Free Tier에서 가장 스펙이 좋은 ARM 기반 사양을 선택했다.

- **Shape**: `VM.Standard.A1.Flex` (Always Free-eligible)
- **Spec**: 1 core OCPU, 6 GB memory, 1 Gbps network

### 네트워크 설정

![Primary VNIC 설정](/assets/img/oracle-cloud-setup-1/image4.png)

- **VNIC name**: `lab-vnic`
- **Primary network**: Create new virtual cloud network
- **VCN name**: `vcn-20260528-1407`
- **Compartment**: `nova_lab (root)`

![Subnet 설정](/assets/img/oracle-cloud-setup-1/image5.png)

- **Subnet**: Create new public subnet
- **Subnet name**: `subnet-20260528-1407`
- **CIDR block**: `10.0.0.0/24`

![Private IPv4 주소 할당](/assets/img/oracle-cloud-setup-1/image6.png)

Private IPv4 주소는 자동 할당으로 설정했다.

### 비용 확인

![예상 비용](/assets/img/oracle-cloud-setup-1/image7.png)

Boot volume 비용으로 $2.76/month가 표시된다. Free Tier 범위에서는 이 비용도 청구되지 않는다.

### 결과: 스택 생성은 됐지만...

![Stack 생성 결과](/assets/img/oracle-cloud-setup-1/image8.png)

Terraform Stack(`instance-auto`)은 Active 상태로 만들어졌지만, 실제 인스턴스 생성 단계에서 아래 에러가 발생했다.

```
Error: 500-InternalError
Out of host capacity
```

### ❌ 에러 원인: "Out of host capacity"란?

설정이나 코드의 문제가 아니다. Oracle Cloud 춘천 리전(ap-chuncheon-1)의 **ARM 서버 자원이 현재 꽉 찬 상태**라는 뜻이다.

`VM.Standard.A1.Flex`는 Oracle Free Tier에서 가장 인기 있는 사양이라 전 세계 사용자가 몰려 자원 부족이 매우 자주 발생한다. 한번 뜨면 수일~수주 기다려야 할 수도 있다.

**해결 방법 두 가지:**
1. 계속 재시도하면서 빈 자리가 생기기를 기다린다 (운에 맡기는 방식)
2. **CPU 아키텍처를 AMD로 바꿔서 재시도한다** ← 이 방법을 선택

---

## 2차 시도: AMD로 전환 — 성공

### 인스턴스 기본 정보 입력

![인스턴스 기본 정보 — instance-lab](/assets/img/oracle-cloud-setup-1/image9.png)

- **Name**: `instance-lab` (이름 변경)
- **Compartment**: `nova_lab (root)`
- **Availability Domain**: AD 1 (FGOE:AP-CHUNCHEON-1-AD-1)

### OS 이미지 선택

![OS 이미지 선택 — Ubuntu 22.04](/assets/img/oracle-cloud-setup-1/image10.png)

OS는 동일하게 Ubuntu 22.04를 선택했다.

### Shape 변경 — AMD EPYC

![Shape 변경 — VM.Standard.E2.1.Micro](/assets/img/oracle-cloud-setup-1/image11.png)

핵심 변경 사항이다. ARM → AMD로 바꿨다.

- **Shape**: `VM.Standard.E2.1.Micro` (Always Free-eligible)
- **Spec**: 1 core OCPU, 1 GB memory, 0.48 Gbps network

ARM(6GB) 대비 메모리가 1GB로 줄어드는 단점이 있지만, 자원을 바로 확보할 수 있다는 게 훨씬 중요했다.

### 고급 설정

![Management — IMDSv2 설정](/assets/img/oracle-cloud-setup-1/image12.png)

Instance Metadata Service(IMDS)는 기본값으로 유지했다. IMDSv2를 강제하면 보안이 강화되지만, 일부 앱에서 호환성 문제가 생길 수 있어 일단 기본으로 두었다.

![Availability configuration](/assets/img/oracle-cloud-setup-1/image13.png)

Live migration 옵션은 "Let Oracle Cloud Infrastructure choose the best migration option"으로 설정했다. 인프라 유지보수 시 자동으로 다른 호스트로 이전된다.

![Oracle Cloud Agent](/assets/img/oracle-cloud-setup-1/image14.png)

Oracle Cloud Agent는 아래 플러그인을 활성화했다.
- Custom Logs Monitoring
- Compute Instance Monitoring
- Cloud Guard Workload Protection

### 보안 설정

![Security — Shielded Instance](/assets/img/oracle-cloud-setup-1/image15.png)

Shielded Instance는 비활성화 상태다. AMD E2.1.Micro Shape에서는 이 옵션이 지원되지 않는다.

### 네트워크 설정

![Primary VNIC — nova_vnic](/assets/img/oracle-cloud-setup-1/image16.png)

- **VNIC name**: `nova_vnic`
- **Primary network**: Create new virtual cloud network
- **VCN name**: `vcn-20260528-1454`
- **Compartment**: `nova_lab (root)`

![Subnet 설정](/assets/img/oracle-cloud-setup-1/image17.png)

- **Subnet**: Create new public subnet
- **Subnet name**: `subnet-20260528-1454`
- **CIDR block**: `10.0.0.0/24`

![Private IPv4 주소 할당](/assets/img/oracle-cloud-setup-1/image18.png)

Private IPv4 주소는 자동 할당으로 설정했다.

### ✅ 최종 결과: Running

![인스턴스 목록 — instance-lab Running](/assets/img/oracle-cloud-setup-1/image19.png)

**2026년 5월 28일 15:01**, 인스턴스 생성 성공.

| 항목 | 값 |
|------|-----|
| Name | instance-lab |
| State | **Running** |
| Public IP | 134.185.109.162 |
| Private IP | 10.0.0.130 |
| Shape | VM.Standard.E2.1.Micro |
| OCPU | 1 |
| Memory | 1 GB |
| Availability Domain | AD-1 |

---

## SSH 접속 확인

```bash
chmod 600 private_key.pem
ssh -i private_key.pem ubuntu@134.185.109.162

# 접속 후 확인
$ uname -a
Linux instance-lab 6.1.0-28-generic #49-Ubuntu SMP PREEMPT_DYNAMIC x86_64 GNU/Linux
```

---

## 정리

| 항목 | 1차 시도 (실패) | 2차 시도 (성공) |
|------|----------------|----------------|
| Shape | VM.Standard.A1.Flex | VM.Standard.E2.1.Micro |
| CPU | ARM AMPERE | AMD EPYC |
| Memory | 6 GB | 1 GB |
| 결과 | Out of host capacity | **Running** |

Free Tier에서 ARM 자원이 부족하다면 AMD로 전환하는 게 현실적인 해결책이다. 메모리가 6GB → 1GB로 줄어들지만, AI 매매 시스템의 신호 생성과 주문 실행 정도는 1GB로도 충분히 돌아간다.

다음 글에서는 이 서버 위에 실제 자동매매 환경을 구축하는 과정을 다룬다.

---

## 참고

- [Oracle Cloud Infrastructure Documentation](https://docs.oracle.com/en-us/iaas/)
- [Always Free Tier Services](https://www.oracle.com/cloud/free/)
