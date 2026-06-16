---
layout: post
title: Oracle Cloud Free Tier — E2에서 A1.Flex까지, 11일간의 기록
date: 2026-06-16 09:00:00 +0900
categories: infrastructure
tags: oracle-cloud ubuntu server cloud-setup free-tier
author: Evan
description: Oracle Cloud Free Tier A1.Flex(ARM 4 OCPU / 24GB)를 확보하기 위해 OCI CLI를 구축하고 자동 재시도 스크립트를 11일간 돌린 끝에 3,310번째 시도 만에 성공한 과정을 기록한다.
---

**작성일**: 2026년 6월 16일  
**최종 수정**: 2026년 6월 16일  
**분야**: Cloud Infrastructure  
**난이도**: Intermediate  
**상태**: Production Ready

---

## 들어가며

결론부터 말하면, **3,310번의 실패 끝에 A1.Flex 확보에 성공했다.**

Oracle Cloud Free Tier에는 평생 무료로 쓸 수 있는 ARM 인스턴스가 있다. VM.Standard.A1.Flex — 최대 4 OCPU, 24GB RAM. 문제는 콘솔에서 직접 만들려 하면 `Out of host capacity` 오류만 돌아온다는 것이다.

자동 재시도 스크립트를 E2.1.Micro 서버에 올려두고 11일을 기다렸다. 2026년 6월 5일에 시작해서 6월 16일 오전 8시 31분에 성공 알림을 받았다.

이 글은 OCI CLI 설치부터 스크립트 작성, 그리고 확보까지의 전 과정을 기록한다.

이전 서버 구축 과정은 [Oracle Cloud 서버 구축기 — ARM 실패, AMD로 성공](/posts/oracle-cloud-setup-1)에서 확인할 수 있다.

---

## Oracle Cloud Free Tier 리소스 구성

Free Tier에서 평생 무료로 사용할 수 있는 컴퓨팅 리소스는 두 종류다.

| 인스턴스 | 스펙 | 아키텍처 | 수량 |
|---------|------|---------|------|
| VM.Standard.E2.1.Micro | 1 OCPU / 1GB RAM | AMD x86 | 최대 2개 |
| VM.Standard.A1.Flex | 최대 4 OCPU / 24GB RAM | ARM | 합산 한도 내 자유 분할 |

E2.1.Micro 하나를 자동매매 스크립트 서버로 운영하던 중 A1.Flex의 존재를 알게 됐다. ARM 기반에 24GB RAM이면 Hermes Agent와 로컬 LLM 모델까지 올릴 수 있다. 당연히 도전해야 했다.

---

## 1단계: OCI CLI 설치

A1.Flex는 콘솔 UI로는 `Out of host capacity` 오류만 반복된다. 자동 재시도 스크립트를 돌리려면 OCI CLI가 필요하다.

### ❌ 에러 원인: `ModuleNotFoundError: No module named 'apt_pkg'`

Ubuntu 시스템 Python 버전과 `apt_pkg` 컴파일 버전이 달랐다.

```bash
python3 --version
# Python 3.11

ls /usr/lib/python3/dist-packages/apt_pkg*.so
# apt_pkg.cpython-310-x86_64-linux-gnu.so
```

시스템은 3.11인데 `apt_pkg`는 3.10으로 빌드되어 있었다. 심볼릭 링크가 존재하지 않는 파일을 가리키고 있는 상태.

**해결 방법:**

```bash
cd /usr/lib/python3/dist-packages
sudo ln -sf apt_pkg.cpython-310-x86_64-linux-gnu.so apt_pkg.so
```

### ✅ 가상환경으로 OCI CLI 설치

시스템 Python을 건드리지 않는 가장 안전한 방법이다.

```bash
python3 -m venv ~/oci-env
source ~/oci-env/bin/activate
pip install oci-cli
pip install cffi        # _cffi_backend 누락 오류 해결
oci --version           # 3.85.0
```

스크립트에서 사용할 때는 항상 가상환경 활성화가 먼저다.

```bash
source ~/oci-env/bin/activate
```

---

## 2단계: OCI CLI 설정

### API Key 생성 (패스프레이즈 없이)

자동화 스크립트에서 매번 패스프레이즈를 입력할 수 없으므로, 패스프레이즈 없는 키로 생성한다.

```bash
openssl genrsa -out ~/.oci/oci_api_key.pem 2048
chmod 600 ~/.oci/oci_api_key.pem
openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem
```

### OCI 콘솔에 Public Key 등록

1. OCI 콘솔 → 우상단 프로필 → **My profile**
2. **Tokens and keys** 탭
3. **Add API Key** → **Paste a public key**
4. `cat ~/.oci/oci_api_key_public.pem` 내용 붙여넣기

### config 파일 작성

```ini
[DEFAULT]
user=ocid1.user.oc1..xxxxx
fingerprint=xx:xx:xx:xx:...
key_file=/home/ubuntu/.oci/oci_api_key.pem
tenancy=ocid1.tenancy.oc1..xxxxx
region=ap-chuncheon-1
```

### 연결 테스트

```bash
oci iam region list
# 패스프레이즈 없이 리전 목록이 출력되면 성공
```

---

## 3단계: 필요한 OCID 값 수집

스크립트 작성 전에 필요한 값들을 미리 확보한다.

```bash
# Availability Domain 확인
oci iam availability-domain list
# → FGOE:AP-CHUNCHEON-1-AD-1

# 현재 인스턴스가 연결된 Subnet OCID 확인
curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics/
oci network vnic get --vnic-id <vnic-id>
# → subnet-id 확인

# Ubuntu 24.04 ARM 최신 이미지 OCID 확인
oci compute image list \
  --compartment-id <tenancy-ocid> \
  --operating-system "Canonical Ubuntu" \
  --shape "VM.Standard.A1.Flex" \
  --sort-by TIMECREATED \
  --all \
  | grep -E '"id"|"display-name"'
# → Canonical-Ubuntu-24.04-aarch64-2026.04.30-1 선택
```

> Root Compartment만 사용 중이라면 Tenancy OCID = Compartment OCID 다.

---

## 4단계: A1.Flex 확보 전략 — 단계적 확장

처음부터 4 OCPU / 24GB를 노리면 `Out of host capacity`에 계속 막힌다. 작은 빈자리를 먼저 잡고 단계적으로 올리는 방식이 성공 확률이 높다.

```
1 OCPU / 6GB  →  2 / 12  →  3 / 18  →  4 / 24
```

이 전략은 [상구너의 개발노트](https://blog.sanguneo.com/77)에서 참고했다.

---

## 5단계: 자동 재시도 스크립트

```bash
cat > ~/a1_retry.sh << 'EOF'
#!/bin/bash

source ~/oci-env/bin/activate

COMPARTMENT_ID="ocid1.tenancy.oc1..xxxxx"
SUBNET_ID="ocid1.subnet.oc1.ap-chuncheon-1.xxxxx"
IMAGE_ID="ocid1.image.oc1.ap-chuncheon-1.xxxxx"
AVAILABILITY_DOMAIN="FGOE:AP-CHUNCHEON-1-AD-1"
SSH_KEY="$(cat ~/.ssh/authorized_keys)"
OCPUS=1
MEMORY_GB=6
DISPLAY_NAME="a1-flex-instance"
LOG_FILE="$HOME/a1_retry.log"

echo "=== A1.Flex 1/6 확보 시작: $(date) ===" >> "$LOG_FILE"

while true; do
    echo "[$(date)] 생성 시도 중... (${OCPUS} OCPU / ${MEMORY_GB}GB)" >> "$LOG_FILE"

    RESULT=$(oci compute instance launch \
        --compartment-id "$COMPARTMENT_ID" \
        --availability-domain "$AVAILABILITY_DOMAIN" \
        --shape "VM.Standard.A1.Flex" \
        --shape-config "{\"ocpus\": $OCPUS, \"memoryInGBs\": $MEMORY_GB}" \
        --subnet-id "$SUBNET_ID" \
        --image-id "$IMAGE_ID" \
        --display-name "$DISPLAY_NAME" \
        --ssh-authorized-keys-file <(echo "$SSH_KEY") \
        --assign-public-ip true \
        2>&1)

    if echo "$RESULT" | grep -q '"lifecycle-state"'; then
        echo "[$(date)] ✅ 성공!" >> "$LOG_FILE"
        echo "$RESULT" >> "$LOG_FILE"
        break
    else
        echo "[$(date)] ❌ 실패 — 180초 후 재시도" >> "$LOG_FILE"
        sleep 180
    fi
done
EOF

chmod +x ~/a1_retry.sh
```

### 백그라운드 실행

```bash
nohup ~/a1_retry.sh &
tail -f ~/a1_retry.log
```

`Ctrl+C`로 로그 모니터링만 종료해도 스크립트는 계속 실행된다.

> 재시도 간격 180초(3분) 권장. 너무 짧으면 OCI API rate limit에 걸릴 수 있다.

---

## 결과

**3,310번의 실패 끝에 성공했다.**

```
=== A1.Flex 1/6 확보 시작: Fri Jun  5 16:19:29 KST 2026 ===
[Fri Jun  5 16:19:29 KST 2026] 생성 시도 중... (1 OCPU / 6GB)
...
[Tue Jun 16 08:31:18 KST 2026] ✅ 성공! 1 OCPU / 6GB 인스턴스 생성됨
```

| 항목 | 값 |
|------|-----|
| 시작 | 2026년 6월 5일 (금) 16:19 |
| 성공 | 2026년 6월 16일 (화) 08:31 |
| 소요 기간 | **약 11일** |
| 총 시도 횟수 | **3,310회** |

춘천 리전 ARM 용량은 그만큼 경쟁이 치열하다. 포기하지 않는 것이 유일한 전략이다.

### 현재 인스턴스 구성

| 인스턴스 | 스펙 | 역할 |
|---------|------|------|
| instance-lab (E2) | 1 OCPU / 1GB | 자동매매 스크립트 |
| a1-flex-instance (A1) | 1→4 OCPU / 6→24GB | Hermes Agent / LLM |

---

## 정리

| 단계 | 내용 | 비고 |
|------|------|------|
| OCI CLI 설치 | 가상환경(venv) 사용 | 시스템 Python 충돌 회피 |
| API Key | 패스프레이즈 없이 생성 | 자동화 필수 조건 |
| 확보 전략 | 1/6 → 2/12 → 3/18 → 4/24 단계적 확장 | 한 번에 큰 스펙 시도 금지 |
| 재시도 스크립트 | 180초 간격, nohup 백그라운드 실행 | API rate limit 주의 |
| 소요 시간 | 11일, 3,310회 | 춘천 리전 ARM 경쟁률 반영 |

다음 단계로는 A1 인스턴스 SSH 접속 확인 → 스펙 단계적 업그레이드(4 OCPU / 24GB) → Hermes Agent 설치 순으로 진행할 예정이다.

---

## 참고

- [Oracle Cloud A1 Flex 4 cpu / 24GB mem 성공기 — 상구너의 개발노트](https://blog.sanguneo.com/77)
- [OCI CLI 공식 문서](https://docs.oracle.com/iaas/Content/API/SDKDocs/cliinstall.htm)
- [OCI Always Free 리소스 안내](https://docs.oracle.com/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
