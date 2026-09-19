#!/usr/bin/env python3
"""Confere se as fachadas tipadas em src/**/Lib/*.luau apontam para as versões de wally.lock.

As fachadas fixam o caminho do índice do Wally (Packages/_Index/<escopo>_<nome>@<versão>) porque
o arquivo de ligação gerado pelo Wally esconde os tipos do analisador. Este script evita que uma
atualização de dependência deixe a fachada apontando para uma versão que não existe mais.

Uso: python3 tools/check_package_facades.py   (sai com 1 quando algo diverge)
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCK = os.path.join(ROOT, "wally.lock")
FACADE_DIRS = [os.path.join(ROOT, "src", "shared", "Lib"), os.path.join(ROOT, "src", "server", "Lib")]
PATTERN = re.compile(r'_Index\["([a-z0-9\-]+)_([a-z0-9\-]+)@([0-9]+\.[0-9]+\.[0-9]+[^"]*)"\]')


def locked_versions():
    versions = {}
    name = None
    with open(LOCK, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line.startswith("name = "):
                name = line.split('"')[1]
            elif line.startswith("version = ") and name:
                versions[name.lower()] = line.split('"')[1]
                name = None
    return versions


def main():
    versions = locked_versions()
    problems = []
    checked = 0
    for directory in FACADE_DIRS:
        if not os.path.isdir(directory):
            continue
        for entry in sorted(os.listdir(directory)):
            if not entry.endswith(".luau"):
                continue
            path = os.path.join(directory, entry)
            source = open(path, encoding="utf-8").read()
            for scope, name, version in PATTERN.findall(source):
                checked += 1
                key = f"{scope}/{name}"
                locked = versions.get(key)
                if locked is None:
                    problems.append(f"{entry}: {key} não está em wally.lock")
                elif locked != version:
                    problems.append(f"{entry}: {key}@{version} != wally.lock ({locked})")
    for problem in problems:
        print("ERRO:", problem)
    if problems:
        return 1
    print(f"fachadas conferidas: {checked} referência(s) alinhada(s) com wally.lock")
    return 0


if __name__ == "__main__":
    sys.exit(main())
