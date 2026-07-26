import csv
from pathlib import Path

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
    if not lines:raise ValueError("File is empty.")
    delim=_delim(raw,path.suffix); header=next(csv.reader([lines[0]],delimiter=delim)); expected=len(header)
    logical=[(1,1,header,lines[0].rstrip())]; issues=[]; buf=""; start=2
    for no,line in enumerate(lines[1:],2):
        if not buf:start=no
        buf+=line
        if _quote_open(buf):continue
        vals=next(csv.reader([buf],delimiter=delim)); logical.append((start,no,vals,buf.rstrip()))
        label=f"{start}-{no}" if start!=no else str(no)
        if start!=no and len(vals)==expected:
            cols=[{"field":header[i],"detected":vals[i],"proposed":vals[i],"state":"RECONSTRUCTED",
                   "reason":"Value preserved after joining physical lines"} for i in range(expected)]
            issues.append({"line":label,"status":"AUTO FIXED","decision":"Safe to auto-fix","problem":"Record split across physical lines",
                           "diagnosis":f"Lines {start}-{no} form one quoted CSV record. Joining them produces exactly {expected} fields.",
                           "expectedColumns":expected,"actualColumns":len(vals),"difference":0,"confidence":"HIGH",
                           "original":buf.rstrip(),"proposed":delim.join(vals),"columns":cols})
        elif len(vals)!=expected:
            delta=len(vals)-expected; cols=[]
            for i,v in enumerate(vals):
                extra=i>=expected
                cols.append({"field":header[i] if not extra else f"UNASSIGNED VALUE {i-expected+1}",
                             "detected":v,"proposed":"" if extra else v,
                             "state":"UNRESOLVED" if extra else "UNCHANGED",
                             "reason":"No matching header exists; value preserved for manual review" if extra else "Mapped by position"})
            for i in range(len(vals),expected):
                cols.append({"field":header[i],"detected":"","proposed":"","state":"MISSING","reason":"Expected field is absent"})
            cause="additional delimiter-separated values appended to the record" if delta>0 else "one or more expected values are missing"
            issues.append({"line":label,"status":"UNRESOLVED","decision":"Manual review required","problem":"Column count differs from header",
                           "diagnosis":f"Expected {expected} fields, detected {len(vals)} ({delta:+d}). Possible cause: {cause}. No values were removed or reassigned.",
                           "expectedColumns":expected,"actualColumns":len(vals),"difference":delta,"confidence":"NONE",
                           "original":buf.rstrip(),"proposed":"","columns":cols})
        buf=""
    if buf:
        issues.append({"line":f"{start}-{len(lines)}","status":"UNRESOLVED","decision":"Manual review required",
                       "problem":"Unclosed quoted field","diagnosis":"The file ended before a quoted value was closed. No destructive repair was attempted.",
                       "expectedColumns":expected,"actualColumns":0,"difference":-expected,"confidence":"NONE",
                       "original":buf.rstrip(),"proposed":"","columns":[]})
    auto=sum(x["status"]=="AUTO FIXED" for x in issues); unresolved=sum(x["status"]=="UNRESOLVED" for x in issues)
    issue_records=len(issues)
    return {"file":path.name,"delimiter":delim,"header":header,"expected":expected,"records":max(0,len(logical)-1),
            "healthy":max(0,len(logical)-1-issue_records),"autoFixed":auto,"unresolved":unresolved,
            "logical":logical,"issues":issues}

def save_repaired(src,dst):
    x=inspect_csv(src)
    with open(dst,"w",newline="",encoding="utf-8-sig") as f:
        w=csv.writer(f,delimiter=x["delimiter"])
        for _,_,vals,_ in x["logical"]:w.writerow(vals)
    return {"unresolved":x["unresolved"],"autoFixed":x["autoFixed"]}
