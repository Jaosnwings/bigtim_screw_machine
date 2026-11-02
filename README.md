# 鎖螺絲機 PLC / HMI

這個 repo 放文字鎖螺絲機的控制程式：主 PLC 是三菱 FX5S-30MR/ES，用 GX Works3 開發，程式以 ST（結構化文字）撰寫；人機是 Pro-face GP-Pro EX 專案（ST-6400WA）。v3 起加入跟中控（car_light_system，Modbus TCP）的放行與回報交握。

> **安全**：所有測試都只在 GX Simulator3 上跑。沒有現場負責人同意，不要 Online → Write to PLC，也不要把 HMI 專案傳到實機。

## 版本

| 版本 | 程式 | 說明 |
|---|---|---|
| v2 | `PLC_v2/`（7 個 .st）、`ScrewMachine_v2.gx3` | 單機版：自動/手動、警報、RC75 鎖付、模擬模式 |
| v3 | `PLC_v3/`（9 個 .st） | 加入中控交握：P15_MES_In、P75_MES_Out，參數 D213/D214/D216 |
| v3.1 | `PLC_v3_1/`（9 個 .st）、`ScrewMachine_v3_1.gx3` | 依中控 V10 修正：放行等待逾時 30 秒、完工待收、放行單次使用。**目前上線版本** |

v3.1 的執行順序（MAIN 的 Program File Setting）：

P00_Init → P05_Sim → P10_Input → P15_MES_In → P20_Mode_Alarm → P30_AutoSeq → P40_Reset_Manual → P70_Output_Data → P75_MES_Out

D200–D499 在 CPU 參數設為停電保持。

## 資料夾

- `PLC_v2/`、`PLC_v3/`、`PLC_v3_1/`：各版 ST 原始碼（UTF-8），可直接貼進 GX Works3
- `ScrewMachine_*.gx3`：GX Works3 專案檔
- `IO_device_comment_v3*.csv`：I/O 與軟元件註解，可匯入 GX Works3
- `HMI/`：GP-Pro EX 專案 `ScrewMachine_HMI_v3_1.prxe`（自動、中控監視、手動、警報 4 個畫面，PLC1 為 iQ-F FX5S，IP 192.168.1.21）
  - `HMI/v4_bg/`：v4 畫面背景圖的 HTML 原稿與產生腳本
  - `HMI/sim_capture/`：模擬器畫面截圖（v3.1 與 v4）
  - `HMI/roundtable/`：v4 畫面改版的討論與定案紀錄
- `SOP/`：現場上線測試 SOP（`上線測試SOP_v3_1.html` 原稿與 PDF），`SOP/shots/` 是 SOP 用的 HMI 截圖
- `GXW3_操作步驟.md`：在 GX Works3 建專案、編譯、模擬的步驟
- `GXW3_test_report.md`、`GXW3_v3_1_test_report.md`：v2 與 v3.1 的模擬測試報告（v3.1：Rebuild All 0 錯誤 0 警告）
- `test_evidence/`：模擬監看畫面截圖

## 開發環境

- GX Works3 1.126G（CPU FX5S）
- GP-Pro EX（ST-6400WA）
