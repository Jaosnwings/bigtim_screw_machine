# IO 側錄（io_rec.ps1）

測試時把 X0～X17、Y0～Y15 的所有變化記成 CSV，給事後分析用。**只讀，不會寫 PLC。**

## 怎麼用
1. 電腦接上機台網路（PLC 192.168.1.21）。
2. 先關掉 `io_grid.ps1` 和任何 Modbus 工具。PLC 只有一個 Modbus 連線位，兩個程式會互搶。
3. 開 PowerShell，執行：

```bash
powershell -ExecutionPolicy Bypass -File D:\Devin_project\screw-machine\test_evidence\io_rec.ps1 -Tag 治具兩點測試
```

4. 畫面每 2 秒更新一次狀態：讀取次數、寫入列數、錯誤次數、實際間隔、最後一次變化。
5. 測完按 Ctrl+C。CSV 存在 `test_evidence\io_rec_<日期時間>_<Tag>.csv`。把它傳給 Claude 分析。

## 參數
| 參數 | 預設 | 說明 |
|---|---|---|
| `-Tag` | 空 | 加在檔名後面，方便分辨是哪一次測試 |
| `-IntervalMs` | 100 | 讀取間隔（毫秒）。實測約 108 ms |
| `-HoldStart` / `-HoldCount` | 不記 | 另外記錄 holding register（0 = D7000）。v3.2 會把步序 D100 等複製到 D7xxx，到時加這兩個參數就能知道每個變化發生在第幾步 |
| `-Plc` / `-Port` | 192.168.1.21 / 502 | |

## CSV 欄位
- 欄位：`time`（到毫秒）、`ms`（側錄開始後的毫秒）、`event`、`changed`，接著 X0～X17、Y0～Y15 各一欄（0/1），最後是 D 暫存器。
- `event` 的值：
  - `start`：第一筆。
  - `change`：有點位變化。
  - `alive`：10 秒沒有變化時寫一筆，用來確認側錄沒停。
  - `error`：讀取失敗，例如斷線。
  - `reconnect`：恢復連線。
- `changed`：這一筆變了哪些點，例如 `X7↑ Y5↑`、`Y5↓`。

## 限制
- 0.1 秒以下的脈衝可能漏掉。PLC 內建追蹤可以補這一塊，排在 v3.2 再做。
- 時間是電腦時間，不是 PLC 時間。
- 側錄期間有 `error` 的那段時間，變化會漏記。
