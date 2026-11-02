(* ============================================================
   P30_AutoSeq  自動步序 D100  v3.2（一循環鎖 D221 點，預設 2）
   0 停止 / 10 待機啟動（等 X7）/ 12 中控開始交握 / 14 等中控放行 /
   15 治具移到第 n 點（Y5 脈衝，等 D234）/ 30 啟動鎖付（Y12，等 X12 OFF）/ 40 鎖付中 /
   50 判定 / 56 分流（下一點或結束）/ 60 等治具回水平（Y5 脈衝，等 X5）
   v3.2 與 v3.1 的差別：
     - 啟動改由 X7（HMI 箱綠鍵）上升沿，自動啟動 M100 只讓機台進入待機
     - 刪除步驟 20（Y14 TABLE 1 常 ON），刪除 X5「治具放開才接受下一次」的 M310 機制
     - 沒有 RC75 循環中訊號：30 看 X12 OFF（Z 離開原點），40 看 X14 + X12 回 ON + X13 OFF
     - 治具沒有到位訊號：15 在 Y5 送出後等 D234（測試暫定 3.0 秒）
     - 光柵 X10 OFF：15/60（治具在動）暫停，計時凍結；30/40 由 P20 報 M155 停機
     - 計數以產品為單位（全部點 OK 才算良品）；每點 OK/NG 另記 D230~D233
     - 中控完工、結果資料一個產品送一次
   D500 = 本步經過時間 (0.1s)，D502 = 循環時間 (0.1s)，D222 = 目前第幾點，D2051 = 等待條件碼
   ============================================================ *)

IF NOT M200 THEN D100 := 0; END_IF;

(* ---- 光柵暫停：治具在動的步驟遮斷 → Y3 保持（P40）、計時凍結；恢復 D224 後繼續 ---- *)
IF M200 AND ((D100 = 15) OR (D100 = 60)) THEN
    IF NOT M10 THEN
        M845 := TRUE;
        D533 := 0;
    ELSIF M845 THEN
        IF M950 THEN D533 := D533 + 1; END_IF;
        IF D533 >= D224 THEN M845 := FALSE; END_IF;
    END_IF;
ELSE
    M845 := FALSE;
END_IF;

(* ---- 步序計時：換步歸零；第 1 點進入 15 時清除上一件結果並記錄開始時間 ---- *)
IF D100 <> D101 THEN
    D500 := 0;
    D534 := 0;
    D101 := D100;
    IF (D100 = 15) AND (D222 = 1) THEN
        M2111 := FALSE;  M2112 := FALSE;
        D2036 := 0;  D2037 := 0;  D2038 := 0;  D2039 := 0;  D2040 := 0;  D2041 := 0;
        D2042 := 0;
        D2030 := SD210;  D2031 := SD211;  D2032 := SD212;   (* 開始：年月日 *)
        D2033 := SD213;  D2034 := SD214;  D2035 := SD215;   (* 開始：時分秒 *)
        M150 := FALSE;   (* 已放行，中控未放行警告自動解除 *)
        M322 := TRUE;    (* 本產品目前全部 OK *)
    END_IF;
ELSIF M950 AND NOT M845 AND (D500 < 32000) THEN
    D500 := D500 + 1;
END_IF;

(* 循環時間：第 1 點治具移動到最後判定 *)
IF (D100 >= 15) AND (D100 < 60) AND M950 AND NOT M845 AND (D502 < 32000) THEN
    D502 := D502 + 1;
END_IF;

(* 循環完成 / 締付 OK 鎖存：只認步驟 30~56 期間的上升沿（X14、X17 是脈衝或保持都可以），離開就清 *)
M320 := (M320 OR (M14 AND NOT M323)) AND (D100 >= 30) AND (D100 <= 56);
M321 := (M321 OR (M17 AND NOT M324)) AND (D100 >= 30) AND (D100 <= 56);
M323 := M14;
M324 := M17;

CASE D100 OF
0:  (* 停止中 *)
    D222 := 0;
    IF M200 THEN D100 := 10; END_IF;

10: (* 待機啟動：綠燈閃，等啟動鈕 X7 *)
    D222 := 0;
    IF M301 THEN
        M200 := FALSE;
        M301 := FALSE;
        D100 := 0;
    ELSIF M36 AND M202 AND NOT M15 AND M2062 AND NOT M2113 AND (D500 >= 5)
          AND (NOT M2051 OR (NOT M2034 AND NOT M2035)) THEN   (* Remote：上一次的 ACK 都已歸 0 *)
        D222 := 1;
        D502 := 0;
        IF M2051 THEN
            D100 := 12;   (* Remote：先問中控 *)
        ELSE
            D100 := 15;   (* Local：直接開始 *)
        END_IF;
    END_IF;

12: (* Remote：送「實體開始」B01（P75 依步序輸出），保持到中控 ACK開始 = 1 *)
    IF M2034 THEN
        M2111 := FALSE;  M2112 := FALSE;
        D2030 := 0;  D2031 := 0;  D2032 := 0;  D2033 := 0;  D2034 := 0;  D2035 := 0;
        D2036 := 0;  D2037 := 0;  D2038 := 0;  D2039 := 0;  D2040 := 0;  D2041 := 0;
        D2042 := 0;
        D100 := 14;
    ELSIF M301 THEN
        D100 := 10;
    ELSIF D500 >= D213 THEN
        M150 := TRUE;   (* 警告：中控未回應 *)
        D100 := 10;
    END_IF;

14: (* Remote：中控掃碼審查中，等防呆放行 Interlock Pass（每次放行只用一次） *)
    IF M2053 AND NOT M2114 THEN
        M2114 := TRUE;
        D100 := 15;
    ELSIF M301 THEN
        D100 := 10;
    ELSIF D500 >= D213 THEN
        M150 := TRUE;   (* 警告：中控未放行（工單/工號/靜電/前站NG，看系統訊息） *)
        D100 := 10;
    END_IF;

15: (* 治具移到第 D222 點：P40 在本步開頭送 Y5 脈衝 D235；沒有到位訊號，等 D234（測試暫定） *)
    IF (D500 >= D234) AND NOT M6 AND M11 AND M12 AND NOT M13 THEN
        D100 := 30;
    ELSIF D500 >= D234 + D210 THEN
        M143 := TRUE;   (* 時間到了 RC75 仍沒準備好 → 啟動逾時 *)
    END_IF;

30: (* 送 CYCLE START 脈衝 D225（P40），等 Z 離開原點 X12 OFF ≥ 0.1 秒 *)
    IF NOT M12 THEN
        IF M950 THEN D534 := D534 + 1; END_IF;
    ELSE
        D534 := 0;
    END_IF;
    IF D534 >= 1 THEN
        D100 := 40;
    ELSIF D500 >= D210 THEN
        M143 := TRUE;
    END_IF;

40: (* 鎖付中：循環完成（鎖存）、Z 回原點、沒有 ALARM 三個都成立 *)
    IF M320 AND M12 AND NOT M13 THEN
        D100 := 50;
    ELSIF D500 >= D211 THEN
        M144 := TRUE;
    END_IF;

50: (* 判定這一點（只執行一個掃描） *)
    IF M321 THEN
        IF D222 = 1 THEN D230 := D230 + 1; ELSE D231 := D231 + 1; END_IF;
    ELSE
        IF D222 = 1 THEN D232 := D232 + 1; ELSE D233 := D233 + 1; END_IF;
        M322 := FALSE;
    END_IF;
    D100 := 56;

56: (* 分流：NG → 結束這件並停機；OK 且還有點 → 下一點；OK 且最後一點 → 結束這件 *)
    IF M322 AND (D222 < D221) THEN
        D222 := D222 + 1;
        D100 := 15;
    ELSE
        (* 結束這件：計數、寫入結果資料 *)
        D304:D := D304:D + 1;
        D402 := D502;
        D2036 := SD210;  D2037 := SD211;  D2038 := SD212;   (* 結束：年月日 *)
        D2039 := SD213;  D2040 := SD214;  D2041 := SD215;   (* 結束：時分秒 *)
        D2042 := D502;   (* Cycle Time 0.1 秒 *)
        M2112 := M322;   (* Overall_Result 1 = OK（先寫結果） *)
        M2111 := TRUE;   (* Result_Ready *)
        IF M2051 THEN
            M2113 := TRUE;   (* 完工 B02 *)
        END_IF;
        IF M322 THEN
            D300:D := D300:D + 1;
            D100 := 60;
        ELSE
            D302:D := D302:D + 1;
            M145 := TRUE;    (* 鎖付 NG：停機，Y3 保持，治具留原地 *)
            D100 := 0;
        END_IF;
    END_IF;

60: (* 等治具回水平：P40 在本步開頭再送一次 Y5（Q-B 暫定），等 X5 ON ≥ 0.3 秒且 Z 在原點 *)
    IF (D500 >= D235 + 3) AND M5 AND M12 THEN
        IF M301 OR M104 THEN
            M200 := FALSE;
            M301 := FALSE;
            D100 := 0;
        ELSE
            D100 := 10;
        END_IF;
    ELSIF D500 >= D217 THEN
        M157 := TRUE;
    END_IF;
ELSE
    D100 := 0;
END_CASE;

(* 等待條件碼（HMI 顯示）：0 無、1 等啟動鈕 X7、2 等中控、3 治具移動中、4 等 Z 離開原點、
   5 鎖付中、6 等治具回水平 X5、7 光柵暫停 *)
IF M845 THEN D2051 := 7;
ELSIF D100 = 10 THEN D2051 := 1;
ELSIF (D100 = 12) OR (D100 = 14) THEN D2051 := 2;
ELSIF D100 = 15 THEN D2051 := 3;
ELSIF D100 = 30 THEN D2051 := 4;
ELSIF D100 = 40 THEN D2051 := 5;
ELSIF D100 = 60 THEN D2051 := 6;
ELSE D2051 := 0;
END_IF;
