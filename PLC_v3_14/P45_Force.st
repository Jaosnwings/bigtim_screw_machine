(* ============================================================
   P45_Force  HMI 畫面 5 的 IO 強制（v3.2 新增）
   強制要求 M800~M813 依序 = Y0,Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y10,Y11,Y12,Y13,Y14,Y15（HMI 寫）
   強制有效 M870~M883 同順序（P70 OR 進 Y）
   只在手動模式、停止中、急停正常、不在復歸、HMI 心跳正常時允許；不允許 → 全部清 0
   切換型（Y0,Y1,Y2,Y3,Y6,Y14,Y15）：D228 自動解除；按住型（Y5,Y10,Y11,Y12,Y13）：單次 D229 上限，Y12 再限 D225
   Y4 安全位置、Y7 永遠不能強制（v3.10：Y15 開放）。只做強制 ON，程式輸出不會被壓掉
   和 GX Works3 Forced I/O 不同：走程式，急停／切模式／HMI 斷線／逾時都會解除
   ============================================================ *)

(* ---- HMI 心跳：HMI 每 0.5 秒翻轉 M830，D227 沒變化 → M831 斷線 ---- *)
IF M830 <> M833 THEN
    M833 := M830;
    D2003 := 0;
ELSIF M950 AND (D2003 < 32000) THEN
    D2003 := D2003 + 1;
END_IF;
M831 := D2003 >= D227;

(* ---- 允許條件 ---- *)
M820 := M201 AND M0 AND NOT M200 AND (D110 = 0) AND NOT M831;

(* 不能強制的點 *)
M804 := FALSE;   (* Y4 *)
M807 := FALSE;   (* Y7 未接 *)
(* v3.10：Y15（M813）開放強制，切換型 *)
M814 := FALSE;
M815 := FALSE;

IF NOT M820 OR M832 THEN
    K4M800 := 0;
    M832 := FALSE;
END_IF;

(* ---- 切換型自動解除：強制內容有變就重新計時 ---- *)
IF K4M800 <> D538 THEN
    D538 := K4M800;
    D537 := 0;
    D539 := 0;
    D540 := 0;
END_IF;
IF M800 OR M801 OR M802 OR M803 OR M806 OR M812 OR M813 THEN
    IF M950 AND (D537 < 32000) THEN D537 := D537 + 1; END_IF;
    IF D537 >= D228 THEN
        M800 := FALSE;  M801 := FALSE;  M802 := FALSE;  M803 := FALSE;  M806 := FALSE;  M812 := FALSE;  M813 := FALSE;
    END_IF;
ELSE
    D537 := 0;
END_IF;

(* ---- 按住型單次上限 ---- *)
IF M805 OR M808 OR M809 OR M810 OR M811 THEN
    IF M950 AND (D539 < 32000) THEN D539 := D539 + 1; END_IF;
    IF D539 >= D229 THEN
        M805 := FALSE;  M808 := FALSE;  M809 := FALSE;  M810 := FALSE;  M811 := FALSE;
    END_IF;
ELSE
    D539 := 0;
END_IF;
IF M810 THEN
    IF M950 AND (D540 < 32000) THEN D540 := D540 + 1; END_IF;
    IF D540 >= D225 THEN M810 := FALSE; END_IF;   (* CYCLE START 最多 D225 *)
ELSE
    D540 := 0;
END_IF;

(* ---- 互鎖 ---- *)
M865 := M11 AND M12 AND NOT M13 AND M10 AND NOT M808 AND NOT M811;   (* Y12 *)
M866 := NOT M810 AND NOT M811;                                                   (* Y10 *)
M867 := NOT M810 AND NOT M808;                                                   (* Y13 *)
M868 := M12 AND M10;                                                             (* Y5 *)

(* ---- 強制有效 ---- *)
M870 := M820 AND M800;            (* Y0 *)
M871 := M820 AND M801;            (* Y1 *)
M872 := M820 AND M802;            (* Y2 *)
M873 := M820 AND M803;            (* Y3 *)
M874 := FALSE;                    (* Y4 不可強制 *)
M875 := M820 AND M805 AND M868;   (* Y5 *)
M876 := M820 AND M806;            (* Y6 *)
M877 := FALSE;                    (* Y7 *)
M878 := M820 AND M808 AND M866;   (* Y10 *)
M879 := M820 AND M809;            (* Y11 *)
M880 := M820 AND M810 AND M865;   (* Y12 *)
M881 := M820 AND M811 AND M867;   (* Y13 *)
M882 := M820 AND M812;            (* Y14 *)
M883 := M820 AND M813;            (* Y15（v3.10 開放強制） *)

M821 := K4M800 <> 0;              (* 任一強制中：所有頁標題列顯示 *)
