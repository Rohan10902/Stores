import os
import subprocess
import sys
import time
from pathlib import Path

APP_NAME="StoreLens"; MAX_ATTEMPTS=3; STARTUP_SECONDS=15

def app_dir(): return Path(sys.executable).resolve().parent if getattr(sys,"frozen",False) else Path(__file__).resolve().parent
def data_dir():
    root=Path(os.getenv("LOCALAPPDATA",str(Path.home())))/APP_NAME; (root/"logs").mkdir(parents=True,exist_ok=True); return root
def log(message):
    with (data_dir()/"logs"/"StoreLensLauncher.log").open("a",encoding="utf-8") as f:f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {message}\n")
def target_command():
    if getattr(sys,"frozen",False):
        exe=app_dir()/"StoreLensCore.exe"
        if not exe.exists():raise FileNotFoundError(f"Required application file is missing: {exe}")
        return [str(exe)]
    return [sys.executable,str(app_dir()/"app.py")]
def clean_safe_state():
    # Only disposable StoreLens startup state is touched. User files/exports are never modified.
    for name in ("startup.pending",):
        p=data_dir()/name
        try:
            if p.exists():p.unlink()
        except OSError as exc:log(f"Could not clear {p.name}: {exc}")
def has_visible_window(pid):
    if os.name!="nt":return False
    try:
        import ctypes
        from ctypes import wintypes
        found=[]; user32=ctypes.windll.user32
        @ctypes.WINFUNCTYPE(ctypes.c_bool,wintypes.HWND,wintypes.LPARAM)
        def cb(hwnd,lparam):
            proc_id=wintypes.DWORD();user32.GetWindowThreadProcessId(hwnd,ctypes.byref(proc_id))
            if proc_id.value==pid and user32.IsWindowVisible(hwnd):
                length=user32.GetWindowTextLengthW(hwnd)
                if length>0:found.append(hwnd);return False
            return True
        user32.EnumWindows(cb,0);return bool(found)
    except Exception as exc:log(f"Window confirmation error: {exc}");return False
def launch_once(attempt):
    env=os.environ.copy();env["STORELENS_LAUNCH_ATTEMPT"]=str(attempt)
    if attempt>=2:
        env["STORELENS_SAFE_START"]="1";env.setdefault("QT_QUICK_BACKEND","software")
    proc=subprocess.Popen(target_command(),env=env,cwd=str(app_dir()));deadline=time.time()+STARTUP_SECONDS
    while time.time()<deadline:
        code=proc.poll()
        if code is not None:log(f"Attempt {attempt}: application exited during startup, code={code}.");return False,proc
        # In normal Windows use, a visible top-level window is the startup success signal.
        if has_visible_window(proc.pid):log(f"Attempt {attempt}: visible application window confirmed (pid {proc.pid}).");return True,proc
        # CI/offscreen mode cannot create a visible desktop window. Surviving the explicit smoke interval is its signal.
        if os.getenv("STORELENS_CI_STARTUP_TEST")=="1" and time.time()>=deadline-3:
            log(f"Attempt {attempt}: CI startup survival confirmed (pid {proc.pid}).");return True,proc
        time.sleep(.25)
    log(f"Attempt {attempt}: no usable application window appeared within {STARTUP_SECONDS}s.")
    try:proc.terminate();proc.wait(timeout=3)
    except Exception:
        try:proc.kill()
        except Exception:pass
    return False,proc
def show_failure(message):
    log(message)
    if os.name=="nt":
        try:
            import ctypes;ctypes.windll.user32.MessageBoxW(0,message+f"\n\nDiagnostic log:\n{data_dir()/'logs'/'StoreLensLauncher.log'}","StoreLens Recovery",0x10);return
        except Exception:pass
    print(message,file=sys.stderr)
def main():
    log("Launcher started.")
    try:target_command()
    except Exception as exc:show_failure(str(exc));return 2
    for attempt in range(1,MAX_ATTEMPTS+1):
        if attempt>1:clean_safe_state()
        ok,_=launch_once(attempt)
        if ok:return 0
        time.sleep(1)
    show_failure("StoreLens could not open after 3 controlled recovery attempts. No user data was changed. See the diagnostic log for the underlying failure.");return 1
if __name__=="__main__":raise SystemExit(main())
