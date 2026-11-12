#!/usr/bin/env python3
"""產生 PLC_v3_14/P16_Sock.st 與 P76_Sock_Out.st（socket 協定 v1）。

HO 解析、ST/HI/SC 組字串都是固定位置，逐字元展開成直接的 D 位址，
避免在 ST 裡大量用索引暫存器。改協定或位址時改這支再重新產生：

    python3 tools/gen_sock_st.py            # 寫進 PLC_v3_14/
    python3 tools/gen_sock_st.py --check    # 只自我檢查（用 Python 模擬解析與組字串）

U0 參數寫法若 GX Works3 不收，改 U0_TOKEN。
"""
import os
import sys

U0_TOKEN = "'U0'"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "PLC_v3_14")

LB = 4100      # 主機一行緩衝（每字 1 位元組）D4100~D4219
SB = 6600      # 組字串暫存（每字 1 位元組）D6600~
BC = 6500      # 條碼擷取（每字 1 位元組）D6500~D6531

# ---------------------------------------------------------------- HO 格式
HO_FIELDS = [  # (名稱, 長度, 種類) 種類 D=數字 H=16進位 P=字串
    ("hb", 5, "D"), ("code", 2, "D"), ("b", 4, "H"),
    ("sn", 20, "P"), ("wo", 12, "P"), ("op", 10, "P"), ("ts", 14, "D"),
]


def ho_layout():
    """回傳 (literal{pos:char}, fields{name:(pos,len,kind)}, total)"""
    lit, fld = {}, {}
    p = 0
    for ch in "HO":
        lit[p] = ch
        p += 1
    for name, n, kind in HO_FIELDS:
        for ch in ";" + name + "=":
            lit[p] = ch
            p += 1
        fld[name] = (p, n, kind)
        p += n
    return lit, fld, p


LIT, FLD, HO_LEN = ho_layout()
assert HO_LEN == 98, HO_LEN


def c(pos):
    return f"D{LB + pos}"


def gen_ho_validate():
    """M2218 已是 TRUE（長度 98、開頭 HO;）。逐字檢查，不合就 FALSE。"""
    out = []
    for pos in sorted(LIT):
        if pos < 3:
            continue
        out.append(f"IF {c(pos)} <> {ord(LIT[pos])} THEN M2218 := FALSE; END_IF;   (* '{LIT[pos]}' *)")
    for name, (p, n, kind) in FLD.items():
        for k in range(p, p + n):
            if kind == "D":
                cond = f"({c(k)} < 48) OR ({c(k)} > 57)"
            elif kind == "H":
                cond = (f"NOT ((({c(k)} >= 48) AND ({c(k)} <= 57)) OR (({c(k)} >= 65) AND ({c(k)} <= 70))"
                        f" OR (({c(k)} >= 97) AND ({c(k)} <= 102)))")
            else:
                cond = f"({c(k)} < 32) OR ({c(k)} > 126)"
            out.append(f"IF {cond} THEN M2218 := FALSE; END_IF;   (* {name} *)")
    # hb 數值不可超過 65535
    p, n, _ = FLD["hb"]
    out.append("IF M2218 THEN")
    out.append("    D2296:D := 0;")
    for k in range(p, p + n):
        out.append(f"    D2296:D := D2296:D * 10 + INT_TO_DINT({c(k)} - 48);")
    out.append("    IF D2296:D > 65535 THEN M2218 := FALSE; END_IF;")
    out.append("END_IF;")
    return out


def gen_dec(p, n, dst="D2296:D"):
    out = [f"{dst} := 0;"]
    for k in range(p, p + n):
        out.append(f"{dst} := {dst} * 10 + INT_TO_DINT({c(k)} - 48);")
    return out


def gen_ho_write():
    out = []
    # hb（驗證時已算在 D2296:D）
    out += ["IF D2296:D > 32767 THEN D2296:D := D2296:D - 65536; END_IF;",
            "D7000 := DINT_TO_INT(D2296:D);"]
    p, n, _ = FLD["code"]
    out.append(f"D7001 := ({c(p)} - 48) * 10 + ({c(p + 1)} - 48);")
    p, n, _ = FLD["b"]
    out.append("D2296:D := 0;")
    for k in range(p, p + n):
        out += [f"D2298 := {c(k)};",
                "IF D2298 >= 97 THEN D2298 := D2298 - 87; ELSIF D2298 >= 65 THEN D2298 := D2298 - 55; ELSE D2298 := D2298 - 48; END_IF;",
                "D2296:D := D2296:D * 16 + INT_TO_DINT(D2298);"]
    out += ["IF D2296:D > 32767 THEN D2296:D := D2296:D - 65536; END_IF;",
            "D7002 := DINT_TO_INT(D2296:D);"]
    # 字串
    lo_first, hi_first = [], []
    for name, dev in (("sn", 7003), ("wo", 7013), ("op", 7019)):
        p, n, _ = FLD[name]
        for w in range(n // 2):
            a, b = c(p + 2 * w), c(p + 2 * w + 1)
            lo_first.append(f"    D{dev + w} := {a} + {b} * 256;")
            hi_first.append(f"    D{dev + w} := {a} * 256 + {b};")
    out.append("IF M2091 THEN   (* 第 1 字元放低位元組 *)")
    out += lo_first
    out.append("ELSE            (* 第 1 字元放高位元組 *)")
    out += hi_first
    out.append("END_IF;")
    # 校時：全 0 不改
    p, n, _ = FLD["ts"]
    out.append("M2219 := TRUE;")
    for k in range(p, p + n):
        out.append(f"IF {c(k)} <> 48 THEN M2219 := FALSE; END_IF;")
    out.append("IF NOT M2219 THEN")
    segs = [(p, 4, 7024), (p + 4, 2, 7025), (p + 6, 2, 7026), (p + 8, 2, 7027), (p + 10, 2, 7028), (p + 12, 2, 7029)]
    for sp, sn, dev in segs:
        expr = " + ".join(f"({c(sp + i)} - 48) * {10 ** (sn - 1 - i)}" if sn - 1 - i > 0 else f"({c(sp + i)} - 48)"
                          for i in range(sn))
        out.append(f"    D{dev} := {expr};")
    out.append("END_IF;")
    return out


# ---------------------------------------------------------------- 送出訊框
class Frame:
    def __init__(self):
        self.code = []
        self.pos = 0
        self.model = []   # Python 自我檢查用：(種類, 參數)

    def lit(self, s):
        for ch in s:
            self.code.append(f"D{SB + self.pos} := {ord(ch)};   (* '{ch}' *)" if ch not in "\r\n"
                             else f"D{SB + self.pos} := {ord(ch)};")
            self.model.append(("lit", ch))
            self.pos += 1

    def dec(self, expr, n, unsigned16=False):
        mx = 10 ** n - 1
        self.code.append(f"D2322:D := {expr};")
        if unsigned16:
            self.code.append("IF D2322:D < 0 THEN D2322:D := D2322:D + 65536; END_IF;")
        else:
            self.code.append("IF D2322:D < 0 THEN D2322:D := 0; END_IF;")
        self.code.append(f"IF D2322:D > {mx} THEN D2322:D := {mx}; END_IF;")
        for k in range(n - 1, -1, -1):
            self.code.append(f"D{SB + self.pos + k} := DINT_TO_INT(D2322:D MOD 10) + 48;")
            if k:
                self.code.append("D2322:D := D2322:D / 10;")
        self.model.append(("dec", (expr, n, unsigned16)))
        self.pos += n

    def hex16(self, dev):
        self.code.append(f"D2322:D := INT_TO_DINT({dev});")
        self.code.append("IF D2322:D < 0 THEN D2322:D := D2322:D + 65536; END_IF;")
        for k in range(3, -1, -1):
            self.code.append("D2324 := DINT_TO_INT(D2322:D MOD 16);")
            self.code.append(f"IF D2324 < 10 THEN D{SB + self.pos + k} := D2324 + 48; ELSE D{SB + self.pos + k} := D2324 + 55; END_IF;")
            if k:
                self.code.append("D2322:D := D2322:D / 16;")
        self.model.append(("hex", dev))
        self.pos += 4

    def barcode(self, n=32):
        """D6500~ 條碼（長度 D2312）；長度 0 = NoRead。右補空白。"""
        self.code.append("IF D2312 > 0 THEN")
        for k in range(n):
            self.code.append(f"    IF D2312 > {k} THEN D{SB + self.pos + k} := D{BC + k}; ELSE D{SB + self.pos + k} := 32; END_IF;")
        self.code.append("ELSE")
        nr = "NoRead".ljust(n)
        for k in range(n):
            self.code.append(f"    D{SB + self.pos + k} := {ord(nr[k])};")
        self.code.append("END_IF;")
        self.model.append(("bar", n))
        self.pos += n

    def finish(self):
        self.lit("\r\n")
        self.code.append(f"D2320 := {self.pos};   (* 位元組數（含 CR LF） *)")
        return self.code, self.pos


def frame_hi():
    f = Frame()
    f.lit("HI;st=02;eq=MC-D002 ;ver=")
    f.dec("INT_TO_DINT(D7106)", 4)
    f.lit(";proto=01")
    return f


def frame_st():
    f = Frame()
    f.lit("ST;hb=");   f.dec("INT_TO_DINT(D7100)", 5, unsigned16=True)
    f.lit(";run=");    f.dec("INT_TO_DINT(D7105)", 1)
    f.lit(";sw=");     f.hex16("D7107")
    for tag, base in ((";t0=", 7110), (";t1=", 7116)):
        f.lit(tag)
        f.dec(f"INT_TO_DINT(D{base})", 4)
        for i in range(1, 6):
            f.dec(f"INT_TO_DINT(D{base + i})", 2)
    f.lit(";ct=");     f.dec("INT_TO_DINT(D7122)", 5)
    f.lit(";tq=");     f.dec("INT_TO_DINT(D7140)", 5)
    f.lit(";ang=");    f.dec("D7141:D", 8)
    f.lit(";tj=");     f.dec("INT_TO_DINT(D7143)", 1)
    f.lit(";aj=");     f.dec("INT_TO_DINT(D7144)", 1)
    f.lit(";hj=");     f.dec("INT_TO_DINT(D7145)", 1)
    f.lit(";tt=");     f.dec("INT_TO_DINT(D7146)", 5)
    f.lit(";stop=");   f.dec("INT_TO_DINT(D7147)", 4)
    f.lit(";cs=");     f.dec("INT_TO_DINT(D7148)", 1)
    f.lit(";n=");      f.dec("INT_TO_DINT(D222)", 1)
    return f


def frame_sc():
    f = Frame()
    f.lit("SC;rid=");  f.dec("D2264:D", 5)
    f.lit(";raw=");    f.barcode(32)
    return f


def pack(nbytes, base=SB, dst=6801):
    return [f"D{dst + w} := D{base + 2 * w} + D{base + 2 * w + 1} * 256;" for w in range((nbytes + 1) // 2)]


def const_words(data, dst):
    """把位元組字串寫成常數字（第 1 位元組在低位元組）"""
    out = [f"D{dst} := {len(data)};"]
    for w in range((len(data) + 1) // 2):
        lo = data[2 * w]
        hi = data[2 * w + 1] if 2 * w + 1 < len(data) else 0
        out.append(f"D{dst + 1 + w} := 16#{hi * 256 + lo:04X};")
    return out


# ---------------------------------------------------------------- 測試字串
SAMPLE_A = b"HO;hb=00124;code=09;b=0013;sn=SN20261112-000000017;wo=WO2611120001;op=OP00012   ;ts=20261112153002\r\n"
SAMPLE_B = b"HO;hb=40000;code=07;b=8a0F;sn=ABCDEFGHIJKLMNOPQRST;wo=W           ;op=          ;ts=00000000000000\r\n"
SAMPLE_BAD = b"HO;hb=1\r\nXX;hb=00124;code=09;b=0013;sn=SN20261112-000000017;wo=WO2611120001;op=OP00012   ;ts=20261112153002\r\n"
SAMPLE_TG = b"TG;rid=00017\r\n"
SAMPLE_SICK = b"\x02TEST-QR-0001\x03\r\n"
for s in (SAMPLE_A, SAMPLE_B):
    assert len(s) == 100, (len(s), s)

COLA_ON = b"\x02sMN mTCgateon\x03"
COLA_OFF = b"\x02sMN mTCgateoff\x03"


def ind(lines, n):
    return [(" " * n + l) if l else l for l in lines]


# ---------------------------------------------------------------- 連線狀態機
def conn_block(n, st, tmr, en_open, en_close, en_recv, ready, rbusy,
               done_open, done_close, done_recv, ctrl_open, ctrl_close, ctrl_recv, rbuf,
               openbit, recvbit, enable, ip_base, port_dev, local_port, on_connect, extra_drop, reconn):
    d_open = int(ctrl_open[1:])
    d_recv = int(ctrl_recv[1:])
    do_n = int(done_open[1:])
    dc_n = int(done_close[1:])
    dr_n = int(done_recv[1:])
    o1, o2, o3, o4 = (f"D{ip_base + i}" for i in range(4))
    L = []
    L.append(f"{en_open} := FALSE;  {en_close} := FALSE;  {en_recv} := FALSE;  {ready} := FALSE;")
    L.append(f"CASE {st} OF")
    L.append(f"0:  (* 未連線 *)")
    L.append(f"    {tmr} := 0;")
    L.append(f"    {rbusy} := FALSE;")
    L.append(f"    {reconn} := FALSE;")
    L.append(f"    IF {enable} THEN")
    L.append(f"        IF M2236 THEN   (* 模擬測試：不執行 socket 指令，直接當作已連線 *)")
    L.append(f"            {st} := 2;")
    L += ind(on_connect, 12)
    L.append(f"        ELSE")
    L.append(f"            D{d_open} := 16#8000;   (* 用控制資料的設定開啟 *)")
    L.append(f"            D{d_open + 2} := 16#0200;   (* TCP、socket 通訊、Active open *)")
    L.append(f"            D{d_open + 3} := {local_port};   (* 本機埠 *)")
    L.append(f"            IF {o3} >= 128 THEN D{d_open + 4} := ({o3} - 256) * 256 + {o4}; ELSE D{d_open + 4} := {o3} * 256 + {o4}; END_IF;")
    L.append(f"            IF {o1} >= 128 THEN D{d_open + 5} := ({o1} - 256) * 256 + {o2}; ELSE D{d_open + 5} := {o1} * 256 + {o2}; END_IF;")
    L.append(f"            D{d_open + 6} := {port_dev};")
    L.append(f"            {en_open} := TRUE;")
    L.append(f"            {st} := 1;")
    L.append(f"        END_IF;")
    L.append(f"    END_IF;")
    L.append(f"1:  (* 開啟中 *)")
    L.append(f"    IF {done_open} THEN")
    L.append(f"        IF M{do_n + 1} THEN")
    L.append(f"            D7163 := D{d_open + 1};  D7172 := {n * 10 + 1};   (* 開啟失敗 *)")
    L.append(f"            {en_close} := TRUE;  {tmr} := 0;  {st} := 3;")
    L.append(f"        ELSE")
    L.append(f"            {tmr} := 0;  {st} := 2;")
    L += ind(on_connect, 12)
    L.append(f"        END_IF;")
    L.append(f"    ELSIF M2236 THEN")
    L.append(f"        {tmr} := 0;  {st} := 0;   (* 進入模擬測試：直接回未連線（模擬器的 SOCOPEN 不會完成） *)")
    L.append(f"    ELSIF NOT {enable} THEN")
    L.append(f"        {en_close} := TRUE;  {tmr} := 0;  {st} := 3;   (* 改回 Modbus：關閉後經 4 回 0 *)")
    L.append(f"    ELSE")
    L.append(f"        IF M950 THEN {tmr} := {tmr} + 1; END_IF;")
    L.append(f"        IF {tmr} >= 100 THEN   (* 10 秒沒完成：當作開啟失敗 *)")
    L.append(f"            D7172 := {n * 10 + 1};")
    L.append(f"            {en_close} := TRUE;  {tmr} := 0;  {st} := 3;")
    L.append(f"        END_IF;")
    L.append(f"    END_IF;")
    L.append(f"2:  (* 已連線 *)")
    L.append(f"    IF M950 AND ({tmr} < 32000) THEN {tmr} := {tmr} + 1; END_IF;")
    L.append(f"    IF {enable} AND NOT M2236 AND NOT {openbit} THEN D7172 := {n * 10 + 5}; END_IF;   (* 對方關閉 *)")
    L += ind(extra_drop[1], 4)
    L.append(f"    IF NOT {enable} OR (NOT M2236 AND NOT {openbit}) OR {reconn}{extra_drop[0]} THEN")
    L.append(f"        {reconn} := FALSE;  {tmr} := 0;")
    L.append(f"        IF M2236 THEN {st} := 4; ELSE {en_close} := TRUE;  {st} := 3; END_IF;")
    L.append(f"    END_IF;")
    L.append(f"3:  (* 關閉中（最多等 5 秒） *)")
    L.append(f"    IF M950 THEN {tmr} := {tmr} + 1; END_IF;")
    L.append(f"    IF {done_close} OR ({tmr} >= 50) THEN {tmr} := 0;  {st} := 4; END_IF;")
    L.append(f"4:  (* 等 3 秒再重連 *)")
    L.append(f"    {rbusy} := FALSE;")
    L.append(f"    IF M950 THEN {tmr} := {tmr} + 1; END_IF;")
    L.append(f"    IF ({tmr} >= 30) OR NOT {enable} THEN {tmr} := 0;  {st} := 0; END_IF;")
    L.append(f"ELSE")
    L.append(f"    {st} := 0;")
    L.append(f"END_CASE;")
    L.append(f"IF ({st} = 2) AND NOT M2236 AND {recvbit} AND NOT {rbusy} THEN {en_recv} := TRUE;  {rbusy} := TRUE; END_IF;")
    L.append(f"SP_SOCOPEN({en_open}, {U0_TOKEN}, {n}, {ctrl_open}, {done_open});")
    L.append(f"SP_SOCCLOSE({en_close}, {U0_TOKEN}, {n}, {ctrl_close}, {done_close});")
    L.append(f"SP_SOCRCV({en_recv}, {U0_TOKEN}, {n}, {ctrl_recv}, {rbuf}, {done_recv});")
    L.append(f"IF {done_recv} THEN")
    L.append(f"    {rbusy} := FALSE;")
    L.append(f"    IF M{dr_n + 1} THEN D7163 := D{d_recv + 1};  D7172 := {n * 10 + 3}; ELSE {ready} := TRUE; END_IF;")
    L.append(f"END_IF;")
    return L


def byte_of(word_expr_dint, idx, out_dev):
    return [f"IF ({idx} MOD 2) = 0 THEN {out_dev} := DINT_TO_INT({word_expr_dint} MOD 256); ELSE {out_dev} := DINT_TO_INT({word_expr_dint} / 256); END_IF;"]


def gen_p16():
    L = []
    L += """(* ============================================================
   P16_Sock  中控 socket 傳輸（輸入側，P15_MES_In 之前執行）  v3.14
   協定：docs/SOCKET_PROTOCOL_v1.md。本檔由 tools/gen_sock_st.py 產生，請改產生器再重新產生。
   D236 = 0：Modbus（v3.13 原樣，本區塊不動任何既有軟元件）；D236 = 1：socket。
     D236 只在 D100 = 0（停止）時生效，生效值放 M2190（D7171 = 0/1 給中控與 HMI 看）。
   socket 時，HO 訊框解開寫進 D7000~D7029（原本由中控用 Modbus 寫的同一區），
     P15 的心跳、Remote/Local、放行、ACK、校時邏輯照舊；中控此時不要再用 Modbus 寫 D7000~D7029。
   連線（都用 SP.SOCOPEN 控制資料 8000H 開啟，參數「外部設備連接設定」不要佔用這幾個連線號碼）：
     連線 1：中控 D243~D246（IP 四段）:D247，預設 192.168.1.200:9500，本機埠 4001
     連線 2：SICK 觸發埠 D237~D240:D241，預設 192.168.1.25:2111，本機埠 4002（D248=0 且 D241<>D242 才用）
     連線 3：SICK 資料埠 D237~D240:D242，預設 192.168.1.25:2112，本機埠 4003
   D248 SICK 觸發方式 0 = CoLa-A「sMN mTCgateon/off」 1 = 送 1 個 STX（0x02，舊中控 ScannerAdapter 的作法）
   D249 SICK 讀取逾時 0.1 秒（預設 30 = 3 秒）
   狀態：D7160 中控連線（0 未連 1 開啟中 2 已連線 3 關閉中 4 等重連） D7161 收到 HO 筆數 D7162 格式錯誤次數
         D7163 最後錯誤碼（指令完成狀態） D7164/D7165 SICK 觸發/資料連線狀態 D7166 SC 送出 D7167 NoRead
         D7168 ST 送出 D7169 收到 TG D7170 距上次 HO 0.1 秒 D7171 生效傳輸 D7172 最後錯誤來源
         （n1 開啟失敗 n2 送出失敗 n3 接收失敗 14 HO 逾時 n5 對方關閉，n = 連線號碼） D7173 HI 送出 D7174 最後條碼長度
   模擬測試（GX Simulator3 不能跑 socket）：M50 模擬模式 + M2235 ON → M2236，不執行 socket 指令、連線直接當作已連上；
     M2238 載入 HO 範例 A、M2185 範例 B（hb=40000、b 含小寫、ts 全 0）、M2189 兩筆錯誤、M2188/M2187 範例 A 分兩段、
     M2184 TG + 範例 B 同一包、M2239 TG；M2186 模擬 SICK 回條碼；M2182 ON = 模擬測試時也計 HO 5 秒逾時（預設不計）。
     開啟中超過 10 秒沒完成當作開啟失敗（D7172 = n1）；開啟中改回 Modbus 會先關閉，進入模擬測試直接回 0。送出的字串留在 D6800（長度）D6801~（D6600~ 每字 1 字元）。
   ============================================================ *)
""".splitlines()

    L += """
(* ---- 生效傳輸 ---- *)
IF D100 = 0 THEN
    M2190 := (D236 = 1);
END_IF;
IF M2190 THEN D7171 := 1; ELSE D7171 := 0; END_IF;
M2236 := M50 AND M2235 AND M2190;
M2198 := (D248 = 0) AND (D241 <> D242);   (* 觸發用獨立連線 2 *)

(* socket 狀態：M2240~ 開啟完成（SD10680）、M2256~ 收到資料（SD10682），bit0 = 連線 1 *)
K4M2240 := SD10680;
K4M2256 := SD10682;

(* ================= 連線 1：中控 ================= *)""".splitlines()
    L += conn_block(1, "D7160", "D2261", "M2209", "M2211", "M2213", "M2215", "M2212",
                    "M2200", "M2202", "M2206", "D2200", "D2210", "D2214", "D3000",
                    "M2240", "M2256", "M2190", 243, "D247", 4001,
                    ["M2230 := TRUE;   (* 連上後送一次 HI *)"],
                    (" OR M2183", ["M2183 := (D2261 >= 50) AND (NOT M2236 OR M2182);   (* 5 秒沒收到 HO；模擬測試時要 M2182 ON 才計 *)",
                                   "IF M2183 THEN D7172 := 14; END_IF;"]),
                    "M2307")
    L.append("D7170 := D2261;")

    L.append("")
    L.append("(* ---- 模擬測試：把範例字串放進接收緩衝 ---- *)")
    L.append("IF M2236 AND (D7160 = 2) THEN")
    tests = [("M2238", SAMPLE_A, "HO 範例 A"), ("M2185", SAMPLE_B, "HO 範例 B"),
             ("M2189", SAMPLE_BAD, "錯誤：太短 + 開頭不是 HO"),
             ("M2188", SAMPLE_A[:51], "範例 A 前 51 位元組"), ("M2187", SAMPLE_A[51:], "範例 A 後 49 位元組"),
             ("M2184", SAMPLE_TG + SAMPLE_B, "TG + 範例 B 同一包"), ("M2239", SAMPLE_TG, "TG")]
    first = True
    for dev, data, note in tests:
        L.append(f"    {'IF' if first else 'ELSIF'} {dev} THEN   (* {note} *)")
        L += ind(const_words(data, 3000), 8)
        first = False
    L.append("    END_IF;")
    L.append("    IF M2238 OR M2185 OR M2189 OR M2188 OR M2187 OR M2184 OR M2239 THEN M2215 := TRUE; END_IF;")
    L.append("END_IF;")
    L.append("M2238 := FALSE;  M2185 := FALSE;  M2189 := FALSE;  M2188 := FALSE;  M2187 := FALSE;  M2184 := FALSE;  M2239 := FALSE;")

    L.append("")
    L.append("(* ---- 收到的資料逐位元組處理：LF 結束一行（去掉前面的 CR） ---- *)")
    L.append("IF M2215 THEN")
    body = []
    body.append("D2290 := 0;")
    body.append("WHILE (D2290 < D3000) AND (D2290 < 2046) DO")
    body.append("    Z0 := D2290 / 2;")
    body.append("    D2292:D := INT_TO_DINT(D3001Z0);")
    body.append("    IF D2292:D < 0 THEN D2292:D := D2292:D + 65536; END_IF;")
    body += ind(byte_of("D2292:D", "D2290", "D2291"), 4)
    body.append("    IF D2291 = 10 THEN")
    body.append("        IF D2294 > 0 THEN")
    body.append("            Z1 := D2294 - 1;")
    body.append("            IF D4100Z1 = 13 THEN D2294 := D2294 - 1; END_IF;")
    body.append("        END_IF;")
    line = []
    line.append("IF M2217 OR (D2294 > 0) THEN")
    line.append("    M2218 := NOT M2217 AND (D2294 = 98) AND (D4100 = 72) AND (D4101 = 79) AND (D4102 = 59);   (* HO; *)")
    line.append("    M2220 := NOT M2217 AND (D2294 = 12) AND (D4100 = 84) AND (D4101 = 71) AND (D4102 = 59)")
    line.append("             AND (D4103 = 114) AND (D4104 = 105) AND (D4105 = 100) AND (D4106 = 61);   (* TG;rid= *)")
    line.append("    IF M2218 THEN")
    line += ind(gen_ho_validate(), 8)
    line.append("        IF M2218 THEN")
    line += ind(gen_ho_write(), 12)
    line.append("            IF D7161 >= 32767 THEN D7161 := 0; ELSE D7161 := D7161 + 1; END_IF;")
    line.append("            D2261 := 0;   (* HO 逾時計時重來 *)")
    line.append("        ELSE")
    line.append("            IF D7162 >= 32767 THEN D7162 := 0; ELSE D7162 := D7162 + 1; END_IF;")
    line.append("        END_IF;")
    line.append("    ELSIF M2220 THEN")
    for k in range(7, 12):
        line.append(f"        IF (D{LB + k} < 48) OR (D{LB + k} > 57) THEN M2220 := FALSE; END_IF;")
    line.append("        IF M2220 THEN")
    line.append("            IF D7169 >= 32767 THEN D7169 := 0; ELSE D7169 := D7169 + 1; END_IF;")
    line.append("            IF (D2310 = 0) AND NOT M2234 THEN   (* SICK 讀取中就忽略 *)")
    line += ind(gen_dec(7, 5, "D2264:D"), 16)
    line.append("                M2234 := TRUE;")
    line.append("            END_IF;")
    line.append("        ELSE")
    line.append("            IF D7162 >= 32767 THEN D7162 := 0; ELSE D7162 := D7162 + 1; END_IF;")
    line.append("        END_IF;")
    line.append("    ELSE")
    line.append("        IF D7162 >= 32767 THEN D7162 := 0; ELSE D7162 := D7162 + 1; END_IF;")
    line.append("    END_IF;")
    line.append("END_IF;")
    body += ind(line, 8)
    body.append("        D2294 := 0;")
    body.append("        M2217 := FALSE;")
    body.append("    ELSIF D2294 < 120 THEN")
    body.append("        Z1 := D2294;")
    body.append("        D4100Z1 := D2291;")
    body.append("        D2294 := D2294 + 1;")
    body.append("    ELSE")
    body.append("        M2217 := TRUE;   (* 一行太長，等到 LF 整行丟掉 *)")
    body.append("    END_IF;")
    body.append("    D2290 := D2290 + 1;")
    body.append("END_WHILE;")
    L += ind(body, 4)
    L.append("END_IF;")
    L.append("IF D7160 <> 2 THEN D2294 := 0;  M2217 := FALSE; END_IF;   (* 斷線時丟掉半行 *)")

    # SICK
    L.append("")
    L.append("(* ================= SICK 條碼機 ================= *)")
    L.append("(* 連線 2：觸發埠（只在 M2198 時用） *)")
    L += conn_block(2, "D7164", "D2300", "M2328", "M2329", "M2331", "M2334", "M2332",
                    "M2320", "M2322", "M2326", "D2220", "D2230", "D2234", "D4300",
                    "M2241", "M2257", "(M2190 AND M2198)", 237, "D241", 4002, [], ("", []), "M2308")
    L.append("(* 連線 3：資料埠 *)")
    L += conn_block(3, "D7165", "D2301", "M2348", "M2349", "M2351", "M2354", "M2352",
                    "M2340", "M2342", "M2346", "D2240", "D2250", "D2254", "D5400",
                    "M2242", "M2258", "M2190", 237, "D242", 4003, [], ("", []), "M2309")
    L.append("(* 連線 2 收到的是 CoLa 回覆（sAN mTCgateon 1），讀出來丟掉即可 *)")
    L.append("")
    L.append("IF M2236 AND M2186 AND (D7165 = 2) THEN   (* 模擬 SICK 回條碼 *)")
    L += ind(const_words(SAMPLE_SICK, 5400), 4)
    L.append("    M2354 := TRUE;")
    L.append("END_IF;")
    L.append("M2186 := FALSE;")
    L.append("")
    L.append("M2197 := (D7165 = 2) AND (NOT M2198 OR (D7164 = 2));   (* SICK 可用 *)")
    L.append("")
    L.append("(* ---- 資料埠逐位元組：STX 開始、ETX/CR/LF 結束；沒有 STX 的可見字元也直接收 ---- *)")
    L.append("IF M2354 THEN")
    b = []
    b.append("D2315 := 0;")
    b.append("WHILE (D2315 < D5400) AND (D2315 < 2046) DO")
    b.append("    Z2 := D2315 / 2;")
    b.append("    D2318:D := INT_TO_DINT(D5401Z2);")
    b.append("    IF D2318:D < 0 THEN D2318:D := D2318:D + 65536; END_IF;")
    b += ind(byte_of("D2318:D", "D2315", "D2316"), 4)
    b.append("    IF (D2310 = 1) AND NOT M2301 THEN")
    b.append("        IF D2316 = 2 THEN")
    b.append("            M2299 := TRUE;  D2312 := 0;")
    b.append("        ELSIF (D2316 = 3) OR (D2316 = 13) OR (D2316 = 10) THEN")
    b.append("            IF M2299 THEN M2301 := TRUE;  M2299 := FALSE; END_IF;")
    b.append("        ELSIF (D2316 >= 32) AND (D2316 <= 126) THEN")
    b.append("            M2299 := TRUE;")
    b.append("            IF (D2316 = 59) OR (D2316 = 61) THEN D2316 := 32; END_IF;   (* ';' '=' 會破壞 SC 訊框，換成空白（同中控 _clean） *)")
    b.append("            IF D2312 < 32 THEN")
    b.append("                Z3 := D2312;")
    b.append(f"                D{BC}Z3 := D2316;")
    b.append("                D2312 := D2312 + 1;")
    b.append("            END_IF;")
    b.append("        END_IF;")
    b.append("    END_IF;")
    b.append("    D2315 := D2315 + 1;")
    b.append("END_WHILE;")
    L += ind(b, 4)
    L.append("END_IF;")
    L.append("")
    L.append("(* ---- 讀取步序 D2310：0 待命 1 等條碼 2 關閉觸發 3 送 SC ---- *)")
    L += """CASE D2310 OF
0:  IF M2234 THEN
        M2234 := FALSE;
        D2312 := 0;  M2299 := FALSE;  M2301 := FALSE;  D2311 := 0;
        IF M2197 THEN
            M2300 := TRUE;   (* 送觸發 *)
            D2310 := 1;
        ELSE
            D2310 := 3;      (* SICK 沒連上：直接回 NoRead *)
        END_IF;
    END_IF;
1:  IF M950 THEN D2311 := D2311 + 1; END_IF;
    IF M2301 OR (D2311 >= D249) OR NOT M2197 THEN D2310 := 2; END_IF;
2:  IF (D248 = 0) AND M2197 THEN M2302 := TRUE; END_IF;   (* CoLa：送 gateoff *)
    D2310 := 3;
3:  IF NOT M2301 OR (D2312 = 0) THEN
        D2312 := 0;
        IF D7167 >= 32767 THEN D7167 := 0; ELSE D7167 := D7167 + 1; END_IF;
    END_IF;
    D7174 := D2312;
    IF D7160 = 2 THEN M2232 := TRUE; END_IF;   (* P76 送 SC *)
    D2310 := 0;
ELSE
    D2310 := 0;
END_CASE;
IF NOT M2190 THEN D2310 := 0;  M2234 := FALSE;  M2300 := FALSE;  M2302 := FALSE; END_IF;

(* ---- 觸發訊息送出（連線 2 或 3） ---- *)
M2330 := FALSE;  M2350 := FALSE;
IF M2300 OR M2302 THEN
    IF M2198 THEN
        IF (D7164 = 2) AND NOT M2333 THEN""".splitlines()

    def trig_build(dst):
        out = []
        out.append("IF M2300 THEN")
        out.append("    IF D248 = 0 THEN")
        out += ind(const_words(COLA_ON, dst), 8)
        out.append("    ELSE")
        out += ind(const_words(b"\x02", dst), 8)
        out.append("    END_IF;")
        out.append("    M2300 := FALSE;")
        out.append("ELSE")
        out += ind(const_words(COLA_OFF, dst), 4)
        out.append("    M2302 := FALSE;")
        out.append("END_IF;")
        return out

    L += ind(trig_build(6900), 12)
    L += """            IF NOT M2236 THEN M2330 := TRUE;  M2333 := TRUE; END_IF;
        ELSIF D7164 <> 2 THEN
            M2300 := FALSE;  M2302 := FALSE;
        END_IF;
    ELSE
        IF (D7165 = 2) AND NOT M2353 THEN""".splitlines()
    L += ind(trig_build(6950), 12)
    L += f"""            IF NOT M2236 THEN M2350 := TRUE;  M2353 := TRUE; END_IF;
        ELSIF D7165 <> 2 THEN
            M2300 := FALSE;  M2302 := FALSE;
        END_IF;
    END_IF;
END_IF;
IF D7164 <> 2 THEN M2333 := FALSE; END_IF;
IF D7165 <> 2 THEN M2353 := FALSE; END_IF;
SP_SOCSND(M2330, {U0_TOKEN}, 2, D2232, D6900, M2324);
SP_SOCSND(M2350, {U0_TOKEN}, 3, D2252, D6950, M2344);
IF M2324 THEN
    M2333 := FALSE;
    IF M2325 THEN D7163 := D2233;  D7172 := 22;  M2308 := TRUE; END_IF;
END_IF;
IF M2344 THEN
    M2353 := FALSE;
    IF M2345 THEN D7163 := D2253;  D7172 := 32;  M2309 := TRUE; END_IF;
END_IF;
""".splitlines()
    return L


def gen_p76():
    L = []
    L += """(* ============================================================
   P76_Sock_Out  中控 socket 傳輸（輸出側，P75_MES_Out 之後執行）  v3.14
   本檔由 tools/gen_sock_st.py 產生。D236 = 0（M2190 OFF）時什麼都不做。
   連上後送一次 HI；每 1 秒以及 D7107 或 D7105 變化時送 ST；SICK 讀完送 SC。一次只送一筆，等完成再送下一筆。
   組字串：D6600~ 每字 1 字元（長度 D2320）→ D6800 長度、D6801~ 每字 2 字元（第 1 字元在低位元組）
   ============================================================ *)

M2303 := SM412 AND NOT M2304;   (* 每秒一次 *)
M2304 := SM412;
IF D7160 <> 2 THEN
    M2230 := FALSE;  M2231 := FALSE;  M2232 := FALSE;  M2233 := FALSE;
ELSIF M2303 OR (D7107 <> D2262) OR (D7105 <> D2263) THEN
    M2231 := TRUE;
END_IF;

M2305 := FALSE;
IF (D7160 = 2) AND NOT M2233 THEN
    D2325 := 0;
    IF M2230 THEN   (* HI *)""".splitlines()
    for name, fr, flag, extra in (("HI", frame_hi(), "M2230", []),
                                  ("SC", frame_sc(), "M2232", []),
                                  ("ST", frame_st(), "M2231", ["D2262 := D7107;  D2263 := D7105;"])):
        code, nbytes = fr.finish()
        if name == "SC":
            L.append("    ELSIF M2232 THEN   (* SC *)")
        elif name == "ST":
            L.append("    ELSIF M2231 THEN   (* ST *)")
        L += ind(code, 8)
        L += ind(extra, 8)
        L.append(f"        {flag} := FALSE;")
        L.append(f"        D2325 := {({'HI': 1, 'ST': 2, 'SC': 3})[name]};")
        globals()[f"LEN_{name}"] = nbytes
    L.append("    END_IF;")
    L.append("    IF D2325 <> 0 THEN")
    L += ind(pack(max(LEN_HI, LEN_ST, LEN_SC)), 8)
    L.append("        D6800 := D2320;")
    L.append("        D2326 := D2325;")
    L.append("        IF M2236 THEN")
    L.append("            M2306 := TRUE;   (* 模擬測試：當作送出完成 *)")
    L.append("        ELSE")
    L.append("            M2305 := TRUE;  M2233 := TRUE;")
    L.append("        END_IF;")
    L.append("    END_IF;")
    L.append("END_IF;")
    L += f"""SP_SOCSND(M2305, {U0_TOKEN}, 1, D2212, D6800, M2204);
IF M2204 THEN
    M2233 := FALSE;
    IF M2205 THEN
        D7163 := D2213;  D7172 := 12;  M2307 := TRUE;   (* 送出失敗：P16 關閉後重連 *)
    ELSE
        M2306 := TRUE;
    END_IF;
END_IF;
IF M2306 THEN
    M2306 := FALSE;
    CASE D2326 OF
    1: IF D7173 >= 32767 THEN D7173 := 0; ELSE D7173 := D7173 + 1; END_IF;
    2: IF D7168 >= 32767 THEN D7168 := 0; ELSE D7168 := D7168 + 1; END_IF;
    3: IF D7166 >= 32767 THEN D7166 := 0; ELSE D7166 := D7166 + 1; END_IF;
    END_CASE;
END_IF;
""".splitlines()
    return L


# ---------------------------------------------------------------- 自我檢查
def py_parse_ho(line, m2091=False):
    """Python 版的 HO 解析（跟產生的 ST 同規則），回傳 dict 或 None"""
    if len(line) != 98 or not line.startswith(b"HO;"):
        return None
    for pos, ch in LIT.items():
        if line[pos] != ord(ch):
            return None
    for name, (p, n, kind) in FLD.items():
        for k in range(p, p + n):
            x = line[k]
            if kind == "D" and not 48 <= x <= 57:
                return None
            if kind == "H" and chr(x) not in "0123456789ABCDEFabcdef":
                return None
            if kind == "P" and not 32 <= x <= 126:
                return None
    g = lambda nm: line[FLD[nm][0]:FLD[nm][0] + FLD[nm][1]]
    hb = int(g("hb"))
    if hb > 65535:
        return None
    out = {7000: hb, 7001: int(g("code")), 7002: int(g("b"), 16)}
    for nm, dev in (("sn", 7003), ("wo", 7013), ("op", 7019)):
        s = g(nm)
        for w in range(len(s) // 2):
            a, b = s[2 * w], s[2 * w + 1]
            out[dev + w] = (a + b * 256) if m2091 else (a * 256 + b)
    ts = g("ts").decode()
    if ts != "0" * 14:
        for dev, v in zip(range(7024, 7030), (ts[0:4], ts[4:6], ts[6:8], ts[8:10], ts[10:12], ts[12:14])):
            out[dev] = int(v)
    return out


def self_check():
    assert LEN_HI == 40 and LEN_SC == 51 and LEN_ST == 137, (LEN_HI, LEN_SC, LEN_ST)
    a = py_parse_ho(SAMPLE_A[:-2])
    assert a[7000] == 124 and a[7001] == 9 and a[7002] == 0x13 and a[7024] == 2026 and a[7029] == 2
    assert a[7003] == 0x534E
    b = py_parse_ho(SAMPLE_B[:-2])
    assert b[7000] == 40000 and b[7002] == 0x8A0F and 7024 not in b
    assert py_parse_ho(SAMPLE_BAD[9:-2]) is None
    print("self check OK", LEN_HI, LEN_ST, LEN_SC)


def main():
    p16 = gen_p16()
    p76 = gen_p76()
    self_check()
    if "--check" in sys.argv:
        return
    for name, lines in (("P16_Sock.st", p16), ("P76_Sock_Out.st", p76)):
        with open(os.path.join(OUT_DIR, name), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
        print("wrote", name, len(lines), "lines")


if __name__ == "__main__":
    main()
