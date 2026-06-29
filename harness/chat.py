import json,urllib.request,time,sys,os
H=os.environ.get("OLLAMA_HOST","http://127.0.0.1:11434")
conv=sys.argv[1]
msgs=json.load(open(conv))
payload={"model":"ornith:35b","messages":msgs,"stream":False,"keep_alive":"40m",
         "options":{"num_predict":48000,"temperature":0.2}}
req=urllib.request.Request(H+"/api/chat",data=json.dumps(payload).encode(),
                           headers={"Content-Type":"application/json"})
t=time.time()
r=json.load(urllib.request.urlopen(req,timeout=6000))
dt=time.time()-t
m=r.get("message",{})
think=m.get("thinking","") or ""
content=m.get("content","") or ""
msgs.append({"role":"assistant","content":content})
json.dump(msgs,open(conv,"w"),indent=1)
open(conv+".last","w").write(content)
open(conv+".think","w").write(think)
print("WALL %.0fs eval=%s think_len=%d resp_len=%d done=%s"%(
      dt,r.get("eval_count"),len(think),len(content),r.get("done_reason")))
