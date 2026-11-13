(* ============================================================
   P40_Reset_Manual  復歸程序 D110、手動輸出、內部輸出線圈 M400~M415  v3.2
   復歸（順序定案：Z 軸先回原點，治具才動）：
     1 RESET 0.5 秒 → 2 等 0.5 秒 → 3 RETURN 直到 X12 HOME → 4 安全位置（清 EMO 保持 M841）
     → 5 Y3 解除，監看 X5 回水平（D217 逾時 → M157）→ 0
   D218 = 1：急停放開後 X0、X10 都 ON ≥ D226 且 X6 OFF 時自動開始復歸（預設 0 = 要按復歸）
   D501 = 復歸步經過時間 (0.1s)
   手動（M201）：M110 RETURN、M111 RESET、M112 送螺絲（按住）；M113 單次鎖付；
                 M115 治具停止 Y3（按一下切換）；M114 治具啟動 Y5（按一下送 D235 脈衝）
   ============================================================ *)

IF D110 <> D111 THEN
    D501 := 0;
    D111 := D110;
ELSIF M950 AND (D501 < 32000) THEN
    D501 := D501 + 1;
END_IF;

IF NOT M0 THEN D110 := 0; END_IF;

(* D218 = 1：急停放開後條件穩定就自動復歸 *)
IF (D218 = 1) AND M841 AND M0 AND M10 AND NOT M6 AND NOT M200 AND (D110 = 0) THEN
    IF M950 AND (D541 < 32000) THEN D541 := D541 + 1; END_IF;
ELSE
    D541 := 0;
END_IF;

CASE D110 OF
0:  IF (M34 AND NOT M200 AND M0) OR (D541 >= D226) THEN
        D541 := 0;
        D110 := 1;
    END_IF;

1:  (* RESET *)
    IF D501 >= 5 THEN D110 := 2; END_IF;

2:  (* 等 RC75 清除異常 *)
    IF D501 >= 5 THEN D110 := 3; END_IF;

3:  (* Z 軸回原點：v3.18 RETURN 至少送 0.5 秒（已在原點也送），之後 X12 HOME 才往下 *)
    IF M12 AND NOT M13 AND (D501 >= 5) THEN
        D110 := 4;
    ELSIF D501 >= D212 THEN
        M149 := TRUE;
        D110 := 0;
    END_IF;

4:  (* Z 在安全位置（Y4 ON）→ 解除急停保持，下一步 Y3 OFF *)
    M841 := FALSE;
    IF M0 THEN M140 := FALSE; END_IF;
    M860 := TRUE;   (* v3.18 治具復歸：Y3 脈衝 1 秒（同上電） *)
    D542 := 0;
    D110 := 5;

5:  (* 治具回水平：Y3 OFF 後監看 X5 *)
    IF M5 THEN
        D110 := 0;
    ELSIF D501 >= D217 THEN
        M157 := TRUE;   (* 治具歸位逾時（v3.06 起不再讓 Y3 ON） *)
        D110 := 0;
    END_IF;
ELSE
    D110 := 0;
END_CASE;

(* ---- 手動：治具停止 Y3（按一下切換；解除要光柵 X10 ON） ---- *)
M851 := M115 AND NOT M853;  M853 := M115;
IF M201 AND M851 THEN
    IF NOT M850 THEN
        M850 := TRUE;
    ELSIF M10 THEN
        M850 := FALSE;
    END_IF;
END_IF;
IF NOT M201 THEN M850 := FALSE; END_IF;

(* ---- 手動：治具啟動 Y5（按一下送 D235 脈衝；Z 在原點、光柵 ON） ---- *)
M854 := M114 AND NOT M855;  M855 := M114;
IF M201 AND M854 AND M0 AND M12 AND M10 AND NOT M203 THEN
    M852 := TRUE;
    D536 := 0;
END_IF;
IF M852 THEN
    IF M950 THEN D536 := D536 + 1; END_IF;
    IF (D536 >= D235) OR NOT M201 OR NOT M0 THEN M852 := FALSE; END_IF;
END_IF;

(* ---- 手動：單次鎖付（v3.11）＋ 手動兩點流程（v3.12，11-11 現場要求）----
   開始條件：手動、急停正常、光柵、RC75 READY、原點、無 ALARM（和強制 Y12 一樣，不看停機異常鎖存 M203）
   觸發：a) HMI「單次鎖付」M113；b) v3.12 手動兩點：按啟動鈕 X1（Y5 ON）→ D546 = 1，
         之後每次 X7 治具到位（M940，且之前 X7 OFF 過 M937）自動鎖一點；第 1 點鎖完 D546 = 2（TABLE 2），第 2 點鎖完 D546 = 0
   1. 先看 X15 螺絲上膛：已上膛直接鎖；沒上膛 → Y13 送螺絲脈衝 0.5 秒，等 X15 ON（最多 3.0 秒，逾時放棄、D544 = 9）
   2. Y12 脈衝 D225，X12 OFF 視為已啟動，X12 回 ON 結束；D211 逾時
   D544 = 單次鎖付步序（0 待命 1 送螺絲 2 鎖付中 9 送螺絲逾時）；D545 = 送螺絲計時 (0.1s)；M934 = 送螺絲中
   D546 = 手動兩點流程目前第幾點（0 沒有在跑）；M938 = 這一次是 X7 觸發的；M939 = 本掃描開始一次鎖付 *)
M930 := M113 AND NOT M931;  M931 := M113;
IF M201 AND NOT M200 AND M36 THEN D546 := 1; END_IF;
IF NOT M201 OR M200 THEN
    D546 := 0;
    M938 := FALSE;
END_IF;
M939 := FALSE;
IF M201 AND NOT M200 AND M0 AND M10 AND M11 AND M12 AND NOT M13 AND NOT M932 AND NOT M934 THEN
    IF ((D546 = 1) OR (D546 = 2)) AND M940 AND M937 THEN
        M937 := FALSE;
        M938 := TRUE;
        M939 := TRUE;
    ELSIF M930 THEN
        M938 := FALSE;
        M939 := TRUE;
    END_IF;
END_IF;
IF M939 THEN
    D548 := D546;   (* v3.15：這一顆是手動兩點的第幾點（給 RS-485 結果標點號；HMI 單次鎖付 = 0） *)
    IF M15 THEN
        M932 := TRUE;
        M933 := FALSE;
        D535 := 0;
        D544 := 2;
    ELSE
        M934 := TRUE;
        D545 := 0;
        D544 := 1;
    END_IF;
END_IF;
IF M934 THEN
    IF M950 AND (D545 < 32000) THEN D545 := D545 + 1; END_IF;
    IF NOT M201 OR NOT M0 THEN
        M934 := FALSE;
        M938 := FALSE;
        D546 := 0;
        D544 := 0;
    ELSIF M15 AND M11 AND M12 AND NOT M13 AND (D545 >= 5) THEN   (* v3.13：送完 0.5 秒、已上膛且 RC75 READY 回來 → 鎖付 *)
        M934 := FALSE;
        M932 := TRUE;
        M933 := FALSE;
        D535 := 0;
        D544 := 2;
    ELSIF D545 >= 30 THEN               (* 3.0 秒還沒上膛或 READY 沒回來 → 放棄，兩點流程也結束 *)
        M934 := FALSE;
        M938 := FALSE;
        D546 := 0;
        D544 := 9;
    END_IF;
END_IF;
IF M932 THEN
    IF M950 AND (D535 < 32000) THEN D535 := D535 + 1; END_IF;
    IF NOT M12 THEN M933 := TRUE; END_IF;
    IF M933 AND M12 THEN                 (* 正常結束 *)
        M932 := FALSE;
        D544 := 0;
        IF M938 THEN
            M938 := FALSE;
            IF (D546 = 1) AND (D221 >= 2) THEN
                D546 := 2;               (* 換 TABLE 2，等治具轉到第 2 點（X7） *)
            ELSE
                D546 := 0;
            END_IF;
        END_IF;
    ELSIF (D535 >= D211) OR NOT M201 OR NOT M0 THEN
        M932 := FALSE;
        M938 := FALSE;
        D546 := 0;
        D544 := 0;
    END_IF;
END_IF;

(* ---- 上電 Y3 脈衝 1 秒（11-11 現場：上電時送 Y3 讓治具復歸） ---- *)
IF M860 THEN
    IF M950 AND (D542 < 32000) THEN D542 := D542 + 1; END_IF;
    IF D542 >= 10 THEN M860 := FALSE; END_IF;
END_IF;

(* ---- 內部輸出線圈 M400~M415（P70 加上 HMI 強制後轉成 Y） ---- *)
(* 塔燈只有紅綠：紅恆亮 = 停機異常；紅閃 = 警告。綠閃 = 待機等啟動；綠恆亮 = 加工中 *)
IF M120 THEN M121 := TRUE; END_IF;
IF NOT (M203 OR M154) THEN M121 := FALSE; END_IF;
M400 := M203 OR M154 OR (M204 AND SM412);                                   (* Y0 塔燈紅 *)
M401 := M200 AND NOT M203 AND (((D100 = 10) AND SM412) OR (D100 >= 12));    (* Y1 塔燈綠 *)
M402 := (M203 OR M154) AND NOT M121;                                        (* Y2 蜂鳴器 *)
(* Y3 治具停止：11-11 現場要求「跟著急停」——急停按下 ON、放開就 OFF，不再保持。
   異常（M203）、急停保持（M841）、復歸步 1~4 都不再讓 Y3 ON；Z 不在原點時靠 Y4 OFF 擋治具。
   保留：光柵暫停 M845、手動切換 M850、上電 1 秒脈衝 M860 *)
M403 := NOT M0 OR M845 OR (M201 AND M850) OR M860;
M404 := M0 AND M12 AND NOT M13;                                             (* Y4 螺絲機在安全位置 *)
M405 := M852 OR (M7 AND M0);                                               (* Y5 治具啟動：X1 啟動鈕按著就 ON（v3.07）；手動 Y5 鈕；v3.12 自動不再自己送 Y5 *)
M406 := M400;                                                               (* Y6 預留：過渡期同紅燈 *)
M407 := FALSE;                                                              (* Y7 預留 *)
M410 := ((D110 = 3) AND ((D501 < 5) OR NOT M12)) OR (M201 AND M110 AND M0);                 (* Y10 RC75 RETURN *)
M411 := (D110 = 1) OR M844 OR (M201 AND M111 AND M0);                       (* Y11 RC75 RESET *)
M412 := (((D100 = 30) AND (D500 < D225)) OR (M932 AND (D535 < D225)))
        AND M0 AND NOT M410 AND NOT M413 AND (D543 >= 2);                                   (* Y12 CYCLE START（TABLE 穩定 0.2 秒後） *)
M413 := (M201 AND M112 AND M0 AND M11) OR (M934 AND (D545 < 5))
        OR (M200 AND (D100 = 20) AND M941 AND (D500 < 5) AND M0);           (* Y13 送螺絲：手動按住；單次鎖付／自動步 20 沒上膛時送 0.5 秒 *)
(* v3.09（11-11）TABLE 依第幾點切換：第 2 點（D222 = 2）時 Y14 OFF、Y15 ON（TABLE 2），其餘 Y14 ON（TABLE 1）。
   RC75 只在 CYCLE START 當下讀 TABLE；切換點 = 第 1 點判定完成（P30 步 56→15）。
   D543 = TABLE 訊號已穩定的時間 (0.1s)；不滿 0.2 秒不送 CYCLE START（P30 步 15、M412） *)
M415 := (M200 AND (D222 = 2)) OR (M201 AND NOT M200 AND (D546 = 2));     (* Y15 TABLE 2：自動第 2 點、手動第 2 點（v3.12） *)
M414 := NOT M415;                                                           (* Y14 TABLE 1 *)
IF M415 <> M864 THEN
    D543 := 0;
    M864 := M415;
ELSIF M950 AND (D543 < 32000) THEN
    D543 := D543 + 1;
END_IF;
