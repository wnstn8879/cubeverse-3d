# CubeVerse 3D

손으로 층을 돌리고 소리와 함께 즐기는 모바일 3D 큐브 게임입니다. Android와 웹을 함께 대상으로 하는 **0.1.0 개발 알파**이며, Godot 4.6.3 / GDScript / Compatibility 렌더러를 사용합니다.

## 실행·배포 상태

| 항목 | 확인된 상태 |
| --- | --- |
| 웹 플레이 고정 주소 | 아직 미배포 · 원격 저장소 연결 대기 |
| 최신 APK 다운로드 | 로컬 디버그 APK 빌드·서명 검증 통과 · Releases 게시 전 |
| GitHub Actions | 워크플로 구성됨 · 원격 실행 전 |
| 자동 테스트 | 엔진 1,019개·카메라 조작 96개·앱 통합 93개 검증과 회귀·프로세스 복원 통과 |
| Android 실기기 | 설치·터치·햅틱·성능 미검증 |

GitHub 계정 조회와 CLI 인증은 확인했습니다. 저장소 생성 요청이 연결된 GitHub 통합의 권한 부족(`Resource not accessible by integration`)으로 거절되어 `cubeverse-3d` 저장소 생성과 원격 게시가 대기 중입니다. [배포 안내](DEPLOYMENT.md)에 연결 후 빌드·배포 절차와 현재 결과를 기록합니다.

## 실제 구현 범위

- 공통 정수 상태 엔진으로 2×2~10×10 층 회전, 셔플, 완성 판정, 실행 취소·다시 실행.
- 조각 드래그로 층 미리보기와 정렬, 배경 드래그로 시점 변경, 두 손가락 확대·축소. 합성 입력으로 취소·멀티터치 전환을 검증했습니다.
- 큐브별 상태·설정·학습 진도·로컬 기록 저장, 이전 정상 저장의 백업 복구.
- 한국어 다크 UI, 큐브 선택, 자유 플레이, 오프라인 타이머.
- 2×2·3×3 고정 예제의 역회전 연습. 임의 상태 전체 풀이 기능은 없습니다.
- 무료 사운드 6종의 선택·미리 듣기·회전 이벤트 연결. 직접 합성한 임시 음원이며 최종 청감 품질과 실기기 오디오 성능은 검증 전입니다.
- Android 진동과 웹 진동 API 지원 감지 코드. 기기별 강도·패턴은 실기기 검증 전입니다.

화면 이동·타이머·고정 예제 학습·저장 복원은 실제 앱 장면을 구동하는 헤드리스 통합 검사를 통과했습니다. Linux 네이티브 렌더링에서 한국어 홈·10×10·설정 화면을 확인했습니다. 실제 브라우저 실행과 Android 기기의 확인 범위는 [TEST_REPORT.md](TEST_REPORT.md)를 기준으로 판단하세요.

## 미완성 기능

특수 퍼즐, 상태별 전체 풀이와 화살표 가이드, 기록 리플레이 화면·통계, 영어 UI, 계정·클라우드 동기화, 친구·온라인 매칭·서버 검증·랭킹, 프리미엄 상품·스킨·Google Play 결제·구매 복원, 정식 서명·Play 등록은 구현되지 않았습니다. 상점에는 무료 미리 듣기와 개발 예정 안내를 제공합니다.

로컬 APK는 [`build/android/CubeVerse-3D-debug.apk`](build/android/CubeVerse-3D-debug.apk)입니다. Android 7.0(API 24) 이상, arm64-v8a 또는 x86_64 대상이며 디버그 서명 빌드입니다. GitHub 공개 다운로드 주소는 아직 없습니다.

## 개발 실행

Godot 4.6.3에서 `project.godot`을 열고 실행합니다.

```sh
godot --path .
godot --headless --editor --import
python3 tests/run_tests.py
python3 tools/test_app.py
```

공식 내보내기 템플릿, Java·Android SDK 설치 후 웹·디버그 APK를 함께 만듭니다. 상세 요구 버전은 [DEPLOYMENT.md](DEPLOYMENT.md)를 따릅니다.

```sh
python3 tools/install_templates.py
tools/build.sh all
python3 tools/write_build_status.py
```

로컬 웹 확인은 `build/web`을 HTTP 서버로 제공합니다. 웹 내보내기는 HTTPS 또는 localhost에서 확인하세요.

```sh
python3 -m http.server 8000 --directory build/web
```

## 프로젝트 구성

| 경로 | 역할 |
| --- | --- |
| `scripts/core/` | 렌더링과 독립된 퍼즐 상태, 저장 |
| `scripts/view/` | 3D 메시·카메라·제스처·애니메이션 |
| `scripts/audio/` | 사전 로드된 효과음과 햅틱 |
| `scripts/ui/` | 화면·학습·오프라인 기록 연결 |
| `tests/` | 엔진·제스처·프로세스 재시작 검증 |
| `tools/`, `.github/workflows/` | 재현 가능한 빌드·상태 페이지·배포 |

현재 개발 단계와 다음 작업은 [PROGRESS.md](PROGRESS.md), 전체 계획은 [ROADMAP.md](ROADMAP.md), 변경 내용은 [CHANGELOG.md](CHANGELOG.md)를 참조하세요. 오디오 제작·사용 조건은 [AUDIO_LICENSE.md](AUDIO_LICENSE.md), 폰트 조건은 `assets/fonts/LICENSE.txt`에 있습니다.
