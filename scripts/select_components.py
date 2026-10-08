#!/usr/bin/env python3
"""Menu para escolher os componentes de um ambiente.

Lê ansible/components/catalog.yml e grava environments/<env>/group_vars/all/components.yml.
Usa whiptail quando disponível; senão pergunta um a um no terminal.
"""
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    if len(sys.argv) != 2:
        print("uso: select_components.py <ambiente>", file=sys.stderr)
        return 2
    env = sys.argv[1]
    target = ROOT / "environments" / env / "group_vars" / "all" / "components.yml"
    catalog = yaml.safe_load((ROOT / "ansible/components/catalog.yml").read_text(encoding="utf-8"))["catalog"]
    current = {}
    if target.exists():
        current = (yaml.safe_load(target.read_text(encoding="utf-8")) or {}).get("components", {})

    if shutil.which("whiptail") and sys.stdin.isatty():
        chosen = ask_whiptail(env, catalog, current)
    else:
        chosen = ask_text(env, catalog, current)
    if chosen is None:
        print("Cancelado.")
        return 1

    lines = [
        "---",
        f"# Componentes ligados neste ambiente. Edite ou rode: make select ENV={env}",
        "# Dependências (ver ansible/components/catalog.yml) são adicionadas automaticamente.",
        "components:",
    ]
    lines += [f"  {c['name']}: {'true' if c['name'] in chosen else 'false'}" for c in catalog]
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Gravado em {target.relative_to(ROOT)}")
    print("Ligados:", ", ".join(c["name"] for c in catalog if c["name"] in chosen) or "(nenhum)")
    return 0


def ask_whiptail(env, catalog, current):
    items = []
    for c in catalog:
        items += [c["name"], c["description"], "ON" if current.get(c["name"]) else "OFF"]
    proc = subprocess.run(
        ["whiptail", "--title", f"Componentes ({env})", "--checklist",
         "Espaço marca/desmarca, Enter confirma", "22", "100", str(len(catalog))] + items,
        stderr=subprocess.PIPE, text=True,
    )
    if proc.returncode != 0:
        return None
    return set(proc.stderr.replace('"', "").split())


def ask_text(env, catalog, current):
    print(f"Componentes do ambiente '{env}' (Enter mantém o valor atual):")
    chosen = set()
    for c in catalog:
        default = bool(current.get(c["name"]))
        try:
            answer = input(f"  {c['name']:<22} {c['description']} [{'S/n' if default else 's/N'}]: ").strip().lower()
        except EOFError:
            return None
        if (answer in ("s", "y", "sim")) or (answer == "" and default):
            chosen.add(c["name"])
    return chosen


if __name__ == "__main__":
    sys.exit(main())
