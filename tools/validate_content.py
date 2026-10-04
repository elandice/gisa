"""Audit this app's eight supplied PDF question banks and diagram assets.

This is a content integrity check, not a generic application test. It verifies
the exact source counts, original numbering/page bounds, all 46 code problems,
and cases whose extraction requires special care. No document code is executed.

Run with Python 3.10+: python tools/validate_content.py
Optionally pass --source-dir PATH to verify page counts against the original PDFs.
"""
from __future__ import annotations

import argparse
import ast
import json
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path(r"C:\Users\qkrgk\OneDrive\문서\카카오톡 받은 파일")
MANIFEST = [
    ("keywords.json", "keyword", 130, 44, "정보처리기사실기_01_키워드찾기130문제.pdf"),
    ("sql.json", "sql", 17, 20, "정보처리기사실기_02_SQL17문제.pdf"),
    ("control.json", "control", 14, 27, "정보처리기사실기_03_코드-제어문14문제.pdf"),
    ("pointers.json", "pointer", 5, 11, "정보처리기사실기_04_코드-포인터5문제.pdf"),
    ("structs.json", "struct", 3, 7, "정보처리기사실기_05_코드-구조체3문제.pdf"),
    ("functions.json", "function", 9, 21, "정보처리기사실기_06_코드-사용자정의함수9문제.pdf"),
    ("java.json", "java", 9, 26, "정보처리기사실기_07_코드-JAVA활용9문제.pdf"),
    ("python.json", "python", 6, 6, "정보처리기사실기_08_코드-Python활용6문제.pdf"),
]
CODE_CATEGORIES = {"control", "pointer", "struct", "function", "java", "python"}
DIAGRAM_QUESTIONS = {7: 3, 14: 5, 40: 14, 60: 20, 66: 24, 98: 33}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path)
    arguments = parser.parse_args()
    source_dir = arguments.source_dir or DEFAULT_SOURCE
    errors: list[str] = []
    notes: list[str] = []
    records_by_id: dict[str, dict] = {}
    code_count = 0
    asset_count = 0

    def require(condition: bool, message: str):
        if not condition:
            errors.append(message)

    try:
        from pypdf import PdfReader
    except ImportError:
        PdfReader = None
        notes.append("pypdf unavailable: source page bounds use the verified source manifest.")

    for data_file, category, count, page_count, source_name in MANIFEST:
        data_path = ROOT / "assets" / "data" / data_file
        try:
            records = json.loads(data_path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exception:
            errors.append(f"{data_file}: cannot read question data: {exception}")
            continue
        if not isinstance(records, list):
            errors.append(f"{data_file}: expected an array of questions")
            continue
        require(len(records) == count, f"{data_file}: expected {count} questions, got {len(records)}")
        source_path = source_dir / source_name
        if source_path.exists() and PdfReader:
            actual_page_count = len(PdfReader(source_path).pages)
            require(actual_page_count == page_count, f"{source_name}: expected {page_count} pages, got {actual_page_count}")
        elif arguments.source_dir:
            require(source_path.exists(), f"{source_name}: source PDF missing from --source-dir")
        else:
            notes.append(f"{source_name}: original PDF unavailable; verified manifest page count used.")

        numbers = []
        for position, record in enumerate(records, 1):
            if not isinstance(record, dict):
                errors.append(f"{data_file} question {position}: expected an object")
                continue
            label = record.get("id", f"{data_file} question {position}")
            number = record.get("number")
            numbers.append(number)
            require(type(number) is int, f"{label}: number must be an integer")
            expected_id = f"{category}-{position:03}"
            require(label == expected_id, f"{label}: expected source ID {expected_id}")
            require(label not in records_by_id, f"{label}: duplicate question ID")
            records_by_id[label] = record
            require(record.get("categoryId") == category, f"{label}: incorrect categoryId")
            require(record.get("source") == source_name, f"{label}: incorrect source filename")
            for field in ["prompt", "answer", "title"]:
                require(isinstance(record.get(field), str) and bool(record[field].strip()), f"{label}: missing {field}")
            require(isinstance(record.get("explanation"), str), f"{label}: explanation must be text")
            require(record.get("grading") in ["exact", "manual"], f"{label}: invalid grading mode")
            aliases = record.get("aliases")
            require(isinstance(aliases, list) and all(isinstance(alias, str) and alias.strip() for alias in aliases), f"{label}: aliases must contain nonempty strings")
            pages = record.get("sourcePages")
            valid_pages = isinstance(pages, list) and bool(pages) and all(type(page) is int and 1 <= page <= page_count for page in pages)
            require(valid_pages, f"{label}: sourcePages missing or outside 1..{page_count}")
            if valid_pages:
                require(pages == sorted(set(pages)), f"{label}: sourcePages must be unique and in source order")
            prompt = record.get("prompt", "")
            if isinstance(prompt, str):
                require(not re.search(r"^\s*답\s*(?::|$)", prompt, re.MULTILINE), f"{label}: answer marker leaked into prompt")
                require("[해설]" not in prompt, f"{label}: explanation leaked into prompt")

            if category in CODE_CATEGORIES:
                code_count += 1
                code = record.get("code")
                has_code = isinstance(code, str) and len(code.strip()) >= 15
                require(has_code, f"{label}: missing program code")
                if has_code:
                    require(not re.search(r"^\s*(?:답\s*:|\[해설\])", code, re.MULTILINE), f"{label}: answer/explanation leaked into code")
                    if category == "python" or label in {"control-006", "control-008"}:
                        try:
                            ast.parse(code)
                        except SyntaxError as exception:
                            errors.append(f"{label}: invalid extracted Python syntax: {exception}")
                    else:
                        require(re.search(r"\bmain\s*\(", code) is not None, f"{label}: extracted program entry point missing")
            if "promptAsset" in record:
                asset_count += 1
                asset_value = record["promptAsset"]
                if not isinstance(asset_value, str):
                    errors.append(f"{label}: promptAsset must be a path")
                    continue
                asset_path = (ROOT / asset_value).resolve()
                require(asset_path.is_relative_to((ROOT / "assets" / "prompts").resolve()), f"{label}: diagram must be inside assets/prompts")
                require(asset_path.is_file(), f"{label}: source diagram missing: {asset_value}")
                if asset_path.is_file():
                    header = asset_path.read_bytes()[:24]
                    require(header[:8] == b"\x89PNG\r\n\x1a\n", f"{label}: diagram is not a PNG")
                    if len(header) == 24:
                        width, height = struct.unpack(">II", header[16:24])
                        require(width >= 100 and height >= 100, f"{label}: source diagram too small to read")
        require(numbers == list(range(1, count + 1)), f"{data_file}: source question numbers are not exactly 1..{count}")
        print(f"{data_file}: {len(records)}/{count} questions, source pages 1..{page_count}")

    require(len(records_by_id) == 193, f"Expected 193 unique questions, got {len(records_by_id)}")
    require(code_count == 46, f"Expected 46 code problems, got {code_count}")
    for number, page in DIAGRAM_QUESTIONS.items():
        record = records_by_id.get(f"keyword-{number:03}", {})
        require(bool(record.get("promptAsset")), f"keyword-{number:03}: indispensable source diagram omitted")
        require(page in record.get("sourcePages", []), f"keyword-{number:03}: source diagram page {page} omitted")

    sql1 = records_by_id.get("sql-001", {})
    require(sql1.get("answer") == "① 3\n② 4", "sql-001: both embedded answer markers must remain in the one question")
    require("DELETE FROM 부서 WHERE 부서코드 = 20;" in sql1.get("prompt", ""), "sql-001: second SQL command lost while removing answers")
    require("COUNT(부서코드) FROM 직원;" in sql1.get("prompt", ""), "sql-001: second SELECT command missing")
    cvs = records_by_id.get("keyword-128", {})
    require(cvs.get("answer") == "CVS, Git, SVN", "keyword-128: source CSV typo must be corrected to CVS")
    require("CSV" in cvs.get("explanation", ""), "keyword-128: correction must disclose the original source typo")
    sql16 = records_by_id.get("sql-016", {})
    require(sql16.get("grading") == "manual" and "대소문자" in sql16.get("explanation", ""), "sql-016: LIKE case-sensitivity assumption must be disclosed with manual grading")
    python3 = records_by_id.get("python-003", {})
    require(python3.get("grading") == "manual", "python-003: unordered set output requires manual grading")
    mines = records_by_id.get("function-001", {})
    matrix = mines.get("answer", "").splitlines()
    require(len(matrix) == 4 and all(len(row.split()) == 4 for row in matrix), "function-001: answer must retain the full 4x4 mines array")
    require("field[4][4]" in mines.get("code", "") and "chkover" in mines.get("code", ""), "function-001: field input or boundary-check function missing")

    for note in notes:
        print(f"NOTE: {note}")
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        print(f"FAILED: {len(errors)} content issues", file=sys.stderr)
        return 1
    print(f"PASS: 193 unique source questions, 46 complete code problems, {asset_count} valid diagrams; special extraction cases checked.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
