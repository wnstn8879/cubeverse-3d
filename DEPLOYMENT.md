# 빌드와 배포

Godot **4.6.3 stable**, GDScript, Compatibility 렌더러를 사용한다. Web 내보내기는 스레드를 끄므로 GitHub Pages에서 COOP/COEP 헤더 없이 실행할 수 있다. Android는 `com.cubeverse.game`, API 24 이상 (Android 7), arm64-v8a 및 x86_64 테스트 APK다.

## 현재 빌드 상태

- 2026-11-15(KST) 로컬 `tools/build.sh all` 통과. 버전 **0.2.0-alpha**, Android 버전 코드 **2**.
- 엔진 1,019개, 카메라 96개, 앱 통합 345개, 실제 합성 터치 GUI 92개, 오디오 851개, NxN 미니맵·모양 521개, 피라밍크스 미니맵 148개, 입문 학습 409개, 피라밍크스 엔진·뷰·학습 2,490개 검사 통과. 저장 복원·회귀 검사도 통과했다.
- Web/APK 내보내기와 APK ZIP·v2/v3 서명·패키지·ABI 검증 통과. APK 안에 오디오 샘플 240개와 폰트 라이선스 동봉을 확인했다. 실제 내보낸 Web PCK도 네이티브 헤드리스 엔진에서 실행 오류 없이 열었다.
- 로컬 빌드 경로: `build/web/index.html`, `build/android/CubeVerse-3D-debug.apk`. 최종 해시·리소스 지문은 `build/reports/final-manifest.json`을 따른다.
- GitHub 저장소 `wnstn8879/cubeverse-3d`는 생성·연결되었고 기존 검증 버전의 원격 저장을 확인했다. 0.2.0의 원격 Actions·Pages·Release 상태는 실제 실행이 끝난 결과만 기준으로 기록한다.
- Android 실기기 설치·프레임 성능·오디오 청감·햅틱은 미검증이다. 빌드 성공이나 합성 터치 검사는 실제 기기 검증을 대신하지 않는다.

### 0.2.0 로컬 산출물

| 파일 | 바이트 | SHA-256 |
| --- | ---: | --- |
| Web WASM | 37,700,666 | `26b61ce95247012ab3dca3ff51e96d1cdbff44ee91a8c20a83e150afca83f1b6` |
| Web PCK | 3,122,540 | `09d7e3a472652ade5b61f4f8d509f6cc126957e3129ec378e8083ab4edd008b0` |
| Android APK | 59,200,397 | `2afefe0fdec5569d8e63bfe1fc874521eebcb51eae862a030295a0ed80265138` |


## 로컬 재현

필수: Godot 4.6.3, Python 3, JDK 17, Android SDK command-line tools, `platform-tools`, `platforms;android-36`, `build-tools;36.0.0`, `rg`.

```bash
export JAVA_HOME=/path/to/jdk17
export ANDROID_HOME=/path/to/android-sdk
export XDG_DATA_HOME="$PWD/.tools/data"
python3 tools/install_templates.py
# 자동 import, 전체 엔진·GUI·오디오·미니맵·학습 검사 후 두 플랫폼 내보내기
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

로컬 주소 `http://localhost:8000`을 연다. 관리형 클라우드 환경에서는 프로젝트의 미리보기 경로를 우선 사용한다. WASM은 `file://`로 열지 않는다. 원격 배포는 HTTPS를 사용해야 한다. 웹 오디오는 브라우저 정책에 따라 첫 터치 이후 활성화된다. 로컬 저장은 해당 브라우저/사이트의 저장소에 보관되며 시크릿 모드 종료나 사이트 데이터 삭제 시 사라질 수 있다. 브라우저 햅틱 지원 여부는 앱이 감지하며 지원하지 않는 환경에서는 비활성화한다.

`status.html`은 이 빌드의 자동 테스트/Web/APK 성공 항목, 실제 커밋 SHA, 생성 시각과 Actions 실행 링크를 표시한다. 전체 제품 완성도를 임의 백분율로 계산하지 않는다.

## GitHub Actions

`.github/workflows/build.yml`의 작업 순서:

1. `main`, `develop`, `feature/**`, PR, `v*` 태그 또는 수동 실행에서 Godot/SDK 설치.
2. headless import, 전체 엔진·저장 복원·앱·합성 터치·오디오·미니맵·입문 학습·피라밍크스 검사.
3. Web 릴리스 내보내기 및 Android 디버그 내보내기 후 APK 서명/ZIP/패키지/아키텍처 검증.
4. 검사 로그, Web ZIP, APK를 30일 보관하는 Actions 아티팩트로 업로드.
5. `main` 성공 빌드를 GitHub Pages에 배포. PR에는 배포 권한을 제공하지 않음.
6. `v*` 태그가 성공한 경우 테스트 APK를 GitHub prerelease에 첨부.

Pages 작업은 `actions/configure-pages@v5`의 `enablement: true`로 최초 활성화를 시도합니다. 저장소 정책으로 거절되면 관리자가 **Settings → Pages → Source → GitHub Actions**를 선택해야 합니다. `github-pages` 환경의 승인 규칙이나 조직 정책이 있으면 그 규칙을 따른다. 현재 연결에 관리 권한이 제공되면 이 설정은 에이전트가 적용할 수 있다.

Actions 성공 여부는 실제 실행 화면에서 확인해야 한다. 워크플로 파일 작성만으로 성공 배지를 표시하지 않는다. 테스트가 실패한 커밋은 `main`에 병합하지 않는다. 배포 실패 시 `pages` 작업 로그와 빌드의 `build-reports-<SHA>` 아티팩트를 확인한다.

## 테스트 APK 설치

Actions 실행의 `CubeVerse-3D-debug-<SHA>` 아티팩트 또는 검증된 태그의 Release에서 APK를 내려받는다. Android에서 다운로드한 APK를 열고 해당 설치 출처의 설치 허용을 선택한다. USB 디버깅을 사용하는 테스트 기기는 다음과 같이 설치한다.

```bash
adb install -r build/android/CubeVerse-3D-debug.apk
```

디버그 키는 정식 출시 키가 아니다. 새 CI 실행에서 키가 바뀌면 기존 앱과 서명이 달라 업데이트 설치가 거부될 수 있다. 같은 키를 안전한 CI secret으로 관리하기 전에는 이전 테스트 앱을 제거한 뒤 재설치해야 하며 로컬 저장 데이터도 삭제된다. 이 개발용 키를 Google Play 출시 키로 재사용하지 않는다.

## 정식 출시 전에 남은 일

실기기 QA, 개인정보 처리방침, Play Console 등록, 정식 AAB/서명키 관리와 Play Billing 검증은 아직 완료되지 않았다. 결제나 계정 동기화가 연결된 것처럼 표시하지 않는다. 정식 키는 승인 후 보안 저장소와 CI Secrets에 보관하고 저장소에 커밋하지 않는다. 현재는 유료 서비스나 실결제를 사용하지 않는다.

## 현재 비공개 미리보기 (Sites 대체 호스팅)

- 웹: https://cubeverse-3d-play.angksehdfur2468.chatgpt.site
- 테스트 APK: https://cubeverse-3d-play.angksehdfur2468.chatgpt.site/downloads.html
- 실제 빌드 현황: https://cubeverse-3d-play.angksehdfur2468.chatgpt.site/status.html

이 주소에 0.2.0 Sites 게시 결과 `succeeded`를 확인했습니다. 게시 ID는 `appgdep_6af92e958b6c819188a60f133a29c482`이며, 코드 기준 커밋은 `9716165c7910906d96362df352a6ffeeb5108385`입니다. 본인 계정만 접근하며 공개 범위는 변경하지 않았습니다. 브라우저 조작·실기기 설치는 미검증입니다. 초기 GitHub 저장소 생성 제한 때문에 이 미리보기를 먼저 게시했습니다. 현재 GitHub 소스 저장과 이 Sites 미리보기의 게시 상태는 별도로 확인합니다.

원본 Web WASM(약36MiB)과 APK(약55MiB)를 18MiB 조각으로 전송하고 브라우저에서 원본 바이트로 재구성합니다. `tools/prepare_site.py`와 `tools/test_site.mjs`는 재구성 SHA-256·WASM 컴파일·fetch 통과를 검증합니다. APK 다운로드 페이지는 저장 전 SHA-256을 검사합니다.

배포 전용 소스는 `/workspace/sites/cubeverse-play`입니다. 기본 제공 Sites 소스 헬퍼가 이 환경에 없어 `tools/publish_site_source.py`를 사용했습니다. 대상 URL·프로젝트 ID를 고정 검증하며 자격증명은 숨겨진 stdin으로만 받아 프로세스 메모리에서 사용합니다. 원격은 1회 푸시64MiB 제한이 있어 Web/APK를 별도 커밋으로 나눕니다. 다음 세션에는 Sites 스킬을 읽고 기존 project_id를 재사용하세요.

기능 브랜치 원격 검증: [Actions 43674662634](https://github.com/wnstn8879/cubeverse-3d/actions/runs/43674662634)에서 0.2.0 전체 테스트·Web/APK·아티팩트 업로드가 성공했습니다. 최초 SDK 오류는 폐기된 `tools` 패키지 설치를 제거해 해결했습니다.

## GitHub 0.2.0 릴리스 확정

- 소스 main/develop 및 태그 `v0.2.0-alpha`: 기능 기준 코드 `9716165`, 릴리스 태그 커밋 `137ba9f`.
- [태그 자동 빌드·릴리스 성공](https://github.com/wnstn8879/cubeverse-3d/actions/runs/43675188530).
- [공개 릴리스](https://github.com/wnstn8879/cubeverse-3d/releases/tag/v0.2.0-alpha).
- [공개 APK](https://github.com/wnstn8879/cubeverse-3d/releases/download/v0.2.0-alpha/CubeVerse-3D-debug.apk): 59,200,397바이트, SHA-256 `26900d3437e158c832986631ef11c1d4beabaa471c5fb05a05f54547dd263ff7`.

이 CI APK와 Sites의 로컬 빌드 APK는 독립된 디버그 빌드이므로 해시와 서명키가 다를 수 있습니다. 같은 배포 경로를 유지하는 편이 테스트 업데이트에 유리합니다. 정식 출시 서명은 아직 연결하지 않았습니다.

[main 실행 43675188364](https://github.com/wnstn8879/cubeverse-3d/actions/runs/43675188364)의 전체 테스트·Web/APK 빌드는 성공했습니다. Pages의 최초 생성만 `Resource not accessible by integration`으로 실패했습니다. 사용자가 [Pages 설정](https://github.com/wnstn8879/cubeverse-3d/settings/pages)에서 Source를 GitHub Actions로 활성화하면 이 실행의 실패한 Pages 작업만 다시 실행할 수 있습니다. 공개 Pages 주소는 아직 성공으로 표시하지 않습니다.
