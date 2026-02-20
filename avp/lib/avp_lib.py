#!/opt/bin/python3
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-LIB
# File      : avp_lib.py
# Role      : Common library (Flash-Safe v1 logs/state + helpers)
# Version   : v2.0.0 (2026-02-20)
# Status    : stable
# =============================================================
from __future__ import annotations
SCRIPT_VER = "v2.0.0"

"""AutoVPN Platform (AVP) common library (Python port).

Este módulo implementa em Python as funções utilitárias presentes no
script shell `avp/lib/avp-lib.sh`, incluindo rotinas de logging JSON
(rotações classe A/B), leitura e escrita de estado (atomizadas) e
log_action para o policy.  Variáveis de ambiente permitem ajustar
caminhos de logs e state; diretórios são criados sob demanda.
"""


import json
import os
import time
from pathlib import Path
from typing import Optional, Tuple

__all__ = [
    "avp_now",
    "avp_epoch",
    "log_event",
    "log_error",
    "log_debug",
    "state_get",
    "state_set",
    "state_write_file",
    "log_action",
]

# ---------------------------------------------------------------------------
# Utility functions

def avp_now() -> str:
    """Return current local time as YYYY-MM-DD HH:MM:SS."""
    return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())

def avp_epoch() -> int:
    """Return current UNIX epoch seconds."""
    return int(time.time())

# ---------------------------------------------------------------------------
# Path resolution

def _resolve_paths() -> Tuple[Path, Path, Path, Path, Path, Path, Path]:
    """Resolve log and state paths from environment or defaults."""
    flash_dir = Path(os.environ.get("AVP_FLASH_LOGDIR", "/jffs/scripts/logs"))
    tmp_dir = Path(os.environ.get("AVP_TMP_LOGDIR", "/tmp/avp_logs"))
    state_dir = Path(os.environ.get("AVP_STATEDIR", "/jffs/scripts/avp/state"))
    state_file = Path(os.environ.get("AVP_STATE_FILE", str(state_dir / "avp.state")))
    event_log = Path(os.environ.get("AVP_EVENT_LOG", str(flash_dir / "avp_events.log")))
    error_log = Path(os.environ.get("AVP_ERROR_LOG", str(flash_dir / "avp_errors.log")))
    debug_log = Path(os.environ.get("AVP_DEBUG_LOG", str(tmp_dir / "avp_debug.log")))
    return flash_dir, tmp_dir, state_dir, state_file, event_log, error_log, debug_log

def _ensure_dirs() -> None:
    """Ensure that the flash, tmp and state directories exist."""
    flash_dir, tmp_dir, state_dir, _, _, _, _ = _resolve_paths()
    for d in (flash_dir, tmp_dir, state_dir):
        try:
            d.mkdir(parents=True, exist_ok=True)
        except OSError:
            pass

def _rotate_if_big(path: Path, max_kb: int = 256) -> None:
    """Rotate a log file if its size exceeds max_kb KiB."""
    try:
        if path.exists() and path.stat().st_size >= max_kb * 1024:
            path.rename(path.with_suffix(path.suffix + ".1"))
    except OSError:
        pass

def _write_json_line(log_file: Path, lvl: str, comp: str, rc: int, msg: str, meta: str) -> None:
    """Write a JSON log record to log_file with rotation fallback."""
    _ensure_dirs()
    _rotate_if_big(log_file)
    record = {
        "ts": avp_now(),
        "lvl": lvl,
        "comp": comp,
        "rc": rc,
        "msg": msg,
        "meta": meta,
    }
    line = json.dumps(record, ensure_ascii=False)
    try:
        with log_file.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        # fallback to /tmp
        try:
            fallback = Path("/tmp") / log_file.name
            with fallback.open("a", encoding="utf-8") as f:
                f.write(line + "\n")
        except OSError:
            pass

# ---------------------------------------------------------------------------
# Logging functions

def log_event(comp: str, msg: str, rc: int = 0, meta: str = "") -> None:
    """Log an event to the flash event log."""
    _, _, _, _, event_log, _, _ = _resolve_paths()
    _write_json_line(event_log, "EVENT", comp, rc, msg, meta)

def log_error(comp: str, msg: str, rc: int = 1, meta: str = "") -> None:
    """Log an error to the flash error log."""
    _, _, _, _, _, error_log, _ = _resolve_paths()
    _write_json_line(error_log, "ERROR", comp, rc, msg, meta)

def log_debug(comp: str, msg: str, meta: str = "") -> None:
    """Log a debug message to the tmp debug log."""
    _, _, _, _, _, _, debug_log = _resolve_paths()
    _write_json_line(debug_log, "DEBUG", comp, 0, msg, meta)

# ---------------------------------------------------------------------------
# State management

def state_get(key: str) -> Optional[str]:
    """Return the value for key from the state file, or None."""
    _, _, _, state_file, _, _, _ = _resolve_paths()
    try:
        with state_file.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                if k == key:
                    return v
    except FileNotFoundError:
        return None
    except OSError:
        return None
    return None

def state_write_file(dest: str, payload: str) -> bool:
    """Atomically write payload to dest with mode 0600."""
    dest_path = Path(dest)
    dir_path = dest_path.parent
    try:
        dir_path.mkdir(parents=True, exist_ok=True)
    except OSError:
        pass
    tmp = dest_path.with_suffix(dest_path.suffix + f".tmp.{os.getpid()}")
    try:
        with tmp.open("w", encoding="utf-8") as f:
            f.write(payload)
        tmp.rename(dest_path)
        dest_path.chmod(0o600)
        return True
    except OSError:
        try:
            tmp.unlink()
        except Exception:
            pass
        return False

def state_set(key: str, value: str, minimum_interval: int = 60) -> bool:
    """Set key=value in the state file; rate limited to minimum_interval seconds."""
    _, _, _, state_file, _, _, _ = _resolve_paths()
    _ensure_dirs()
    current = state_get(key)
    if current is not None and current == value:
        return False
    now = avp_epoch()
    lwf_path = Path("/tmp/avp_state.lastwrite")
    last = 0
    try:
        if lwf_path.is_file():
            with lwf_path.open("r", encoding="utf-8") as f:
                last = int(f.read().strip() or "0")
    except Exception:
        last = 0
    if now - last < minimum_interval:
        return False
    # build new state payload
    entries = {}
    if state_file.exists():
        try:
            with state_file.open("r", encoding="utf-8") as f:
                for line in f:
                    line = line.rstrip("\n")
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    k, v = line.split("=", 1)
                    entries[k] = v
        except Exception:
            pass
    entries[key] = value
    payload = "\n".join(f"{k}={v}" for k, v in entries.items()) + "\n"
    if not state_write_file(str(state_file), payload):
        return False
    try:
        with lwf_path.open("w", encoding="utf-8") as f:
            f.write(str(now))
    except Exception:
        pass
    return True

# ---------------------------------------------------------------------------
# Policy action logging

def log_action(action: str, *args: str) -> None:
    """Log a policy action with optional rc and key-value pairs."""
    rc = 0
    meta_parts = []
    for kv in args:
        if kv.startswith("rc="):
            try:
                rc = int(kv.split("=", 1)[1])
            except ValueError:
                rc = 0
        meta_parts.append(kv)
    meta = " ".join(meta_parts)
    log_event("POL", f"action={action}", rc=rc, meta=meta)
