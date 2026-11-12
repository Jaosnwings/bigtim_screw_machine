(* ============================================================
   P70_Output_Data  內部 M → 實體 Y（只有這裡寫 Y）、生產資料、HMI 燈號  v3.2
   v3.2：Y 對應改為現場點位表；每個 Y 加上 HMI 強制（P45 的 M870~M883）
   ============================================================ *)
IF M50 THEN
    Y0 := FALSE;  Y1 := FALSE;  Y2 := FALSE;  Y3 := FALSE;
    Y4 := FALSE;  Y5 := FALSE;  Y6 := FALSE;  Y7 := FALSE;
    Y10 := FALSE; Y11 := FALSE; Y12 := FALSE; Y13 := FALSE;
    Y14 := FALSE; Y15 := FALSE;
ELSE
    Y0  := M400 OR M870;   (* 塔燈紅 *)
    Y1  := M401 OR M871;   (* 塔燈綠 *)
    Y2  := M402 OR M872;   (* 蜂鳴器 *)
    (* Y3 治具停止：HMI 強制＝反轉程式輸出（11-11 現場要求：程式保持 ON 時可在手動停止中強制 OFF）。
       急停、切自動、HMI 斷線會解除強制（M820 OFF），Y3 回到程式值 *)
    IF M873 THEN
        Y3 := NOT M403;
    ELSE
        Y3 := M403;
    END_IF;
    Y4  := M404;           (* 螺絲機在安全位置（不可強制） *)
    Y5  := M405 OR M875;   (* 治具啟動／前進 *)
    Y6  := M406 OR M876;   (* 預留：過渡期同紅燈 *)
    Y7  := M407;           (* 預留 *)
    Y10 := M410 OR M878;   (* RC75 RETURN       XB00 *)
    Y11 := M411 OR M879;   (* RC75 RESET        XB01 *)
    Y12 := M412 OR M880;   (* RC75 CYCLE START  XB02 *)
    Y13 := M413 OR M881;   (* RC75 送螺絲       XB03 *)
    Y14 := (M414 AND NOT M883) OR M882;   (* RC75 TABLE 1 XB04；v3.10：強制 Y15 時程式的 Y14 讓開，才會是 TABLE 2 *)
    Y15 := M415 OR M883;   (* RC75 TABLE 2      XB05（第 2 點時 ON；v3.10 可強制） *)
END_IF;

(* ---- HMI 顯示燈 ---- *)
M205 := M11;          (* RC75 READY *)
M206 := M12;          (* RC75 HOME *)
M207 := NOT M12;      (* Z 不在原點（取代 v3.1 循環中） *)
M208 := M5;           (* 治具水平待命 *)
M209 := M10;          (* 安全光柵無遮斷 *)
M210 := M7;           (* 啟動鈕 *)
M211 := M6;           (* 治具停止 *)
M212 := (D100 = 12) OR (D100 = 14);   (* 等待中控放行 *)
M213 := M2113;                        (* 完工待收 *)

(* HMI 狀態文字 D2050：0 停止 1 待機中 2 加工中 3 等待中控 4 異常 5 手動 6 強制中 7 光柵暫停 *)
IF M203 OR M154 THEN
    D2050 := 4;
ELSIF M821 THEN
    D2050 := 6;
ELSIF M201 THEN
    D2050 := 5;
ELSIF M845 THEN
    D2050 := 7;
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
    D230 := 0;  D231 := 0;  D232 := 0;  D233 := 0;
END_IF;

(* ---- 良率 0.1% ---- *)
IF D304:D > 0 THEN
    D306 := DINT_TO_INT(D300:D * 1000 / D304:D);
ELSE
    D306 := 0;
END_IF;
