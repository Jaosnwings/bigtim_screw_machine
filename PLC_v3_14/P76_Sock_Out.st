(* ============================================================
   P76_Sock_Out  中控 socket 傳輸（輸出側，P75_MES_Out 之後執行）  v3.14
   本檔由 tools/gen_sock_st.py 產生。D236 = 0（M2190 OFF）時什麼都不做。
   連上後送一次 HI；每 1 秒以及 D7107 或 D7105 變化時送 ST；SICK 讀完送 SC。一次只送一筆，等完成再送下一筆。
   組字串：D6600~ 每字 1 字元（長度 D2320）→ D6800 長度、D6801~ 每字 2 字元（第 1 字元在低位元組）
   ============================================================ *)

M2303 := SM412 AND NOT M2304;   (* 每秒一次 *)
M2304 := SM412;
IF D7160 <> 2 THEN
    M2230 := FALSE;  M2231 := FALSE;  M2232 := FALSE;  M2233 := FALSE;
ELSIF M2303 OR (D7107 <> D2262) OR (D7105 <> D2263) THEN
    M2231 := TRUE;
END_IF;

M2305 := FALSE;
IF (D7160 = 2) AND NOT M2233 THEN
    D2325 := 0;
    IF M2230 THEN   (* HI *)
        D6600 := 72;   (* 'H' *)
        D6601 := 73;   (* 'I' *)
        D6602 := 59;   (* ';' *)
        D6603 := 115;   (* 's' *)
        D6604 := 116;   (* 't' *)
        D6605 := 61;   (* '=' *)
        D6606 := 48;   (* '0' *)
        D6607 := 50;   (* '2' *)
        D6608 := 59;   (* ';' *)
        D6609 := 101;   (* 'e' *)
        D6610 := 113;   (* 'q' *)
        D6611 := 61;   (* '=' *)
        D6612 := 77;   (* 'M' *)
        D6613 := 67;   (* 'C' *)
        D6614 := 45;   (* '-' *)
        D6615 := 68;   (* 'D' *)
        D6616 := 48;   (* '0' *)
        D6617 := 48;   (* '0' *)
        D6618 := 50;   (* '2' *)
        D6619 := 32;   (* ' ' *)
        D6620 := 59;   (* ';' *)
        D6621 := 118;   (* 'v' *)
        D6622 := 101;   (* 'e' *)
        D6623 := 114;   (* 'r' *)
        D6624 := 61;   (* '=' *)
        D2322:D := INT_TO_DINT(D7106);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 9999 THEN D2322:D := 9999; END_IF;
        D6628 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6627 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6626 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6625 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6629 := 59;   (* ';' *)
        D6630 := 112;   (* 'p' *)
        D6631 := 114;   (* 'r' *)
        D6632 := 111;   (* 'o' *)
        D6633 := 116;   (* 't' *)
        D6634 := 111;   (* 'o' *)
        D6635 := 61;   (* '=' *)
        D6636 := 48;   (* '0' *)
        D6637 := 49;   (* '1' *)
        D6638 := 13;
        D6639 := 10;
        D2320 := 40;   (* 位元組數（含 CR LF） *)
        M2230 := FALSE;
        D2325 := 1;
    ELSIF M2232 THEN   (* SC *)
        D6600 := 83;   (* 'S' *)
        D6601 := 67;   (* 'C' *)
        D6602 := 59;   (* ';' *)
        D6603 := 114;   (* 'r' *)
        D6604 := 105;   (* 'i' *)
        D6605 := 100;   (* 'd' *)
        D6606 := 61;   (* '=' *)
        D2322:D := D2264:D;
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 99999 THEN D2322:D := 99999; END_IF;
        D6611 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6610 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6609 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6608 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6607 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6612 := 59;   (* ';' *)
        D6613 := 114;   (* 'r' *)
        D6614 := 97;   (* 'a' *)
        D6615 := 119;   (* 'w' *)
        D6616 := 61;   (* '=' *)
        IF D2312 > 0 THEN
            IF D2312 > 0 THEN D6617 := D6500; ELSE D6617 := 32; END_IF;
            IF D2312 > 1 THEN D6618 := D6501; ELSE D6618 := 32; END_IF;
            IF D2312 > 2 THEN D6619 := D6502; ELSE D6619 := 32; END_IF;
            IF D2312 > 3 THEN D6620 := D6503; ELSE D6620 := 32; END_IF;
            IF D2312 > 4 THEN D6621 := D6504; ELSE D6621 := 32; END_IF;
            IF D2312 > 5 THEN D6622 := D6505; ELSE D6622 := 32; END_IF;
            IF D2312 > 6 THEN D6623 := D6506; ELSE D6623 := 32; END_IF;
            IF D2312 > 7 THEN D6624 := D6507; ELSE D6624 := 32; END_IF;
            IF D2312 > 8 THEN D6625 := D6508; ELSE D6625 := 32; END_IF;
            IF D2312 > 9 THEN D6626 := D6509; ELSE D6626 := 32; END_IF;
            IF D2312 > 10 THEN D6627 := D6510; ELSE D6627 := 32; END_IF;
            IF D2312 > 11 THEN D6628 := D6511; ELSE D6628 := 32; END_IF;
            IF D2312 > 12 THEN D6629 := D6512; ELSE D6629 := 32; END_IF;
            IF D2312 > 13 THEN D6630 := D6513; ELSE D6630 := 32; END_IF;
            IF D2312 > 14 THEN D6631 := D6514; ELSE D6631 := 32; END_IF;
            IF D2312 > 15 THEN D6632 := D6515; ELSE D6632 := 32; END_IF;
            IF D2312 > 16 THEN D6633 := D6516; ELSE D6633 := 32; END_IF;
            IF D2312 > 17 THEN D6634 := D6517; ELSE D6634 := 32; END_IF;
            IF D2312 > 18 THEN D6635 := D6518; ELSE D6635 := 32; END_IF;
            IF D2312 > 19 THEN D6636 := D6519; ELSE D6636 := 32; END_IF;
            IF D2312 > 20 THEN D6637 := D6520; ELSE D6637 := 32; END_IF;
            IF D2312 > 21 THEN D6638 := D6521; ELSE D6638 := 32; END_IF;
            IF D2312 > 22 THEN D6639 := D6522; ELSE D6639 := 32; END_IF;
            IF D2312 > 23 THEN D6640 := D6523; ELSE D6640 := 32; END_IF;
            IF D2312 > 24 THEN D6641 := D6524; ELSE D6641 := 32; END_IF;
            IF D2312 > 25 THEN D6642 := D6525; ELSE D6642 := 32; END_IF;
            IF D2312 > 26 THEN D6643 := D6526; ELSE D6643 := 32; END_IF;
            IF D2312 > 27 THEN D6644 := D6527; ELSE D6644 := 32; END_IF;
            IF D2312 > 28 THEN D6645 := D6528; ELSE D6645 := 32; END_IF;
            IF D2312 > 29 THEN D6646 := D6529; ELSE D6646 := 32; END_IF;
            IF D2312 > 30 THEN D6647 := D6530; ELSE D6647 := 32; END_IF;
            IF D2312 > 31 THEN D6648 := D6531; ELSE D6648 := 32; END_IF;
        ELSE
            D6617 := 78;
            D6618 := 111;
            D6619 := 82;
            D6620 := 101;
            D6621 := 97;
            D6622 := 100;
            D6623 := 32;
            D6624 := 32;
            D6625 := 32;
            D6626 := 32;
            D6627 := 32;
            D6628 := 32;
            D6629 := 32;
            D6630 := 32;
            D6631 := 32;
            D6632 := 32;
            D6633 := 32;
            D6634 := 32;
            D6635 := 32;
            D6636 := 32;
            D6637 := 32;
            D6638 := 32;
            D6639 := 32;
            D6640 := 32;
            D6641 := 32;
            D6642 := 32;
            D6643 := 32;
            D6644 := 32;
            D6645 := 32;
            D6646 := 32;
            D6647 := 32;
            D6648 := 32;
        END_IF;
        D6649 := 13;
        D6650 := 10;
        D2320 := 51;   (* 位元組數（含 CR LF） *)
        M2232 := FALSE;
        D2325 := 3;
    ELSIF M2231 THEN   (* ST *)
        D6600 := 83;   (* 'S' *)
        D6601 := 84;   (* 'T' *)
        D6602 := 59;   (* ';' *)
        D6603 := 104;   (* 'h' *)
        D6604 := 98;   (* 'b' *)
        D6605 := 61;   (* '=' *)
        D2322:D := INT_TO_DINT(D7100);
        IF D2322:D < 0 THEN D2322:D := D2322:D + 65536; END_IF;
        IF D2322:D > 99999 THEN D2322:D := 99999; END_IF;
        D6610 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6609 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6608 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6607 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6606 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6611 := 59;   (* ';' *)
        D6612 := 114;   (* 'r' *)
        D6613 := 117;   (* 'u' *)
        D6614 := 110;   (* 'n' *)
        D6615 := 61;   (* '=' *)
        D2322:D := INT_TO_DINT(D7105);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 9 THEN D2322:D := 9; END_IF;
        D6616 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6617 := 59;   (* ';' *)
        D6618 := 115;   (* 's' *)
        D6619 := 119;   (* 'w' *)
        D6620 := 61;   (* '=' *)
        D2322:D := INT_TO_DINT(D7107);
        IF D2322:D < 0 THEN D2322:D := D2322:D + 65536; END_IF;
        D2324 := DINT_TO_INT(D2322:D MOD 16);
        IF D2324 < 10 THEN D6624 := D2324 + 48; ELSE D6624 := D2324 + 55; END_IF;
        D2322:D := D2322:D / 16;
        D2324 := DINT_TO_INT(D2322:D MOD 16);
        IF D2324 < 10 THEN D6623 := D2324 + 48; ELSE D6623 := D2324 + 55; END_IF;
        D2322:D := D2322:D / 16;
        D2324 := DINT_TO_INT(D2322:D MOD 16);
        IF D2324 < 10 THEN D6622 := D2324 + 48; ELSE D6622 := D2324 + 55; END_IF;
        D2322:D := D2322:D / 16;
        D2324 := DINT_TO_INT(D2322:D MOD 16);
        IF D2324 < 10 THEN D6621 := D2324 + 48; ELSE D6621 := D2324 + 55; END_IF;
        D6625 := 59;   (* ';' *)
        D6626 := 116;   (* 't' *)
        D6627 := 48;   (* '0' *)
        D6628 := 61;   (* '=' *)
        D2322:D := INT_TO_DINT(D7110);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 9999 THEN D2322:D := 9999; END_IF;
        D6632 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6631 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6630 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6629 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := INT_TO_DINT(D7111);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 99 THEN D2322:D := 99; END_IF;
        D6634 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6633 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := INT_TO_DINT(D7112);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 99 THEN D2322:D := 99; END_IF;
        D6636 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6635 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := INT_TO_DINT(D7113);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 99 THEN D2322:D := 99; END_IF;
        D6638 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6637 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := INT_TO_DINT(D7114);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 99 THEN D2322:D := 99; END_IF;
        D6640 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6639 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := INT_TO_DINT(D7115);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 99 THEN D2322:D := 99; END_IF;
        D6642 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6641 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6643 := 59;   (* ';' *)
        D6644 := 116;   (* 't' *)
        D6645 := 49;   (* '1' *)
        D6646 := 61;   (* '=' *)
        D2322:D := INT_TO_DINT(D7116);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 9999 THEN D2322:D := 9999; END_IF;
        D6650 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6649 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6648 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6647 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := INT_TO_DINT(D7117);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 99 THEN D2322:D := 99; END_IF;
        D6652 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6651 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := INT_TO_DINT(D7118);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 99 THEN D2322:D := 99; END_IF;
        D6654 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6653 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := INT_TO_DINT(D7119);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 99 THEN D2322:D := 99; END_IF;
        D6656 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6655 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := INT_TO_DINT(D7120);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 99 THEN D2322:D := 99; END_IF;
        D6658 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6657 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := INT_TO_DINT(D7121);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 99 THEN D2322:D := 99; END_IF;
        D6660 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6659 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6661 := 59;   (* ';' *)
        D6662 := 99;   (* 'c' *)
        D6663 := 116;   (* 't' *)
        D6664 := 61;   (* '=' *)
        D2322:D := INT_TO_DINT(D7122);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 99999 THEN D2322:D := 99999; END_IF;
        D6669 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6668 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6667 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6666 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6665 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6670 := 59;   (* ';' *)
        D6671 := 116;   (* 't' *)
        D6672 := 113;   (* 'q' *)
        D6673 := 61;   (* '=' *)
        D2322:D := INT_TO_DINT(D7140);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 99999 THEN D2322:D := 99999; END_IF;
        D6678 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6677 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6676 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6675 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6674 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6679 := 59;   (* ';' *)
        D6680 := 97;   (* 'a' *)
        D6681 := 110;   (* 'n' *)
        D6682 := 103;   (* 'g' *)
        D6683 := 61;   (* '=' *)
        D2322:D := D7141:D;
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 99999999 THEN D2322:D := 99999999; END_IF;
        D6691 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6690 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6689 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6688 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6687 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6686 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6685 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6684 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6692 := 59;   (* ';' *)
        D6693 := 116;   (* 't' *)
        D6694 := 106;   (* 'j' *)
        D6695 := 61;   (* '=' *)
        D2322:D := INT_TO_DINT(D7143);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 9 THEN D2322:D := 9; END_IF;
        D6696 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6697 := 59;   (* ';' *)
        D6698 := 97;   (* 'a' *)
        D6699 := 106;   (* 'j' *)
        D6700 := 61;   (* '=' *)
        D2322:D := INT_TO_DINT(D7144);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 9 THEN D2322:D := 9; END_IF;
        D6701 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6702 := 59;   (* ';' *)
        D6703 := 104;   (* 'h' *)
        D6704 := 106;   (* 'j' *)
        D6705 := 61;   (* '=' *)
        D2322:D := INT_TO_DINT(D7145);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 9 THEN D2322:D := 9; END_IF;
        D6706 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6707 := 59;   (* ';' *)
        D6708 := 116;   (* 't' *)
        D6709 := 116;   (* 't' *)
        D6710 := 61;   (* '=' *)
        D2322:D := INT_TO_DINT(D7146);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 99999 THEN D2322:D := 99999; END_IF;
        D6715 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6714 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6713 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6712 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6711 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6716 := 59;   (* ';' *)
        D6717 := 115;   (* 's' *)
        D6718 := 116;   (* 't' *)
        D6719 := 111;   (* 'o' *)
        D6720 := 112;   (* 'p' *)
        D6721 := 61;   (* '=' *)
        D2322:D := INT_TO_DINT(D7147);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 9999 THEN D2322:D := 9999; END_IF;
        D6725 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6724 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6723 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D2322:D := D2322:D / 10;
        D6722 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6726 := 59;   (* ';' *)
        D6727 := 99;   (* 'c' *)
        D6728 := 115;   (* 's' *)
        D6729 := 61;   (* '=' *)
        D2322:D := INT_TO_DINT(D7148);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 9 THEN D2322:D := 9; END_IF;
        D6730 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6731 := 59;   (* ';' *)
        D6732 := 110;   (* 'n' *)
        D6733 := 61;   (* '=' *)
        D2322:D := INT_TO_DINT(D222);
        IF D2322:D < 0 THEN D2322:D := 0; END_IF;
        IF D2322:D > 9 THEN D2322:D := 9; END_IF;
        D6734 := DINT_TO_INT(D2322:D MOD 10) + 48;
        D6735 := 13;
        D6736 := 10;
        D2320 := 137;   (* 位元組數（含 CR LF） *)
        D2262 := D7107;  D2263 := D7105;
        M2231 := FALSE;
        D2325 := 2;
    END_IF;
    IF D2325 <> 0 THEN
        D6801 := D6600 + D6601 * 256;
        D6802 := D6602 + D6603 * 256;
        D6803 := D6604 + D6605 * 256;
        D6804 := D6606 + D6607 * 256;
        D6805 := D6608 + D6609 * 256;
        D6806 := D6610 + D6611 * 256;
        D6807 := D6612 + D6613 * 256;
        D6808 := D6614 + D6615 * 256;
        D6809 := D6616 + D6617 * 256;
        D6810 := D6618 + D6619 * 256;
        D6811 := D6620 + D6621 * 256;
        D6812 := D6622 + D6623 * 256;
        D6813 := D6624 + D6625 * 256;
        D6814 := D6626 + D6627 * 256;
        D6815 := D6628 + D6629 * 256;
        D6816 := D6630 + D6631 * 256;
        D6817 := D6632 + D6633 * 256;
        D6818 := D6634 + D6635 * 256;
        D6819 := D6636 + D6637 * 256;
        D6820 := D6638 + D6639 * 256;
        D6821 := D6640 + D6641 * 256;
        D6822 := D6642 + D6643 * 256;
        D6823 := D6644 + D6645 * 256;
        D6824 := D6646 + D6647 * 256;
        D6825 := D6648 + D6649 * 256;
        D6826 := D6650 + D6651 * 256;
        D6827 := D6652 + D6653 * 256;
        D6828 := D6654 + D6655 * 256;
        D6829 := D6656 + D6657 * 256;
        D6830 := D6658 + D6659 * 256;
        D6831 := D6660 + D6661 * 256;
        D6832 := D6662 + D6663 * 256;
        D6833 := D6664 + D6665 * 256;
        D6834 := D6666 + D6667 * 256;
        D6835 := D6668 + D6669 * 256;
        D6836 := D6670 + D6671 * 256;
        D6837 := D6672 + D6673 * 256;
        D6838 := D6674 + D6675 * 256;
        D6839 := D6676 + D6677 * 256;
        D6840 := D6678 + D6679 * 256;
        D6841 := D6680 + D6681 * 256;
        D6842 := D6682 + D6683 * 256;
        D6843 := D6684 + D6685 * 256;
        D6844 := D6686 + D6687 * 256;
        D6845 := D6688 + D6689 * 256;
        D6846 := D6690 + D6691 * 256;
        D6847 := D6692 + D6693 * 256;
        D6848 := D6694 + D6695 * 256;
        D6849 := D6696 + D6697 * 256;
        D6850 := D6698 + D6699 * 256;
        D6851 := D6700 + D6701 * 256;
        D6852 := D6702 + D6703 * 256;
        D6853 := D6704 + D6705 * 256;
        D6854 := D6706 + D6707 * 256;
        D6855 := D6708 + D6709 * 256;
        D6856 := D6710 + D6711 * 256;
        D6857 := D6712 + D6713 * 256;
        D6858 := D6714 + D6715 * 256;
        D6859 := D6716 + D6717 * 256;
        D6860 := D6718 + D6719 * 256;
        D6861 := D6720 + D6721 * 256;
        D6862 := D6722 + D6723 * 256;
        D6863 := D6724 + D6725 * 256;
        D6864 := D6726 + D6727 * 256;
        D6865 := D6728 + D6729 * 256;
        D6866 := D6730 + D6731 * 256;
        D6867 := D6732 + D6733 * 256;
        D6868 := D6734 + D6735 * 256;
        D6869 := D6736 + D6737 * 256;
        D6800 := D2320;
        D2326 := D2325;
        IF M2236 THEN
            M2306 := TRUE;   (* 模擬測試：當作送出完成 *)
        ELSE
            M2305 := TRUE;  M2233 := TRUE;
        END_IF;
    END_IF;
END_IF;
SP_SOCSND(M2305, 'U0', 1, D2212, D6800, M2204);
IF M2204 THEN
    M2233 := FALSE;
    IF M2205 THEN
        D7163 := D2213;  D7172 := 12;  M2307 := TRUE;   (* 送出失敗：P16 關閉後重連 *)
    ELSE
        M2306 := TRUE;
    END_IF;
END_IF;
IF M2306 THEN
    M2306 := FALSE;
    CASE D2326 OF
    1: IF D7173 >= 32767 THEN D7173 := 0; ELSE D7173 := D7173 + 1; END_IF;
    2: IF D7168 >= 32767 THEN D7168 := 0; ELSE D7168 := D7168 + 1; END_IF;
    3: IF D7166 >= 32767 THEN D7166 := 0; ELSE D7166 := D7166 + 1; END_IF;
    END_CASE;
END_IF;
