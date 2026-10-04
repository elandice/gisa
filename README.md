# 차곡 · 정보처리기사 실기

제공받은 PDF 8종의 **193문제 전체**를 담은 Flutter 학습 앱입니다. 부드러운 입체감의 뉴모피즘 디자인으로 휴대폰과 데스크톱 화면을 지원합니다.

## 기능

- **학습:** 과목 선택, 문제 검색, 북마크, 답안 입력, 정답·해설 펼치기, 학습 진도 저장. 먼저 정답을 펼친 경우 스스로 이해도를 평가할 수 있습니다.
- **시험:** 과목 조합, 무작위 출제, 문제 수·제한 시간 선택, 문제 간 자유 이동, 자동 제출, 결과·해설·시험 기록. 진행 중인 시험은 재시작해도 답안과 원래 제한 시간이 복원됩니다.
- **오답노트:** 틀린 답안 자동 수집, 과목 필터, 메모, 다시 풀기, 복습 완료. 다시 맞히면 완료로 이동하고 다시 틀리면 복습 대상으로 돌아옵니다.
- **저장:** 학습 기록, 북마크, 오답·메모, 시험 기록은 현재 기기에 저장됩니다. 저장 중·완료·실패를 표시하고 실패 시 다시 저장할 수 있습니다. 손상된 기록은 정상 항목을 복구하고 원본을 별도 보관합니다. 원본 보관에 실패하면 기존 기록을 덮어쓰지 않습니다. 웹에서는 같은 브라우저·주소를 사용해야 같은 기록을 확인할 수 있습니다. 브라우저 데이터를 삭제하면 기록이 삭제됩니다.

단답형·실행 결과 108문제는 답안 및 동의어로 채점합니다. 서술형·복수 답안·SQL 작성·표·집합 등 85문제는 모범답안과 비교하여 직접 채점합니다. 시험의 미응답은 오답으로 처리합니다. 점수는 문항별 동일 배점의 백분율이며 실제 시험의 배점표를 재현하지 않습니다.

키워드·SQL 단답은 대소문자와 입력 간격 차이를 허용합니다. **프로그램 실행 결과는 대소문자·내부 공백·줄바꿈을 구분**합니다. 줄 끝의 불필요한 공백, 답안 앞뒤의 빈 공간, Windows의 CRLF 줄바꿈은 허용합니다. 예를 들어 Python의 `False`와 `false`, 두 줄의 출력과 한 줄의 출력은 서로 다른 답입니다.

## 문제 구성

| 과목 | 문제 수 |
| --- | ---: |
| 키워드 찾기 | 130 |
| SQL | 17 |
| C 제어문 | 14 |
| C 포인터 | 5 |
| C 구조체 | 3 |
| C 사용자 정의 함수 | 9 |
| JAVA 활용 | 9 |
| Python 활용 | 6 |

문제마다 원문 파일명과 페이지를 표시합니다. 코드의 들여쓰기, SQL·표의 가로 스크롤, 6개의 원문 도표를 포함합니다. 코드 실행은 앱 내부에서 수행하지 않으며 사용자가 실행 결과를 추론하여 답합니다.

원문 키워드 128번의 `CSV` 표기는 `CVS`로 바로잡고 해설에 명시했습니다. SQL 16번의 답은 원문의 대소문자 구분 없는 LIKE 전제를 해설에 표시했습니다. 해설이 없는 일부 용어에는 모범답안을 표시하고, 프로그래밍 문제에는 원문을 토대로 요약한 풀이를 제공합니다.

## 바로 실행

프로젝트를 처음 내려받았다면 Flutter SDK에서 의존성과 웹 빌드를 준비합니다. 빌드 결과는 Git 저장소에 포함하지 않습니다.

```powershell
flutter pub get
flutter build web
```

프로젝트 폴더에서 다음 명령으로 빌드된 앱을 열 수 있습니다.

```powershell
python -m http.server 8765 --bind 127.0.0.1 --directory build/web
```

브라우저에서 **http://127.0.0.1:8765**를 여세요. `tools/preview.cmd`를 두 번 클릭해 실행할 수도 있습니다. HTML 파일을 직접 더블클릭하지 말고 로컬 서버로 실행해주세요.

Android APK는 `build/app/outputs/flutter-apk/`에 생성합니다. 개인 설치용 빌드이며 스토어 배포를 위한 서명 설정은 별도입니다.

## 개발 및 검증

검증 기준은 **Flutter 3.38.9 / Dart 3.10.8**입니다. 잠금 파일 `pubspec.lock`을 사용합니다.

```powershell
flutter pub get
flutter run -d chrome
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --coverage
flutter build web --no-pub --no-wasm-dry-run
flutter build apk --release --no-pub
```

Windows에서 `pub get`이 플러그인 심볼릭 링크 오류를 안내하면 Windows 개발자 모드가 필요합니다. 이 환경에서는 의존성을 내려받은 후 `--no-pub`으로 웹·Android 빌드와 테스트를 완료했습니다.

```powershell
python tools/validate_content.py
```

자료 검증은 전체 문항 수·고유 ID·출처 페이지·코드·도표·추출 예외를 확인합니다. 위 명령은 JSON과 포함된 도표를 검사합니다. 원본 PDF와 페이지 수도 대조하려면 `pypdf`를 설치하고 경로를 지정하세요.

```powershell
python -m pip install pdfplumber pypdf
python tools/validate_content.py --source-dir "C:\자료\원본PDF"
```

원본 PDF는 이동·수정하지 않았습니다. `tools/extract_keywords_sql.py --source-dir "C:\자료\원본PDF"`와 `tools/extract_code.py --source-dir "C:\자료\원본PDF"`로 문제 JSON을 재생성할 수 있습니다. 두 추출 명령은 `assets/data/`를 갱신하므로 결과를 검토하세요. 기본 입력 폴더는 Git에서 제외한 `source-pdfs/`이며, 특정 사용자의 경로에 의존하지 않습니다.

`.github/workflows/flutter-ci.yml`은 자료 검증, 포맷, 정적 분석, 테스트, 웹 빌드를 자동 실행하도록 구성되어 있습니다. SDK 버전과 실행 액션의 커밋을 고정했습니다. 소프트웨어 공학 평가와 수정 근거는 [평가 보고서](docs/engineering-review.md)에 정리했습니다.

## 소스

- `lib/main.dart`: 앱 실행 진입점
- `lib/app.dart`: 테마와 앱 로딩·오류 처리
- `lib/screens/`: 학습 홈, 학습, 시험, 결과, 오답노트 화면
- `lib/widgets/`: 문제·답안 표시와 공통 화면 구성
- `lib/design.dart`: 뉴모피즘 카드·버튼·색상·과목 아이콘
- `lib/models.dart`: 문제·채점·시험 모델
- `lib/study_store.dart`: 기기 저장, 진도, 오답·메모, 시험 상태
- `assets/data/`: PDF에서 추출한 8개 문제집 JSON
- `assets/prompts/`: 정답을 제외한 원문 도표

Noto Sans KR와 JetBrains Mono는 앱에 포함되며 SIL Open Font License를 따릅니다. 라이선스는 `assets/fonts/`에 보관되어 있습니다.
