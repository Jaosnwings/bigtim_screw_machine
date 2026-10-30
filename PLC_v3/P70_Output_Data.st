(* ============================================================
   P70_Output_Data  內部 M → 實體 Y（只有這裡寫 Y）、生產資料、HMI 燈號  v3
   ============================================================ *)
IF M50 THEN
    Y0 := FALSE;  Y1 := FALSE;  Y2 := FALSE;  Y3 := FALSE;
    Y4 := FALSE;  Y5 := FALSE;  Y6 := FALSE;  Y7 := FALSE;
    Y10 := FALSE; Y11 := FALSE; Y12 := FALSE; Y13 := FALSE;
    Y14 := FALSE; Y15 := FALSE;
ELSE
    Y0  := M400;   (* 機台停止 → 治具 VB1-X0 *)
    Y1  := M401;   (* 機台待機 → 治具 VB1-X1 *)
    Y2  := FALSE;  (* 預留 *)
    Y3  := FALSE;  (* 預留 *)
    Y4  := M404;   (* 塔燈綠 *)
    Y5  := M405;   (* 塔燈黃 *)
    Y6  := M406;   (* 塔燈紅 *)
    Y7  := M407;   (* 蜂鳴器 *)
    Y10 := M410;   (* RC75 RETURN       XB00 *)
    Y11 := M411;   (* RC75 RESET        XB01 *)
    Y12 := M412;   (* RC75 CYCLE START  XB02 *)
    Y13 := M413;   (* RC75 送螺絲       XB03 *)
    Y14 := M414;   (* RC75 TABLE bit0   XB04 *)
    Y15 := M415;   (* RC75 TABLE bit1   XB05 *)
END_IF;

(* ---- HMI 顯示燈 ---- *)
M205 := M10;   (* RC75 READY *)
M206 := M11;   (* RC75 原位置 *)
M207 := M13;   (* RC75 循環中 *)
M208 := M5;    (* 治具啟動要求（治具夾好） *)
M209 := M4;    (* RC75 扭力 NG *)
M210 := M7;    (* RC75 浮鎖 NG *)
M211 := M6;    (* v3 治具停止要求 *)
M212 := (D100 = 12) OR (D100 = 14);   (* v3 等待中控放行 *)
M213 := (D100 = 55);                  (* v3 等待中控收完工 *)

(* v3 HMI 狀態文字 D2050：0 停止 1 待機中 2 加工中 3 等待中控 4 異常 5 手動 *)
IF M203 THEN
    D2050 := 4;
ELSIF M201 THEN
    D2050 := 5;
ELSIF M212 OR M213 THEN
    D2050 := 3;
ELSIF M200 AND (D100 = 10) THEN
    D2050 := 1;
ELSIF M200 THEN
    D2050 := 2;
ELSE
    D2050 := 0;
END_IF;

(* ---- 計數清除（停止中才可） ---- *)
IF M130 AND NOT M200 THEN
    D300:D := 0;
    D302:D := 0;
    D304:D := 0;
END_IF;

(* ---- 良率 0.1% ---- *)
IF D304:D > 0 THEN
    D306 := DINT_TO_INT(D300:D * 1000 / D304:D);
ELSE
    D306 := 0;
END_IF;
