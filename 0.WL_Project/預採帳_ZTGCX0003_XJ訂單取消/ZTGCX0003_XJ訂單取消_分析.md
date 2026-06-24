# ZTGCX0003 預採帳—訂單異動與取消報庫存（XJ 單）— 程式分析文件

> **目的**：提供後續接手者快速了解 ZTGCX0003 的整體結構、四種執行模式、角色 × 狀態流轉、定價邏輯與**已發現的 Bug／弱點**。
>
> **建立日期**：2026-06-01
> **最後更新**：2026-06-11（新增 §15–§17：上傳流程／取數與 ALV 呈現／可改欄位全矩陣；§12 補 **B-7** 並同日**修正**：讀 PP-029 `ZTGPPRP0019` + FM `ZPF_ORDER_CANCEL_SIMU` 後確認 1.831 是「建立時活 MRP 快照」非 save_data bug；加總實測 1,441.679。內容已對現行碼複查。）
> **撰寫者**：JosephLo
> **原作者**：Ron Chang（2024/10/20 建立，V001）
> **檔案位置**：`C:\JLOWorkspace\WLProjects\JLOSAPSpace\預採帳_ZTGCX0003_XJ訂單取消\`
> **業務名詞**：**XJ 單** — 訂單取消／異動後，把受影響的庫存／MRP 數量「報庫存」，經生管→採購→業務三方接力確認。
>
> **地標慣例**：本文件不用行號定位（會漂移），改以 **FORM 名 + 關鍵語句 + 表/欄名** 標記程式位置。

---

## 目錄

1. [程式概覽](#1-程式概覽)
2. [檔案結構](#2-檔案結構)
3. [Selection Screen 設計](#3-selection-screen-設計)
4. [四種執行模式總覽](#4-四種執行模式總覽)
5. [角色 × 狀態模型（核心）](#5-角色--狀態模型核心)
6. [主流程：START / END-OF-SELECTION](#6-主流程start--end-of-selection)
7. [各功能模組詳解（依 FORM）](#7-各功能模組詳解依-form)
8. [定價邏輯（料價／業務單價）](#8-定價邏輯料價業務單價)
9. [PP-029 BOM 展開與 MRP 數量](#9-pp-029-bom-展開與-mrp-數量)
10. [外部呼叫 / 資料表對照](#10-外部呼叫--資料表對照)
11. [GUI Status / Function Code 對照](#11-gui-status--function-code-對照)
12. [★ 已發現的 Bug 與弱點](#12--已發現的-bug-與弱點)
13. [📌 待業務確認（非機械錯誤）](#13--待業務確認非機械錯誤)
14. [建議修復順序](#14-建議修復順序)
15. [詳解一：XJ 怎麼上傳](#15-詳解一xj-怎麼上傳)
16. [詳解二：上傳後取數與 ALV 呈現](#16-詳解二上傳後取數與-alv-呈現)
17. [詳解三：可以改哪些值](#17-詳解三可以改哪些值)

---

## 1. 程式概覽

| 項目 | 內容 |
|-----|------|
| 程式名稱 | `ZTGCX0003` |
| 中文功能 | 預採帳 — 訂單異動與取消報庫存 |
| 主程式類型 | 報表 (REPORT) + ALV（`REUSE_ALV_GRID_DISPLAY_LVC`） |
| Message ID | `ZCX01` |
| 原作者 | Ron Chang（2024/10/20 V001） |
| 主要外掛表 | **`ZTCX0004`**（XJ 單主檔，一筆=一個 XJ 單項次） |
| 角色表 | `ZTCX0003`（uname→role，含 vtweg 通路維度） |
| 對照表 | `ZTCX0008`（通路-廠別→帳本別 zseq）、`ZTCX0005`（理論存量）、`ZTCX0004A`（特殊標記） |
| ALV 顯示結構 | `ZSCX0003_ALV`（建立/維護/更新）／`ZTCX0004`（顯示） |
| 上傳結構 | `ZSCX0003_UPLOAD`（建立用）／`ZSCX0004_UPD`（更新用） |
| 關鍵外部程式 | `ZTGPPRP0019`（PP-029，展開訂單取消/異動影響） |
| 關鍵 FM | `Z_QT_COMP_PRICE_GET`（料價）、`ZSD_ODM_XQ_PRICE`（業務單價）、`BAPI_EXCHANGERATE_GETDETAIL`（匯率） |

### 業務情境

訂單被取消或異動 → 受影響的半成品/零件其 MRP 供需要重算 → 透過 PP-029 展開 BOM，逐料號算出「報庫存數量、理論存量、各 MRP 桶數量」→ 生管確認自製件、採購確認外購件並補料價 → 送業務 → 客戶同意（E）或維持原單（F）。每完成一輪寫回 `ZTCX0004`。

---

## 2. 檔案結構

| 檔案 | 角色 | 內容 |
|---|---|---|
| `ZTGCX0003.abap` | 主程式 | `INITIALIZATION` / `AT SELECTION-SCREEN` / `START-OF-SELECTION` 分流 / `END-OF-SELECTION` 統一補值 + 顯示 ALV |
| `include/ZTGCX0003_TOP.abap` | 宣告 | `TABLES`、`PARAMETERS`/`SELECT-OPTIONS`、`TYPES`(ty_key/ty_pp029/ty_rep)、全域 `gt_*` |
| `include/ZTGCX0003_SUB.abap` | 邏輯主體 | 約 2,700 行，所有 FORM |

---

## 3. Selection Screen 設計

**模式 radio（group `rg1`）**：`p_imp`（預設X，上傳建立）／`p_upd`（上傳更新）／`p_mod`（維護）／`p_dis`（顯示）；`p_file`（檔案路徑）。

**Block bk1 查詢條件（SELECT-OPTIONS，對 `ztcx0004`/`marc`）**：
`s_vtweg` 通路、`s_kunnr` 客戶、`s_vbeln` 銷售文件、`s_idnrk` 物料、`s_werks` 工廠、`s_status` 狀態、`s_xj` XJ 單號、`s_erdat` 建立日、`s_ernam` 建立者、`s_beskz` 採購類型、`s_qty` 報庫存量、`s_netpr` 料價。

**Function Key 1**：`FC01` = 下載上傳範本（`frm_download_template`，由 `wwwdata` 物件 `ZTGCX0003` 下載 xlsx）。

---

## 4. 四種執行模式總覽

| 模式 | 參數 | 進入 FORM 串 | 寫 DB? | 重點 |
|---|---|---|---|---|
| 上傳建立 | `p_imp` | `excel_upload`→`check_upload_data`→（有錯）`show_error_alv`／（無錯）`prepare_data` | 是(存檔時) | Submit PP-029 展開、組 `gt_data`、取新 XJ 號 |
| 上傳更新 | `p_upd` | `excel_upload`→`collect_upd_data`→`confirm_qty` | 是(存檔時) | 以 Excel 回補既有 XJ 的數量/料價 |
| 維護 | `p_mod` | `get_data`（會 `ENQUEUE_EZ_ZTCX0004` 鎖列） | 是 | ALV 可編輯 + 確認/鎖定/還原/送業務 |
| 顯示 | `p_dis` | `get_data` | 否 | 唯讀，來源 `gt_report`(=ztcx0004) |

> **想看細節**：上傳怎麼讀、上傳後每個 ALV 欄位的數字從哪來、各角色能改哪些值 —— 見 **§15／§16／§17**（本文件後段詳解，已對現行碼複查）。

---

## 5. 角色 × 狀態模型（核心）

### 角色（`ztcx0003-role`）

| role | 角色 | 負責採購類型 `marc-beskz` | 可編輯欄位（維護模式） |
|---|---|---|---|
| `A` | 生管 | **自製件 `E`**（遇 `F` 被 disable） | `STOCK_QTY`、`PP_REMARK`；所有單價/幣別隱藏(`tech`) |
| `B` | 業務 | （客戶確認） | `CUST_QTY`、`CUST_AMT`、`CUST_DATE`、`SA_REMARK` |
| `C` | 採購 | **外購件 `F`**（遇 `E` 被 disable） | `NETPR`、`WAERS`、`PUR_REMARK`、`STOCK_QTY`；業務單價隱藏 |

> 單價可見性卡控在 `frm_set_fieldcat`（2026-05-18 Rogney 註記）：採購不可見業務單價、生管不可見任何單價。

### 狀態（`ztcx0004-xj_status`）流轉

```
       上傳建立
          │ (有報量→B / 無→A)
          ▼
   A 生管建立 ──確認量──► B 生管確認量
                              │
                  採購確認量+料價
                              ▼
                         C 採購確認量
                              │ CONFIRM_1「確認並送出給業務」
                              ▼
                    D 送業務確認(資料鎖住) ── LOCK 亦設 D
                         │            ▲
              業務 CONFIRM│            │ CANC 還原(E→B / F→C)
                         ▼
        ┌──────────────┴───────────────┐
        ▼                               ▼
   E 客戶同意                     F 維持原訂單(不同意)  ← NOCONFIRM
```

| 狀態 | 意義 | 設定處（FORM） |
|---|---|---|
| `A` | 生管建立（上傳時無報量） | `save_data`（p_imp） |
| `B` | 生管確認量 | `confirm_qty`(role A)、`save_data`(p_imp 有報量) |
| `C` | 採購確認量/料價 | `confirm_qty`(role C) |
| `D` | 送業務確認（鎖住） | `confirm_1`、`lock_xj` |
| `E` | 客戶同意 | `confirm_qty`(role B) |
| `F` | 維持原訂單 | `noconfirm` |

> **同單序列規則**（`check_upload_data`）：同一 `vbeln+posnr` 要再開新 XJ，前一張必須已是 `E` 或 `F`（結案）才放行。

---

## 6. 主流程：START / END-OF-SELECTION

### START-OF-SELECTION（`ZTGCX0003.abap`）

1. `"PERFORM check_auth.` — **被註解停用**（見 §12 弱點 W-1）。
2. 讀角色 `gt_role`(ztcx0003) 與 `gt_custmap`(ztcx0008)。
3. 角色守門：
   - `gt_role IS INITIAL AND ( p_imp OR p_mod )` → `MESSAGE e005`。
   - `line_exists( gt_role[ role='B' ] ) AND ( p_imp OR p_upd )` → `MESSAGE e006`（非生管/採購不能上傳）。
4. 依模式分流（見 §4）。

### END-OF-SELECTION

- **統一補值**：對 `gt_data` 與 `gt_report` 每列以 `ty_key(matnr=idnrk, werks)` 呼叫 `update_alv_fields`（補規格/品名/供應商/PIR 料價）。
- **顯示**：`gt_data` 有值且 `gt_report` 空 → `display_alv gt_data` + `unlock_table`；反之顯示 `gt_report`；都空 → `No data exist.`。

---

## 7. 各功能模組詳解（依 FORM）

| FORM | 職責 | 備註 |
|---|---|---|
| `file_open_dialog` / `frm_download_template` | 選檔 / 下載範本 | 範本來源 `wwwdata` 物件 `ZTGCX0003` |
| `excel_upload` | 讀 Excel | `p_imp` 用 `ZSCX0003_UPLOAD`(欄 30)、`p_upd` 用 `ZSCX0004_UPD`(欄 100)；第 5 欄去 `/`、`menge` 去逗號 |
| `check_upload_data` | 上傳驗證 | 驗 `vbap` 存在、同單前張需 E/F 結案；多段 `marc/tvtw` 檢查被註解 |
| `prepare_data` | 建立模式組資料 | 對每個 upload Submit PP-029 → 對展開料號**取最高版本**去重 → 補主檔/帳本/料價/理論存量/MRP |
| `get_data` | 維護/顯示查詢 | `SELECT ztcx0004`；`p_mod` 逐列 `lock_table` + 依角色 disable `SEL`；`p_dis` 直接給 `gt_report` |
| `collect_upd_data` | 更新模式組資料 | 依角色/beskz 把 Excel 併回既有 XJ；**見 §12 B-2、B-6** |
| `confirm_qty` | 確認量 | role A 驗 `stock_qty≤bdmng`；role C 需 netpr；role B 設 E |
| `confirm_1` / `check_confirm_1` | 送業務 + 前置驗價 | **見 §12 B-1（驗證被繞過）** |
| `lock_xj` / `unlock_xj` / `noconfirm` | 鎖定/還原/維持原單 | **見 §12 B-4（過濾分支條件反向）** |
| `save_data` | 寫 `ztcx0004` | p_imp 先取號+依 xj/idnrk 彙總；存前 `WHERE msg IS NOT INITIAL` 守門；`MODIFY ztcx0004` |
| `get_xj_number` | 取 XJ 單號 | `SELECT MAX+1`、`substring()`；**見 §12 W-2、W-3** |
| `get_extra_mrp` | 抓 MRP 供需 | **見 §12 B-3（總需求取錯來源）** |
| `default_netpr` / `get_info_record` / `get_po_price` / `get_std_cost` | 料價來源 | 見 §8 |
| `get_sales_price` | 業務單價 | `ZSD_ODM_XQ_PRICE`；**見 §12 B-5（TWD 漏 ×100）** |
| `update_alv_fields` | 統一補值 | 逐列 SELECT ztmara/ztmarc/lfa1/eina-eine（N+1，見 §12 W-4） |
| `get_trans_qty` | 理論存量 | 由 `ztcx0005`(matnr+werks+calc_date) |
| `frm_set_fieldcat` / `frm_status_set` / `frm_user_command` | ALV fieldcat/狀態/事件 | 角色欄位卡控、PF-STATUS 排除碼、按鈕分派 |

---

## 8. 定價邏輯（料價／業務單價）

### 料價 `default_netpr`（僅 `beskz='F' AND sobsl 空`，即市購）

1. `Z_QT_COMP_PRICE_GET`（`source_c='2'`, `priceflag='X'`）取 CNY → 設 `netpr`/`waers`/`netpr_cny`/`waers_cny`。
2. 再呼一次取 TWD → `netpr_twd`/`waers_twd`。
3. 若仍無 `netpr` → `get_info_record`（有效 PIR `eine`），再以 `BAPI_EXCHANGERATE_GETDETAIL` 折 CNY/TWD。
4. 若 `netpr` 有但 `netpr_cny` 空 → 補折 CNY/TWD。

> 自製件（E）與外包（F+sobsl=30）**不在此 FORM 取價**；另有被註解的 `get_po_price`(期間最高 PO 價)、`get_std_cost`(標準成本) 備援未啟用。

### 業務單價 `get_sales_price`（`ZSD_ODM_XQ_PRICE`）

輸入把 `netpr`、`netpr_cny` 乘 100、per=100；輸出 `sales_waers`/`sales_netpr`/`sales_amt`。
**⚠ TWD 輸入未乘 100**（B-5）。

---

## 9. PP-029 BOM 展開與 MRP 數量

- `submit_pp029`：以 `SUBMIT ztgpprp0019 ... AND RETURN`，再用 `cl_salv_bs_runtime_info=>get_data_ref` 取回 ALV 內表 → `gt_pp029`。
- `prepare_data` 對 `gt_pp029` 做**最高版本料號去重**（比較料號末碼字母 A–Z；註：未限 werks，見 §13）。
- `get_extra_mrp`：
  - `ztpprp0019` 抓多餘供給 `lv_extra`；
  - `ztpprp0011` 依 `delkz` 分「總供給 `lr_delkz_sup`」/「總需求 `lr_delkz_dem`」加總；
  - `bmeng = lv_extra - 總供給`；在途量 `sub_qty`(delkz=E1)。

---

## 10. 外部呼叫 / 資料表對照

### Function Module / 程式

| 物件 | 用途 | 呼叫處 |
|---|---|---|
| `ZTGPPRP0019`(PP-029) | 展開訂單取消/異動影響 | `submit_pp029` |
| `Z_QT_COMP_PRICE_GET` | 組件料價(CNY/TWD) | `default_netpr` |
| `ZSD_ODM_XQ_PRICE` | 業務單價 | `get_sales_price` |
| `BAPI_EXCHANGERATE_GETDETAIL` | 匯率 | `default_netpr` |
| `ALSM_EXCEL_TO_INTERNAL_TABLE` | 讀 Excel | `excel_upload` |
| `ENQUEUE_EZ_ZTCX0004`/`DEQUEUE_ALL` | 鎖列/解鎖 | `lock_table`/`unlock_table` |
| `POPUP_TO_CONFIRM` | 動作確認 | `pop_up_confirm` |

### 主要資料表

`ztcx0004`(主) · `ztcx0003`(角色) · `ztcx0008`(通路廠別→zseq) · `ztcx0005`(理論存量) · `ztcx0004a`(特殊標記) · `vbak/vbap` · `marc` · `ztmara/makt/mara` · `ztmarc/lfa1` · `eina/eine`(PIR) · `ztpprp0011/0019`(MRP) · `ztsd0020`(成品型號) · `user_addr`(全名)。

---

## 11. GUI Status / Function Code 對照

PF-STATUS：`STATUS_ALV`，於 `frm_status_set` 依模式/角色排除功能碼。

| 功能碼 | 動作 | 可用模式 |
|---|---|---|
| `CONFIRM` | 確認數量 → `confirm_qty`+`save_data` | p_mod(role≠B) |
| `CONFIRM_1` | 確認並送業務 → `check_confirm_1`→`confirm_1`+`save_data` | p_mod(role A/C) |
| `LOCK` | 鎖定（設 D） | p_mod(role≠B) |
| `CANC` | 還原（E→B/F→C） | p_mod(role≠B) |
| `NOCONFIRM` | 維持原單（設 F） | p_mod(role≠B) |
| `CALC_SALES` | 重算業務幣別/金額 | p_mod(role≠A) |
| `&DATA_SAVE` | 存檔 | p_imp/p_upd/p_mod |
| `SALL`/`DSAL` | 全選/取消全選 | 非 p_dis |

---

## 12. ★ 已發現的 Bug 與弱點

> 嚴重度：**P0**=會導致錯誤存檔/short dump，**P1**=使用者看到錯數字，**P2**=特定操作下失效，**W**=設計/健壯性。

### P0｜B-1：`CONFIRM_1`（送業務）的料價驗證被整段繞過 🔴

規則本意（`check_confirm_1` 註解）：*送業務時，報庫存量 > 0 的項次必須有幣別且料價 > 0*。但：

```abap
" FORM check_confirm_1 結尾
IF NOT line_exists( gt_data[ msg = '' ] ).   " 判斷對象是整個 gt_data(含未勾列)
  p_subrc = 4.
ELSE.
  p_subrc = 0.                                " 只要有任一列 msg 空 → 通過(幾乎永遠)
ENDIF.
```

未勾選列的 `msg` 多半為空 → `line_exists(msg='')` 恆真 → `p_subrc=0`（通過）。緊接著：

```abap
" FORM confirm_1 開頭
LOOP AT gt_data ASSIGNING <ls_data> WHERE sel IS NOT INITIAL.
  CLEAR:<ls_data>-msg.    " 把 check 標記的錯誤抹掉
  ...  <ls_data>-xj_status = 'D'.
```

`confirm_1` 又把錯誤 `msg` 清掉 → `save_data` 後段 `WHERE msg IS NOT INITIAL` 救援也失效 → **報庫存量 > 0 但無料價/幣別的列照樣存檔並送業務（D）**。此路徑在 `p_mod` 對生管(A)/採購(C) 開放，影響直接。

**修法**：`check_confirm_1` 只看勾選列、有錯就回 `p_subrc=4`（用旗標累計，勿用 `line_exists(msg='')`）；`confirm_1` 不要無條件 `CLEAR msg`（或先存好 check 結果再清）。

### P0｜B-2：`collect_upd_data` 的 `sales_amt` 寫在 IF 之外 → 未指派 FS / 跨列汙染 🔴

```abap
" FORM collect_upd_data,LOOP AT GROUP lg_report 內
IF ls_role-role = 'A'.
  IF ls_marc-beskz = 'E'.  ... APPEND ... ASSIGNING <ls_data> ...  ENDIF.
ELSEIF ls_role-role = 'C'.
  IF ls_marc-beskz = 'F' OR ls_marc-beskz = 'E'. ... APPEND ... ENDIF.
ENDIF.
"業務金額...
<ls_data>-sales_amt = <ls_data>-sales_netpr * <ls_data>-stock_qty.  " 在所有 IF 之外
```

某列不符角色/beskz（例如 role A 遇 `beskz='F'`）時不 `APPEND`，但最後這行仍執行：
- 群組**第一列**就不符 → `<ls_data>` 未指派 → **`GETWA_NOT_ASSIGNED` short dump**；
- 中間列不符 → 以目前列 `stock_qty` 覆寫上一筆已 append 列的 `sales_amt` → **資料錯亂**。

**修法**：把 `sales_amt` 計算搬進兩個 `APPEND` 區塊內。

### P1｜B-3：`get_extra_mrp` 總需求取錯來源（供給填進需求）🟠

```abap
... INTO TABLE @DATA(lt_sup).            " 總供給
READ TABLE lt_sup INTO DATA(ls_sup) INDEX 1.
... INTO TABLE @DATA(lt_dem).            " 總需求
READ TABLE lt_dem INTO DATA(ls_dem) INDEX 1.
IF sy-subrc = 0.
  p_data-tot_req_qty = ls_sup-mng01.     " 用了 ls_sup(供給);ls_dem 從未被使用
ENDIF.
```

`tot_req_qty`（總需求）被填成供給值。**修法**：`p_data-tot_req_qty = ls_dem-mng01`。

### P2｜B-4：`lock_xj` / `unlock_xj` / `noconfirm` 過濾分支條件反向 🟡

三 FORM 的 `gt_filtered` 分支皆：

```abap
READ TABLE gt_data ASSIGNING <ls_data> INDEX lv_index.
IF sy-subrc NE 0 .              " 讀「失敗」才設狀態 → 反了(應 = 0)
  <ls_data>-xj_status = 'D'.    " 對未成功指派的 FS 寫值
ENDIF.
```

後果：**只要在 ALV 套用篩選**（`gt_filtered` 有值），鎖定/還原/維持原單就失效或對失敗 FS 寫值；無篩選時走 `ELSE`(`WHERE sel`) 才正常。**修法**：改 `IF sy-subrc = 0`；並釐清 `get_filtered_entries` 回傳的是「被篩掉的列」，要套用於「可見列」的語意。

### P2｜B-5：`get_sales_price` 的 TWD 單價漏乘 100 🟡

```abap
i_zpup    = 100 * p_data-netpr.        " 原幣 ×100
i_zpcnyup = 100 * p_data-netpr_cny.    " CNY  ×100
i_zptwdup =       p_data-netpr_twd.    " TWD  沒有 ×100 ← 不一致
i_zptwd_per = 100.
```

TWD 單價基準較 CNY/原幣小 100 倍。與 `ZTGCX0001_UPD_PRICE` 既記的「TWD 缺乘 100」同類，建議一併確認 `ZSD_ODM_XQ_PRICE` 對 TWD 的 per 約定。

### P2｜B-6：採購(C) 上傳更新連自製件(E) 都收，與維護模式不一致 🟡

`collect_upd_data` 角色 C 條件為 `beskz='F' OR 'E'`（註解卻寫「採購只能確認採購件」）；但 `get_data`(p_mod) 對角色 C 遇 `beskz='E'` 是 **disable**。兩路對「採購能否碰自製件」相反。**修法**：`p_upd` 也應只收 `'F'`。

### P1｜B-7：需求數量 `bdmng` 是「建立時的活 MRP 快照」會過時；PP-029 加總疑重複計 🟠

> **2026-06-11 讀 PP-029（`ZTGPPRP0019`）+ FM `ZPF_ORDER_CANCEL_SIMU` 後修正前判**：原以為是 `save_data` 漏加總 `bdmng`，**實測證明不是**（見下）。

**需用料量怎麼算（FM `ZPF_ORDER_CANCEL_SIMU`）**：
- 主路徑＝**比例分攤**：`menge = ( 取消量 ÷ 母單表頭量 gamng/gsmng/menge ) × 子件預留需求 resb-bdmng`（深階用 `CS_BOM_EXPL_MAT_V2`，`emeng` = 上階已分攤 menge → 取 `mnglg`）。→ 小數（如 21.679）就是「取消量只佔母單一小部分」分攤來的。
- FM 尾段「**9999**（原始工單 FE）/**8888**（原始計畫單 PA）」附加情境，`menge` **直接抄 `enmng`/`bdmng`、不分攤** → 整數列（如 1,420）。

**真因＝快照過時，不是 `save_data`**：
- FM 全程 `del12 = ls_mldelay_index_1-rcenr`（根節點，**整次展開是常數**）。ZTGCX0003 用**加總**模式 `SUM(menge) GROUP BY (kdpos, del12, werks, matnr)`，del12 既是常數 → 同料所有列**加總成一列** → `gt_pp029` 對每個料**只有一筆** → `save_data` 聚合根本不會有「多列同 `idnrk`」→ **「沒加總 `bdmng`」這件事咬不到**（純潛在 code smell，本案不發作）。
- **實測**：A0510-000618 加總**今日 = 一列 `1,441.679`**（= 21.679 + 1,420，源頭單據 `0010154440`）；但 XJ **06/04 建立時存 `1.831`**。同程式同模式差這麼多 → 只能是**底層活 MRP 變了**（06/04 當時那張帶 1,420 的計畫單還沒生）。即 **`bdmng` 是建立當下對活 MRP 的一次性快照，之後 MRP 變了也不刷新**（p_mod/p_upd 不會重展）。`報庫存量 ≤ bdmng`（`confirm_qty`）因此被卡死在過時的 1.831。

**⚠ 連 PP-029 加總本身都疑重複計**：它把「分攤列（21.679）+ 9999/8888 直接預留列（1,420）」**同料相加** = 1,441.679，可能比真實需求（~1,420）**多算**。屬 **PP-029（`ZTGPPRP0019`）設計**，非 ZTGCX0003。

**處理方向（需業務決策）**：(a) 重建/刷新 XJ 讓 PP-029 重展——**但要先解 PP-029 加總重複計，否則上限變太大**；(b) 報庫存量上限與過時的 `bdmng` 脫鉤；(c) 業務接受「建立時快照」語意。

### W-1：授權檢查被停用 🟠

`START-OF-SELECTION` 首行 `"PERFORM check_auth.` 被註解，`AUTHORITY-CHECK OBJECT 'Z_CX01'` 形同虛設，目前**僅靠 `ztcx0003` 角色表**把關。若非開發暫態，上線前需恢復。

### W-2：XJ 取號併發撞號 🟠

`get_xj_number` 以 `SELECT … ORDER BY xj DESC UP TO 1 ROWS` 後 `+1`，**無鎖、無 number range**（正規 `get_number_range`(enqueue) 整段被註解）。兩人同時上傳會拿到同一 XJ 號，`save_data` 的 `MODIFY` 互蓋。與 `ZTGCX0019` 取號 race 同一風險，此處更裸露。**修法**：恢復 number range + enqueue，或對取號加序列化鎖。

### W-3：`substring()` 進 OpenSQL WHERE（嚴格語法地雷）🟠

`get_xj_number`：`WHERE substring( xj, 3, 6 ) = @sy-datum+2(6)` 命中本系統「卡 substring 表達式」的編譯地雷。**修法**：改 `xj LIKE |XJ{ sy-datum+2(6) }%|` 或以 offset 條件改寫。

### W-4：效能 N+1 🟡

`END-OF-SELECTION` 統一補值對 `gt_data`+`gt_report` 每列呼叫 `update_alv_fields`（內含 ztmara/ztmarc/lfa1/eina-eine 多次 `SELECT SINGLE`）；`prepare_data` 又對每列逐筆 `Z_QT_COMP_PRICE_GET`(×2)、`ZSD_ODM_XQ_PRICE`、`BAPI_EXCHANGERATE_GETDETAIL`。大量上傳會慢，且**顯示模式 p_dis 也照跑補值**。**修法**：改批次預抓 + 內表查找；顯示模式略過重算。

### W-5：角色守門條件不對稱 🟡

`e005` 只擋 `p_imp/p_mod`、`e006` 擋 `p_imp/p_upd`。`p_upd` 在「完全無角色」時兩道都漏接（實務上靠 `collect_upd_data` 收不到資料而無害，但邏輯不一致）。

### W-6：持久化細節 🟡

`save_data` 的 `MODIFY ztcx0004` 後無顯式 `COMMIT WORK`（靠 dialog 隱式 commit）；`unlock_table` 用 `DEQUEUE_ALL` 釋放過廣（非僅本程式鎖）。

---

## 13. 📌 待業務確認（非機械錯誤）

- **`prepare_data` 最高版本料號去重未限 `werks`**：那段 `lv_base/lv_best` 字串運算在**整個 `gt_pp029`** 找同基礎碼最高版本字母，沒有用 `werks` 框住。若同基礎料號跨廠出現，可能被併成一筆。
  依「疑似粒度 bug 別預設立場」原則，這可能是刻意（同料不分廠）也可能是漏限廠 → **先請業務確認展開後是否該分廠去重**，再決定動不動。

---

## 14. 建議修復順序

| 順序 | 項目 | 嚴重度 | 理由 |
|---|---|---|---|
| 1 | **B-1** CONFIRM_1 驗證繞過 | P0 | 未報價單會流到業務、寫進 DB |
| 2 | **B-2** sales_amt 在 IF 外 | P0 | short dump / 資料汙染 |
| 3 | **B-3** tot_req_qty 取錯來源 | P1 | 使用者看到的總需求是錯的 |
| 3.5 | **B-7** 需求數量=活 MRP 建立快照(過時)＋PP-029 加總疑重複計 | P1 | 報庫存量被卡在過時值（業務已踩到）；非 save_data bug，已釐清 → 多為業務/PP 顧問決策 |
| 4 | **B-5** TWD ×100、**B-6** 採購收 E | P2 | 影響金額/分工，可同批 |
| 5 | **B-4** 過濾分支反向 | P2 | 套篩選後操作失效 |
| 6 | **W-1/W-2/W-3** 授權、取號、substring | W | 上線前必清（安全/併發/可編譯） |
| 7 | **W-4** 效能 | W | 視資料量決定 |

---

## 15. 詳解一：XJ 怎麼上傳

> 兩條上傳路徑：**p_imp 建立**（從訂單取消無中生有）與 **p_upd 更新**（拿查詢格式回補既有 XJ）。

### 15.1 兩種上傳一眼比較

| | p_imp 上傳建立 | p_upd 上傳更新 |
|---|---|---|
| 用途 | 從訂單取消**建立新 XJ 單** | 回補**既有 XJ** 的量/價 |
| Excel 結構 | `ZSCX0003_UPLOAD`（讀 1–30 欄） | `ZSCX0004_UPD`（讀 1–100 欄） |
| 資料起始列 | **第 3 列**起（`row > 2`，前 2 列標題） | **第 2 列**起（`row > 1`） |
| 真正消費的 Excel 欄 | **只有 `vbeln`+`posnr`+`menge`(取消量)+`calc_date`** | xj/xj_item/vbeln/posnr + `stock_qty`/`netpr`/`waers`/`pp_remark`/`pur_remark` … |
| 料件資料哪來 | **PP-029 展開 + 主檔查**（不是 Excel） | Excel 帶 + DB 既有列合併 |
| FORM 串 | `excel_upload`→`check_upload_data`→`prepare_data` | `excel_upload`→`collect_upd_data`→`confirm_qty` |

### 15.2 p_imp 上傳建立 — 逐步

1. **下載範本（FC01）**：`frm_download_template` 從 `wwwdata`（`relid='MI'`, `objid='ZTGCX0003'`）以 `DOWNLOAD_WEB_OBJECT` 下載 xlsx。
2. **選檔**：`AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file` → `file_open_dialog`（`cl_gui_frontend_services=>file_open_dialog`，過濾 *.XLS/XLSX/XLSM）。
3. **路徑檢查**：`AT SELECTION-SCREEN ON p_file` → p_imp 有值但 p_file 空 → `MESSAGE e001 '請選擇上傳檔案路徑'`。
4. **讀 Excel（`excel_upload`，p_imp 分支）**：
   - `ALSM_EXCEL_TO_INTERNAL_TABLE`（col 1–30、row 1–65000）→ `i_intern`（每格 row/col/value）→ `SORT BY row col`。
   - `LOOP AT i_intern WHERE row > 2`：`ASSIGN COMPONENT i_intern-col OF STRUCTURE ls_upload`（**依欄序定位**：Excel 第 N 欄 → 結構第 N 欄）；**第 5 欄**特例 `REPLACE ALL '/' WITH space`（去日期斜線）。
   - `AT END OF row`：`posnr = |{ posnr ALPHA = IN }|`（補零）→ `APPEND ls_upload TO gt_upload`。
5. **驗證（`check_upload_data`，逐列）**：
   - 正規化：`vbeln`=ALPHA+UPPER、`posnr`=ALPHA、`menge` 去逗號。
   - **驗 1**：`SELECT vbap WHERE vbeln+posnr` 不存在 → `zmsg='訂單+訂單項次不存在'`。
   - **驗 2（同單序列閘門）**：取同 `vbeln+posnr` **最新一張** `ztcx0004`（`ORDER BY xj_erdat,xj_ertim DESC`）→ 若存在且 `xj_status` ∉ {E,F} → `zmsg='必須上一張 XJ 結案(E/F)才能再開'`。
   - （被註解停用：訂單類型 ZPP*、預採帳客戶別 TVTW、料號主檔 MARC。）
6. **分流**：`gt_upload` 空 → `'No data upload'`+RETURN；任一列 `zmsg` 有值 → `show_error_alv`（**不進** prepare_data）；全無錯 → `prepare_data`（見 §16）。

> **重點**：p_imp 的 Excel **真正只用到 `vbeln/posnr/menge/calc_date`**。報出來的料號與各種數量，全是 PP-029 展開 + 主檔/MRP 查出來的，**不是 Excel 填的**。

### 15.3 p_upd 上傳更新 — 逐步

1. 同樣選檔。
2. **讀 Excel（`excel_upload`，p_upd 分支）**：`ALSM_EXCEL`（col 1–**100**）→ `LOOP WHERE row > 1` → `ASSIGN COMPONENT` 進 `ls_utmp`(`zscx0004_upd`)，去逗號、`CATCH`→空 → `AT END OF row APPEND lt_utmp`。
3. **搬進 `gt_report`**（逐欄 MOVE）：`xj, xj_item, vbeln, posnr, matnr, skuitem, maktx, beskz, werks, idnrk, meins, kunnr, vtweg, zseq, kwmeng, vrkme, canc_qty, stock_qty, pp_remark, pur_remark, netpr, waers`。
4. **`collect_upd_data`**：依**角色 × beskz** 把 Excel 列併回既有 `ztcx0004`：
   - 角色 A（生管）只收 `beskz='E'`；角色 C（採購）收 `beskz='F' or 'E'`（⚠ 與 p_mod 卡控不一致＝B-6）。
   - 既有列命中 → `MOVE-CORRESPONDING` DB 列 + 覆寫 `stock_qty`/備註/`netpr`/`waers`。
   - ⚠ 幣別覆寫**無空白保護**：上傳幣別空白會清掉既有幣別（本輪討論的「重傳幣別消失」，方案 A 可修）。
5. **`confirm_qty`**：依角色蓋狀態 + 戳記（見 §5）。

---

## 16. 詳解二：上傳後取數與 ALV 呈現

> 即 `prepare_data` 怎麼把一筆上傳 → 展成多筆子件 → 每欄填值 → 丟上 ALV。

### 16.1 每列 `gt_data` 的建立流程（p_imp）

對 `gt_upload` 每一列：
1. **`submit_pp029(ls_upload)`**：`SUBMIT ztgpprp0019 WITH r_bt1='X' p_vbeln p_posnr p_menge=menge r_mode1='X' r_mode2=space AND RETURN` → `cl_salv_bs_runtime_info` 攔截輸出 → `gt_pp029 = CORRESPONDING #( … )`（= 取消量展開後的各子件 + MRP 桶）。
2. `LOOP gt_pp029 INTO ls_029`：
   - **(a) 最高版本去重**：看 `ls_029-matnr` 末碼字母，在整個 `gt_pp029` 找同基礎碼最高版本；`ls_029-matnr ≠ lv_best` → `CONTINUE`（⚠ 未限 `werks`＝§13）。
   - **(b) 逐欄組 `ls_data`**（見 §16.2）→ `APPEND gt_data`。
3. `END-OF-SELECTION`：`update_alv_fields` 對每列**補值**（規格/品名/供應商/PIR 料價，僅市購 F 且空）→ `display_alv`。

### 16.2 ALV 各欄「資料來源」全表（已對現行碼複查）

| ALV 欄位 | 中文 | 來源 | 取數處 |
|---|---|---|---|
| `vbeln`/`posnr` | 銷售文件/項次 | PP-029 `kdauf`/`kdpos` | prepare_data |
| `vtweg`/`kunnr`/`matnr`/`kwmeng`/`vrkme` | 通路/客戶/成品/訂單量/單位 | `vbak`+`vbap` JOIN | SELECT |
| `werks` | 工廠 | `ls_029-werks` | PP-029 |
| `idnrk` | **材料（子件）** | `ls_029-matnr` | PP-029 |
| `zseq` | 帳本編號 | `ztcx0008`(werks+vtweg) | gt_custmap READ |
| `skuitem` | 型號 | `ztsd0020-zcn`(vtweg+**matnr**) | SELECT |
| `wl2_*`/`maktx`/`meins` | 規格/品名/單位 | `ztmara`+`makt`+`mara`(idnrk) | SELECT；END-OF 再補 |
| `zdefault_vendor`/`name1` | 供應商/名稱 | `ztmarc`+`lfa1` | SELECT；END-OF 再補 |
| `ekgrp` | 採購群組 | `eina`+`eine`（F+sobsl空→`esokz'0'`；F+30→`'3'`） | SELECT |
| `zex_hier`/`del12`/`delnr` | 展開階層/源頭單據/展開單據 | `ls_029` | PP-029 |
| `beskz`/`sobsl` | 採購類型/特殊採購 | `ls_029` | PP-029 |
| `calc_date` | 計算日 | `ls_upload-calc_date` | Excel |
| `labst`/`feaub`/`plafb`/`insme`/`bebst`/`banfb` | 庫存/工單/計畫單/IQC/採購量/請購量 | `ls_029` | PP-029（MRP 快照） |
| `bmeng`/`tot_req_qty`/`sub_qty` | 淨需求/總需求/在途 | `ztpprp0019`+`ztpprp0011` | `get_extra_mrp`（⚠ tot_req_qty 取錯來源＝B-3） |
| `ztrans_qty` | 理論存量 | `ztcx0005`(matnr+werks+calc_date) | `get_trans_qty` |
| `bstmi`/`bstrf` | 最小批量/倍數 | `marc` | SELECT |
| `canc_qty` | 取消數量 | `ls_upload-menge` | Excel |
| **`bdmng`** | **需求數量** | **`ls_029-menge`（PP-029 需用料量，比例分攤算）** | prepare_data（⚠ **建立時活 MRP 快照、不刷新，會過時**＝B-7，見 §16.4） |
| `netpr`/`waers`/`netpr_cny`/`netpr_twd` | 料價/幣別 | FM（僅市購 F+空） | `default_netpr` |
| `sales_waers`/`sales_netpr`/`sales_amt` | 業務幣別/單價/金額 | FM `ZSD_ODM_XQ_PRICE` | `get_sales_price`（單價=`e_zup/e_zup_per`） |
| `zind01`/`zdesc` | 特殊標記 | `ztcx0004a` JOIN mara(matkl)+marc(strgr) | SELECT |
| **`stock_qty`** | **報庫存數量** | **不帶值 → 生管手填** | （`confirm_qty` 卡 `≤bdmng`） |

> **一句話**：除了 `vbeln/posnr/canc_qty/calc_date` 來自 Excel、`stock_qty` 由生管手填，**其餘全是 PP-029 展開 + 主檔/MRP 快照查出來的**。

### 16.3 ALV 怎麼長出來（`display_alv` 鏈）

`display_alv` → `frm_set_layout`（`cwidth_opt`/`sel_mode='A'`/`zebra`/`stylefname='CELLSTYLES'`）→ `frm_set_fieldcat`（`LVC_FIELDCATALOG_MERGE` on `ZSCX0003_ALV`；p_dis 用 `ZTCX0004`，再加角色/模式欄位卡控與標題）→ `frm_set_events` → `frm_alv_display`（`REUSE_ALV_GRID_DISPLAY_LVC` + `FRM_STATUS_SET`/`FRM_USER_COMMAND`）。

> ⚠ 角色未設定時，`frm_set_fieldcat` 的 `CASE ls_role-role` 全不命中 → **所有單價/業務金額欄都露出來**（看似一堆重複欄）；設了角色才會依角色 `tech='X'` 收掉。

### 16.4 ⚠ 取數真相：需求數量是「建立時的活 MRP 快照」（B-7，已釐清）

需求數量 `bdmng` = PP-029 的需用料量（FM `ZPF_ORDER_CANCEL_SIMU` 以 `(取消量÷母單表頭量)×預留需求` **比例分攤**算的），**ZTGCX0003 原樣抄、不重算也不刷新**。它是**建立當下對活 MRP 的一次性快照**：A0510-000618 建立時存 `1.831`，今日 PP-029 加總已是 `1,441.679`（活 MRP 變了）→ `報庫存量 ≤ bdmng` 被卡在過時值。
⚠ **不是 `save_data` 漏加總**（加總模式 `del12` 為常數 → 每料一列，咬不到）；且 PP-029 加總把「分攤列 21.679 + 9999/8888 直接預留列 1,420」同料相加疑**重複計**。完整見 §12 B-7。

---

## 17. 詳解三：可以改哪些值

> 來源：`frm_set_fieldcat`（`edit`/`tech`）＋ `get_data`（SEL 卡控）。已對現行碼複查。

### 17.1 編輯權限矩陣

| 模式 | 角色 | **可編輯欄位** | 隱藏（看不到） | SEL 勾選 |
|---|---|---|---|---|
| p_imp 建立 | A 生管 | `STOCK_QTY`、`PP_REMARK` | 所有料價/業務價 | 隱藏（存檔自動勾） |
| p_mod 維護 | A 生管 | `STOCK_QTY`、`PP_REMARK` | 所有單價/幣別 | 自製 **E** 可勾（F 鎖） |
| p_mod 維護 | C 採購 | `NETPR`(料價)、`WAERS`(幣別)、`PUR_REMARK`、`STOCK_QTY` | 業務幣別/單價/金額 | 外購 **F** 可勾（E 鎖） |
| p_mod 維護 | B 業務 | `CUST_QTY`、`CUST_AMT`、`CUST_DATE`、`SA_REMARK` | （無單價隱藏，業務單價唯讀可見） | 通路相符可勾 |
| p_upd 更新 | A/C | 同 p_mod（但主要靠上傳帶值） | 同上 | 可勾 |
| p_dis 顯示 | 任意 | **無（全唯讀）** | — | 無 |

### 17.2 重點規則

- **報庫存數量 `STOCK_QTY`**：生管、採購都能改；`confirm_qty`(role A) 卡 **`stock_qty ≤ bdmng`**（超過需求量會擋；遇 B-7 低報時會被卡死）。
- **料價 `NETPR` + 幣別 `WAERS`**：**只有採購(C)** 能改（p_mod/p_upd）。
- **客戶同意量/金額/日期 `CUST_*` + 業務備註**：**只有業務(B)、且只在 p_mod** 能改（`IF p_mod` 才設 `edit`）。
- **業務單價 `SALES_NETPR`**：**任何角色都不能改**（`ZSD_ODM_XQ_PRICE` 算的）；生管整欄隱藏、採購隱藏、業務唯讀。要變動只能改料價後按 `CALC_SALES`——而該鈕在 **p_mod 對 A/C 被排除**，須走 p_imp/p_upd（見 §11）。
- **需求數量/MRP 各桶/理論存量/採購量…**：**唯讀**（PP-029/快照來的）。
- **SEL 卡控（`get_data`，p_mod）**：鎖定中（`ENQUEUE` 失敗）→ 不可勾；角色×beskz 不符 → 不可勾（`cellstyle = mc_style_disabled`）。

### 17.3 「改值 → 狀態/戳記」連動

| 動作 | 改的值 | 蓋戳記？ |
|---|---|---|
| 改 `STOCK_QTY` 後 CONFIRM | →狀態 B(生管)/C(採購) | ✅ `pp_`/`pur_chg_*` |
| 改 `CUST_*` 後 CONFIRM(業務) | →狀態 E | ✅ `sa_chg_*` |
| CONFIRM_1 送業務 | →狀態 D | ✅ `pp_`/`pur_chg_*` |
| LOCK / CANC / NOCONFIRM | 只翻狀態 | ❌ 不蓋（**還原無 audit**，查不到誰退的） |

---

> **下一步可選**：(a) 直接修 B-1 / B-2 / B-3 三個確認 bug（遵守註解不用行號、避開嚴格語法地雷）；(b) 評估 **B-7**（需求數量多計畫單低報，業務已踩到）+ 與業務確認多計畫單需求是否全加；(c) 先就 §13 與業務確認去重粒度；(d) 補一份「修復前後對照」變更紀錄。
