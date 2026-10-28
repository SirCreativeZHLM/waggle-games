#!/usr/bin/env python3
"""Pretends to be the phone remote: pairs, streams a pose, throws one swing, presses A.
Usage: fake_phone.py [host] [code]"""
import json, socket, sys, time, uuid
host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
code = sys.argv[2] if len(sys.argv) > 2 else "1234"
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.settimeout(0.05)
me = str(uuid.uuid4())
def send(o): s.sendto(json.dumps(o).encode(), (host, 47777))
send({"t": "hello", "id": me, "code": "9999", "name": "bad"})  # must be rejected
send({"t": "hello", "id": me, "code": code, "name": "Fake Phone"})
t0 = time.time(); n = 0
while time.time() - t0 < 4:
    t = time.time() - t0
    swing = 1.0 < t < 1.15   # ~150 ms of 3 g forward push
    st = {"t": "s", "id": me, "x": [1, 0, 0], "y": [0, 1, 0], "z": [0, 0, 1],
          "a": [0, 3.0 if swing else 0.0, 0], "g": [0, 0, 0], "b": 1 if 2.0 < t < 2.2 else 0}
    send(st); n += 1
    try: print("reply:", s.recv(2048).decode())
    except socket.timeout: pass
    time.sleep(1 / 60)
print("sent", n)
