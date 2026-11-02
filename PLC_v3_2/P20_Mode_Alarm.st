(* ============================================================
   P20_Mode_Alarm  異常偵測、自動/手動、啟動/停止  v3.2
   M140~M149 = 異常／警告（v2）；M150~M154 = 中控／靜電（v3）；M155、M157 = v3.2
   警告（不停機）：M142 未準備好、M146 螺絲不足、M150 中控未放行、M152 中控通訊中斷、M153 靜電不 OK
   M214 = 機台異常（回報中控 B03），不含鎖付 NG（NG 由 Overall_Result 回報）
   v3.2：
     M141 RC75 ALARM 改看 X13；M147 送料異常刪除（X16 蜂鳴只顯示）
     M155 光柵遮斷（Z 在動的步驟 30/40）、M157 治具歸位逾時（P30 步 60、P40 復歸步 5 設定）
     M841 = 急停或立即停之後保持 Y3，直到復歸流程第 5 步；M844 = RESET 脈衝 0.5 秒
     D2052 = 按自動啟動時缺的條件碼（HMI 顯示）
   ============================================================ *)

(* ---- 異常偵測 ---- *)
IF NOT M0 THEN
    M140 := TRUE;      (* 緊急停止（保持到復歸） *)
    M841 := TRUE;      (* Y3 治具停止保持到復歸流程 *)
END_IF;
M141 := M13;                              (* RC75 ALARM（X13） *)
M146 := M15;                              (* 螺絲不足：警告 *)
M147 := FALSE;                            (* v3.2 不再使用 *)
IF M6 AND M200 THEN M148 := TRUE; END_IF; (* 運轉中治具停止 *)
IF NOT M10 AND M200 AND ((D100 = 30) OR (D100 = 40)) THEN M155 := TRUE; END_IF;   (* 光柵遮斷：Z 在動 *)
(* M142、M143、M144、M145、M149、M157 由 P30/P40 設定；M150 由 P30 設定；M152、M153、M154 由 P15 設定 *)

(* ---- 立即停（HMI M105）：軟體急停，無安全功能 ---- *)
M856 := M105 AND NOT M857;  M857 := M105;
IF M856 THEN
    M200 := FALSE;
    M301 := FALSE;
    D100 := 0;
    M841 := TRUE;
END_IF;

(* ---- 急停或立即停：RC75 RESET 脈衝 0.5 秒（軟體中止 RC75，不是安全停止） ---- *)
M858 := NOT M0 OR M105;
IF M858 AND NOT M859 THEN
    M844 := TRUE;
    D532 := 0;
END_IF;
M859 := M858;
IF M844 THEN
    IF M950 THEN D532 := D532 + 1; END_IF;
    IF D532 >= 5 THEN M844 := FALSE; END_IF;
END_IF;

(* ---- 復歸：停止中才清除已排除的保持型異常（M841 由復歸流程第 4 步清） ---- *)
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
    IF M10 THEN M155 := FALSE; END_IF;
    M157 := FALSE;
    M121 := FALSE;   (* 蜂鳴器靜音解除 *)
END_IF;

(* 停機型異常 *)
M214 := M140 OR M141 OR M143 OR M144 OR M148 OR M149 OR M155 OR M157;   (* 機台異常 *)
M203 := M214 OR M145;
M204 := M142 OR M146 OR M150 OR M152 OR M153;   (* 警告 *)

(* ---- 自動 / 手動切換（停止中、不在復歸才可切） ---- *)
M920 := M103 AND NOT M921;  M921 := M103;
IF M920 AND NOT M200 AND (D110 = 0) THEN M201 := NOT M201; END_IF;

(* ---- 運轉準備完成 ---- *)
M202 := M0 AND M10 AND M11 AND M12 AND NOT M13 AND M5 AND NOT M6
        AND NOT M203 AND NOT M201 AND (D110 = 0) AND NOT M841 AND NOT M821;

(* 缺的條件碼（第一個不成立的）：0 OK、1 急停、2 光柵、3 RC75 未 READY、4 Z 不在原點、5 RC75 ALARM、
   6 治具不在水平、7 治具停止、8 有異常未復歸、9 手動模式、10 復歸中或急停後未復歸、11 強制中 *)
IF NOT M0 THEN D2052 := 1;
ELSIF NOT M10 THEN D2052 := 2;
ELSIF NOT M11 THEN D2052 := 3;
ELSIF NOT M12 THEN D2052 := 4;
ELSIF M13 THEN D2052 := 5;
ELSIF NOT M5 THEN D2052 := 6;
ELSIF M6 THEN D2052 := 7;
ELSIF M203 THEN D2052 := 8;
ELSIF M201 THEN D2052 := 9;
ELSIF (D110 <> 0) OR M841 THEN D2052 := 10;
ELSIF M821 THEN D2052 := 11;
ELSE D2052 := 0;
END_IF;

(* ---- 自動啟動（HMI）：進入待機，之後每循環由 X7 啟動 ---- *)
IF M30 AND NOT M200 AND NOT M201 THEN
    IF M202 THEN
        M200 := TRUE;
        M301 := FALSE;
        M142 := FALSE;
    ELSE
        M142 := TRUE;   (* 警告：條件不足，看 D2052 *)
    END_IF;
END_IF;

(* ---- 停止：鎖完目前這個產品再停 ---- *)
IF M32 AND M200 THEN M301 := TRUE; END_IF;

(* ---- 異常：立即停止 ---- *)
IF M203 THEN
    M200 := FALSE;
    M301 := FALSE;
END_IF;
