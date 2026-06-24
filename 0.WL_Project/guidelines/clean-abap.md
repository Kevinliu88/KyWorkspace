# Clean ABAP / 編碼風格指南

S/4HANA 2022 / ABAP 7.57 適用。參考 SAP 官方 [Clean ABAP](https://github.com/SAP/styleguides/blob/main/clean-abap/CleanABAP.md) 並針對本團隊需求調整。

---

## 基本原則

1. **語意清楚優先於行數短**。命名要能直接讀懂，不靠註解解釋。
2. **新程式預設用 OO**：global class 取代 function module / report logic。Report 主程式只做啟動，邏輯放 class。
3. **不寫向後相容魔法**：S/4 2022 已淘汰 R/3 殘餘語法，不再使用 `TABLES`、`HEADER LINE`、`OCCURS`、`MOVE-CORRESPONDING` (改用 `CORRESPONDING #( )`) 等舊寫法。
4. **保持函式短小**：方法理想 ≤ 20 行，最多 ≤ 50 行；超過就拆。
5. **單一職責**：一個方法只做一件事，名字描述「做什麼」而非「怎麼做」。

---

## 宣告 (Declarations)

- 用 **inline declaration** (`DATA(...)`, `FIELD-SYMBOL(<...>)`)，不要先 `DATA: ... TYPE ...` 再賦值。
- 型別用 **`TYPES`** 集中定義在 class 的 `TYPES` 區或 type pool；不要散落在程式中段。
- 常數用 **`CONSTANTS`**，不要用 hard-coded literal；多個相關常數包進 `BEGIN OF gc_xxx ... END OF`。

```abap
" Good
DATA(lt_orders) = NEW zcl_order_reader( )->read_by_date( iv_date = sy-datum ).

" Bad
DATA: lt_orders TYPE ztt_order.
DATA: lo_reader TYPE REF TO zcl_order_reader.
CREATE OBJECT lo_reader.
CALL METHOD lo_reader->read_by_date EXPORTING iv_date = sy-datum IMPORTING et_orders = lt_orders.
```

---

## 控制流程

- 用 `COND` / `SWITCH` 表達式取代多段 `IF...ELSEIF...ENDIF` 賦值。
- 提早 return：用 `CHECK` 或 `IF ... RETURN. ENDIF.`，**避免深層巢狀**。
- 不寫 `IF NOT lv_x IS INITIAL.`，改 `IF lv_x IS NOT INITIAL.`。
- 不用 `EXIT` 跳出 `LOOP`，用 `EXIT` 容易誤解，改成把邏輯包成方法後 `RETURN`。

```abap
" Good
DATA(lv_status_text) = SWITCH string( ls_po-status
                                      WHEN 'A' THEN 'Approved'
                                      WHEN 'R' THEN 'Rejected'
                                      ELSE          'Open' ).
```

---

## 內表 (Internal Tables) 操作

- 用 `VALUE #( )` 建表、`FOR` 迴圈、`REDUCE`、`FILTER`。
- 讀取單筆用 `READ TABLE ... ASSIGNING FIELD-SYMBOL(<...>) WITH KEY ...` 或 `lt_xxx[ key = ... ]` (table expression)，後者更簡潔但 catch `CX_SY_ITAB_LINE_NOT_FOUND`。
- 用 `LINE_EXISTS( )` / `LINE_INDEX( )` 取代 `READ TABLE ... TRANSPORTING NO FIELDS`。
- **盡量用 `SORTED` / `HASHED` table**，避免線性搜尋；報表型暫存表才用 `STANDARD`。

```abap
" Good
DATA(lt_total_by_vendor) = VALUE ztt_vendor_amount(
  FOR GROUPS <grp> OF <po> IN lt_po
  GROUP BY ( vendor = <po>-lifnr )
  ( vendor = <grp>-vendor
    amount = REDUCE dmbtr( INIT s = 0 FOR <p> IN GROUP <grp> NEXT s = s + <p>-netwr ) ) ).
```

---

## SQL / 資料存取

- **Open SQL 改用 inline target**：`SELECT ... INTO TABLE @DATA(lt_x)`。
- 一律用 `@` 主機變數、`SINGLE` 須加 `WHERE` 完整 key。
- `SELECT *` 禁止；只選需要的欄位。
- **CDS View 優先**：跨表查詢、聚合、計算欄位建 CDS，不要在 ABAP 端寫巨大 JOIN。
- 不在迴圈內 `SELECT`；改用 `FOR ALL ENTRIES IN` 或 CDS 帶條件一次取回。
- `FOR ALL ENTRIES` 使用前必須檢查驅動表非空、去重、預期回筆數合理。

```abap
" Good
SELECT po~ebeln, po~lifnr, item~ebelp, item~matnr, item~menge
       FROM ekko AS po
       INNER JOIN ekpo AS item ON item~ebeln = po~ebeln
       WHERE po~bsart = @lc_po_type
         AND po~bedat >= @lv_from_date
       INTO TABLE @DATA(lt_po_items).
```

---

## 類別設計 (OO)

- **預設 `FINAL`**，類別不開放繼承除非有明確設計需求。
- 公開介面以 **interface** 暴露，不要讓呼叫者直接依賴 class。
- 建構子盡量 **接受依賴 (constructor injection)**，方便單元測試 mock。
- 不要在 class 裡寫 static method 來「集合工具」；那是 utility class 反模式。真要工具，封進有意義的物件。
- Exception 用 **`ZCX_*` class-based**，不要回傳 `sy-subrc` / `BAPIRET2` 作為唯一錯誤管道（兩種都有時優先用例外）。

```abap
CLASS zcl_po_overdue_finder DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_po_overdue_finder.
    METHODS constructor
      IMPORTING
        io_po_reader TYPE REF TO zif_po_reader
        io_clock     TYPE REF TO zif_clock.
  PRIVATE SECTION.
    DATA po_reader TYPE REF TO zif_po_reader.
    DATA clock     TYPE REF TO zif_clock.
ENDCLASS.
```

---

## 訊息與例外

- 不要在底層方法 `MESSAGE ... TYPE 'E'`，會中斷流程難測試；改 `RAISE EXCEPTION TYPE zcx_xxx`。
- UI 層才把例外轉訊息或加入 `BAPIRET2`。
- 訊息文字一律用訊息類別 (T100)，不要 hard-code 字串。

---

## 註解

- **預設不寫註解**。命名清楚就不需要解釋。
- 只在 **為什麼** 非顯而易見時寫：歷史問題、業務規則來源、SAP Note 編號、效能權衡。
- 不寫 `* 修改人 / 修改日期 / 修改內容` 區塊，靠 transport 與 version management 追蹤。
- **註解內不要用行號當參照**（如 `:3914`、`:1276`）。程式會持續修改、行號會漂移失準。改用不漂移的地標：FORM / Method 名稱、修改標記字串、關鍵語句、表 / 欄位名。同理也適用於分析 / 設計 `.md` 文件。

```abap
" Good — 解釋 why
" SAP Note 3198472: BAPI does not refresh ATP buffer, force re-read.
CALL FUNCTION 'BAPI_MATERIAL_AVAILABILITY' ...

" Bad — 用行號指位置，改版後就不準
" 過濾邏輯見 :3503，補列在 :4067
" Good — 用不漂移的地標
" 過濾邏輯見 explode_bom 的角色過濾 (PATCH 2)；補列在 assign_rem_data
```

---

## 選擇畫面 (Selection Screen) 慣例

### 說明區塊一律放在最下方

選擇畫面若要放「程式說明 / 操作說明」框，**一律擺在所有輸入元素（`PARAMETERS` / `SELECT-OPTIONS` / 選項區塊）的最下方**。

**Why**：使用者打開畫面，第一眼要看到的是「要填什麼、要勾什麼」，不要被整段說明文字往下擠。說明放最後當參考即可；多支程式位置統一也好維護。

作法：說明框用帶 frame 的 `BLOCK` + 數行 `SELECTION-SCREEN COMMENT`，文字在 `INITIALIZATION` 設定（自包含，不必另外維護 text symbol，貼進 SAP 就會顯示）。

```abap
" 選項在上
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE gv_tit1.
  PARAMETERS p_test AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b1.

" 說明一律放最下方
SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE gv_tit2.
  SELECTION-SCREEN COMMENT /1(79) gv_in1.
  SELECTION-SCREEN COMMENT /1(79) gv_in2.
SELECTION-SCREEN END OF BLOCK b2.

INITIALIZATION.
  gv_tit1 = '執行選項'.
  gv_tit2 = '程式說明'.
  gv_in1  = '【用途】…'.
  gv_in2  = '…'.
```

> `gv_tit1/2`（`WITH FRAME TITLE`）與 `gv_in1/2`（`COMMENT`）都會被**自動宣告**，不可再 `DATA`（見下方「COMMENT / FRAME TITLE 的名稱限制」）。

---

## 效能注意事項

- HANA 上，**邏輯下推到 DB**（CDS、SQLScript AMDP）通常比在 ABAP 算迴圈快得多。
- 大資料量處理避免 `SORT lt_xxx` 之後 `LOOP`，能用 SQL 排序就在 SELECT 排。
- 避免在 LOOP 內呼叫 RFC / BAPI。如不得已，包裝成批次。
- 量大時用 `Package Size`、`CURSOR`，不要一次撈百萬筆。

---

## 不再使用的舊語法 (S/4 2022 上會出現 warning 或建議淘汰)

| 不要用 | 用 |
| --- | --- |
| `TABLES tbl.` (除 SAPMP / Dynpro 真有需要) | inline `DATA(...)` |
| `HEADER LINE` | work area + 內表分開 |
| `OCCURS n` | `TYPE STANDARD TABLE OF ...` |
| `MOVE x TO y.` | `y = x.` |
| `MOVE-CORRESPONDING` | `CORRESPONDING #( ... [MAPPING ...] )` |
| `LOOP AT ... INTO ls_x.` (純讀) | `LOOP AT ... ASSIGNING FIELD-SYMBOL(<x>).` |
| `CALL FUNCTION '...' DESTINATION ...` 為主要 API | 改用 RAP / OData / class-based 介面 |
| `WRITE :` 列報表 | ALV (`CL_SALV_TABLE`) 或 Fiori |

---

## S/4 匯入 / Activation 常見語法錯誤處理

從舊 ECC report 改寫或搬到 S/4 時，SAP GUI 的 syntax check 可能比本地文字檢查更嚴格。遇到以下錯誤時，優先用保守寫法修正。

### String template 內不要組尾端反斜線

錯誤例：

```abap
lv_path = |{ lv_path }\|.
```

可能錯誤：

```text
Invalid line break in string template.
```

處理方式：尾端反斜線用 `CONCATENATE`，避免 `\|` 被 parser 誤判。

```abap
CONCATENATE lv_path '\' INTO lv_path.
```

### Method 參數避免把 DDIC char 欄位硬宣告為 string

錯誤例：

```abap
METHODS append_field_line
  IMPORTING
    iv_text TYPE string.

append_field_line( iv_text = ls_dfies-fieldtext ).
```

可能錯誤：

```text
"LS_DFIES-FIELDTEXT" is not type-compatible with formal parameter "IV_TEXT".
```

處理方式：若 method 接收的是文字、欄位名稱、物件名稱等 char-like 值，宣告成 `TYPE csequence`。

```abap
METHODS append_field_line
  IMPORTING
    iv_fieldname TYPE csequence
    iv_rollname  TYPE csequence
    iv_datatype  TYPE csequence
    iv_text      TYPE csequence.
```

若 method 內需要串接輸出，再轉成 local `string`。

### GUI_DOWNLOAD 的 codepage 要用正確型別

錯誤例：

```abap
CONSTANTS c_codepage_utf8 TYPE c LENGTH 4 VALUE '4110'.

cl_gui_frontend_services=>gui_download(
  EXPORTING
    codepage = c_codepage_utf8
  CHANGING
    data_tab = lt_lines ).
```

可能錯誤：

```text
"C_CODEPAGE_UTF8" is not type-compatible with formal parameter "CODEPAGE".
```

處理方式：使用 SAP 預期的 `ABAP_ENCODING`。

```abap
CONSTANTS c_codepage_utf8 TYPE abap_encoding VALUE '4110'.
```

### Selection screen 參數用 flat type 較穩

舊 report 或需要貼到 SAP GUI editor 的工具程式，selection screen 參數避免直接使用 `TYPE string`，改用 `char255` 或自訂 DDIC data element。

```abap
PARAMETERS p_path TYPE char255 LOWER CASE.
```

class method 內若需要字串處理，再轉成 `string`。

### SELECTION-SCREEN COMMENT / FRAME TITLE / 參數名稱的限制

selection screen 元素有幾個容易踩的限制（貼舊程式、或自訂動態標題時最常見）。

**限制 1：名稱最多 8 字元**

`PARAMETERS`、`SELECT-OPTIONS`、`SELECTION-SCREEN COMMENT / PUSHBUTTON` 引用的名稱**最多 8 個字元**（一般 `DATA` 變數無此限制，但只要被 selection screen 元素引用就受限）。

```text
The name of the comment can be up to eight characters long.
```

```abap
" Bad — gv_scr_info 有 11 字元
SELECTION-SCREEN COMMENT 1(79) gv_scr_info.
" Good — gv_scinf 8 字元
SELECTION-SCREEN COMMENT 1(79) gv_scinf.
```

**限制 2：COMMENT 會「自動宣告」該名稱，不可再 DATA 宣告**

`SELECTION-SCREEN COMMENT pos(len) name.` 會**自動**把 `name` 宣告成 `c(len)` 變數。若又 `DATA name ...` 就重複宣告。

```text
"GV_SCINF" was already declared.
```

```abap
" Bad — COMMENT 已自動宣告，再 DATA 就重複
DATA gv_scinf TYPE char79.
SELECTION-SCREEN COMMENT 1(79) gv_scinf.

" Good — 只留 COMMENT（它自己宣告 gv_scinf c79）；要設值直接在 INITIALIZATION / AT SELECTION-SCREEN OUTPUT 賦值
SELECTION-SCREEN COMMENT 1(79) gv_scinf.
```

> 動態標題實例：用 COMMENT 在第一行顯示當前 t-code（區分同一支程式的多個 tcode 入口），在 `INITIALIZATION` 設 `gv_scinf = |T-Code：{ sy-tcode }|.`，比改 program title（`sy-title`）穩。

**限制 3：`WITH FRAME TITLE name` 的 name 也會自動宣告，同樣不可再 DATA**

`SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE name.` 的 `name`（frame 標題變數）與 `COMMENT` 一樣會被**自動宣告**成 `c` 變數，**不可**再 `DATA name ...`，否則同樣報 already declared。要動態標題就在 `INITIALIZATION` 賦值（名稱一樣 ≤ 8 字元）。

```text
"GV_TITL" was already declared.
```

```abap
" Bad — frame title 已自動宣告，再 DATA 就重複
DATA gv_titl TYPE c LENGTH 30.
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE gv_titl.

" Good — 不要 DATA，直接在 INITIALIZATION 設值
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE gv_titl.
INITIALIZATION.
  gv_titl = '程式說明'.
```

### 不同 DDIC text table 欄位不完全相同

不要把 `DD04T` / `DD01T` 的查詢條件直接套到 `DD03T`。

`DD04T`、`DD01T` 可用：

```abap
AND as4local = 'A'
AND as4vers  = '0000'
```

但 `DD03T` 在部分系統沒有 `AS4VERS`，查欄位描述時只用：

```abap
SELECT SINGLE ddtext
  FROM dd03t
  WHERE tabname    = @iv_tabname
    AND fieldname  = @iv_fieldname
    AND ddlanguage = @iv_langu
    AND as4local   = 'A'
  INTO @rv_text.
```

### DDIC 描述文字要準備 fallback

匯出 table 欄位說明時，`DDIF_FIELDINFO_GET` 的 `DFIES-FIELDTEXT` 不一定完整，特別是 built-in type 欄位、append/include 展開欄位、或登入語言與維護語言不同時。

建議 fallback 順序：

1. `DFIES-FIELDTEXT`
2. `DD03T`：先用原始 table name + field name，再用 `DFIES-TABNAME + FIELDNAME`
3. 若欄位有 data element (`DFIES-ROLLNAME`)，查 `DD04T-DDTEXT`
4. 語言 fallback 可依專案需要使用 `SY-LANGU`、`E`、`M`、`1`

### cl_salv_table 方法的 checked exception 要完整捕捉

`CL_SALV_TABLE` 的設定方法多會拋 class-based exception，呼叫時**必須 catch（或在 method 的 `RAISING` 宣告）**，否則 activation 出 warning，且執行時真的拋出會 short dump。

錯誤例（只 catch 了部分 exception）：

```abap
TRY.
    lo_salv->get_sorts( )->add_sort( columnname = 'SORT_SEQ'
                                     sequence   = if_salv_c_sort=>sort_up ).
  CATCH cx_salv_existing cx_salv_data_error.
ENDTRY.
```

可能警告：

```text
The exception CX_SALV_NOT_FOUND is not caught or declared in the RAISING clause of "...".
```

處理方式：把該方法宣告的 exception **全部**列入 `CATCH`（`add_sort` 共三個）。

```abap
TRY.
    lo_salv->get_sorts( )->add_sort( columnname = 'SORT_SEQ'
                                     sequence   = if_salv_c_sort=>sort_up ).
  CATCH cx_salv_not_found cx_salv_existing cx_salv_data_error.
ENDTRY.
```

常用方法的 exception 對照（呼叫前以 F2 確認簽名，全部 catch）：

| 方法 | 會拋的 exception |
| --- | --- |
| `cl_salv_table=>factory( )` | `cx_salv_msg` |
| `lo_sorts->add_sort( )` | `cx_salv_not_found`、`cx_salv_existing`、`cx_salv_data_error` |
| `lo_columns->get_column( )` | `cx_salv_not_found` |
| `lo_salv->display( )` | `cx_salv_msg`（部分情境） |

> ⚠️ `cx_salv_not_found` 與 `cx_salv_msg` 是**平行**的子類別，`CATCH cx_salv_msg` **不會**順帶接到 `cx_salv_not_found`，必須個別列出（或統一 `CATCH cx_salv_error` 接全部）。

### REUSE_ALV popup：用 user_command 區分「✓ 確認」做自訂動作

把 `REUSE_ALV_GRID_DISPLAY[_LVC]` 做成 popup（`I_SCREEN_START_COLUMN/LINE` + `I_SCREEN_END_COLUMN/LINE`）時：

- popup 的標準工具列是**精簡版**（列印 / 排序 / 找 / 篩選），**沒有「匯出試算表」**；完整匯出工具列只有全螢幕才有。
- 要自訂動作（如匯出 Excel）用 `I_CALLBACK_USER_COMMAND`。實測（S/4 2022）：
  - 按「**✓ 確認**」→ fcode **`&ONT`**，會進 user_command callback。
  - 按 **X 關閉、列印、排序**等 → **不進 callback、照標準行為**（X = 直接離開 popup）。
- 因此能做到「**✓ 詢問/做自訂、X 直接離開**」而**不必建 GUI status**：

```abap
FORM my_ucomm USING r_ucomm LIKE sy-ucomm rs_selfield TYPE slis_selfield.
  CHECK r_ucomm = '&ONT'.        "只在 ✓ 確認時動作；X / 列印照原本
  PERFORM export_to_excel.
ENDFORM.
```

- 對比 `cl_salv_table=>set_screen_popup`：**沒有工具列、`display( )` 也無法區分 ✓/X**（要自訂得 `set_screen_status` + class event，更煩）。所以「**popup 要自訂動作 / 匯出，優先用 REUSE popup + user_command**」。
- 自寫匯出 Excel：`cl_gui_frontend_services=>gui_download`，`filetype='ASC'` + tab 分隔 + `codepage='4110'`(UTF-8) + `write_bom=abap_true`，Excel 開中文不亂碼。
- popup 內的 grid 標題用 **`I_GRID_TITLE`** 參數（`lvc_s_layo-grid_title` 在 LVC popup 不一定顯示）。

### 無型別的 FORM `TABLES` 參數不能取欄位（`-component` 會 activation 失敗）

舊 report 的 `FORM xxx TABLES pt ...`（沒接 `STRUCTURE`）會被當成**無結構的泛型表**，對它寫
`pt[ ... ]-idnrk`（或 `READ ... INTO wa` 後 `wa-idnrk`）都會報
**「The specified type does not have a structure and therefore does not have a component called "XXX"」**。

- 同一段邏輯在「表有型別」的地方能編譯、搬到「`TABLES` 參數」就掛，多半是這個原因。
- 解法（優先序）：
  1. **改查一個 typed 的全域/區域內表**（同資料的 typed 版本）。例：本專案 `assign_rem_data` 對 untyped 參數 `lt_stpox` 取 `-idnrk` 失敗 → 改查 typed 全域 `lt_bom`（`TYPE TABLE OF stpox`，與 `lt_stpox` 同一棵 BOM 樹）。
  2. 真要用該參數 → `FORM ... TABLES pt STRUCTURE dbtab`（補回行結構；但改動簽章、影響呼叫端，較大）。
  3. 新程式別用 `TABLES`，改 `USING/CHANGING ct TYPE ty_xxx`（typed）。

---

## Code review checklist (簡版)

貼程式到 `reviews/` 請 Claude 看時，預期會逐項檢查：

- [ ] 命名是否合規 (`naming-conventions.md`)
- [ ] 有沒有舊語法殘留 (見上表)
- [ ] SELECT 是否選欄位、有沒有在迴圈內 SELECT
- [ ] 例外處理是否合理，沒被吞掉 (empty `CATCH`)
- [ ] 是否有 hard-coded 字串、magic number
- [ ] 註解是否避免用行號參照（改用 FORM 名 / 標記字串 / 關鍵語句等地標）
- [ ] 方法長度、巢狀深度
- [ ] 授權檢查 (`AUTHORITY-CHECK`) 是否到位（涉及敏感資料時）
- [ ] 是否有 unit test (ABAP Unit) 涵蓋核心邏輯
