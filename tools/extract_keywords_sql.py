"""Extract the 130 keyword and 17 SQL questions from the supplied PDFs.

Question starts are matched in strict source order; answer/explanation numbering
cannot accidentally create questions. Source data is never executed.
"""
from pathlib import Path
import argparse
import json
import re
import pdfplumber

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source-pdfs"
DATA = ROOT / "assets" / "data"
ASSETS = ROOT / "assets" / "prompts"
DATA.mkdir(parents=True, exist_ok=True)
ASSETS.mkdir(parents=True, exist_ok=True)


def read_questions(filename, count):
    pages = pdfplumber.open(SOURCE / filename)
    records = []
    current = None
    expected = 1
    for page_no, page in enumerate(pages.pages, 1):
        for line in (page.extract_text() or "").splitlines():
            if line in ["[정렬]", "[그룹]", "[조인]"]:
                continue
            match = re.match(rf"^{expected}\.\s+(.*)$", line)
            if match:
                if current:
                    records.append(current)
                current = {"number": expected, "lines": [], "pages": []}
                expected += 1
                line = match.group(1)
            if current:
                current["lines"].append(line)
                if page_no not in current["pages"]:
                    current["pages"].append(page_no)
    if current:
        records.append(current)
    assert [record["number"] for record in records] == list(range(1, count + 1))
    return pages, records


def parse_record(raw, category, filename):
    lines = raw["lines"]
    explanation_start = next((i for i, line in enumerate(lines) if line == "[해설]"), len(lines))
    question_answer = lines[:explanation_start]
    explanation = "\n".join(lines[explanation_start + 1:]).strip()
    # SQL topic banners belong to the next chapter rather than an explanation.
    explanation = re.sub(r"\n\[(?:정렬|그룹|조인)\]\s*$", "", explanation)
    answer_start = next(i for i, line in enumerate(question_answer) if re.match(r"^답\s*(?::|$)", line))
    prompt = "\n".join(question_answer[:answer_start]).strip()
    answer_lines = question_answer[answer_start:]
    answer_lines[0] = re.sub(r"^답\s*:?\s*", "", answer_lines[0])
    answer = "\n".join(answer_lines).strip()
    record = {
        "id": f"{category}-{raw['number']:03}",
        "categoryId": category,
        "number": raw["number"],
        "prompt": prompt,
        "answer": answer,
        "explanation": explanation,
        "aliases": [],
        "grading": "manual",
        "source": filename,
        "sourcePages": raw["pages"],
        "title": "",
    }
    return record


KEYWORD_TITLES = """
애자일 개발 방법론|리팩토링의 목적|기능·비기능 요구사항|클래스 다이어그램|UML의 구성 요소|UML 관계|UML 다이어그램 식별|LOC 개발 기간 계산|데이터베이스 스키마|데이터베이스 설계 단계|
데이터베이스 구축 순서|데이터 모델 구성 요소|카디널리티와 디그리|E-R 다이어그램 요소|키의 유일성과 최소성|관계대수 연산 기호|관계대수 나누기 연산|관계해석|삭제 이상|이상의 종류|
함수적 종속|제2정규형|반정규화|비정규화의 개념|트랜잭션의 원자성|트랜잭션 특성|색인 파일 구조|목표 복구 시간|임의 접근통제|REDO와 UNDO|
XML|SOAP|WSDL|럼바우 모델링|인터페이스 분리 원칙|제어 결합도|결합도의 종류|결합도와 응집도|응집도의 종류|팬인과 팬아웃|
프로세스 간 통신|테스트 케이스 구성 요소|Factory Method 패턴|Bridge와 Observer 패턴|행위 패턴|EAI|EAI 구축 유형|JSON|AJAX|IPSec|
JUnit|자연 사용자 인터페이스|그래픽 사용자 인터페이스|UI 직관성|UI 유효성|UX와 UI|살충제 패러독스|정적 분석|테스트 커버리지|분기 커버리지 경로|
블랙박스 테스트|경계값 분석|블랙박스 테스트 기법|원인·효과 그래프|동치 분할 검사|V-모델 테스트 단계|단위·통합 테스트|알파·베타 테스트|스텁|상향식 통합 테스트|
회귀 테스트|샘플링 오라클|애플리케이션 성능 지표|정적·동적 분석|GRANT|ROLLBACK|보안 가용성|SQL Injection|IDEA와 Skipjack|TKIP|
DES|AES|MD5|ARP 스푸핑|LAND Attack|사회 공학과 다크 데이터|세션 하이재킹|Watering Hole|AAA 서버|VPN|
SIEM|헝가리안 표기법|스니핑|생성자|UNIX|Python 리스트 메소드|안드로이드|프로세스 상태 전이|HRN 우선순위|프로세스 스케줄링|
chmod 권한 설정|IPv4·IPv6 주소 비트|FLSM 브로드캐스트 주소|서브네팅 주소와 호스트 수|IPv6|OSI 계층|물리 계층|프로토콜|프로토콜의 기본 요소|HTTP·하이퍼텍스트·HTML|
가상 회선과 데이터그램|RARP|ICMP|SSO|애드 혹 네트워크|NAT|개방형 링크드 데이터|경로 제어 프로토콜|블록체인|ISMS|
Trustzone과 Typosquatting|RAID 0|하둡|데이터 마이닝|즉각 갱신 기법|로킹|릴리즈 노트 머릿말|형상 관리 도구|형상 통제|형상관리
""".replace("\n", "").strip().split("|")

SQL_TITLES = [
    "COUNT·DISTINCT와 연쇄 삭제", "DISTINCT와 집계 결과", "ALL을 이용한 하위 질의", "NULL과 COUNT",
    "관계대수 PROJECT", "UPDATE와 SET", "AND·OR 연산자 우선순위", "DELETE문 작성", "ALTER TABLE과 ADD",
    "IN을 이용한 조회", "인덱스 생성", "내림차순 정렬", "LIKE와 ORDER BY", "GROUP BY와 COUNT",
    "GROUP BY와 HAVING", "CROSS JOIN과 LIKE", "LEFT JOIN 조건",
]


def aliases_for_keyword(record):
    answer = record["answer"]
    # Full descriptions, multipart questions and lists require comparison by the learner.
    if "\n" in answer or "•" in answer or any(word in record["prompt"] for word in ["서술", "설명하시오", "3가지를", "계산식", "계산식을", "명령문을 작성"]):
        return
    if re.search(r"(?:이다|한다|있다|없다|된다)\.$", answer):
        return
    if "," in answer or len(answer) > 100:
        return
    record["grading"] = "exact"
    alternatives = [answer]
    match = re.fullmatch(r"([^()]+)\(([^()]+)\)", answer)
    if match:
        alternatives += [match.group(1).strip(), match.group(2).strip()]
    custom = {
        7: ["패키지", "Package Diagram", "패키지 다이어그램"],
        23: ["반정규화", "비정규화", "Denormalization"],
        58: ["정적 분석", "정적 테스트", "Static Analysis", "Static Test"],
        62: ["Boundary Value Analysis", "경계값 분석", "경계값 분석 검사"],
        64: ["Cause-Effect Graph", "원인 효과 그래프", "원인·효과 그래프", "원인 효과 그래프 검사"],
        65: ["동치 분할 검사", "동치 분할", "동등 분할", "Equivalence Partitioning Testing", "Equivalence Partitioning"],
        71: ["Regression", "Regression Test", "회귀 테스트"],
        88: ["Watering Hole", "워터링 홀", "워터링홀"],
        122: ["0", "RAID 0", "Level 0", "Level ( 0 )"],
    }
    alternatives += custom.get(record["number"], [])
    record["aliases"] = list(dict.fromkeys(alternatives))


def crop_diagram(pdf, number, page_no):
    page = pdf.pages[page_no - 1]
    # The source has Image1 as its background watermark, Image2 as the question figure,
    # and sometimes Image3 as a QR code. Only the figure is needed in the app.
    figure = next(item for item in page.images if item["name"] == "Image2")
    bbox = (figure["x0"] - 2, figure["top"] - 2, figure["x1"] + 2, figure["bottom"] + 2)
    path = ASSETS / f"keyword-{number:03}.png"
    page.crop(bbox).to_image(resolution=180).save(path)
    return f"assets/prompts/{path.name}"


def keyword_questions():
    filename = "정보처리기사실기_01_키워드찾기130문제.pdf"
    pdf, raw = read_questions(filename, 130)
    records = [parse_record(item, "keyword", filename) for item in raw]
    assert len(KEYWORD_TITLES) == 130
    for record, title in zip(records, KEYWORD_TITLES):
        record["title"] = title
        aliases_for_keyword(record)
    for number, page in [(7, 3), (14, 5), (40, 14), (60, 20), (66, 24), (98, 33)]:
        records[number - 1]["promptAsset"] = crop_diagram(pdf, number, page)
    records[59]["prompt"] += "\n\n답안은 7칸과 6칸의 두 테스트 경로로 작성합니다."
    # Correct the obvious CVS typo and explicitly retain its provenance in the note.
    records[127]["answer"] = "CVS, Git, SVN"
    records[127]["explanation"] = "원문 정답의 ‘CSV’는 보기의 ‘CVS’를 잘못 적은 표기입니다. 형상 관리 도구는 CVS, Git, SVN입니다."
    # Preserve tables as independent blocks when the source lays them side by side.
    records[21]["prompt"] = """데이터베이스에 대한 다음 설명에서 괄호에 공통으로 들어갈 알맞은 답을 쓰시오.
테이블을 만들 때는 이상(Anomaly)을 방지하기 위해 데이터들의 중복성 및 종속성을 배제하는 정규화를 수행한다. 아래 그림은 부분 함수적 종속을 제거하여 제 (   ) 정규형을 만드는 과정이다.

<Table R>
A(key)  B(key)  C        D
A345    1001    Seoul    Pmre
D347    1001    Busan    Preo
A210    1007    Gwangju  Ciqen
A345    1007    Seoul    Esto
B230    1007    Daegu    Loid
D347    1201    Busan    Drag

<Table R>의 함수적 종속 관계
A, B → C, D
A → C
         ↓
<Table R1>
A(key)  B(key)  D
A345    1001    Pmre
D347    1001    Preo
A210    1007    Ciqen
A345    1007    Esto
B230    1007    Loid
D347    1201    Drag

<Table R2>
A(key)  C
A345    Seoul
D347    Busan
A210    Gwangju
B230    Daegu

<Table R>의 경우, C는 key에 해당하는 A와 B 중 A에만 종속되는 부분 함수적 종속이다. 이 문제 해결을 위해 <Table R1>에서 C를 분리하여 <Table R1>과 <Table R2>로 만들면 제 (   ) 정규형에 해당하는 테이블이 완성된다."""
    records[25]["prompt"] = """다음은 트랜잭션(Transaction)의 특징이다. 괄호(①, ②)에 들어갈 알맞은 특징을 쓰시오.

( ① )
트랜잭션의 연산은 데이터베이스에 모두 반영되도록 완료(Commit)되든지 아니면 전혀 반영되지 않도록 복구(Rollback)되어야 한다. (All or Nothing)

일관성
트랜잭션이 그 실행을 성공적으로 완료하면 언제나 일관성 있는 데이터베이스 상태로 변환한다.

( ② )
둘 이상의 트랜잭션이 동시에 병행 실행되는 경우 어느 하나의 트랜잭션 실행 중에 다른 트랜잭션의 연산이 끼어들 수 없다.

지속성
성공적으로 완료된 트랜잭션의 결과는 시스템이 고장나더라도 영구적으로 반영되어야 한다."""
    records[41]["prompt"] = """다음 테스트 케이스를 참조하여 괄호에 들어갈 테스트 케이스의 구성 요소를 <보기>에서 찾아 쓰시오.

식별자_ID | 테스트 항목 | ( ① ) | ( ② ) | ( ③ )
LS_W10_35 | 로그인 기능 | 사용자 초기 화면 | 아이디(test_a01), 비밀번호(203a!d5%ffa1) | 로그인 성공
LS_W10_36 | 로그인 기능 | 사용자 초기 화면 | 아이디(test_a01), 비밀번호(1234) | 로그인 실패(1) - 비밀번호 비일치
LS_W10_37 | 로그인 기능 | 사용자 초기 화면 | 아이디(""), 비밀번호("") | 로그인 실패(2) - 미입력

<보기>
• 요구 절차 • 의존성 여부 • 테스트 데이터 • 테스트 조건
• 하드웨어 환경 • 예상 결과 • 소프트웨어 환경 • 성공/실패 기준"""
    records[72]["prompt"] = """애플리케이션 성능이란 사용자가 요구한 기능을 최소한의 자원을 사용하여 최대한 많은 기능을 신속하게 처리하는 정도를 나타낸다. 애플리케이션 성능 측정의 지표에 대한 다음 설명에서 괄호(①~③)에 들어갈 알맞은 용어를 쓰시오.

( ① ) : 일정 시간 내에 애플리케이션이 처리하는 일의 양을 의미한다.
( ② ) : 애플리케이션에 요청을 전달한 시간부터 응답이 도착할 때까지 걸린 시간을 의미한다.
( ③ ) : 애플리케이션에 작업을 의뢰한 시간부터 처리가 완료될 때까지 걸린 시간을 의미한다.
자원 활용률 : 애플리케이션이 의뢰한 작업을 처리하는 동안의 CPU, 메모리, 네트워크 등의 자원 사용률을 의미한다."""
    pdf.close()
    return records


def sql_questions():
    filename = "정보처리기사실기_02_SQL17문제.pdf"
    pdf, raw = read_questions(filename, 17)
    records = [parse_record(item, "sql", filename) for item in raw]
    for record, title in zip(records, SQL_TITLES):
        record["title"] = title
    # Question 1 places an answer between its two SQL commands: both commands remain
    # in the prompt, and both answers belong to the one source question.
    first_lines = raw[0]["lines"]
    first_lines = first_lines[:first_lines.index("[해설]")]
    records[0]["prompt"] = "\n".join(line for line in first_lines if not re.match(r"^답\s*:", line)).strip()
    records[0]["answer"] = "① 3\n② 4"
    records[0]["explanation"] = "① 부서코드가 20인 직원은 3명입니다. DISTINCT는 부서코드가 아니라 COUNT(부서코드)의 결과에 적용되므로 결과는 3입니다.\n② ON DELETE CASCADE에 의해 부서 20을 삭제하면 해당 직원 3명도 함께 삭제됩니다. 전체 7명 중 4명이 남으므로 결과는 4입니다."
    records[4]["prompt"] = """다음은 <EMPLOYEE> 릴레이션에 대해 <관계 대수식>을 수행했을 때 출력되는 <결과>이다. <결과>의 각 괄호(①~⑤)에 들어갈 알맞은 답을 쓰시오.

<관계 대수식>
π_TTL(EMPLOYEE)

<EMPLOYEE>
INDEX  AGE  TTL
1      48   부장
2      25   대리
3      41   과장
4      36   차장

<결과>
( ① )
( ② )
( ③ )
( ④ )
( ⑤ )"""
    records[14]["answer"] = "SELECT 과목이름, MIN(점수) AS 최소점수, MAX(점수) AS 최대점수 FROM 성적 GROUP BY 과목이름 HAVING AVG(점수) >= 90;"
    records[15]["prompt"] = """<A> 테이블과 <B> 테이블을 참고하여 <SQL문>의 실행 결과를 쓰시오.

<A>
NAME
Smith
Allen
Scott

<B>
RULE
S%
%T%

<SQL문>
SELECT COUNT(*) CNT FROM A CROSS JOIN B WHERE A.NAME LIKE B.RULE;"""
    records[15]["explanation"] += "\n\n원문 정답 4는 LIKE의 영문 대소문자를 구분하지 않는 비교를 전제로 합니다. 대소문자를 구분하는 데이터베이스 설정에서는 %T%가 Smith와 Scott에 일치하지 않아 결과가 달라집니다."
    records[16]["prompt"] = """다음 <사원> 테이블과 <동아리> 테이블을 조인(Join)한 <결과>를 확인하여 <SQL문>의 괄호(①, ②)에 들어갈 알맞은 답을 쓰시오.

<사원>
코드  이름    부서
1601  김명해  인사
1602  이진성  경영지원
1731  박영광  개발
2001  이수진  (값 없음)

<동아리>
코드  동아리명
1601  테니스
1731  탁구
2001  볼링

<결과>
코드  이름    동아리명
1601  김명해  테니스
1602  이진성  (값 없음)
1731  박영광  탁구
2001  이수진  볼링

<SQL문>
SELECT a.코드, 이름, 동아리명 FROM 사원 a LEFT JOIN 동아리 b ( ① ) a.코드 = b.( ② );"""
    for number in [3, 4, 7]:
        record = records[number - 1]
        record["grading"] = "exact"
        record["aliases"] = [record["answer"]]
    pdf.close()
    return records


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=SOURCE,
                        help="원본 PDF 폴더 (기본값: 프로젝트의 source-pdfs)")
    SOURCE = parser.parse_args().source_dir
    if not SOURCE.is_dir():
        parser.error(f"원본 PDF 폴더가 없습니다: {SOURCE}. --source-dir로 지정해주세요.")
    for filename in ["정보처리기사실기_01_키워드찾기130문제.pdf", "정보처리기사실기_02_SQL17문제.pdf"]:
        if not (SOURCE / filename).is_file():
            parser.error(f"원본 PDF가 없습니다: {filename}")
    for name, records in [("keywords", keyword_questions()), ("sql", sql_questions())]:
        for record in records:
            assert record["prompt"].strip() and record["answer"].strip()
            assert "답 :" not in record["prompt"]
            assert record["sourcePages"]
            if "promptAsset" in record:
                assert (ROOT / record["promptAsset"]).exists()
        destination = DATA / f"{name}.json"
        destination.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"{destination}: {len(records)} questions")
        print(f"  {sum(r['grading'] == 'exact' for r in records)} exact / {sum(r['grading'] == 'manual' for r in records)} manual")
