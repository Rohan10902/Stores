import csv
from pathlib import Path

def inspect_csv(p):
    raw=Path(p).read_text(encoding="utf-8-sig",errors="replace"); lines=raw.splitlines(keepends=True)
    if not lines: raise ValueError("File is empty.")
    try: delim=csv.Sniffer().sniff(raw[:12000],delimiters=",;\t|").delimiter
    except Exception: delim=","
    header=next(csv.reader([lines[0]],delimiter=delim)); expected=len(header)
    logical=[]; issues=[]; buf=""; start=1
    def quote_open(s):
        i=count=0
        while i<len(s):
            if s[i]=='"':
                if i+1<len(s) and s[i+1]=='"': i+=2; continue
                count+=1
            i+=1
        return count%2==1
    for no,line in enumerate(lines,1):
        if not buf:start=no
        buf+=line
        if quote_open(buf): continue
        vals=next(csv.reader([buf],delimiter=delim)); logical.append((start,no,vals,buf.rstrip()))
        if no>1 and len(vals)!=expected:
            issues.append({"line":f"{start}-{no}" if start!=no else str(no),"expectedColumns":expected,"actualColumns":len(vals),"status":"UNRESOLVED","repair":"Column count differs from header","content":buf.rstrip()})
        elif start!=no:
            issues.append({"line":f"{start}-{no}","expectedColumns":expected,"actualColumns":len(vals),"status":"REPAIRED","repair":f"Combined physical lines {start}-{no} into one logical record","content":buf.rstrip()})
        buf=""
    if buf: issues.append({"line":f"{start}-{len(lines)}","expectedColumns":expected,"actualColumns":0,"status":"UNRESOLVED","repair":"Unclosed quoted field","content":buf.rstrip()})
    return {"delimiter":delim,"expected":expected,"logical":logical,"issues":issues}
def save_repaired(src,dst):
    x=inspect_csv(src)
    with open(dst,"w",newline="",encoding="utf-8-sig") as f:
        w=csv.writer(f,delimiter=x["delimiter"])
        for _,_,vals,_ in x["logical"]:
            if len(vals)<x["expected"]: vals += [""]*(x["expected"]-len(vals))
            elif len(vals)>x["expected"]: vals=vals[:x["expected"]-1]+[x["delimiter"].join(vals[x["expected"]-1:])]
            w.writerow(vals)
