import subprocess,plistlib,json,sys
sp=sys.argv[1]; theme=sys.argv[2]; x,y,w,h=map(float,sys.argv[3:7]); visible=sys.argv[7]=='1'
d=plistlib.loads(subprocess.run(['defaults','export','io.coreify.keyli','-'],capture_output=True).stdout)
c=json.loads(d['io.coreify.keyli.config.v1'])
c.update(themeId=theme, isFloatingVisible=visible, floatingOpacity=1.0, isFloatingPinned=True,
         floatingWindowX=x, floatingWindowY=y, floatingWindowWidth=w, floatingWindowHeight=h)
d['io.coreify.keyli.config.v1']=json.dumps(c).encode()
open(sp+'/tmp_prefs.plist','wb').write(plistlib.dumps(d)); subprocess.run(['defaults','import','io.coreify.keyli',sp+'/tmp_prefs.plist'])
