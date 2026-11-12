"""SD550T settings dump over RS-485 (read-only).

Protocol: 日東精工 "SD550T 簡易ネットワーク 通信仕様 V1.1x"
(SOP/20261111_nitto_drawings/SD550TV11x通信仕様.pdf).

Only sends "R" (read) commands. Never sends "W".

Usage (laptop + USB-RS485 adapter, PLC FX5-485ADP disconnected from the line):
    pip install pyserial
    python -I sd550t_dump.py COM5                 # ID 01, 9600, L0000-L0999 + R results
    python -I sd550t_dump.py COM5 --id 1 --baud 9600 --from 500 --to 599
Output: sd550t_dump_<timestamp>.csv next to this script.
"""
import argparse
import csv
import datetime as dt
import os
import sys
import time

import serial  # pyserial

RESULTS = {
    "R0010": "完了トルク(小數點見手冊)",
    "R0020": "本締角度(度)",
    "R0021": "高さ角度(10度)",
    "R0030": "トルク判定 0NG 1OK 9無効",
    "R0031": "角度判定",
    "R0032": "高さ判定",
    "R0051": "停止step",
    "R0052": "停止Prog",
    "R0053": "締付時間(0.01s)",
    "R0060": "停止要因",
}
NG = {
    "0001": "checksum", "0002": "command NG", "0003": "no data", "0004": "VNo NG",
    "0005": "value NG", "0006": "access denied", "0007": "numeric error",
    "0008": "format error", "0010": "data type error", "0011": "setting in progress",
    "0012": "EEPROM write while tightening", "0013": "abort requested",
}


def checksum(s: str) -> str:
    return f"{sum(s.encode('ascii')) & 0xFF:02X}"


def read_vno(port: serial.Serial, sid: int, vno: str, timeout: float):
    body = f"{sid:02d}R{vno}"
    frame = (body + checksum(body) + "\r").encode("ascii")
    port.reset_input_buffer()
    port.write(frame)
    port.flush()
    deadline = time.monotonic() + timeout
    buf = b""
    while time.monotonic() < deadline:
        buf += port.read(port.in_waiting or 1)
        # 2-wire half duplex adapters may echo our own frame: drop it
        if buf.startswith(frame):
            buf = buf[len(frame):]
        if b"\r" in buf:
            break
    time.sleep(0.005)  # spec: >= 1 ms between response and next command
    line = buf.split(b"\r")[0].decode("ascii", "replace")
    if not line:
        return "TIMEOUT", "", ""
    if len(line) < 6:
        return "BADFRAME", line, ""
    payload, sum_rx = line[:-2], line[-2:]
    sum_ok = sum_rx == "**" or sum_rx.upper() == checksum(payload)
    kind = payload[2:4]
    val = payload[4:]
    if kind.startswith("E"):
        code = val[-4:]
        return "NG", line, f"{code} {NG.get(code, '4000+ = comm status' if code >= '4000' else '')}"
    if kind in ("D0", "D1", "D9"):
        return ("OK" if sum_ok else "SUMERR"), line, val
    return "BADFRAME", line, ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("port")
    ap.add_argument("--id", type=int, default=1, help="Pa80 controller ID (factory 0000; must be 01..30)")
    ap.add_argument("--baud", type=int, default=9600, help="Pa81 (factory 0003 = 9600)")
    ap.add_argument("--from", dest="lo", type=int, default=0)
    ap.add_argument("--to", dest="hi", type=int, default=999)
    ap.add_argument("--timeout", type=float, default=1.0)
    a = ap.parse_args()

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       f"sd550t_dump_{dt.datetime.now():%Y%m%d_%H%M%S}.csv")
    with serial.Serial(a.port, a.baud, bytesize=8, parity="N", stopbits=1, timeout=0.05) as port, \
            open(out, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["VNo", "status", "value", "raw", "note"])
        # probe first so a wrong ID/baud/wiring fails fast
        st, raw, val = read_vno(port, a.id, "L0000", a.timeout)
        print(f"probe L0000 -> {st} {raw!r}")
        if st == "TIMEOUT":
            sys.exit("No reply. Check ID (Pa80), baud (Pa81), TxD+<->RxD+ / TxD-<->RxD- jumpers, "
                     "A/B polarity, terminator, and that nothing else (PLC/RC75) is master on the line.")
        ok = 0
        for n in range(a.lo, a.hi + 1):
            vno = f"L{n:04d}"
            st, raw, val = read_vno(port, a.id, vno, a.timeout)
            if st == "NG" and val.startswith("0003"):
                continue  # unused address
            w.writerow([vno, st, val if st != "NG" else "", raw, val if st == "NG" else ""])
            ok += st == "OK"
            print(f"{vno} {st} {val}")
        for vno, note in RESULTS.items():
            st, raw, val = read_vno(port, a.id, vno, a.timeout)
            w.writerow([vno, st, val, raw, note])
            print(f"{vno} {st} {val}  {note}")
    print(f"\n{ok} memory-sheet values read -> {out}")


if __name__ == "__main__":
    main()
