#!/usr/bin/env python3
"""IO 側錄（只讀，不會寫 PLC）

FX5S MODBUS/TCP 502：預設每 0.1 秒讀 X0～X17、Y0～Y15 與 D7200～D7204
（v3.2 的步序 D100、第幾點 D222、本步秒數 D500、復歸步序 D110、等待條件碼 D2051）。
有任何點變化就寫一行 CSV（UTF-8 BOM，Excel 可直接開）；10 秒沒變化寫一行 alive。
PLC 只有一個 MODBUS 連線位：側錄時不要同時開 io_grid.ps1 或其他 Modbus 工具。

用法：python io_rec.py [--tag 治具測試] [--plc 192.168.1.21] [--interval 0.1]
停止：Ctrl+C
只用 Python 標準函式庫（3.8 以上）。
"""
import argparse
import csv
import datetime as dt
import os
import socket
import struct
import sys
import time

X_NAMES = ["X%o" % i for i in range(16)]                       # X0..X7, X10..X17
Y_IDX = list(range(8)) + list(range(8, 14))                     # Y0..Y7, Y10..Y15
Y_NAMES = ["Y%o" % i for i in Y_IDX]
D_NAMES = ["D100步序", "D222第幾點", "D500本步0.1s", "D110復歸步", "D2051等待碼"]


class Modbus:
    def __init__(self, host, port, timeout=2.0):
        self.host, self.port, self.timeout = host, port, timeout
        self.sock = None
        self.tid = 0

    def close(self):
        if self.sock:
            try:
                self.sock.close()
            finally:
                self.sock = None

    def _recv(self, n):
        buf = b""
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                raise ConnectionError("PLC 關閉連線")
            buf += chunk
        return buf

    def read(self, fc, addr, count):
        if self.sock is None:
            self.sock = socket.create_connection((self.host, self.port), self.timeout)
            self.sock.settimeout(self.timeout)
            self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        try:
            self.tid = (self.tid + 1) % 65536
            self.sock.sendall(struct.pack(">HHHBBHH", self.tid, 0, 6, 1, fc, addr, count))
            head = self._recv(9)
            _, _, length, _, rfc, nbytes = struct.unpack(">HHHBBB", head)
            if rfc >= 0x80:
                raise IOError("Modbus exception %d" % nbytes)
            data = self._recv(nbytes)
        except Exception:
            self.close()
            raise
        if fc in (1, 2):
            return [(data[i // 8] >> (i % 8)) & 1 for i in range(count)]
        return [v for v in struct.unpack(">%dh" % count, data[: 2 * count])]


def main():
    ap = argparse.ArgumentParser(description="FX5S IO 側錄成 CSV（只讀）")
    ap.add_argument("--plc", default="192.168.1.21")
    ap.add_argument("--port", type=int, default=502)
    ap.add_argument("--interval", type=float, default=0.1, help="讀取間隔秒數")
    ap.add_argument("--tag", default="", help="加在檔名後面，例如 A3_EMO")
    ap.add_argument("--out", default="", help="CSV 路徑（預設存在本程式旁邊的 csv 資料夾）")
    ap.add_argument("--no-d", action="store_true", help="不讀 D7200～D7204（PLC 還是舊版時用）")
    a = ap.parse_args()
    try:  # Windows 主控台（cp950）遇到顯示不了的字不要當掉
        sys.stdout.reconfigure(errors="replace")
    except AttributeError:
        pass

    if a.out:
        out = a.out
    else:
        folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), "csv")
        os.makedirs(folder, exist_ok=True)
        name = "io_rec_" + dt.datetime.now().strftime("%Y%m%d_%H%M%S")
        if a.tag:
            name += "_" + "".join(c for c in a.tag if c not in '\\/:*?"<>| ')
        out = os.path.join(folder, name + ".csv")

    names = X_NAMES + Y_NAMES + ([] if a.no_d else D_NAMES)
    mb = Modbus(a.plc, a.port)
    f = open(out, "w", newline="", encoding="utf-8-sig")
    w = csv.writer(f)
    w.writerow(["time", "ms", "event", "changed"] + names)
    f.flush()
    t0 = time.monotonic()

    def row(event, changed, vals):
        w.writerow([dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3],
                    int((time.monotonic() - t0) * 1000), event, changed] + list(vals))
        f.flush()

    print("IO 側錄 → %s" % out)
    print("PLC %s，每 %.2f 秒讀一次；Ctrl+C 停止。" % (a.plc, a.interval))
    prev = None
    rows = polls = errs = 0
    last_err = ""
    last_alive = time.monotonic()
    last_change = ""
    last_status = 0.0
    try:
        while True:
            start = time.monotonic()
            try:
                x = mb.read(2, 0, 16)
                y_all = mb.read(1, 0, 16)
                y = [y_all[i] for i in Y_IDX]
                d = [] if a.no_d else mb.read(3, 200, 5)
                vals = x + y + d
                polls += 1
                if last_err:
                    row("reconnect", last_err, vals)
                    rows += 1
                    last_err = ""
                if prev is None:
                    row("start", "", vals)
                    rows += 1
                else:
                    ch = []
                    for i, (v, p) in enumerate(zip(vals, prev)):
                        if v != p:
                            if i < 30:
                                ch.append(names[i] + ("↑" if v else "↓"))
                            else:
                                ch.append("%s=%d" % (names[i], v))
                    if ch:
                        row("change", " ".join(ch), vals)
                        rows += 1
                        last_change = dt.datetime.now().strftime("%H:%M:%S ") + " ".join(ch)
                        last_alive = time.monotonic()
                    elif time.monotonic() - last_alive >= 10:
                        row("alive", "", vals)
                        rows += 1
                        last_alive = time.monotonic()
                prev = vals
            except Exception as e:  # 斷線：記一筆，1 秒後重試
                errs += 1
                msg = str(e).replace(",", ";")
                if msg != last_err:
                    row("error", msg, [])
                    rows += 1
                last_err = msg
                time.sleep(1)
            if time.monotonic() - last_status >= 2:
                line = "%s 讀 %d 次 寫 %d 列 錯誤 %d  最後變化：%s" % (
                    dt.datetime.now().strftime("%H:%M:%S"), polls, rows, errs, last_change)
                sys.stdout.write("\r" + line[:110].ljust(110))
                sys.stdout.flush()
                last_status = time.monotonic()
            left = a.interval - (time.monotonic() - start)
            if left > 0:
                time.sleep(left)
    except KeyboardInterrupt:
        pass
    finally:
        f.close()
        mb.close()
        print("\n已停止，CSV：%s" % out)


if __name__ == "__main__":
    main()
