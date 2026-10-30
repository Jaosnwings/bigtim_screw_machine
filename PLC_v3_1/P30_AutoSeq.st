(* ============================================================
   P30_AutoSeq  自動步序 D100  v3.1
   0 停止 / 10 待機 / 12 中控開始交握 / 14 等中控放行 / 20 選表 / 30 啟動 / 40 等完成
   50 判定 / 56 OK/NG 分流 / 60 等回原點
   Local 模式：10 → 20 … 50 → 56（與 v2 相同，只多記錄時間與結果）
   Remote 模式：10 → 12 → 14 → 20 … 50 → 56；50 同時舉「完工待收」M2113（B02）
   v3.1：完工待收保持到中控 ACK完工（不逾時），機台可先回原點、放治具讓 OP 取件重刷，
         但 M2113 未清前不接下一件（V10 5.3）
   D500 = 本步經過時間 (0.1s)，D502 = 循環時間 (0.1s)
   結果資料（P75 複製到 D7110~D7122）：D2030~D2035 開始時間、D2036~D2041 結束時間、
   D2042 Cycle Time、M2111 Result_Ready、M2112 Overall_Result
   ============================================================ *)

IF NOT M200 THEN D100 := 0; END_IF;

(* 步序計時：換步歸零；進入步序 20 時清除上一顆結果並記錄開始時間 *)
IF D100 <> D101 THEN
    D500 := 0;
    D101 := D100;
    IF D100 = 20 THEN
        M2111 := FALSE;  M2112 := FALSE;
        D2036 := 0;  D2037 := 0;  D2038 := 0;  D2039 := 0;  D2040 := 0;  D2041 := 0;
        D2042 := 0;
        D2030 := SD210;  D2031 := SD211;  D2032 := SD212;   (* 開始：年月日 *)
        D2033 := SD213;  D2034 := SD214;  D2035 := SD215;   (* 開始：時分秒 *)
        M150 := FALSE;   (* 這顆已放行，中控未放行警告自動解除 *)
    END_IF;
ELSIF M950 AND (D500 < 32000) THEN
    D500 := D500 + 1;
END_IF;

(* 循環時間：選表到判定 *)
IF (D100 >= 20) AND (D100 < 50) AND M950 AND (D502 < 32000) THEN
    D502 := D502 + 1;
END_IF;

(* 循環完成 / OK 鎖存：步序 40~56 保持（v3 延長到 56，交握期間不能掉） *)
M320 := (M320 OR M14) AND (D100 >= 40) AND (D100 <= 56);
M321 := (M321 OR (M15 AND NOT M12)) AND (D100 >= 40) AND (D100 <= 56);

CASE D100 OF
0:  (* 停止中 *)
    IF M200 THEN D100 := 10; END_IF;

10: (* 待機：輸出「機台待機」給治具，等治具啟動要求 *)
    IF NOT M5 THEN M310 := FALSE; END_IF;   (* 治具放開要求後才接受下一次 *)
    IF (D200 < 1) OR (D200 > 3) THEN M142 := TRUE; END_IF;
    IF M301 THEN
        M200 := FALSE;
        M301 := FALSE;
        D100 := 0;
    ELSIF M5 AND NOT M310 AND M202 AND M2062 AND NOT M2113 AND (D500 >= 5) AND (D200 >= 1) AND (D200 <= 3)
          AND (NOT M2051 OR (NOT M2034 AND NOT M2035)) THEN   (* Remote：上一次的 ACK 都已歸 0 *)
        D201 := D200;   (* 本次使用的 TABLE *)
        D502 := 0;
        IF M2051 THEN
            D100 := 12;   (* Remote：先問中控 *)
        ELSE
            D100 := 20;   (* Local：直接鎖 *)
        END_IF;
    END_IF;

12: (* Remote：送「實體開始」B01（P75 依步序輸出），保持到中控 ACK開始 = 1 *)
    IF M2034 THEN
        (* 清零交握：清除上一顆結果，中控收到的是乾淨的資料 *)
        M2111 := FALSE;  M2112 := FALSE;
        D2030 := 0;  D2031 := 0;  D2032 := 0;  D2033 := 0;  D2034 := 0;  D2035 := 0;
        D2036 := 0;  D2037 := 0;  D2038 := 0;  D2039 := 0;  D2040 := 0;  D2041 := 0;
        D2042 := 0;
        D100 := 14;
    ELSIF NOT M5 THEN
        D100 := 10;   (* 治具放開，取消 *)
    ELSIF D500 >= D213 THEN
        M150 := TRUE;   (* 警告：中控未回應 *)
        M310 := TRUE;   (* 需治具放開後再重來 *)
        D100 := 10;
    END_IF;

14: (* Remote：中控掃碼審查中，等防呆放行 Interlock Pass（每次放行只用一次） *)
    IF M2053 AND NOT M2114 THEN
        M2114 := TRUE;
        D100 := 20;
    ELSIF NOT M5 THEN
        D100 := 10;
    ELSIF D500 >= D213 THEN
        M150 := TRUE;   (* 警告：中控未放行（工單/工號/靜電/前站NG，看系統訊息） *)
        M310 := TRUE;
        D100 := 10;
    END_IF;

20: (* 輸出 TABLE 選擇，穩定 0.2 秒並再確認條件 *)
    IF (D500 >= 2) AND M0 AND M10 AND M11 AND NOT M12 AND NOT M13 AND M5 THEN
        D100 := 30;
    ELSIF D500 >= D210 THEN
        M143 := TRUE;
    END_IF;

30: (* 送 CYCLE START（至少 0.3 秒），等 RC75 循環中 *)
    IF M13 AND (D500 >= 3) THEN
        D100 := 40;
    ELSIF D500 >= D210 THEN
        M143 := TRUE;
    END_IF;

40: (* 等循環完成 *)
    IF M320 AND NOT M13 THEN
        D100 := 50;
    ELSIF D500 >= D211 THEN
        M144 := TRUE;
    END_IF;

50: (* 判定、計數、寫入結果資料（只執行一個掃描） *)
    D304:D := D304:D + 1;
    D402 := D502;
    D2036 := SD210;  D2037 := SD211;  D2038 := SD212;   (* 結束：年月日 *)
    D2039 := SD213;  D2040 := SD214;  D2041 := SD215;   (* 結束：時分秒 *)
    D2042 := D502;   (* Cycle Time 0.1 秒 *)
    M2112 := M321;   (* Overall_Result 1 = OK（先寫結果） *)
    M2111 := TRUE;   (* Result_Ready：資料已更新 *)
    IF M2051 THEN
        M2113 := TRUE;   (* 完工 B02：P75 在本掃描最後把結果、Result_Ready、完工一次寫出 *)
    END_IF;
    IF M321 THEN
        D300:D := D300:D + 1;
    ELSE
        D302:D := D302:D + 1;
    END_IF;
    D100 := 56;

56: (* OK → 等回原點；NG → 異常停機（與 v2 相同） *)
    IF M321 THEN
        D100 := 60;
    ELSE
        M145 := TRUE;
        M310 := TRUE;   (* NG 後須治具放開要求才會再接受 *)
        D100 := 0;
    END_IF;

60: (* 等 Z 軸回原點且不在循環中，才讓治具動作 *)
    IF M11 AND NOT M13 THEN
        M310 := TRUE;
        D100 := 10;
    ELSIF D500 >= D212 THEN
        M149 := TRUE;
    END_IF;
ELSE
    D100 := 0;
END_CASE;
