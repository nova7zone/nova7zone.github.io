---
layout: post
title: Oracle Cloud 서버 초기 설정 — 고정 IP, 가상메모리, SFTP 접속
date: 2026-05-29 09:43:00 +0900
categories: infrastructure
tags: oracle-cloud ubuntu server sftp swap putty
author: Evan
description: Oracle Cloud 인스턴스 생성 후 필수 초기 설정 — 고정 IP 할당, PuTTY SSH 접속, 가상메모리 4GB 추가, FileZilla SFTP 연결까지 순서대로 기록한다.
---

**작성일**: 2026년 5월 29일  
**최종 수정**: 2026년 5월 29일  
**분야**: Infrastructure  
**난이도**: Beginner ~ Intermediate  
**상태**: Production Ready

---

## 들어가며

이전 글에서 Oracle Cloud AMD 인스턴스 생성을 완료했다. 이번 글은 그 다음 단계 — 서버를 실제로 쓸 수 있도록 초기 설정하는 과정이다.

무료 티어를 그냥 두면 두 가지 문제가 생긴다:

1. **공개 IP가 임의로 바뀔 수 있다** — 재부팅 시 접속 주소 변경
2. **RAM 1GB가 너무 작다** — 자동매매 봇 실행 중 메모리 부족으로 프로세스 강제 종료

이 글에서 두 문제를 순서대로 해결한다.

---

## 1. 고정 IP 설정 (Reserved Public IP)

> 참고: [오라클 클라우드 고정IP 설정하기](https://technfin.tistory.com/entry/%EC%98%A4%EB%9D%BC%ED%81%B4-%ED%81%B4%EB%9D%BC%EC%9A%B0%EB%93%9C-%EA%B3%A0%EC%A0%95IP-%EC%84%A4%EC%A0%95%ED%95%98%EA%B8%B0)

서버에 고정 IP를 설정하는 것은 영구적인 집 주소를 만드는 것과 같다. 설정 후에는 서버 IP가 변경되지 않으며, 나중에 도메인을 연결할 때도 이 IP를 사용한다.

### 접근 경로

1. Oracle Cloud 콘솔 → **Compute > Instances** → 인스턴스 클릭
2. 왼쪽 메뉴에서 **Attached VNICs** 클릭
3. VNIC 이름 클릭 → **IP administration 탭** → **IPv4 Addresses** 클릭

### 기존 IP 제거

먼저 임시(Ephemeral) IP를 삭제해야 Reserved IP를 새로 할당할 수 있다.

1. 우측 점 세 개 버튼(···) → **Edit**
2. **NO PUBLIC IP** 선택
3. **Update** 클릭

Public IP가 사라지면 정상이다.

### Reserved IP 새로 생성

1. 다시 점 세 개 버튼(···) → **Edit**
2. **RESERVED PUBLIC IP** 선택
3. **CREATE NEW RESERVED IP ADDRESS** 선택
4. IP 이름 자유 입력 (예: `nova-lab-ip`)
5. **Oracle** 선택
6. **Assign** 클릭

### 결과 확인

![Reserved IP 설정 완료](/assets/img/oracle-cloud-server-setup/image1.png)

IP Lifetime 컬럼에 **Reserved** 표시가 되면 완료다. 이 IP는 이제 인스턴스를 종료하거나 재부팅해도 변경되지 않는다.

---

## 2. PuTTY로 첫 SSH 접속

> 참고: [PuTTYgen으로 키 변환 방법](https://blog.naver.com/danla_0/224217566735)

Oracle Cloud에서 받은 `.key` 파일은 PuTTY가 직접 읽지 못한다. **PuTTYgen**으로 `.ppk` 파일로 변환해야 한다.

### 키 파일 변환

1. **PuTTYgen** 실행
2. **Load** 클릭 → `.key` 파일 선택
3. 보안을 위해 비밀번호(passphrase) 설정
4. **Save private key** → `.ppk` 파일로 저장

### SSH 접속

```
호스트: 168.110.107.113 (Reserved IP)
포트: 22
인증: 위에서 생성한 .ppk 파일
초기 사용자: ubuntu
```

### Root 비밀번호 설정

```bash
# ubuntu 계정으로 접속 후
sudo passwd root
# 새 비밀번호 입력

# root 전환
su root
```

---

## 3. 가상 메모리(Swap) 4GB 추가

Oracle Cloud 무료 티어 AMD 인스턴스(RAM 1GB)를 그대로 쓰면 자동매매 봇이 메모리 부족으로 종료된다. Swap 메모리를 추가해 이를 방지한다.

### 현재 상태 확인

```bash
free -h
```

Swap이 0B로 나오면 아래 단계를 진행한다.

### Swap 4GB 생성

**1단계: 파일 생성**

```bash
sudo fallocate -l 4G /swapfile
# fallocate가 실패하면:
sudo dd if=/dev/zero of=/swapfile bs=1M count=4096
```

**2단계: 권한 설정**

```bash
sudo chmod 600 /swapfile
```

루트 계정만 접근하도록 설정. 안 하면 보안 경고가 뜬다.

**3단계: Swap 활성화**

```bash
sudo mkswap /swapfile
sudo swapon /swapfile
```

**4단계: 재부팅 후에도 유지되도록 등록**

```bash
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 최종 확인

```bash
free -h
```

```
               total        used        free      shared  buff/cache   available
Mem:           956Mi       217Mi        95Mi       1.0Mi       643Mi       590Mi
Swap:          4.0Gi          0B       4.0Gi
```

Swap 항목에 **4.0Gi**가 표시되면 성공이다.

---

## 4. FileZilla로 SFTP 접속

서버에 파일을 올리고 관리할 때 **FileZilla** 무설치 버전을 사용한다.

### 사이트 관리자 설정

FileZilla 실행 → **파일 > 사이트 관리자** → 새사이트 추가

| 항목 | 값 |
|------|-----|
| 사이트 이름 | nova_lab |
| 프로토콜 | SFTP |
| 호스트 | 168.110.107.113 |
| 포트 | 22 |
| 로그온 유형 | 키 파일 |
| 사용자 | ubuntu |
| 키 파일 | PUTTYgen에서 생성한 `.key` 파일 |
| 비밀번호 저장 | 활성화 (다음 접속부터 자동 인증) |

### 파일 업로드 시 소유권

FileZilla로 업로드한 파일의 소유자는 자동으로 **ubuntu**로 설정된다.

```bash
# 서버에서 확인
ls -la /path/to/uploaded/file
# -rw-r--r-- 1 ubuntu ubuntu ...
```

---

## 설정 완료 요약

| 항목 | 완료 |
|------|------|
| 고정 IP (Reserved) | ✅ 168.110.107.113 |
| SSH 접속 (PuTTY) | ✅ ubuntu / root |
| 가상 메모리 | ✅ Swap 4GB |
| SFTP 연결 | ✅ FileZilla |

다음 글에서는 이 서버 위에 자동매매 프로그램을 설치하는 과정을 다룬다.
