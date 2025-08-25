# Ubuntu Offline Packages

Ubuntu 여러 버전에 대한 오프라인 패키지를 빌드하고 관리하는 도구입니다.

## 디렉토리 구조

```
.
├── Dockerfile                 # 메인 빌드 파일
├── Makefile                   # 빌드 자동화
├── README.md                  # 문서
├── packages/                  # Ubuntu 버전별 패키지 목록
│   ├── packages-20.04.txt
│   ├── packages-22.04.txt
│   └── packages-24.04.txt
├── scripts/                   # 유틸리티 스크립트
│   ├── install-packages.sh
│   ├── conditional-install.sh
│   ├── fetch_archives.sh
│   └── create-apt-get-install-with-version.sh
├── control-files/             # Debian 패키지 컨트롤 파일
│   ├── control
│   ├── control-buildkit
│   └── control-nerdctl
└── archives/                  # 생성된 패키지 아카이브 (git에서 무시됨)
    ├── 20.04/
    ├── 22.04/
    └── 24.04/
```

## 사용법

### 개별 버전 빌드

```bash
# Ubuntu 20.04 빌드
make build-20.04

# Ubuntu 22.04 빌드  
make build-22.04

# Ubuntu 24.04 빌드
make build-24.04
```

### 빌드 + 아카이브 추출

```bash
# 빌드하고 패키지 아카이브 추출
make fetch-20.04
make fetch-22.04
make fetch-24.04
```

### 정리

```bash
# Docker 이미지 정리
make clean

# 아카이브 디렉토리 정리
make clean-archives

# 도움말 보기
make help
```

## 패키지 목록 관리

각 Ubuntu 버전별로 다른 패키지 목록을 관리할 수 있습니다:

- `packages/packages-20.04.txt` - Ubuntu 20.04용 패키지 목록
- `packages/packages-22.04.txt` - Ubuntu 22.04용 패키지 목록  
- `packages/packages-24.04.txt` - Ubuntu 24.04용 패키지 목록

패키지 목록을 수정하려면 해당 파일을 편집하고 다시 빌드하세요.

## 특징

- **k9s 최신 버전 자동 다운로드**: GitHub API를 통해 빌드 시점의 최신 버전 자동 설치
- **Ubuntu 버전별 패키지 관리**: 각 Ubuntu 버전에 맞는 패키지 목록 지원
- **구조화된 파일 관리**: 스크립트, 패키지 목록, 컨트롤 파일을 각각 디렉토리로 분리

## 결과물

빌드 완료 후 `archives/` 디렉토리에 각 Ubuntu 버전별로:

- `*.deb` 파일들 (패키지 파일들)
- `Packages.gz` (패키지 인덱스)
- `apt-get-install-with-version.sh` (설치 스크립트)

이 파일들을 오프라인 환경으로 복사하여 사용할 수 있습니다.