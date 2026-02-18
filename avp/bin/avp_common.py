#!/opt/bin/python3
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-COMMON
# File      : avp_common.py
# Role      : Shared helpers (paths/run/log/json) for V2 python tools
# Version   : v1.0.0 (2026-02-18)
# Status    : stable
# =============================================================

SCRIPT_VER="v1.0.0"

import datetime as _dt
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

RC_OK = 0
RC_FAIL = 1
RC_USAGE = 2

def ts() -> str:
    return _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def eprint(msg: str) -> None:
    print(msg, file=sys.stderr)

def info(tag: str, msg: str) -> None:
    eprint(f"{ts()} [{tag}] {msg}")

def err(tag: str, msg: str) -> None:
    eprint(f"{ts()} [{tag}] ERR: {msg}")

def want_json() -> bool:
    v = (os.environ.get("AVP_JSON") or "").strip().lower()
    return v in ("1", "true", "yes", "on")

def jprint(obj: Any) -> None:
    print(json.dumps(obj, ensure_ascii=False, separators=(",", ":")))

def self_paths(from_file: Optional[str] = None) -> Tuple[Path, Path, Path]:
    """
    Returns: (REPO_ROOT, AVP_ROOT, BIN_DIR)
    Assumes python tools live in: <REPO_ROOT>/avp/bin/
    """
    if from_file:
        p = Path(from_file).resolve()
    else:
        p = Path(__file__).resolve()
    bin_dir = p.parent
    avp_root = bin_dir.parent
    repo_root = avp_root.parent
    return repo_root, avp_root, bin_dir

def run(cmd: List[str], *, cwd: Optional[Path] = None, check: bool = False, capture: bool = True) -> Tuple[int, str]:
    try:
        r = subprocess.run(
            cmd,
            cwd=str(cwd) if cwd else None,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.STDOUT if capture else None,
            text=True,
        )
        out = (r.stdout or "") if capture else ""
        if check and r.returncode != 0:
            return r.returncode, out
        return r.returncode, out
    except FileNotFoundError:
        return 127, f"cmd not found: {cmd[0]}"
    except Exception as ex:
        return 126, f"run exception: {ex}"

def git(args: List[str], *, repo_root: Path, check: bool = False, capture: bool = True) -> Tuple[int, str]:
    return run(["git"] + args, cwd=repo_root, check=check, capture=capture)

def git_lines(args: List[str], *, repo_root: Path) -> List[str]:
    rc, out = git(args, repo_root=repo_root, check=False, capture=True)
    if rc != 0:
        return []
    return [ln.strip() for ln in (out or "").splitlines() if ln.strip()]

def find_changed_files(repo_root: Path) -> List[str]:
    staged = git_lines(["diff", "--name-only", "--cached"], repo_root=repo_root)
    if staged:
        return staged
    unstaged = git_lines(["diff", "--name-only"], repo_root=repo_root)
    return unstaged
