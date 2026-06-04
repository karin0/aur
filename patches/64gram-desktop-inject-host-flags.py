#!/usr/bin/env python3
import re
import sys


def patch_cmake(path):
    with open(path, encoding='utf-8') as f:
        content = f.read()

    pattern = re.compile(
        r'(add_executable|add_library)\s*\(\s*([a-zA-Z0-9_\$\{\}-]+)', re.IGNORECASE
    )
    pos = 0
    modified = ''
    changed = False

    while True:
        match = pattern.search(content, pos)
        if not match:
            modified += content[pos:]
            break

        modified += content[pos : match.start()]
        target_name = match.group(2)

        bracket_count = 1
        i = match.end()
        while i < len(content) and bracket_count > 0:
            if content[i] == '(':
                bracket_count += 1
            elif content[i] == ')':
                bracket_count -= 1
            i += 1

        block = content[match.start() : i]
        modified += block

        if not re.search(r'\b(INTERFACE|ALIAS)\b', block, re.IGNORECASE):
            option_str = f'target_compile_options({target_name} PRIVATE "-march=x86-64" "-O2")'
            if option_str not in content:
                modified += f'\n{option_str}'
                changed = True

        pos = i

    if changed:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(modified)


if __name__ == '__main__':
    for p in sys.argv[1:]:
        patch_cmake(p)
