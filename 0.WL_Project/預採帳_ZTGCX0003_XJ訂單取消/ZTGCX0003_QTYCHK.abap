*&---------------------------------------------------------------------*
*& Report  ZTGCX0003_QTYCHK
*&---------------------------------------------------------------------*
*& 預採帳-XJ 需求量比對核對報表(唯讀)
*&---------------------------------------------------------------------*
* Purpose : 對已建立的 XJ,再呼叫一次 018(ZTGPPRP0019)即時重算需求量,
*           與「建立當下存的需求量(ZTCX0004-BDMNG)」並排比差異,
*           讓生管警覺「建立當下數字極端異常」的單,並補顯示
*           「018 有、003 沒有」的漏料(新舊料/最高版本去重砍掉的舊料)。
* Note    : 純唯讀、不寫 DB、不做任何動作。比對是啟發式警示,非對錯判定。
*           設計依據:ZTGCX0003_需求量比對核對報表_提案.md
* Author  : JosephLo                                   Date: 2026-06-11
*&---------------------------------------------------------------------*
REPORT ztgcx0003_qtychk NO STANDARD PAGE HEADING MESSAGE-ID zcx01.

TYPE-POOLS: icon.
TABLES: ztcx0004.

*&---------------------------------------------------------------------*
*& 全域型別 / 資料
*&---------------------------------------------------------------------*
* 即時 018 重算結果(聚合到 料號+工廠)
TYPES: BEGIN OF ty_now,
         matnr   TYPE matnr,
         werks   TYPE werks_d,
         menge   TYPE zpsrp0002-menge,   "即時需用料量
         matched TYPE c LENGTH 1,        "是否已對應到 003 列
       END OF ty_now.
TYPES: ty_now_t TYPE STANDARD TABLE OF ty_now WITH DEFAULT KEY.

* 比對輸出列
TYPES: BEGIN OF ty_out,
         prio      TYPE c LENGTH 1,             "排序優先(技術欄,隱藏)
         light     TYPE icon_d,                 "號誌燈
         status    TYPE c LENGTH 24,            "兩邊都有/003未顯示(漏料)/018現無/核對失敗
         xj        TYPE ztcx0004-xj,
         xj_item   TYPE ztcx0004-xj_item,
         vbeln     TYPE ztcx0004-vbeln,
         posnr     TYPE ztcx0004-posnr,
         idnrk     TYPE ztcx0004-idnrk,
         werks     TYPE ztcx0004-werks,
         maktx     TYPE makt-maktx,
         bdmng_db  TYPE ztcx0004-bdmng,         "建立時需求量
         menge_now TYPE zpsrp0002-menge,        "即時 018 需求量
         diff      TYPE zpsrp0002-menge,        "即時 − 建立
         ratio     TYPE p LENGTH 11 DECIMALS 3, "比率 = 即時 ÷ 建立
         canc_qty  TYPE ztcx0004-canc_qty,
         stock_qty TYPE ztcx0004-stock_qty,     "生管當初報的量(對照)
         xj_status TYPE ztcx0004-xj_status,
         xj_erdat  TYPE ztcx0004-xj_erdat,
       END OF ty_out.

DATA: gt_xj  TYPE TABLE OF ztcx0004,
      gt_out TYPE TABLE OF ty_out.

*&---------------------------------------------------------------------*
*& Selection Screen
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE title1.
  SELECT-OPTIONS: s_xj    FOR ztcx0004-xj OBLIGATORY,
                  s_werks FOR ztcx0004-werks,
                  s_vtweg FOR ztcx0004-vtweg,
                  s_erdat FOR ztcx0004-xj_erdat.
  PARAMETERS:     p_thr   TYPE p LENGTH 5 DECIMALS 2 DEFAULT '10.00'. "紅燈倍率門檻
SELECTION-SCREEN END OF BLOCK b1.

* 說明區塊(慣例:放輸入元素最下方)
SELECTION-SCREEN BEGIN OF BLOCK b9 WITH FRAME TITLE title9.
  SELECTION-SCREEN COMMENT /1(79) cmt1.
  SELECTION-SCREEN COMMENT /1(79) cmt2.
  SELECTION-SCREEN COMMENT /1(79) cmt3.
  SELECTION-SCREEN COMMENT /1(79) cmt4.
SELECTION-SCREEN END OF BLOCK b9.

*&---------------------------------------------------------------------*
*& INITIALIZATION (FRAME TITLE / COMMENT 變數自動宣告,勿再 DATA)
*&---------------------------------------------------------------------*
INITIALIZATION.
  title1 = '篩選條件'.
  title9 = '說明'.
  cmt1 = '對選取的 XJ 再跑一次 018(ZTGPPRP0019)即時重算,與建立時存的需求量比差異。'.
  cmt2 = '🔴 漏料(003未顯示)/比率≥門檻或≤1/門檻; 🟡 1.5x~門檻; 🟢 正常波動。純顯示,不做任何動作。'.
  cmt3 = '⚠ 不同時點本就有差異;此報表是抓「建立當下極端異常(如 1.3→200)」,非判對錯。'.
  cmt4 = '⚠ 建立後須隔一段時間(MRP 動過)再核對才有偵測力;一張 XJ 會跑一次 018,請適度縮範圍。'.

*&---------------------------------------------------------------------*
*& START-OF-SELECTION
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM get_xj_data.
  IF gt_xj IS INITIAL.
    MESSAGE s001(00) WITH '查無 XJ 資料'.
    RETURN.
  ENDIF.
  PERFORM build_compare.
  PERFORM display_alv.

*&---------------------------------------------------------------------*
*& Form get_xj_data
*&---------------------------------------------------------------------*
FORM get_xj_data.
  SELECT * FROM ztcx0004
    INTO TABLE @gt_xj
    WHERE xj       IN @s_xj
      AND werks    IN @s_werks
      AND vtweg    IN @s_vtweg
      AND xj_erdat IN @s_erdat.
  SORT gt_xj BY xj xj_item.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form build_compare
*&  每張 XJ 跑一次 018,以 idnrk+werks 做 full outer join,分三桶
*&---------------------------------------------------------------------*
FORM build_compare.
  DATA: lt_now   TYPE ty_now_t,
        lv_fail  TYPE c LENGTH 1,
        lv_vbeln TYPE vbeln,
        lv_posnr TYPE posnr,
        lv_menge TYPE resbd-menge.
  FIELD-SYMBOLS: <now> TYPE ty_now,
                 <o>   TYPE ty_out.

  LOOP AT gt_xj INTO DATA(ls_x) GROUP BY ( xj = ls_x-xj ) INTO DATA(lg).
    CLEAR: lt_now, lv_fail, lv_vbeln, lv_posnr, lv_menge.

    "--- 取該 XJ 的 vbeln/posnr/canc_qty(各項次一致,取第一筆) ---
    LOOP AT GROUP lg INTO DATA(ls_h).
      lv_vbeln = ls_h-vbeln.
      lv_posnr = ls_h-posnr.
      lv_menge = ls_h-canc_qty.
      EXIT.
    ENDLOOP.

    "--- 即時重跑 018 ---
    PERFORM run_018 USING lv_vbeln lv_posnr lv_menge
                  CHANGING lt_now lv_fail.

    "--- 003 側:逐項次比對 ---
    LOOP AT GROUP lg INTO DATA(ls_c).
      APPEND INITIAL LINE TO gt_out ASSIGNING <o>.
      <o>-xj        = ls_c-xj.
      <o>-xj_item   = ls_c-xj_item.
      <o>-vbeln     = ls_c-vbeln.
      <o>-posnr     = ls_c-posnr.
      <o>-idnrk     = ls_c-idnrk.
      <o>-werks     = ls_c-werks.
      <o>-bdmng_db  = ls_c-bdmng.
      <o>-canc_qty  = ls_c-canc_qty.
      <o>-stock_qty = ls_c-stock_qty.
      <o>-xj_status = ls_c-xj_status.
      <o>-xj_erdat  = ls_c-xj_erdat.
      PERFORM get_maktx USING ls_c-idnrk CHANGING <o>-maktx.

      IF lv_fail = 'X'.
        <o>-status = '018 核對失敗/無資料'.
        <o>-light  = icon_yellow_light.
        <o>-prio   = '5'.
        CONTINUE.
      ENDIF.

      READ TABLE lt_now ASSIGNING <now>
           WITH KEY matnr = ls_c-idnrk werks = ls_c-werks.
      IF sy-subrc = 0.
        <now>-matched   = 'X'.
        <o>-menge_now   = <now>-menge.
        <o>-diff        = <now>-menge - ls_c-bdmng.
        <o>-status      = '兩邊都有'.
        PERFORM calc_light USING ls_c-bdmng <now>-menge
                         CHANGING <o>-ratio <o>-light <o>-prio.
      ELSE.
        "003 有、018 現在沒有
        <o>-status = '018 現無(已處理/料變)'.
        <o>-light  = icon_yellow_light.
        <o>-prio   = '4'.
      ENDIF.
    ENDLOOP.

    "--- 018 側:沒被對應到的 = 漏料(003 未顯示) ---
    IF lv_fail = space.
      LOOP AT lt_now ASSIGNING <now> WHERE matched = space.
        APPEND INITIAL LINE TO gt_out ASSIGNING <o>.
        <o>-xj        = lg-xj.
        <o>-vbeln     = lv_vbeln.
        <o>-posnr     = lv_posnr.
        <o>-idnrk     = <now>-matnr.
        <o>-werks     = <now>-werks.
        <o>-menge_now = <now>-menge.
        <o>-canc_qty  = lv_menge.
        <o>-status    = '003 未顯示(漏料)'.
        <o>-light     = icon_red_light.
        <o>-prio      = '1'.
        PERFORM get_maktx USING <now>-matnr CHANGING <o>-maktx.
      ENDLOOP.
    ENDIF.
  ENDLOOP.

  "排序:漏料(1) → 紅(2) → 黃(3) → 018現無(4) → 核對失敗(5) → 綠(6);同組比率大者在前
  SORT gt_out BY prio ASCENDING ratio DESCENDING xj xj_item.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form run_018
*&  複用 ZTGCX0003 submit_pp029 的攔截寫法,聚合到 (matnr,werks)
*&---------------------------------------------------------------------*
FORM run_018 USING    p_vbeln TYPE vbeln
                      p_posnr TYPE posnr
                      p_menge TYPE resbd-menge
             CHANGING ct_now  TYPE ty_now_t
                      cv_fail TYPE c.
  DATA: lr_data TYPE REF TO data,
        ls_n    TYPE ty_now.
  FIELD-SYMBOLS: <tab> TYPE STANDARD TABLE,
                 <row> TYPE any.

  CLEAR: ct_now, cv_fail.
  IF p_vbeln IS INITIAL OR p_posnr IS INITIAL OR p_menge IS INITIAL.
    cv_fail = 'X'.
    RETURN.
  ENDIF.

  cl_salv_bs_runtime_info=>set( display  = abap_false
                                metadata = abap_false
                                data     = abap_true ).
  SUBMIT ztgpprp0019 WITH r_bt1   = 'X'
                     WITH p_vbeln = p_vbeln
                     WITH p_posnr = p_posnr
                     WITH p_menge = p_menge
                     WITH r_mode1 = 'X'        "加總(與 003 建立時一致)
                     WITH r_mode2 = space
    AND RETURN.
  TRY.
      cl_salv_bs_runtime_info=>get_data_ref( IMPORTING r_data = lr_data ).
      ASSIGN lr_data->* TO <tab>.
    CATCH cx_salv_bs_sc_runtime_info.
      cv_fail = 'X'.
  ENDTRY.
  cl_salv_bs_runtime_info=>clear_all( ).

  IF cv_fail = 'X' OR <tab> IS NOT ASSIGNED.
    cv_fail = 'X'.
    RETURN.
  ENDIF.

  "聚合到 (matnr,werks);排除成品本身列(matnr = matnr_f)
  LOOP AT <tab> ASSIGNING <row>.
    ASSIGN COMPONENT 'MATNR'   OF STRUCTURE <row> TO FIELD-SYMBOL(<f_matnr>).
    ASSIGN COMPONENT 'WERKS'   OF STRUCTURE <row> TO FIELD-SYMBOL(<f_werks>).
    ASSIGN COMPONENT 'MENGE'   OF STRUCTURE <row> TO FIELD-SYMBOL(<f_menge>).
    ASSIGN COMPONENT 'MATNR_F' OF STRUCTURE <row> TO FIELD-SYMBOL(<f_matf>).
    IF <f_matnr> IS ASSIGNED AND <f_werks> IS ASSIGNED AND <f_menge> IS ASSIGNED.
      IF <f_matf> IS ASSIGNED AND <f_matnr> = <f_matf>.
        "成品本身,非要報的子件,略過
      ELSE.
        CLEAR ls_n.
        ls_n-matnr = <f_matnr>.
        ls_n-werks = <f_werks>.
        ls_n-menge = <f_menge>.
        COLLECT ls_n INTO ct_now.
      ENDIF.
    ENDIF.
    UNASSIGN: <f_matnr>, <f_werks>, <f_menge>, <f_matf>.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form calc_light  (比率 + 號誌 + 排序優先)
*&---------------------------------------------------------------------*
FORM calc_light USING    p_db   TYPE ztcx0004-bdmng
                         p_now  TYPE zpsrp0002-menge
                CHANGING p_ratio TYPE p
                         p_light TYPE icon_d
                         p_prio  TYPE c.
  DATA: lv_db  TYPE p LENGTH 16 DECIMALS 6,
        lv_now TYPE p LENGTH 16 DECIMALS 6,
        lv_lo  TYPE p LENGTH 11 DECIMALS 6.

  lv_db  = p_db.
  lv_now = p_now.

  "建立值≈0 的特例
  IF lv_db = 0.
    IF lv_now = 0.
      p_ratio = 1.
      p_light = icon_green_light.
      p_prio  = '6'.
    ELSE.
      p_ratio = 9999.                 "建立 0、現有量 → 極端
      p_light = icon_red_light.
      p_prio  = '2'.
    ENDIF.
    RETURN.
  ENDIF.

  p_ratio = lv_now / lv_db.
  lv_lo   = 1 / p_thr.                 "下界 = 1/門檻

  IF p_ratio >= p_thr OR p_ratio <= lv_lo.
    p_light = icon_red_light.
    p_prio  = '2'.
  ELSEIF p_ratio >= '1.5' OR p_ratio <= '0.67'.
    p_light = icon_yellow_light.
    p_prio  = '3'.
  ELSE.
    p_light = icon_green_light.
    p_prio  = '6'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_maktx
*&---------------------------------------------------------------------*
FORM get_maktx USING p_matnr TYPE matnr CHANGING p_maktx TYPE makt-maktx.
  CLEAR p_maktx.
  SELECT SINGLE maktx FROM makt
    INTO @p_maktx
    WHERE matnr = @p_matnr
      AND spras = @sy-langu.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form display_alv
*&---------------------------------------------------------------------*
FORM display_alv.
  DATA: lt_fcat TYPE lvc_t_fcat,
        ls_fcat TYPE lvc_s_fcat,
        ls_layo TYPE lvc_s_layo.

  DEFINE m_fcat.
    CLEAR ls_fcat.
    ls_fcat-fieldname = &1.
    ls_fcat-coltext   = &2.
    ls_fcat-scrtext_l = &2.
    ls_fcat-scrtext_m = &2.
    ls_fcat-scrtext_s = &2.
    ls_fcat-outputlen = &3.
    APPEND ls_fcat TO lt_fcat.
  END-OF-DEFINITION.

  m_fcat 'LIGHT'     '號誌'         4.
  m_fcat 'STATUS'    '比對狀態'     22.
  m_fcat 'XJ'        'XJ 單號'      12.
  m_fcat 'XJ_ITEM'   'XJ 項次'      6.
  m_fcat 'VBELN'     '銷售文件'     10.
  m_fcat 'POSNR'     '項次'         6.
  m_fcat 'IDNRK'     '材料'         18.
  m_fcat 'MAKTX'     '品名'         24.
  m_fcat 'BDMNG_DB'  '建立時需求量' 15.
  m_fcat 'MENGE_NOW' '即時018需求量' 15.
  m_fcat 'DIFF'      '差異(即時−建立)' 15.
  m_fcat 'RATIO'     '比率(倍)'     12.
  m_fcat 'CANC_QTY'  '取消數量'     13.
  m_fcat 'STOCK_QTY' '報庫存數量'   15.
  m_fcat 'XJ_STATUS' 'XJ狀態'       6.
  m_fcat 'XJ_ERDAT'  '建立日'       10.

  "號誌欄以 icon 呈現
  READ TABLE lt_fcat ASSIGNING FIELD-SYMBOL(<lt>) WITH KEY fieldname = 'LIGHT'.
  IF sy-subrc = 0.
    <lt>-icon = 'X'.
  ENDIF.

  ls_layo-cwidth_opt = 'X'.
  ls_layo-zebra      = 'X'.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
      i_callback_program = sy-repid
      is_layout_lvc      = ls_layo
      it_fieldcat_lvc    = lt_fcat
      i_save             = 'A'
    TABLES
      t_outtab           = gt_out
    EXCEPTIONS
      program_error      = 1
      OTHERS             = 2.
ENDFORM.
