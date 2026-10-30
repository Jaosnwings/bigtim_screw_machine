(* ============================================================
   P20_Mode_Alarm  異常偵測、自動/手動、啟動/停止  v3.1
   M140~M149 = 異常／警告（v2）；M150~M154 = 中控／靜電（v3）
   警告（不停機）：M142 未READY、M146 螺絲不足、M150 中控未放行、M152 中控通訊中斷、M153 靜電不 OK
   M154 完工待收時中控斷線：亮紅燈但不中斷步序（v3.1）；M151 v3.1 起不再使用
   M214 = 機台異常（回報中控 B03），不含鎖付 NG（NG 由 Overall_Result 回報）
   ============================================================ *)

(* ---- 異常偵測 ---- *)
IF NOT M0 THEN M140 := TRUE; END_IF;      (* 緊急停止（保持到復歸） *)
M141 := M12;                              (* RC75 ALARM *)
M146 := M16;                              (* 螺絲不足：警告 *)
M147 := M17;                              (* 送料/取料異常 *)
IF M6 AND M200 THEN M148 := TRUE; END_IF; (* 運轉中收到治具停止要求 *)
(* M142、M143、M144、M145、M149 由 P30/P40 設定；M150 由 P30 設定；M152、M153、M154 由 P15 設定 *)

(* ---- 復歸：停止中才清除已排除的保持型異常 ---- *)
IF M34 AND NOT M200 THEN
    IF M0 THEN M140 := FALSE; END_IF;
    M142 := FALSE;
    M143 := FALSE;
    M144 := FALSE;
    M145 := FALSE;
    IF NOT M6 THEN M148 := FALSE; END_IF;
    M149 := FALSE;
    M150 := FALSE;
    M151 := FALSE;
    IF NOT M2052 THEN M154 := FALSE; END_IF;   (* 解除異常不等於資料已收，完工待收 M2113 不清 *)
    M121 := FALSE;   (* 蜂鳴器靜音解除 *)
END_IF;

(* 停機型異常 *)
M214 := M140 OR M141 OR M143 OR M144 OR M147 OR M148 OR M149;   (* 機台異常 *)
M203 := M214 OR M145;
M204 := M142 OR M146 OR M150 OR M152 OR M153;   (* 警告 *)

(* ---- 自動 / 手動切換（停止中才可切） ---- *)
M920 := M103 AND NOT M921;  M921 := M103;
IF M920 AND NOT M200 THEN M201 := NOT M201; END_IF;

(* ---- 運轉準備完成 ---- *)
M202 := M0 AND M10 AND M11 AND NOT M12 AND NOT M203 AND NOT M201 AND (D110 = 0);

(* ---- 啟動 ---- *)
IF M30 AND NOT M200 AND NOT M201 THEN
    IF M202 THEN
        M200 := TRUE;
        M301 := FALSE;
        M142 := FALSE;
    ELSIF NOT M10 OR NOT M11 THEN
        M142 := TRUE;   (* 警告：RC75 未 READY 或不在原點，請先復歸 *)
    END_IF;
END_IF;

(* ---- 停止：鎖完目前這一顆再停 ---- *)
IF M32 AND M200 THEN M301 := TRUE; END_IF;

(* ---- 異常：立即停止 ---- *)
IF M203 THEN
    M200 := FALSE;
    M301 := FALSE;
END_IF;
