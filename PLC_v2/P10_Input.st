(* P10_Input  X -> M  v2 *)
IF NOT M50 THEN
    M0 := X0; M1 := X1; M2 := X2; M3 := X3; M4 := X4; M5 := X5; M6 := X6; M7 := X7;
    M10 := X10; M11 := X11; M12 := X12; M13 := X13; M14 := X14; M15 := X15; M16 := X16; M17 := X17;
ELSE
    M0 := X0 AND NOT M57;
    M1 := FALSE; M2 := FALSE; M3 := FALSE; M4 := FALSE; M5 := M54; M6 := M55; M7 := FALSE;
    M10 := M60; M11 := M61; M12 := M62; M13 := M63; M14 := M64; M15 := M65; M16 := M66; M17 := M67;
END_IF;
M20 := M1 OR M100;
M21 := M3 OR M101;
M22 := M2 OR M102;
M30 := M20 AND NOT M31;  M31 := M20;
M32 := M21 AND NOT M33;  M33 := M21;
M34 := M22 AND NOT M35;  M35 := M22;
