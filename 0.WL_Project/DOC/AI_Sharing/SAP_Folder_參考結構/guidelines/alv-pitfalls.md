# ALV 常見陷阱 (Pitfalls)

S/4HANA 2022 / ABAP 7.57 適用。記錄實作 hotspot popup ALV 過程踩過、且**編譯不會報錯、runtime 才會 dump** 的雷，未來踩同樣的就回來看這份。

---

## 1. `REUSE_ALV_POPUP_TO_SELECT` 不支援 `IS_LAYOUT`

**症狀**：呼叫時 dump `CALL_FUNCTION_PARM_UNKNOWN` / `Function parameter "IS_LAYOUT" is unknown`。

**原因**：`REUSE_ALV_POPUP_TO_SELECT` 是較早期的 popup 函式，**參數清單不含 `IS_LAYOUT`**（也沒 `IS_LAYOUT_LVC`），所以無法傳 layout 相關設定（row 染色、`cwidth_opt`、`info_fname`/`info_fieldname` 等都用不到）。

**選用準則**：

| 需求 | 用哪個 FM |
|---|---|
| 只要簡單的 popup 表格、不需 layout | `REUSE_ALV_POPUP_TO_SELECT`（簡單、欄位少時夠用） |
| 需要 row 染色、`cwidth_opt`、進階 layout、event handler | `REUSE_ALV_GRID_DISPLAY_LVC` **配** `i_screen_start_column/line` `i_screen_end_column/line`（這樣會以 popup 大小顯示，但有完整 layout 能力） |

**正確寫法（要 layout 時）**：

```abap
CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
  EXPORTING
    i_callback_program    = sy-repid
    i_bypassing_buffer    = 'X'
    i_grid_title          = lv_title
    is_layout_lvc         = ls_layout       " LVC layout (lvc_s_layo)
    it_fieldcat_lvc       = lt_fieldcat     " LVC fieldcat (lvc_t_fcat)
    i_save                = 'A'
    i_screen_start_column = 5
    i_screen_start_line   = 3
    i_screen_end_column   = 200
    i_screen_end_line     = 22
  TABLES
    t_outtab              = lt_show
  EXCEPTIONS
    program_error         = 1
    OTHERS                = 2.
```

> 範例參考：`預採帳_ZTGCX0001` 的 `FORM hotspot_show_prior_moq` (V023)、`FORM show_excluded_popup`。

---

## 2. SLIS vs LVC layout 欄位名「縮寫」差異

**症狀**：用 SLIS 名稱填 LVC 結構 — **編譯不會錯**（因為 LVC 結構也可能恰好有同名欄位，或 ABAP 接受所有 component），但 runtime **染色 / sort / 其他 layout 功能不生效**，看起來像沒設定。

**最常踩雷的對照表**：

| 用途 | SLIS (`slis_layout_alv`) | LVC (`lvc_s_layo`) |
|---|---|---|
| Row-level 顏色欄位 | `info_fieldname` | **`info_fname`** |
| Cell-level 顏色表 | `coltab_fieldname` | **`ctab_fname`** |
| Style 欄位 | `stylefname` | `stylefname`（同名） |
| Zebra | `zebra` | `zebra`（同名） |
| 欄寬最佳化 | `colwidth_optimize` | **`cwidth_opt`** |
| 沒資料訊息 | `no_input` | `no_input`（同名） |

**通則**：LVC 結構的欄位名**通常比 SLIS 短**（縮寫風格），不確定時去 SE11 看 `LVC_S_LAYO` 結構欄位清單。

**fieldcat 的差異也很多**（fields 較多重命名）：

| 用途 | SLIS (`slis_fieldcat_alv`) | LVC (`lvc_s_fcat`) |
|---|---|---|
| 標題（中欄寬） | `seltext_m` | `scrtext_m`（也建議同時填 `scrtext_l/s` + `coltext`） |
| 隱藏 | `no_out` | `no_out`（同名） |
| 不可見（技術用） | `tech` | `tech`（同名） |
| Hotspot | `hotspot` | `hotspot`（同名） |

---

## 3. Function module 參數型別檢查很嚴格 — STRING 不能傳 CHAR\*

**症狀**：dump `CALL_FUNCTION_CONFLICT_TYPE` / `CX_SY_DYN_CALL_ILLEGAL_TYPE`，錯誤訊息類似：

> The function module interface was defined in such a way that only fields of a particular type can be specified under "I_GRID_TITLE". Field "%_##TVREG_001" specified here has a different field type however.

**典型陷阱程式碼**：

```abap
" ❌ Dump！string template 結果是 STRING 型別
CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
  EXPORTING
    i_grid_title = |前期 MOQ 結餘明細: 子件 { iv_idnrk }|.   " STRING → CHAR70 FM 參數,型別不符
```

**原因**：
- ABAP **變數賦值**會自動做型別轉換（STRING → CHAR* 自動截斷或補空白）
- 但 **FM 參數的型別檢查更嚴格**：宣告是固定 CHAR70 的參數，不接受 STRING 型別實參
- String template `|...|` 結果是 STRING 型別（不是 CHAR）→ 直接傳給 CHAR\* FM 參數會 dump

**正確寫法**：先存到正確型別的變數，再傳：

```abap
" ✅ 先存到 typed variable
DATA lv_title TYPE lvc_title.
lv_title = |前期 MOQ 結餘明細: 子件 { iv_idnrk }|.   " STRING → CHAR70 變數賦值 OK

CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
  EXPORTING
    i_grid_title = lv_title.                          " CHAR70 → CHAR70 OK
```

**通用原則**：
- 傳 literal 字串（`'...'`）給 CHAR\* FM 參數 → ✅ OK（literal 會自動類型化）
- 傳 STRING 變數 / string template 結果 → ❌ 通常 dump
- 不確定時，**先存到 typed variable** 再傳

---

## 4. `FOR ALL ENTRIES IN @itab` 遇到空 itab 的行為陷阱

**症狀**：SELECT 出來的資料量比預期大、或完全空（看 kernel 版本而定）。

**原因**：`FOR ALL ENTRIES IN @itab` 遇到空 driver table 時行為**依 ABAP 版本不同**：

| ABAP 版本 / kernel | 空 driver 行為 |
|---|---|
| 較舊版本（無 SAP_BASIS 740+ kernel patch） | **忽略整個 WHERE 條件、回傳所有 rows**（災難級） |
| 較新版本（740+ 配套 OSS notes） | 回傳空集合（安全） |

**正確寫法**：永遠先 check empty：

```abap
" ✅ 安全
CHECK lt_driver IS NOT INITIAL.
SELECT … FROM ztable FOR ALL ENTRIES IN @lt_driver WHERE … INTO TABLE @lt_result.

" 或:
IF lt_driver IS INITIAL.
  RETURN.   "或 MESSAGE 提示
ENDIF.
SELECT … FROM ztable FOR ALL ENTRIES IN @lt_driver WHERE … INTO TABLE @lt_result.
```

---

## 5. ALV hotspot pattern（雙擊欄位觸發 popup）

完整可運作的最小骨架（fieldcat 標 hotspot → frm_user_command 收 '&IC1' → 開 popup ALV）：

```abap
" --- (1) 在 fieldcat 把欄位設為 hotspot ---
WHEN 'YOUR_LINK_FIELD'.
  <fs_fcat>-hotspot = 'X'.
  <fs_fcat>-outputlen = 50.

" --- (2) frm_user_command 收 '&IC1' (雙擊事件) ---
WHEN '&IC1'.
  PERFORM frm_double_click USING is_selfield.   "既有 FORM

" --- (3) frm_double_click 內依 fieldname 分流 ---
FORM frm_double_click USING is_selfield TYPE slis_selfield.
  READ TABLE gt_data ASSIGNING FIELD-SYMBOL(<fs_tab>) INDEX is_selfield-tabindex.
  IF sy-subrc EQ 0.
    CASE is_selfield-fieldname.
      WHEN 'YOUR_LINK_FIELD'.
        IF <fs_tab>-your_link_field IS NOT INITIAL.
          PERFORM your_hotspot_handler USING <fs_tab>-key1 <fs_tab>-key2.
        ENDIF.
    ENDCASE.
  ENDIF.
ENDFORM.

" --- (4) hotspot handler 用 REUSE_ALV_GRID_DISPLAY_LVC 開 popup ---
FORM your_hotspot_handler USING iv_key1 ... iv_key2 ...
  ...SELECT 資料...
  ...build fieldcat (lvc_t_fcat)...
  ...build layout (lvc_s_layo) — 含 info_fname for row 染色 if 需要...
  DATA lv_title TYPE lvc_title.
  lv_title = |Title: { iv_key1 } / { iv_key2 }|.    "存到 typed variable
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
      i_callback_program    = sy-repid
      i_bypassing_buffer    = 'X'
      i_grid_title          = lv_title
      is_layout_lvc         = ls_layout
      it_fieldcat_lvc       = lt_fieldcat
      i_save                = 'A'
      i_screen_start_column = 5
      i_screen_start_line   = 3
      i_screen_end_column   = 200
      i_screen_end_line     = 22
    TABLES
      t_outtab              = lt_show.
ENDFORM.
```

**Row-level 染色完整範例**：

```abap
" 在 ty_show 加一個 CHAR4 欄位
TYPES: BEGIN OF ty_show,
         ... 各欄位 ...
         info_color TYPE c LENGTH 4,    " 'C310' 等顏色碼
       END OF ty_show.

" 標色: 對要標的列填顏色碼
LOOP AT lt_show ASSIGNING <fs>.
  IF <fs>-key = '...想標色的條件...'.
    <fs>-info_color = 'C310'.   " 黃色
  ENDIF.
ENDLOOP.

" Layout 指向那個欄位
ls_layout-info_fname = 'INFO_COLOR'.    " ★ LVC: info_fname (非 info_fieldname)
```

**SAP 標準顏色碼** (`Cxyz` 三位數)：

| 碼 | 顏色（亮色背景） |
|---|---|
| `C100` | 灰 |
| `C200` | 淡灰 |
| `C300` / `C310` | 黃（C310 = intensified） |
| `C400` | 淡藍 |
| `C500` | 綠 |
| `C600` / `C610` | 紅 |
| `C700` | 橙 |

第二位 `x`：強度 (0 / 1)；第三位 `y`：反色 (0 / 1)。常用：`C310`（明黃，標「請看這列」）。

---

## 6. Quick reference: SLIS layout / LVC layout / fieldcat 對照

需要從 SLIS 改 LVC 時的速查：

```abap
" SLIS 版本                              " LVC 版本
DATA: lt_fcat   TYPE slis_t_fieldcat_alv,  → DATA: lt_fcat   TYPE lvc_t_fcat,
      ls_fcat   TYPE slis_fieldcat_alv,    →       ls_fcat   TYPE lvc_s_fcat,
      ls_layout TYPE slis_layout_alv.      →       ls_layout TYPE lvc_s_layo.

ls_fcat-seltext_m = '標題'.                → ls_fcat-scrtext_l = '標題'.
                                              ls_fcat-scrtext_m = '標題'.
                                              ls_fcat-scrtext_s = '標題'.
                                              ls_fcat-coltext   = '標題'.

ls_layout-info_fieldname    = 'COLOR'.     → ls_layout-info_fname   = 'COLOR'.
ls_layout-colwidth_optimize = 'X'.         → ls_layout-cwidth_opt   = 'X'.

CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'     → CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
  i_title         = ...                       i_grid_title     = lv_title (要 typed)
  it_fieldcat     = lt_fcat                   it_fieldcat_lvc  = lt_fcat
  is_layout       = ls_layout                 is_layout_lvc    = ls_layout
```

新程式**優先選 LVC**（功能較全、未來繼續維護）；舊有用 SLIS 的不必為改而改。
