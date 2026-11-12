# 빌드와 배포

Godot **4.6.3 stable**, GDScript, Compatibility 렌더러를 사용한다. Web 내보내기는 스레드를 끄므로 GitHub Pages에서 COOP/COEP 헤더 없이 실행할 수 있다. Android는 `com.cubeverse.game`, API 24 이상 (Android 7), arm64-v8a 및 x86_64 테스트 APK다.

## 현재 배포 상태

- 2026-11-12 로컬 `tools/build.sh all` 통과: 자동 엔진 검사 1,019개, 별도 프로세스 저장/복원, 앱 통합 검사 93개, Web/APK 내보내기 및 APK 서명/내용 검증 성공.
- 로컬 빌드 경로: `build/web/index.html`, `build/android/CubeVerse-3D-debug.apk`.
- GitHub 저장소 생성/푸시 권한을 확보하기 전까지 Actions 실행·Pages 공개 배포·Release 게시는 대기 상태다.
- 아직 확인하지 않은 고정 웹 주소나 APK 다운로드 주소를 성공한 배포 링크로 표시하지 않는다.
- Android 실기기 설치·프레임 성능·햅틱은 별도 검증이 필요하다. 빌드 성공은 실기기 검증 완료를 뜻하지 않는다.

## 로컬 재현

필수: Godot 4.6.3, Python 3, JDK 17, Android SDK command-line tools, `platform-tools`, `platforms;android-36`, `build-tools;36.0.0`, `rg`.

```bash
export JAVA_HOME=/path/to/jdk17
export ANDROID_HOME=/path/to/android-sdk
export XDG_DATA_HOME="$PWD/.tools/data"
python3 tools/install_templates.py
# 자동 import, 큐브/프로세스 재시작 테스트 후 두 플랫폼 내보내기
./tools/build.sh all
python3 tools/write_build_status.py
```

이 세션에 설치한 SDK와 JDK는 각각 `.tools/android-sdk`, `.tools/jdk17`이다. `tools/configure_android.py`는 환경 변수 또는 이 경로를 사용하고 `.tools/config/godot/editor_settings-4.6.tres`에 컴퓨터별 설정을 만든다. 개발용 서명키는 `.tools/keys/debug.keystore`에만 생성한다. 이 경로와 인증 파일은 Git에서 제외한다.

웹만 빌드하려면 `tools/build.sh web`, APK만 빌드하려면 `tools/build.sh android`를 실행한다. 어떤 대상이든 엔진 자동 테스트가 먼저 통과해야 한다. Godot가 스크립트 오류를 출력하고 종료코드 0을 반환하는 경우까지 Python 테스트 실행기가 차단한다.

템플릿 설치기는 공식 Godot 릴리스 ZIP에서 HTTP Range로 필요한 Web/Android 항목만 내려받고 ZIP CRC를 검증한다. 외부 재배포 템플릿을 사용하지 않는다.

## 웹 미리보기

```bash
python3 -m http.server 8000 --directory build/web
```

로컬 주소 `http://localhost:8000`을 연다. WASM은 `file://`로 열지 않는다. 원격 배포는 HTTPS를 사용해야 한다. 웹 오디오는 브라우저 정책에 따라 첫 터치 이후 활성화된다. 로컬 저장은 해당 브라우저/사이트의 저장소에 보관되며 시크릿 모드 종료나 사이트 데이터 삭제 시 사라질 수 있다. 브라우저 햅틱 지원 여부는 앱이 감지하며 지원하지 않는 환경에서는 비활성화한다.

`status.html`은 이 빌드의 자동 테스트/Web/APK 성공 항목, 실제 커밋 SHA, 생성 시각과 Actions 실행 링크를 표시한다. 전체 제품 완성도를 임의 백분율로 계산하지 않는다.

## GitHub Actions

`.github/workflows/build.yml`의 작업 순서:

1. `main`, `develop`, `feature/**`, PR, `v*` 태그 또는 수동 실행에서 Godot/SDK 설치.
2. headless import, 전체 엔진 테스트, 별도 프로세스 저장/복원 및 실제 게임 씬 통합 테스트.
3. Web 릴리스 내보내기 및 Android 디버그 내보내기 후 APK 서명/ZIP/패키지/아키텍처 검증.
4. 검사 로그, Web ZIP, APK를 30일 보관하는 Actions 아티팩트로 업로드.
5. `main` 성공 빌드를 GitHub Pages에 배포. PR에는 배포 권한을 제공하지 않음.
6. `v*` 태그가 성공한 경우 테스트 APK를 GitHub prerelease에 첨부.

저장소 관리자는 최초 한 번 **Settings → Pages → Source → GitHub Actions**를 활성화해야 한다. `github-pages` 환경의 승인 규칙이나 조직 정책이 있으면 그 규칙을 따른다. 현재 연결에 관리 권한이 제공되면 이 설정은 에이전트가 적용할 수 있다.

Actions 성공 여부는 실제 실행 화면에서 확인해야 한다. 워크플로 파일 작성만으로 성공 배지를 표시하지 않는다. 테스트가 실패한 커밋은 `main`에 병합하지 않는다. 배포 실패 시 `pages` 작업 로그와 빌드의 `build-reports-<SHA>` 아티팩트를 확인한다.

## 테스트 APK 설치

Actions 실행의 `CubeVerse-3D-debug-<SHA>` 아티팩트 또는 검증된 태그의 Release에서 APK를 내려받는다. Android에서 다운로드한 APK를 열고 해당 설치 출처의 설치 허용을 선택한다. USB 디버깅을 사용하는 테스트 기기는 다음과 같이 설치한다.

```bash
adb install -r build/android/CubeVerse-3D-debug.apk
```

디버그 키는 정식 출시 키가 아니다. 새 CI 실행에서 키가 바뀌면 기존 앱과 서명이 달라 업데이트 설치가 거부될 수 있다. 같은 키를 안전한 CI secret으로 관리하기 전에는 이전 테스트 앱을 제거한 뒤 재설치해야 하며 로컬 저장 데이터도 삭제된다. 이 개발용 키를 Google Play 출시 키로 재사용하지 않는다.

## 정식 출시 전에 남은 일

실기기 QA, 개인정보 처리방침, Play Console 등록, 정식 AAB/서명키 관리와 Play Billing 검증은 아직 완료되지 않았다. 결제나 계정 동기화가 연결된 것처럼 표시하지 않는다. 정식 키는 승인 후 보안 저장소와 CI Secrets에 보관하고 저장소에 커밋하지 않는다. 현재는 유료 서비스나 실결제를 사용하지 않는다.
