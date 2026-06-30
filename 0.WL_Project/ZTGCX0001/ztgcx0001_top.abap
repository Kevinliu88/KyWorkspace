*&---------------------------------------------------------------------*
*& INCLUDE          ZTGCX0001_TOP (修改版 - 含 PATCH H)
*&--------------------------------------------------------------------*
TABLES: ztcx0001, sscrfields.

*--- 新增 PIR 相關表格宣告 ---
TABLES: pbim, pbed.

**Selection Screen
* 20260524 JosephLo 第一行動態顯示當前 t-code，方便分辨 ZTGCX0001 / ZTGCX0001A 等不同入口
*   註：COMMENT 會自動宣告 gv_scinf(char79)，不可再用 DATA 宣告(否則 already declared)
SELECTION-SCREEN BEGIN OF LINE.
  SELECTION-SCREEN COMMENT 1(79) gv_scinf.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN SKIP.
PARAMETERS: p_imp  TYPE char1 RADIOBUTTON GROUP rg1 DEFAULT 'X',
            p_filt TYPE char1 AS CHECKBOX,    "V025 過濾:勾=只顯示本角色關注件(濾掉非所屬角色/不報MOQ),不勾(預設)=顯示全部;僅ZTGCX0001A模擬+上傳露出(adjust_screen_filt控制);選擇文字需文字池維護
            p_upd  TYPE char1 RADIOBUTTON GROUP rg1,
            p_file TYPE string,
            p_mod  TYPE char1 RADIOBUTTON GROUP rg1,
            p_dis  TYPE char1 RADIOBUTTON GROUP rg1,
            p_fix  TYPE char1 RADIOBUTTON GROUP rg1.  "補回不報MOQ料號

SELECTION-SCREEN BEGIN OF BLOCK bk1 WITH FRAME TITLE title01.
  SELECT-OPTIONS: s_vtweg  FOR ztcx0001-vtweg,
                  s_beskz  FOR ztcx0001-beskz,
                  "s_kunnr FOR ztcx0001-kunnr,
                  s_idnrk  FOR ztcx0001-idnrk,
                  s_werks  FOR ztcx0001-werks,
                  s_status FOR ztcx0001-qq_status,
                  s_pr     FOR ztcx0001-zportalno,
                  s_so     FOR ztcx0001-vbeln,
                  s_qq     FOR ztcx0001-qq,
                  s_erdat  FOR ztcx0001-erdat,
                  s_sku    FOR ztcx0001-skuitem.
SELECTION-SCREEN END OF BLOCK bk1.
SELECTION-SCREEN: FUNCTION KEY 1.

*---------------------------------------------------------------------*
* PATCH F : Independent Demand Types (PIR 相關型別定義)
*---------------------------------------------------------------------*
TYPES: BEGIN OF ty_key,
         matnr    TYPE matnr,
         werks    TYPE werks_d,
         req_date TYPE datum,
       END OF ty_key.

" === 修改後（增加 is_electronic 欄位）===
TYPES: BEGIN OF ty_result,
         matnr         TYPE matnr,
         werks         TYPE werks_d,
         req_date      TYPE datum,
         qty           TYPE menge_d,
         is_electronic TYPE abap_bool,   " 是否電子件
       END OF ty_result.

" === 專用 TABLE TYPE ===
TYPES: tt_key    TYPE STANDARD TABLE OF ty_key    WITH DEFAULT KEY,
       tt_result TYPE STANDARD TABLE OF ty_result WITH DEFAULT KEY.

*---------------------------------------------------------------------*
* 子階料號結構定義 (for filter_sub_materials)
*---------------------------------------------------------------------*
TYPES: BEGIN OF ty_sub,
         matnr        TYPE matnr,       " 料號
         werks        TYPE werks_d,     " 工廠
         cross_status TYPE char1,       " 跨廠狀態
         bun          TYPE i,           " 元件數量
         mtart        TYPE mtart,       " 物料類型
         stock        TYPE menge_d,     " 理論庫存
         indep_qty    TYPE menge_d,     " 有效獨立需求數量
         beskz        TYPE beskz,       " 採購型態 (E/F)
         sobsl        TYPE sobsl,       " 特殊採購類型
         auto_price   TYPE abap_bool,   " 是否自動取價
         is_missing   TYPE abap_bool,   " 是否缺料
       END OF ty_sub.

TYPES: tt_sub TYPE STANDARD TABLE OF ty_sub WITH DEFAULT KEY.

*---------------------------------------------------------------------*
* 新增：物料狀態檢查用型別
*---------------------------------------------------------------------*
TYPES: BEGIN OF ty_mara_check,
         matnr TYPE matnr,
         mstae TYPE mstae,
       END OF ty_mara_check.

TYPES: tt_mara_check TYPE STANDARD TABLE OF ty_mara_check WITH DEFAULT KEY.

*---------------------------------------------------------------------*
* 上傳檔案結構
*---------------------------------------------------------------------*
TYPES: BEGIN OF ty_upload,
         vtweg     TYPE ztcx0001-vtweg,
         matnr     TYPE mara-matnr,
         werks     TYPE t001w-werks,
         menge     TYPE char20,
         req_date  TYPE datum,
         zportalno TYPE ztcx0001-zportalno,
         ebeln     TYPE ztcx0001-ebeln,
         zmsg      TYPE char100,
       END OF ty_upload.

*---------------------------------------------------------------------*
* 全域變數宣告
*---------------------------------------------------------------------*
DATA: gt_upload TYPE TABLE OF ty_upload.
DATA: gt_data   TYPE TABLE OF zscx0001_alv,
      gt_report TYPE TABLE OF zscx0001_alv.
DATA: gt_custmap TYPE TABLE OF ztcx0008.
DATA: gt_nomoq   TYPE TABLE OF ztcx0014.
DATA: gt_role    TYPE TABLE OF ztcx0003.
DATA: gv_save    TYPE char1.
* V022 Added by JosephLo 20260526 *
* MOQ 計算基準動態切換旗標 (詳見 SUB:choose_moq_basis FORM)
*   'L' = Liability 餘額 (z_end_balance) — 本案目標的新基準
*   'S' = 理論庫存 (stock_qty) — V013 改回後維持的舊基準
* 預設 'L' (本案專案目標)；實際值由 choose_moq_basis 在使用者按
*   [重新計算報MOQ量] 或 [確認產生QQ單號] 時動態設定。
*   gate: sy-tcode='ZTGCX0001A' 才彈窗讓 user 選；其他 t-code(含本主程式) 固定 'L'。
* 兩個消費端：calc_moq_qty 的 lv_req_qty(§5.2)、calc_7day_qq 的 moq_remain 首次分支(§5.1)
DATA: gv_moq_basis TYPE char1 VALUE 'L'.
* V022 End off *
* V025 JosephLo 2026/06/01 mode profile：把散落的 sy-tcode 判斷收斂成一處能力旗標(由 init_mode 設定一次)
TYPES: BEGIN OF ty_mode,
         tcode       TYPE sy-tcode,
         do_filter   TYPE abap_bool,   "角色+不報MOQ過濾(explode_bom/assign_rem_data/check_nomoq_rule)
         allow_write TYPE abap_bool,   "可寫DB:CONFIRM產QQ/&DATA_SAVE/DELETE
         pick_basis  TYPE abap_bool,   "彈窗讓user挑MOQ基準L/S
         relax_check TYPE abap_bool,   "放寬上傳/詢單檢查(is_check_bypassed)
       END OF ty_mode.
DATA: gs_mode TYPE ty_mode.
* V020 JosephLo 2026/05/22 客戶型號不存在件號清單(無BOM且ZTSD0020 ZTYPE=2查無)→交易(Save/QQ)時檢查
DATA: BEGIN OF gs_sku_err,
        matnr TYPE matnr,
        vtweg TYPE vtweg,
      END OF gs_sku_err,
      gt_sku_err LIKE TABLE OF gs_sku_err.
* 20260524 JosephLo 統一異常訊息顯示重構：所有「沒進主alv的件」統一收集，進alv前 popup 條列
TYPES: BEGIN OF ty_excluded,
         sort_seq  TYPE n LENGTH 2,                "排序鍵(IT_SORT用,重要性遞減大者在前:99上傳檢查/98詢單重複/97無客戶型號/50分隔/09無可報子件/08非本角色/07不報MOQ)
         category  TYPE c LENGTH 20,               "分類文字
         matnr_fg  TYPE matnr,                     "成品料號(=上傳主件號)
         idnrk     TYPE matnr,                     "被排除料號本身(子件或無BOM自身)
         parent    TYPE matnr,                     "上階料號(若可得)
         mnglg     TYPE p LENGTH 13 DECIMALS 3,    "單位用量(若有)
         menge     TYPE p LENGTH 13 DECIMALS 3,    "需求數量(若有)
         beskz     TYPE beskz,                     "採購類型F/E(若有)
         sobsl     TYPE sobsl,                     "特殊採購(若有)
         lifnr     TYPE lifnr,                     "外部供應商(若有)
         vtweg     TYPE vtweg,
         werks     TYPE werks_d,
         zportalno TYPE ztcx0001-zportalno,
         reason    TYPE c LENGTH 120,              "原因明細
       END OF ty_excluded.
DATA: gt_excluded TYPE STANDARD TABLE OF ty_excluded.
* V013 Added by Tristan 2026/04/29 *
DATA: it_bom TYPE TABLE OF ztcx0001_bom.
DATA: r_zportalno TYPE RANGE OF ztcx0001-zportalno.
DATA: del_log TYPE TABLE OF ztcx0001.
RANGES: r_lifnr FOR lfa1-lifnr.
* V013 End off *
*=== 不報MOQ料號清單（內存控制）===
DATA: gt_no_moq_list TYPE HASHED TABLE OF matnr WITH UNIQUE KEY table_line.
* 20260524 JosephLo 階段3 W統一：原 ty_self_moq/gt_self_moq(需求3 補自身項用)已廢除；
*   無BOM件統一由 assign_rem_data(lines(lt_stpox)=0)處理(查 ZTSD0020 客戶型號)。



*---------------------------------------------------------------------*
* 新增：PIR 相關全域變數
*---------------------------------------------------------------------*
DATA: gt_pir_keys   TYPE tt_key,
      gt_pir_result TYPE tt_result.

*---------------------------------------------------------------------*
* 新增：物料狀態檢查緩存
*---------------------------------------------------------------------*
DATA: gt_mara_status TYPE tt_mara_check.
* V013 Added by Tristan 2026/04/16 *
DATA: it_stpox TYPE TABLE OF stpox,
      lt_bom   TYPE TABLE OF stpox,
      it_liab  TYPE TABLE OF ztcx0026.
TYPES: BEGIN OF ty_marc,
         matnr           TYPE matnr,
         werks           TYPE werks_d,
         zdefault_vendor TYPE lifnr,
       END OF ty_marc.
DATA: it_marc TYPE SORTED TABLE OF ty_marc WITH UNIQUE KEY matnr werks,
      pt_data TYPE TABLE OF zscx0001_alv.
* V013 End off *

*===============================================================================
* PATCH A：在 TYPE 區段增加料價結構定義
* 位置：TOP include 約第 170 行附近,ty_result 定義後方
*===============================================================================
TYPES: BEGIN OF ty_price,
         matnr TYPE matnr,
         bwkey TYPE bwkey,
         stprs TYPE stprs,
         verpr TYPE verpr,   " 改為 verpr
         peinh TYPE peinh,
       END OF ty_price.
TYPES: tt_price TYPE HASHED TABLE OF ty_price WITH UNIQUE KEY matnr bwkey.

" QI 庫存結構
TYPES: BEGIN OF ty_qi_stock,
         matnr TYPE matnr,
         werks TYPE werks_d,
         lgort TYPE lgort_d,
         insme TYPE insme,   " 檢驗中庫存
       END OF ty_qi_stock.
TYPES: tt_qi_stock TYPE STANDARD TABLE OF ty_qi_stock WITH DEFAULT KEY.
*===============================================================================
* PATCH B：全域變數區增加料價與 QI 庫存緩存
* 位置：DATA 區段,約第 225 行附近 gt_pir_result 後方
*===============================================================================
DATA: gt_price_cache TYPE tt_price,
      gt_qi_cache    TYPE tt_qi_stock.

*---------------------------------------------------------------------*
* 新增：ERDAT  建立日期指定為月底
*---------------------------------------------------------------------*
DATA: my_erdat   TYPE sy-datum.
my_erdat = '20260331'.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
