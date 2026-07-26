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
    delim=_delim(raw,path.suffix); header=next(csv.reader([lines[0]],delimiter=delim)); expected=len(header)
    logical=[(1,1,header,lines[0].rstrip())]; issues=[]; buf=""; start=2
    for no,line in enumerate(lines[1:],2):
        if not buf:start=no
        buf+=line
        if _quote_open(buf):continue
        vals=next(csv.reader([buf],delimiter=delim)); logical.append((start,no,vals,buf.rstrip()))
        label=f"{start}-{no}" if start!=no else str(no); cols=[]
        if start!=no and len(vals)==expected:
            for i,v in enumerate(vals): cols.append({"field":header[i],"detected":v,"proposed":v,"state":"RECONSTRUCTED","reason":"Preserved after joining quoted physical lines"})
            issues.append({"line":label,"status":"AUTO FIXED","decision":"Safe to auto-fix","problem":"Record split across physical lines","diagnosis":f"Physical lines {start}-{no} form one quoted record. Joining them produces exactly {expected} fields. No values were discarded.","expectedColumns":expected,"actualColumns":len(vals),"difference":0,"confidence":"HIGH","original":buf.rstrip(),"proposed":delim.join(vals),"columns":cols,"kind":"PHYSICAL_LINE_SPLIT"})
        elif len(vals)>expected:
            for i,v in enumerate(vals):
                extra=i>=expected
                cols.append({"field":header[i] if not extra else f"PRESERVED EXTRA {i-expected+1}","detected":v,"proposed":v if not extra else "","state":"REVIEW" if extra else "UNCHANGED","reason":"No header exists; value preserved and not deleted" if extra else "Position matches header"})
            extra=len(vals)-expected
            issues.append({"line":label,"status":"REVIEW REQUIRED","decision":"Manual mapping required","problem":"Extra delimiter-separated values","diagnosis":f"Expected {expected} fields, detected {len(vals)} (+{extra}). {extra} additional value(s) have no reliable destination. They are preserved exactly as found; the application will not guess, merge or delete them.","expectedColumns":expected,"actualColumns":len(vals),"difference":extra,"confidence":"LOW","original":buf.rstrip(),"proposed":"","columns":cols,"kind":"EXTRA_FIELDS"})
        elif len(vals)<expected:
            for i in range(expected):
                present=i<len(vals)
                cols.append({"field":header[i],"detected":vals[i] if present else "","proposed":vals[i] if present else "","state":"UNCHANGED" if present else "MISSING","reason":"Position matches header" if present else "Expected field absent; no value invented"})
            missing=expected-len(vals)
            issues.append({"line":label,"status":"REVIEW REQUIRED","decision":"Manual review required","problem":"Missing field values","diagnosis":f"Expected {expected} fields, detected {len(vals)} (-{missing}). Existing values are preserved and missing values are not fabricated.","expectedColumns":expected,"actualColumns":len(vals),"difference":-missing,"confidence":"LOW","original":buf.rstrip(),"proposed":"","columns":cols,"kind":"MISSING_FIELDS"})
        buf=""
    if buf:
        issues.append({"line":f"{start}-{len(lines)}","status":"UNRECOVERABLE","decision":"Manual recovery required","problem":"Unclosed quoted field","diagnosis":"The file ended before a quoted value was closed. No destructive repair was attempted.","expectedColumns":expected,"actualColumns":0,"difference":-expected,"confidence":"NONE","original":buf.rstrip(),"proposed":"","columns":[],"kind":"UNCLOSED_QUOTE"})
    healthy_rows=[vals for _,_,vals,_ in logical[1:] if len(vals)==expected]
    for issue in issues:
        if issue.get("kind")=="EXTRA_FIELDS":
            vals=next(csv.reader([issue["original"]],delimiter=delim))
            suggestions=analyze_extras(header,healthy_rows,vals[expected:])
            issue["suggestions"]=suggestions
            for j,sug in enumerate(suggestions):
                idx=expected+j
                if idx<len(issue["columns"]):
                    issue["columns"][idx].update({"suggestedField":sug["suggestedField"],"confidence":sug["confidence"],
                                                  "decision":sug["decision"],"reason":sug["reason"]})
    auto=sum(x["status"]=="AUTO FIXED" for x in issues); review=sum(x["status"]=="REVIEW REQUIRED" for x in issues); bad=sum(x["status"]=="UNRECOVERABLE" for x in issues)
    return {"file":path.name,"delimiter":delim,"header":header,"expected":expected,"records":max(0,len(logical)-1),"healthy":max(0,len(logical)-1-len(issues)),"autoFixed":auto,"reviewRequired":review,"unrecoverable":bad,"unresolved":review+bad,"logical":logical,"issues":issues}

def save_repaired(src,dst):
    x=inspect_csv(src)
    with open(dst,"w",newline="",encoding="utf-8-sig") as f:
        w=csv.writer(f,delimiter=x["delimiter"])
        for _,_,vals,_ in x["logical"]:w.writerow(vals)
    return {"unresolved":x["unresolved"],"autoFixed":x["autoFixed"],"reviewRequired":x["reviewRequired"],"unrecoverable":x["unrecoverable"]}
