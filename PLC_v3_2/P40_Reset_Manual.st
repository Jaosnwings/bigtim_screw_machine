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

3:  (* Z 軸回原點：X12 OFF 時送 RETURN *)
    IF M12 AND NOT M13 THEN
        D110 := 4;
    ELSIF D501 >= D212 THEN
        M149 := TRUE;
        D110 := 0;
    END_IF;

4:  (* Z 在安全位置（Y4 ON）→ 解除急停保持，下一步 Y3 OFF *)
    M841 := FALSE;
    IF M0 THEN M140 := FALSE; END_IF;
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

(* ---- 手動：單次鎖付 = Y12 脈衝 D225，X12 OFF 視為已啟動，X12 回 ON 結束 ---- *)
M930 := M113 AND NOT M931;  M931 := M113;
IF M201 AND M930 AND M0 AND M10 AND M11 AND M12 AND NOT M13 AND NOT M203 THEN
    M932 := TRUE;
    M933 := FALSE;
    D535 := 0;
END_IF;
IF M932 THEN
    IF M950 AND (D535 < 32000) THEN D535 := D535 + 1; END_IF;
    IF NOT M12 THEN M933 := TRUE; END_IF;
    IF (M933 AND M12) OR (D535 >= D211) OR NOT M201 OR M203 OR NOT M0 THEN
        M932 := FALSE;
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
M405 := (M200 AND ((D100 = 15) OR (D100 = 60)) AND (D500 < D235) AND NOT M845
         AND M0 AND M12 AND NOT M203) OR M852
        OR (M7 AND M0);                                                     (* Y5 治具啟動／前進；v3.07（11-11 現場）：X1 啟動鈕按著 Y5 就 ON、放開 OFF（只看急停） *)
M406 := M400;                                                               (* Y6 預留：過渡期同紅燈 *)
M407 := FALSE;                                                              (* Y7 預留 *)
M410 := ((D110 = 3) AND NOT M12) OR (M201 AND M110 AND M0);                 (* Y10 RC75 RETURN *)
M411 := (D110 = 1) OR M844 OR (M201 AND M111 AND M0);                       (* Y11 RC75 RESET *)
M412 := (((D100 = 30) AND (D500 < D225)) OR (M932 AND (D535 < D225)))
        AND M0 AND NOT M410 AND NOT M413;                                   (* Y12 CYCLE START *)
M413 := M201 AND M112 AND M0 AND M11;                                       (* Y13 RC75 送螺絲 *)
M414 := (D200 = 1);                                                         (* Y14 TABLE 1 常 ON *)
M415 := FALSE;                                                              (* Y15 TABLE 2 未接 *)
