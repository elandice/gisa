from pathlib import Path
import argparse
import json
import re
import pdfplumber

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'source-pdfs'
FILES = [
    ('03', 'control', 'control', '14', '제어문'),
    ('04', 'pointer', 'pointers', '5', '포인터'),
    ('05', 'struct', 'structs', '3', '구조체'),
    ('06', 'function', 'functions', '9', '사용자정의함수'),
    ('07', 'java', 'java', '9', 'JAVA활용'),
    ('08', 'python', 'python', '6', 'Python활용'),
]

def collect():
    result = []
    for prefix, category, output, count, label in FILES:
        source = next(SOURCE.glob(f'정보처리기사실기_{prefix}_*.pdf'))
        pages = []
        with pdfplumber.open(source) as pdf:
            for index, page in enumerate(pdf.pages):
                lines = [{'text': line['text'], 'x': min(char['x0'] for char in line['chars'])}
                         for line in page.extract_text_lines() if line['chars']]
                pages.append({'number': index + 1, 'lines': lines})
        questions = []
        for page in pages:
            for line in page['lines']:
                match = re.match(r'^(\d+)\. 다음', line['text'])
                if match:
                    questions.append({'number': int(match[1]), 'pages': [], 'lines': []})
                if questions:
                    questions[-1]['lines'].append(line)
                    if page['number'] not in questions[-1]['pages']:
                        questions[-1]['pages'].append(page['number'])
        for question in questions:
            question['raw'] = '\n'.join(line['text'] for line in question['lines'])
        result.append({'category': category, 'output': output, 'source': source.name, 'questions': questions})
    return result


NOTES = {
 'control': [
  ('완전수 세기', '6부터 30까지 각 수의 자기 자신을 제외한 약수를 합산한다. 약수의 합이 원래 수와 같은 완전수는 6과 28 두 개이므로 el은 2가 된다.'),
  ('조건을 만족하는 마지막 정수', 'i는 1부터 998까지 증가한다. 3과 2로 모두 나누어 떨어지는 수, 즉 6의 배수일 때 r을 i로 덮어쓴다. 마지막으로 저장되는 값은 996이다.'),
  ('switch의 연속 실행', 'i가 3이므로 case 3에서 k=0이 된다. break가 없어 case 4, case 5, default도 실행한다. k는 0 → 3 → -7 → -8로 바뀐다.'),
  ('정수 역순 변환의 연산자', '양의 정수 number가 0이 될 때까지 반복해야 하므로 ①은 != 또는 >이다. 마지막 자릿수는 number % div로 얻고, 처리한 자릿수를 제거하려면 number / div를 사용하므로 ②는 %, ③은 /이다.'),
  ('논리 연산과 XOR', '처음 조건에서 (w==2 | w==y)는 true, !(y>z)는 true, (1==x ^ y!=z)는 false ^ true이므로 true이다. w=x+y=7이 된다. 다음 조건 7==x ^ y!=w는 false ^ true이므로 true가 되어 w의 값 7을 출력한다.'),
  ('비트 시프트와 반복', 'range(1,3)은 1과 2를 만든다. 매 반복에서 result는 누적값이 아니라 a >> i로 다시 저장된다. i=1일 때 100 >> 1=50에 1을 더하여 51, i=2일 때 100 >> 2=25에 1을 더하여 26이 된다.'),
  ('반복문의 출력 형식', 'i=0부터 5까지 각 i를 출력하고 j에 누적한다. i가 5가 아니면 +를 출력하고, i=5이면 =과 합계 15를 출력하므로 0+1+2+3+4+5=15가 된다.'),
  ('중첩 리스트 순회', 'lol[0]은 [1, 2, 3], lol[2][1]은 7이다. 바깥 반복에서 각 행을, 안쪽 반복에서 각 행의 요소를 순서대로 출력한다. end=\' \'로 요소 사이에 공백을 넣고, 각 행이 끝나면 print()로 줄을 바꾼다.'),
  ('10진수를 2진수로 변환', 'n이 0보다 큰 동안 나머지 n % 2를 배열에 저장하고 n을 2로 나눈 몫으로 바꾼다. 따라서 ①은 n > 0, ②는 n % 2이다. 배열을 거꾸로 출력하면 10의 8자리 2진수 00001010이 된다.'),
  ('2차원 배열의 크기', 'i는 0, 1, 2의 3개 행을, j는 0부터 4까지 5개 열을 사용한다. 따라서 ary는 new int[3][5]로 선언해야 하므로 ①은 3, ②는 5이다.'),
  ('0으로 시작하는 누적 곱', 'c의 초기값은 0이다. i가 증가하더라도 c *= i는 계속 0에 i를 곱하므로 c는 0을 유지한다.'),
  ('continue로 홀수 건너뛰기', 'a는 1부터 10까지 증가한다. a가 홀수이면 continue로 합산을 건너뛴다. 짝수 2, 4, 6, 8, 10의 합은 30이다.'),
  ('배열 값의 순위', 'result[i]를 1로 시작하고 arr[i]보다 큰 원소가 있을 때마다 1씩 증가시킨다. 77, 32, 10, 99, 50의 내림차순 순위는 각각 2, 4, 5, 1, 3이다. 공백 없이 이어 출력하므로 24513이다.'),
  ('가변 길이 2차원 배열', 'aa[0]은 {45, 50, 75}이므로 길이가 3이고, aa[1]은 {89}이므로 길이가 1이다. 이어서 aa[0][0]=45, aa[0][1]=50, aa[1][0]=89를 각각 한 줄씩 출력한다.'),
 ],
 'pointer': [
  ('문자열 길이와 포인터', 'len은 포인터가 문자열 종료 문자 \\0을 만날 때까지 p와 r을 1씩 증가시킨다. "2022"의 길이는 4, "202207"의 길이는 6이므로 두 길이의 합 10을 출력한다.'),
  ('배열과 포인터 연산', 'p=a+i는 a[i]를 가리키므로 *p는 a[i]이다. i=1,2,3일 때 b[i-1]은 각각 2,2,4이고 sum에 더하는 값은 각각 2+2=4, 2+4=6, 4+8=12이다. 합계는 22이다.'),
  ('포인터 배열의 역참조', 'array[1]은 b의 주소이므로 *array[1]=24이다. array는 첫 요소 array[0]을 가리키고 그 요소는 a의 주소이므로 **array=12이다. 24+12+1=37을 출력한다.'),
  ('배열 표기와 포인터 표기', '*(ary+0)과 *ary는 ary[0]과 같다. ary[0]=1, ary[1]=1+2=3, ary[2]=1+3=4가 된다. 반복문으로 합산하면 8이다.'),
  ('문자열 포인터와 문자 연산', '%s에 p를 전달하면 전체 문자열 KOREA, p+3을 전달하면 3번째 인덱스부터의 문자열 EA를 출력한다. *p는 K, *(p+3)은 E이다. *p+2는 K의 문자 코드에 2를 더한 M이다. 각 출력은 줄바꿈한다.'),
 ],
 'struct': [
  ('구조체 배열의 멤버', '반복문의 i=0일 때 st[0].n=0, st[0].g=1이고, i=1일 때 st[1].n=1, st[1].g=2이다. st[0].n + st[1].g는 0+2=2이다.'),
  ('구조체 포인터의 이동', 'p=a로 첫 번째 구조체를 가리킨 뒤 p++로 두 번째 구조체로 이동한다. 두 번째 원소의 name은 Lee, age는 38이다. -> 연산자로 두 멤버를 각각 한 줄에 출력한다.'),
  ('구조체 포인터와 합계', '(p+1)은 st[1], (p+2)는 st[2]를 가리킨다. st[1].hab=84+75=159이고 st[1].hhab=159+95+88=342이다. 출력값은 159+342=501이다.'),
 ],
 'function': [
  ('경계 검사와 인접 칸 누적', 'field[y][x]가 1인 칸마다 자기 칸을 포함한 주변 3×3 영역에 1씩 더한다. chkover는 행과 열이 0 이상 4 미만인지 검사하여 배열 밖 접근을 막는다. 최종 mines의 행은 [1,1,3,2], [3,4,5,3], [3,5,6,4], [3,5,5,3]이다.'),
  ('함수에서 배열 반환', 'mkarr는 길이가 4인 tmpArr를 만들고 각 인덱스 i에 i를 저장하여 [0,1,2,3]을 반환한다. main의 arr가 이를 참조하고 원소를 공백 없이 출력하므로 0123이다.'),
  ('가장 큰 소인수', 'isPrime은 2부터 number-1 사이의 수로 나누어 떨어지면 0, 그렇지 않으면 1을 반환한다. main은 13195를 나누어 떨어지게 하는 소수를 찾을 때마다 max_div를 갱신한다. 13195=5×7×13×29이므로 마지막으로 저장되는 가장 큰 소인수는 29이다.'),
  ('반복문으로 거듭제곱', 'mp(2,10)은 res=1에서 시작하여 2를 10번 곱한다. 결과는 2의 10제곱인 1024이다.'),
  ('클래스 이름으로 메서드 호출', 'main에서 객체를 만들지 않고 Test.check(1)처럼 클래스 이름으로 check를 호출한다. check를 클래스 메서드로 선언하는 예약어 static이 필요하다.'),
  ('중첩 함수 호출의 반환값', 'r1()은 4를 반환하고 r10()은 30+4=34를 반환한다. r100()은 200+34=234를 반환하므로 main은 234를 출력한다.'),
  ('배열 반환과 공백 출력', 'arr()는 길이가 4인 배열 a에 0,1,2,3을 차례로 저장한 뒤 반환한다. main은 각 원소 뒤에 공백을 붙여 출력하므로 0 1 2 3이 출력된다.'),
  ('배열을 전달한 버블 정렬', 'align은 인접한 두 원소의 크기를 비교하여 앞의 값이 더 크면 temp를 이용해 교환한다. 반복할수록 큰 값이 뒤로 이동하여 배열은 [50,75,85,95,100]으로 정렬된다. main이 같은 배열을 공백으로 구분하여 출력한다.'),
  ('재귀 팩토리얼', 'func(a)는 a가 1 이하이면 1을 반환하고, 아니면 a * func(a-1)을 반환한다. 5를 입력하면 5×4×3×2×1=120이다.'),
 ],
 'java': [
  ('생성자와 객체 속성', 'new cond(3)은 a를 3으로 초기화하지만 이후 obj.a=5로 바뀐다. func의 b는 1에서 시작하여 5×1, 5×2, 5×3, 5×4를 더하므로 51이다. func는 a+b=56을 반환하고 main은 obj.a+56=61을 출력한다.'),
  ('객체 참조를 전달한 메서드', 'func1과 func2는 main에서 만든 같은 객체 m을 참조한다. m.a=100에서 func1이 10을 곱해 1000으로 바꾼다. m.b=1000으로 저장한 후 func2가 m.a에 m.b를 더하므로 2000이다.'),
  ('오버라이딩과 super', 'ovr1의 sun(3,2)은 3+2=5를 반환한다. ovr2의 sun(3,2)은 3-2+super.sun(3,2)=1+5=6을 반환한다. 두 값을 더하여 11을 출력한다.'),
  ('상위 클래스 생성자 호출', 'new B(10)에서 B의 생성자가 super(10)을 호출하여 A의 a에 10을 저장한다. 이어서 super.display()가 "a="와 a를 연결한 a=10을 출력한다.'),
  ('Runnable로 스레드 생성', 'Car는 Runnable 인터페이스를 구현하고 run()을 정의한다. new Thread(new Car())처럼 Runnable 객체를 Thread 생성자에 전달해야 하므로 괄호에는 Car가 들어간다.'),
  ('싱글턴의 공유 상태', 'Connection.get()은 처음 한 번만 새 객체를 만들고 이후에는 정적 변수 _inst에 저장한 같은 객체를 반환한다. conn1, conn2, conn3이 같은 객체의 count()를 총 3회 호출하므로 getCount()는 3을 반환한다.'),
  ('객체 생성과 동적 메서드 호출', '객체를 생성할 때 사용하는 예약어는 new이다. Parent pa = new Child()로 생성하면 pa.show()는 실제 객체 Child에서 재정의한 show()를 호출하여 child를 출력한다.'),
  ('오버라이딩된 재귀 호출', 'obj의 선언형은 Parent지만 실제 객체는 Child이므로 Child.compute가 호출된다. 이 메서드는 num<=1이면 num 자체를 반환하고, 나머지는 compute(num-1)+compute(num-3)이다. compute(2)=1+(-1)=0, compute(3)=0+0=0, compute(4)=0+1=1이다.'),
  ('추상 클래스와 메서드 오버로딩', 'Car 생성자는 자식의 name과 super.name을 모두 Spark로 저장한다. obj.getName()에는 인수가 없으므로 Vehicle의 매개변수 없는 메서드를 호출한다. 이 메서드는 Vehicle의 name을 사용하여 Vehicle name : Spark를 반환한다. Car의 인수가 있는 getName 메서드들은 호출되지 않는다.'),
 ],
 'python': [
  ('비교 연산자', 'x=100, y=200이므로 x==y는 거짓이다. Python의 불리언 표기에 따라 False를 출력한다.'),
  ('문자열 슬라이싱과 서식', 'a[0:3]은 REM, a[12:16]은 EMBE이므로 b는 REMEMBE이다. "R AND %s" % "STR"은 R AND STR이다. b와 c를 연결하면 REMEMBER AND STR이 된다.'),
  ('집합의 원소 변경', '집합은 중복을 허용하지 않는다. 베트남을 추가하고 중국을 다시 추가해도 중국은 하나만 남는다. 일본을 제거한 후 한국, 홍콩, 태국을 추가하면 한국, 중국, 베트남, 홍콩, 태국의 다섯 원소가 남는다. 집합의 출력 순서는 고정되지 않으므로 원소 구성이 같으면 정답이다.'),
  ('map과 lambda', 'map은 각 원소를 lambda num : num + 100에 전달한다. [1,2,3,4,5]의 각 원소에 100을 더한 결과를 list로 변환하여 [101, 102, 103, 104, 105]를 출력한다.'),
  ('기본 매개변수', 'func의 num2에는 기본값 2가 지정되어 있다. func(20)은 num1에 20을 전달하고 num2는 2를 사용한다. print는 각 인수 사이에 공백을 넣으므로 a = 20 b = 2를 출력한다.'),
  ('클래스 속성과 문자열 누적', 'myVar는 CharClass의 객체이고 a는 여섯 도시 이름을 담은 리스트이다. 각 문자열의 첫 글자 i[0]를 str01에 차례로 연결한다. S, K, I, D, D, P를 모으므로 SKIDDP를 출력한다.'),
 ],
}

MANUAL = {('control', 4), ('control', 9), ('control', 10), ('function', 1), ('python', 3)}
OVERRIDE_ANSWER = {
    ('control', 4): '① != 또는 >\n② %\n③ /',
    ('control', 9): '① n > 0\n② n % 2',
    ('control', 10): '① 3\n② 5',
    ('function', 1): '1 1 3 2\n3 4 5 3\n3 5 6 4\n3 5 5 3',
    ('python', 3): "{'한국', '중국', '베트남', '홍콩', '태국'}",
}


def build_question(group, question):
    category, number = group['category'], question['number']
    lines = question['lines']
    key = (category, number)
    end = next((i for i, line in enumerate(lines) if line['text'].startswith('답') or line['text'].startswith('배열 <field>')), len(lines))
    body = lines[:end]
    start = next(i for i, line in enumerate(body) if re.match(r'^(#include|public class|class |abstract class|def |x, y =|a =|asia =|lol =)', line['text']))
    prompt = '\n'.join(line['text'] for line in body[:start])
    prompt = re.sub(r'^\d+\.\s*', '', prompt)
    code_lines = body[start:]
    # Cluster the PDF's leading x coordinates, preserving the source block nesting.
    levels = []
    for x in sorted(line['x'] for line in code_lines):
        if not levels or x - levels[-1] > 2:
            levels.append(x)
    code = '\n'.join('    ' * min(range(len(levels)), key=lambda i: abs(levels[i] - line['x'])) + line['text'] for line in code_lines)
    if key == ('control', 10):
        code = code.replace('int n = ;', 'int n = 1;').replace('j * 3 + i + ;', 'j * 3 + i + 1;')
    if key == ('function', 1):
        prompt += '\n\n배열 <field>\n0 1 0 1\n0 0 0 1\n1 1 1 0\n0 1 1 1\n\n배열 <mines>의 4행 4열 값을 작성하시오.'
    answer_body = question['raw'].split('[해설]')[0]
    answer_match = re.search(r'(?m)^답\s*:?\s*(.*)', answer_body)
    answer = answer_body[answer_match.start():] if answer_match else ''
    answer = re.sub(r'^답\s*:?\s*', '', answer).strip()
    if key in OVERRIDE_ANSWER:
        answer = OVERRIDE_ANSWER[key]
    title, explanation = NOTES[category][number - 1]
    return {'id': f'{category}-{number:03}', 'categoryId': category, 'number': number,
            'prompt': prompt, 'code': code, 'answer': answer, 'explanation': explanation,
            'aliases': [], 'grading': 'manual' if key in MANUAL else 'exact',
            'source': group['source'], 'sourcePages': question['pages'], 'title': title}


def write_data(data):
    target = ROOT / 'assets' / 'data'
    target.mkdir(parents=True, exist_ok=True)
    total = 0
    for group in data:
        records = [build_question(group, question) for question in group['questions']]
        expected = len(NOTES[group['category']])
        assert len(records) == expected, (group['category'], len(records), expected)
        assert [q['number'] for q in records] == list(range(1, expected + 1))
        assert all(q['prompt'] and q['code'] and q['answer'] and q['explanation'] for q in records)
        (target / f'{group["output"]}.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        total += len(records)
        print(f'{group["output"]}.json: {len(records)} questions')
    print(f'Total: {total} questions')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='제공받은 코드 PDF 6종에서 문제를 추출합니다.')
    parser.add_argument('--source-dir', type=Path, default=SOURCE,
                        help='원본 PDF 폴더 (기본값: 프로젝트의 source-pdfs)')
    display = parser.add_mutually_exclusive_group()
    display.add_argument('--dump', action='store_true')
    display.add_argument('--raw', choices=[item[1] for item in FILES])
    arguments = parser.parse_args()
    SOURCE = arguments.source_dir
    if not SOURCE.is_dir():
        parser.error(f'원본 PDF 폴더가 없습니다: {SOURCE}. --source-dir로 지정해주세요.')
    for prefix, *_ in FILES:
        matches = list(SOURCE.glob(f'정보처리기사실기_{prefix}_*.pdf'))
        if len(matches) != 1:
            parser.error(f'{prefix}번 원본 PDF가 하나씩 있어야 합니다 (현재 {len(matches)}개).')
    data = collect()
    if arguments.dump:
        for group in data:
            print('\nFILE', group['source'], 'QUESTIONS', len(group['questions']))
            for question in group['questions']:
                print('\nQUESTION', question['number'], 'PAGES', question['pages'])
                print(question['raw'].split('[해설]')[0])
    elif arguments.raw:
        category = arguments.raw
        for group in data:
            if group['category'] == category:
                for question in group['questions']:
                    print('\nQUESTION', question['number'], 'PAGES', question['pages'])
                    print(question['raw'])
    else:
        write_data(data)
