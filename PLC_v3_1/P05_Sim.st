(* ============================================================
   P05_Sim  0.1 秒時基 + 模擬模式（假裝 RC75 與治具的回應）  v3.1
   M50 = 模擬模式。ON 時 P10 改用本段產生的訊號，P70 關閉所有實體輸出
   v3：中控被拒（M310 且回到待機）時，模擬治具也放開
   ============================================================ *)

(* 0.1 秒時基脈衝 M950：每 0.1 秒 ON 一個掃描 *)
M950 := SM410 AND NOT M951;
M951 := SM410;

(* 模擬模式只能在停止、未復歸中切換；運轉中切換會被還原 *)
IF (M200 OR (D110 <> 0)) AND (M50 <> M59) THEN
    M50 := M59;
END_IF;
M59 := M50;

IF M50 THEN
    (* ---- RC75 模擬 ---- *)
    M960 := M412 AND NOT M961;
    M961 := M412;
    IF M960 AND NOT M62 AND NOT M63 THEN
        M63 := TRUE;      (* 循環中 *)
        M64 := FALSE;     (* 循環完成 *)
        M65 := FALSE;     (* OK *)
        D520 := 0;
    END_IF;
    IF M63 THEN
        IF M950 THEN D520 := D520 + 1; END_IF;
        IF D520 >= D521 THEN
            M63 := FALSE;
            M64 := TRUE;
            M65 := NOT M52;   (* M52 = HMI「模擬 NG」 *)
        END_IF;
    END_IF;
    IF M411 THEN M51 := FALSE; END_IF;   (* RC75 RESET 清除模擬異常 *)
    M60 := NOT M51;   (* READY；M51 = HMI「模擬 RC75 異常」 *)
    M61 := NOT M63;   (* 原位置 *)
    M62 := M51;       (* ALARM *)
    M66 := FALSE;     (* 螺絲不足 *)
    M67 := FALSE;     (* 送料/取料異常 *)

    (* ---- 治具模擬 ---- *)
    M962 := M53 AND NOT M963;
    M963 := M53;
    IF M962 THEN M54 := TRUE; END_IF;
    IF (D100 = 60) OR M400 OR (M310 AND (D100 = 10)) THEN M54 := FALSE; END_IF;
    M55 := M56;       (* HMI「模擬治具停止」 *)
ELSE
    M54 := FALSE;
    M55 := FALSE;
    M63 := FALSE;
    M64 := FALSE;
    M960 := FALSE;
    M961 := FALSE;
END_IF;
