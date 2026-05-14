import argparse
import json
from collections import defaultdict
from pathlib import Path


EXTENSIONS = {
    "c": "c",
    "go": "go",
    "java": "java",
    "js": "js",
    "jsx": "jsx",
    "py": "py",
    "rb": "rb",
}


def load_language(data_root: Path, split: str, cwe: str, scenario: str) -> str:
    with open(data_root / split / cwe / scenario / "info.json") as f:
        return json.load(f)["language"]


def count_files(path: Path, lang: str) -> int:
    ext = EXTENSIONS[lang]
    return sum(1 for _ in path.glob(f"*.{ext}")) if path.exists() else 0


def add_count(counts: dict, key: tuple[str, ...], parsed: int, non_parsed: int) -> None:
    counts[key]["parsed"] += parsed
    counts[key]["non_parsed"] += non_parsed


def print_table(title: str, rows: list[tuple[str, int, int]]) -> None:
    print(title)
    print(f"{'group':<48} {'parsed':>8} {'non_parsed':>11} {'total':>8} {'non_parsed_%':>13}")
    for group, parsed, non_parsed in rows:
        total = parsed + non_parsed
        pct = (non_parsed / total * 100) if total else 0.0
        print(f"{group:<48} {parsed:>8} {non_parsed:>11} {total:>8} {pct:>12.2f}%")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--eval-root", default="../experiments/sec_eval")
    parser.add_argument("--data-root", default="../data_eval/sec_eval")
    parser.add_argument("--model", default=None)
    parser.add_argument("--split", choices=["trained", "trained-new", "not-trained"], default=None)
    parser.add_argument("--by-model", action="store_true")
    args = parser.parse_args()

    eval_root = Path(args.eval_root)
    data_root = Path(args.data_root)
    by_language = defaultdict(lambda: {"parsed": 0, "non_parsed": 0})
    by_model_language = defaultdict(lambda: {"parsed": 0, "non_parsed": 0})

    for scenario_dir in sorted(eval_root.glob("*/*/*/*")):
        if not scenario_dir.is_dir():
            continue
        model, split, cwe, scenario = scenario_dir.parts[-4:]
        if args.model and model != args.model:
            continue
        if args.split and split != args.split:
            continue

        info_path = data_root / split / cwe / scenario / "info.json"
        if not info_path.exists():
            continue
        lang = load_language(data_root, split, cwe, scenario)
        parsed = count_files(scenario_dir / "output_srcs", lang)
        non_parsed = count_files(scenario_dir / "non_parsed_srcs", lang)

        add_count(by_language, (lang,), parsed, non_parsed)
        add_count(by_model_language, (model, lang), parsed, non_parsed)

    language_rows = [
        (lang, counts["parsed"], counts["non_parsed"])
        for (lang,), counts in sorted(by_language.items())
    ]
    print_table("By language", language_rows)

    if args.by_model:
        print()
        model_rows = [
            (f"{model}/{lang}", counts["parsed"], counts["non_parsed"])
            for (model, lang), counts in sorted(by_model_language.items())
        ]
        print_table("By model/language", model_rows)


if __name__ == "__main__":
    main()
