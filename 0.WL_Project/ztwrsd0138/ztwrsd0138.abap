*&==================================================================*
* Modification Log - History
*&==================================================================*
* DATE        VERSION   AUTHOR          DESCRIPTION
* ========== ========  ===========  =================================
* 2021/05/07  V001     yinglung     SAPERP-1401:ODM-預採帳增加整批匯入功能
* 2021/06/28  V002     yinglung     SAPERP-1491:ODM-整批匯入單價部分未產生
* 2021/09/22  V003     Tristan      增加下載Template功能
* 2022/07/25  V004     Kiwi         單位用量放大位數
* 2022/07/26  V005     Kiwi         ALV 點擊會dump
* 2023/10/31  V006     CaroL        調整預採帳客戶檢查方式
* 2026/06/11  V007     Tristan      上傳檔案新增欄位
*&---------------------------------------------------------------------*

REPORT ztwrsd0138 MESSAGE-ID zodmsd01.


DATA:   bdcdata LIKE bdcdata    OCCURS 0 WITH HEADER LINE.
DATA:   messtab LIKE bdcmsgcoll OCCURS 0 WITH HEADER LINE.
DATA:   e_message LIKE TABLE OF bapiret2 WITH HEADER LINE.
* ALV Variables
DATA: gs_layout_alv   TYPE slis_layout_alv,
      gt_fieldcat     TYPE slis_fieldcat_alv OCCURS 0,
      gt_events       TYPE slis_alv_event    OCCURS 0,
      gt_sortinfo_alv TYPE slis_sortinfo_alv OCCURS 0.
DATA: g_col TYPE i VALUE 0.
DATA: gt_alsm   LIKE alsmex_tabline OCCURS 0 WITH HEADER LINE.
DATA: g_err TYPE c.
DATA: BEGIN OF it_xq0098 OCCURS 0,
        werks     LIKE ztsd0098-werks,
        vtweg     LIKE ztsd0098-vtweg,
        zbcust    LIKE ztsd0098-zbcust,
        zscust    LIKE ztsd0098-zscust,
        zxqdat    LIKE ztsd0098-zxqdat,
        zxqline   LIKE ztsd0098-zxqline,
        zxqtyp    LIKE ztsd0098-zxqtyp,
        zunptyp   LIKE ztsd0098-zunptyp,
        zcpno     LIKE ztsd0098-zcpno,
        zcpnocn   LIKE ztsd0098-zcpnocn,
        zdesc     LIKE ztsd0098-zdesc,
        zrem1     LIKE ztsd0098-zrem1,
        zxqno     LIKE ztsd0098-zxqno,
        zmsg(100),
      END OF it_xq0098.

DATA: BEGIN OF it_xq0099 OCCURS 0,
        werks       LIKE ztsd0098-werks,
        vtweg       LIKE ztsd0098-vtweg,
        zbcust      LIKE ztsd0098-zbcust,
        zscust      LIKE ztsd0098-zscust,
        zxqdat      LIKE ztsd0098-zxqdat,
        zxqline     LIKE ztsd0098-zxqline,
        zxqtyp      LIKE ztsd0098-zxqtyp,
        zunptyp     LIKE ztsd0098-zunptyp,
        zcpno       LIKE ztsd0098-zcpno,
        zcpnocn     LIKE ztsd0098-zcpnocn,
        zdesc       LIKE ztsd0098-zdesc,
        zrem1       LIKE ztsd0098-zrem1,
        zpno        LIKE ztsd0099-zpno,
        zspno       LIKE ztsd0099-zspno,
        ztunyn      LIKE ztsd0099-ztunyn,
        zxqdtyp     LIKE ztsd0099-zxqdtyp,
        zqty(15),
* 2022/07/25  V004 Begin
*        zunit(6),
        zunit(10),
* 2022/07/25  V004 End
        zpcur       LIKE ztsd0099-zpcur,
        zdispup(15),
        zrem        LIKE ztsd0099-zrem,
        zpup        LIKE ztsd0099-zpup,
        zpup_per    LIKE ztsd0099-zpup_per,
        zxqno       LIKE ztsd0099-zxqno,
        zxqmsg(100),
      END OF it_xq0099.

* V003 Added by Tristan 2021/09/22 *
DATA: it_dd03l LIKE dd03l OCCURS 0 WITH HEADER LINE,
      it_dd03t LIKE dd03t OCCURS 0 WITH HEADER LINE,
      it_dd03m LIKE dd03m OCCURS 0 WITH HEADER LINE.
FIELD-SYMBOLS:<dyn_table> TYPE STANDARD TABLE,
              <dyn_wa>,
              <dyn_field>.
DATA: dy_table TYPE REF TO data,
      dy_line  TYPE REF TO data,
      wa_fcat  TYPE lvc_s_fcat,
      it_fcat  TYPE lvc_t_fcat,
      lt_fcat  TYPE lvc_t_fcat.
* V003 End off *
START-OF-SELECTION.
* V003 Added by Tristan 2021/09/22 *
  SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME.
    PARAMETERS: p_upload RADIOBUTTON GROUP gp1 DEFAULT 'X' USER-COMMAND ucomm,
                p_downld RADIOBUTTON GROUP gp1.
  SELECTION-SCREEN END OF BLOCK b2.
* V003 End off *
  SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
    PARAMETERS: p_file TYPE rlgrap-filename MODIF ID crt DEFAULT 'C:\temp\ZXQ07_template.xls'.
  SELECTION-SCREEN END OF BLOCK b01.

*V006 ATC調整
*AT SELECTION-SCREEN.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM get_file_location CHANGING p_file.

START-OF-SELECTION.
  CASE 'X'.
    WHEN p_upload.
      g_err = ''.
      PERFORM alsm_excel_to_internal_table.
      PERFORM checkdata.
      IF g_err EQ ''.
        PERFORM createxq.
      ENDIF.
      PERFORM disp_alv.
* V003 Added by Tristan 2021/09/22 *
    WHEN p_downld.
      PERFORM download_template.
* V003 End off *
  ENDCASE.
  "FREE OBJECT GT_ALSM.

*V006 ATC調整
*END-OF-SELECTION.

FORM checkdata.
  DATA: l_cntCust TYPE i.   "V006
  DATA: l_cnt TYPE i.
  DATA: l_domaintext TYPE c LENGTH 30.
  DATA: l_err TYPE c.
  DATA: l_str TYPE string.
  DATA: l_dtype LIKE dd01v-datatype.
  DATA: l_val LIKE cats_its_fields-num_value.
  g_err = ''.
  LOOP AT it_xq0099.
    l_err = ''.
    IF it_xq0099-vtweg EQ ''.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '未輸入配銷通路！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    "" IF it_xq0099-vtweg NE 'WL' AND it_xq0099-vtweg NE 'BP'.
    ""   g_err = 'X'.
    ""   l_err = 'X'.
    ""   it_xq0099-zxqmsg = '無此配銷通路！'.
    ""   MODIFY it_xq0099.
    ""   CONTINUE.
    "" ENDIF.

    IF it_xq0099-zbcust EQ ''.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '未輸客戶別！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.
*2023/10/31  V006    CaroL       調整預採帳客戶檢查方式
*    IF it_xq0099-zbcust NE 'GA01' AND it_xq0099-zbcust NE 'B01' AND
*      it_xq0099-zbcust NE 'C01' AND it_xq0099-zbcust NE 'J01' AND
*      it_xq0099-zbcust NE 'N01'   .
    SELECT COUNT(*) INTO l_cntCust FROM ztsd0088
    WHERE vtweg EQ it_xq0099-vtweg AND
         zbcust EQ it_xq0099-zbcust .
    IF l_cntCust EQ 0.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '無此客戶別！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    IF it_xq0099-zcpno EQ ''.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '未輸入客戶件號！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    IF it_xq0099-zcpnocn EQ ''.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '未輸入對應型號！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    IF it_xq0099-zxqdat EQ '' OR it_xq0099-zxqdat EQ '00000000'.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '未輸入產生日期！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
      EXPORTING
        date                      = it_xq0099-zxqdat
      EXCEPTIONS
        plausibility_check_failed = 1
        OTHERS                    = 2.
    IF sy-subrc NE 0.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '日期錯誤！'.
      MODIFY it_xq0099.
      CONTINUE.
    ELSE.

      SELECT COUNT(*) INTO l_cnt FROM ztsd0088
      WHERE vtweg  EQ it_xq0099-vtweg AND
            zbcust EQ it_xq0099-zbcust AND
      zsdat LE it_xq0099-zxqdat AND
      zedat GE it_xq0099-zxqdat.
      IF l_cnt EQ 0.
        g_err = 'X'.
        l_err = 'X'.
        it_xq0099-zxqmsg = '日期不存在預採帳區間！'.
        MODIFY it_xq0099.
        CONTINUE.
      ENDIF.
    ENDIF.

    IF it_xq0099-zxqline EQ ''.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '未輸入線別！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    PERFORM get_domain_value USING 'ZMOQLINE' it_xq0099-zxqline
              CHANGING l_domaintext.
    IF l_domaintext EQ 'UNKNOW'.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '無此線別！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.


    IF it_xq0099-zxqtyp EQ ''.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '未輸入大分類！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    SELECT COUNT(*) INTO l_cnt FROM ztsd0112
    WHERE vtweg EQ it_xq0099-vtweg AND
    zxqtyp EQ it_xq0099-zxqtyp.
    IF l_cnt EQ 0.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '無此大分類！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    IF it_xq0099-zunptyp EQ ''.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '未輸入UNPAY排序！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    SELECT COUNT(*) INTO l_cnt FROM ztsd0113
    WHERE vtweg EQ it_xq0099-vtweg AND
    zunptyp EQ it_xq0099-zunptyp.
    IF l_cnt EQ 0.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '無此UNPAY排序！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    IF it_xq0099-zpno EQ ''.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '未輸入料號！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    "" SELECT COUNT(*) INTO l_cnt FROM ztsd0130
    "" WHERE zauthorg EQ it_xq0099-zauthorg AND zpno EQ it_xq0099-zpno.
    "" IF l_cnt EQ 0.
    ""   g_err = 'X'.
    ""   l_err = 'X'.
    ""   it_xq0099-zxqmsg = '無此料號！'.
    ""   MODIFY it_xq0099.
    ""   CONTINUE.
    "" ENDIF.

    SELECT COUNT(*) INTO l_cnt FROM ztmara
    WHERE matnr EQ it_xq0099-zpno.
    IF l_cnt EQ 0.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '無此料號！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    IF it_xq0099-zspno NE ''.
      "" SELECT COUNT(*) INTO l_cnt FROM ztsd0130
      "" WHERE zauthorg EQ it_xq0099-zauthorg AND zpno EQ it_xq0099-zspno.
      SELECT COUNT(*) INTO l_cnt FROM ztmara
    WHERE matnr EQ it_xq0099-zspno.
      IF l_cnt EQ 0.
        g_err = 'X'.
        l_err = 'X'.
        it_xq0099-zxqmsg = '無此視同料號！'.
        MODIFY it_xq0099.
        CONTINUE.
      ENDIF.
    ENDIF.

    IF it_xq0099-zxqdtyp EQ ''.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '未輸入預採帳小分類！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    SELECT COUNT(*) INTO l_cnt FROM ztsd0111
    WHERE zxqdtyp EQ it_xq0099-zxqdtyp.
    " AND ZENTITY EQ IT_XQ0099-ZAUTHORG.
    IF l_cnt EQ 0.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '無此預採帳小分類！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    IF it_xq0099-zqty EQ '' OR it_xq0099-zqty IS INITIAL.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '未輸入數量！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    CALL FUNCTION 'CATS_ITS_MAKE_STRING_NUMERICAL'
      EXPORTING
        input_string  = it_xq0099-zqty
      IMPORTING
        value         = l_val
      EXCEPTIONS
        not_numerical = 1
        OTHERS        = 2.

    IF sy-subrc <> 0.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '數量需為數字格式！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    IF it_xq0099-zunit EQ '' OR it_xq0099-zunit IS INITIAL.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '未輸入單位用量！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.

    CALL FUNCTION 'CATS_ITS_MAKE_STRING_NUMERICAL'
      EXPORTING
        input_string  = it_xq0099-zunit
      IMPORTING
        value         = l_val
      EXCEPTIONS
        not_numerical = 1
        OTHERS        = 2.

    IF sy-subrc <> 0.
      g_err = 'X'.
      l_err = 'X'.
      it_xq0099-zxqmsg = '單位用量需為數字格式！'.
      MODIFY it_xq0099.
      CONTINUE.
    ENDIF.
    IF it_xq0099-zdispup NE '' AND it_xq0099-zdispup IS NOT INITIAL.

      CALL FUNCTION 'CATS_ITS_MAKE_STRING_NUMERICAL'
        EXPORTING
          input_string  = it_xq0099-zdispup
        IMPORTING
          value         = l_val
        EXCEPTIONS
          not_numerical = 1
          OTHERS        = 2.

      IF sy-subrc <> 0.
        g_err = 'X'.
        l_err = 'X'.
        it_xq0099-zxqmsg = '採購單價需為數字格式！'.
        MODIFY it_xq0099.
        CONTINUE.
      ENDIF.

      IF it_xq0099-zpcur EQ '' .
        g_err = 'X'.
        l_err = 'X'.
        it_xq0099-zxqmsg = '未輸入採購幣別！'.
        MODIFY it_xq0099.
        CONTINUE.
      ENDIF.

      IF it_xq0099-zpcur NE 'TWD' AND it_xq0099-zpcur NE 'CNY' AND
        it_xq0099-zpcur NE 'USD' AND it_xq0099-zpcur NE 'HKD' AND
        it_xq0099-zpcur NE 'EUR'.
        g_err = 'X'.
        l_err = 'X'.
        it_xq0099-zxqmsg = '無此預採帳採購幣別 ( 僅可輸入 TWD / CNY / USD / HKD / EUR )！'.
        MODIFY it_xq0099.
        CONTINUE.
      ENDIF.

      PERFORM convert_price USING it_xq0099-zpcur
                                  it_xq0099-zdispup  "原採購單價
                         CHANGING it_xq0099-zpup
                                  it_xq0099-zpup_per.

      MODIFY it_xq0099.
    ENDIF.

  ENDLOOP.

ENDFORM.


FORM convert_price  USING    p_waers
                             p_pup
                    CHANGING p_zpup
                             p_zpup_per.
*  DATA: L_CURRDEC TYPE CURRDEC. "小數位數
*  IF P_WAERS <> ''.
*    SELECT SINGLE CURRDEC FROM TCURX INTO L_CURRDEC
*                  WHERE CURRKEY = P_WAERS.
*    IF SY-SUBRC <> 0.
*      L_CURRDEC = 2.
*    ENDIF.
*  ENDIF.
*  IF P_PUP = 0.
*    L_CURRDEC = 6.
*  ENDIF.
*  CASE L_CURRDEC.
*    WHEN 0.
*      P_ZPUP_PER = 1000000.
*    WHEN 1.
*      P_ZPUP_PER = 100000.
*    WHEN 2.
*      P_ZPUP_PER = 10000.
*    WHEN 3.
*      P_ZPUP_PER = 1000.
*    WHEN 4.
*      P_ZPUP_PER = 100.
*    WHEN 5.
*      P_ZPUP_PER = 10.
*    WHEN 6.
*      P_ZPUP_PER = 1.
*  ENDCASE.
*  IF P_PUP <> 0.
*    P_ZPUP = P_PUP * P_ZPUP_PER.
*  ENDIF.
*判斷小數點位數
  DATA: l_p TYPE p DECIMALS 9,
        l_i TYPE i.
  DATA: l_v TYPE p DECIMALS 9. "20210628 yinglung V002
  l_v = p_pup. "20210628 yinglung V002
  l_p = frac( p_pup ).
  CLEAR l_i.
  DO 10 TIMES.
    IF l_p > 1 OR l_p = 0.
      EXIT.
    ENDIF.
    l_i = l_i + 1.
    l_p = l_p * 10.
    l_p = frac( l_p ).
  ENDDO.
  p_zpup_per = 10 ** l_i.

  "20210628 yinglung V002 begin
*  CHECK p_pup NE 0.
*  IF p_pup <> 0.
*    p_zpup = p_pup * p_zpup_per.
*  ENDIF.
  CHECK l_v NE 0.
  IF l_v <> 0.
    p_zpup = l_v * p_zpup_per.
  ENDIF.
  "20210628 yinglung V002 end

*將外部傳入金額轉成內部值
  DATA l_factor TYPE isoc_factor.
  CALL FUNCTION 'CURRENCY_CONVERTING_FACTOR'
    EXPORTING
      currency          = p_waers
    IMPORTING
      factor            = l_factor
    EXCEPTIONS
      too_many_decimals = 1
      OTHERS            = 2.
  IF sy-subrc <> 0.
    l_factor = 1.
  ENDIF.
**如果是1,代表金額可到小數下兩位
  IF l_factor = 1.
    IF p_zpup_per < 100.
      IF l_factor NE 0.  "V006
        p_zpup = p_zpup / l_factor.
      ENDIF.
    ELSE.
      p_zpup_per = p_zpup_per / 100.
      IF l_factor NE 0.  "V006
        p_zpup = ( p_zpup / l_factor ) / 100.
      ENDIF.
    ENDIF.
  ELSE.
    IF l_factor NE 0.  "V006
      p_zpup = p_zpup / l_factor.
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  GET_DOMAIN_VALUE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_<ITAB>_WBSTK  text
*      <--P_<ITAB>_WBSTK_TEXT  text
*----------------------------------------------------------------------*
FORM get_domain_value  USING    p_domain p_value
                       CHANGING p_text.
  DATA: i_domname  LIKE  dd07v-domname,
        i_domvalue LIKE  dd07v-domvalue_l,
        e_ddtext   LIKE  dd07v-ddtext.

  i_domname  = p_domain.
  i_domvalue = p_value.
  CLEAR e_ddtext.
  CALL FUNCTION 'DOMAIN_VALUE_GET'
    EXPORTING
      i_domname  = i_domname
      i_domvalue = i_domvalue
    IMPORTING
      e_ddtext   = e_ddtext
    EXCEPTIONS
      not_exist  = 1
      OTHERS     = 2.
  IF sy-subrc <> 0.
    e_ddtext = 'UNKNOW'.
  ENDIF.
  p_text = e_ddtext.
ENDFORM.
"20210222 yinglung V010 end

FORM disp_alv .
  PERFORM build_filedcat.
  PERFORM build_layout.
  PERFORM list_display.
ENDFORM.

FORM build_filedcat .

  REFRESH gt_fieldcat.
  g_col = 0.
  "" PERFORM set_fields USING 'ZAUTHORG' '權限組織'      ''  ''.
  "" PERFORM set_fields USING 'ZBCUST'   '客戶別'        ''  ''.
  PERFORM set_fields USING 'WERKS'    '工廠'          ''  ''.
  PERFORM set_fields USING 'VTWEG'    '通路'          ''  ''.
  PERFORM set_fields USING 'ZSCUST'   '客戶'          ''  ''.
  PERFORM set_fields USING 'ZXQDAT'   '產生日期'      ''  ''.
  PERFORM set_fields USING 'ZXQLINE'  '線別'          ''  ''.
  PERFORM set_fields USING 'ZXQTYP'   '大分類'        ''  ''.
  PERFORM set_fields USING 'ZUNPTYP'  'UNPAY排序'     ''  ''.
  PERFORM set_fields USING 'ZCPNO'    '客戶件號'      ''  ''.
  PERFORM set_fields USING 'ZCPNOCN'  '對應型號'      ''  ''.
  PERFORM set_fields USING 'ZDESC'    '敘述'          ''  ''.
  PERFORM set_fields USING 'ZREM1'    '表頭備註1'          ''  ''.
  PERFORM set_fields USING 'ZPNO'     '預採件號'      ''  ''.
  PERFORM set_fields USING 'ZTUNYN'   '系統轉出'      ''  ''.
  PERFORM set_fields USING 'ZXQDTYP'  '預採帳小分類'  ''  ''.
  PERFORM set_fields USING 'ZQTY'     '數量'          ''  ''.
  PERFORM set_fields USING 'ZUNIT'    '單位用量'      ''  ''.
  PERFORM set_fields USING 'ZPCUR'    '採購幣別'      ''  ''.
  PERFORM set_fields USING 'ZDISPUP'  '採購單價'      ''  ''.
  PERFORM set_fields USING 'ZREM'     '明細備註'          ''  ''.
  PERFORM set_fields USING 'ZXQNO'    'XQ單號'        ''  ''.
  PERFORM set_fields USING 'ZXQMSG'   '處理訊息'      ''  ''.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  SET_FIELDS
*&---------------------------------------------------------------------*
*       Setup Column Attributes
*----------------------------------------------------------------------*
*      -->P_1   Column Name
*      -->P_2   Column Text Description(L)
*      -->P_3   Column Display or NOT (X)Display/( )Not Display
*      -->P_4   Column Alignment (R: Right / C: Center / L: Left)
*----------------------------------------------------------------------*
FORM set_fields  USING    p1
                          p2
                          p3
                          p4.

  DATA: ls_fieldcat     TYPE slis_fieldcat_alv.

  CLEAR ls_fieldcat.

* 欄位位置
  ADD 1 TO g_col .
  ls_fieldcat-col_pos   = g_col.

* 欄位名稱
  ls_fieldcat-fieldname = p1.

* 欄位說明內文(L)
  ls_fieldcat-seltext_l = p2.

* 欄位顯示與否
  ls_fieldcat-no_out    = p3.

* 對齊 (R:靠右 / C:置中 / L:靠左)
  ls_fieldcat-just      = p4.

  APPEND ls_fieldcat TO gt_fieldcat.
  CLEAR: ls_fieldcat.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  BUILD_LAYOUT
*&---------------------------------------------------------------------*
*       Setup Parameters
*----------------------------------------------------------------------*
FORM build_layout .

  gs_layout_alv-zebra                = 'X'.
  gs_layout_alv-colwidth_optimize    = 'X'.
  gs_layout_alv-detail_initial_lines = 'X'.
  gs_layout_alv-no_vline             = ''.
  gs_layout_alv-f2code               = '&IC1'.
  "(&IC1): double click / (&ETA): ALV item detail window.
  gs_layout_alv-detail_popup         = ''.

* ALV Variant
*  GS_VARIANT-REPORT = SY-REPID.

ENDFORM.

FORM list_display .

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program      = sy-cprog
*     I_CALLBACK_PF_STATUS_SET = 'SET_PF_STATUS'
      i_callback_user_command = 'USER_COMMAND'
      is_layout               = gs_layout_alv
      it_fieldcat             = gt_fieldcat[]
      i_save                  = 'A'
*     IS_VARIANT              = GS_VARIANT    "ALV VARIANT
      it_events               = gt_events
    TABLES
      t_outtab                = it_xq0099
    EXCEPTIONS
      program_error           = 1
      OTHERS                  = 2.

ENDFORM.

FORM createxq.
  DATA: l_pup TYPE c LENGTH 15.
  DATA: l_pup_per TYPE c LENGTH 7.
  LOOP AT it_xq0098.
    PERFORM bdc_dynpro      USING 'ZTWBSD0017' '6000'.
    PERFORM bdc_field       USING 'BDC_OKCODE'
                                  '/00'.
    PERFORM bdc_field       USING 'STSD98-VTWEG'
                                  it_xq0098-vtweg.
    PERFORM bdc_field       USING 'STSD98-WERKS'
                                  it_xq0098-werks.
    PERFORM bdc_field       USING 'STSD98-ZBCUST'
                                  it_xq0098-zbcust.
    PERFORM bdc_field       USING 'STSD98-ZXQDAT'
                                  it_xq0098-zxqdat.
    PERFORM bdc_field       USING 'STSD98-ZSCUST'
                                  it_xq0098-zscust.
    PERFORM bdc_dynpro      USING 'ZTWBSD0017' '6000'.
    PERFORM bdc_field       USING 'BDC_OKCODE'
                                  '/00'.
    PERFORM bdc_dynpro      USING 'ZTWBSD0017' '6000'.
    PERFORM bdc_field       USING 'BDC_OKCODE'
                                  '=CCTABS_FC2'.
    PERFORM bdc_dynpro      USING 'ZTWBSD0017' '6000'.
    PERFORM bdc_field       USING 'BDC_OKCODE'
                                  '/00'.
    PERFORM bdc_field       USING 'BDC_CURSOR'
                                  'STSD98-ZXQLINE'.
    PERFORM bdc_field       USING 'STSD98-ZXQLINE'
                                  it_xq0098-zxqline.
    PERFORM bdc_field       USING 'STSD98-ZCPNO'
                                  it_xq0098-zcpno.
    PERFORM bdc_field       USING 'STSD98-ZCPNOCN'
                                  it_xq0098-zcpnocn.
    PERFORM bdc_field       USING 'STSD98-ZXQTYP'
                                  it_xq0098-zxqtyp.
    PERFORM bdc_field       USING 'STSD98-ZUNPTYP'
                                  it_xq0098-zunptyp.
    PERFORM bdc_field       USING 'STSD98-ZDESC'
                                  it_xq0098-zdesc.
    PERFORM bdc_dynpro      USING 'ZTWBSD0017' '6000'.
    PERFORM bdc_field       USING 'BDC_OKCODE'
                                  '=CCTABS_FC3'.
    PERFORM bdc_dynpro      USING 'ZTWBSD0017' '6000'.
    PERFORM bdc_field       USING 'BDC_OKCODE'
                                  '/00'.
    PERFORM bdc_field       USING 'BDC_CURSOR'
                                  'STSD98-ZREM1'.
    PERFORM bdc_field       USING 'STSD98-ZREM1'
                                  it_xq0098-zrem1.
    PERFORM bdc_dynpro      USING 'ZTWBSD0017' '6000'.
    PERFORM bdc_field       USING 'BDC_OKCODE'
                                  '=CCTABS_FC1'.
    LOOP AT it_xq0099 WHERE vtweg EQ it_xq0098-vtweg AND
        zbcust EQ it_xq0098-zbcust AND
        zscust EQ it_xq0098-zscust AND
        zxqdat EQ it_xq0098-zxqdat AND
        zxqline EQ it_xq0098-zxqline AND
        zxqtyp EQ it_xq0098-zxqtyp AND
        zunptyp EQ it_xq0098-zunptyp AND
        zcpno EQ it_xq0098-zcpno AND
        zcpnocn EQ it_xq0098-zcpnocn AND
        zdesc EQ it_xq0098-zdesc AND
        zrem1 EQ it_xq0098-zrem1  .

      PERFORM bdc_dynpro      USING 'ZTWBSD0017' '6000'.
      PERFORM bdc_field       USING 'BDC_OKCODE'
                                    '=INST'.
      PERFORM bdc_dynpro      USING 'ZTWBSD0017' '6200'.
      PERFORM bdc_field       USING 'BDC_CURSOR'
                                    'STDATA-ZPNO'.
      PERFORM bdc_field       USING 'BDC_OKCODE'
                                     '/00'.
      PERFORM bdc_field       USING 'STDATA-ZPNO'
                                    it_xq0099-zpno.
      PERFORM bdc_dynpro      USING 'ZTWBSD0017' '6200'.
      PERFORM bdc_field       USING 'BDC_CURSOR'
                                    'STDATA-ZXQDTYP'.
      PERFORM bdc_field       USING 'BDC_OKCODE'
                                     '/00'.
      PERFORM bdc_field       USING 'STDATA-ZXQDTYP'
                                    it_xq0099-zxqdtyp.
      PERFORM bdc_field       USING 'STDATA-ZSPNO'
                                    it_xq0099-zspno.
      PERFORM bdc_dynpro      USING 'ZTWBSD0017' '6200'.
      PERFORM bdc_field       USING 'BDC_CURSOR'
                                    'STDATA-ZUNIT'.
      PERFORM bdc_field       USING 'BDC_OKCODE'
                                    '/00'.
      PERFORM bdc_dynpro      USING 'ZTWBSD0017' '6200'.
      PERFORM bdc_field       USING 'BDC_CURSOR'
                                    'STDATA-ZQTY'.
      PERFORM bdc_field       USING 'BDC_OKCODE'
                                    '/00'.
      PERFORM bdc_field       USING 'STDATA-ZQTY'
                                    it_xq0099-zqty.
      PERFORM bdc_dynpro      USING 'ZTWBSD0017' '6200'.
      PERFORM bdc_field       USING 'STDATA-ZBQTY'
                                    it_xq0099-zunit.
      PERFORM bdc_field       USING 'BDC_CURSOR'
                                    'STDATA-ZBQTY'.
      PERFORM bdc_field       USING 'STDATA-ZPCUR'
                                    it_xq0099-zpcur.
      l_pup = it_xq0099-zpup.
      l_pup_per = it_xq0099-zpup_per.
      PERFORM bdc_field       USING 'STDATA-ZPUP'
                                    l_pup.
      PERFORM bdc_field       USING 'STDATA-ZPUP_PER'
                                    l_pup_per.
      PERFORM bdc_field       USING 'BDC_OKCODE'
                                    '/00'.
      PERFORM bdc_field       USING 'STDATA-ZTUNYN'
                                    it_xq0099-ztunyn.
      PERFORM bdc_field       USING 'STDATA-ZREM'
                                    it_xq0099-zrem.

      PERFORM bdc_dynpro      USING 'ZTWBSD0017' '6200'.
      PERFORM bdc_field       USING 'BDC_CURSOR'
                                    'STDATA-ZPNO'.
      PERFORM bdc_field       USING 'BDC_OKCODE'
                                    '=BACK62'.
    ENDLOOP.
    PERFORM bdc_dynpro      USING 'ZTWBSD0017' '6000'.
    PERFORM bdc_field       USING 'BDC_OKCODE'
                                  '=SAVE'.
    PERFORM bdc_transaction USING 'ZXQ01' .

    REFRESH: e_message. CLEAR: e_message.
    READ TABLE messtab WITH KEY msgtyp = 'E'.
    IF sy-subrc = 0.
      ROLLBACK WORK.
      LOOP AT messtab WHERE msgtyp = 'E'.
        it_xq0098-zmsg = messtab-msgv1.
        MODIFY it_xq0098.
      ENDLOOP.
    ELSE.

      LOOP AT messtab WHERE msgtyp = 'I'.
        it_xq0098-zxqno = messtab-msgv3.
        MODIFY it_xq0098.
      ENDLOOP.
    ENDIF.

  ENDLOOP.

  LOOP AT it_xq0098.
    LOOP AT it_xq0099 WHERE
                      werks   EQ it_xq0098-werks   AND
                      vtweg   EQ it_xq0098-vtweg   AND
                      zbcust  EQ it_xq0098-zbcust  AND
                      zscust  EQ it_xq0098-zscust  AND
                      zxqdat  EQ it_xq0098-zxqdat  AND
                      zxqline EQ it_xq0098-zxqline AND
                      zxqtyp  EQ it_xq0098-zxqtyp  AND
                      zunptyp EQ it_xq0098-zunptyp AND
                      zcpno   EQ it_xq0098-zcpno   AND
                      zcpnocn EQ it_xq0098-zcpnocn AND
                      zdesc   EQ it_xq0098-zdesc   AND
                      zrem1   EQ it_xq0098-zrem1 .
      it_xq0099-zxqno = it_xq0098-zxqno.
      it_xq0099-zxqmsg  = it_xq0098-zmsg.
      MODIFY it_xq0099.
    ENDLOOP.
  ENDLOOP.

ENDFORM.

FORM bdc_dynpro USING program dynpro.
  CLEAR bdcdata.
  bdcdata-program  = program.
  bdcdata-dynpro   = dynpro.
  bdcdata-dynbegin = 'X'.
  APPEND bdcdata.
ENDFORM.

FORM bdc_field USING fnam fval.
*  IF FVAL <> NODATA.
  CLEAR bdcdata.
  bdcdata-fnam = fnam.
  bdcdata-fval = fval.
  APPEND bdcdata.
*  ENDIF.
ENDFORM.

FORM bdc_transaction USING tcode .
  DATA: ctu_parameters TYPE ctu_params.
  ctu_parameters-dismode = 'N'.
  ctu_parameters-updmode = 'L'.
  ctu_parameters-racommit = 'X'. "No abortion by COMMIT WORK
* call transaction using
*測試可開此組設定
*  CTU_PARAMETERS-DISMODE = 'A'.
*  CTU_PARAMETERS-UPDMODE = 'L'.
*  CTU_PARAMETERS-RACOMMIT = ''. "No abortion by COMMIT WORK

  REFRESH messtab.
  CLEAR: messtab.
  CALL TRANSACTION tcode USING bdcdata
                   OPTIONS FROM ctu_parameters
                   MESSAGES INTO messtab.

  REFRESH bdcdata.
ENDFORM.

FORM get_file_location  CHANGING p_file.

  CALL FUNCTION 'KD_GET_FILENAME_ON_F4'
*   EXPORTING
*     PROGRAM_NAME        = SYST-REPID
*     DYNPRO_NUMBER       = SYST-DYNNR
*     FIELD_NAME          = ' '
*     STATIC              = ' '
*     MASK                = ' '
*     FILEOPERATION       = 'R'
*     PATH                =
    CHANGING
      file_name     = p_file
*     LOCATION_FLAG = 'P'
    EXCEPTIONS
      mask_too_long = 1
      OTHERS        = 2.

  CASE sy-subrc.
    WHEN 1.
      MESSAGE s398(00) WITH 'File Path too long!'.
      STOP.
    WHEN 2.
      MESSAGE s398(00) WITH 'File Path reading error!'.
      STOP.
  ENDCASE.

ENDFORM.

FORM alsm_excel_to_internal_table .

  DATA: l_index TYPE i.
  FIELD-SYMBOLS: <fs>.

  CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
    EXPORTING
      filename                = p_file
      i_begin_col             = 1
      i_begin_row             = 3
* V007 Changed by Tristan 2026/06/11 *
*      i_end_col               = 20
      i_end_col               = 21
* V007 End off *
      i_end_row               = 65535
    TABLES
      intern                  = gt_alsm
    EXCEPTIONS
      inconsistent_parameters = 1
      upload_ole              = 2
      OTHERS                  = 3.

  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.


  IF gt_alsm[] IS INITIAL.
    MESSAGE s398(00) WITH 'File is empty!'.
    STOP.
  ENDIF.

  LOOP AT gt_alsm.
    MOVE gt_alsm-col TO l_index.
    ASSIGN COMPONENT l_index OF STRUCTURE it_xq0099 TO <fs>.
    MOVE gt_alsm-value TO <fs>.
    AT END OF row.
      APPEND it_xq0099. CLEAR it_xq0099.
    ENDAT.
  ENDLOOP.

  LOOP AT it_xq0099.
    it_xq0098-vtweg    = it_xq0099-vtweg.
    it_xq0098-werks    = it_xq0099-werks.
    it_xq0098-zbcust   = it_xq0099-zbcust.
    it_xq0098-zscust   = it_xq0099-zscust.
    it_xq0098-zxqdat   = it_xq0099-zxqdat.
    it_xq0098-zxqline  = it_xq0099-zxqline.
    it_xq0098-zxqtyp   = it_xq0099-zxqtyp.
    it_xq0098-zunptyp  = it_xq0099-zunptyp.
    it_xq0098-zcpno    = it_xq0099-zcpno.
    it_xq0098-zcpnocn  = it_xq0099-zcpnocn.
    it_xq0098-zdesc    = it_xq0099-zdesc.
    it_xq0098-zrem1    = it_xq0099-zrem1.
    COLLECT it_xq0098.

    IF it_xq0099-ztunyn EQ 'Y' OR it_xq0099-ztunyn = 'y'.
      it_xq0099-ztunyn = 'X'.
    ELSE.
      it_xq0099-ztunyn = ''.
    ENDIF.
    MODIFY it_xq0099.
  ENDLOOP.



ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  DOWNLOAD_TEMPLATE
*&---------------------------------------------------------------------*
FORM download_template .
  DATA: g_fldnam(20).
  FIELD-SYMBOLS: <fs_value>, <fs_field>.
** Table Schema
*  PERFORM get_table_schema.
  PERFORM assign_field_catalog.
* Create dynamic internal table and assign to FS
  CALL METHOD cl_alv_table_create=>create_dynamic_table
    EXPORTING
      it_fieldcatalog = it_fcat
    IMPORTING
      ep_table        = dy_table.
  ASSIGN dy_table->* TO <dyn_table>.
* Create dynamic work area and assign to FS
  CREATE DATA dy_line LIKE LINE OF <dyn_table>.
  ASSIGN dy_line->* TO <dyn_wa>.
* 新增加一行 因為上傳檔案是從第三筆讀起(含欄位說明)
  LOOP AT lt_fcat INTO wa_fcat.
    g_fldnam = '<dyn_wa>-' && wa_fcat-fieldname.
    ASSIGN (g_fldnam) TO <fs_field>.
    ASSIGN '必輸' TO <fs_value>.
    <fs_field> = <fs_value>.
    AT LAST.
      APPEND <dyn_wa> TO <dyn_table>.
    ENDAT.
  ENDLOOP.
* Field Description
  LOOP AT it_fcat INTO wa_fcat.
    g_fldnam = '<dyn_wa>-' && wa_fcat-fieldname.
    ASSIGN (g_fldnam) TO <fs_field>.
* Description
    READ TABLE gt_fieldcat INTO DATA(wa_fieldcat)
                           WITH KEY fieldname = wa_fcat-fieldname.
    ASSIGN wa_fieldcat-seltext_l TO <fs_value>.
    <fs_field> = <fs_value>.
    AT LAST.
      APPEND <dyn_wa> TO <dyn_table>.
    ENDAT.
  ENDLOOP.

  PERFORM gui_download TABLES <dyn_table>
                        USING p_file.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GUI_DOWNLOAD
*&---------------------------------------------------------------------*
FORM gui_download TABLES it_out
                  USING  i_filename.
* 如果要下載成EXCEL 所有的欄位屬性都要宣告成CHAR
  CALL FUNCTION 'SAP_CONVERT_TO_XLS_FORMAT'
    EXPORTING
      i_field_seperator = '#' "Field seprator in internal table
      i_line_header     = 'X'
      i_filename        = i_filename
    TABLES
      i_tab_sap_data    = it_out
    EXCEPTIONS
      conversion_failed = 1
      OTHERS            = 2.

  IF sy-subrc <> 0.
*    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    MESSAGE 'Template Download Fail' TYPE 'S' DISPLAY LIKE 'E'.
    LEAVE LIST-PROCESSING.
  ELSE.
    MESSAGE s000 WITH 'Template Download Successfully'.
    LEAVE LIST-PROCESSING.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  ASSIGN_FIELD_CATALOG
*&---------------------------------------------------------------------*
FORM assign_field_catalog .
  DATA: st_fieldcat TYPE slis_fieldcat_alv,
        wa_fieldcat LIKE st_fieldcat.
  RANGES: r_fieldname FOR st_fieldcat-fieldname.
  DEFINE assign_range_table.
    &1-sign = &2. &1-option = &3.
    &1-low  = &4. &1-high = &5.
    APPEND &1. CLEAR &1.
  END-OF-DEFINITION.
  DEFINE assign_fieldcat.
    wa_fieldcat-fieldname = &1.
    wa_fieldcat-seltext_s = wa_fieldcat-seltext_m =
    wa_fieldcat-seltext_l = &2.
    wa_fieldcat-datatype = 'C'.
    wa_fieldcat-inttype = 'C'.
    wa_fieldcat-intlen = 30.
    APPEND wa_fieldcat TO gt_fieldcat.
    MOVE-CORRESPONDING wa_fieldcat TO wa_fcat.
    APPEND wa_fcat TO it_fcat.
  END-OF-DEFINITION.
  assign_fieldcat: 'WERKS'    '工廠 (Ex. 1120)',  "" 'ZAUTHORG' '權限組織(WL/BP)',
                   'VTWEG'    '通路 (Ex. G1)',  "" 'ZBCUST'   '客戶別',
                   'ZBCUST'   '客戶別 (Ex. 0006100006)',
                   'ZSCUST'   '客戶 (Ex. 0006100006)',
                   'ZXQDAT'   '產生日期 (YYYYMMDD)',
                   'ZXQLINE'  '客戶線別',
                   'ZXQTYP'   '大分類',
                   'ZUNPTYP'  'UNPAY排序',
                   'ZCPNO'    '客戶件號(30)',
                   'ZCPNOCN'  '對應型號(30)',
                   'ZDESC'    '敘述',
                   'ZREM1'    '表頭備註1',
                   'ZPNO'     '預採件號',
                   'ZSPNO'    '視同件號',
                   'ZTUNYN'   '系統轉出否(Y)',
                   'ZXQDTYP'  '預採帳小分類',
                   'ZQTY'     '數量',
                   'ZUNIT'    '單位用量',
                   'ZPCUR'    '原採購幣別',
                   'ZDISPUP'  '原採購單價',
                   'ZREM'     '明細備註'.

* 這幾個欄位不標示 "必輸" 這個字眼
  assign_range_table r_fieldname 'I' 'EQ': 'ZBCUST'  '',
                                           'ZSCUST'  '',
                                           'ZDESC'   '',
                                           'ZREM1'   '',
                                           'ZSPNO'   '',
                                           'ZTUNYN'  '',
                                           'ZPCUR'   '',
                                           'ZDISPUP' '',
                                           'ZREM' ''.
* 為了標示第一行 "必輸" 這個字眼
  lt_fcat[] = it_fcat[].
  DELETE lt_fcat WHERE fieldname IN r_fieldname.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_TABLE_SCHEMA
*&---------------------------------------------------------------------*
FORM get_table_schema .
* 欄位說明 有Data Element
  SELECT * FROM dd03m INTO TABLE it_dd03m
   WHERE ( tabname = 'ZTSD0098' OR tabname = 'ZTSD0099' )
     AND ddlanguage = 'E'.

* 欄位說明 沒有Data Element
  SELECT * FROM dd03t INTO TABLE it_dd03t
   WHERE ( tabname = 'ZTSD0098' OR tabname = 'ZTSD0099' )
     AND ddlanguage = 'E'.

  SELECT * FROM dd03l INTO TABLE it_dd03l
   WHERE ( tabname = 'ZTSD0098' OR tabname = 'ZTSD0099' )
     AND fieldname <> 'MANDT'
   ORDER BY position.
  LOOP AT it_dd03l ASSIGNING FIELD-SYMBOL(<fs_dd03l>).
    <fs_dd03l>-position = sy-tabix.
  ENDLOOP.
ENDFORM.

** 2022/07/26  V005     Begin
FORM user_command USING vl_ucomm LIKE sy-ucomm              "#EC CALLED
                  rs_selfield TYPE slis_selfield.

*V006 ATC檢查不可為空Procedute,但V005只調整這裡,補個變數避免錯誤
  DATA: g_forATC(20).
  g_forATC = '1'.

ENDFORM.
** 2022/07/26  V005     End


*Selection texts
*----------------------------------------------------------
* P_DOWNLD         Download Template
* P_FILE         檔案路徑(*.xls)
* P_UPLOAD         Upload


*Messages
*----------------------------------------------------------
*
* Message class: 00
*398   & & & &
*
* Message class: Hard coded
*   Template Download Fail
*
* Message class: ZODMSD01
*000   & & & &

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
