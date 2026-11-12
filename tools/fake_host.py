#!/usr/bin/env python3
"""假中控（socket 協定 v1，docs/SOCKET_PROTOCOL_v1.md）。只用標準函式庫。

在筆電上開 TCP server（預設 0.0.0.0:9500），PLC（D236=1）會主動連進來。
- 每秒送一筆 HO（hb 每次 +1）
- 印出收到的 HI / ST / SC（ST 會拆欄位顯示）
- 鍵盤指令（打完按 Enter）：
    t            送 TG（rid 自動 +1）
    b <位元>     切換 b 的某一位元，例如 b 0 = B00 Remote、b 1 = B01 放行、b 4 = ACK開始、b 5 = ACK完工
    b= <16進位>  直接設定 b，例如 b= 0013
    code <n>     設定 code（0~99）
    sn <字串>    設定序號（20 碼，右補空白）；wo / op 同理（12 / 10 碼）
    ts           下一筆 HO 帶目前時間（校時一次）；平常 ts 送全 0
    pause        暫停 / 恢復送 HO（測 PLC 5 秒逾時重連）
    raw <字串>   原樣送一行（測格式錯誤）
    q            結束
用法：python3 fake_host.py [--port 9500] [--bind 0.0.0.0]
"""
import argparse
import datetime
import socket
import sys
import threading
import time

ST_FIELDS = ["hb", "run", "sw", "t0", "t1", "ct", "tq", "ang", "tj", "aj", "hj", "tt", "stop", "cs", "n"]


class Host:
    def __init__(self):
        self.lock = threading.Lock()
        self.conn = None
        self.hb = 0
        self.code = 0
        self.b = 0x0000
        self.sn = ""
        self.wo = ""
        self.op = ""
        self.send_ts = False
        self.paused = False
        self.rid = 0
        self.last_st = None

    # ---------------------------------------------------- 訊框
    def ho(self):
        with self.lock:
            self.hb = (self.hb + 1) % 65536
            ts = "0" * 14
            if self.send_ts:
                ts = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
                self.send_ts = False
            s = (f"HO;hb={self.hb:05d};code={self.code:02d};b={self.b:04X};"
                 f"sn={self.sn[:20]:<20};wo={self.wo[:12]:<12};op={self.op[:10]:<10};ts={ts}")
        assert len(s) == 98, len(s)
        return s

    def send_line(self, s):
        c = self.conn
        if c is None:
            print("  (PLC 還沒連上)")
            return
        try:
            c.sendall(s.encode("ascii") + b"\r\n")
        except OSError as e:
            print(f"  送出失敗：{e}")

    # ---------------------------------------------------- 收
    def on_line(self, line):
        ts = time.strftime("%H:%M:%S")
        if line.startswith("ST;"):
            kv = dict(p.split("=", 1) for p in line.split(";")[1:] if "=" in p)
            short = {k: kv.get(k) for k in ST_FIELDS}
            if short != self.last_st:   # 內容沒變就不重印，免得洗版
                print(f"{ts} ST ({len(line)}) " + " ".join(f"{k}={v}" for k, v in short.items()))
                sw = kv.get("sw")
                if sw and len(sw) == 4:
                    v = int(sw, 16)
                    on = [f"B{i:02d}" for i in range(16) if v >> i & 1]
                    print(f"         sw 位元 ON：{' '.join(on) or '（無）'}")
                self.last_st = short
            bad = [k for k in ST_FIELDS if k not in kv]
            if bad or len(line) != 135:
                print(f"         !! ST 格式不對：長度 {len(line)}（應 135），缺 {bad}")
        elif line.startswith("HI;"):
            print(f"{ts} HI ({len(line)}) {line}" + ("" if len(line) == 38 else "  !! 長度應 38"))
        elif line.startswith("SC;"):
            print(f"{ts} SC ({len(line)}) {line}" + ("" if len(line) == 49 else "  !! 長度應 49"))
        else:
            print(f"{ts} ?? ({len(line)}) {line!r}")

    def reader(self, c):
        buf = b""
        while True:
            try:
                d = c.recv(4096)
            except OSError:
                d = b""
            if not d:
                print(time.strftime("%H:%M:%S"), "PLC 斷線")
                with self.lock:
                    if self.conn is c:
                        self.conn = None
                return
            buf += d
            while b"\n" in buf:
                ln, buf = buf.split(b"\n", 1)
                self.on_line(ln.rstrip(b"\r").decode("ascii", "replace"))

    def sender(self):
        while True:
            time.sleep(1.0)
            if self.conn is not None and not self.paused:
                self.send_line(self.ho())

    def serve(self, bind, port):
        srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.bind((bind, port))
        srv.listen(1)
        print(f"假中控在 {bind}:{port} 等 PLC 連線…（輸入 help 看指令）")
        while True:
            c, addr = srv.accept()
            c.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            print(time.strftime("%H:%M:%S"), f"PLC 連上 {addr[0]}:{addr[1]}")
            with self.lock:
                old, self.conn = self.conn, c
            if old is not None:
                try:
                    old.close()
                except OSError:
                    pass
            threading.Thread(target=self.reader, args=(c,), daemon=True).start()

    # ---------------------------------------------------- 鍵盤
    def console(self):
        for raw in sys.stdin:
            cmd = raw.strip()
            if not cmd:
                continue
            w = cmd.split(None, 1)
            k, arg = w[0].lower(), (w[1] if len(w) > 1 else "")
            if k == "q":
                return
            if k == "help":
                print(__doc__)
            elif k == "t":
                self.rid = (self.rid + 1) % 100000
                s = f"TG;rid={self.rid:05d}"
                print("  送", s)
                self.send_line(s)
            elif k == "b" and arg.isdigit() and 0 <= int(arg) <= 15:
                with self.lock:
                    self.b ^= 1 << int(arg)
                print(f"  b = {self.b:04X}（B{int(arg):02d} = {self.b >> int(arg) & 1}）")
            elif k == "b=":
                try:
                    with self.lock:
                        self.b = int(arg, 16) & 0xFFFF
                    print(f"  b = {self.b:04X}")
                except ValueError:
                    print("  用法：b= 0013")
            elif k == "code" and arg.isdigit():
                self.code = int(arg) % 100
            elif k in ("sn", "wo", "op"):
                if not all(32 <= ord(ch) <= 126 for ch in arg):
                    print("  只能用 ASCII 可見字元")
                else:
                    setattr(self, k, arg)
            elif k == "ts":
                self.send_ts = True
            elif k == "pause":
                self.paused = not self.paused
                print("  暫停送 HO" if self.paused else "  恢復送 HO")
            elif k == "raw":
                self.send_line(arg)
            else:
                print("  不認得的指令，輸入 help")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=9500)
    ap.add_argument("--bind", default="0.0.0.0")
    a = ap.parse_args()
    h = Host()
    threading.Thread(target=h.serve, args=(a.bind, a.port), daemon=True).start()
    threading.Thread(target=h.sender, daemon=True).start()
    try:
        h.console()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
