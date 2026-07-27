import json
import os
from pathlib import Path

class MappingStore:
    def __init__(self, path=None):
        default_root = Path(os.getenv("LOCALAPPDATA", str(Path.home()))) / "StoreLens"
        self.path = Path(path) if path else default_root / "approved_mappings.json"
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.data = self._load()

    def _load(self):
        try:
            data=json.loads(self.path.read_text(encoding="utf-8"))
            if not isinstance(data,dict) or not isinstance(data.get("mappings",{}),dict):
                raise ValueError("Invalid mapping store")
            data.setdefault("version",1);data.setdefault("mappings",{})
            return data
        except Exception:
            return {"version": 1, "mappings": {}}

    @staticmethod
    def signature(value):
        s = str(value or "").strip().lower()
        if s in {"yes","no","true","false","y","n","1","0","active","inactive"}:
            return "boolean:" + s
        if s.isdigit() and len(s) in (5,6):
            return "zip-like"
        return "literal:" + s

    def remember(self, value, target):
        key = self.signature(value)
        row = self.data["mappings"].setdefault(key, {})
        row[target] = int(row.get(target, 0)) + 1
        tmp=self.path.with_suffix(self.path.suffix+".tmp")
        tmp.write_text(json.dumps(self.data, indent=2), encoding="utf-8")
        tmp.replace(self.path)

    def suggestions(self, value):
        row = self.data.get("mappings", {}).get(self.signature(value), {})
        return dict(row)
