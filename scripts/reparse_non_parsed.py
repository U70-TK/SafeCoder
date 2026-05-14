import argparse
import json
import os
import re
import shutil
from pathlib import Path

from safecoder.utils import try_parse


EXTENSIONS = {
    "c": "c",
    "go": "go",
    "java": "java",
    "js": "js",
    "jsx": "jsx",
    "py": "py",
    "rb": "rb",
}


def next_index(output_srcs: Path, lang: str) -> int:
    prefix = "MyTestClass" if lang == "java" else ""
    pattern = re.compile(rf"^{prefix}(\d+)\.{re.escape(EXTENSIONS[lang])}$")
    indexes = []
    for path in output_srcs.glob(f"*.{EXTENSIONS[lang]}"):
        match = pattern.match(path.name)
        if match:
            indexes.append(int(match.group(1)))
    return max(indexes, default=-1) + 1


def target_for(output_srcs: Path, lang: str, index: int) -> Path:
    if lang == "java":
        return output_srcs / f"MyTestClass{index:02d}.java"
    return output_srcs / f"{index:02d}.{EXTENSIONS[lang]}"


def rewrite_java_class(src: str, index: int) -> str:
    return re.sub(r"public class MyTestClass\d*", f"public class MyTestClass{index:02d}", src, count=1)


def normalize_java_class(src: str) -> str:
    return re.sub(r"public class MyTestClass\d*", "public class MyTestClass", src, count=1)


def load_info(data_root: Path, split: str, cwe: str, scenario: str) -> dict:
    with open(data_root / split / cwe / scenario / "info.json") as f:
        return json.load(f)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--eval-root", default="../experiments/sec_eval")
    parser.add_argument("--data-root", default="../data_eval/sec_eval")
    parser.add_argument("--model", default=None)
    parser.add_argument("--split", choices=["trained", "trained-new", "not-trained"], default=None)
    parser.add_argument("--languages", nargs="+", default=["go", "java", "js", "jsx", "rb"])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    eval_root = Path(args.eval_root)
    data_root = Path(args.data_root)
    moved = 0
    checked = 0

    for non_parsed_dir in sorted(eval_root.glob("*/*/*/*/non_parsed_srcs")):
        model, split, cwe, scenario = non_parsed_dir.parts[-5:-1]
        if args.model and model != args.model:
            continue
        if args.split and split != args.split:
            continue

        info = load_info(data_root, split, cwe, scenario)
        lang = info["language"]
        if lang not in args.languages:
            continue
        output_srcs = non_parsed_dir.parent / "output_srcs"
        output_srcs.mkdir(exist_ok=True)
        index = next_index(output_srcs, lang)

        for src_path in sorted(non_parsed_dir.glob(f"*.{EXTENSIONS[lang]}")):
            checked += 1
            src = src_path.read_text()
            parse_src = normalize_java_class(src) if lang == "java" else src
            if try_parse(parse_src, info) != 0:
                continue

            dst = target_for(output_srcs, lang, index)
            if lang == "java":
                src = rewrite_java_class(src, index)
                if not args.dry_run:
                    dst.write_text(src)
                    src_path.unlink()
            elif not args.dry_run:
                shutil.move(str(src_path), dst)
            moved += 1
            print(f"{'would move' if args.dry_run else 'moved'} {src_path} -> {dst}")
            index += 1

    print(f"checked={checked} reparsed={moved}")


if __name__ == "__main__":
    main()
