# GX Works3 操作步驟(鎖螺絲機 v2,僅模擬)

**安全:全程只用 GX Simulator3。不要按 Online → Write to PLC,不要設定連線目標到實體 PLC,不要對 HMI 傳送。**

程式檔:`D:\Devin_project\screw-machine\PLC_v2\` P00、P05、P10、P20、P30、P40、P70 共 7 個 .st(UTF-8)。

## A. 建專案
1. 啟動 GX Works3,Help → Version Information,記下版本。
2. Project → New:Series = FX5CPU,Type = FX5S(沒有就選 FX5UJ 並記錄),Program Language = ST。
3. Navigation 視窗 Program → Scan → MAIN。刪除預設空白區塊。
4. 對 Scan 按右鍵 → Add New Data → Program,Language = ST,名稱依序 P00_Init、P05_Sim、P10_Input、P20_Mode_Alarm、P30_AutoSeq、P40_Reset_Manual、P70_Output_Data(順序不可錯)。
5. 每個區塊開啟後,用記事本開對應 .st,全選複製、貼進編輯器。
6. Parameter → FX5CPU → CPU Parameter → Memory/Device Setting → Device/Label Memory Area:把 D200–D499 設為 Latch(停電保持)。
7. Convert → Rebuild All。
8. 存檔到 `D:\Devin_project\screw-machine\ScrewMachine_v2.gx3`。

## B. 編譯錯誤處理
- 逐一記錄訊息與行號。
- 若 `D300:D`、`D302:D`、`D304:D` 被拒:Global Label 宣告 DINT 標籤 cntOK、cntNG、cntAll,分別分配到 D300、D302、D304,程式中的 `D300:D` → `cntOK`、`D302:D` → `cntNG`、`D304:D` → `cntAll`(P30、P70)。
- 其他錯誤只做最小修正,記錄修改前後。修改後的 .st 另存到 PLC_v2 資料夾。

## C. 模擬
1. Debug → Simulation → Start Simulation,寫入模擬器並 RUN。
2. Device/Buffer Memory Batch Monitor 監看 D100、D110、M200、M202、M140–M149、D300、D302、D304。
3. 測試(每項記錄實際值):
   - (a) M50=ON → M202 應 ON。
   - (b) M100 按一下 → M200 ON、D100=10。
   - (c) M53 按一下 → D100 走 20→30→40→50→60→10;D300、D304 各 +1。
   - (d) 再按 M53,再 +1。
   - (e) M52=ON 再按 M53 → M145 ON、D302 +1、M200 OFF。
   - (f) M52=OFF、M102 按一下 → M145 OFF、D110 走 1→2→0。
   - (g) 啟動後設 M51=ON → M141 ON、自動停止;復歸後清除。
   - (h) M57=ON → M140 ON;M57 仍 ON 時復歸不清,M57=OFF 再復歸才清。
   - (i) D521 改 50,按 M53,D100=40 時按 M101 → 這顆鎖完回 10 後 M200 OFF;再改回 20。
   - (j) D521 改 200 → 15 秒時 M144 ON;改回 20。
   - (k) M103 切手動(M201 ON),按住 M113 → M412 ON。
   - (l) M130 按一下 → 計數歸零。
4. 停止模擬、存檔,把結果填入 `GXW3_test_report.md`。
