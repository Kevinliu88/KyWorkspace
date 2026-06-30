*&---------------------------------------------------------------------*
*& Report ZTGCX0028
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ztgcx0028.

TABLES:ztsd0098,ztsd0099.
*----------------------------------------------------------------------*
* TYPE-POOLS
*----------------------------------------------------------------------*
TYPE-POOLS: slis.
*交通燈引用類型池
TYPE-POOLS:icon.
*&---------------------------------------------------------------------*
*&聲明ALV參數
*&---------------------------------------------------------------------*
DATA:gt_fieldcat TYPE lvc_t_fcat, "字段目錄内表
     gs_fieldcat TYPE lvc_s_fcat, "字段目錄工作區
     gs_layout   TYPE lvc_s_layo. "用於定義ALV表單的相關格式、屬性

TYPES:BEGIN OF ty_alv,
        vtweg     TYPE ztsd0098-vtweg, "配銷通路
        zpno      TYPE ztsd0099-zpno,  "預採件號
        zxqdat    TYPE ztsd0098-zxqdat, "XQ單產生日期
        zxqno     TYPE ztsd0100-zxqno, "XQ單號
        zxqseq    TYPE ztsd0100-zxqseq, "XQ單序號
        zym       TYPE ztsd0100-zym, "XQ單轉出年月
        zseq_xq   TYPE ztsd0100-zseq, "XQ單轉出序號
        zup       TYPE ztsd0099-zup, "XQ單業務單價
        zup_per   TYPE ztsd0099-zup_per, "業務單價定價單位
        zptyp     TYPE ztsd0100-zptyp,  "XQ單轉出類別
        zqty      TYPE ztsd0100-zqty,  "XQ單轉出數量
        zprice    TYPE  ztsd0099-zup,  "超轉出金額
        zqty_sy   TYPE ztcx0026-zqty_sy,  "剩餘XQ
        zquan     TYPE ztcx0026-zquan, "正確轉出數量
        menge_sy  TYPE ztcx0026-menge_sy, "剩餘IQ
        zportalno TYPE ztcx0001-zportalno, "詢單單號
        zseq      TYPE ztcx0001-zseq, "帳本編號
        qq        TYPE ztcx0001-qq,  "QQ單號
        qq_seq    TYPE ztcx0001-qq_seq, "QQ單序號
        vbeln     TYPE ztcx0001-vbeln, "銷售文件
        posnr     TYPE ztcx0001-posnr, "銷售文件項目
        audat     TYPE ztsd0028-audat, "轉正確認日期
        menge     TYPE ztcx0026-menge, "轉正數量
        check     TYPE c,
      END OF ty_alv.
DATA:gt_alv TYPE TABLE OF ty_alv,
     gs_alv TYPE ty_alv.
*&---------------------------------------------------------------------*
*搜索幫助
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001. "選擇準則
  SELECT-OPTIONS: s_vtweg FOR ztsd0098-vtweg,"配銷通路
                               s_zpno FOR ztsd0099-zpno, "預採件號
                               s_audat FOR ztsd0098-zxqdat DEFAULT sy-datum OBLIGATORY NO INTERVALS NO-EXTENSION. "詢單轉正截止日期
SELECTION-SCREEN END OF BLOCK b1.

AT SELECTION-SCREEN OUTPUT.

START-OF-SELECTION.
  PERFORM frm_get_data.   "獲取數據
  PERFORM frm_set_fieldcat."設置字段
  PERFORM frm_set_layout.  "設置顯示格式
  PERFORM frm_display_alv. "ALV報表展示
*&---------------------------------------------------------------------*
*& Form frm_get_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM frm_get_data.
  TYPES:BEGIN OF ty_ztcx0001,
          werks     TYPE ztcx0001-werks,
          vtweg     TYPE ztcx0001-vtweg,
          zseq      TYPE ztcx0001-zseq,
          zportalno TYPE ztcx0001-zportalno,
          idnrk     TYPE ztcx0001-idnrk,
          qq        TYPE ztcx0001-qq,
          qq_seq    TYPE ztcx0001-qq_seq,
          vbeln     TYPE ztcx0001-vbeln,
          posnr     TYPE ztcx0001-posnr,
          menge     TYPE ztcx0026-menge,
          erdat     TYPE ztcx0001-erdat,
          audat_0   TYPE ztsd0028-audat,
          audat     TYPE ztsd0028-audat,
        END OF ty_ztcx0001.
  DATA:lt_ztcx0001      TYPE TABLE OF ty_ztcx0001,
       lt_ztcx0001_copy TYPE TABLE OF ty_ztcx0001.
  DATA:lv_zqty  TYPE ztsd0100-zqty,
       lv_menge TYPE ztcx0026-menge.
  DATA:lv_exist TYPE c.
  CLEAR:gt_alv.
  SELECT
    a~werks,
    a~zxqno,
    a~zxqseq,
    a~zym,
    a~zperiod,
    a~zseq AS zseq_xq,
    a~zqty,
    a~zptyp,
    b~vtweg,
    b~zxqdat,
    c~zpno,
    c~zup,
    c~zup_per
    INTO TABLE @DATA(lt_ztsd0100)
    FROM ztsd0100 AS a
    JOIN ztsd0098 AS b ON b~werks = a~werks AND b~zxqno = a~zxqno
    JOIN ztsd0099 AS c ON c~werks = a~werks AND c~zxqno = a~zxqno AND c~zxqseq = a~zxqseq
    WHERE b~vtweg IN @s_vtweg
    AND c~zpno IN @s_zpno
    AND a~zym >= '202506'
    AND a~zqty > 0.
  SORT lt_ztsd0100 BY vtweg zpno zxqdat zptyp zym zxqno zxqseq zseq_xq.

  IF  lt_ztsd0100 IS NOT INITIAL.
    CLEAR:lt_ztcx0001,lt_ztcx0001_copy.
    SELECT DISTINCT
      a~werks,
      a~vtweg,
      a~zseq,
      a~zportalno,
      a~idnrk,
      a~qq,
      a~qq_seq,
      a~vbeln,
      a~posnr,
      CASE WHEN a~beskz IS INITIAL THEN a~menge ELSE a~moq_confirm END AS menge,
      a~erdat,
      b~zapropd AS audat_0,  ""第0版確認日期
      CASE WHEN a~erdat >= b~zapropd THEN a~erdat ELSE b~zapropd END AS audat
      FROM ztcx0001 AS a
      JOIN ztsd0028 AS b ON a~vbeln = b~vbeln AND b~zvsnmr_v = '000'
      JOIN @lt_ztsd0100 AS c ON a~vtweg = c~vtweg AND a~idnrk = c~zpno
      WHERE a~loekz = ''
      AND a~qq_status <> 'C'
      AND ( CASE WHEN a~beskz IS INITIAL THEN a~menge ELSE a~moq_confirm END ) > 0
      AND ( CASE WHEN a~erdat >= b~zapropd THEN a~erdat ELSE b~zapropd END ) <= @s_audat-low
      INTO TABLE @lt_ztcx0001.
    SORT lt_ztcx0001 BY vtweg idnrk audat.
    MOVE-CORRESPONDING lt_ztcx0001 TO lt_ztcx0001_copy.
    SORT lt_ztcx0001_copy BY werks vtweg zseq zportalno idnrk.

    LOOP AT lt_ztsd0100 INTO DATA(ls_ztsd0100).
      CLEAR:lv_zqty,lv_exist.
      lv_zqty =  ls_ztsd0100-zqty.
      LOOP AT lt_ztcx0001 ASSIGNING FIELD-SYMBOL(<fs_ztcx0001>) WHERE vtweg = ls_ztsd0100-vtweg AND idnrk = ls_ztsd0100-zpno AND audat >= ls_ztsd0100-zxqdat .
        lv_exist = 'X'.
        CLEAR:lv_menge.
        lv_menge = <fs_ztcx0001>-menge.
        CLEAR:gs_alv.
        MOVE-CORRESPONDING ls_ztsd0100 TO gs_alv.
        gs_alv-zportalno   =    <fs_ztcx0001>-zportalno.
        gs_alv-zseq    =     <fs_ztcx0001>-zseq.
        gs_alv-qq   =     <fs_ztcx0001>-qq.
        gs_alv-qq_seq   =     <fs_ztcx0001>-qq_seq.
        gs_alv-vbeln   =     <fs_ztcx0001>-vbeln.
        gs_alv-posnr   =     <fs_ztcx0001>-posnr.
        gs_alv-audat   =    <fs_ztcx0001>-audat.
        READ TABLE lt_ztcx0001_copy INTO DATA(ls_ztcx0001_copy) WITH KEY werks = <fs_ztcx0001>-werks vtweg = <fs_ztcx0001>-vtweg zseq = <fs_ztcx0001>-zseq zportalno = <fs_ztcx0001>-zportalno idnrk = <fs_ztcx0001>-idnrk BINARY SEARCH.
        IF sy-subrc = 0 .
          gs_alv-menge   =     ls_ztcx0001_copy-menge.
          CLEAR:ls_ztcx0001_copy.
        ENDIF.
        IF lv_zqty >= lv_menge.
          gs_alv-zquan = lv_menge.
        ELSE.
          gs_alv-zquan = lv_zqty.
        ENDIF.
        lv_zqty = lv_zqty - gs_alv-zquan.
        lv_menge =  lv_menge - gs_alv-zquan.
        gs_alv-zqty_sy =  lv_zqty.
        gs_alv-menge_sy =  lv_menge.
        IF lv_menge <= 0 .
          DELETE lt_ztcx0001.
        ELSE.
          <fs_ztcx0001>-menge = lv_menge.
        ENDIF.
        IF gs_alv-zup_per <> 0.
          gs_alv-zprice = ( gs_alv-zup / gs_alv-zup_per ) * gs_alv-zqty_sy.
        ENDIF.
        APPEND gs_alv TO gt_alv.
        IF lv_zqty <= 0.
          EXIT.
        ENDIF.
      ENDLOOP.

      IF lv_exist = ''.
        CLEAR:gs_alv.
        MOVE-CORRESPONDING ls_ztsd0100 TO gs_alv.
        gs_alv-zqty_sy =  gs_alv-zqty.
        IF gs_alv-zup_per <> 0.
          gs_alv-zprice = ( gs_alv-zup / gs_alv-zup_per ) * gs_alv-zqty_sy.
        ENDIF.
        APPEND gs_alv TO gt_alv.
      ELSEIF lv_exist = 'X' AND lv_zqty > 0.
        CLEAR:gs_alv.
        MOVE-CORRESPONDING ls_ztsd0100 TO gs_alv.
        gs_alv-zqty_sy =  lv_zqty.
        IF gs_alv-zup_per <> 0.
          gs_alv-zprice = ( gs_alv-zup / gs_alv-zup_per ) * gs_alv-zqty_sy.
        ENDIF.
        APPEND gs_alv TO gt_alv.
      ENDIF.
      CLEAR:ls_ztsd0100,gs_alv.
    ENDLOOP.

  ENDIF.


*  IF gt_alv IS INITIAL.
*    MESSAGE  TEXT-002  TYPE 'S' DISPLAY LIKE 'E'.   "未獲取到數據！
*    LEAVE LIST-PROCESSING.
*  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form FRM_SET_FIELDCAT
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM frm_set_fieldcat.
  REFRESH gt_fieldcat.
  PERFORM frm_set_fieldcat_line USING 'VTWEG'   '配銷通路'  'ZTSD0098'  'VTWEG' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'ZPNO'   '預採件號'  'ZTSD0099'  'ZPNO' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'ZXQDAT'   'XQ單產生日期'  'ZTSD0098'  'ZXQDAT' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'ZXQNO'   'XQ單號'  'ZTSD0100'  'ZXQNO' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'ZXQSEQ'   'XQ單序號'  'ZTSD0100'  'ZXQSEQ' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'ZYM'   'XQ單轉出年月'  'ZTSD0100'  'ZYM' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'ZSEQ_XQ'   'XQ單轉出序號'  'ZTSD0100'  'ZSEQ' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'ZUP'   'XQ單業務單價'  'ZTSD0099'  'ZUP' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'ZUP_PER'   '業務單價定價單位'  'ZTSD0099'  'ZUP_PER' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'ZPTYP'   'XQ單轉出類別'  'ZTSD0100'  'ZPTYP' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'ZQTY'   'XQ單轉出數量'  'ZTSD0100'  'ZQTY' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'ZPRICE'   '超轉出金額'  'ZTSD0099'  'ZUP' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'ZQTY_SY'   '剩餘XQ'  'ZTCX0026'  'ZQTY_SY' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'ZQUAN'   '正確轉出數量'  'ZTCX0026'  'ZQUAN' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'MENGE_SY'   '剩餘IQ'  'ZTCX0026'  'MENGE_SY' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'ZPORTALNO'   '詢單單號'  'ZTCX0001'  'ZPORTALNO' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'ZSEQ'   '帳本編號'  'ZTCX0001'  'ZSEQ' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'QQ'   'QQ單號'  'ZTCX0001'  'QQ' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'QQ_SEQ'   'QQ單序號'  'ZTCX0001'  'QQ_SEQ' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'VBELN'   '銷售文件'  'ZTCX0001'  'VBELN' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'POSNR'   '銷售文件項目'  'ZTCX0001'  'POSNR' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'AUDAT'   '轉正確認日期'  'ZTSD0028'  'AUDAT' ''  ''.
  PERFORM frm_set_fieldcat_line USING 'MENGE'   '轉正數量'  'ZTCX0026'  'MENGE' ''  ''.
ENDFORM.
*&---------------------------------------------------------------------*
*&FRM_SET_FIELDCAT_LINE
*&---------------------------------------------------------------------*
FORM frm_set_fieldcat_line USING pv_name TYPE char100
                                 pv_title TYPE char100
                                 pv_table TYPE char30
                                 pv_field TYPE char30
                                 pv_zero TYPE char1
                                 pv_hotspot TYPE char1.
  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = pv_name."數據字段
  gs_fieldcat-coltext = pv_title.       "字段描述
  gs_fieldcat-ref_table = pv_table.
  gs_fieldcat-ref_field = pv_field.
  gs_fieldcat-no_zero = pv_zero.
  gs_fieldcat-hotspot = pv_hotspot.
  APPEND gs_fieldcat TO gt_fieldcat.
ENDFORM. " frm_set_fieldcat_line
*&---------------------------------------------------------------------*
*& Form FRM_SET_LAYOUT
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM frm_set_layout .
  "ALV界面格式
  CLEAR gs_layout.
  gs_layout-box_fname  = 'CHECK'. "選擇行控制
  gs_layout-sel_mode = 'A'.       "設置行模式
  gs_layout-cwidth_opt = 'X'.     "優化列寬設置
  gs_layout-zebra = 'X'.          "設置斑馬綫
ENDFORM.
*&---------------------------------------------------------------------*
*& Form FRM_DISPLAY_ALV
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM frm_display_alv.
  "報表展示
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
      i_callback_program = sy-repid
*     i_callback_pf_status_set = 'SET_PF_STATUS '
*     i_callback_user_command  = 'ALV_USER_COMMAND '
      is_layout_lvc      = gs_layout      "界面格式
      it_fieldcat_lvc    = gt_fieldcat    "字段屬性
      i_save             = 'A'
*   IMPORTING
*     E_EXIT_CAUSED_BY_CALLER  =
*     ES_EXIT_CAUSED_BY_USER   =
    TABLES
      t_outtab           = gt_alv
    EXCEPTIONS
      program_error      = 1
      OTHERS             = 2.
ENDFORM.