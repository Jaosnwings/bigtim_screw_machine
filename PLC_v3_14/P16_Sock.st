(* ============================================================
   P16_Sock  中控 socket 傳輸（輸入側，P15_MES_In 之前執行）  v3.14
   協定：docs/SOCKET_PROTOCOL_v1.md。本檔由 tools/gen_sock_st.py 產生，請改產生器再重新產生。
   D236 = 0：Modbus（v3.13 原樣，本區塊不動任何既有軟元件）；D236 = 1：socket。
     D236 只在 D100 = 0（停止）時生效，生效值放 M2190（D7171 = 0/1 給中控與 HMI 看）。
   socket 時，HO 訊框解開寫進 D7000~D7029（原本由中控用 Modbus 寫的同一區），
     P15 的心跳、Remote/Local、放行、ACK、校時邏輯照舊；中控此時不要再用 Modbus 寫 D7000~D7029。
   連線（都用 SP.SOCOPEN 控制資料 8000H 開啟，參數「外部設備連接設定」不要佔用這幾個連線號碼）：
     連線 1：中控 D243~D246（IP 四段）:D247，預設 192.168.1.200:9500，本機埠 4001
     連線 2：SICK 觸發埠 D237~D240:D241，預設 192.168.1.25:2111，本機埠 4002（D248=0 且 D241<>D242 才用）
     連線 3：SICK 資料埠 D237~D240:D242，預設 192.168.1.25:2112，本機埠 4003
   D248 SICK 觸發方式 0 = CoLa-A「sMN mTCgateon/off」 1 = 送 1 個 STX（0x02，舊中控 ScannerAdapter 的作法）
   D249 SICK 讀取逾時 0.1 秒（預設 30 = 3 秒）
   狀態：D7160 中控連線（0 未連 1 開啟中 2 已連線 3 關閉中 4 等重連） D7161 收到 HO 筆數 D7162 格式錯誤次數
         D7163 最後錯誤碼（指令完成狀態） D7164/D7165 SICK 觸發/資料連線狀態 D7166 SC 送出 D7167 NoRead
         D7168 ST 送出 D7169 收到 TG D7170 距上次 HO 0.1 秒 D7171 生效傳輸 D7172 最後錯誤來源
         （n1 開啟失敗 n2 送出失敗 n3 接收失敗 14 HO 逾時 n5 對方關閉，n = 連線號碼） D7173 HI 送出 D7174 最後條碼長度
   模擬測試（GX Simulator3 不能跑 socket）：M50 模擬模式 + M2235 ON → M2236，不執行 socket 指令、連線直接當作已連上；
     M2238 載入 HO 範例 A、M2185 範例 B（hb=40000、b 含小寫、ts 全 0）、M2189 兩筆錯誤、M2188/M2187 範例 A 分兩段、
     M2184 TG + 範例 B 同一包、M2239 TG；M2186 模擬 SICK 回條碼；M2182 ON = 模擬測試時也計 HO 5 秒逾時（預設不計）。
     開啟中超過 10 秒沒完成當作開啟失敗（D7172 = n1）；開啟中改回 Modbus 會先關閉，進入模擬測試直接回 0。送出的字串留在 D6800（長度）D6801~（D6600~ 每字 1 字元）。
   ============================================================ *)

(* ---- 生效傳輸 ---- *)
IF D100 = 0 THEN
    M2190 := (D236 = 1);
END_IF;
IF M2190 THEN D7171 := 1; ELSE D7171 := 0; END_IF;
M2236 := M50 AND M2235 AND M2190;
M2198 := (D248 = 0) AND (D241 <> D242);   (* 觸發用獨立連線 2 *)

(* socket 狀態：M2240~ 開啟完成（SD10680）、M2256~ 收到資料（SD10682），bit0 = 連線 1 *)
K4M2240 := SD10680;
K4M2256 := SD10682;

(* ================= 連線 1：中控 ================= *)
M2209 := FALSE;  M2211 := FALSE;  M2213 := FALSE;  M2215 := FALSE;
CASE D7160 OF
0:  (* 未連線 *)
    D2261 := 0;
    M2212 := FALSE;
    M2307 := FALSE;
    IF M2190 THEN
        IF M2236 THEN   (* 模擬測試：不執行 socket 指令，直接當作已連線 *)
            D7160 := 2;
            M2230 := TRUE;   (* 連上後送一次 HI *)
        ELSE
            D2200 := 16#8000;   (* 用控制資料的設定開啟 *)
            D2202 := 16#0200;   (* TCP、socket 通訊、Active open *)
            D2203 := 4001;   (* 本機埠 *)
            IF D245 >= 128 THEN D2204 := (D245 - 256) * 256 + D246; ELSE D2204 := D245 * 256 + D246; END_IF;
            IF D243 >= 128 THEN D2205 := (D243 - 256) * 256 + D244; ELSE D2205 := D243 * 256 + D244; END_IF;
            D2206 := D247;
            M2209 := TRUE;
            D7160 := 1;
        END_IF;
    END_IF;
1:  (* 開啟中 *)
    IF M2200 THEN
        IF M2201 THEN
            D7163 := D2201;  D7172 := 11;   (* 開啟失敗 *)
            M2211 := TRUE;  D2261 := 0;  D7160 := 3;
        ELSE
            D2261 := 0;  D7160 := 2;
            M2230 := TRUE;   (* 連上後送一次 HI *)
        END_IF;
    ELSIF M2236 THEN
        D2261 := 0;  D7160 := 0;   (* 進入模擬測試：直接回未連線（模擬器的 SOCOPEN 不會完成） *)
    ELSIF NOT M2190 THEN
        M2211 := TRUE;  D2261 := 0;  D7160 := 3;   (* 改回 Modbus：關閉後經 4 回 0 *)
    ELSE
        IF M950 THEN D2261 := D2261 + 1; END_IF;
        IF D2261 >= 100 THEN   (* 10 秒沒完成：當作開啟失敗 *)
            D7172 := 11;
            M2211 := TRUE;  D2261 := 0;  D7160 := 3;
        END_IF;
    END_IF;
2:  (* 已連線 *)
    IF M950 AND (D2261 < 32000) THEN D2261 := D2261 + 1; END_IF;
    IF M2190 AND NOT M2236 AND NOT M2240 THEN D7172 := 15; END_IF;   (* 對方關閉 *)
    M2183 := (D2261 >= 50) AND (NOT M2236 OR M2182);   (* 5 秒沒收到 HO；模擬測試時要 M2182 ON 才計 *)
    IF M2183 THEN D7172 := 14; END_IF;
    IF NOT M2190 OR (NOT M2236 AND NOT M2240) OR M2307 OR M2183 THEN
        M2307 := FALSE;  D2261 := 0;
        IF M2236 THEN D7160 := 4; ELSE M2211 := TRUE;  D7160 := 3; END_IF;
    END_IF;
3:  (* 關閉中（最多等 5 秒） *)
    IF M950 THEN D2261 := D2261 + 1; END_IF;
    IF M2202 OR (D2261 >= 50) THEN D2261 := 0;  D7160 := 4; END_IF;
4:  (* 等 3 秒再重連 *)
    M2212 := FALSE;
    IF M950 THEN D2261 := D2261 + 1; END_IF;
    IF (D2261 >= 30) OR NOT M2190 THEN D2261 := 0;  D7160 := 0; END_IF;
ELSE
    D7160 := 0;
END_CASE;
IF (D7160 = 2) AND NOT M2236 AND M2256 AND NOT M2212 THEN M2213 := TRUE;  M2212 := TRUE; END_IF;
SP_SOCOPEN(M2209, 'U0', 1, D2200, M2200);
SP_SOCCLOSE(M2211, 'U0', 1, D2210, M2202);
SP_SOCRCV(M2213, 'U0', 1, D2214, D3000, M2206);
IF M2206 THEN
    M2212 := FALSE;
    IF M2207 THEN D7163 := D2215;  D7172 := 13; ELSE M2215 := TRUE; END_IF;
END_IF;
D7170 := D2261;

(* ---- 模擬測試：把範例字串放進接收緩衝 ---- *)
IF M2236 AND (D7160 = 2) THEN
    IF M2238 THEN   (* HO 範例 A *)
        D3000 := 100;
        D3001 := 16#4F48;
        D3002 := 16#683B;
        D3003 := 16#3D62;
        D3004 := 16#3030;
        D3005 := 16#3231;
        D3006 := 16#3B34;
        D3007 := 16#6F63;
        D3008 := 16#6564;
        D3009 := 16#303D;
        D3010 := 16#3B39;
        D3011 := 16#3D62;
        D3012 := 16#3030;
        D3013 := 16#3331;
        D3014 := 16#733B;
        D3015 := 16#3D6E;
        D3016 := 16#4E53;
        D3017 := 16#3032;
        D3018 := 16#3632;
        D3019 := 16#3131;
        D3020 := 16#3231;
        D3021 := 16#302D;
        D3022 := 16#3030;
        D3023 := 16#3030;
        D3024 := 16#3030;
        D3025 := 16#3731;
        D3026 := 16#773B;
        D3027 := 16#3D6F;
        D3028 := 16#4F57;
        D3029 := 16#3632;
        D3030 := 16#3131;
        D3031 := 16#3231;
        D3032 := 16#3030;
        D3033 := 16#3130;
        D3034 := 16#6F3B;
        D3035 := 16#3D70;
        D3036 := 16#504F;
        D3037 := 16#3030;
        D3038 := 16#3130;
        D3039 := 16#2032;
        D3040 := 16#2020;
        D3041 := 16#743B;
        D3042 := 16#3D73;
        D3043 := 16#3032;
        D3044 := 16#3632;
        D3045 := 16#3131;
        D3046 := 16#3231;
        D3047 := 16#3531;
        D3048 := 16#3033;
        D3049 := 16#3230;
        D3050 := 16#0A0D;
    ELSIF M2185 THEN   (* HO 範例 B *)
        D3000 := 100;
        D3001 := 16#4F48;
        D3002 := 16#683B;
        D3003 := 16#3D62;
        D3004 := 16#3034;
        D3005 := 16#3030;
        D3006 := 16#3B30;
        D3007 := 16#6F63;
        D3008 := 16#6564;
        D3009 := 16#303D;
        D3010 := 16#3B37;
        D3011 := 16#3D62;
        D3012 := 16#6138;
        D3013 := 16#4630;
        D3014 := 16#733B;
        D3015 := 16#3D6E;
        D3016 := 16#4241;
        D3017 := 16#4443;
        D3018 := 16#4645;
        D3019 := 16#4847;
        D3020 := 16#4A49;
        D3021 := 16#4C4B;
        D3022 := 16#4E4D;
        D3023 := 16#504F;
        D3024 := 16#5251;
        D3025 := 16#5453;
        D3026 := 16#773B;
        D3027 := 16#3D6F;
        D3028 := 16#2057;
        D3029 := 16#2020;
        D3030 := 16#2020;
        D3031 := 16#2020;
        D3032 := 16#2020;
        D3033 := 16#2020;
        D3034 := 16#6F3B;
        D3035 := 16#3D70;
        D3036 := 16#2020;
        D3037 := 16#2020;
        D3038 := 16#2020;
        D3039 := 16#2020;
        D3040 := 16#2020;
        D3041 := 16#743B;
        D3042 := 16#3D73;
        D3043 := 16#3030;
        D3044 := 16#3030;
        D3045 := 16#3030;
        D3046 := 16#3030;
        D3047 := 16#3030;
        D3048 := 16#3030;
        D3049 := 16#3030;
        D3050 := 16#0A0D;
    ELSIF M2189 THEN   (* 錯誤：太短 + 開頭不是 HO *)
        D3000 := 109;
        D3001 := 16#4F48;
        D3002 := 16#683B;
        D3003 := 16#3D62;
        D3004 := 16#0D31;
        D3005 := 16#580A;
        D3006 := 16#3B58;
        D3007 := 16#6268;
        D3008 := 16#303D;
        D3009 := 16#3130;
        D3010 := 16#3432;
        D3011 := 16#633B;
        D3012 := 16#646F;
        D3013 := 16#3D65;
        D3014 := 16#3930;
        D3015 := 16#623B;
        D3016 := 16#303D;
        D3017 := 16#3130;
        D3018 := 16#3B33;
        D3019 := 16#6E73;
        D3020 := 16#533D;
        D3021 := 16#324E;
        D3022 := 16#3230;
        D3023 := 16#3136;
        D3024 := 16#3131;
        D3025 := 16#2D32;
        D3026 := 16#3030;
        D3027 := 16#3030;
        D3028 := 16#3030;
        D3029 := 16#3130;
        D3030 := 16#3B37;
        D3031 := 16#6F77;
        D3032 := 16#573D;
        D3033 := 16#324F;
        D3034 := 16#3136;
        D3035 := 16#3131;
        D3036 := 16#3032;
        D3037 := 16#3030;
        D3038 := 16#3B31;
        D3039 := 16#706F;
        D3040 := 16#4F3D;
        D3041 := 16#3050;
        D3042 := 16#3030;
        D3043 := 16#3231;
        D3044 := 16#2020;
        D3045 := 16#3B20;
        D3046 := 16#7374;
        D3047 := 16#323D;
        D3048 := 16#3230;
        D3049 := 16#3136;
        D3050 := 16#3131;
        D3051 := 16#3132;
        D3052 := 16#3335;
        D3053 := 16#3030;
        D3054 := 16#0D32;
        D3055 := 16#000A;
    ELSIF M2188 THEN   (* 範例 A 前 51 位元組 *)
        D3000 := 51;
        D3001 := 16#4F48;
        D3002 := 16#683B;
        D3003 := 16#3D62;
        D3004 := 16#3030;
        D3005 := 16#3231;
        D3006 := 16#3B34;
        D3007 := 16#6F63;
        D3008 := 16#6564;
        D3009 := 16#303D;
        D3010 := 16#3B39;
        D3011 := 16#3D62;
        D3012 := 16#3030;
        D3013 := 16#3331;
        D3014 := 16#733B;
        D3015 := 16#3D6E;
        D3016 := 16#4E53;
        D3017 := 16#3032;
        D3018 := 16#3632;
        D3019 := 16#3131;
        D3020 := 16#3231;
        D3021 := 16#302D;
        D3022 := 16#3030;
        D3023 := 16#3030;
        D3024 := 16#3030;
        D3025 := 16#3731;
        D3026 := 16#003B;
    ELSIF M2187 THEN   (* 範例 A 後 49 位元組 *)
        D3000 := 49;
        D3001 := 16#6F77;
        D3002 := 16#573D;
        D3003 := 16#324F;
        D3004 := 16#3136;
        D3005 := 16#3131;
        D3006 := 16#3032;
        D3007 := 16#3030;
        D3008 := 16#3B31;
        D3009 := 16#706F;
        D3010 := 16#4F3D;
        D3011 := 16#3050;
        D3012 := 16#3030;
        D3013 := 16#3231;
        D3014 := 16#2020;
        D3015 := 16#3B20;
        D3016 := 16#7374;
        D3017 := 16#323D;
        D3018 := 16#3230;
        D3019 := 16#3136;
        D3020 := 16#3131;
        D3021 := 16#3132;
        D3022 := 16#3335;
        D3023 := 16#3030;
        D3024 := 16#0D32;
        D3025 := 16#000A;
    ELSIF M2184 THEN   (* TG + 範例 B 同一包 *)
        D3000 := 114;
        D3001 := 16#4754;
        D3002 := 16#723B;
        D3003 := 16#6469;
        D3004 := 16#303D;
        D3005 := 16#3030;
        D3006 := 16#3731;
        D3007 := 16#0A0D;
        D3008 := 16#4F48;
        D3009 := 16#683B;
        D3010 := 16#3D62;
        D3011 := 16#3034;
        D3012 := 16#3030;
        D3013 := 16#3B30;
        D3014 := 16#6F63;
        D3015 := 16#6564;
        D3016 := 16#303D;
        D3017 := 16#3B37;
        D3018 := 16#3D62;
        D3019 := 16#6138;
        D3020 := 16#4630;
        D3021 := 16#733B;
        D3022 := 16#3D6E;
        D3023 := 16#4241;
        D3024 := 16#4443;
        D3025 := 16#4645;
        D3026 := 16#4847;
        D3027 := 16#4A49;
        D3028 := 16#4C4B;
        D3029 := 16#4E4D;
        D3030 := 16#504F;
        D3031 := 16#5251;
        D3032 := 16#5453;
        D3033 := 16#773B;
        D3034 := 16#3D6F;
        D3035 := 16#2057;
        D3036 := 16#2020;
        D3037 := 16#2020;
        D3038 := 16#2020;
        D3039 := 16#2020;
        D3040 := 16#2020;
        D3041 := 16#6F3B;
        D3042 := 16#3D70;
        D3043 := 16#2020;
        D3044 := 16#2020;
        D3045 := 16#2020;
        D3046 := 16#2020;
        D3047 := 16#2020;
        D3048 := 16#743B;
        D3049 := 16#3D73;
        D3050 := 16#3030;
        D3051 := 16#3030;
        D3052 := 16#3030;
        D3053 := 16#3030;
        D3054 := 16#3030;
        D3055 := 16#3030;
        D3056 := 16#3030;
        D3057 := 16#0A0D;
    ELSIF M2239 THEN   (* TG *)
        D3000 := 14;
        D3001 := 16#4754;
        D3002 := 16#723B;
        D3003 := 16#6469;
        D3004 := 16#303D;
        D3005 := 16#3030;
        D3006 := 16#3731;
        D3007 := 16#0A0D;
    END_IF;
    IF M2238 OR M2185 OR M2189 OR M2188 OR M2187 OR M2184 OR M2239 THEN M2215 := TRUE; END_IF;
END_IF;
M2238 := FALSE;  M2185 := FALSE;  M2189 := FALSE;  M2188 := FALSE;  M2187 := FALSE;  M2184 := FALSE;  M2239 := FALSE;

(* ---- 收到的資料逐位元組處理：LF 結束一行（去掉前面的 CR） ---- *)
IF M2215 THEN
    D2290 := 0;
    WHILE (D2290 < D3000) AND (D2290 < 2046) DO
        Z0 := D2290 / 2;
        D2292:D := INT_TO_DINT(D3001Z0);
        IF D2292:D < 0 THEN D2292:D := D2292:D + 65536; END_IF;
        IF (D2290 MOD 2) = 0 THEN D2291 := DINT_TO_INT(D2292:D MOD 256); ELSE D2291 := DINT_TO_INT(D2292:D / 256); END_IF;
        IF D2291 = 10 THEN
            IF D2294 > 0 THEN
                Z1 := D2294 - 1;
                IF D4100Z1 = 13 THEN D2294 := D2294 - 1; END_IF;
            END_IF;
            IF M2217 OR (D2294 > 0) THEN
                M2218 := NOT M2217 AND (D2294 = 98) AND (D4100 = 72) AND (D4101 = 79) AND (D4102 = 59);   (* HO; *)
                M2220 := NOT M2217 AND (D2294 = 12) AND (D4100 = 84) AND (D4101 = 71) AND (D4102 = 59)
                         AND (D4103 = 114) AND (D4104 = 105) AND (D4105 = 100) AND (D4106 = 61);   (* TG;rid= *)
                IF M2218 THEN
                    IF D4103 <> 104 THEN M2218 := FALSE; END_IF;   (* 'h' *)
                    IF D4104 <> 98 THEN M2218 := FALSE; END_IF;   (* 'b' *)
                    IF D4105 <> 61 THEN M2218 := FALSE; END_IF;   (* '=' *)
                    IF D4111 <> 59 THEN M2218 := FALSE; END_IF;   (* ';' *)
                    IF D4112 <> 99 THEN M2218 := FALSE; END_IF;   (* 'c' *)
                    IF D4113 <> 111 THEN M2218 := FALSE; END_IF;   (* 'o' *)
                    IF D4114 <> 100 THEN M2218 := FALSE; END_IF;   (* 'd' *)
                    IF D4115 <> 101 THEN M2218 := FALSE; END_IF;   (* 'e' *)
                    IF D4116 <> 61 THEN M2218 := FALSE; END_IF;   (* '=' *)
                    IF D4119 <> 59 THEN M2218 := FALSE; END_IF;   (* ';' *)
                    IF D4120 <> 98 THEN M2218 := FALSE; END_IF;   (* 'b' *)
                    IF D4121 <> 61 THEN M2218 := FALSE; END_IF;   (* '=' *)
                    IF D4126 <> 59 THEN M2218 := FALSE; END_IF;   (* ';' *)
                    IF D4127 <> 115 THEN M2218 := FALSE; END_IF;   (* 's' *)
                    IF D4128 <> 110 THEN M2218 := FALSE; END_IF;   (* 'n' *)
                    IF D4129 <> 61 THEN M2218 := FALSE; END_IF;   (* '=' *)
                    IF D4150 <> 59 THEN M2218 := FALSE; END_IF;   (* ';' *)
                    IF D4151 <> 119 THEN M2218 := FALSE; END_IF;   (* 'w' *)
                    IF D4152 <> 111 THEN M2218 := FALSE; END_IF;   (* 'o' *)
                    IF D4153 <> 61 THEN M2218 := FALSE; END_IF;   (* '=' *)
                    IF D4166 <> 59 THEN M2218 := FALSE; END_IF;   (* ';' *)
                    IF D4167 <> 111 THEN M2218 := FALSE; END_IF;   (* 'o' *)
                    IF D4168 <> 112 THEN M2218 := FALSE; END_IF;   (* 'p' *)
                    IF D4169 <> 61 THEN M2218 := FALSE; END_IF;   (* '=' *)
                    IF D4180 <> 59 THEN M2218 := FALSE; END_IF;   (* ';' *)
                    IF D4181 <> 116 THEN M2218 := FALSE; END_IF;   (* 't' *)
                    IF D4182 <> 115 THEN M2218 := FALSE; END_IF;   (* 's' *)
                    IF D4183 <> 61 THEN M2218 := FALSE; END_IF;   (* '=' *)
                    IF (D4106 < 48) OR (D4106 > 57) THEN M2218 := FALSE; END_IF;   (* hb *)
                    IF (D4107 < 48) OR (D4107 > 57) THEN M2218 := FALSE; END_IF;   (* hb *)
                    IF (D4108 < 48) OR (D4108 > 57) THEN M2218 := FALSE; END_IF;   (* hb *)
                    IF (D4109 < 48) OR (D4109 > 57) THEN M2218 := FALSE; END_IF;   (* hb *)
                    IF (D4110 < 48) OR (D4110 > 57) THEN M2218 := FALSE; END_IF;   (* hb *)
                    IF (D4117 < 48) OR (D4117 > 57) THEN M2218 := FALSE; END_IF;   (* code *)
                    IF (D4118 < 48) OR (D4118 > 57) THEN M2218 := FALSE; END_IF;   (* code *)
                    IF NOT (((D4122 >= 48) AND (D4122 <= 57)) OR ((D4122 >= 65) AND (D4122 <= 70)) OR ((D4122 >= 97) AND (D4122 <= 102))) THEN M2218 := FALSE; END_IF;   (* b *)
                    IF NOT (((D4123 >= 48) AND (D4123 <= 57)) OR ((D4123 >= 65) AND (D4123 <= 70)) OR ((D4123 >= 97) AND (D4123 <= 102))) THEN M2218 := FALSE; END_IF;   (* b *)
                    IF NOT (((D4124 >= 48) AND (D4124 <= 57)) OR ((D4124 >= 65) AND (D4124 <= 70)) OR ((D4124 >= 97) AND (D4124 <= 102))) THEN M2218 := FALSE; END_IF;   (* b *)
                    IF NOT (((D4125 >= 48) AND (D4125 <= 57)) OR ((D4125 >= 65) AND (D4125 <= 70)) OR ((D4125 >= 97) AND (D4125 <= 102))) THEN M2218 := FALSE; END_IF;   (* b *)
                    IF (D4130 < 32) OR (D4130 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4131 < 32) OR (D4131 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4132 < 32) OR (D4132 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4133 < 32) OR (D4133 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4134 < 32) OR (D4134 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4135 < 32) OR (D4135 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4136 < 32) OR (D4136 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4137 < 32) OR (D4137 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4138 < 32) OR (D4138 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4139 < 32) OR (D4139 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4140 < 32) OR (D4140 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4141 < 32) OR (D4141 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4142 < 32) OR (D4142 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4143 < 32) OR (D4143 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4144 < 32) OR (D4144 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4145 < 32) OR (D4145 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4146 < 32) OR (D4146 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4147 < 32) OR (D4147 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4148 < 32) OR (D4148 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4149 < 32) OR (D4149 > 126) THEN M2218 := FALSE; END_IF;   (* sn *)
                    IF (D4154 < 32) OR (D4154 > 126) THEN M2218 := FALSE; END_IF;   (* wo *)
                    IF (D4155 < 32) OR (D4155 > 126) THEN M2218 := FALSE; END_IF;   (* wo *)
                    IF (D4156 < 32) OR (D4156 > 126) THEN M2218 := FALSE; END_IF;   (* wo *)
                    IF (D4157 < 32) OR (D4157 > 126) THEN M2218 := FALSE; END_IF;   (* wo *)
                    IF (D4158 < 32) OR (D4158 > 126) THEN M2218 := FALSE; END_IF;   (* wo *)
                    IF (D4159 < 32) OR (D4159 > 126) THEN M2218 := FALSE; END_IF;   (* wo *)
                    IF (D4160 < 32) OR (D4160 > 126) THEN M2218 := FALSE; END_IF;   (* wo *)
                    IF (D4161 < 32) OR (D4161 > 126) THEN M2218 := FALSE; END_IF;   (* wo *)
                    IF (D4162 < 32) OR (D4162 > 126) THEN M2218 := FALSE; END_IF;   (* wo *)
                    IF (D4163 < 32) OR (D4163 > 126) THEN M2218 := FALSE; END_IF;   (* wo *)
                    IF (D4164 < 32) OR (D4164 > 126) THEN M2218 := FALSE; END_IF;   (* wo *)
                    IF (D4165 < 32) OR (D4165 > 126) THEN M2218 := FALSE; END_IF;   (* wo *)
                    IF (D4170 < 32) OR (D4170 > 126) THEN M2218 := FALSE; END_IF;   (* op *)
                    IF (D4171 < 32) OR (D4171 > 126) THEN M2218 := FALSE; END_IF;   (* op *)
                    IF (D4172 < 32) OR (D4172 > 126) THEN M2218 := FALSE; END_IF;   (* op *)
                    IF (D4173 < 32) OR (D4173 > 126) THEN M2218 := FALSE; END_IF;   (* op *)
                    IF (D4174 < 32) OR (D4174 > 126) THEN M2218 := FALSE; END_IF;   (* op *)
                    IF (D4175 < 32) OR (D4175 > 126) THEN M2218 := FALSE; END_IF;   (* op *)
                    IF (D4176 < 32) OR (D4176 > 126) THEN M2218 := FALSE; END_IF;   (* op *)
                    IF (D4177 < 32) OR (D4177 > 126) THEN M2218 := FALSE; END_IF;   (* op *)
                    IF (D4178 < 32) OR (D4178 > 126) THEN M2218 := FALSE; END_IF;   (* op *)
                    IF (D4179 < 32) OR (D4179 > 126) THEN M2218 := FALSE; END_IF;   (* op *)
                    IF (D4184 < 48) OR (D4184 > 57) THEN M2218 := FALSE; END_IF;   (* ts *)
                    IF (D4185 < 48) OR (D4185 > 57) THEN M2218 := FALSE; END_IF;   (* ts *)
                    IF (D4186 < 48) OR (D4186 > 57) THEN M2218 := FALSE; END_IF;   (* ts *)
                    IF (D4187 < 48) OR (D4187 > 57) THEN M2218 := FALSE; END_IF;   (* ts *)
                    IF (D4188 < 48) OR (D4188 > 57) THEN M2218 := FALSE; END_IF;   (* ts *)
                    IF (D4189 < 48) OR (D4189 > 57) THEN M2218 := FALSE; END_IF;   (* ts *)
                    IF (D4190 < 48) OR (D4190 > 57) THEN M2218 := FALSE; END_IF;   (* ts *)
                    IF (D4191 < 48) OR (D4191 > 57) THEN M2218 := FALSE; END_IF;   (* ts *)
                    IF (D4192 < 48) OR (D4192 > 57) THEN M2218 := FALSE; END_IF;   (* ts *)
                    IF (D4193 < 48) OR (D4193 > 57) THEN M2218 := FALSE; END_IF;   (* ts *)
                    IF (D4194 < 48) OR (D4194 > 57) THEN M2218 := FALSE; END_IF;   (* ts *)
                    IF (D4195 < 48) OR (D4195 > 57) THEN M2218 := FALSE; END_IF;   (* ts *)
                    IF (D4196 < 48) OR (D4196 > 57) THEN M2218 := FALSE; END_IF;   (* ts *)
                    IF (D4197 < 48) OR (D4197 > 57) THEN M2218 := FALSE; END_IF;   (* ts *)
                    IF M2218 THEN
                        D2296:D := 0;
                        D2296:D := D2296:D * 10 + INT_TO_DINT(D4106 - 48);
                        D2296:D := D2296:D * 10 + INT_TO_DINT(D4107 - 48);
                        D2296:D := D2296:D * 10 + INT_TO_DINT(D4108 - 48);
                        D2296:D := D2296:D * 10 + INT_TO_DINT(D4109 - 48);
                        D2296:D := D2296:D * 10 + INT_TO_DINT(D4110 - 48);
                        IF D2296:D > 65535 THEN M2218 := FALSE; END_IF;
                    END_IF;
                    IF M2218 THEN
                        IF D2296:D > 32767 THEN D2296:D := D2296:D - 65536; END_IF;
                        D7000 := DINT_TO_INT(D2296:D);
                        D7001 := (D4117 - 48) * 10 + (D4118 - 48);
                        D2296:D := 0;
                        D2298 := D4122;
                        IF D2298 >= 97 THEN D2298 := D2298 - 87; ELSIF D2298 >= 65 THEN D2298 := D2298 - 55; ELSE D2298 := D2298 - 48; END_IF;
                        D2296:D := D2296:D * 16 + INT_TO_DINT(D2298);
                        D2298 := D4123;
                        IF D2298 >= 97 THEN D2298 := D2298 - 87; ELSIF D2298 >= 65 THEN D2298 := D2298 - 55; ELSE D2298 := D2298 - 48; END_IF;
                        D2296:D := D2296:D * 16 + INT_TO_DINT(D2298);
                        D2298 := D4124;
                        IF D2298 >= 97 THEN D2298 := D2298 - 87; ELSIF D2298 >= 65 THEN D2298 := D2298 - 55; ELSE D2298 := D2298 - 48; END_IF;
                        D2296:D := D2296:D * 16 + INT_TO_DINT(D2298);
                        D2298 := D4125;
                        IF D2298 >= 97 THEN D2298 := D2298 - 87; ELSIF D2298 >= 65 THEN D2298 := D2298 - 55; ELSE D2298 := D2298 - 48; END_IF;
                        D2296:D := D2296:D * 16 + INT_TO_DINT(D2298);
                        IF D2296:D > 32767 THEN D2296:D := D2296:D - 65536; END_IF;
                        D7002 := DINT_TO_INT(D2296:D);
                        IF M2091 THEN   (* 第 1 字元放低位元組 *)
                            D7003 := D4130 + D4131 * 256;
                            D7004 := D4132 + D4133 * 256;
                            D7005 := D4134 + D4135 * 256;
                            D7006 := D4136 + D4137 * 256;
                            D7007 := D4138 + D4139 * 256;
                            D7008 := D4140 + D4141 * 256;
                            D7009 := D4142 + D4143 * 256;
                            D7010 := D4144 + D4145 * 256;
                            D7011 := D4146 + D4147 * 256;
                            D7012 := D4148 + D4149 * 256;
                            D7013 := D4154 + D4155 * 256;
                            D7014 := D4156 + D4157 * 256;
                            D7015 := D4158 + D4159 * 256;
                            D7016 := D4160 + D4161 * 256;
                            D7017 := D4162 + D4163 * 256;
                            D7018 := D4164 + D4165 * 256;
                            D7019 := D4170 + D4171 * 256;
                            D7020 := D4172 + D4173 * 256;
                            D7021 := D4174 + D4175 * 256;
                            D7022 := D4176 + D4177 * 256;
                            D7023 := D4178 + D4179 * 256;
                        ELSE            (* 第 1 字元放高位元組 *)
                            D7003 := D4130 * 256 + D4131;
                            D7004 := D4132 * 256 + D4133;
                            D7005 := D4134 * 256 + D4135;
                            D7006 := D4136 * 256 + D4137;
                            D7007 := D4138 * 256 + D4139;
                            D7008 := D4140 * 256 + D4141;
                            D7009 := D4142 * 256 + D4143;
                            D7010 := D4144 * 256 + D4145;
                            D7011 := D4146 * 256 + D4147;
                            D7012 := D4148 * 256 + D4149;
                            D7013 := D4154 * 256 + D4155;
                            D7014 := D4156 * 256 + D4157;
                            D7015 := D4158 * 256 + D4159;
                            D7016 := D4160 * 256 + D4161;
                            D7017 := D4162 * 256 + D4163;
                            D7018 := D4164 * 256 + D4165;
                            D7019 := D4170 * 256 + D4171;
                            D7020 := D4172 * 256 + D4173;
                            D7021 := D4174 * 256 + D4175;
                            D7022 := D4176 * 256 + D4177;
                            D7023 := D4178 * 256 + D4179;
                        END_IF;
                        M2219 := TRUE;
                        IF D4184 <> 48 THEN M2219 := FALSE; END_IF;
                        IF D4185 <> 48 THEN M2219 := FALSE; END_IF;
                        IF D4186 <> 48 THEN M2219 := FALSE; END_IF;
                        IF D4187 <> 48 THEN M2219 := FALSE; END_IF;
                        IF D4188 <> 48 THEN M2219 := FALSE; END_IF;
                        IF D4189 <> 48 THEN M2219 := FALSE; END_IF;
                        IF D4190 <> 48 THEN M2219 := FALSE; END_IF;
                        IF D4191 <> 48 THEN M2219 := FALSE; END_IF;
                        IF D4192 <> 48 THEN M2219 := FALSE; END_IF;
                        IF D4193 <> 48 THEN M2219 := FALSE; END_IF;
                        IF D4194 <> 48 THEN M2219 := FALSE; END_IF;
                        IF D4195 <> 48 THEN M2219 := FALSE; END_IF;
                        IF D4196 <> 48 THEN M2219 := FALSE; END_IF;
                        IF D4197 <> 48 THEN M2219 := FALSE; END_IF;
                        IF NOT M2219 THEN
                            D7024 := (D4184 - 48) * 1000 + (D4185 - 48) * 100 + (D4186 - 48) * 10 + (D4187 - 48);
                            D7025 := (D4188 - 48) * 10 + (D4189 - 48);
                            D7026 := (D4190 - 48) * 10 + (D4191 - 48);
                            D7027 := (D4192 - 48) * 10 + (D4193 - 48);
                            D7028 := (D4194 - 48) * 10 + (D4195 - 48);
                            D7029 := (D4196 - 48) * 10 + (D4197 - 48);
                        END_IF;
                        IF D7161 >= 32767 THEN D7161 := 0; ELSE D7161 := D7161 + 1; END_IF;
                        D2261 := 0;   (* HO 逾時計時重來 *)
                    ELSE
                        IF D7162 >= 32767 THEN D7162 := 0; ELSE D7162 := D7162 + 1; END_IF;
                    END_IF;
                ELSIF M2220 THEN
                    IF (D4107 < 48) OR (D4107 > 57) THEN M2220 := FALSE; END_IF;
                    IF (D4108 < 48) OR (D4108 > 57) THEN M2220 := FALSE; END_IF;
                    IF (D4109 < 48) OR (D4109 > 57) THEN M2220 := FALSE; END_IF;
                    IF (D4110 < 48) OR (D4110 > 57) THEN M2220 := FALSE; END_IF;
                    IF (D4111 < 48) OR (D4111 > 57) THEN M2220 := FALSE; END_IF;
                    IF M2220 THEN
                        IF D7169 >= 32767 THEN D7169 := 0; ELSE D7169 := D7169 + 1; END_IF;
                        IF (D2310 = 0) AND NOT M2234 THEN   (* SICK 讀取中就忽略 *)
                            D2264:D := 0;
                            D2264:D := D2264:D * 10 + INT_TO_DINT(D4107 - 48);
                            D2264:D := D2264:D * 10 + INT_TO_DINT(D4108 - 48);
                            D2264:D := D2264:D * 10 + INT_TO_DINT(D4109 - 48);
                            D2264:D := D2264:D * 10 + INT_TO_DINT(D4110 - 48);
                            D2264:D := D2264:D * 10 + INT_TO_DINT(D4111 - 48);
                            M2234 := TRUE;
                        END_IF;
                    ELSE
                        IF D7162 >= 32767 THEN D7162 := 0; ELSE D7162 := D7162 + 1; END_IF;
                    END_IF;
                ELSE
                    IF D7162 >= 32767 THEN D7162 := 0; ELSE D7162 := D7162 + 1; END_IF;
                END_IF;
            END_IF;
            D2294 := 0;
            M2217 := FALSE;
        ELSIF D2294 < 120 THEN
            Z1 := D2294;
            D4100Z1 := D2291;
            D2294 := D2294 + 1;
        ELSE
            M2217 := TRUE;   (* 一行太長，等到 LF 整行丟掉 *)
        END_IF;
        D2290 := D2290 + 1;
    END_WHILE;
END_IF;
IF D7160 <> 2 THEN D2294 := 0;  M2217 := FALSE; END_IF;   (* 斷線時丟掉半行 *)

(* ================= SICK 條碼機 ================= *)
(* 連線 2：觸發埠（只在 M2198 時用） *)
M2328 := FALSE;  M2329 := FALSE;  M2331 := FALSE;  M2334 := FALSE;
CASE D7164 OF
0:  (* 未連線 *)
    D2300 := 0;
    M2332 := FALSE;
    M2308 := FALSE;
    IF (M2190 AND M2198) THEN
        IF M2236 THEN   (* 模擬測試：不執行 socket 指令，直接當作已連線 *)
            D7164 := 2;
        ELSE
            D2220 := 16#8000;   (* 用控制資料的設定開啟 *)
            D2222 := 16#0200;   (* TCP、socket 通訊、Active open *)
            D2223 := 4002;   (* 本機埠 *)
            IF D239 >= 128 THEN D2224 := (D239 - 256) * 256 + D240; ELSE D2224 := D239 * 256 + D240; END_IF;
            IF D237 >= 128 THEN D2225 := (D237 - 256) * 256 + D238; ELSE D2225 := D237 * 256 + D238; END_IF;
            D2226 := D241;
            M2328 := TRUE;
            D7164 := 1;
        END_IF;
    END_IF;
1:  (* 開啟中 *)
    IF M2320 THEN
        IF M2321 THEN
            D7163 := D2221;  D7172 := 21;   (* 開啟失敗 *)
            M2329 := TRUE;  D2300 := 0;  D7164 := 3;
        ELSE
            D2300 := 0;  D7164 := 2;
        END_IF;
    ELSIF M2236 THEN
        D2300 := 0;  D7164 := 0;   (* 進入模擬測試：直接回未連線（模擬器的 SOCOPEN 不會完成） *)
    ELSIF NOT (M2190 AND M2198) THEN
        M2329 := TRUE;  D2300 := 0;  D7164 := 3;   (* 改回 Modbus：關閉後經 4 回 0 *)
    ELSE
        IF M950 THEN D2300 := D2300 + 1; END_IF;
        IF D2300 >= 100 THEN   (* 10 秒沒完成：當作開啟失敗 *)
            D7172 := 21;
            M2329 := TRUE;  D2300 := 0;  D7164 := 3;
        END_IF;
    END_IF;
2:  (* 已連線 *)
    IF M950 AND (D2300 < 32000) THEN D2300 := D2300 + 1; END_IF;
    IF (M2190 AND M2198) AND NOT M2236 AND NOT M2241 THEN D7172 := 25; END_IF;   (* 對方關閉 *)
    IF NOT (M2190 AND M2198) OR (NOT M2236 AND NOT M2241) OR M2308 THEN
        M2308 := FALSE;  D2300 := 0;
        IF M2236 THEN D7164 := 4; ELSE M2329 := TRUE;  D7164 := 3; END_IF;
    END_IF;
3:  (* 關閉中（最多等 5 秒） *)
    IF M950 THEN D2300 := D2300 + 1; END_IF;
    IF M2322 OR (D2300 >= 50) THEN D2300 := 0;  D7164 := 4; END_IF;
4:  (* 等 3 秒再重連 *)
    M2332 := FALSE;
    IF M950 THEN D2300 := D2300 + 1; END_IF;
    IF (D2300 >= 30) OR NOT (M2190 AND M2198) THEN D2300 := 0;  D7164 := 0; END_IF;
ELSE
    D7164 := 0;
END_CASE;
IF (D7164 = 2) AND NOT M2236 AND M2257 AND NOT M2332 THEN M2331 := TRUE;  M2332 := TRUE; END_IF;
SP_SOCOPEN(M2328, 'U0', 2, D2220, M2320);
SP_SOCCLOSE(M2329, 'U0', 2, D2230, M2322);
SP_SOCRCV(M2331, 'U0', 2, D2234, D4300, M2326);
IF M2326 THEN
    M2332 := FALSE;
    IF M2327 THEN D7163 := D2235;  D7172 := 23; ELSE M2334 := TRUE; END_IF;
END_IF;
(* 連線 3：資料埠 *)
M2348 := FALSE;  M2349 := FALSE;  M2351 := FALSE;  M2354 := FALSE;
CASE D7165 OF
0:  (* 未連線 *)
    D2301 := 0;
    M2352 := FALSE;
    M2309 := FALSE;
    IF M2190 THEN
        IF M2236 THEN   (* 模擬測試：不執行 socket 指令，直接當作已連線 *)
            D7165 := 2;
        ELSE
            D2240 := 16#8000;   (* 用控制資料的設定開啟 *)
            D2242 := 16#0200;   (* TCP、socket 通訊、Active open *)
            D2243 := 4003;   (* 本機埠 *)
            IF D239 >= 128 THEN D2244 := (D239 - 256) * 256 + D240; ELSE D2244 := D239 * 256 + D240; END_IF;
            IF D237 >= 128 THEN D2245 := (D237 - 256) * 256 + D238; ELSE D2245 := D237 * 256 + D238; END_IF;
            D2246 := D242;
            M2348 := TRUE;
            D7165 := 1;
        END_IF;
    END_IF;
1:  (* 開啟中 *)
    IF M2340 THEN
        IF M2341 THEN
            D7163 := D2241;  D7172 := 31;   (* 開啟失敗 *)
            M2349 := TRUE;  D2301 := 0;  D7165 := 3;
        ELSE
            D2301 := 0;  D7165 := 2;
        END_IF;
    ELSIF M2236 THEN
        D2301 := 0;  D7165 := 0;   (* 進入模擬測試：直接回未連線（模擬器的 SOCOPEN 不會完成） *)
    ELSIF NOT M2190 THEN
        M2349 := TRUE;  D2301 := 0;  D7165 := 3;   (* 改回 Modbus：關閉後經 4 回 0 *)
    ELSE
        IF M950 THEN D2301 := D2301 + 1; END_IF;
        IF D2301 >= 100 THEN   (* 10 秒沒完成：當作開啟失敗 *)
            D7172 := 31;
            M2349 := TRUE;  D2301 := 0;  D7165 := 3;
        END_IF;
    END_IF;
2:  (* 已連線 *)
    IF M950 AND (D2301 < 32000) THEN D2301 := D2301 + 1; END_IF;
    IF M2190 AND NOT M2236 AND NOT M2242 THEN D7172 := 35; END_IF;   (* 對方關閉 *)
    IF NOT M2190 OR (NOT M2236 AND NOT M2242) OR M2309 THEN
        M2309 := FALSE;  D2301 := 0;
        IF M2236 THEN D7165 := 4; ELSE M2349 := TRUE;  D7165 := 3; END_IF;
    END_IF;
3:  (* 關閉中（最多等 5 秒） *)
    IF M950 THEN D2301 := D2301 + 1; END_IF;
    IF M2342 OR (D2301 >= 50) THEN D2301 := 0;  D7165 := 4; END_IF;
4:  (* 等 3 秒再重連 *)
    M2352 := FALSE;
    IF M950 THEN D2301 := D2301 + 1; END_IF;
    IF (D2301 >= 30) OR NOT M2190 THEN D2301 := 0;  D7165 := 0; END_IF;
ELSE
    D7165 := 0;
END_CASE;
IF (D7165 = 2) AND NOT M2236 AND M2258 AND NOT M2352 THEN M2351 := TRUE;  M2352 := TRUE; END_IF;
SP_SOCOPEN(M2348, 'U0', 3, D2240, M2340);
SP_SOCCLOSE(M2349, 'U0', 3, D2250, M2342);
SP_SOCRCV(M2351, 'U0', 3, D2254, D5400, M2346);
IF M2346 THEN
    M2352 := FALSE;
    IF M2347 THEN D7163 := D2255;  D7172 := 33; ELSE M2354 := TRUE; END_IF;
END_IF;
(* 連線 2 收到的是 CoLa 回覆（sAN mTCgateon 1），讀出來丟掉即可 *)

IF M2236 AND M2186 AND (D7165 = 2) THEN   (* 模擬 SICK 回條碼 *)
    D5400 := 16;
    D5401 := 16#5402;
    D5402 := 16#5345;
    D5403 := 16#2D54;
    D5404 := 16#5251;
    D5405 := 16#302D;
    D5406 := 16#3030;
    D5407 := 16#0331;
    D5408 := 16#0A0D;
    M2354 := TRUE;
END_IF;
M2186 := FALSE;

M2197 := (D7165 = 2) AND (NOT M2198 OR (D7164 = 2));   (* SICK 可用 *)

(* ---- 資料埠逐位元組：STX 開始、ETX/CR/LF 結束；沒有 STX 的可見字元也直接收 ---- *)
IF M2354 THEN
    D2315 := 0;
    WHILE (D2315 < D5400) AND (D2315 < 2046) DO
        Z2 := D2315 / 2;
        D2318:D := INT_TO_DINT(D5401Z2);
        IF D2318:D < 0 THEN D2318:D := D2318:D + 65536; END_IF;
        IF (D2315 MOD 2) = 0 THEN D2316 := DINT_TO_INT(D2318:D MOD 256); ELSE D2316 := DINT_TO_INT(D2318:D / 256); END_IF;
        IF (D2310 = 1) AND NOT M2301 THEN
            IF D2316 = 2 THEN
                M2299 := TRUE;  D2312 := 0;
            ELSIF (D2316 = 3) OR (D2316 = 13) OR (D2316 = 10) THEN
                IF M2299 THEN M2301 := TRUE;  M2299 := FALSE; END_IF;
            ELSIF (D2316 >= 32) AND (D2316 <= 126) THEN
                M2299 := TRUE;
                IF (D2316 = 59) OR (D2316 = 61) THEN D2316 := 32; END_IF;   (* ';' '=' 會破壞 SC 訊框，換成空白（同中控 _clean） *)
                IF D2312 < 32 THEN
                    Z3 := D2312;
                    D6500Z3 := D2316;
                    D2312 := D2312 + 1;
                END_IF;
            END_IF;
        END_IF;
        D2315 := D2315 + 1;
    END_WHILE;
END_IF;

(* ---- 讀取步序 D2310：0 待命 1 等條碼 2 關閉觸發 3 送 SC ---- *)
CASE D2310 OF
0:  IF M2234 THEN
        M2234 := FALSE;
        D2312 := 0;  M2299 := FALSE;  M2301 := FALSE;  D2311 := 0;
        IF M2197 THEN
            M2300 := TRUE;   (* 送觸發 *)
            D2310 := 1;
        ELSE
            D2310 := 3;      (* SICK 沒連上：直接回 NoRead *)
        END_IF;
    END_IF;
1:  IF M950 THEN D2311 := D2311 + 1; END_IF;
    IF M2301 OR (D2311 >= D249) OR NOT M2197 THEN D2310 := 2; END_IF;
2:  IF (D248 = 0) AND M2197 THEN M2302 := TRUE; END_IF;   (* CoLa：送 gateoff *)
    D2310 := 3;
3:  IF NOT M2301 OR (D2312 = 0) THEN
        D2312 := 0;
        IF D7167 >= 32767 THEN D7167 := 0; ELSE D7167 := D7167 + 1; END_IF;
    END_IF;
    D7174 := D2312;
    IF D7160 = 2 THEN M2232 := TRUE; END_IF;   (* P76 送 SC *)
    D2310 := 0;
ELSE
    D2310 := 0;
END_CASE;
IF NOT M2190 THEN D2310 := 0;  M2234 := FALSE;  M2300 := FALSE;  M2302 := FALSE; END_IF;

(* ---- 觸發訊息送出（連線 2 或 3） ---- *)
M2330 := FALSE;  M2350 := FALSE;
IF M2300 OR M2302 THEN
    IF M2198 THEN
        IF (D7164 = 2) AND NOT M2333 THEN
            IF M2300 THEN
                IF D248 = 0 THEN
                    D6900 := 15;
                    D6901 := 16#7302;
                    D6902 := 16#4E4D;
                    D6903 := 16#6D20;
                    D6904 := 16#4354;
                    D6905 := 16#6167;
                    D6906 := 16#6574;
                    D6907 := 16#6E6F;
                    D6908 := 16#0003;
                ELSE
                    D6900 := 1;
                    D6901 := 16#0002;
                END_IF;
                M2300 := FALSE;
            ELSE
                D6900 := 16;
                D6901 := 16#7302;
                D6902 := 16#4E4D;
                D6903 := 16#6D20;
                D6904 := 16#4354;
                D6905 := 16#6167;
                D6906 := 16#6574;
                D6907 := 16#666F;
                D6908 := 16#0366;
                M2302 := FALSE;
            END_IF;
            IF NOT M2236 THEN M2330 := TRUE;  M2333 := TRUE; END_IF;
        ELSIF D7164 <> 2 THEN
            M2300 := FALSE;  M2302 := FALSE;
        END_IF;
    ELSE
        IF (D7165 = 2) AND NOT M2353 THEN
            IF M2300 THEN
                IF D248 = 0 THEN
                    D6950 := 15;
                    D6951 := 16#7302;
                    D6952 := 16#4E4D;
                    D6953 := 16#6D20;
                    D6954 := 16#4354;
                    D6955 := 16#6167;
                    D6956 := 16#6574;
                    D6957 := 16#6E6F;
                    D6958 := 16#0003;
                ELSE
                    D6950 := 1;
                    D6951 := 16#0002;
                END_IF;
                M2300 := FALSE;
            ELSE
                D6950 := 16;
                D6951 := 16#7302;
                D6952 := 16#4E4D;
                D6953 := 16#6D20;
                D6954 := 16#4354;
                D6955 := 16#6167;
                D6956 := 16#6574;
                D6957 := 16#666F;
                D6958 := 16#0366;
                M2302 := FALSE;
            END_IF;
            IF NOT M2236 THEN M2350 := TRUE;  M2353 := TRUE; END_IF;
        ELSIF D7165 <> 2 THEN
            M2300 := FALSE;  M2302 := FALSE;
        END_IF;
    END_IF;
END_IF;
IF D7164 <> 2 THEN M2333 := FALSE; END_IF;
IF D7165 <> 2 THEN M2353 := FALSE; END_IF;
SP_SOCSND(M2330, 'U0', 2, D2232, D6900, M2324);
SP_SOCSND(M2350, 'U0', 3, D2252, D6950, M2344);
IF M2324 THEN
    M2333 := FALSE;
    IF M2325 THEN D7163 := D2233;  D7172 := 22;  M2308 := TRUE; END_IF;
END_IF;
IF M2344 THEN
    M2353 := FALSE;
    IF M2345 THEN D7163 := D2253;  D7172 := 32;  M2309 := TRUE; END_IF;
END_IF;
