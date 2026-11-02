# 圓桌會議簡報：鎖螺絲站 v3.2 流程與 HMI 手動頁（2026-11-02 現場對點後）

角色：Opus 5.5 提案（rt_1）→ Sonnet 反方（rt_2）→ Fable 仲裁定案（rt_3）。
定案會用來更新三樣東西：計畫（PLC v3.2 修改清單）、HMI 原型（`HMI/v4_bg/*.html`）、Excel（點位控制流程 v3.2）。
**這一輪不改 PLC 程式、不寫實機**，只出方案。

## 使用者這次的要求（原話整理）
1. 圖 1 紅框是今天硬體接線人員確認的點位；使用者也更新了今天和治具工程人員核對的流程與點位（Excel `點位控制流程_JASON_v3.1.xlsx`）。
2. 圖 4：HMI 箱上有硬體 EMO（急停）和綠色「啟動」按鈕。
3. 圖 3：治具與 RC75 的配置。**一次啟動，兩邊都要鎖**，所以自動流程一個循環要鎖兩次。
4. 請依目前狀況重新安排流程。自動流程分三段：
   - EMO button hit（停止）
   - 待機啟動
   - 啟動鎖付
5. HMI 手動頁面要新增流程。
6. 手動頁面要有一個 X、Y 點位監視表（ON/OFF），而且能強制點亮。
7. 計畫、原型、Excel 都要更新。

## 圖片（可用 Read 直接看）
資料夾：`D:\Devin_project\screw-machine\SOP\20261102_bigtime_docking_test\`
- `S__106602529_0.jpg` 或 `S__106602530_0.jpg`：RC75 EX2 外部 IO 接線圖，有手寫點位（圖 1）
- `7EC21432-808F-4AEB-90E4-7BCEECE4114D.png`：Excel 片段「EMO button hit (停止) / 待機啟動」（圖 2）
- `9911ED2A-B2BC-47EB-A3C4-FF2821CA2D63.jpg`：機台與治具，雙邊治具（圖 3）
- 另一張：HMI 箱，有 Pro-face 螢幕、EMO、綠色按鈕、2 個空孔；上方是紅綠兩色塔燈（圖 4）

## 圖 1 紅框手寫點位（Opus 判讀）
PLC 輸出 → RC75 輸入：
| PLC | RC75 | 訊號 |
|---|---|---|
| Y10 | XB00 | RETURN 復歸 |
| Y11 | XB01 | RESET |
| Y12 | XB02 | CYCLE START |
| Y13 | XB03 | SCREW FEED 送螺絲 |
| Y14 | XB04 | TABLE SELECTION 1 |

RC75 輸出 → PLC 輸入：
| PLC | RC75 | 訊號 |
|---|---|---|
| X11 | YB00 | READY（可啟動），旁註「準備」 |
| X12 | YB01 | HOME POSITION，旁註「回原點」 |
| X13 | YB02 | ALARM |
| X14 | YB04 | CYCLE COMPLETION |
| X15 | YB06 | SCREW SHORTAGE |
| X16 | YB12 | BUZZER ON（異常、循環完了） |
| X17 | YB13 | TIGHTENING OK COMPLETION（手寫位置落在 TIGHTENING OK 與 CHUCK TIP 兩列之間，依 YB 編號判為 OK 完了，待確認） |

沒有接的：YB03 DURING RUNNING（循環中）、YB05、YB07 扭力 NG、YB10 浮鎖 NG、YB11 送料異常、XB05 TABLE 2。

## 使用者 Excel 的修改（JASON 版，相對範本 v3.1）
自動流程：
- 步驟 0「EMO button hit（停止）」：輸入「X0 OFF→ON」，輸出「Y3 ON→OFF」。現場備註：「治具 Homing 回到水平待機 → X5 ON」。條件與逾時欄寫「AI suggestion」，要我們補。
- 步驟 10「待機啟動」：輸入「X7 OFF→ON」，輸出「Y5 ON（與 X7 連動）」。
  - 現場備註（原文）：「治具移動到鎖付點01，執行步驟30->40，鎖付時X12 RC75 Home -> on-> off，等到再次X12 ON代表鎖了完第一個位置，會在收到一次X7On，Y5On->off 移動到鎖付點02->1步驟30」
- 步驟 12、14（中控）：not yet testing。
- 步驟 20（選 TABLE）：「really need???」

I/O 對照：
- X0 用途改寫成「ON=按下」。但 11-02 監看紀錄是平常 ON、按下 OFF（NC），X0→Y3 規則也是在 X0 OFF→ON（放開）時觸發。
- X7：啟動鈕（備註沿用舊 X1 的「按 6 次都讀到」）。
- X5：治具水平待機 OK。
- X6：治具馬達異常 ALARM。
- X10：光閘安全圍欄，ON = 無遮斷、安全；OFF = 有人。
- X11、X12 標籤與舊表互換（X12 註「實體是這樣接」）。
- Y4：通知 RC75 HOME 點位，與 X12 連動。
- Y5：啟動鍵 → X7 → Y5。
- Y3：用途待確認，計畫是 X0 放開時亮 1 秒。
- 說明頁加了 HMI IP、Port、連線密碼、PLC IP。**密碼不要抄進任何產出。**

## 11-02 現場監看事實（test_evidence/2026-11-02_現場IO測試紀錄.md）
- 靜止時 ON 的點：X0、X4、X11、X12；X10 會自己 0.5～3 秒 ON/OFF。依新接線，X10 是光柵（有人走動），X11 是 READY，X12 是 HOME，都屬正常。
- **舊程式把 X12 當 RC75 ALARM**，所以一整天都報「RC75 異常，無法排除」。依新接線，X12 是 HOME，真正的 ALARM 是 X13，那天一直是 OFF。
- X1 在 16:35 被按過一次（3.3 秒），同時 X7 也是 ON。啟動鈕到底是 X1 還是 X7，現場要再確認。
- X4 一直 ON，新接線沒有它。
- 16:12 起測試「X0 OFF→ON → Y3 亮約 1 秒」共 9 次；是用 PC 強制輸出做的，延遲 15～58 秒。
- Y5 一直閃：v3.1 把 Y5 當黃燈，警告時閃。上電預設 Remote，中控沒接，M152 通訊中斷警告一直亮。

## 目前 PLC v3.1 結構（PLC_v3_1/*.st）
- P10 讀 X 轉成 M：M0=X0 … M17=X17。
- P20 異常、模式、啟動。
- P30 自動步序 D100：0、10、12、14、20、30、40、50、56、60。
  - 30 等 X13 循環中。
  - 40 等 X14 完成且 X13 OFF。
  - 50 用 X15 判 OK。
- P40 復歸步序 D110：1 RESET → 2 等 → 3 RETURN，以及手動輸出 M400～M415。
- P70 把 M 轉成 Y。
- HMI 手動按鈕：M110 RETURN、M111 RESET、M112 送螺絲、M113 單次鎖付、M114 待機給治具、M115 停止給治具、M103 自動/手動切換。
- 可用的空位：M800 起、D217 起、D220 起、D530 起都還沒用。
- 硬體：FX5S-30MR/ES，X0～X17（16 點）、Y0～Y7 加 Y10～Y15（14 點，Y16、Y17 不存在）。HMI 是 Pro-face ET-6400WA，800×480。

## HMI 原型
- `D:\Devin_project\screw-machine\HMI\v4_bg\`：每頁一個 HTML，800×480 絕對座標，`common.js` 的 `render()` 會畫出來。
- 色票：`C` 物件；舊定案見 `HMI/roundtable/rt_3_fable_final_plan.md` B.1。
- 現有頁：auto（1）、host（2）、manual（3）、alarm（4）。
- `manual.html` 現在有 7 顆按鈕和 5 個狀態燈。
