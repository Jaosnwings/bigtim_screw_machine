(* ============================================================
   P05_Sim  0.1 秒時基 + 模擬模式（假裝 RC75 與治具的回應）  v3.2
   M50 = 模擬模式。ON 時 P10 改用本段產生的訊號，P70 關閉所有實體輸出
   v3.2：RC75 改用 HOME（X12）行為：START 後 HOME OFF，D521 後 HOME ON + 循環完成 + OK
         治具：Y5 脈衝在步驟 15 → 離開水平（X5 OFF）；步驟 60 的 Y5 或 Y3 解除 → 1 秒後回水平
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
        M63 := TRUE;      (* 鎖付中（內部用，v3.2 沒有接循環中） *)
        M64 := FALSE;     (* 循環完成 *)
        M65 := FALSE;     (* 締付 OK *)
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
    IF (D100 = 15) OR (D100 = 0) THEN M64 := FALSE; END_IF;   (* 下一點前循環完成歸 0 *)
    IF M411 THEN M51 := FALSE; END_IF;   (* RC75 RESET 清除模擬異常 *)
    M60 := NOT M51;   (* READY；M51 = HMI「模擬 RC75 異常」 *)
    M61 := NOT M63;   (* HOME：鎖付中 Z 離開原點 *)
    M62 := M51;       (* ALARM *)
    M66 := FALSE;     (* 螺絲不足 *)

    (* ---- 治具模擬 ---- *)
    M962 := M405 AND NOT M963;     (* Y5 上升沿 *)
    M963 := M405;
    IF M962 THEN
        IF D100 = 60 THEN
            M966 := TRUE;          (* 回水平中 *)
            D522 := 0;
        ELSE
            M54 := FALSE;          (* 離開水平，往鎖付點 *)
            M966 := FALSE;
        END_IF;
    END_IF;
    IF M965 AND NOT M403 AND NOT M54 THEN   (* Y3 解除 → 治具自己回水平 *)
        M966 := TRUE;
        D522 := 0;
    END_IF;
    M965 := M403;
    IF M966 AND NOT M403 THEN
        IF M950 THEN D522 := D522 + 1; END_IF;
        IF D522 >= 10 THEN
            M54 := TRUE;
            M966 := FALSE;
        END_IF;
    END_IF;
    M55 := M56;       (* HMI「模擬治具停止」 *)
ELSE
    M54 := TRUE;
    M55 := FALSE;
    M63 := FALSE;
    M64 := FALSE;
    M960 := FALSE;
    M961 := FALSE;
    M966 := FALSE;
END_IF;
