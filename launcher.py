import os
import subprocess
import sys
import time
from pathlib import Path

APP_NAME = "StoreLens"
MAX_ATTEMPTS = 3
STARTUP_SECONDS = 12


def app_dir():
    return Path(sys.executable).resolve().parent if getattr(sys, "frozen", False) else Path(__file__).resolve().parent


def data_dir():
    root = Path(os.getenv("LOCALAPPDATA", str(Path.home()))) / APP_NAME
    (root / "logs").mkdir(parents=True, exist_ok=True)
    return root


def log(message):
    stamp = time.strftime("%Y-%m-%d %H:%M:%S")
    with (data_dir() / "logs" / "StoreLensLauncher.log").open("a", encoding="utf-8") as f:
        f.write(f"{stamp} {message}\n")


def target_command():
    if getattr(sys, "frozen", False):
        exe = app_dir() / "StoreLens.exe"
        if not exe.exists():
            raise FileNotFoundError(f"Required application file is missing: {exe}")
        return [str(exe)]
    return [sys.executable, str(app_dir() / "app.py")]


def clean_safe_state():
    # Only StoreLens-owned disposable startup state is touched. User datasets and exports are never modified.
    for name in ("startup.ok", "startup.pending"):
        p = data_dir() / name
        try:
            if p.exists(): p.unlink()
        except OSError as exc:
            log(f"Could not clear {p.name}: {exc}")


def launch_once(attempt):
    env = os.environ.copy()
    env["STORELENS_LAUNCH_ATTEMPT"] = str(attempt)
    if attempt >= 2:
        env["STORELENS_SAFE_START"] = "1"
        env.setdefault("QT_QUICK_BACKEND", "software")
    marker = data_dir() / "startup.ok"
    try:
        if marker.exists(): marker.unlink()
    except OSError: pass
    proc = subprocess.Popen(target_command(), env=env, cwd=str(app_dir()))
    deadline = time.time() + STARTUP_SECONDS
    while time.time() < deadline:
        if marker.exists():
            log(f"Attempt {attempt}: startup confirmed by application (pid {proc.pid}).")
            return True, proc
        code = proc.poll()
        if code is not None:
            log(f"Attempt {attempt}: application exited before confirmation, code={code}.")
            return False, proc
        time.sleep(0.25)
    if proc.poll() is None:
        # A responsive process that has not written the marker is not treated as proven success.
        log(f"Attempt {attempt}: process remained alive but startup confirmation was not received.")
        try: proc.terminate(); proc.wait(timeout=3)
        except Exception:
            try: proc.kill()
            except Exception: pass
    return False, proc


def show_failure(message):
    log(message)
    if os.name == "nt":
        try:
            import ctypes
            ctypes.windll.user32.MessageBoxW(0, message + f"\n\nDiagnostic log:\n{data_dir() / 'logs' / 'StoreLensLauncher.log'}", "StoreLens Recovery", 0x10)
            return
        except Exception: pass
    print(message, file=sys.stderr)


def main():
    log("Launcher started.")
    try:
        target_command()
    except Exception as exc:
        show_failure(str(exc)); return 2
    for attempt in range(1, MAX_ATTEMPTS + 1):
        if attempt > 1: clean_safe_state()
        ok, _ = launch_once(attempt)
        if ok: return 0
        time.sleep(1)
    show_failure("StoreLens could not complete startup after 3 controlled recovery attempts. No user data was changed. Please use the diagnostic log for the underlying failure.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
