*&---------------------------------------------------------------------*
*& INCLUDE          ZTGCX0003_TOP
*&---------------------------------------------------------------------*
TABLES:ztcx0004,sscrfields,marc.
**Selectin Screen

PARAMETERS: p_imp  TYPE char1 RADIOBUTTON GROUP rg1 DEFAULT 'X',
            p_upd  TYPE char1 RADIOBUTTON GROUP rg1,
            p_file TYPE string,
            p_mod  TYPE char1 RADIOBUTTON GROUP rg1,
            p_dis  TYPE char1 RADIOBUTTON GROUP rg1.
"快照開關(隱藏,預設開):未來問題全釐清後,把DEFAULT改掉(或維護TVARVC)即不再建快照
PARAMETERS p_snap TYPE char1 NO-DISPLAY DEFAULT 'X'.   "'X'=建立計算快照
SELECTION-SCREEN BEGIN OF BLOCK bk1 WITH FRAME TITLE title01.
  SELECT-OPTIONS: s_vtweg FOR ztcx0004-vtweg,
                  s_kunnr FOR ztcx0004-kunnr,
                  s_vbeln FOR ztcx0004-vbeln,
                  s_idnrk FOR ztcx0004-idnrk,
                  s_werks FOR ztcx0004-werks,
                  s_status FOR ztcx0004-xj_status,
                  s_xj    FOR ztcx0004-xj,
                  s_erdat FOR ztcx0004-xj_erdat,
                  s_ernam FOR ztcx0004-xj_ernam,
                  s_beskz FOR marc-beskz,
                  s_qty FOR ztcx0004-stock_qty,
                  s_netpr FOR ztcx0004-netpr.
SELECTION-SCREEN END OF BLOCK bk1.
SELECTION-SCREEN: FUNCTION KEY 1.
TYPES: BEGIN OF ty_key, matnr TYPE matnr, werks TYPE werks_d, END OF ty_key.
TYPES: BEGIN OF ty_pp029,
         kdauf    TYPE co_kdauf,
         kdpos    TYPE co_kdpos,
         matnr    TYPE vbap-matnr,
         werks    TYPE marc-werks,
         werks_yc TYPE marc-werks,  "V007 V1 子件需求廠(=原版 werks);攔截後回填 werks
         werks_so TYPE marc-werks,  "V1 訂單表頭展開廠(新增記錄欄)
         menge    TYPE mseg-menge, "需用量
         beskz    TYPE marc-beskz,        "採購類型
         sobsl    TYPE marc-sobsl,
         zex_hier TYPE zpsrp0002-zex_hier, "展開階層
         del12    TYPE zpsrp0002-del12,   "源頭單據號碼
         delnr    TYPE ioel-delnr,        "展開單據號碼
         meins    TYPE mara-meins,        "庫存單位
         labst    TYPE ztpprp0010-labst, "庫存數量
         insme    TYPE ztpprp0010-insme, "IQC待驗量
         bebst    TYPE ztpprp0010-bebst, "採購量
         banfb    TYPE ztpprp0010-banfb, "請購量
         menge_g  TYPE ztpprp0010-sum04, "毛需求量
         feaub    TYPE ztpprp0010-feaub, "工單數量
         plafb    TYPE ztpprp0010-plafb, "計畫單量
         menge_t  TYPE ztpprp0019-quantity, "理論存量
       END OF ty_pp029.
TYPES: BEGIN OF ty_rep,
         werks TYPE marc-werks,
         idnrk TYPE stpo-idnrk,
         rep   TYPE xfeld,
         prod  TYPE zscx0003_alv-prod,
       END OF ty_rep.
DATA:gt_rep TYPE TABLE OF ty_rep.
"V005 CALC_REP:收集「未重算/未配到適用型號」的列(P_MOD 彈窗用)
TYPES: BEGIN OF ty_calc_skip,
         xj      TYPE ztcx0004-xj,
         xj_item TYPE ztcx0004-xj_item,
         idnrk   TYPE ztcx0004-idnrk,
         matnr   TYPE ztcx0004-matnr,
         skuitem TYPE ztcx0004-skuitem,
         vtweg   TYPE ztcx0004-vtweg,
         rep     TYPE ztcx0004-rep,
         reason  TYPE c LENGTH 60,
       END OF ty_calc_skip.
DATA:gt_calc_skip TYPE TABLE OF ty_calc_skip.
"V008 confirm_qty 軟提醒:報庫存量 > 018需求量(bdmng)的列收集到此,確認後條列彈窗(不擋、不寫msg)
TYPES: BEGIN OF ty_exceed,
         xj        TYPE zscx0003_alv-xj,
         xj_item   TYPE zscx0003_alv-xj_item,
         idnrk     TYPE zscx0003_alv-idnrk,
         matnr     TYPE zscx0003_alv-matnr,
         skuitem   TYPE zscx0003_alv-skuitem,
         vtweg     TYPE zscx0003_alv-vtweg,
         werks     TYPE zscx0003_alv-werks,
         bdmng     TYPE zscx0003_alv-bdmng,        "018需求量
         stock_qty TYPE zscx0003_alv-stock_qty,    "報庫存量
         over_qty  TYPE zscx0003_alv-stock_qty,    "超出量
         over_pct  TYPE p LENGTH 7 DECIMALS 1,     "超出%(放寬長度避免極端值overflow)
       END OF ty_exceed.
DATA:gt_exceed TYPE TABLE OF ty_exceed.
DATA:gt_upload TYPE TABLE OF zscx0003_upload.  "ty_upload.
DATA:gt_data    TYPE TABLE OF zscx0003_alv,
     gt_report  TYPE TABLE OF ztcx0004,
     gt_role    TYPE TABLE OF ztcx0003,
     gt_pp029   TYPE TABLE OF ty_pp029,
     gt_custmap TYPE TABLE OF ztcx0008.
DATA:gv_xj      TYPE zscx0003_alv-xj.
"=== 快照(計算回溯)用 ===
CONSTANTS gc_stale_min   TYPE i VALUE 15.            "計算↔存檔落差提醒門檻(分)
DATA      gv_calc_tstamp TYPE timestamp.             "018最後計算時點(T0;prepare_data記)
DATA: gt_filtered TYPE lvc_t_fidx.
DATA:gv_confrim_text LIKE smp_dyntxt.
DATA:ls_data LIKE LINE OF gt_data.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
