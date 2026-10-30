# GX Works3 模擬測試報告（鎖螺絲機 v2）

- 日期：2026-10-30 06:47–07:12（台北）
- 執行方式：Claude 以電腦操作控制 GX Works3，依 `GXW3_操作步驟.md` 進行
- **安全**：全程只用 GX Simulator3（狀態列 `Simulation (1)`），未執行 Online → Write to PLC，未設定實體 PLC 連線目標，未連 HMI。模擬結束後狀態列回到 `Host`。

## A. 專案建立

| 項目 | 結果 |
|---|---|
| GX Works3 版本 | **1.126G** |
| Series / Type | FX5CPU / **FX5S**（有此型號，未改用 FX5UJ） |
| Program Language | ST |
| 程式區塊 | Scan → MAIN 下依序 P00_Init、P05_Sim、P10_Input、P20_Mode_Alarm、P30_AutoSeq、P40_Reset_Manual、P70_Output_Data（皆 ST）；預設 ProgPou 已刪除 |
| 程式內容 | 7 個 .st 原樣貼上（只去掉行首縮排，編輯器會自動縮排；邏輯未改） |
| 停電保持 | CPU Parameter → Memory/Device Setting → Device/Label Memory Area → Device (high speed) Setting → Data Register D 的 Latch(1) 由預設 **128–1999 改為 200–499**（300 點）。重開參數畫面確認已保存 |
| Rebuild All | **Error 0、Warning 0**（Retain，1.228 s） |
| 存檔 | `D:\Devin_project\screw-machine\ScrewMachine_v2.gx3`（未壓縮格式） |

## B. 編譯錯誤處理

無錯誤。`D300:D`、`D302:D`、`D304:D` 寫法被 FX5S 接受，**不需要**改成 Global Label，PLC_v2 內 .st 未修改、也沒有另存修改版。

## C. 模擬測試結果

前置條件：模擬器裡 X 全為 OFF，`M0 := X0 AND NOT M57` 使 M140 一開始就是 ON。因此先把 **X0 設為 ON**（模擬急停正常），再 M50=ON、按 M102 復歸清掉 M140。

監看方式：Watch 1，D300/D302/D304 以 Double Word [Signed] 顯示。另外加看 X0、M0、M50、D500、D521、M203，(k) 時加 M63、M13、D520。

| # | 測試 | 實際值 | 判定 |
|---|---|---|---|
| a | M50=ON → M202 ON | X0=ON、M50=ON、M102 復歸後 M203=OFF、**M202=ON** | PASS |
| b | M100 按一下 → M200 ON、D100=10 | **M200=ON、D100=10** | PASS |
| c | M53 按一下 → D100 20→30→40→50→60→10；D300、D304 +1 | 取樣看到 D100 **30→40→10**；週期中 M412 有 ON；**D300 0→1、D304 0→1**、D302=0；結束後 M200 仍 ON、D100=10。20/50/60 停留時間短於 Watch 更新週期，所以沒取樣到 | PASS（中間步序只看到一部分） |
| d | 再按 M53，再 +1 | D100 取樣 **30→40→10**；**D300=2、D304=2** | PASS |
| e | M52=ON 再按 M53 → M145 ON、D302 +1、M200 OFF | **M145=ON、D302 0→1**、D304 2→3、D300 不變（2）、**M200=OFF**、D100=0、M202=OFF | PASS |
| f | M52=OFF、M102 按一下 → M145 OFF、D110 1→2→0 | D110 取樣 **1→2→0**；**M145=OFF**、M202=ON | PASS |
| g | 啟動後 M51=ON → M141 ON、自動停止；復歸後清除 | M100 啟動（D500 歸零，表示 D100 有變化）→ M51=ON：**M141=ON、M203=ON、M200=OFF**、D100=0。M102 復歸：D110=1 時 M411 讓 M51 自動 OFF，**M141=OFF**、M202=ON | PASS |
| h | M57=ON → M140 ON；M57 ON 時復歸不清，OFF 後再復歸才清 | M57=ON：**M140=ON**、M0=OFF、M202=OFF；M57 仍 ON 按 M102：**M140 維持 ON**；M57=OFF（M0 回 ON，M140 仍 ON）後再按 M102：**M140=OFF**、M202=ON | PASS |
| i | D521=50，按 M53，D100=40 時按 M101 → 這顆鎖完回 10 後 M200 OFF；改回 20 | D521=50、M100 啟動、M53；**D100=40 時按 M101**；這顆鎖完 **D300 2→3、D304 3→4**，之後 **M200=OFF、D100=0**、M203=OFF（不是異常停止）；D521 已改回 20 | PASS |
| j | D521=200 → 15 秒時 M144 ON；改回 20 | 步序 40 時 D500 取樣 114→147，到 150（15.0 s）時 **M144=ON**、M200=OFF；D300/D302/D304 不變。D521 改回 20，M102 復歸後 M144=OFF | PASS |
| k | M103 切手動（M201 ON），按住 M113 → M412 ON | M103 按一下：**M201=ON**。按住 M113 約 5 s：**Watch 裡的 M412 一直是 FALSE**；同時 M63/M13=TRUE，D520 一直重新從 0 數到 20（取樣 4、18、11、5、18） | **部分通過**（見下方發現 1） |
| l | M130 按一下 → 計數歸零 | D300/D302/D304 **3/1/4 → 0/0/0** | PASS |

結果：11 項 PASS，1 項部分通過（k）。(k) 已依據 RC75 圖面修正並重測通過，見下方「修正與重測」。

## 發現

1. **(k) 手動鎖付時 M412 只 ON 一個 scan。** P40：`M412 := ... (M201 AND M113 AND ... AND NOT M13 AND ...)`。M412 一 ON，P05 的模擬起子就把 M63 設 ON，M13 跟著 ON，下一個 scan 的 `NOT M13` 就把 M412 關掉。起子模擬跑完 2 s，M13 OFF，M412 又出現一個 scan 的脈衝，於是持續循環。所以按住 M113 時 Y12 是每約 2 s 一個 scan 的脈衝，不是持續 ON。如果起子的 START 是邊緣觸發，這樣可以用（自動步序 30 也是同樣的「起動後放開」模式）。如果需要按住時持續輸出，就要拿掉手動條件裡的 `NOT M13`，或改成用 M13 自保。**需要你決定規格，程式未修改。**
2. **M 也有預設停電保持：M384–M1999。** FX5S 預設 M 的 Latch(1) 範圍是 384–1999，所以 M400–M415、M920/M921、M950–M963 都是停電保持。手冊只要求設定 D，所以我沒有改 M。實機斷電再上電時，這些邊緣偵測用的 M 會保留舊值，可能造成第一個 scan 誤判邊緣，建議評估是否把 M 的保持範圍清掉或縮小。
3. 預設 D 的保持範圍原本是 128–1999，改成 200–499 之後，D100/D110/D500–D521 已不再停電保持（D521 上電後由 P00 補 20）。這符合程式的設計。
4. 在模擬模式下 M0 仍然取 X0，所以模擬器裡要先把 X0 設 ON 才能做 (a)。如果模擬時想完全不碰 X，可以考慮在 M50 分支裡不要讀 X0。

## 修正與重測（2026-10-30 07:30 台北）

依據：使用者提供的日東精工 FM513VZ-01-NX-100（S/N U17984）圖面。RC75-T1 外部 I/O（EX2）有 EXE CYCLE START（X22）以及 DURING RUNNING / CYCLE COMPLETION / TIGHTENING OK 回報，是「起動 → 等回報運轉中」的交握方式。因此保留 `NOT M13`，不讓 START 一直保持 ON（否則一顆鎖完可能立刻再起動）。修正重點是「按住 M113 會連續重複鎖付」：改成按一下 = 一個循環。

修改（原檔備份在 `PLC_v2/orig_20261030/`）：
- `P40_Reset_Manual.st`：M412 那一行改為
  ```
  M930 := M113 AND NOT M931;  M931 := M113;
  IF M201 AND M930 AND M0 AND M10 AND M11 AND NOT M12 AND NOT M13 AND NOT M203 THEN M932 := TRUE; END_IF;
  IF M13 OR NOT M201 OR M203 OR NOT M0 THEN M932 := FALSE; END_IF;
  M412 := (D100 = 30) OR M932;
  ```
- `P00_Init.st`：SM402 初始化加 `M932 := FALSE;`（M932 在預設停電保持範圍 M384–M1999 內）。

GX Works3：只更新 P00、P40 兩個區塊，Rebuild All 結果 **Error 0、Warning 0**；07:33 存檔。

GX Simulator3 重測（用 P40 編輯器的即時監看值觀察）：

| 測試 | 實際值 | 判定 |
|---|---|---|
| k-1 手動模式：X0、M50 ON → M102 復歸 → M103 | M201=ON、M203=OFF、M0/M10/M11=ON | PASS |
| k-2 按住 M113 約 7 s | M13 只在開頭 ON 一次（約 2 s，一個模擬循環），之後持續 OFF，沒有重複起動；M932/M412 只在起動那一刻 ON | PASS（修正後的規格） |
| k-3 放開後再按一下 M113 | M13 再 ON 一次後回到 OFF | PASS |
| 自動回歸：M103 回到自動 → M100 → M53 | M201=OFF；完成一顆後 D300=1、D304=1、D302=0，D100 回到 10，M200 仍 ON | PASS |

尚未處理：手動起動後如果 RC75 一直沒回報運轉中，M932 會一直等下去，目前沒有逾時報警；可比照自動模式用 D210 計時、逾時報 M143。這部分要等使用者決定。

## 操作備註

- CPU Parameter 的 Apply 用滑鼠點擊不會生效，要讓 Apply 鈕取得焦點後按空白鍵才行（關閉時會跳出「資料已變更」提示）。
- 證據截圖：`test_evidence/watch_after_l.jpg`（(l) 之後的 Watch 畫面，模擬中）。
