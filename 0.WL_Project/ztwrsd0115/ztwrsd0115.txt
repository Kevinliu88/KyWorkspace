*&---------------------------------------------------------------------*
* Module      ：SD-ODMII               Package：ZODM_SD
* Program Name：ZTWRSD0115             T-Code：ZTWRSD0115
* Description ：預採帳收款匯總報表
* Author      ：Gary
* Create Date ：2019/04/30
* Spec. Logic ：
*&=====================================================================*
* Modification Log - History
*&=====================================================================*
*    DATE     VERSION      AUTHOR                  DESCRIPTION
* ========== ========  ==============  =================================
* 2020/03/26     V001       yinglung   若XQ單表頭的成品件號為空，用客戶號
*                                      找看看成品件號是多少
* 2020/04/14     V002       yinglung   SAPERP-260 pearl 增加欄位與順序調整
* 2020/04/23     V003       Fangchyi   檢查權限物件Z_AUTHORG
* 2020/05/05     V004       yinglung   SAPERP-424 PAID DN# 未串區域別
* 2020/05/19     V005       yinglung   SAPERP-470 ODM-預採帳 ZTWRSD0115
*                                      E&O report description 加上工程圖號
* 2020/06/08     V006       yinglung   預採帳彙總表未顯示完整收貨客戶
* 2020/06/11     V007       yinglung   unpaid/paid 合併資料畫面顯示Graco Only字樣,並取消預設
* 2020/07/10     V008       yinglung   增加判斷餘數<=0不顯示在Detail分頁上
* 2021/01/15     V009       Kiwi       針對權限組織於BP的預採報表, 調整所有title為BP
* 2021/06/04     V010       Kiwi       XQ排列順序小->大
* 2022/05/16     V011      Fangchyi   xls file column name change : GCP Model# > Model#
* 2022/08/03     V012       Fangchyi   同一XQ項次有多張DN收款調整
* 2023/01/31     V013       Fangchyi   Paid頁籤by 幣別拆頁籤
*                                      Paid頁籤增加交易幣別及交易金額欄位
*                                      TABLE ZTSD0109頁籤設定表:增加幣別欄位為KEY
* 2023/4/17      V014     Joseph  增加Detail-unpaid 頁面 (所有unpaid的XQ清單)
* 2023/4/27      V015     Joseph 因應Graco user需求, 將原unpaid各線別頁面, 改為各筆資料(不彙總)
* 2023/12/07     V016     Fangchyi   增加ZOLDDAT欄位放原 ZDAT 或 取消訂單的簽核日
* 2024/01/31    V017    CaroL -Freda 增加Graco新模板格式+取消V015
* 2024/05/09     V018     Fangchyi    改用畫面上輸入的PAY比較日取代使用預採帳期間迄止日計算storage days
* 2025/03/03     V019     Francie     S4調整
*                            1. 不再使用ztsd0098-zauthorg
*                            2. 不再使用table ZTSD0130,改抓 ZTMARA & MARM
*&---------------------------------------------------------------------*
REPORT ztwrsd0115.

************************************************************************
* SAP TABLES                                                           *
************************************************************************

************************************************************************
* TYPES and TYPE-POOLS                                                 *
************************************************************************

************************************************************************
* Working Area & Internal Tables                                       *
************************************************************************
**CONSTANTS
CONSTANTS: c_unpaid(10) VALUE 'Un-Paid',
           c_paid(05)   VALUE 'Paid',
           c_paid21(10) VALUE 'Paid2_1',
           c_paid24(10) VALUE 'Paid2_4',
           c1(1)        VALUE '1',
           c2(1)        VALUE '2',
           c3(1)        VALUE '3',
           c4(1)        VALUE '4',
           c_over(05)   VALUE 'Over',
           c_under(05)  VALUE 'Under',
           c_perd1(20)  VALUE 'over 1 year',     "若Store Days> 365
           c_perd2(20)  VALUE '7-12 months',     "若Store Days >180 AND <= 365
           c_perd3(20)  VALUE '4-6 months',      "若Store Days>90 AND <=180
           c_perd4(20)  VALUE 'within 3 months'. "若Store Days<= 90"
* Working Area
DATA: ztsd0098     TYPE ztsd0098. "預採帳 XQ 主檔
DATA: ztsd0099     TYPE ztsd0099. "預採帳 XQ 明細檔
DATA: ztsd0101     TYPE ztsd0101.
DATA: g_dec(6)     TYPE n.
DATA: g_c2(2).

DATA: gs_context   TYPE zfs060.
DATA: gs_detail    TYPE zfs060_s_detail.
DATA: gs_header    TYPE zfs060_s_header.
DATA: gs_ztsd0088  LIKE ztsd0088.


DATA: gs_ztsd0109  LIKE ztsd0109 OCCURS 0 WITH HEADER LINE.
DATA: gs_ztsd0110  LIKE ztsd0110 OCCURS 0 WITH HEADER LINE.
DATA: gs_ztsd0111  LIKE ztsd0111 OCCURS 0 WITH HEADER LINE.
DATA: gs_ztsd0113  LIKE ztsd0113 OCCURS 0 WITH HEADER LINE.
DATA: gs_ztsd0114  LIKE ztsd0114 OCCURS 0 WITH HEADER LINE.
DATA: gs_ztsd0101  LIKE ztsd0101.
DATA: gs_ztsd0100  LIKE ztsd0100.
DATA: gs_kna1      LIKE kna1 OCCURS 0 WITH HEADER LINE.

DATA: g_flag.

DATA: p_con        TYPE dbcon-con_name VALUE 'SAPODM'.
DATA: g_ok.
DATA: exc_ref    TYPE REF TO cx_sy_native_sql_error,
      error_text TYPE string.

** Internal Tables
DATA: gt_ztsd0098  LIKE TABLE OF ztsd0098 WITH HEADER LINE.
DATA: gt_ztsd0099  LIKE TABLE OF ztsd0099 WITH HEADER LINE.
DATA: BEGIN OF gt_zpno OCCURS 0,
*>> V019 modify start
*        zauthorg       LIKE ztsd0098-zauthorg,
        werks          LIKE ztsd0098-werks,
*<< V019 modify end
        zpno           LIKE ztsd0098-zpno,
        pno_cn(100),
        pno_edesc(100),
        pno_desc(100),
      END OF gt_zpno.

DATA: BEGIN OF gt_m020_nam OCCURS 0,
*>> V019 modify start
*        zauthorg      LIKE ztsd0098-zauthorg,
        werks         LIKE ztsd0098-werks,
*<< V019 modify end

        zpno          LIKE ztsd0098-zpno,
        m020_nam(100),
      END OF gt_m020_nam.
** Detail
DATA: gt_detail LIKE TABLE OF gs_detail.
DATA: gt_detail_unpaid LIKE TABLE OF gs_detail. "V014
** DN已收款不還款/Non-compliant/ob model
DATA: BEGIN OF gt_all OCCURS 0,
        typeid(1),
        zsort_200                TYPE zsort_200,
        type(20),
        summary_sheet_period(30), "2020/04/14 yinglung V002
        zunptyp                  TYPE zunptyp.     "2020/04/14 yinglung V002
        INCLUDE STRUCTURE zfs060_s_lines.
DATA:   z6ptyp(10),
      END OF gt_all.
DATA: gt_dn  LIKE TABLE OF gt_all WITH HEADER LINE.
DATA: gt_non LIKE TABLE OF gt_all WITH HEADER LINE.
DATA: gt_ob  LIKE TABLE OF gt_all WITH HEADER LINE.
** Paid
DATA: gt_header_paid LIKE TABLE OF zfs060_s_header     WITH HEADER LINE.
DATA: gt_paid        LIKE TABLE OF zfs060_s_paid_lines WITH HEADER LINE.
** Un-Paid
DATA: gt_header_unpaid    LIKE TABLE OF zfs060_s_header         WITH HEADER LINE.
DATA: gt_g_header_unpaid  LIKE TABLE OF zfs060_s_group_header   WITH HEADER LINE.
DATA: gt_g_line_header_unpaid LIKE TABLE OF zgroup_lines_header WITH HEADER LINE.
DATA: gt_unpaid           LIKE TABLE OF zfs060_s_paid_lines     WITH HEADER LINE.
* V016 Added by Tristan 2023/12/08 *
DATA: it_lead LIKE ztsd0205 OCCURS 0 WITH HEADER LINE.
* V016 End off *
*>>V019 modify start
*RANGES: r_zpno     FOR ztsd0098-zpno.
*DATA: it_ztsd0130 LIKE ztsd0130 OCCURS 0 WITH HEADER LINE.
RANGES: r_zpno     FOR ztmara-matnr.
DATA: it_ZTMARA LIKE ztmara OCCURS 0 WITH HEADER LINE.
*DATA: it_ztmm_color  LIKE ztmm_color  OCCURS 0 WITH HEADER LINE.
DATA: BEGIN OF it_ZTMM0050COLOR OCCURS 0,
        wl2_colorno LIKE ztmm0050color-wl2_colorno,
        object_name LIKE ztmm0050color-object_name,
      END OF it_ZTMM0050COLOR.
*<<V019 modify end
DATA: save_as    TYPE string.
*V017 CaroL取消
*DATA: zxlwb_form_id TYPE string. "V015
************************************************************************
** Selection screen deslare                                            *
************************************************************************
SELECTION-SCREEN BEGIN OF BLOCK blk1 WITH FRAME TITLE TEXT-t01.
*>> V019 modify start
*PARAMETERS:     p_zauth  LIKE ztsd0098-zauthorg OBLIGATORY.       "環境別
  PARAMETERS:      p_werks  LIKE ztsd0098-werks OBLIGATORY.
  PARAMETERS:      p_vtweg  LIKE ztsd0098-vtweg OBLIGATORY.
*<< V019 modify end

  PARAMETERS:     p_zbcust LIKE ztsd0098-zbcust   OBLIGATORY.       "客戶別
  SELECT-OPTIONS: s_zline  FOR ztsd0098-zxqline." OBLIGATORY.       "線別
  SELECT-OPTIONS: s_zxqno  FOR ztsd0098-zxqno     NO-DISPLAY.
  SELECT-OPTIONS: s_zym    FOR ztsd0098-zym.    " OBLIGATORY.

  PARAMETERS:     p_month  TYPE monat             OBLIGATORY        "分隔月數
                                                  DEFAULT '06'.
  PARAMETERS:     p_date   TYPE sy-datum          OBLIGATORY        "PAY比較日
                                                  DEFAULT sy-datum.
  PARAMETERS:     p_days   LIKE g_dec             OBLIGATORY        "PAY未異動天數
                                                  DEFAULT '360'.
  SELECTION-SCREEN SKIP.
  SELECTION-SCREEN COMMENT /1(50) TEXT-t02. "20200611 yinglung V007
  PARAMETERS:     p_unpaid AS CHECKBOX            DEFAULT ''.       "UNPAID彙總總數 "20200611 yinglung V007 取消預設
  PARAMETERS:     p_paid   AS CHECKBOX            DEFAULT ''.       "PAID彙總總數   "20200611 yinglung V007 取消預設
  PARAMETERS:     p_exqty0 AS CHECKBOX            DEFAULT ''.       "排除Detail餘數為0 "20200710 yinglung V008

*V017 CaroL取消
*PARAMETERS:  p_unp_d AS CHECKBOX   DEFAULT ''.
  "V015 UNPAID 明細

* V016 Added by Tristan 2023/12/08 *
  PARAMETERS: p_lead AS CHECKBOX, " 納入物料Lead Time
              p_cnfm AS CHECKBOX. " OrderCancel顯示ConfirmDate
* V016 End off *

  PARAMETERS:  p_label AS CHECKBOX   DEFAULT ''. "V017 Graco格式

SELECTION-SCREEN END OF BLOCK blk1.
PARAMETERS :  preview  RADIOBUTTON GROUP abc.
PARAMETERS :  psave    RADIOBUTTON GROUP abc.
PARAMETERS :  p_file  LIKE rlgrap-filename .

************************************************************************
* INITIALIZATION Event                                                 *
************************************************************************
*INITIALIZATION.

************************************************************************
* AT SELECTION-SCREEN OUTPUT Event                                     *
************************************************************************
AT SELECTION-SCREEN OUTPUT.

************************************************************************
* AT SELECTION-SCREEN Event                                            *
************************************************************************
AT SELECTION-SCREEN.
  IF psave = 'X' AND p_file = space.
    MESSAGE e002(sy) WITH '請指定存放檔名'.
  ENDIF.

*V003 added by Fangchyi 2020/04/23
*>> V019 modify start
*  AUTHORITY-CHECK OBJECT 'Z_AUTHORG'
*         ID 'ZAUTHORG' FIELD p_zauth
*         ID 'ACTVT' FIELD '03'.
  AUTHORITY-CHECK OBJECT 'V_KNA1_VKO'
         ID 'VTWEG' FIELD p_vtweg
         ID 'ACTVT' FIELD '03'.
*<< V019 modify end
  IF sy-subrc <> 0.
    MESSAGE e002(sy) WITH '無此通路的權限'.
  ENDIF.
*V003 end off

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM get_filename USING p_file.

************************************************************************
* START-OF-SELECTION Event                                             *
************************************************************************
START-OF-SELECTION.
  PERFORM clear_data.

*1.依輸入條件找 ztsd0098,ztsd0099
*2.刪除以下條件資料不顯示
*  當 預採帳數量ZQTY - 收款後轉出ZP653BQTY - 收款前轉出ZN653BQTY -
*                      報廢數量(ZDN3QTY+ZDN4QTY+ZCN5QTY+ZDN6QTY) <= 0，排除
  PERFORM get_ztsd0098_99.

** Prepare Detail Data
  PERFORM prepare_data.
  SORT gt_detail BY typeid zxqline zkinds z090styp zcpnocn zscust zpno zxqno.
** Un-Paid / Paid 彙總
  PERFORM collect_data_for_unpaid_paid.

***
  PERFORM prepare_header.

***DN已收款不還款/Non-compliant/ob model/Paid/un-paid
  PERFORM prepare_all_data.

** Prepare Excel Data
  PERFORM prepare_excel_data.

************************************************************************
* END-OF-SELECTION Event                                             *
************************************************************************
END-OF-SELECTION.
  CLEAR: save_as.
  IF psave = 'X'.
    save_as = p_file.
  ENDIF.

*V017 CaroL取消
**  V015 start
*  IF p_unp_d = 'X'.
*    zxlwb_form_id =  'FS060_2'.
*  ELSE.
*    zxlwb_form_id =  'FS060'.
*  ENDIF.
**  V015 endof
*V017 CaroL取消End

  CALL FUNCTION 'ZXLWB_CALLFORM'
    EXPORTING
      iv_formname        = 'FS060'   "V017 CaroL復原
*     iv_formname        = 'FS060'   "V015 modify
*     iv_formname        = zxlwb_form_id
      iv_context_ref     = gs_context
*     IV_VIEWER_TITLE    = SY-TITLE
*     iv_viewer_inplace  = 'X'
*     IV_VIEWER_CALLBACK_PROG       = SY-CPROG
*     IV_VIEWER_CALLBACK_FORM       =
      iv_viewer_suppress = psave
*     IV_PROTECT         =
      iv_save_as         = save_as
*     IV_SAVE_AS_APPSERVER          =
*     IV_STARTUP_MACRO   =
*     IT_DOCPROPERTIES   =
* IMPORTING
*     EV_DOCUMENT_RAWDATA           =
*     EV_DOCUMENT_EXTENSION         =
    EXCEPTIONS
      process_terminated = 1
      OTHERS             = 2.
  IF sy-subrc <> 0.
* Implement suitable error handling here
    MESSAGE e002(sy) WITH 'ZXLWB_CALLFORM Error, please call IT'.
  ENDIF.

  PERFORM clear_data. "2020/04/16 yinglung V002

*&---------------------------------------------------------------------*
*&      Form  CLEAR_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM clear_data .
*>> V019 modify start
*  REFRESH: gt_ztsd0098, gt_ztsd0099, it_ztsd0130, gt_detail, gt_zpno, gt_m020_nam,
*            r_zpno, gt_all, gt_dn, gt_non, gt_ob, gt_header_paid,
*            gt_paid, gt_header_unpaid, gt_g_header_unpaid,
*            gt_g_line_header_unpaid, gt_unpaid.
*  CLEAR:   gt_ztsd0098, gt_ztsd0099, it_ztsd0130, gt_detail, gt_zpno, gt_m020_nam,
*           r_zpno, gt_all, gt_dn, gt_non, gt_ob, gt_header_paid,
*           gt_paid, gt_header_unpaid, gt_g_header_unpaid,
*           gt_g_line_header_unpaid, gt_unpaid.
  REFRESH: gt_ztsd0098, gt_ztsd0099, gt_detail, gt_zpno, gt_m020_nam,
            r_zpno, gt_all, gt_dn, gt_non, gt_ob, gt_header_paid,
            gt_paid, gt_header_unpaid, gt_g_header_unpaid,
            gt_g_line_header_unpaid, gt_unpaid.
  CLEAR:   gt_ztsd0098, gt_ztsd0099, gt_detail, gt_zpno, gt_m020_nam,
           r_zpno, gt_all, gt_dn, gt_non, gt_ob, gt_header_paid,
           gt_paid, gt_header_unpaid, gt_g_header_unpaid,
           gt_g_line_header_unpaid, gt_unpaid.
*<< V019 modify end
  CLEAR:   gs_detail, gs_header.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_ZTSD0098_99
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM get_ztsd0098_99 .
*1.依輸入條件找 ztsd0098,ztsd0099
  SELECT * FROM ztsd0098
           INTO CORRESPONDING FIELDS OF TABLE gt_ztsd0098
*>>V019 modify start
*           WHERE zauthorg  =   p_zauth  "環境別
            WHERE werks = p_werks
              AND vtweg = p_vtweg
*<< V019 modify end
             AND zbcust    =   p_zbcust "客戶別
             AND zxqline   IN  s_zline  "線別
             AND zxqno     IN  s_zxqno
  AND zym       IN  s_zym.
  IF sy-subrc = 0.
    SELECT * FROM ztsd0099
             INTO CORRESPONDING FIELDS OF TABLE gt_ztsd0099
             FOR ALL ENTRIES IN gt_ztsd0098
*>>V019 modify start
*             WHERE zauthorg  =  gt_ztsd0098-zauthorg  "環境別
*    AND zxqno     =  gt_ztsd0098-zxqno.    "XQ單號
       WHERE werks  =  gt_ztsd0098-werks    "plant
     AND zxqno     =  gt_ztsd0098-zxqno     "XQ單號
     AND vtweg = gt_ztsd0098-vtweg.
*<< V019 modify end
  ENDIF.
*2.刪除以下條件資料不顯示
*  當 預採帳數量ZQTY - 收款後轉出ZP653BQTY - 收款前轉出ZN653BQTY -
*                      報廢數量(ZDN3QTY+ZDN4QTY+ZCN5QTY+ZDN6QTY) <= 0，排除  ( (ZDN6QTY為負數)
*  LOOP AT GT_ZTSD0099.
*    IF  GT_ZTSD0099-ZQTY - GT_ZTSD0099-ZP653BQTY - GT_ZTSD0099-ZN653BQTY -
*      ( GT_ZTSD0099-ZDN3QTY + GT_ZTSD0099-ZDN4QTY + GT_ZTSD0099-ZCN5QTY - GT_ZTSD0099-ZDN6QTY ) <= 0.
*      DELETE GT_ZTSD0099 INDEX SY-TABIX.
*    ENDIF.
*  ENDLOOP.

  r_zpno-sign = 'I'.
  r_zpno-option = 'EQ'.
  LOOP AT gt_ztsd0098 WHERE zpno <> ''.
    r_zpno-low = gt_ztsd0098-zpno.
    COLLECT r_zpno.
  ENDLOOP.
*20200326 yinglung V001 begin
  LOOP AT gt_ztsd0098 WHERE zpno EQ ''.
*>> V019 modify start
*    SELECT SINGLE zzpno_no INTO r_zpno-low FROM ztsd0020
*      WHERE zauthorg EQ gt_ztsd0098-zauthorg AND
*        WHERE zauthorg EQ gt_ztsd0098-zauthorg AND
*            kunnr EQ gt_ztsd0098-zbcust AND
*            zcpno EQ gt_ztsd0098-zcpno AND
*            zcn   EQ gt_ztsd0098-zcpnocn.


    SELECT matnr INTO r_zpno-low FROM ztsd0020
        UP TO 1 ROWS
       WHERE vtweg  = gt_ztsd0098-vtweg AND
            kunnr EQ gt_ztsd0098-zbcust AND
            zcpno EQ gt_ztsd0098-zcpno AND
            zcn   EQ gt_ztsd0098-zcpnocn
       ORDER BY PRIMARY KEY.
    ENDSELECT.

*<< V019 modify end

    IF sy-subrc EQ 0.
      gt_ztsd0098-zpno = r_zpno-low.
      MODIFY gt_ztsd0098.
      COLLECT r_zpno.
    ENDIF.
  ENDLOOP.
*20200326 yinglung V001 end
  LOOP AT gt_ztsd0099 WHERE zpno <> ''.
    r_zpno-low = gt_ztsd0099-zpno.
    COLLECT r_zpno.
  ENDLOOP.
*>> V019 modify start
*  SORT gt_ztsd0098 BY zauthorg zxqno.
*  SORT gt_ztsd0099 BY zauthorg zxqno zxqseq.
  SORT gt_ztsd0098 BY werks zxqno.
  SORT gt_ztsd0099 BY werks zxqno zxqseq.
*<< V019 modify end
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PREPARE_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM prepare_data .
  DATA: l_days(10) TYPE n.
  DATA: l_ztsd0088 TYPE ztsd0088.

  DATA: l_qty1 LIKE ztsd0099-zdn1qty.
  DATA: l_qty2 LIKE ztsd0099-zdn1qty.
  DATA: l_qty3 LIKE ztsd0099-zdn1qty.
  DATA: l_qty4 LIKE ztsd0099-zdn1qty.
  DATA: l_date TYPE sy-datum.
  DATA: chk_qty LIKE ztsd0099-zdn1qty.
  DATA: l_area LIKE ztsd0101-zarea. "20200505 yinglung V004
*V016 added
**抓取成品廠內件號
  DATA: it_zfrt LIKE mara OCCURS 0 WITH HEADER LINE.
  SELECT *
    INTO TABLE it_zfrt
    FROM mara
   WHERE mtart = 'ZFRT'. "ODM成品
*>> V019 modify start
*  CASE P_ZAUTH.
*    WHEN 'WL'.
*      SORT it_zfrt BY zzpno_no.
*    WHEN 'BP'.
*      SORT it_zfrt BY zzpno_no_px.
*  ENDCASE.
  SORT it_zfrt BY matnr.
*<< V019 modify end

*V016 end off
** 到中介db中抓取
*  PERFORM GET_SQL_DATA.
*  SORT GT_ZPNO     BY ZAUTHORG ZPNO.
*  SORT GT_M020_NAM BY ZAUTHORG ZPNO.
*>>V019 modify start , ztsd0130 改抓 ztmara
*改抓ztsd0130
*  PERFORM get_ztsd0130.
  PERFORM get_ztmara.
*<<V019 modify end
* V016 Added by Tristan 2023/12/08 *
  SELECT * FROM ztsd0205 INTO TABLE it_lead
*>>V019 modify start
*   WHERE zauthorg = p_zauth
   WHERE vtweg = p_VTWEG
*<<V019 modify end
     AND zbcust = p_zbcust.
  SORT it_lead.
* V016 End off *
**
  CLEAR: g_flag,gs_ztsd0088.
  LOOP AT gt_ztsd0099.
    CLEAR: gs_detail,gt_ztsd0098,
           gs_ztsd0109, gs_ztsd0110, gs_ztsd0111, gs_ztsd0113, gs_ztsd0114, gs_kna1,chk_qty.

**CHK_QTY <=代表已結案
    chk_qty =   gt_ztsd0099-zqty - gt_ztsd0099-zp653bqty - gt_ztsd0099-zn653bqty
            - ( gt_ztsd0099-zdn3qty + gt_ztsd0099-zdn4qty + gt_ztsd0099-zcn5qty - gt_ztsd0099-zdn6qty ).

*>>V019 modify start
*    READ TABLE gt_ztsd0098 WITH KEY zauthorg = gt_ztsd0099-zauthorg
*                                    zxqno    = gt_ztsd0099-zxqno.
    READ TABLE gt_ztsd0098 WITH KEY werks = gt_ztsd0099-werks
                                    zxqno    = gt_ztsd0099-zxqno.
*<<V019 modify end
    IF sy-subrc = 0.
      TRANSLATE gt_ztsd0098-zxqline  TO UPPER CASE.
** Get 預採帳線別名稱, 預採帳小分類設定表, 預採帳Presure說明,  預採帳Unpay排序名稱
*      Get最新一期預採帳期間, KNA1
      PERFORM get_master_data.

*** ZTSD0088
      WRITE gs_ztsd0088-zedat TO gs_detail-zedat.     "預採帳迄止日
*** ZTSD0098
      gs_detail-zxqline     = gt_ztsd0098-zxqline.    "線別
      gs_detail-zcpno       = gt_ztsd0098-zcpno.      "SAP model#
      gs_detail-zcpnocn     = gt_ztsd0098-zcpnocn.    "GCP Model#
*進一步判斷以下logic(2019.07.24 add)
*1.對應型號為空，則放入對應型號=客戶件號 (if ztsd0098-zcpnocn = '' ,then = ztsd0098-zcpno)
*2.如果對應型號 = 客戶件號 # 只顯示對應型號(D)、客戶件號(C) 放空白
*sap model# = space
      IF gs_detail-zcpnocn EQ space.
        gs_detail-zcpnocn = gs_detail-zcpno.
      ENDIF.
      IF gs_detail-zcpnocn = gs_detail-zcpno.
        CLEAR : gs_detail-zcpno.
      ENDIF.
      gs_detail-zscust      = gt_ztsd0098-zscust.     "Customerid
      gs_detail-zcord       = gt_ztsd0098-zcord.      "PO#
      IF gs_detail-zcord IS INITIAL.
        gs_detail-zcord = gt_ztsd0098-zsappo.
      ENDIF.
* V016 Changed by Tristan 2023/12/08 *
*      SELECT SINGLE zsappo FROM ztsd0028 INTO gs_detail-zsappo      "SAP PO
*                    WHERE  vbeln = gt_ztsd0098-zsono
*      AND  zvsnmr_v = '000'.
*      IF gs_detail-zsappo = ''.
*        gs_detail-zsappo = gt_ztsd0098-zsappo.
*      ENDIF.
      IF p_cnfm = 'X' AND gs_ztsd0111-zkinds = 'PS20'. " 'PS20' "Order Cancel"系列
        SELECT SINGLE zsappo, zapropd
          FROM ztsd0028
          INTO ( @gs_detail-zsappo, @DATA(p_zapropd) )
         WHERE vbeln = @gt_ztsd0098-zsono
           AND zvsnmr_v = '000'.
        IF sy-subrc = 0.
          WRITE p_zapropd TO gs_detail-zolddat.
        ENDIF.
        IF gs_detail-zsappo = ''.
          gs_detail-zsappo = gt_ztsd0098-zsappo.
        ENDIF.
      ELSE.
        SELECT SINGLE zsappo FROM ztsd0028 INTO gs_detail-zsappo      "SAP PO
                      WHERE  vbeln = gt_ztsd0098-zsono
        AND  zvsnmr_v = '000'.
        IF gs_detail-zsappo = ''.
          gs_detail-zsappo = gt_ztsd0098-zsappo.
        ENDIF.
      ENDIF.
* V016 End off *
*** ZTSD0099
*>>V019 modify start
*      gs_detail-zauthorg    = gt_ztsd0099-zauthorg.
      gs_detail-vtweg = gt_ztsd0099-vtweg.
*<<V019 modify end
      gs_detail-zpno        = gt_ztsd0099-zpno.       "廠內件號
      gs_detail-zspno       = gt_ztsd0099-zspno.      "視同件號
      WRITE gt_ztsd0099-zmoqty TO gs_detail-zmoqty DECIMALS 3 NO-GROUPING.
*      GS_DETAIL-ZMOQTY      = GT_ZTSD0099-ZMOQTY.     "原MOQ數量
      gs_detail-z6ptyp      = gt_ztsd0099-z6ptyp.     "6Ptype
      gs_detail-z6ptypnam   = gs_ztsd0114-z6ptypnam.  "是否符合6P&HR4040
      gs_detail-z6prem      = gt_ztsd0099-z6prem.     "6p備註
      gs_detail-zxqdtyp     = gt_ztsd0099-zxqdtyp.    "預採帳小分類
      gs_detail-zdesc       = gt_ztsd0099-zdesc.      "Inventory Item
* V016 Changed by Tristan 2023/12/08 *
*      WRITE gt_ztsd0099-zdat TO gs_detail-zdat.       "Date
      IF p_lead = 'X' AND ( gs_ztsd0111-zkinds = 'PS30' OR  " 'PS30' "MOQ"系列
                            gs_ztsd0111-zkinds = 'PS50' ).  " 'PS50' "forecast"系列
        IF gt_ztsd0098-zsono IS NOT INITIAL.    "取ZVA03上銷售訂單的第0版確認日期audat
          SELECT SINGLE audat FROM ztsd0028 INTO @DATA(lv_audat)
                   WHERE  vbeln = @gt_ztsd0098-zsono AND  zvsnmr_v = '000'.
          IF sy-subrc = 0.
            gt_ztsd0099-zdat = lv_audat.
          ENDIF.
          CLEAR:lv_audat.
        ENDIF.
        WRITE gt_ztsd0099-zdat TO gs_detail-zolddat.    " Old Date
**若廠內件號為成品則不計算lead days
*>> wait
*        CASE P_ZAUTH.
*          WHEN 'WL'.
*            READ TABLE it_zfrt WITH KEY zzpno_no = gt_ztsd0099-zpno BINARY SEARCH.
*          WHEN 'BP'.
*            READ TABLE it_zfrt WITH KEY zzpno_no_px = gt_ztsd0099-zpno BINARY SEARCH.
*        ENDCASE.
*<< wait
        IF sy-subrc <> 0.
          PERFORM calc_lead_days. " Date->gt_ztsd0099-zdat + lead days
        ENDIF.
***如果沒有勾 p_lead 則改取marc
*      ELSEIF p_lead = ''.
        PERFORM calc_lead_days_marc.
      ENDIF.
      WRITE gt_ztsd0099-zdat TO gs_detail-zdat.       "Date
* V016 End off *
      CONCATENATE gt_ztsd0099-zxqno '-' gt_ztsd0099-zxqseq+3(3)
                            INTO gs_detail-zxqno.     "庫存單明細
*** ZTSD0109
      gs_detail-zsort_200   = gs_ztsd0109-zsort_200.  "線別排序
      gs_detail-zlinenam    = gs_ztsd0109-zlinenam.   "轉換後線別名稱
      gs_detail-zlinenam2   = gs_ztsd0109-zlinenam2.  "轉換後線別名稱2
      gs_detail-zlinenam3   = gs_ztsd0109-zlinenam3.  "for by Date sheet(線別)
*** ZTSD0110
      gs_detail-zkindsnam1  = gs_ztsd0110-zkindsnam1. "Pressure說明1
      gs_detail-zkindsnam2  = gs_ztsd0110-zkindsnam2. "Summary sheet row name
*** ZTSD0111
      gs_detail-zkinds      = gs_ztsd0111-zkinds.     "Pressure分類
      gs_detail-zxqdtypnam  = gs_ztsd0111-zxqdtypnam. "預採帳小分類說明
      gs_detail-z090styp    = gs_ztsd0111-z090styp.   "090小分類
      PERFORM get_dimain_text USING 'Z090STYP'        "090小分類說明
                                    gs_detail-z090styp
                           CHANGING gs_detail-z090styptext.
*** ZTSD0113
      gs_detail-zunptypnam   = gs_ztsd0113-zunptypnam. "Reason
      gs_detail-zunptyp      = gs_ztsd0113-zunptyp. "2020/04/16 yinglung V002

*** KNA1
      gs_detail-sortl        = gs_kna1-sortl.          "Customer

*20200608 yinglung V006 begin
      IF gs_detail-sortl EQ ''.
        gs_detail-sortl     = gt_ztsd0098-zscust.
      ENDIF.
*20200608 yinglung V006 end

*V018 changed: Store Days	改成=PAY比較日 -ztsd0099-zdat
**Store Days  =預採帳迄止日 -ztsd0099-zdat
*      gs_detail-store_days   = gs_ztsd0088-zedat - gt_ztsd0099-zdat.
      gs_detail-store_days   = p_date - gt_ztsd0099-zdat.
*V018 end off
*Summary sheet Period	若Store Days > 挑選畫面上的分隔月數*30，則放'Over',否則放'Under'
      CLEAR l_days.
      l_days = p_month * 30.
      IF gs_detail-store_days > l_days.
        gs_detail-summary_sheet_period = c_over.
      ELSE.
        gs_detail-summary_sheet_period = c_under.
      ENDIF.


*by US sheet Period for Store Days
      IF gs_detail-store_days > 365.
        gs_detail-us_sheet_period      = c_perd1. "'over 1 year'
      ELSEIF gs_detail-store_days > 180 AND gs_detail-store_days <= 365.
        gs_detail-us_sheet_period      = c_perd2. "'7-12 months'
      ELSEIF gs_detail-store_days > 90 AND gs_detail-store_days <= 180.
        gs_detail-us_sheet_period      = c_perd3. "'4-6 months'
      ELSEIF gs_detail-store_days <= 90.
        gs_detail-us_sheet_period      = c_perd4. "'within 3 months'
      ENDIF.
*>> V019 modify start
*      IF gt_ztsd0099-zauthorg <> '' AND gt_ztsd0099-zpno <> ''.
*        SORT it_ztsd0130 BY zauthorg zpno. "V015 ATC (在get_ztsd0130 裡面其實已經sort過)
*        READ TABLE it_ztsd0130 WITH KEY zauthorg = gt_ztsd0099-zauthorg
*                                        zpno     = gt_ztsd0099-zpno
*                                        BINARY SEARCH.
*        IF sy-subrc = 0.
*
**20200519 yinglung V005 begin
*          IF it_ztsd0130-zpno_draw NE ''.
*            CONCATENATE gs_detail-zdesc it_ztsd0130-zpno_draw INTO gs_detail-zdesc SEPARATED BY space.
*          ENDIF.
**20200519 yinglung V005 end
*
*          gs_detail-pno_edesc = it_ztsd0130-zpno_edesc.
**中文品名
*          CONCATENATE it_ztsd0130-zpno_cn it_ztsd0130-zpno_desc INTO gs_detail-pno_desc SEPARATED BY space.
**廠內顏色
*          gs_detail-m020_nam = it_ztsd0130-zpno_colornam.
*        ENDIF.
*
*      ENDIF.
**MODEL英文規格
*      IF gt_ztsd0098-zauthorg <> '' AND gt_ztsd0098-zpno <> ''.
*        SORT it_ztsd0130 BY zauthorg zpno. "V015 ATC (在get_ztsd0130 裡面其實已經sort過)
*        READ TABLE it_ztsd0130 WITH KEY zauthorg = gt_ztsd0098-zauthorg
*                                        zpno     = gt_ztsd0098-zpno
*                                        BINARY SEARCH.
*        IF sy-subrc = 0.
*          gs_detail-pno_edesc_model = it_ztsd0130-zpno_edesc.
*        ENDIF.
*      ENDIF.

      IF gt_ztsd0099-zpno <> ''.
        READ TABLE it_ztmara WITH KEY matnr = gt_ztsd0099-zpno
             BINARY SEARCH.
        IF sy-subrc = 0.
          IF it_ztmara-maindrawingno NE ''.
            CONCATENATE gs_detail-zdesc it_ztmara-maindrawingno INTO gs_detail-zdesc SEPARATED BY space.
          ENDIF.

          gs_detail-pno_edesc = it_ztmara-wl2_englishspecifications.
*中文品名
          CONCATENATE it_ZTMARA-wl2_thenameoftheerp it_ZTMARA-wl2_erpspecification INTO gs_detail-pno_desc SEPARATED BY space.
*廠內顏色 : domain ZCOLOR_CODE 對應的說明文字
*          READ TABLE it_ztmm_color WITH KEY zzcolor_code = it_ztmara-factorythecolor.  "2025/06/01 mark
          READ TABLE it_ZTMM0050COLOR                                                  "2025/06/01 add
               WITH KEY wl2_colorno = it_ztmara-factorythecolor.

          IF sy-subrc = 0.
*            gs_detail-m020_nam = it_ztmm_color-zzcolor_name.      "2025/06/01 mark
            gs_detail-m020_nam = it_ZTMM0050COLOR-object_name.    "2025/06/01 add
          ENDIF.
        ENDIF.

      ENDIF.
*MODEL英文規格
      IF gs_detail-zcpnocn IS NOT INITIAL.   "根據Model#對應ZTMARA- WL2_THENAMEOFTHEERP，找到 WL2_ENGLISHSPECIFICATIONS
        SELECT SINGLE wl2_englishspecifications
           INTO gs_detail-pno_edesc_model FROM ztmara
           WHERE wl2_thenameoftheerp = gs_detail-zcpnocn.
      ENDIF.
*      IF gt_ztsd0098-zpno <> ''.
*        READ TABLE it_ztmara WITH KEY matnr = gt_ztsd0099-zpno
*             BINARY SEARCH.
*        IF sy-subrc = 0.
*          gs_detail-pno_edesc_model = it_ZTMARA-wl2_englishspecifications.
*        ENDIF.
*      ENDIF.
*<< V019 modify end


***** Un-Paid/Paid處理  ************
** 3.1 當 ztsd0099-ZDN1QTY + ztsd0099-ZDN4QTY = 0 或 ztsd0099-ZQTY - ztsd0099-ZN653BQTY -  ( ztsd0099-ZDN1QTY + ztsd0099-ZDN4QTY) >0 則計算unpaid數量
*      unpaid 數量 = ztsd0099-ZQTY - ztsd0099-ZN653BQTY -  ( ztsd0099-ZDN1QTY + ztsd0099-ZDN4QTY)
      CLEAR: l_qty1, l_qty2.
** 收款數量
      l_qty1 = gt_ztsd0099-zdn1qty + gt_ztsd0099-zdn4qty.
      l_qty2 = gt_ztsd0099-zqty - gt_ztsd0099-zn653bqty -  ( gt_ztsd0099-zdn1qty + gt_ztsd0099-zdn4qty ).

**針對未結案資料進行處理Un-Paid
      IF chk_qty > 0.
        IF l_qty1 = 0 OR l_qty2 > 0.
          gs_detail-typeid  = c1. "'1'. "Un-Paid
          gs_detail-type    = c_unpaid. "'Un-Paid'.
          gs_detail-yds_pcs = gt_ztsd0099-zqty - gt_ztsd0099-zn653bqty -  ( gt_ztsd0099-zdn1qty + gt_ztsd0099-zdn4qty ).

* " Summary sheet(線別)	=轉換後線別名稱2 + 空兩格 + Type
          CONCATENATE gs_detail-zlinenam2 gs_detail-type
                      INTO gs_detail-summary_sheet
                      SEPARATED BY g_c2.
*Units  =YDS/PCS / ztsd0099-zbqty
          IF gt_ztsd0099-zbqty <> 0.
            gs_detail-units      = gs_detail-yds_pcs / gt_ztsd0099-zbqty. "Unite
            gs_detail-zbqty      = gt_ztsd0099-zbqty.
          ENDIF.

*單價 當type = 'Un-Paid'時，=ztsd0099-zup/ztsd0099-ZUP_PER
          IF gt_ztsd0099-zup_per <> 0.
            gs_detail-zup    = gt_ztsd0099-zup / gt_ztsd0099-zup_per.
            WRITE gs_detail-zup TO gs_detail-zup NO-GROUPING.
          ENDIF.
*Amount (US$)	"=單價 *YDS/PCS 取到小數下兩位
          gs_detail-amount       = gs_detail-yds_pcs * gs_detail-zup.

          APPEND gs_detail TO gt_detail.
        ENDIF.
      ENDIF.
*****************************************************************************
*  3.2當收款數量(ZDN1QTY +  ZDN4QTY) > 0 且 收款數量 - 收款後轉出 - 報廢數量 > 0時，則計算paid數量
*     先判斷還款數量(ZCN2QTY)是否超過收款後轉出(ZP653BQTY)，如果超過收款後轉出的數量，也要加入報廢數量中計算
*     收款數量 = ztsd0099-zdn1qty + ztsd0099-zdn4qty
*     收款後轉出 = ztsd0099-zp653bqty
*     超過收款後轉出的數量 = ztsd0099-zcn2qty - ztsd0099-zp653bqty ，若計算後小於0則reassign = 0
*     報廢數量 = ztsd0099-ZDN3QTY+ ztsd0099-ZDN4QTY + ztsd0099-ZCN5QTY + ztsd0099-ZDN6QTY + 超過收款後轉出的數量
*     paid餘量 = 收款數量 - 收款後轉出 - 報廢數量
      CLEAR: l_qty1, l_qty2, l_qty3, l_qty4.
** 收款數量: L_QTY1
      l_qty1 = gt_ztsd0099-zdn1qty + gt_ztsd0099-zdn4qty.
** 收款後轉出: GT_ZTSD0099-ZP653BQTY.
** 超過收款後轉出的數量: L_QTY2.
      IF gt_ztsd0099-zcn2qty > gt_ztsd0099-zp653bqty.
        l_qty2 = gt_ztsd0099-zcn2qty - gt_ztsd0099-zp653bqty.
      ELSE.
        l_qty2 = 0.
      ENDIF.
** 報廢數量: L_QTY3 (ZDN6QTY為負數)
      l_qty3 =  gt_ztsd0099-zdn3qty + gt_ztsd0099-zdn4qty + gt_ztsd0099-zcn5qty -
                gt_ztsd0099-zdn6qty + l_qty2. "(超過收款後轉出的數量)
** 收款數量 - 收款後轉出 - 報廢數量
** 餘量: L_QTY4
      l_qty4 = l_qty1 - gt_ztsd0099-zp653bqty - l_qty3.
      IF l_qty1 > 0.

        IF chk_qty > 0.
          IF  l_qty4 > 0.
            gs_detail-typeid  = c2. "'2'. "Paid
            gs_detail-type    = c_paid.   "'Paid'.
          ELSE.
            IF gt_ztsd0099-zdn1qty > 0.
              gs_detail-typeid  = c3. "'3'.   "Paid2_1
              gs_detail-type    = c_paid21.   "'Paid2_1'.
            ELSE.
              gs_detail-typeid  = c4. "'3'.   "Paid2_4
              gs_detail-type    = c_paid24.   "'Paid2_4'.
            ENDIF.
          ENDIF.
        ELSE.
          IF gt_ztsd0099-zdn1qty > 0.
            gs_detail-typeid  = c3. "'3'.   "Paid2_1
            gs_detail-type    = c_paid21.   "'Paid2_1'.
          ELSE.
            gs_detail-typeid  = c4. "'3'.   "Paid2_4
            gs_detail-type    = c_paid24.   "'Paid2_4'.
          ENDIF.
        ENDIF.

**CHKAMT :  CHKAMT的邏輯為 paid 與 paid2_1, paid2_4此三個類別實際於ZTSD0101-ZXQDCTYPE = 1, 4 的 ZTOTAL
*>> V019 modify start
*        SELECT  * FROM ztsd0101
*                        WHERE zauthorg  = gt_ztsd0099-zauthorg
*                          AND zxqno     = gt_ztsd0099-zxqno
*                          AND zxqseq    = gt_ztsd0099-zxqseq
*                          AND zxqdctype IN ('1','4').

        SELECT  * FROM ztsd0101
                        WHERE werks  = gt_ztsd0099-werks   "wait
                          AND zxqno     = gt_ztsd0099-zxqno
                          AND zxqseq    = gt_ztsd0099-zxqseq
                          AND zxqdctype IN ('1','4').
*<< V019 modify end
          gs_detail-ztotal101  = gs_detail-ztotal101 + ztsd0101-ztotal.
*V012 added
**Paid DN#  "當Type = Paid時才抓取，否則為空白 =ZTSD0101-ZDCDOCNO
          IF gs_detail-zdcno <> ''.
            CONCATENATE gs_detail-zdcno ',' INTO gs_detail-zdcno.
          ENDIF.

          IF ztsd0101-zdcdocno <> space AND ztsd0101-zarea <> space.
            CONCATENATE '-' ztsd0101-zarea INTO l_area.
            IF ztsd0101-zdcdocno NS l_area.
              CONCATENATE gs_detail-zdcno ztsd0101-zdcdocno l_area INTO gs_detail-zdcno.
            ELSE.
              CONCATENATE gs_detail-zdcno ztsd0101-zdcdocno INTO gs_detail-zdcno.
            ENDIF.
          ELSE.
            CONCATENATE gs_detail-zdcno ztsd0101-zdcdocno INTO gs_detail-zdcno.
          ENDIF.
*V012 end off
        ENDSELECT.

        gs_detail-yds_pcs = l_qty4.

* " Summary sheet(線別)  =轉換後線別名稱2 + 空兩格 + Type
        CONCATENATE gs_detail-zlinenam2 gs_detail-type
                    INTO gs_detail-summary_sheet
                    SEPARATED BY g_c2.
*Units  =YDS/PCS / ztsd0099-zbqty
        IF gt_ztsd0099-zbqty <> 0.
          gs_detail-units      = gs_detail-yds_pcs / gt_ztsd0099-zbqty. "Unite
          gs_detail-zbqty      = gt_ztsd0099-zbqty.
        ENDIF.
*單價 當type = 'Paid'時，=ztsd101-ZUP / ztsd101-ZUP_PER
        CLEAR gs_ztsd0101.
*>> V019 modify start
*        SELECT SINGLE * FROM ztsd0101 INTO gs_ztsd0101
*                        WHERE zauthorg  = gt_ztsd0099-zauthorg
*                          AND zxqno     = gt_ztsd0099-zxqno
*                          AND zxqseq    = gt_ztsd0099-zxqseq
*                          AND zxqdctype = '1'.
*        IF sy-subrc <> 0.
*          SELECT SINGLE * FROM ztsd0101 INTO gs_ztsd0101
*                          WHERE zauthorg  = gt_ztsd0099-zauthorg
*                            AND zxqno     = gt_ztsd0099-zxqno
*                            AND zxqseq    = gt_ztsd0099-zxqseq
*                            AND zxqdctype = '4'.
*        ENDIF.
        SELECT  * FROM ztsd0101 INTO gs_ztsd0101 UP TO 1 ROWS
                        WHERE werks  = gt_ztsd0099-werks
                          AND zxqno     = gt_ztsd0099-zxqno
                          AND zxqseq    = gt_ztsd0099-zxqseq
                          AND zxqdctype = '1'
             ORDER BY PRIMARY KEY.
        ENDSELECT.
        IF sy-subrc <> 0.
          SELECT * FROM ztsd0101 INTO gs_ztsd0101 UP TO 1 ROWS
                          WHERE werks =  gt_ztsd0099-werks
                            AND zxqno     = gt_ztsd0099-zxqno
                            AND zxqseq    = gt_ztsd0099-zxqseq
                            AND zxqdctype = '4'
              ORDER BY PRIMARY KEY.
          ENDSELECT.
        ENDIF.
*<< V019 modify end

        IF gs_ztsd0101-zup_per <> 0.
          gs_detail-zup    = gs_ztsd0101-zup / gs_ztsd0101-zup_per.
          WRITE gs_detail-zup TO gs_detail-zup NO-GROUPING.
          CONDENSE gs_detail-zup.
        ENDIF.
*V012 marked
**Paid DN#  "當Type = Paid時才抓取，否則為空白 =ZTSD0101-ZDCDOCNO
*        gs_detail-zdcno    = gs_ztsd0101-zdcdocno.          "Paid DN#
*
**20200505 yinglung V004 begin
*      IF gs_ztsd0101-zdcdocno <> space AND gs_ztsd0101-zarea <> space.
*        CONCATENATE '-' gs_ztsd0101-zarea INTO l_area.
*        IF gs_ztsd0101-zdcdocno NS l_area.
*          CONCATENATE gs_ztsd0101-zdcdocno l_area INTO gs_detail-zdcno.
*        ENDIF.
*      ENDIF.
**20200505 yinglung V004 end
*V012 end off
*Paid date   "當Type = Paid時才抓取，否則為空白 =ZTSD0101-ZCNDAT"
        IF gs_ztsd0101-zfinaldat IS NOT INITIAL.
          WRITE gs_ztsd0101-zfinaldat TO gs_detail-zcndat.    "Paid date
        ENDIF.
*by Date sheet Pay Days  "當type = 'Paid'
*Pay Days= Paid date  - Date
*且 Paid Date>= ztsd0088-ZSDAT and Paid Date <= ztsd0088-ZEDAT時 >>不判斷 2019.08.07
*        IF GS_ZTSD0101-ZCNDAT >= GS_ZTSD0088-ZSDAT AND GS_ZTSD0101-ZCNDAT <= GS_ZTSD0088-ZEDAT.
        PERFORM convert_date_to_date USING gs_detail-zcndat
                                     CHANGING l_date.
        gs_detail-pay_days = l_date - gt_ztsd0099-zdat.
*        ENDIF.
*by Date sheet Period for Pay Days
        IF gs_detail-pay_days > 365.
          gs_detail-date_sheet_period      = c_perd1. "'over 1 year'
        ELSEIF gs_detail-pay_days > 180 AND gs_detail-pay_days <= 365.
          gs_detail-date_sheet_period      = c_perd2. "'7-12 months'
        ELSEIF gs_detail-pay_days > 90 AND gs_detail-pay_days <= 180.
          gs_detail-date_sheet_period      = c_perd3. "'4-6 months'
        ELSEIF gs_detail-pay_days <= 90.
          gs_detail-date_sheet_period      = c_perd4. "'within 3 months'
        ENDIF.
*360 未異動  "當TYPID = '1' 時為空白 當TYPEID = '2'時才作判斷
        CLEAR: gs_ztsd0100, l_ztsd0088.
*1.找到對應最新一筆ztsd0100:
*>> V019 modify start
*        SELECT * UP TO 1 ROWS FROM ztsd0100 INTO gs_ztsd0100
*                 WHERE zauthorg = gt_ztsd0099-zauthorg
*                   AND zxqno    = gt_ztsd0099-zxqno
*                   AND zxqseq   = gt_ztsd0099-zxqseq
*                   ORDER BY zym DESCENDING.
*        ENDSELECT.
        SELECT * UP TO 1 ROWS FROM ztsd0100 INTO gs_ztsd0100
                 WHERE werks = gt_ztsd0099-werks
                   AND zxqno    = gt_ztsd0099-zxqno
                   AND zxqseq   = gt_ztsd0099-zxqseq
                   ORDER BY zym DESCENDING.
        ENDSELECT.
*<< V019 modify end

        IF sy-subrc = 0.
*>> V019 modify start
*          SELECT SINGLE * FROM ztsd0088 INTO l_ztsd0088
*                   WHERE zauthorg = gs_ztsd0100-zauthorg
*                     AND zym      = gs_ztsd0100-zym
*                     AND zbcust   = gt_ztsd0099-zbcust
*           AND zperiod  = gs_ztsd0100-zperiod.

          SELECT SINGLE * FROM ztsd0088 INTO l_ztsd0088
                   WHERE vtweg  = gs_ztsd0100-vtweg
                     AND zym      = gs_ztsd0100-zym
                     AND zbcust   = gt_ztsd0099-zbcust
          AND zperiod  = gs_ztsd0100-zperiod.
*<< V019 modify end

*4.找到ztsd0088時 ，且 (挑選畫面上的PAY比較日期 - ztsd0088-zsdat > 挑選畫面上的PAY比較天數) 時，
* 則此欄位值 = 畫面上的PAY比較天數 +'未異動'"
          IF sy-subrc = 0.
            CLEAR l_days.
            l_days = p_date - l_ztsd0088-zsdat.
            IF l_days > p_days.
              WRITE p_days TO gs_detail-p_daystx NO-ZERO.
              CONDENSE gs_detail-p_daystx.
              CONCATENATE gs_detail-p_daystx '未異動' INTO gs_detail-p_daystx.
            ENDIF.
          ENDIF.
        ENDIF.
*Amount (US$)  "=單價 *YDS/PCS 取到小數下兩位
        gs_detail-amount       = gs_detail-yds_pcs * gs_detail-zup.
*V013 added
        IF gs_ztsd0101-doc_curr <> ''.
          gs_detail-doc_curr =  gs_ztsd0101-doc_curr.
        ELSE.
          gs_detail-doc_curr = gs_ztsd0101-zcur.
        ENDIF.
        IF gs_ztsd0101-doc_rate <> 0.
          gs_detail-doc_amt = gs_detail-amount * gs_ztsd0101-doc_rate.
        ELSE.
          gs_detail-doc_amt = gs_detail-amount.
        ENDIF.
*V013 end off

        APPEND gs_detail TO gt_detail.
      ENDIF.

*    V014 Start
      IF gs_detail-typeid = '1'.
        CONCATENATE gs_detail-zlinenam '-' 'unpaid' INTO gs_detail-zsheetnam. "V015
        APPEND gs_detail TO gt_detail_unpaid.
      ENDIF.
*    V014 endof

    ENDIF.
  ENDLOOP.


ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_MASTER_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM get_master_data .
** Get最新一期預採帳期間 from ZTSD00889 using call function ZSD_ODM_ZTSD0088
*  (抓一次就好，因為每筆資料的迄止日都是一樣的)
  IF g_flag = ''.
*>> V019 modify start
*    CALL FUNCTION 'ZSD_ODM_ZTSD0088'
*      EXPORTING
*        i_zauthorg = gt_ztsd0098-zauthorg
*        i_zbcust   = gt_ztsd0098-zbcust
*      IMPORTING
*        e_ztsd0088 = gs_ztsd0088.

    CALL FUNCTION 'ZSD_ODM_ZTSD0088'
      EXPORTING
        i_vtweg    = gt_ztsd0098-vtweg
        i_zbcust   = gt_ztsd0098-zbcust
      IMPORTING
        e_ztsd0088 = gs_ztsd0088.
*<< V019 modify end

    g_flag = 'X'.
  ENDIF.
** Get預採帳線別名稱 from ZTSD0109 using call function ZSD_ODM_ZTSD0109
*V013 added
  DATA: l_waers TYPE waers.
  CLEAR gs_ztsd0101.
*取得DNCN收款幣別
*>> V019 modify start
*  SELECT SINGLE * FROM ztsd0101 INTO gs_ztsd0101
*                  WHERE zauthorg  = gt_ztsd0099-zauthorg
*                    AND zxqno     = gt_ztsd0099-zxqno
*                    AND zxqseq    = gt_ztsd0099-zxqseq
*                    AND zxqdctype = '1'.
*  IF sy-subrc <> 0.
*    SELECT SINGLE * FROM ztsd0101 INTO gs_ztsd0101
*                    WHERE zauthorg  = gt_ztsd0099-zauthorg
*                      AND zxqno     = gt_ztsd0099-zxqno
*                      AND zxqseq    = gt_ztsd0099-zxqseq
*                      AND zxqdctype = '4'.
*  ENDIF.
  SELECT SINGLE * FROM ztsd0101 INTO gs_ztsd0101
                  WHERE vtweg  = gt_ztsd0099-vtweg
                    AND zxqno     = gt_ztsd0099-zxqno
                    AND zxqseq    = gt_ztsd0099-zxqseq
                    AND zxqdctype = '1'.
  IF sy-subrc <> 0.
    SELECT SINGLE * FROM ztsd0101 INTO gs_ztsd0101
                    WHERE vtweg  = gt_ztsd0099-vtweg
                      AND zxqno     = gt_ztsd0099-zxqno
                      AND zxqseq    = gt_ztsd0099-zxqseq
                      AND zxqdctype = '4'.
  ENDIF.
*<< V019 modify end

  IF sy-subrc = 0.
    SELECT SINGLE waers
      INTO l_waers
      FROM ztsd0118
     WHERE zdcno = gs_ztsd0101-zdcno_i.
    IF sy-subrc <> 0.
      l_waers = gs_ztsd0101-zcur.
    ENDIF.
  ELSE.
    l_waers = gt_ztsd0099-zusdcur.
  ENDIF.
*V013 end off
  READ TABLE gs_ztsd0109 WITH KEY zxqline = gt_ztsd0098-zxqline
                                  waers   = l_waers.  "V013 added field waers
  IF sy-subrc <> 0.
*>>V019 modify start
*    CALL FUNCTION 'ZSD_ODM_ZTSD0109'
*      EXPORTING
*        i_zxqline  = gt_ztsd0098-zxqline
*        i_zauthorg = gt_ztsd0098-zauthorg
*        i_zbcust   = gt_ztsd0098-zbcust
*        i_zwaers   = l_waers   "V013 added
*      IMPORTING
*        e_ztsd0109 = gs_ztsd0109.

    CALL FUNCTION 'ZSD_ODM_ZTSD0109'
      EXPORTING
        i_zxqline  = gt_ztsd0098-zxqline
        i_vtweg    = gt_ztsd0098-vtweg
        i_zbcust   = gt_ztsd0098-zbcust
        i_zwaers   = l_waers   "V013 added
      IMPORTING
        e_ztsd0109 = gs_ztsd0109.
*<< V019 modify end

    IF gs_ztsd0109 IS NOT INITIAL.
      APPEND gs_ztsd0109.
    ENDIF.
  ENDIF.
** Get預採帳小分類設定表 from ZTSD0111 using call function ZSD_ODM_ZTSD0111
  READ TABLE gs_ztsd0111 WITH KEY zxqdtyp = gt_ztsd0099-zxqdtyp.
  IF sy-subrc <> 0.
*>>V019 modify start
*    CALL FUNCTION 'ZSD_ODM_ZTSD0111'
*      EXPORTING
*        i_zxqdtyp  = gt_ztsd0099-zxqdtyp
*        i_zauthorg = gt_ztsd0099-zauthorg
*        i_zbcust   = gt_ztsd0099-zbcust
*      IMPORTING
*        e_ztsd0111 = gs_ztsd0111.
    CALL FUNCTION 'ZSD_ODM_ZTSD0111'
      EXPORTING
        i_zxqdtyp  = gt_ztsd0099-zxqdtyp
        i_vtweg    = gt_ztsd0099-vtweg
        i_zbcust   = gt_ztsd0099-zbcust
      IMPORTING
        e_ztsd0111 = gs_ztsd0111.
*<<V019 modify end
    IF gs_ztsd0111 IS NOT INITIAL.
      APPEND gs_ztsd0111.
    ENDIF.
  ENDIF.
** Get預採帳Presure說明 from ZTSD0110 using call function ZSD_ODM_ZTSD0110
  READ TABLE gs_ztsd0110 WITH KEY zkinds = gs_ztsd0111-zkinds.
  IF sy-subrc <> 0.
*>> V019 modify start
*    CALL FUNCTION 'ZSD_ODM_ZTSD0110'
*      EXPORTING
*        i_zkinds   = gs_ztsd0111-zkinds
*        i_zauthorg = gt_ztsd0099-zauthorg
*        i_zbcust   = gt_ztsd0099-zbcust
*      IMPORTING
*        e_ztsd0110 = gs_ztsd0110.
    CALL FUNCTION 'ZSD_ODM_ZTSD0110'
      EXPORTING
        i_zkinds   = gs_ztsd0111-zkinds
        i_vtweg    = gt_ztsd0099-vtweg
        i_zbcust   = gt_ztsd0099-zbcust
      IMPORTING
        e_ztsd0110 = gs_ztsd0110.
*<< V019 modify end

    IF gs_ztsd0110 IS NOT INITIAL.
      APPEND gs_ztsd0110.
    ENDIF.
  ENDIF.
** Get 預採帳Unpay排序名稱 from ZTSD0113 using call function ZSD_ODM_ZTSD0113
  READ TABLE gs_ztsd0113 WITH KEY zunptyp = gt_ztsd0098-zunptyp.
  IF sy-subrc <> 0.
*>> V019 modify start
*    CALL FUNCTION 'ZSD_ODM_ZTSD0113'
*      EXPORTING
*        i_zunptyp  = gt_ztsd0098-zunptyp
*        i_zauthorg = gt_ztsd0098-zauthorg
*        i_zbcust   = gt_ztsd0098-zbcust
*      IMPORTING
*        e_ztsd0113 = gs_ztsd0113.
    CALL FUNCTION 'ZSD_ODM_ZTSD0113'
      EXPORTING
        i_zunptyp  = gt_ztsd0098-zunptyp
        i_vtweg    = gt_ztsd0098-vtweg
        i_zbcust   = gt_ztsd0098-zbcust
      IMPORTING
        e_ztsd0113 = gs_ztsd0113.
*<< V019 modify end
    IF gs_ztsd0113 IS NOT INITIAL.
      APPEND gs_ztsd0113.
    ENDIF.
  ENDIF.
** Get 預採帳6PTYP特殊類別名稱 from ZTSD0114 using call function ZSD_ODM_ZTSD0114
  READ TABLE gs_ztsd0114 WITH KEY z6ptyp = gt_ztsd0099-z6ptyp.
  IF sy-subrc <> 0.
*>> V019 modify start
*    CALL FUNCTION 'ZSD_ODM_ZTSD0114'
*      EXPORTING
*        i_z6ptyp   = gt_ztsd0099-z6ptyp
*        i_zauthorg = gt_ztsd0098-zauthorg
*        i_zbcust   = gt_ztsd0098-zbcust
*      IMPORTING
*        e_ztsd0114 = gs_ztsd0114.
    CALL FUNCTION 'ZSD_ODM_ZTSD0114'
      EXPORTING
        i_z6ptyp   = gt_ztsd0099-z6ptyp
        i_vtweg    = gt_ztsd0098-vtweg
        i_zbcust   = gt_ztsd0098-zbcust
      IMPORTING
        e_ztsd0114 = gs_ztsd0114.
*<< V019 modify end
    IF gs_ztsd0114 IS NOT INITIAL.
      APPEND gs_ztsd0114.
    ENDIF.
  ENDIF.

** Get KNA1
  READ TABLE gs_kna1 WITH KEY kunnr = gt_ztsd0098-zscust.
  IF sy-subrc <> 0.
    SELECT SINGLE * FROM kna1 INTO gs_kna1
    WHERE kunnr = gt_ztsd0098-zscust.
    IF gs_kna1 IS NOT INITIAL.
      APPEND gs_kna1.
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_DIMAIN_TEXT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_0355   text
*      -->P_GS_DETAIL_Z090STYP  text
*      <--P_GS_DETAIL_Z090STYPTEXT  text
*----------------------------------------------------------------------*
FORM get_dimain_text  USING    VALUE(p_domain)
                               p_domainval
                      CHANGING p_domaintext.
  DATA: l_domname    LIKE  dd07l-domname,
        l_text       LIKE  ddrefstruc-bool,
        l_langu      LIKE  dd07t-ddlanguage,
        wa_dd07v_tab LIKE dd07v,
        lt_dd07v_tab LIKE TABLE OF dd07v.

  l_domname = p_domain.
  l_text    = 'X'.
  l_langu   = 'E'.
  CLEAR: wa_dd07v_tab, lt_dd07v_tab.

  CALL FUNCTION 'DD_DOMVALUES_GET'
    EXPORTING
      domname   = l_domname
      text      = l_text
      langu     = l_langu
*     BYPASS_BUFFER        = ' '
*       IMPORTING
*     RC        =
    TABLES
      dd07v_tab = lt_dd07v_tab.
  READ TABLE lt_dd07v_tab INTO wa_dd07v_tab WITH KEY domvalue_l = p_domainval.
  IF sy-subrc = 0.
    p_domaintext = wa_dd07v_tab-ddtext.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_SQL_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM get_sql_data .
*>> V019 modify start "mark , no use
*  CLEAR: g_ok.
*  PERFORM connect_pcss USING p_con
*                    CHANGING g_ok.
*
*  IF g_ok = ''.
**英文規格  " V_PNO-PNO_EDESC
**SELECT PNO_EDESC FROM V_PNO WHERE ENTITY = ZTSD0099-ZAUTHORG AND PNO_NO = ZTSD0099-ZPNO
**中文品名  "V_PNO-PNO_DESC
**SELECT PNO_DESC FROM V_PNO WHERE ENTITY = ZTSD0099-ZAUTHORG AND PNO_NO = ZTSD0099-ZPNO
**MODEL英文規格  " V_PNO-PNO_EDESC
**SELECT PNO_EDESC FROM V_PNO WHERE PNO_NO = ZTSD0098-ZPNO
*    CLEAR: error_text.
*    TRY.
*        EXEC SQL PERFORMING append_zpno.
*          SELECT ENTITY, PNO_NO, PNO_CN, PNO_EDESC, PNO_DESC
*            INTO :GT_ZPNO-ZAUTHORG,
*                 :GT_ZPNO-ZPNO,
*                 :GT_ZPNO-PNO_CN,
*                 :GT_ZPNO-PNO_EDESC,
*                 :GT_ZPNO-PNO_DESC
*          FROM  dbo.V_PNO
*        ENDEXEC.
*      CATCH cx_sy_native_sql_error INTO exc_ref.
*        error_text = exc_ref->get_text( ).
*    ENDTRY.
*
**廠內顏色  "V_W1MCOLOR-M020_NAM
**SELECT M020_NAM FROM V_W1MCOLOR  WHERE ENTITY = ZTSD0099-ZAUTHORG AND W1MCOL_PNO = ZTSD0099-ZPNO
*    CLEAR: error_text.
*    TRY.
*        EXEC SQL PERFORMING append_gt_m020_nam.
*          SELECT ENTITY, W1MCOL_PNO, M020_NAM
*            INTO :GT_M020_NAM-ZAUTHORG,
*                 :GT_M020_NAM-ZPNO,
*                 :GT_M020_NAM-M020_NAM
*          FROM  dbo.V_W1MCOLOR
*        ENDEXEC.
*      CATCH cx_sy_native_sql_error INTO exc_ref.
*        error_text = exc_ref->get_text( ).
*    ENDTRY.
*  ENDIF.
*** DB DisConnect
*  PERFORM disconnect_pcss USING p_con.
*<< V019 modify end "mark , no use

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  COLLECT_DATA_FOR_UNPAID_PAID
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM collect_data_for_unpaid_paid .

  IF p_unpaid = 'X'. "UNPAID彙總總數
    PERFORM collect_data USING '1'.
  ENDIF.

  IF p_paid   = 'X'. "PAID彙總總數
    PERFORM collect_data USING '2'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  COLLECT_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_1135   text
*----------------------------------------------------------------------*
FORM collect_data  USING    VALUE(p_type).
  DATA: lt_detail LIKE TABLE OF gs_detail.
  DATA: ls_detail LIKE gs_detail.
  DATA: BEGIN OF lt_group OCCURS 0,
          zxqline       LIKE gs_detail-zxqline,        "線別
          zsort_200     LIKE gs_detail-zsort_200,      "線別排序
          zlinenam      LIKE gs_detail-zlinenam,       "轉換後線別名稱
          zlinenam2     LIKE gs_detail-zlinenam2,      "轉換後線別名稱2
          typeid        LIKE gs_detail-typeid,         "UNPAID/ PAID判斷
          type          LIKE gs_detail-type,           "UNPAID/ PAID判斷
          zkinds        LIKE gs_detail-zkinds,         "Pressure分類
          zkindsnam1    LIKE gs_detail-zkindsnam1,     "Pressure說明1
          summary_sheet LIKE gs_detail-summary_sheet,  "Summary sheet(線別)
          zkindsnam2    LIKE gs_detail-zkindsnam2,     "Summary sheet row name
          z090styp      LIKE gs_detail-z090styp,       "090小分類
          z090styptext  LIKE gs_detail-z090styptext,   "090小分類說明
          zxqdtyp       LIKE gs_detail-zxqdtyp,        "預採帳小分類
          zxqdtypnam    LIKE gs_detail-zxqdtypnam,     "預採帳小分類說明
          zlinenam3     LIKE gs_detail-zlinenam3,      "for by Date sheet(線別)
          z6ptyp        LIKE gs_detail-z6ptyp,         "6Ptype
          zcpno         LIKE gs_detail-zcpno,          "SAP model#
          zcpnocn       LIKE gs_detail-zcpnocn,        "GCP Model#
          zscust        LIKE gs_detail-zscust,         "Customerid
          sortl         LIKE gs_detail-sortl,          "Customer
          zunptyp       LIKE gs_detail-zunptyp,        "UNPAY排序 "2020/04/16 yinglung V002
          zunptypnam    LIKE gs_detail-zunptypnam,     "Reason
          zedat         LIKE gs_detail-zedat,          "預採帳迄止日
          zpno          LIKE gs_detail-zpno,           "廠內件號
          pno_edesc     LIKE gs_detail-pno_edesc,      "英文規格
          pno_desc      LIKE gs_detail-pno_desc,       "中文品名
          m020_nam      LIKE gs_detail-m020_nam,       "廠內顏色
          zdcno         LIKE gs_detail-zdcno,          "Paid DN#
          zcndat        LIKE gs_detail-zcndat,         "Paid date
*>>V019 modify start
*          zauthorg      LIKE gs_detail-zauthorg,
          werks         LIKE gs_detail-werks,
*<<V019 modify end
        END OF lt_group.
  DATA: BEGIN OF lt_zcord OCCURS 0,
          zcord LIKE zfs060_s_detail-zcord, "PO#
        END OF lt_zcord.
  DATA: BEGIN OF lt_zsappo OCCURS 0,
          zsappo LIKE zfs060_s_detail-zsappo, "SAP PO
        END OF lt_zsappo.
  DATA: l_days(10) TYPE n.
  DATA: l_date1 TYPE sy-datum.
  DATA: l_date2 TYPE sy-datum.

  REFRESH: lt_group, lt_detail. CLEAR: lt_group, lt_detail.

  LOOP AT gt_detail INTO gs_detail WHERE typeid = p_type.
    APPEND gs_detail TO lt_detail.
    MOVE-CORRESPONDING gs_detail TO lt_group.
    COLLECT lt_group.
    CLEAR lt_group.
  ENDLOOP.
  DELETE gt_detail WHERE typeid = p_type.

  CASE p_type.
    WHEN '1'.
*unpaid的資料排序方式 :  依TYPEID +線別排序 +Pressure分類 + 小分類說明  + GCP Model# + Store Days +Customerid +廠內件號
      SORT lt_group BY typeid zxqline zkinds zxqdtypnam zcpnocn zscust zpno.
    WHEN '2'.
*paid的資料排序方式：依TYPEID+線別排序 +Pressure分類+Store Days+GCP Model#+Customerid+廠內件號
      SORT lt_group BY typeid zxqline zkinds zcpnocn zscust zpno.
  ENDCASE.

  LOOP AT lt_group.
    REFRESH: lt_zcord, lt_zsappo.
    CLEAR: gs_detail, lt_zcord, lt_zsappo.
* 2021/06/04     V010 Begin
    SORT lt_detail BY zxqno ASCENDING.
* 2021/06/04     V010 End
    LOOP AT lt_detail INTO  ls_detail
                      WHERE zxqline       = lt_group-zxqline        "線別
                        AND zsort_200     = lt_group-zsort_200      "線別排序
                        AND zlinenam      = lt_group-zlinenam       "轉換後線別名稱
                        AND zlinenam2     = lt_group-zlinenam2      "轉換後線別名稱2
                        AND typeid        = lt_group-typeid         "UNPAID/ PAID判斷
                        AND type          = lt_group-type           "UNPAID/ PAID判斷
                        AND zkinds        = lt_group-zkinds         "Pressure分類
                        AND zkindsnam1    = lt_group-zkindsnam1     "Pressure說明1
                        AND summary_sheet = lt_group-summary_sheet  "Summary sheet(線別)
                        AND zkindsnam2    = lt_group-zkindsnam2     "Summary sheet row name
                        AND z090styp      = lt_group-z090styp       "090小分類
                        AND z090styptext  = lt_group-z090styptext   "090小分類說明
                        AND zxqdtyp       = lt_group-zxqdtyp        "預採帳小分類
                        AND zxqdtypnam    = lt_group-zxqdtypnam     "預採帳小分類說明
                        AND zlinenam3     = lt_group-zlinenam3      "for by Date sheet(線別)
                        AND z6ptyp        = lt_group-z6ptyp         "6Ptype
                        AND zcpno         = lt_group-zcpno          "SAP model#
                        AND zcpnocn       = lt_group-zcpnocn        "GCP Model#
                        AND zscust        = lt_group-zscust         "Customerid
                        AND sortl         = lt_group-sortl          "Customer
                        AND zunptypnam    = lt_group-zunptypnam     "Reason
                        AND zedat         = lt_group-zedat          "預採帳迄止日
                        AND zpno          = lt_group-zpno           "廠內件號
                        AND pno_edesc     = lt_group-pno_edesc      "英文規格
                        AND pno_desc      = lt_group-pno_desc       "中文品名
                        AND m020_nam      = lt_group-m020_nam       "廠內顏色
                        AND zdcno         = lt_group-zdcno          "Paid DN#
                        AND zcndat        = lt_group-zcndat         "Paid date
*>> V019 modify start
*                        AND zauthorg      = lt_group-zauthorg.
                         AND werks        = lt_group-werks.
*<< V019 modify end
      MOVE-CORRESPONDING lt_group TO gs_detail.

      gs_detail-z6ptypnam   = ls_detail-z6ptypnam.  "是否符合6P&HR4040
      gs_detail-z6prem      = ls_detail-z6prem.     "6p備註

*Date 放入彙總group中最早的ztsd0099-zdat
      IF gs_detail-zdat  = '' OR gs_detail-zdat > ls_detail-zdat.
        gs_detail-zdat   = ls_detail-zdat.
      ENDIF.
*V016 added
*Old Date  放入彙總group中最早的olddate
      IF gs_detail-zolddat  = '' OR gs_detail-zolddat > ls_detail-zolddat.
        gs_detail-zolddat   = ls_detail-zolddat.
      ENDIF.
*V016 end off
*Inventory Item 抓彙總group第一筆ztsd0099-zen
      IF gs_detail-zdesc = ''.
        gs_detail-zdesc  = ls_detail-zdesc.
      ENDIF.
* YDS/PCS 依彙總Group加總
      gs_detail-yds_pcs  = gs_detail-yds_pcs + ls_detail-yds_pcs.
      gs_detail-zbqty    = ls_detail-zbqty.
* 單價 依彙總Group將每一筆單價合併顯示於此欄位,用,分隔
      CONDENSE ls_detail-zup.
      IF gs_detail-zup   = ''.
        gs_detail-zup    = ls_detail-zup.
      ELSE.
        CONCATENATE gs_detail-zup ',' ls_detail-zup INTO gs_detail-zup.
      ENDIF.
* Amount (US$) =sum(每一筆Amount(US$)
      gs_detail-amount   = gs_detail-amount + ls_detail-amount.
* PO# 依彙總Group將每一筆ztsd0098-zcord合併顯示於此欄位,用,分隔  (空白不顯示或重覆單號不可重覆顯示)
      IF ls_detail-zcord <> ''.
        lt_zcord-zcord = ls_detail-zcord.
        COLLECT lt_zcord.
      ENDIF.
* 庫存單明細 依彙總Group將每一筆ZTSD0099-ZXQNO & '-' & ZTSD0099-ZXQSEQ合併顯示於此欄位,用,分隔

      IF gs_detail-zxqno = ''.
        gs_detail-zxqno  = ls_detail-zxqno.
      ELSE.
* 2021/06/04     V010 Begin
*        CONCATENATE ls_detail-zxqno ',' gs_detail-zxqno INTO gs_detail-zxqno.
        CONCATENATE gs_detail-zxqno',' ls_detail-zxqno INTO gs_detail-zxqno.
* 2021/06/04     V010 End
      ENDIF.
* 360 未異動
      IF ls_detail-p_daystx <> ''.
        gs_detail-p_daystx = ls_detail-p_daystx.
      ENDIF.
* 視同件號 依彙總Group將每一筆ZTSD0099-ZSPNO合併顯示於此欄位,用/分隔
      IF gs_detail-zspno = ''.
        gs_detail-zspno  = ls_detail-zspno.
      ELSE.
        CONCATENATE gs_detail-zspno '/' ls_detail-zspno INTO gs_detail-zspno.
      ENDIF.
* SAP PO 依彙總Group將每一筆SAPPO合併顯示於此欄位,用,分隔  (空白不顯示或重覆單號不可重覆顯示)
      IF ls_detail-zsappo <> ''.
        lt_zsappo-zsappo = ls_detail-zsappo.
        COLLECT lt_zsappo.
      ENDIF.
* 原MOQ數量 依彙總Group將每一筆ZTSD0099-ZMOQTY合併顯示於此欄位,用,分隔
      CONDENSE ls_detail-zmoqty.
      PERFORM convert_qty  USING ls_detail-zmoqty
                        CHANGING ls_detail-zmoqty.

      IF gs_detail-zmoqty = ''.
        gs_detail-zmoqty  = ls_detail-zmoqty.
      ELSE.
        CONCATENATE gs_detail-zmoqty ',' ls_detail-zmoqty INTO gs_detail-zmoqty.
      ENDIF.
* MODEL英文規格 抓彙總group第一筆v_pno-pno_edesc
      IF gs_detail-pno_edesc_model = ''.
        gs_detail-pno_edesc_model = ls_detail-pno_edesc_model.
      ENDIF.
      gs_detail-ztotal101 = gs_detail-ztotal101 + ls_detail-ztotal101.

    ENDLOOP.
***************** Detail End **************************************
* Units =sum(YDS/PCS) / group最後一筆ztsd0099-zbqty

*V015 ATC mark start
*    IF gs_detail-zbqty = 0.
*      gs_detail-units    = 0.
*    ELSE.
*        gs_detail-units    = gs_detail-yds_pcs / gs_detail-zbqty.
*    ENDIF.
*V015 ATC mark end

*V015 ATC
    IF gs_detail-zbqty <> 0.
      gs_detail-units    = gs_detail-yds_pcs / gs_detail-zbqty.
    ELSE.
      gs_detail-units    = 0.
    ENDIF.

* PO# 依彙總Group將每一筆ztsd0098-zcord合併顯示於此欄位,用,分隔  (空白不顯示或重覆單號不可重覆顯示)
    LOOP AT lt_zcord.
      IF gs_detail-zcord = ''.
        gs_detail-zcord  = lt_zcord-zcord.
      ELSE.
        CONCATENATE gs_detail-zcord ',' lt_zcord-zcord INTO gs_detail-zcord.
      ENDIF.
    ENDLOOP.
* SAP PO 依彙總Group將每一筆SAPPO合併顯示於此欄位,用,分隔  (空白不顯示或重覆單號不可重覆顯示)
    LOOP AT lt_zsappo.
      IF gs_detail-zsappo = ''.
        gs_detail-zsappo  = lt_zsappo-zsappo.
      ELSE.
        CONCATENATE gs_detail-zsappo ',' lt_zsappo-zsappo INTO gs_detail-zsappo.
      ENDIF.
    ENDLOOP.

* Store Days =預採帳迄止日 -最早的ztsd0099-zdat
    PERFORM convert_date_to_date USING gs_detail-zedat
                              CHANGING l_date1.
    PERFORM convert_date_to_date USING gs_detail-zdat
                              CHANGING l_date2.
    gs_detail-store_days   = l_date1 - l_date2.
*Summary sheet Period	若Store Days > 挑選畫面上的分隔月數*30，則放'Over',否則放'Under'
    CLEAR l_days.
    l_days = p_month * 30.
    IF gs_detail-store_days > l_days.
      gs_detail-summary_sheet_period = c_over.
    ELSE.
      gs_detail-summary_sheet_period = c_under.
    ENDIF.
*by US sheet Period for Store Days
    IF gs_detail-store_days > 365.
      gs_detail-us_sheet_period      = c_perd1. "'over 1 year'
    ELSEIF gs_detail-store_days > 180 AND gs_detail-store_days <= 365.
      gs_detail-us_sheet_period      = c_perd2. "'7-12 months'
    ELSEIF gs_detail-store_days > 90 AND gs_detail-store_days <= 180.
      gs_detail-us_sheet_period      = c_perd3. "'4-6 months'
    ELSEIF gs_detail-store_days <= 90.
      gs_detail-us_sheet_period      = c_perd4. "'within 3 months'
    ENDIF.

    CASE gs_detail-typeid.
      WHEN '1'. "Un-Paid
      WHEN '2'. "Paid
*Pay Days= Paid date  - Date
        PERFORM convert_date_to_date USING gs_detail-zcndat
                                  CHANGING l_date1.
        PERFORM convert_date_to_date USING gs_detail-zdat
                                  CHANGING l_date2.
        gs_detail-pay_days =  l_date1 - l_date2.
*by Date sheet Period for Pay Days
        IF gs_detail-pay_days > 365.
          gs_detail-date_sheet_period      = c_perd1. "'over 1 year'
        ELSEIF gs_detail-pay_days > 180 AND gs_detail-pay_days <= 365.
          gs_detail-date_sheet_period      = c_perd2. "'7-12 months'
        ELSEIF gs_detail-pay_days > 90 AND gs_detail-pay_days <= 180.
          gs_detail-date_sheet_period      = c_perd3. "'4-6 months'
        ELSEIF gs_detail-pay_days <= 90.
          gs_detail-date_sheet_period      = c_perd4. "'within 3 months'
        ENDIF.
    ENDCASE.
    APPEND gs_detail TO gt_detail.
    CLEAR gs_detail.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CONNECT_PCSS
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_P_CON  text
*      <--P_G_OK  text
*----------------------------------------------------------------------*
FORM connect_pcss USING    p_con   TYPE  dbcon-con_name
                  CHANGING p_ok.

  CLEAR error_text.
  IF p_ok = ''.
    TRY.
        EXEC SQL.
          CONNECT TO :P_CON
        ENDEXEC.
      CATCH cx_sy_native_sql_error INTO exc_ref.
        error_text = exc_ref->get_text( ).
    ENDTRY.
    IF sy-subrc <> 0.
      p_ok = 'N'.
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  DISCONNECT_PCSS
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_P_CON  text
*----------------------------------------------------------------------*
FORM disconnect_pcss  USING    p_con  TYPE  dbcon-con_name.
  CLEAR error_text.
  TRY.
      EXEC SQL.
        DISCONNECT :P_CON
      ENDEXEC.
    CATCH cx_sy_native_sql_error INTO exc_ref.
      error_text = exc_ref->get_text( ).
  ENDTRY.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CONVERT_DATE_TO_DATE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_GS_DETAIL_ZEDAT  text
*      <--P_L_DATE1  text
*----------------------------------------------------------------------*
FORM convert_date_to_date  USING    p_datec
                           CHANGING p_date.
  CLEAR p_date.
  CONCATENATE p_datec(4) p_datec+5(2) p_datec+8(2) INTO p_date.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PREPARE_EXCEL_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM prepare_excel_data .
  FIELD-SYMBOLS: <all>    TYPE zfs060_s_all,
                 <slines> TYPE zfs060_s_lines.
  FIELD-SYMBOLS: <paid>        TYPE zfs060_s_paid,
                 <paid_header> TYPE zfs060_s_header,
                 <paid_lines>  TYPE zfs060_s_paid_lines.
  FIELD-SYMBOLS: <unpaid>        TYPE zfs060_s_unpaid,
                 <unpaid_header> TYPE zfs060_s_header,
                 <group>         TYPE zfs060_s_paid_group,
                 <group_header>  TYPE zfs060_s_group_header,
                 <group_lines>   TYPE zfs060_s_paid_group_lines,
                 <unpaid_lines>  TYPE zfs060_s_paid_lines.

*V017 CaroL取消
*   DATA: gt_detail_by_line TYPE TABLE OF zfs060_s_detail. "V015
*  DATA: gt_detail_by_line_record TYPE zfs060_s_unpaid2. "V015
*V017 CaroL取消 End

  CLEAR: gs_context-header,     gs_context-detail[],
         gs_context-header_dn,  gs_context-dn_list[],
         gs_context-header_non, gs_context-non_list[],
         gs_context-header_ob,  gs_context-ob_list[],
         gs_context-paid[],     gs_context-unpaid[].

  CLEAR: gs_detail.
*** Detail
  gs_context-header-p_daystx = gs_header-p_daystx.


  CONCATENATE gs_ztsd0088-zsdat+0(4) '/' gs_ztsd0088-zsdat+4(2) '/' gs_ztsd0088-zsdat+6(2) INTO gs_context-header-zsdat.
  CONCATENATE gs_ztsd0088-zedat+0(4) '/' gs_ztsd0088-zedat+4(2) '/' gs_ztsd0088-zedat+6(2) INTO gs_context-header-zedat.

  "" LOOP AT gt_detail INTO gs_detail.
  ""   APPEND gs_detail TO gs_context-detail.
  ""   CLEAR: gs_detail.
  "" ENDLOOP.

  LOOP AT gt_detail INTO DATA(ls_detail_0).
    DATA(ls_u_0) = ls_detail_0.
*    " 只影響 Detail 這個頁籤：Customerid 強制為文字
*    CONCATENATE '''' ls_u_0-zscust INTO ls_u_0-zscust.

    DATA(lv_cust_0) = CONV string( ls_u_0-zscust ).

    IF lv_cust_0 IS NOT INITIAL AND strlen( lv_cust_0 ) >= 3 AND lv_cust_0 CO '0123456789'.
      IF lv_cust_0+0(3) = '000'.
        SHIFT lv_cust_0 LEFT BY 1 PLACES.   " 去掉第一個字元
        lv_cust_0 = |'{ lv_cust_0 }|.       " 在前面加單引號 " 將第一個 0 換成單引號，後面接剩下的字串
        ls_u_0-zscust = lv_cust_0.
      ENDIF.
    ELSE.
      CONCATENATE '''' ls_u_0-zscust INTO ls_u_0-zscust.
    ENDIF.

    APPEND ls_u_0 TO gs_context-detail.
  ENDLOOP.

*  V014 start
  "" LOOP AT gt_detail_unpaid INTO gs_detail.
  ""   APPEND gs_detail TO gs_context-detail_unpaid.
  ""   CLEAR: gs_detail.
  "" ENDLOOP.

  LOOP AT gt_detail_unpaid INTO DATA(ls_detail).
    DATA(ls_u) = ls_detail.
*    " 只影響 Detail-unpaid 這個頁籤：Customerid 強制為文字
*    CONCATENATE '''' ls_u-zscust INTO ls_u-zscust.

    DATA(lv_cust) = CONV string( ls_u-zscust ).

    IF lv_cust IS NOT INITIAL AND strlen( lv_cust ) >= 3 AND lv_cust CO '0123456789'.
      IF lv_cust+0(3) = '000'.
        SHIFT lv_cust LEFT BY 1 PLACES.   " 去掉第一個字元
        lv_cust = |'{ lv_cust }|.
        ls_u-zscust = lv_cust.
      ENDIF.
    ELSE.
      CONCATENATE '''' ls_u-zscust INTO ls_u-zscust.
    ENDIF.

    APPEND ls_u TO gs_context-detail_unpaid.
  ENDLOOP.

*  V014 end of

*V017 CaroL取消
**V015 start
*  IF p_unp_d = 'X'.
*    LOOP AT gt_detail_unpaid INTO DATA(gs_detail) GROUP BY gs_detail-zsheetnam.
*      CLEAR gt_detail_by_line.
*      CLEAR gt_detail_by_line_record.
*
*      LOOP AT GROUP gs_detail INTO DATA(gs_detail_byline).
*        APPEND gs_detail_byline TO gt_detail_by_line.
*        CLEAR: gs_detail_byline.
*      ENDLOOP.
*
*      IF gt_detail_by_line IS NOT INITIAL.
*        gt_detail_by_line_record-tabnam =  gt_detail_by_line[ 1 ]-zsheetnam.
*        gt_detail_by_line_record-lines = gt_detail_by_line.
*
*        APPEND gt_detail_by_line_record TO gs_context-unpaid2.
*      ENDIF.
*
*    ENDLOOP.
*  ENDIF.
**V015 end
*V017 CaroL取消 End

*** DN已收款不還款
  IF gt_dn[] IS NOT INITIAL.
    gs_context-header_dn-prtdate = gs_header-prtdate. "印表日期
    gs_context-header_dn-prtname = gs_header-prtname. "印表人員
    gs_context-header_dn-p_date  = gs_header-p_date.  "PAY比較日
*2020/04/14 yinglung V002 begin
    "SORT GT_DN BY TYPEID ZSORT_200 TYPE.
    SORT gt_dn BY typeid type zsort_200 summary_sheet_period zunptyp.
*2020/04/14 yinglung V002 end
    LOOP AT gt_dn.
      AT NEW type.
        APPEND INITIAL LINE TO gs_context-dn_list ASSIGNING <all>.
        <all>-type = gt_dn-type.
        IF gt_dn-typeid = '2'.  "Paid
          <all>-zdcno_col = 'Paid DN #'.
          <all>-zcndat_col = 'Paid Date'.
        ENDIF.
      ENDAT.
      APPEND INITIAL LINE TO <all>-lines ASSIGNING <slines>.
      MOVE-CORRESPONDING gt_dn TO <slines>.
    ENDLOOP.
  ENDIF.

*** Non-compliant
  IF gt_non[] IS NOT INITIAL.
    gs_context-header_non-prtdate = gs_header-prtdate. "印表日期
    gs_context-header_non-prtname = gs_header-prtname. "印表人員
    gs_context-header_non-p_date  = gs_header-p_date.  "PAY比較日

*2020/04/14 yinglung V002 begin
    "SORT GT_NON BY TYPEID ZSORT_200 TYPE.
    SORT gt_non BY typeid type zsort_200 summary_sheet_period zunptyp.
*2020/04/14 yinglung V002 end
    LOOP AT gt_non.
      AT NEW type.
        APPEND INITIAL LINE TO gs_context-non_list ASSIGNING <all>.
        <all>-type = gt_non-type.
        IF gt_non-typeid = '2'.  "Paid
          <all>-zdcno_col = 'Paid DN #'.
          <all>-zcndat_col = 'Paid Date'.
        ENDIF.
      ENDAT.
      APPEND INITIAL LINE TO <all>-lines ASSIGNING <slines>.
      MOVE-CORRESPONDING gt_non TO <slines>.
    ENDLOOP.
  ENDIF.

*** ob model
  IF gt_ob[] IS NOT INITIAL.
    gs_context-header_ob-prtdate = gs_header-prtdate. "印表日期
    gs_context-header_ob-prtname = gs_header-prtname. "印表人員
    gs_context-header_ob-p_date  = gs_header-p_date.  "PAY比較日
*2020/04/14 yinglung V002 begin
    "SORT GT_OB BY TYPEID ZSORT_200 TYPE.
    SORT gt_ob BY typeid type zsort_200 summary_sheet_period zunptyp.
*2020/04/14 yinglung V002 end
    LOOP AT gt_ob.
      AT NEW type.
        APPEND INITIAL LINE TO gs_context-ob_list ASSIGNING <all>.
        <all>-type = gt_ob-type.
        IF gt_ob-typeid = '2'.  "Paid
          <all>-zdcno_col = 'Paid DN #'.
          <all>-zcndat_col = 'Paid Date'.
        ENDIF.

      ENDAT.
      APPEND INITIAL LINE TO <all>-lines ASSIGNING <slines>.
      MOVE-CORRESPONDING gt_ob TO <slines>.
    ENDLOOP.
  ENDIF.

** Paid
  SORT gt_header_paid BY type.
*  SORT GT_PAID        BY TYPE ZCPNOCN ZKINDSNAM1 STORE_DAYS SORTL ZPNO.
  SORT gt_paid        BY type zcpnocn zdcno zunptypnam zpno.

  LOOP AT gt_header_paid.
    APPEND INITIAL LINE TO gs_context-paid ASSIGNING <paid>.
    MOVE-CORRESPONDING gt_header_paid TO <paid>-header_paid.

    LOOP AT gt_paid WHERE type = gt_header_paid-type.
      APPEND INITIAL LINE TO <paid>-lines ASSIGNING <paid_lines>.
      MOVE-CORRESPONDING gt_paid TO <paid_lines>.
    ENDLOOP.
  ENDLOOP.

** Un-Paid
  SORT gt_header_unpaid        BY type.
  SORT gt_g_header_unpaid      BY type summary_sheet_period.
  SORT gt_g_line_header_unpaid BY type summary_sheet_period zkinds zkindsnam1.
*  SORT GT_UNPAID               BY TYPE SUMMARY_SHEET_PERIOD ZKINDS ZKINDSNAM1 ZCPNOCN STORE_DAYS SORTL ZPNO.
  SORT gt_unpaid               BY type summary_sheet_period zxqline zkinds zkindsnam1 zxqdtypnam zcpnocn store_days sortl zpno.

  LOOP AT gt_header_unpaid.
    APPEND INITIAL LINE TO gs_context-unpaid ASSIGNING <unpaid>.
    MOVE-CORRESPONDING gt_header_unpaid TO <unpaid>-header_unpaid.

    LOOP AT gt_g_header_unpaid WHERE type = gt_header_unpaid-type.
      APPEND INITIAL LINE TO <unpaid>-group ASSIGNING <group>.
      MOVE-CORRESPONDING gt_g_header_unpaid TO <group>-group_header.

      LOOP AT gt_g_line_header_unpaid WHERE
                type                 = gt_header_unpaid-type
            AND summary_sheet_period = gt_g_header_unpaid-summary_sheet_period.
        APPEND INITIAL LINE TO <group>-group_lines ASSIGNING <group_lines>.
        MOVE-CORRESPONDING gt_g_line_header_unpaid TO <group_lines>-group_lines_header.

        LOOP AT gt_unpaid WHERE
                type                 = gt_header_unpaid-type
            AND summary_sheet_period = gt_g_header_unpaid-summary_sheet_period
            AND zkinds               = gt_g_line_header_unpaid-zkinds.
          APPEND INITIAL LINE TO <group_lines>-lines ASSIGNING <unpaid_lines>.
          MOVE-CORRESPONDING gt_unpaid TO <unpaid_lines>.
        ENDLOOP.

      ENDLOOP.
    ENDLOOP.

  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PREPARE_HEADER
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM prepare_header .


  WRITE p_days  TO gs_header-p_daystx NO-ZERO.
  CONDENSE gs_header-p_daystx.
  CONCATENATE gs_header-p_daystx ' 未異動' INTO gs_header-p_daystx.

  WRITE: sy-datum TO gs_header-prtdate.  "印表日期
  WRITE: sy-uname TO gs_header-prtname.  "印表人員

*V018 changed:
*  WRITE: gs_ztsd0088-zedat   TO gs_header-p_date.   "PAY比較日:改用預採帳期間迄止日
  WRITE: p_date   TO gs_header-p_date.   "改用PAY比較日

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  APPEND_ZPNO
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM append_zpno .
  IF gt_zpno-zpno IN r_zpno.
    APPEND gt_zpno.
  ENDIF.
  CLEAR gt_zpno.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  APPEND_GT_M020_NAM
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM append_gt_m020_nam .
  IF gt_m020_nam-zpno IN r_zpno.
    APPEND gt_m020_nam.
  ENDIF.
  CLEAR gt_m020_nam.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PREPARE_ALL_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM prepare_all_data .
  DATA: BEGIN OF lt_zauthorg OCCURS 0,
*>> V019 modify start
*          zauthorg TYPE zauthorg,
          werks TYPE werks_d,
*<< V019 modify end
        END OF lt_zauthorg.
  DATA: l_date(15).
  DATA: l_month(2).

  REFRESH: lt_zauthorg. CLEAR: lt_zauthorg.

*20200710 yinglung V008 begin
  IF p_exqty0 EQ 'X'.
    DELETE gt_detail WHERE yds_pcs <= 0 OR  amount <= 0 .
  ENDIF.
*20200710 yinglung V008 end

  LOOP AT gt_detail INTO gs_detail.
    CHECK gs_detail-typeid = '1' OR gs_detail-typeid = '2'.
** DN已收款不還款/Non-compliant/ob model
    MOVE-CORRESPONDING gs_detail TO gt_all.
    CONCATENATE gs_detail-zlinenam '-' gs_detail-type INTO gt_all-type.
    TRANSLATE gt_all-type TO UPPER CASE.
    APPEND gt_all. CLEAR gt_all.
*>>V019 modify start
*    lt_zauthorg-zauthorg = gs_detail-zauthorg.
    lt_zauthorg-werks = gs_detail-werks.
*<<V019 modify end
    COLLECT lt_zauthorg.
** Paid
    IF gs_detail-typeid = '2' AND gs_detail-z6ptyp = ''.
      MOVE-CORRESPONDING gs_detail TO gt_paid.
      CONCATENATE gs_detail-zlinenam '-' 'paid' INTO gt_paid-type.
      APPEND gt_paid. CLEAR gt_paid.
    ENDIF.
** Un-Paid
    IF gs_detail-typeid = '1' AND gs_detail-z6ptyp = ''.
      MOVE-CORRESPONDING gs_detail TO gt_unpaid.
      CONCATENATE gs_detail-zlinenam '-' 'unpaid' INTO gt_unpaid-type.
      APPEND gt_unpaid. CLEAR gt_unpaid.
    ENDIF.
  ENDLOOP.

  SORT gt_all BY typeid zsort_200 type.
  LOOP AT gt_all.
** DN已收款不還款 6Ptype = 'U'
    IF gt_all-z6ptyp = 'U'.
      MOVE-CORRESPONDING gt_all TO gt_dn.
      APPEND gt_dn. CLEAR gt_dn.
    ENDIF.
** Non-compliant 6Ptype <> '' AND 6Ptype <> 'U' and 6Ptype <> 'OB'
    IF gt_all-z6ptyp <> '' AND gt_all-z6ptyp <> 'U' AND gt_all-z6ptyp <> 'OB'.
      MOVE-CORRESPONDING gt_all TO gt_non.
      APPEND gt_non. CLEAR gt_non.
    ENDIF.
** ob model  6Ptype = 'OB'
    IF gt_all-z6ptyp = 'OB'.
      MOVE-CORRESPONDING gt_all TO gt_ob.
      APPEND gt_ob. CLEAR gt_ob.
    ENDIF.
  ENDLOOP.

** Paid
*V018 changed
*  PERFORM convert_date USING gs_ztsd0088-zedat CHANGING l_date. "預採帳迄止日
  PERFORM convert_date USING p_date CHANGING l_date. "PAY比較日
*V018 end off
** convert MONTH
  WRITE p_month TO l_month NO-ZERO.
  CONDENSE l_month.

  SORT lt_zauthorg.
*  SORT GT_PAID BY TYPE STORE_DAYS ZCPNOCN ZPNO.
  SORT gt_paid        BY type zcpnocn zdcno zxqdtypnam zpno.

  LOOP AT gt_paid.
    AT NEW type.
      READ TABLE gt_paid INDEX sy-tabix.
      gt_header_paid-type = gt_paid-type.
      WRITE p_days  TO gt_header_paid-p_daystx NO-ZERO.
      CONDENSE gt_header_paid-p_daystx.
      CONCATENATE gt_header_paid-p_daystx ' 未異動' INTO gt_header_paid-p_daystx.

      WRITE: sy-datum TO gt_header_paid-prtdate.  "印表日期
      WRITE: sy-uname TO gt_header_paid-prtname.  "印表人員
*V018 changed
*      WRITE: gs_ztsd0088-zedat TO gt_header_paid-p_date.   "預採帳迄止日
      WRITE: p_date TO gt_header_paid-p_date.   "PAY比較日
*V018 end off
*  V017 CaroL Graco新模板格式不同: UnPaid-A欄/B欄/AA欄,Paid-A欄/B欄/AC欄
      IF p_label = 'X'.
        WRITE: 'PO Placement Date' TO gt_header_paid-labela.
        WRITE: 'Est. Material Arrival Date/ Order Cancellation Date/ MCN Implement Date/ Level Loads finished Date ' TO gt_header_paid-labelb.
        WRITE: 'Transferable (Y/N)' TO gt_header_paid-labelc.
      ELSE.
        WRITE: '' TO gt_header_paid-labela.
        WRITE: 'DATE' TO gt_header_paid-labelb.
        WRITE: '' TO gt_header_paid-labelc.
      ENDIF.
*  V017 endof

*ZAUTHORG
      LOOP AT lt_zauthorg.
*>>V019 modify start
*        IF gt_header_paid-zauthorg = ''.
*          gt_header_paid-zauthorg = lt_zauthorg-zauthorg.
*        ELSE.
*          CONCATENATE gt_header_paid-zauthorg '/' lt_zauthorg-zauthorg
*                                          INTO gt_header_paid-zauthorg.
*        ENDIF.
        IF gt_header_paid-werks = ''.
          gt_header_paid-werks = lt_zauthorg-werks.
        ELSE.
          CONCATENATE gt_header_paid-werks '/' lt_zauthorg-werks
                                          INTO gt_header_paid-werks.
        ENDIF.
*<< V019 modify end
      ENDLOOP.
*HTEXT DI & DA / WLC - Raw Material / Finish Unit Inventory From Order - List Up ToNOV/15/2018(Paid)
* V009  by Kiwi 2021/01/15 */
*      CONCATENATE GT_PAID-ZXQLINE
*                  '& DA / WLC - Raw Material / Finish Unit Inventory From Order - List Up To'
*                  L_DATE
*                  '(Paid)'
*                  INTO GT_HEADER_PAID-HTEXT SEPARATED BY SPACE.

*>> V019 modify start  "wait confirm if need
*      IF gt_header_paid-zauthorg = 'BP'.
*        CONCATENATE gt_paid-zxqline
*                    '& DA / BP - Raw Material / Finish Unit Inventory From Order - List Up To'
*                    l_date
*                    '(Paid)'
*                    INTO gt_header_paid-htext SEPARATED BY space.
*        CONCATENATE gt_paid-zxqline '/BP' INTO gt_header_paid-tol_text.
*      ELSE.
*        CONCATENATE gt_paid-zxqline
*              '& DA / WLC - Raw Material / Finish Unit Inventory From Order - List Up To'
*              l_date
*              '(Paid)'
*              INTO gt_header_paid-htext SEPARATED BY space.
*        CONCATENATE gt_paid-zxqline '/WLC' INTO gt_header_paid-tol_text.
*      ENDIF.
*<< V019 modify end

*TOL_TEXT Total DII-APAC/WLC APAC-paid inventory cost
*      CONCATENATE GT_PAID-ZXQLINE '/WLC' INTO GT_HEADER_PAID-TOL_TEXT.
*V009 End off *
      CONCATENATE 'Total' gt_header_paid-tol_text gt_header_paid-type 'inventory cost'
                  INTO gt_header_paid-tol_text SEPARATED BY space.
    ENDAT.
    gt_header_paid-tol_amount = gt_header_paid-tol_amount + gt_paid-amount.
    AT END OF type.
      APPEND gt_header_paid. CLEAR gt_header_paid.
    ENDAT.
  ENDLOOP.

** Un-Paid
  SORT lt_zauthorg.
*  SORT GT_UNPAID BY TYPE ZXQLINE SUMMARY_SHEET_PERIOD ZKINDS ZKINDSNAM1 STORE_DAYS ZCPNOCN ZPNO.
  SORT gt_unpaid BY type zxqline summary_sheet_period zkinds zkindsnam1 zxqdtypnam zcpnocn store_days sortl zpno.

  LOOP AT gt_unpaid.
    AT NEW zkindsnam1.
      gt_g_line_header_unpaid-type = gt_unpaid-type.
      gt_g_line_header_unpaid-summary_sheet_period = gt_unpaid-summary_sheet_period.
      gt_g_line_header_unpaid-zkinds               = gt_unpaid-zkinds.
      gt_g_line_header_unpaid-zkindsnam1           = gt_unpaid-zkindsnam1.
      CASE gt_g_line_header_unpaid-summary_sheet_period.
        WHEN c_under. "'Under'.
          CONCATENATE gt_unpaid-zkindsnam1 'under'
                      l_month 'months'
                      INTO gt_g_line_header_unpaid-htext
                      SEPARATED BY space.
        WHEN c_over.  "Over
          CONCATENATE gt_unpaid-zkindsnam1 'more than'
                      l_month 'months'
                      INTO gt_g_line_header_unpaid-htext
                      SEPARATED BY space.
      ENDCASE.
    ENDAT.

    AT NEW summary_sheet_period.
      gt_g_header_unpaid-type = gt_unpaid-type.
      gt_g_header_unpaid-summary_sheet_period = gt_unpaid-summary_sheet_period.

      CASE gt_g_line_header_unpaid-summary_sheet_period.
        WHEN c_under. "'Under'. "Total Cost for the inventory under 6months
          CONCATENATE 'Total Cost for the inventory under' l_month 'months'
                      INTO gt_g_header_unpaid-htext SEPARATED BY space.
        WHEN c_over.  "Over "Total Cost for the inventory more than 6months
          CONCATENATE 'Total Cost for the inventory more than' l_month 'months'
                      INTO gt_g_header_unpaid-htext SEPARATED BY space.
      ENDCASE.
    ENDAT.

    AT NEW type.
      READ TABLE gt_unpaid INDEX sy-tabix.
      gt_header_unpaid-type = gt_unpaid-type.
      WRITE p_days  TO gt_header_unpaid-p_daystx NO-ZERO.
      CONDENSE gt_header_unpaid-p_daystx.
      CONCATENATE gt_header_unpaid-p_daystx ' 未異動' INTO gt_header_unpaid-p_daystx.

      WRITE: sy-datum TO gt_header_unpaid-prtdate.  "印表日期
      WRITE: sy-uname TO gt_header_unpaid-prtname.  "印表人員
*V018 changed
*      WRITE: gs_ztsd0088-zedat TO gt_header_unpaid-p_date.   "預採帳迄止日
      WRITE: p_date TO gt_header_unpaid-p_date.   "PAY比較日
*V018 end off
*  V017 CaroL Graco新模板格式不同: UnPaid-A欄/B欄/AA欄,Paid-A欄/B欄/AC欄
      IF p_label = 'X'.
        WRITE: 'PO Placement Date' TO gt_header_unpaid-labela.
        WRITE: 'Est. Material Arrival Date/ Order Cancellation Date/ MCN Implement Date/ Level Loads finished Date ' TO gt_header_unpaid-labelb.
        WRITE: 'Transferable (Y/N)' TO gt_header_unpaid-labelc.
      ELSE.
        WRITE: '' TO gt_header_unpaid-labela.
        WRITE: 'DATE' TO gt_header_unpaid-labelb.
        WRITE: '' TO gt_header_unpaid-labelc.
      ENDIF.
*  V017 endof


*ZAUTHORG
      LOOP AT lt_zauthorg.
*>> V019 modify start
*        IF gt_header_unpaid-zauthorg = ''.
*          gt_header_unpaid-zauthorg = lt_zauthorg-zauthorg.
*        ELSE.
*          CONCATENATE gt_header_unpaid-zauthorg '/' lt_zauthorg-zauthorg
*                                          INTO gt_header_unpaid-zauthorg.
*        ENDIF.
        IF gt_header_unpaid-werks = ''.
          gt_header_unpaid-werks = lt_zauthorg-werks.
        ELSE.
          CONCATENATE gt_header_unpaid-werks '/' lt_zauthorg-werks
                                          INTO gt_header_unpaid-werks.
        ENDIF.
*<< V019 modify end
      ENDLOOP.
*HTEXT DI & DA / WLC - Raw Material / Finish Unit Inventory From Order - List Up ToNOV/15/2018(Paid)
* V009  by Kiwi 2021/01/15 */
*      CONCATENATE GT_UNPAID-ZXQLINE
*                  '& DA / WLC - Raw Material / Finish Unit Inventory From Order - List Up To'
*                  L_DATE
*                  '(not Paid)'
*                  INTO GT_HEADER_UNPAID-HTEXT SEPARATED BY SPACE.

*>> V019 modify start "wait confirm if need
*      IF gt_header_unpaid-zauthorg = 'BP'.
*        CONCATENATE gt_unpaid-zxqline
*        '& DA / BP - Raw Material / Finish Unit Inventory From Order - List Up To'
*        l_date
*        '(not Paid)'
*        INTO gt_header_unpaid-htext SEPARATED BY space.
*        CONCATENATE gt_unpaid-zxqline '/BP' INTO gt_header_unpaid-tol_text.
*      ELSE.
*        CONCATENATE gt_unpaid-zxqline
*        '& DA / WLC - Raw Material / Finish Unit Inventory From Order - List Up To'
*        l_date
*        '(not Paid)'
*        INTO gt_header_unpaid-htext SEPARATED BY space.
*        CONCATENATE gt_unpaid-zxqline '/WLC' INTO gt_header_unpaid-tol_text.
*
*      ENDIF.
*<< V019 modify end

*TOL_TEXT Total DII-APAC/WLC APAC-paid inventory cost
*      CONCATENATE GT_UNPAID-ZXQLINE '/WLC' INTO GT_HEADER_UNPAID-TOL_TEXT.
* V009 End off */
      CONCATENATE 'Total' gt_header_unpaid-tol_text gt_header_unpaid-type 'inventory cost'
                  INTO gt_header_unpaid-tol_text SEPARATED BY space.
    ENDAT.

    gt_g_line_header_unpaid-sub_amount = gt_g_line_header_unpaid-sub_amount + gt_unpaid-amount.
    gt_header_unpaid-tol_amount = gt_header_unpaid-tol_amount + gt_unpaid-amount.
    gt_g_header_unpaid-tol_amount = gt_g_header_unpaid-tol_amount + gt_unpaid-amount.

    AT END OF zkindsnam1.
      APPEND gt_g_line_header_unpaid. CLEAR gt_g_line_header_unpaid.
    ENDAT.
    AT END OF summary_sheet_period.
      APPEND gt_g_header_unpaid. CLEAR gt_g_header_unpaid.
    ENDAT.
    AT END OF type.
      APPEND gt_header_unpaid. CLEAR gt_header_unpaid.
    ENDAT.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CONVERT_DATE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_P_DATE  text
*      <--P_L_DATE  text
*----------------------------------------------------------------------*
FORM convert_date  USING    p_p_date
                   CHANGING p_l_date.
  DATA: l_en(3).
  CLEAR p_l_date.

*  20190509.
  CASE p_p_date+4(2).
    WHEN '01'.
      l_en = 'JAN'.
    WHEN '02'.
      l_en = 'FEB'.
    WHEN '03'.
      l_en = 'MAR'.
    WHEN '04'.
      l_en = 'APR'.
    WHEN '05'.
      l_en = 'MAY'.
    WHEN '06'.
      l_en = 'JUN'.
    WHEN '07'.
      l_en = 'JUL'.
    WHEN '08'.
      l_en = 'AUG'.
    WHEN '09'.
      l_en = 'SEP'.
    WHEN '10'.
      l_en = 'OCT'.
    WHEN '11'.
      l_en = 'NOV'.
    WHEN '12'.
      l_en = 'DEC'.
  ENDCASE.

  CONCATENATE l_en '/' p_p_date+6(2) '/' p_p_date(4) INTO p_l_date.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_ZTSD0130
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM get_ztsd0130 .
*>> V019 modify start , change to select ztmara
*  REFRESH: it_ztsd0130.
*  IF r_zpno[] IS NOT INITIAL.
*    SELECT *
*      INTO TABLE it_ztsd0130
*      FROM ztsd0130
*      FOR ALL ENTRIES IN r_zpno
*     WHERE zauthorg = p_zauth
*       AND zpno = r_zpno-low.
*  ENDIF.
*  SORT it_ztsd0130   BY zauthorg zpno.
*<< V019 modify end
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_FILENAME
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_P_FILE  text
*----------------------------------------------------------------------*
FORM get_filename  USING    p_p_file.

  DATA: tmp_filename LIKE rlgrap-filename.
  DATA: tmp_mask(80).
  FIELD-SYMBOLS: <tmp_sym>.
  tmp_mask = ',*.*,*.*.'.

  CALL FUNCTION 'WS_FILENAME_GET'
    EXPORTING
      def_filename     = p_p_file  "RLGRAP-FILENAME
      def_path         = ''        "DEF_PATH
*     MASK             = ',*.*,*.*.'
      mask             = tmp_mask
      mode             = 'O'
*     TITLE            = ' '
    IMPORTING
      filename         = tmp_filename
*     RC               =
    EXCEPTIONS
      inv_winsys       = 01
      no_batch         = 02
      selection_cancel = 03
      selection_error  = 04.

  IF sy-subrc = 0.
    p_p_file = tmp_filename.
  ENDIF.
ENDFORM.                    " GET_FILENAME
*&---------------------------------------------------------------------*
*&      Form  CONVERT_QTY
*&---------------------------------------------------------------------*
FORM convert_qty   USING p_qtyin
                CHANGING p_qtyout.
  DATA: c1(13), c2(3).
  SPLIT p_qtyin AT '.' INTO c1 c2.
  CONDENSE: c1, c2.
  IF c2 = '000'.
    CLEAR c2.
    p_qtyout = c1.
  ELSEIF c2+1(2) = '00'.
    c2+1(2) = ''.
    CONCATENATE c1 '.' c2 INTO p_qtyout.
  ELSEIF c2+2(1) = '0'.
    c2+2(1) = ''.
    CONCATENATE c1 '.' c2 INTO p_qtyout.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CALC_LEAD_DAYS
*&---------------------------------------------------------------------*
FORM calc_lead_days .
  RANGES r_zpno FOR ztsd0205-zpno.
  LOOP AT it_lead WHERE zkinds = gs_ztsd0111-zkinds.
    REFRESH r_zpno.
    r_zpno = it_lead-zpno.
    APPEND r_zpno. CLEAR r_zpno.
    IF gs_detail-zpno IN r_zpno.
      gt_ztsd0099-zdat = gt_ztsd0099-zdat + it_lead-zdays.
      EXIT.
    ENDIF.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form calc_lead_days_marc
*&---------------------------------------------------------------------*
FORM calc_lead_days_marc .
  SELECT SINGLE plifz INTO @DATA(lv_PLIFZ) FROM marc
    WHERE matnr = @gt_ztsd0099-zpno AND werks = @gt_ztsd0099-werks.
  IF sy-subrc = 0.
    gt_ztsd0099-zdat = gt_ztsd0099-zdat + lv_plifz.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_ztmara
*&---------------------------------------------------------------------*
FORM get_ztmara .
  REFRESH: it_ztmara.
  IF r_zpno[] IS NOT INITIAL.
    SELECT * INTO TABLE it_ztmara
      FROM ztmara
     WHERE matnr IN r_zpno.
  ENDIF.
  SORT it_ztmara   BY matnr.
*>> V019 2025/06/01 modify
*  SELECT * INTO CORRESPONDING FIELDS OF TABLE it_ztmm_color
*    FROM ztmm_color ORDER BY zzcolor_code.
  SELECT * INTO CORRESPONDING FIELDS OF TABLE it_ZTMM0050COLOR
    FROM ztmm0050color ORDER BY wl2_colorno.
*<< V019 2025/06/01 modify

ENDFORM.

*Text elements
*----------------------------------------------------------
* T01 篩選條件
* T02 下列條件僅供GRACO使用!


*Selection texts
*----------------------------------------------------------
* PREVIEW         預覽
* PSAVE         存檔
* P_CNFM         OrderCancel 顯示ConfirmDate
* P_DATE         PAY比較日
* P_DAYS         PAY未異動天數
* P_EXQTY0         排除餘數為0
* P_FILE         存放路徑及檔名
* P_LABEL         Graco新模板
* P_LEAD         納入物料Lead Time
* P_MONTH         分隔月數
* P_PAID         PAID彙總總數
* P_UNPAID         UNPAID彙總總數
* P_VTWEG D       .
* P_WERKS D       .
* P_ZBCUST         客戶
* S_ZLINE         預採帳線別
* S_ZYM         預採帳年月


*Messages
*----------------------------------------------------------
*
* Message class: SY
*002   &

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
