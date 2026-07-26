import re
from collections import Counter

BOOL_WORDS = {"yes","no","y","n","true","false","1","0","active","inactive"}
NULL_WORDS = {"", "null", "none", "na", "n/a", "nan"}

def norm(v):
    return re.sub(r"\s+", " ", str(v or "").strip()).lower()

def looks_zip(v):
    return bool(re.fullmatch(r"\d{5,6}", re.sub(r"[\s-]", "", str(v or "").strip())))

def looks_sid(v):
    return bool(re.fullmatch(r"(?i)SID[\s_-]*\d+", str(v or "").strip()))

def looks_date(v):
    s = str(v or "").strip()
    return bool(
        re.fullmatch(r"\d{4}[-/]\d{1,2}[-/]\d{1,2}", s)
        or re.fullmatch(r"\d{1,2}[-/]\d{1,2}[-/]\d{2,4}", s)
    )

def value_type(v):
    s = norm(v)
    if s in NULL_WORDS: return "blank"
    if looks_sid(v): return "sid"
    if looks_zip(v): return "zip"
    if looks_date(v): return "date"
    if s in BOOL_WORDS: return "boolean"
    try:
        float(str(v).replace(",", ""))
        return "numeric"
    except Exception:
        return "text"

def header_hints(header):
    h = norm(header)
    hints = set()
    if h == "sid" or h.endswith(" sid"): hints.add("sid")
    if any(x in h for x in ("zip", "postal", "postcode", "pin code", "pincode")): hints.add("zip")
    if any(x in h for x in ("date", "trip", "updated", "created")): hints.add("date")
    if h.startswith("is ") or h.startswith("has ") or h in {"active / inactive","active","inactive"}:
        hints.add("boolean")
    if any(x in h for x in ("amount","units","count","total","qty","quantity","price","value")):
        hints.add("numeric")
    return hints

def profiles(header, rows):
    result = {}
    for i, field in enumerate(header):
        vals = [r[i] for r in rows if i < len(r) and norm(r[i]) not in NULL_WORDS]
        types = Counter(value_type(v) for v in vals)
        values = Counter(norm(v) for v in vals)
        result[field] = {
            "types": types,
            "values": values,
            "count": len(vals),
            "unique": len(values),
            "hints": header_hints(field),
        }
    return result

def score_candidate(value, field, profile, learned_weight=0):
    t = value_type(value)
    score = 0
    reasons = []

    if t in profile["hints"]:
        score += 55
        reasons.append(f"header semantics match {t}")

    total = sum(profile["types"].values())
    if total:
        ratio = profile["types"].get(t, 0) / total
        if ratio >= .95:
            score += 25
            reasons.append(f"{round(ratio*100)}% of existing values share this type")
        elif ratio >= .75:
            score += 15
            reasons.append("type matches most existing values")
        elif ratio >= .50:
            score += 7
            reasons.append("type matches many existing values")

    nv = norm(value)
    if nv in profile["values"]:
        score += 20
        reasons.append("value already occurs in this column")

    if t == "zip" and "zip" in profile["hints"]:
        score += 15
        reasons.append("postal/ZIP pattern match")
    if t == "sid" and "sid" in profile["hints"]:
        score += 20
        reasons.append("SID pattern match")
    if t == "date" and "date" in profile["hints"]:
        score += 10
        reasons.append("date pattern match")

    if learned_weight:
        bonus = min(20, 5 + learned_weight * 3)
        score += bonus
        reasons.append("supported by previously approved local mapping")

    return min(score, 100), reasons

def rank_candidates(value, header, healthy_rows, occupied=None, learned=None):
    occupied = set(occupied or [])
    learned = learned or {}
    ps = profiles(header, healthy_rows)
    ranked = []

    for field in header:
        if field in occupied:
            continue
        weight = int(learned.get(field, 0))
        score, reasons = score_candidate(value, field, ps[field], weight)
        ranked.append({
            "field": field,
            "score": score,
            "reasons": reasons,
            "fieldType": max(ps[field]["types"], key=ps[field]["types"].get)
                         if ps[field]["types"] else "unknown",
        })

    ranked.sort(key=lambda x: x["score"], reverse=True)
    return ranked

def suggest_mapping(value, header, healthy_rows, occupied=None, learned=None):
    ranked = rank_candidates(value, header, healthy_rows, occupied, learned)
    if not ranked:
        return {
            "value": str(value), "suggestedField": "", "confidence": 0,
            "decision": "UNRESOLVED", "requiresPrompt": False,
            "reason": "No destination columns are available.", "candidates": []
        }

    best = ranked[0]
    second = ranked[1]["score"] if len(ranked) > 1 else 0
    confidence = best["score"]
    gap = confidence - second
    t = value_type(value)

    # Boolean/categorical ambiguity is deliberately conservative.
    plausible = [x for x in ranked if x["score"] >= 55]
    ambiguous = len(plausible) > 1 and gap < 20

    if ambiguous:
        decision = "REVIEW"
        requires_prompt = True
        reason = "Multiple columns are plausible; user confirmation is required."
    elif confidence >= 95:
        decision = "AUTO-FIX CANDIDATE"
        requires_prompt = False
        reason = "; ".join(best["reasons"]) or "Strong profile match."
    elif confidence >= 70:
        decision = "REVIEW"
        requires_prompt = True
        reason = "; ".join(best["reasons"]) or "Mapping requires confirmation."
    else:
        decision = "UNRESOLVED"
        requires_prompt = bool(plausible)
        reason = "; ".join(best["reasons"]) or "Insufficient evidence."

    # A Boolean value never gets silently assigned when two Boolean-like
    # destinations are plausible.
    if t == "boolean" and len(plausible) > 1:
        decision = "REVIEW"
        requires_prompt = True
        reason = "Boolean value matches multiple columns; choose the intended destination."

    return {
        "value": str(value),
        "valueType": t,
        "suggestedField": best["field"],
        "confidence": confidence,
        "decision": decision,
        "requiresPrompt": requires_prompt,
        "reason": reason,
        "candidates": ranked[:5],
    }

def analyze_extras(header, healthy_rows, extras, learned_lookup=None):
    output = []
    for value in extras:
        learned = learned_lookup(value) if learned_lookup else {}
        output.append(suggest_mapping(value, header, healthy_rows, learned=learned))
    return output
