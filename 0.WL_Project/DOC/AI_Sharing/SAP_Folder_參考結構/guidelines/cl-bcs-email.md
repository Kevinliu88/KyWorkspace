# CL_BCS 寄信（HTML 內文 + 附件）指引

S/4HANA 2022 / ABAP 7.57。記錄本工作區寄 email 實作踩過、且**編譯不會報錯或屬版本差異**的雷與可重用配方。首次落地：`ZTGCX0032`（QQ/XJ 無業務單價通知，背景排程）。相關：SBWP 分配名單見工作區 memory `reference_sood_dli_bcs_send`。

---

## 1. 最小可用配方（HTML 內文 + 寄共用分配名單）

```abap
DATA(lo_send) = cl_bcs=>create_persistent( ).

" --- HTML 內文：string → xstring(UTF-8) → solix → document ---
DATA(lv_xstr) = cl_abap_codepage=>convert_to( source = lv_html ).   " 預設 UTF-8
DATA(lt_hex)  = cl_bcs_convert=>xstring_to_solix( lv_xstr ).
DATA lv_subject TYPE so_obj_des.                                     " 主旨上限 50 字
lv_subject = |ZTGCX0032 通知 { sy-datum }|.
DATA(lo_doc) = cl_document_bcs=>create_document(
                 i_type    = 'HTM'
                 i_hex     = lt_hex
                 i_subject = lv_subject ).
lo_send->set_document( lo_doc ).

" --- 收件人：SBWP 共用分配名單(名稱來自 SOOD-OBJNAM) ---
DATA(lo_dl) = cl_distributionlist_bcs=>getu_persistent(
                i_dliname = lv_objnam
                i_private = abap_false ).        " 共用名單；個人名單=abap_true(背景不可用)
lo_send->add_recipient( i_recipient = lo_dl ).

" --- 背景必備：立即送 + COMMIT，且關掉錯誤畫面 ---
lo_send->set_send_immediately( abap_true ).
DATA(lv_ok) = lo_send->send( i_with_error_screen = abap_false ).
COMMIT WORK.                                     " 不 COMMIT 不會真的送出
```

---

## 2. ⚠️ `cl_bcs_convert=>string_to_solix` 在本系統**沒有 RETURNING**

- 直接寫 `DATA(x) = cl_bcs_convert=>string_to_solix( ... )` → 編譯錯
  `The method "STRING_TO_SOLIX" does not have a RETURNING parameter.`
- **改走 xstring 路線**（兩段都有 RETURNING、且 `xstring_to_solix` 已在 `ZTGCX0001` 實證可用）：

```abap
DATA(lv_xstr) = cl_abap_codepage=>convert_to( source = lv_string ).  " string→xstring, 預設 UTF-8
DATA(lt_solix) = cl_bcs_convert=>xstring_to_solix( lv_xstr ).        " xstring→solix(positional 呼叫)
```

> 中文 HTML 用 UTF-8；HTML 內務必加 `<meta charset="utf-8">`。不必加 BOM（HTML 反而可能因 BOM 出現怪字元）。
> 若某系統連 `cl_abap_codepage` 都沒有：退用 FM `SCMS_STRING_TO_XSTRING`。

---

## 3. ⚠️ 大量資料：HTML 巨表會讓 Outlook 卡住 → 改附 Excel

**症狀**：內文塞 6000+ 列的 `<table>`，Outlook（Word 引擎）渲染極慢甚至像沒讀完。

**準則**：**筆數超過門檻（建議 200）就不要把明細塞進 HTML**，改：
- HTML 內文只放「摘要 + 檢核邏輯 + 請見附件」，
- 明細產生**真 .xlsx** 當附件。

**內表 → 真 .xlsx（xstring）**（沿用 `ZTGCX0001` 實證寫法）：

```abap
" 1) 用 SALV 取得帶欄位標題的 LVC fieldcat
cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_salv) CHANGING t_table = gt_out ).
" ...(set_short/medium/long_text 設中文欄名)...
DATA(lt_fcat) = cl_salv_controller_metadata=>get_lvc_fieldcatalog(
                  r_columns      = lo_salv->get_columns( )
                  r_aggregations = lo_salv->get_aggregations( ) ).

" 2) fieldcat + 資料 → result data → 真 xlsx xstring
DATA(lo_result) = cl_salv_ex_util=>factory_result_data_table(
                    r_data = REF #( gt_out ) t_fieldcatalog = lt_fcat ).
DATA lv_xlsx TYPE xstring.
cl_salv_bs_tt_util=>if_salv_bs_tt_util~transform(
  EXPORTING
    xml_type      = if_salv_bs_xml=>c_type_xlsx
    xml_version   = cl_salv_bs_a_xml_base=>get_version( )
    r_result_data = lo_result
    xml_flavour   = if_salv_bs_c_tt=>c_tt_xml_flavour_export
    gui_type      = if_salv_bs_xml=>c_gui_type_gui
  IMPORTING
    xml           = lv_xlsx ).
```

**掛成附件**（檔名用 `&SO_FILENAME` 控成 .xlsx）：

```abap
DATA(lt_att) = cl_bcs_convert=>xstring_to_solix( lv_xlsx ).
DATA lv_size TYPE so_obj_len.
lv_size = xstrlen( lv_xlsx ).         " ★ 精確位元組數，務必傳
DATA ls_head TYPE soli.               " ⚠ SOLI 是「結構」，文字要塞 line 欄位
ls_head-line = |&SO_FILENAME=ZTGCX0032_明細_{ sy-datum }.xlsx|.
DATA lt_head TYPE soli_tab.
APPEND ls_head TO lt_head.
lo_doc->add_attachment(
  i_attachment_type    = 'BIN'
  i_attachment_subject = 'ZTGCX0032_明細'
  i_attachment_size    = lv_size       " ★ 不傳→檔案損毀(見下)
  i_att_content_hex    = lt_att
  i_attachment_header  = lt_head ).
```

> 🔴 **最容易踩的雷：附件一定要傳 `i_attachment_size = xstrlen( xstring )`。**
> `xstring_to_solix` 把二進位切成每列 255 bytes，**最後一列用 `00` 補滿**；不給精確 size，BCS 會把補的 `00` 也算進去 → xlsx(=zip)尾端多垃圾位元組 → Excel 開檔報「We found a problem… recover?」。`gui_download` 同理要傳 `bin_filesize = xstrlen( … )`。
> ⚠️ `SOLI`/`SOLISTI1` 是**結構**(欄位 `line` char255)，不可 `DATA x TYPE soli. x = '...'.`（報 *cannot be converted to a character-like value*）→ 要 `x-line = '...'`。
> 版本差異點：`add_attachment` 若不吃 `&SO_FILENAME`，退而求其次用
> `i_attachment_type = 'XLS'`（Excel 開啟時可能跳一次「格式不符」提示，內容仍正確）。

---

### 3a. 要「多個 sheet」→ 用 SpreadsheetML，不要硬湊 .xlsx

`cl_salv_bs_tt_util~transform` 只產**單一 sheet**。要多 sheet（如 QQ 一頁、XJ 一頁）最省力的是 **SpreadsheetML（Excel 2003 XML）**：純文字組一個 `<Workbook>` 內含多個 `<Worksheet>`，無需任何外部元件（`Tool_DataToExcel` 即此法）。

```abap
" 骨架(每個 Worksheet 一頁；Cell 一律 ss:Type="String" 最單純)
APPEND '<?xml version="1.0" encoding="UTF-8"?>'        TO lt_xml.
APPEND '<?mso-application progid="Excel.Sheet"?>'      TO lt_xml.
APPEND '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">' TO lt_xml.
" ...<Worksheet ss:Name="QQ"><Table><Row><Cell><Data ss:Type="String">值</Data></Cell>...</Row></Table></Worksheet>...
APPEND '</Workbook>' TO lt_xml.
CONCATENATE LINES OF lt_xml INTO lv_str SEPARATED BY cl_abap_char_utilities=>newline.
DATA(lv_body) = cl_abap_codepage=>convert_to( source = lv_str ).   " UTF-8
CONCATENATE lc_bom lv_body INTO lv_xstring IN BYTE MODE.            " lc_bom = x'EFBBBF'
```

- 附檔副檔名用 **`.xls`**（`&SO_FILENAME=xxx.xls`）；Excel 開 SpreadsheetML 多 sheet 正常（少數 Office 版本會跳一次「格式/副檔名不符」提示，內容無誤）。
- 文字 cell 記得 XML 跳脫 `& < >`；日期自己格式化成字串。
- 要「真 .xlsx 多 sheet」才需 abap2xlsx 或 OOXML(`cl_xlsx_*`) API（較重，非必要不用）。
- 範例：`ZTGCX0032` 的 `build_xls_2sheet` / `add_xls_sheet`。

## 4. 背景排程注意
- 全程**不可彈窗**：`send( i_with_error_screen = abap_false )`、不要 `POPUP_*`、F4 只在前景。
- 送出要 `COMMIT WORK`；要立即送用 `set_send_immediately( abap_true )`（否則卡在 SOST 等 SCOT 批次）。
- 分配名單成員是 SAP 使用者 → 信進 SBWP 收件匣；要**真外部 email** 需名單成員為 internet 位址、或 SU01 有 email + SCOT 對外路由（Basis 面，非程式能保證）。
- 查無資料是否仍發信，依需求；`ZTGCX0032` 採「仍發、主旨/內文註記無項目」。
```
