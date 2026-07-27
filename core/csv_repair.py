import csv
from pathlib import Path
from .smart_repair import analyze_extras

def _delim(raw,suffix):
    if suffix.lower()==".tsv": return "\t"
    try:return csv.Sniffer().sniff(raw[:16000],delimiters=",;\t|").delimiter
    except:return ","

def _quote_open(s):
    i=n=0
    while i<len(s):
        if s[i]=='"':
            if i+1<len(s) and s[i+1]=='"':i+=2;continue
            n+=1
        i+=1
    return n%2==1

def refresh_audit(audit):
    pending=unresolved_extras(audit)
    unresolved_issues=0
    for issue in audit.get("issues",[]):
        if issue.get("status")=="UNRECOVERABLE": unresolved_issues+=1
        elif issue.get("kind")=="MISSING_FIELDS" and any(c.get("state")=="MISSING" for c in issue.get("columns",[])): unresolved_issues+=1
    audit["unresolved"]=len(pending)+unresolved_issues
    audit["reviewRequired"]=sum(1 for x in audit.get("issues",[]) if x.get("status")=="REVIEW REQUIRED")
    audit["unrecoverable"]=sum(1 for x in audit.get("issues",[]) if x.get("status")=="UNRECOVERABLE")
    audit["records"]=max(0,len(audit.get("logical",[]))-1)
    return audit

def preview_rows(audit):
    header=audit.get("header",[]); issue_by_record={}
    for issue in audit.get("issues",[]):
        ri=issue.get("recordIndex",-1)
        if ri>=1: issue_by_record[ri]=issue
    rows=[]
    for logical_index,rec in enumerate(audit.get("logical",[])[1:],1):
        vals=list(rec.get("values",[]))[:len(header)]; vals += [""]*(len(header)-len(vals))
        issue=issue_by_record.get(logical_index)
        if rec.get("createdByUser"): state="NEW"
        elif issue and issue.get("status")=="AUTO FIXED": state="REPAIRED"
        elif issue and issue.get("status") in ("REVIEW REQUIRED","UNRECOVERABLE"): state="UNRESOLVED"
        elif issue and issue.get("status")=="REVIEWED": state="REPAIRED"
        else: state="UNCHANGED"
        rows.append({"row":len(rows)+1,"state":state,"values":vals})
    return rows

def inspect_csv(p):
    path=Path(p); raw=path.read_text(encoding="utf-8-sig",errors="replace"); lines=raw.splitlines(keepends=True)
    if not lines: raise ValueError("File is empty.")
    delim=_delim(raw,path.suffix); header=next(csv.reader([lines[0]],delimiter=delim)); expected=len(header)
    logical=[{"start":1,"end":1,"values":header,"raw":lines[0].rstrip()}]; issues=[]; buf=""; start=2
    for no,line in enumerate(lines[1:],2):
        if not buf:start=no
        buf+=line
        if _quote_open(buf):continue
        vals=next(csv.reader([buf],delimiter=delim)); logical.append({"start":start,"end":no,"values":vals,"raw":buf.rstrip()}); label=f"{start}-{no}" if start!=no else str(no); cols=[]
        if start!=no and len(vals)==expected:
            for i,v in enumerate(vals):cols.append({"field":header[i],"detected":v,"proposed":v,"state":"RECONSTRUCTED","reason":"Joined quoted physical lines","suggestedField":"","confidence":100,"decision":"AUTO FIXED"})
            issues.append({"recordIndex":len(logical)-1,"line":label,"status":"AUTO FIXED","decision":"Safe to auto-fix","problem":"Record split across physical lines","diagnosis":f"Physical lines {start}-{no} form one quoted record with exactly {expected} fields.","expectedColumns":expected,"actualColumns":len(vals),"difference":0,"confidence":"HIGH","original":buf.rstrip(),"proposed":delim.join(vals),"columns":cols,"kind":"PHYSICAL_LINE_SPLIT"})
        elif len(vals)>expected:
            for i,v in enumerate(vals):
                extra=i>=expected;cols.append({"field":header[i] if not extra else f"PRESERVED EXTRA {i-expected+1}","detected":v,"proposed":v if not extra else "","state":"REVIEW" if extra else "UNCHANGED","reason":"No destination selected" if extra else "Position matches header","suggestedField":"","confidence":0,"decision":"REVIEW" if extra else "UNCHANGED"})
            extra=len(vals)-expected;issues.append({"recordIndex":len(logical)-1,"line":label,"status":"REVIEW REQUIRED","decision":"Manual mapping required","problem":"Extra delimiter-separated values","diagnosis":f"Expected {expected} fields, detected {len(vals)} (+{extra}). Extra values are preserved until mapped or explicitly left unresolved.","expectedColumns":expected,"actualColumns":len(vals),"difference":extra,"confidence":"LOW","original":buf.rstrip(),"proposed":"","columns":cols,"kind":"EXTRA_FIELDS"})
        elif len(vals)<expected:
            for i in range(expected):
                present=i<len(vals);cols.append({"field":header[i],"detected":vals[i] if present else "","proposed":vals[i] if present else "","state":"UNCHANGED" if present else "MISSING","reason":"Position matches header" if present else "Expected field absent; no value invented","suggestedField":"","confidence":0,"decision":"REVIEW" if not present else "UNCHANGED"})
            missing=expected-len(vals);issues.append({"recordIndex":len(logical)-1,"line":label,"status":"REVIEW REQUIRED","decision":"Manual review required","problem":"Missing field values","diagnosis":f"Expected {expected} fields, detected {len(vals)} (-{missing}). Missing values are not fabricated.","expectedColumns":expected,"actualColumns":len(vals),"difference":-missing,"confidence":"LOW","original":buf.rstrip(),"proposed":"","columns":cols,"kind":"MISSING_FIELDS"})
        buf=""
    if buf:issues.append({"recordIndex":-1,"line":f"{start}-{len(lines)}","status":"UNRECOVERABLE","decision":"Manual recovery required","problem":"Unclosed quoted field","diagnosis":"The file ended before a quoted value was closed. No destructive repair was attempted.","expectedColumns":expected,"actualColumns":0,"difference":-expected,"confidence":"NONE","original":buf.rstrip(),"proposed":"","columns":[],"kind":"UNCLOSED_QUOTE"})
    healthy_rows=[x["values"] for x in logical[1:] if len(x["values"])==expected]
    for issue in issues:
        if issue["kind"]=="EXTRA_FIELDS":
            vals=logical[issue["recordIndex"]]["values"];suggestions=analyze_extras(header,healthy_rows,vals[expected:]);issue["suggestions"]=suggestions
            for j,sug in enumerate(suggestions):issue["columns"][expected+j].update({"suggestedField":sug["suggestedField"],"confidence":sug["confidence"],"decision":sug["decision"],"reason":sug["reason"],"candidates":sug.get("candidates",[])})
    auto=sum(x["status"]=="AUTO FIXED" for x in issues);review=sum(x["status"]=="REVIEW REQUIRED" for x in issues);bad=sum(x["status"]=="UNRECOVERABLE" for x in issues)
    audit={"file":path.name,"delimiter":delim,"header":header,"expected":expected,"records":max(0,len(logical)-1),"healthy":max(0,len(logical)-1-len(issues)),"autoFixed":auto,"reviewRequired":review,"unrecoverable":bad,"unresolved":review+bad,"logical":logical,"issues":issues}
    return refresh_audit(audit)

def apply_mapping(audit,issue_index,column_index,target_field):
    if not (0<=issue_index<len(audit["issues"])):raise ValueError("Invalid repair issue.")
    issue=audit["issues"][issue_index]
    if issue["kind"]!="EXTRA_FIELDS":raise ValueError("Only preserved extra values can be mapped.")
    if not (0<=column_index<len(issue["columns"])):raise ValueError("Invalid repair value.")
    col=issue["columns"][column_index]
    if not col["field"].startswith("PRESERVED EXTRA"):raise ValueError("Select a preserved extra value.")
    if target_field not in audit["header"]:raise ValueError("Select a valid destination column.")
    rec=audit["logical"][issue["recordIndex"]];target=audit["header"].index(target_field);detected=col["detected"]
    current=rec["values"][target] if target<len(rec["values"]) else ""
    if str(current).strip():raise ValueError(f"{target_field} already contains '{current}'. Clear/review it before mapping another value.")
    while len(rec["values"])<audit["expected"]:rec["values"].append("")
    rec["values"][target]=detected;col["proposed"]=detected;col["state"]="USER APPROVED";col["reason"]=f"Mapped to {target_field} by user";col["mappedTo"]=target_field
    if not unresolved_extras_for_issue(issue):issue["status"]="REVIEWED";issue["decision"]="Reviewed mapping complete"
    return refresh_audit(audit)

def unresolved_extras_for_issue(issue):return [c for c in issue.get("columns",[]) if c.get("field","").startswith("PRESERVED EXTRA") and c.get("state") not in ("USER APPROVED","NEW RECORD")]
def keep_unresolved(audit,issue_index,column_index):
    col=audit["issues"][issue_index]["columns"][column_index];col["state"]="UNRESOLVED";col["decision"]="UNRESOLVED";col["reason"]="User chose to keep this value unresolved";return refresh_audit(audit)
def unresolved_extras(audit):
    pending=[]
    for i,issue in enumerate(audit.get("issues",[])):
        if issue.get("kind")=="EXTRA_FIELDS":
            for j,col in enumerate(issue.get("columns",[])):
                if col.get("field","").startswith("PRESERVED EXTRA") and col.get("state") not in ("USER APPROVED","NEW RECORD"):pending.append((i,j,col.get("detected","")))
    return pending

def save_repaired(audit,dst):
    refresh_audit(audit)
    if audit["unresolved"]:raise ValueError(f"{audit['unresolved']} unresolved repair item(s) remain.")
    with open(dst,"w",newline="",encoding="utf-8-sig") as f:
        w=csv.writer(f,delimiter=audit["delimiter"])
        for rec in audit["logical"]:w.writerow(list(rec["values"])[:audit["expected"]])
    return True

def keep_issue_as_is(audit,issue_index):
    issue=audit["issues"][issue_index]
    if issue["kind"]!="EXTRA_FIELDS":raise ValueError("This action is only available for records with extra values.")
    for col in issue["columns"]:
        if col["field"].startswith("PRESERVED EXTRA"):col["state"]="UNRESOLVED";col["decision"]="UNRESOLVED";col["reason"]="Whole record explicitly kept as-is by user"
    issue["decision"]="Keep original / unresolved";return refresh_audit(audit)

def create_record_from_extras(audit,issue_index,mapping):
    issue=audit["issues"][issue_index]
    if issue["kind"]!="EXTRA_FIELDS":raise ValueError("Select a record with preserved extra values.")
    new=[""]*audit["expected"];used=set();mapping=dict(mapping or {});explicit=mapping.pop("__values__",{})
    for field,value in explicit.items():
        if field in audit["header"] and str(value).strip():ti=audit["header"].index(field);new[ti]=str(value);used.add(ti)
    for col_index,target in mapping.items():
        ci=int(col_index)
        if not (0<=ci<len(issue["columns"])):continue
        col=issue["columns"][ci]
        if not col["field"].startswith("PRESERVED EXTRA") or target not in audit["header"]:continue
        ti=audit["header"].index(target)
        if ti in used:raise ValueError(f"More than one value was assigned to {target}.")
        new[ti]=col["detected"];used.add(ti);col["state"]="NEW RECORD";col["mappedTo"]=target;col["reason"]=f"User assigned value to {target} in a new record"
    if not used:raise ValueError("Map at least one preserved value before creating a new record.")
    if "SID" in audit["header"] and not str(new[audit["header"].index("SID")]).strip():raise ValueError("SID is required for a new record. Enter an SID before creating the candidate.")
    audit["logical"].append({"start":0,"end":0,"values":new,"raw":"","createdByUser":True});issue["decision"]="New record created from reviewed values";issue["status"]="REVIEWED"
    return refresh_audit(audit)
