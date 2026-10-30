(* P00_Init  首掃描初始化  v2 *)
IF SM402 THEN
    IF (D200 < 1) OR (D200 > 3) THEN D200 := 1; END_IF;   (* RC75 TABLE 1~3 *)
    IF D210 <= 0 THEN D210 := 30;  END_IF;   (* 啟動逾時 3.0s *)
    IF D211 <= 0 THEN D211 := 150; END_IF;   (* 鎖付逾時 15.0s *)
    IF D212 <= 0 THEN D212 := 100; END_IF;   (* 原點復歸逾時 10.0s *)
    IF D521 <= 0 THEN D521 := 20;  END_IF;   (* 模擬鎖付時間 2.0s *)
    M50 := FALSE; M59 := FALSE; M200 := FALSE; M201 := FALSE; M301 := FALSE;
    M310 := FALSE; M320 := FALSE; M321 := FALSE; M121 := FALSE;
    D100 := 0; D101 := 0; D110 := 0; D111 := 0;
END_IF;
