"""Cari drive iCELink di Windows.  python3 icelink.py          -> cetak drive terpilih
                                  python3 icelink.py --list   -> daftar semua drive"""
import ctypes, os, sys, string

def info(d):
    k = ctypes.windll.kernel32
    buf = ctypes.create_unicode_buffer(261)
    ok = k.GetVolumeInformationW(d + ":\\", buf, 261, None, None, None, None, 0)
    return (buf.value if ok else ""), k.GetDriveTypeW(d + ":\\")

def drives():
    for d in string.ascii_uppercase:
        if os.path.exists(d + ":\\"):
            label, typ = info(d)
            files = []
            try: files = os.listdir(d + ":\\")[:6]
            except OSError: pass
            yield d, label, typ, files

def pick():
    ds = [x for x in drives() if x[0] not in "AB"]
    for d, l, t, f in ds:                       # 1. label mengandung icelink/icesugar
        if "icelink" in l.lower() or "icesugar" in l.lower(): return d
    for d, l, t, f in ds:                       # 2. ciri DAPLink (MBED.HTM / DETAIL.TXT)
        if any(n.upper() in ("MBED.HTM", "DETAIL.TXT") for n in f): return d
    rem = [x for x in ds if x[2] == 2]          # 3. satu-satunya drive removable
    return rem[0][0] if len(rem) == 1 else ""

if os.name != "nt":
    sys.exit(0)
if "--list" in sys.argv:
    kinds = {2: "removable", 3: "fixed", 4: "network", 5: "cdrom"}
    for d, l, t, f in drives():
        print("%s:  label=%-16r type=%-9s isi=%s" % (d, l, kinds.get(t, t), f))
    print("terpilih:", (pick() + ":") if pick() else "(tidak ada)")
else:
    p = pick()
    print(p + ":/" if p else "")
