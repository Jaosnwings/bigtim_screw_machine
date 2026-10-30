(* ============================================================
   P40_Reset_Manual  復歸程序 D110 與手動輸出  v3.1（與筆電版 v2 相同，僅紅燈含 M154）
   復歸：1 送 RESET 0.5 秒 → 2 等 0.5 秒 → 3 送 RETURN 直到原位置
   D501 = 復歸步經過時間 (0.1s)
   ============================================================ *)

IF D110 <> D111 THEN
    D501 := 0;
    D111 := D110;
ELSIF M950 AND (D501 < 32000) THEN
    D501 := D501 + 1;
END_IF;

IF NOT M0 THEN D110 := 0; END_IF;

CASE D110 OF
0:  IF M34 AND NOT M200 AND M0 THEN D110 := 1; END_IF;

1:  (* RESET *)
    IF D501 >= 5 THEN D110 := 2; END_IF;

2:  (* 等 RC75 清除異常 *)
    IF D501 >= 5 THEN
        IF M11 AND NOT M13 THEN
            D110 := 0;
        ELSE
            D110 := 3;
        END_IF;
    END_IF;

3:  (* RETURN 回原點 *)
    IF M11 AND NOT M13 THEN
        D110 := 0;
    ELSIF D501 >= D212 THEN
        M149 := TRUE;
        D110 := 0;
    END_IF;
ELSE
    D110 := 0;
END_CASE;

(* ---- 內部輸出線圈 M400~M415（P70 轉成 Y） ---- *)
M400 := NOT M0 OR M203 OR (M201 AND M115);                           (* 機台停止 → 治具 *)
M401 := ((D100 = 10) AND M200 AND NOT M301 AND M11 AND NOT M13 AND M0)
        OR (M201 AND M114 AND M0 AND M11 AND NOT M13 AND NOT M203);   (* 機台待機 → 治具 *)
M410 := (D110 = 3) OR (M201 AND M110 AND M0);                        (* RC75 RETURN *)
M411 := (D110 = 1) OR (M201 AND M111 AND M0);                        (* RC75 RESET *)

(* 手動鎖付：按一下 = 一個循環（筆電測試後修正） *)
M930 := M113 AND NOT M931;  M931 := M113;
IF M201 AND M930 AND M0 AND M10 AND M11 AND NOT M12 AND NOT M13 AND NOT M203 THEN
    M932 := TRUE;
END_IF;
IF M13 OR NOT M201 OR M203 OR NOT M0 THEN M932 := FALSE; END_IF;
M412 := (D100 = 30) OR M932;                                         (* CYCLE START *)

M413 := M201 AND M112 AND M0;                                        (* RC75 送螺絲 *)
M414 := (D201 MOD 2) = 1;                                            (* TABLE bit0 *)
M415 := ((D201 / 2) MOD 2) = 1;                                      (* TABLE bit1 *)

(* 手動模式下 TABLE 跟隨設定值 *)
IF M201 AND (D200 >= 1) AND (D200 <= 3) THEN D201 := D200; END_IF;

(* 塔燈與蜂鳴器 *)
IF M120 THEN M121 := TRUE; END_IF;
IF NOT (M203 OR M154) THEN M121 := FALSE; END_IF;
M404 := M200 AND NOT M203;                                (* 綠：自動運轉 *)
M405 := (NOT M200 AND NOT M203) OR (M204 AND SM412);      (* 黃：停止；警告閃爍 *)
M406 := M203 OR M154;                                    (* 紅：異常（含完工待收時中控斷線） *)
M407 := (M203 OR M154) AND NOT M121;                      (* 蜂鳴器 *)
