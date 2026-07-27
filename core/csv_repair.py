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

def inspect_csv(p):
    path=Path(p); raw=path.read_text(encoding="utf-8-sig",errors="replace")
    lines=raw.splitlines(keepends=True)
    if not lines: raise ValueError("File is empty.")
    delim=_delim(raw,path.suffix)
    header=next(csv.reader([lines[0]],delimiter=delim))
    expected=len(header); logical=[{"start":1,"end":1,"values":header,"raw":lines[0].rstrip()}]
    issues=[]; buf=""; start=2
    for no,line in enumerate(lines[1:],2):
        if not buf:start=no
        buf+=line
        if _quote_open(buf):continue
        vals=next(csv.reader([buf],delimiter=delim))
        logical.append({"start":start,"end":no,"values":vals,"raw":buf.rstrip()})
        label=f"{start}-{no}" if start!=no else str(no)
        cols=[]
        if start!=no and len(vals)==expected:
            for i,v in enumerate(vals):cols.append({"field":header[i],"detected":v,"proposed":v,"state":"RECONSTRUCTED","reason":"Joined quoted physical lines","suggestedField":"","confidence":100,"decision":"AUTO FIXED"})
            issues.append({"recordIndex":len(logical)-1,"line":label,"status":"AUTO FIXED","decision":"Safe to auto-fix","problem":"Record split across physical lines","diagnosis":f"Physical lines {start}-{no} form one quoted record with exactly {expected} fields.","expectedColumns":expected,"actualColumns":len(vals),"difference":0,"confidence":"HIGH","original":buf.rstrip(),"proposed":delim.join(vals),"columns":cols,"kind":"PHYSICAL_LINE_SPLIT"})
        elif len(vals)>expected:
            for i,v in enumerate(vals):
                extra=i>=expected;cols.append({"field":header[i] if not extra else f"PRESERVED EXTRA {i-expected+1}","detected":v,"proposed":v if not extra else "","state":"REVIEW" if extra else "UNCHANGED","reason":"No destination selected" if extra else "Position matches header","suggestedField":"","confidence":0,"decision":"REVIEW" if extra else "UNCHANGED"})
            extra=len(vals)-expected;issues.append({"recordIndex":len(logical)-1,"line":label,"status":"REVIEW REQUIRED","decision":"Manual mapping required","problem":"Extra delimiter-separated values","diagnosis":f"Expected {expected} fields, detected {len(vals)} (+{extra}). Extra values are preserved until mapped, absorbed, or explicitly left unresolved.","expectedColumns":expected,"actualColumns":len(vals),"difference":extra,"confidence":"LOW","original":buf.rstrip(),"proposed":"","columns":cols,"kind":"EXTRA_FIELDS"})
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
            for j,sug in enumerate(suggestions):
                idx=expected+j;issue["columns"][idx].update({"suggestedField":sug["suggestedField"],"confidence":sug["confidence"],"decision":sug["decision"],"reason":sug["reason"],"candidates":sug.get("candidates",[])})
    auto=sum(x["status"]=="AUTO FIXED" for x in issues);review=sum(x["status"]=="REVIEW REQUIRED" for x in issues);bad=sum(x["status"]=="UNRECOVERABLE" for x in issues)
    return {"file":path.name,"delimiter":delim,"header":header,"expected":expected,"records":max(0,len(logical)-1),"healthy":max(0,len(logical)-1-len(issues)),"autoFixed":auto,"reviewRequired":review,"unrecoverable":bad,"unresolved":review+bad,"logical":logical,"issues":issues,"createdRecords":[],"undoStack":[]}

def apply_mapping(audit, issue_index, column_index, target_field):
    if not (0 <= issue_index < len(audit["issues"])): raise ValueError("Invalid repair issue.")
    issue=audit["issues"][issue_index]
    if issue["kind"]!="EXTRA_FIELDS": raise ValueError("Only preserved extra values can be mapped.")
    if not (0 <= column_index < len(issue["columns"])): raise ValueError("Invalid repair value.")
    col=issue["columns"][column_index]
    if not col["field"].startswith("PRESERVED EXTRA"): raise ValueError("Select a preserved extra value.")
    if target_field not in audit["header"]: raise ValueError("Select a valid destination column.")
    rec=audit["logical"][issue["recordIndex"]];target=audit["header"].index(target_field);detected=col["detected"];current=rec["values"][target] if target < len(rec["values"]) else ""
    if str(current).strip():raise ValueError(f"{target_field} already contains '{current}'. Clear/review it before mapping another value.")
    while len(rec["values"]) < audit["expected"]:rec["values"].append("")
    rec["values"][target]=detected;col["proposed"]=detected;col["state"]="USER APPROVED";col["reason"]=f"Mapped to {target_field} by user";col["mappedTo"]=target_field
    return audit

def absorb_extras(audit, issue_index, target_field, separator=" "):
    if not (0<=issue_index<len(audit["issues"])):raise ValueError("Invalid repair issue.")
    issue=audit["issues"][issue_index]
    if issue["kind"]!="EXTRA_FIELDS":raise ValueError("Absorb is only available for records with extra values.")
    if target_field not in audit["header"]:raise ValueError("Choose a valid destination field.")
    extras=[c for c in issue["columns"] if c["field"].startswith("PRESERVED EXTRA") and c.get("state") not in ("USER APPROVED","NEW RECORD","ABSORBED")]
    if not extras:raise ValueError("No unresolved extra values remain to absorb.")
    rec=audit["logical"][issue["recordIndex"]];ti=audit["header"].index(target_field)
    while len(rec["values"])<audit["expected"]:rec["values"].append("")
    before=str(rec["values"][ti] or "");parts=[before] if before.strip() else [];parts.extend(str(c["detected"]) for c in extras if str(c["detected"]).strip());combined=separator.join(parts)
    audit.setdefault("undoStack",[]).append({"action":"ABSORB","issueIndex":issue_index,"targetIndex":ti,"before":before,"columns":[issue["columns"].index(c) for c in extras]})
    rec["values"][ti]=combined;del rec["values"][audit["expected"]:]
    for c in extras:c["state"]="ABSORBED";c["decision"]="ABSORBED";c["mappedTo"]=target_field;c["proposed"]=combined;c["reason"]=f"Absorbed into {target_field} by user"
    issue["status"]="REVIEWED";issue["decision"]=f"Broken line absorbed into {target_field}";issue["actualColumns"]=audit["expected"];issue["difference"]=0
    return audit

def keep_unresolved(audit, issue_index, column_index):
    col=audit["issues"][issue_index]["columns"][column_index];col["state"]="UNRESOLVED";col["decision"]="UNRESOLVED";col["reason"]="User chose to keep this value unresolved";return audit

def save_repaired(audit,dst):
    with open(dst,"w",newline="",encoding="utf-8-sig") as f:
        w=csv.writer(f,delimiter=audit["delimiter"])
        for rec in audit["logical"]:w.writerow(list(rec["values"])[:audit["expected"]])
    return True

def unresolved_extras(audit):
    pending=[]
    for i,issue in enumerate(audit["issues"]):
        if issue["kind"]=="EXTRA_FIELDS":
            for j,col in enumerate(issue["columns"]):
                if col["field"].startswith("PRESERVED EXTRA") and col.get("state") not in ("USER APPROVED","NEW RECORD","ABSORBED"):pending.append((i,j,col["detected"]))
    return pending

def keep_issue_as_is(audit, issue_index):
    issue=audit["issues"][issue_index]
    if issue["kind"]!="EXTRA_FIELDS": raise ValueError("This action is only available for records with extra values.")
    for col in issue["columns"]:
        if col["field"].startswith("PRESERVED EXTRA"):col["state"]="UNRESOLVED";col["decision"]="UNRESOLVED";col["reason"]="Whole record explicitly kept as-is by user"
    issue["decision"]="Keep original / unresolved";return audit

def create_record_from_extras(audit, issue_index, mapping):
    issue=audit["issues"][issue_index]
    if issue["kind"]!="EXTRA_FIELDS": raise ValueError("Select a record with preserved extra values.")
    mapping=dict(mapping or {});new=[""]*audit["expected"];used=set();explicit=mapping.pop("__values__",{}) if isinstance(mapping,dict) else {}
    for field,value in explicit.items():
        if field in audit["header"] and str(value).strip():ti=audit["header"].index(field);new[ti]=str(value);used.add(ti)
    used_columns=[]
    for col_index,target in mapping.items():
        ci=int(col_index)
        if not (0<=ci<len(issue["columns"])):continue
        col=issue["columns"][ci]
        if not col["field"].startswith("PRESERVED EXTRA") or target not in audit["header"]:continue
        ti=audit["header"].index(target)
        if ti in used:raise ValueError(f"More than one value was assigned to {target}.")
        new[ti]=col["detected"];used.add(ti);used_columns.append(ci)
    if not used:raise ValueError("Map at least one preserved value before creating a new record.")
    if "SID" in audit["header"] and not str(new[audit["header"].index("SID")]).strip():raise ValueError("SID is required for a new record. Enter an SID before creating the candidate.")
    record_id=max([r.get("id",0) for r in audit.get("createdRecords",[])]+[0])+1;rec={"start":0,"end":0,"values":new,"raw":"","createdByUser":True,"createdRecordId":record_id,"sourceIssue":issue_index};audit["logical"].append(rec)
    for ci in used_columns:
        col=issue["columns"][ci];col["state"]="NEW RECORD";col["mappedTo"]=mapping.get(str(ci),mapping.get(ci,""));col["reason"]=f"User assigned value to {col['mappedTo']} in new record #{record_id}"
    created={"id":record_id,"logicalIndex":len(audit["logical"])-1,"sourceIssue":issue_index,"values":dict(zip(audit["header"],new)),"active":True};audit.setdefault("createdRecords",[]).append(created);audit.setdefault("undoStack",[]).append({"action":"CREATE","recordId":record_id});issue["decision"]=f"New record #{record_id} created";issue["status"]="REVIEWED";return audit

def delete_created_record(audit, record_id):
    target=next((r for r in audit.get("createdRecords",[]) if r["id"]==record_id and r.get("active",True)),None)
    if not target:raise ValueError("Created record is no longer available.")
    li=target["logicalIndex"]
    if not (0<=li<len(audit["logical"])):raise ValueError("Created record location is invalid.")
    removed=audit["logical"].pop(li);target["active"]=False
    for r in audit.get("createdRecords",[]):
        if r.get("active",True) and r["logicalIndex"]>li:r["logicalIndex"]-=1
    audit.setdefault("undoStack",[]).append({"action":"DELETE","recordId":record_id,"record":removed,"logicalIndex":li});return audit

def undo_last_created_action(audit):
    stack=audit.setdefault("undoStack",[])
    if not stack:raise ValueError("Nothing to undo.")
    action=stack.pop()
    if action["action"]=="ABSORB":
        issue=audit["issues"][action["issueIndex"]];rec=audit["logical"][issue["recordIndex"]];rec["values"][action["targetIndex"]]=action["before"]
        for ci in action["columns"]:
            col=issue["columns"][ci];col["state"]="REVIEW";col["decision"]="REVIEW";col["mappedTo"]="";col["proposed"]="";col["reason"]="No destination selected"
        issue["status"]="REVIEW REQUIRED";issue["decision"]="Manual mapping required";issue["actualColumns"]=audit["expected"]+len(action["columns"]);issue["difference"]=len(action["columns"]);return audit
    rid=action["recordId"];target=next((r for r in audit.get("createdRecords",[]) if r["id"]==rid),None)
    if action["action"]=="CREATE":
        if target and target.get("active",True):
            li=target["logicalIndex"];audit["logical"].pop(li);target["active"]=False
            for r in audit.get("createdRecords",[]):
                if r.get("active",True) and r["logicalIndex"]>li:r["logicalIndex"]-=1
    elif action["action"]=="DELETE":
        li=min(action["logicalIndex"],len(audit["logical"]));audit["logical"].insert(li,action["record"])
        if target:target["active"]=True;target["logicalIndex"]=li
        for r in audit.get("createdRecords",[]):
            if r is not target and r.get("active",True) and r["logicalIndex"]>=li:r["logicalIndex"]+=1
    return audit