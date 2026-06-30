*&---------------------------------------------------------------------*
* Module      ：SD-ODMII               Package：ZODM_SD
* Program Name：ZTWRSD0100             T-Code：ZTWRSD0100
* Description ：預採帳收還款報表
* Author      ：Gary
* Create Date ：2019/02/26
* Spec. Logic ：
*&=====================================================================*
* Modification Log - History
*&=====================================================================*
*    DATE     VERSION      AUTHOR                  DESCRIPTION
* ========== ========  ==============  =================================
* 2020/03/26     V001        yinglung  debit /Credit Note 增加串接區域別
* 2020/04/23     V002        Fangchyi  檢查權限物件Z_AUTHORG
* 2020/06/30     V003        yinglung  RETURN Qty 判斷調整
* 2020/08/06     V004        yinglung  ODM-ZTWRSD0100 還款數量邏輯調整
* 2020/08/28     V005        yinglung  ODM-BP 調整
* 2022/04/22     V006        Kiwi      增加DNCD Header Remark 顯示
* 2022/06/14     V007        Kiwi      Return Qty 邏輯是
*                                      "收款後轉出數量– 收款類別 ( 2 )"
*                                      但應該再把不還款報廢數量(5)
*                                      & 不還款出貨數量(7) 納入減項
* 2022/02/03     V008        Fangchyi  增加交易幣別及金額欄位
* 2023/06/12     V009        Kiwi      新增已結案不顯示報表
* 2023/10/20     V010        Tristan   是否顯示已結案DebitNote
* 2023/11/16     V011        Tristan   Return數量= 收款後轉出數量 –
*                                      已還款數量(2)– 不還款出貨數量(7)
*                                      ，不需納入不還款報廢數量(5)
* 2025/02/25     V012        Francie   S4調整
*                            1. 不再使用ztsd0101-zauthorg
*                            2 key值調整: zauthorg > werks
*                    3. 取消 zfs061_s_detail-ZAUTHORG (原程式也沒用此值)
*
*&---------------------------------------------------------------------*
REPORT ztwrsd0100.

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

* Working Area
DATA: ztsd0098 TYPE ztsd0098. "預採帳 XQ 主檔
DATA: ztsd0099 TYPE ztsd0099. "預採帳 XQ 明細檔
DATA: ztsd0101 TYPE ztsd0101. "預採帳 XQ 單收還款明細檔
DATA: g10(10).
DATA: wa_ztsd0098 LIKE ztsd0098. "預採帳 XQ 主檔
DATA: wa_ztsd0099 LIKE ztsd0099. "預採帳 XQ 明細檔

DATA: gs_context   TYPE zfs061.
DATA: gs_detail    TYPE zfs061_s_detail.
DATA: gs_ownadmit  TYPE zfs061_s_ownadmit.
DATA: gs_split     TYPE zfs061_s_detail.

DATA: g_factor     TYPE p DECIMALS 3.
DATA: g_retamt     TYPE p DECIMALS 2.
DATA: g_scrpamt    TYPE p DECIMALS 2.
DATA: p_con        TYPE dbcon-con_name VALUE 'SAPODM'.
DATA: g_ok.
DATA: exc_ref    TYPE REF TO cx_sy_native_sql_error,
      error_text TYPE string.
DATA: x_area LIKE ztsd0101-zarea. "20200326 yinglung V001
** Internal Tables
DATA: BEGIN OF gt_main OCCURS 0,
        zbcust  TYPE zbcust,
        zdcno_i TYPE zdcno101,
        zdnno   TYPE ztsd0101-zdnno,
        zdc     TYPE zdc101,
        zpno    TYPE ztsd0099-zpno,
        zcpno   TYPE ztsd0098-zcpno,
*        ZCPNOCN TYPE ZCN_XQ,
      END OF gt_main.
** Detail
DATA: BEGIN OF gt_detail OCCURS 0.
        INCLUDE STRUCTURE zfs061_s_detail.
DATA: END OF gt_detail.
** Detail Split
DATA: BEGIN OF gt_dtl_split OCCURS 0.
        INCLUDE STRUCTURE zfs061_s_detail.
DATA: END OF gt_dtl_split.
** Summary
DATA: BEGIN OF gt_summary OCCURS 0,
        doc_curr          TYPE waers,         "交易幣別 V008
        area(20),   "V008 :紀錄detail table的原zarea
        zarea(20),
        zdcno_i           TYPE zdcno101,
        zdnno(30),
        zdndc             TYPE zdndc,
        zdcno(30),
        zfinaldat         TYPE sy-datum,
        seqno(5),
        ztotal            TYPE p DECIMALS 2,
        scdate            TYPE sy-datum,
        scamt             TYPE p DECIMALS 2,
        shamt             TYPE p DECIMALS 2,
        zcur              TYPE waers,
        cndate            TYPE sy-datum,
        zcnno(20),
        cnamt             TYPE p DECIMALS 2,
        balamt            TYPE p DECIMALS 2,
        zauthorg(20),    "V012 add remark: for print zdcvkorg value
        zdcrmk(200),
        zdcnobk(30),
        zdcvkorg(20),
        sub_total,
* 2022/04/22     V006   Begin
        zdndc_remark(200),
* 2022/04/22     V006   End
*V008 added
        ztotal_doc        TYPE p DECIMALS 2,  "DN Amount(交易幣別)
        cnamt_doc         TYPE p DECIMALS 2,  "Scrap Amount(交易幣別)
        balamt_doc        TYPE p DECIMALS 2,  "Shipped Amount(交易幣別)
        scamt_doc         TYPE p DECIMALS 2,  "CN Amount(交易幣別)
        shamt_doc         TYPE p DECIMALS 2,  "Balance Amount(交易幣別)
*V008 end off
      END OF gt_summary.
** 自行吸收
DATA: BEGIN OF gt_ownadmit OCCURS 0.
        INCLUDE STRUCTURE zfs061_s_ownadmit.
DATA:  zupc(20),
       zup_perc(10),
      END OF gt_ownadmit.

DATA: BEGIN OF it_ztsd0101 OCCURS 0.
        INCLUDE STRUCTURE ztsd0101.
DATA: zpno    TYPE ztsd0099-zpno,   "預採件號(料號)
      zcpno   TYPE ztsd0098-zcpno,  "客戶件號(SAP NO)
      zcpnocn TYPE ztsd0098-zcpnocn, "對應型號(Model)
      dndate  TYPE sy-datum,        "DN NO Final Day
      END OF it_ztsd0101.
DATA: BEGIN OF gt_cn OCCURS 0 ,
        zdcno LIKE ztsd0101-zdcno,
      END OF gt_cn.

DATA: BEGIN OF gt_zpno OCCURS 0,
*>> V012 modify start
*        zauthorg       LIKE ztsd0098-zauthorg,
*<< V012 modify end
        zpno           LIKE ztsd0098-zpno,
        pno_cn(100),
        pno_edesc(100),
      END OF gt_zpno.

DATA: BEGIN OF gt_m020_nam OCCURS 0,
*>> V012 modify start
*        zauthorg      LIKE ztsd0098-zauthorg,
*<< V012 modify end
        zpno          LIKE ztsd0098-zpno,
        m020_nam(100),
      END OF gt_m020_nam.
*>> V012 modify start
*RANGES: r_zpno     FOR ztsd0098-zpno.
RANGES: r_zpno     FOR ztmara-matnr.
data: it_ZTMARA like ZTMARA occurs 0 with header line.
data: begin of it_ZTMM0050COLOR occurs 0,
       WL2_COLORNO like ZTMM0050COLOR-WL2_COLORNO,
       OBJECT_NAME like ZTMM0050COLOR-OBJECT_NAME,
      end of it_ZTMM0050COLOR.
*<< V012 modify end

DATA: it_ztsd0098 LIKE ztsd0098 OCCURS 0 WITH HEADER LINE.
DATA: it_ztsd0099 LIKE ztsd0099 OCCURS 0 WITH HEADER LINE.
DATA: it_ztsd0130 LIKE ztsd0130 OCCURS 0 WITH HEADER LINE.

DATA: save_as    TYPE string.
************************************************************************
** Selection screen deslare                                            *
************************************************************************
SELECTION-SCREEN BEGIN OF BLOCK blk1 WITH FRAME TITLE text-t01.
*>> V012 modify start
*PARAMETERS    : p_zauth  TYPE ztsd0101-zauthorg OBLIGATORY.       "環境別
parameters    : p_vtweg  type ztsd0101-vtweg obligatory.
PARAMETERS    : p_werks  TYPE ztsd0101-werks OBLIGATORY.       "工廠
*<< V012 modify end
PARAMETERS    : p_zbcust TYPE ztsd0101-zbcust   OBLIGATORY.       "客戶別
SELECT-OPTIONS: s_zline  FOR ztsd0098-zxqline   OBLIGATORY.       "線別
SELECT-OPTIONS: s_zdnno  FOR g10. "ZTSD0101-ZDNNO.                "DN NO
SELECT-OPTIONS: s_zdndt  FOR ztsd0101-zcndat.                     "DN NO Final Day
SELECT-OPTIONS: s_xqtype FOR ztsd0101-zxqdctype NO INTERVALS      "收還款類別
                                                NO-DISPLAY.
SELECTION-SCREEN SKIP.
PARAMETERS:     p_split  AS CHECKBOX DEFAULT 'X'.                 "產生DN-XQ分頁
PARAMETERS:     p_area   AS CHECKBOX DEFAULT 'X'.                 "Summary依區域別分頁
* 2023/06/12     V009 Begin
PARAMETERS :  p_status  AS CHECKBOX DEFAULT 'X'.
* 2023/06/12     V009 End
* V010 Added by Tristan 2023/10/20 *
PARAMETERS: p_close AS CHECKBOX DEFAULT 'X'.
* V010 End off *
SELECTION-SCREEN END OF BLOCK blk1.

PARAMETERS :  preview  RADIOBUTTON GROUP abc.
PARAMETERS :  psave    RADIOBUTTON GROUP abc.
PARAMETERS :  p_file  LIKE rlgrap-filename .
************************************************************************
* INITIALIZATION Event                                                 *
************************************************************************
*INITIALIZATION.
*  APPEND 'IEQ1' TO S_XQTYPE.
*  APPEND 'IEQ3' TO S_XQTYPE.
*  APPEND 'IEQ4' TO S_XQTYPE.
*  APPEND 'IEQ6' TO S_XQTYPE.

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
  ELSEIF psave = 'X' AND p_file <> space.
    IF p_file CA 'xls'.
    ELSE.
      MESSAGE e002(sy) WITH '請指定存放檔名'.
    ENDIF.
  ENDIF.
*>> V012 modify start
**V002 added by Fangchyi 2020/04/23
*  AUTHORITY-CHECK OBJECT 'Z_AUTHORG'
*         ID 'ZAUTHORG' FIELD p_zauth
*         ID 'ACTVT' FIELD '03'.
*  IF sy-subrc <> 0.
*    MESSAGE e002(sy) WITH '無此權限組織的權限'.
*  ENDIF.
**V002 end off

  AUTHORITY-CHECK OBJECT 'V_KNA1_VKO'
         ID 'VTWEG' FIELD p_vtweg
         ID 'ACTVT' FIELD '03'.
  IF sy-subrc <> 0.
    MESSAGE e002(sy) WITH '無此通路的權限'.
  ENDIF.
*<< V012 modify end

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM get_filename USING p_file.

************************************************************************
* START-OF-SELECTION Event                                             *
************************************************************************
START-OF-SELECTION.
** Get 預採帳 XQ單收還款明細檔 from ZTSD0101 Table
  REFRESH: it_ztsd0101, it_ztsd0098, it_ztsd0099, gt_main, gt_zpno, gt_m020_nam, r_zpno.
  CLEAR: it_ztsd0101, it_ztsd0098, it_ztsd0099, gt_main, gt_zpno, gt_m020_nam, r_zpno.
  PERFORM get_data.
  SORT gt_main BY zdnno zpno zcpno.

** Prepare Detail, Summary, 自行吸收, Detail Split Data
  PERFORM prepare_data.
** Prepare Detail, Summary, 自行吸收, Detail Split Excel Data
*  PERFORM prepare_excel_data.   "V008 marked
  PERFORM prepare_excel_data_n.  "V008 added
************************************************************************
* END-OF-SELECTION Event                                             *
************************************************************************
END-OF-SELECTION.
  CLEAR: save_as.
  IF psave = 'X'.
    save_as = p_file.
  ENDIF.
  CALL FUNCTION 'ZXLWB_CALLFORM'
    EXPORTING
      iv_formname        = 'FS061'
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
    DATA(p_error) = 'X'.
  ENDIF.

*&---------------------------------------------------------------------*
*&      Form  GET_DATA
*&---------------------------------------------------------------------*
FORM get_data .
* V010 Added by Tristan 2023/10/20 *
  DATA: BEGIN OF it_debit OCCURS 0,
          zdcvkorg  TYPE vkorg,
          zbcust    TYPE kunnr,
          zdcno_i   TYPE zdcno101,
          zdcno     TYPE zdcch_dcno2,
          zdc       TYPE zdc101,
          zxqno     TYPE zxqno,
          zxqseq    TYPE zxqseq,
          zxqsta    TYPE zxqsta,
          zxqwrktyp TYPE zxqwrktyp,
        END OF it_debit.
* V010 End off *
* "收還款類別
* 1:收款 2:還款 3:自行報廢 4:收款後報廢 5:不還款出貨 6:手動報廢
  SELECT * FROM ztsd0101 INTO ztsd0101
*           WHERE zauthorg  =  p_zauth   "環境別
            where vtweg = p_vtweg
             AND werks = p_werks
             AND zbcust    =  p_zbcust  "客戶別
             AND ( ( zdcno IN s_zdnno AND zdcno <> '' )
              OR   ( zdnno IN s_zdnno AND zdnno <> '' ) )
             AND  zxqdctype IN s_xqtype .  "收還款類別 Default 1,3,4,6
    CLEAR: ztsd0098, ztsd0099.
    SELECT SINGLE * FROM ztsd0098 INTO ztsd0098
*>> V012 modify start
*                    WHERE zauthorg = ztsd0101-zauthorg
                     where werks = ztsd0101-werks
*<< V012 modify end
                      AND zxqno    = ztsd0101-zxqno
    AND zxqline  IN s_zline.  "線別
    IF sy-subrc = 0.
      SELECT SINGLE * FROM ztsd0099 INTO ztsd0099
*>> V012 modify start
*                      WHERE zauthorg = ztsd0101-zauthorg
                       where werks = ztsd0101-werks
*<< V012 modify end
                        AND zxqno    = ztsd0101-zxqno
      AND zxqseq = ztsd0101-zxqseq.
* V010 Changed by Tristan 2023/10/20 *
**  2023/06/12     V009 Begin
*      IF p_status <> 'X'.
*        IF ztsd0098-zxqsta = '8'.
*          CONTINUE.
*        ENDIF.
*      ENDIF.
**  2023/06/12     V009 End
      MOVE-CORRESPONDING ztsd0101 TO it_debit.
      it_debit-zxqwrktyp = ztsd0099-zxqwrktyp.
      it_debit-zxqsta = ztsd0098-zxqsta.
      APPEND it_debit. CLEAR it_debit.
* V010 End off *

      MOVE-CORRESPONDING ztsd0101 TO it_ztsd0101.
      it_ztsd0101-zpno    = ztsd0099-zpno.     "預採件號(料號)
      it_ztsd0101-zcpno   = ztsd0098-zcpno.    "客戶件號(SAP NO)
      it_ztsd0101-zcpnocn = ztsd0098-zcpnocn.  "對應型號(Model)
** DN#
      IF it_ztsd0101-zdnno = ''.
        it_ztsd0101-zdnno  = it_ztsd0101-zdcno.
      ENDIF.
      IF it_ztsd0101-zdndc = ''.
        it_ztsd0101-zdndc  = it_ztsd0101-zdc.
      ENDIF.
      IF it_ztsd0101-zdcno_dn = ''.
        it_ztsd0101-zdcno_dn  = it_ztsd0101-zdcno_i.
      ENDIF.
** 舊資料
* DNDATE  Get DN NO Final Day
      IF it_ztsd0101-zfinaldat <> ''.
        it_ztsd0101-dndate = it_ztsd0101-zfinaldat.
      ENDIF.
*20200326 yinglung V001 begin
      IF it_ztsd0101-zdcdocno <> space AND it_ztsd0101-zarea <> space.
        CONCATENATE '-' it_ztsd0101-zarea INTO x_area.
        IF it_ztsd0101-zdcdocno NS x_area.
          CONCATENATE it_ztsd0101-zdcdocno x_area INTO it_ztsd0101-zdcdocno.
        ENDIF.
      ENDIF.
*20200326 yinglung V001 end
      IF it_ztsd0101-zdcdocno <> space.
        APPEND it_ztsd0101. CLEAR it_ztsd0101.
      ENDIF.
      MOVE-CORRESPONDING ztsd0098 TO it_ztsd0098.
      APPEND it_ztsd0098. CLEAR it_ztsd0098.

      MOVE-CORRESPONDING ztsd0099 TO it_ztsd0099.
      APPEND it_ztsd0099. CLEAR it_ztsd0099.
    ENDIF.
  ENDSELECT.
* V010 Added by Tristan 2023/10/20 *
  SORT it_debit.
* 過濾掉已結案Debit Note
  IF p_close = ''.
    LOOP AT it_debit.
      AT NEW zdc.
        DATA(closed_flag) = 'X'.
      ENDAT.
* 未結
      IF it_debit-zxqwrktyp = '1'.
        CLEAR closed_flag.
      ENDIF.
      AT END OF zdc.
        IF closed_flag = 'X'.
          DELETE it_ztsd0101 WHERE zdcvkorg = it_debit-zdcvkorg
                               AND zbcust = it_debit-zbcust
                               AND zdcno_i = it_debit-zdcno_i
                               AND zdcno = it_debit-zdcno
                               AND zdc = it_debit-zdc.
        ENDIF.
      ENDAT.
    ENDLOOP.
  ENDIF.
* 過濾掉已結案XQ單
  IF p_status = ''.
    LOOP AT it_debit WHERE zxqsta = '8'.
      DELETE it_ztsd0101 WHERE zxqno = it_debit-zxqno
                           AND zxqseq = it_debit-zxqseq.
    ENDLOOP.
  ENDIF.
* V010 End off *
  DELETE it_ztsd0101 WHERE NOT zdnno    IN s_zdnno.  "DN NO
**只處理類別為 1 & 4的FINAL DATE 在畫面指定日期區間的DN資料
  DELETE it_ztsd0101 WHERE zxqdctype EQ '1' AND NOT dndate   IN s_zdndt AND dndate <> ''. "DN NO Final Day
  DELETE it_ztsd0101 WHERE zxqdctype EQ '4' AND NOT dndate   IN s_zdndt AND dndate <> ''. "DN NO Final Day
*自行吸收sheet 類別為 3,只要符合畫面條件就顯示 (不檢查對應的類別為 1 or 4是否存在)
  DELETE it_ztsd0101 WHERE zxqdctype EQ '3' AND NOT dndate   IN s_zdndt AND dndate <> ''. "DN NO Final Day

  r_zpno-sign = 'I'.
  r_zpno-option = 'EQ'.
  LOOP AT it_ztsd0101 WHERE zxqdctype = '1'
                         OR zxqdctype = '4'.
    MOVE-CORRESPONDING it_ztsd0101 TO gt_main.
    COLLECT gt_main. CLEAR gt_main.

    IF it_ztsd0101-zpno <> ''.
      r_zpno-low = it_ztsd0101-zpno.
      COLLECT r_zpno.
    ENDIF.

  ENDLOOP.

  SORT gt_main BY zbcust zdcno_i zdnno zdc.
**刪除類別不為 1 & 3 & 4 中且不屬於本次處理dn的相關 IT_ZTSD0101
  IF gt_main[] IS NOT INITIAL.
    LOOP AT it_ztsd0101 WHERE zxqdctype <> '1'
                          AND zxqdctype <> '3'
                          AND zxqdctype <> '4'.
      CASE it_ztsd0101-zxqdctype.
        WHEN OTHERS.
          READ TABLE gt_main WITH KEY zbcust = it_ztsd0101-zbcust
                                      zdcno_i = it_ztsd0101-zdcno_dn
                                      zdnno   = it_ztsd0101-zdnno
                                      zdc   = it_ztsd0101-zdndc BINARY SEARCH.
      ENDCASE.
      CHECK sy-subrc NE 0.
      DELETE it_ztsd0101.

    ENDLOOP.
  ENDIF.
*>> V012 modify start
*  SORT it_ztsd0101 BY zauthorg zxqno zxqseq zfinaldat zxqdctype.
*  SORT it_ztsd0098 BY zauthorg zxqno.
*  SORT it_ztsd0099 BY zauthorg zxqno zxqseq.
  SORT it_ztsd0101 BY werks zxqno zxqseq zfinaldat zxqdctype.
  SORT it_ztsd0098 BY werks zxqno.
  SORT it_ztsd0099 BY werks zxqno zxqseq.
*<< V012 modify end
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
** 到中介db中抓取
*  PERFORM GET_SQL_DATA.
*  SORT GT_ZPNO     BY ZAUTHORG ZPNO.
*  SORT GT_M020_NAM BY ZAUTHORG ZPNO.
*>> V012 modify start
**改抓ztsd0130
*  PERFORM get_ztsd0130.
  perform get_ztmara.
*<< V012 modify end

** Detail Split分頁
  CLEAR: gt_dtl_split[], gt_dtl_split.
  PERFORM prepare_detail_split.
** Detail 分頁
  CLEAR: gt_detail[], gt_detail.
  PERFORM prepare_detail.
** Summary 分頁
  CLEAR: gt_summary[], gt_summary.
  PERFORM prepare_summary.
** 自行吸收分頁
  CLEAR: gt_ownadmit[], gt_ownadmit.
  PERFORM prepare_ownadmit.
***************************************************************

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
  DATA: l_zup     TYPE p DECIMALS 6,
        l_zup_per TYPE p.
  DATA: l_date    TYPE sy-datum.
  DATA: l_zdcnobk(30).
  FIELD-SYMBOLS:
    <split> TYPE zfs061_s_split,
    <lines> TYPE zfs061_s_detail.
  FIELD-SYMBOLS: <summary> TYPE zfs061_s_summary,
                 <slines>  TYPE zfs061_s_summary_lines.

  CLEAR: gs_context-detail[], gs_context-summaryall[],
         gs_context-summary[], gs_context-ownadmit[],
         gs_context-detail_split[].
  CLEAR: gs_detail, gs_ownadmit, gs_split.
** Detail
  LOOP AT gt_detail.
    MOVE-CORRESPONDING gt_detail TO gs_detail.
    l_date = gt_detail-zfinaldat.
    WRITE: l_date TO gs_detail-zfinaldat.
    l_date = gt_detail-zdat.
    WRITE: l_date TO gs_detail-zdat.

    APPEND gs_detail TO gs_context-detail.
    CLEAR: gs_detail.
  ENDLOOP.
  IF p_split = 'X'.
* Detail Split
    APPEND INITIAL LINE TO gs_context-detail_split ASSIGNING <split>.
    <split>-name = 'DetailSplit'.
    LOOP AT gt_dtl_split.
      APPEND INITIAL LINE TO <split>-lines ASSIGNING <lines>.
      MOVE-CORRESPONDING gt_dtl_split TO <lines>.
      l_date = gt_dtl_split-zfinaldat.
      WRITE: l_date TO <lines>-zfinaldat.
      l_date = gt_dtl_split-zdat.
      WRITE: l_date TO <lines>-zdat.
      <lines>-name = 'DetailSplit'.
    ENDLOOP.
  ENDIF.
** Summary All
  READ TABLE gt_summary INDEX 1.
  l_zdcnobk = gt_summary-zdcnobk.
  LOOP AT gt_summary.
**若分區印SUMMARY,此SHEET 只印區域別為空白的資料
    IF p_area = 'X'.
      CHECK gt_summary-zarea EQ ''.
    ENDIF.
    AT NEW zarea.
      APPEND INITIAL LINE TO gs_context-summaryall ASSIGNING <summary>.
      <summary>-zarea = gt_summary-zarea.
    ENDAT.

    IF l_zdcnobk <> gt_summary-zdcnobk.
      APPEND INITIAL LINE TO <summary>-lines ASSIGNING <slines>.
      l_zdcnobk = gt_summary-zdcnobk.
    ENDIF.

    APPEND INITIAL LINE TO <summary>-lines ASSIGNING <slines>.
    MOVE-CORRESPONDING gt_summary TO <slines>.

    PERFORM convert_char USING gt_summary-ztotal gt_summary-sub_total CHANGING <slines>-ztotal.
    PERFORM convert_char USING gt_summary-scamt gt_summary-sub_total CHANGING <slines>-scamt.
    PERFORM convert_char USING gt_summary-shamt gt_summary-sub_total CHANGING <slines>-shamt.
    PERFORM convert_char USING gt_summary-cnamt gt_summary-sub_total CHANGING <slines>-cnamt.
    PERFORM convert_char USING gt_summary-balamt gt_summary-sub_total CHANGING <slines>-balamt.
*V008 added
    PERFORM convert_char USING gt_summary-ztotal_doc gt_summary-sub_total CHANGING <slines>-ztotal_doc.
    PERFORM convert_char USING gt_summary-scamt_doc gt_summary-sub_total CHANGING <slines>-scamt_doc.
    PERFORM convert_char USING gt_summary-shamt_doc gt_summary-sub_total CHANGING <slines>-shamt_doc.
    PERFORM convert_char USING gt_summary-cnamt_doc gt_summary-sub_total CHANGING <slines>-cnamt_doc.
    PERFORM convert_char USING gt_summary-balamt_doc gt_summary-sub_total CHANGING <slines>-balamt_doc.
*V008 end off
    WRITE: gt_summary-zfinaldat TO <slines>-zfinaldat NO-ZERO.
    WRITE: gt_summary-scdate    TO <slines>-scdate    NO-ZERO.
    WRITE: gt_summary-cndate    TO <slines>-cndate    NO-ZERO.
  ENDLOOP.
** Summary by Area
  IF p_area = 'X'.
***空白區域別不再分頁顯示
    DELETE gt_summary WHERE zarea = space.

    READ TABLE gt_summary INDEX 1.
    l_zdcnobk = gt_summary-zdcnobk.
    LOOP AT gt_summary.
      AT NEW zarea.
        APPEND INITIAL LINE TO gs_context-summary ASSIGNING <summary>.
        CONCATENATE 'Summary-' gt_summary-zarea INTO <summary>-zarea.
*V008 added
*area為空白但DOC_CURR <> USD的頁籤名稱
        IF   gt_summary-area = ''
        AND  gt_summary-zarea <> ''.
          CONCATENATE 'Summary All Area-' gt_summary-zarea INTO <summary>-zarea.
        ENDIF.
*V008 end off
      ENDAT.
      IF l_zdcnobk <> gt_summary-zdcnobk.
        APPEND INITIAL LINE TO <summary>-lines ASSIGNING <slines>.
        l_zdcnobk = gt_summary-zdcnobk.
      ENDIF.

      APPEND INITIAL LINE TO <summary>-lines ASSIGNING <slines>.
      MOVE-CORRESPONDING gt_summary TO <slines>.

      PERFORM convert_char USING gt_summary-ztotal gt_summary-sub_total CHANGING <slines>-ztotal.
      PERFORM convert_char USING gt_summary-scamt gt_summary-sub_total CHANGING <slines>-scamt.
      PERFORM convert_char USING gt_summary-shamt gt_summary-sub_total CHANGING <slines>-shamt.
      PERFORM convert_char USING gt_summary-cnamt gt_summary-sub_total CHANGING <slines>-cnamt.
      PERFORM convert_char USING gt_summary-balamt gt_summary-sub_total CHANGING <slines>-balamt.
*V008 added
      PERFORM convert_char USING gt_summary-ztotal_doc gt_summary-sub_total CHANGING <slines>-ztotal_doc.
      PERFORM convert_char USING gt_summary-scamt_doc gt_summary-sub_total CHANGING <slines>-scamt_doc.
      PERFORM convert_char USING gt_summary-shamt_doc gt_summary-sub_total CHANGING <slines>-shamt_doc.
      PERFORM convert_char USING gt_summary-cnamt_doc gt_summary-sub_total CHANGING <slines>-cnamt_doc.
      PERFORM convert_char USING gt_summary-balamt_doc gt_summary-sub_total CHANGING <slines>-balamt_doc.
*V008 end off
      WRITE: gt_summary-zfinaldat TO <slines>-zfinaldat NO-ZERO.
      WRITE: gt_summary-scdate    TO <slines>-scdate    NO-ZERO.
      WRITE: gt_summary-cndate    TO <slines>-cndate    NO-ZERO.
    ENDLOOP.
  ENDIF.
** 自行吸收
  LOOP AT gt_ownadmit.
    MOVE-CORRESPONDING gt_ownadmit TO gs_ownadmit.
    l_zup     = gt_ownadmit-zupc.
    l_zup_per = gt_ownadmit-zup_perc.
    IF l_zup_per <> 0.
      l_zup     = l_zup / l_zup_per.
    ELSE.
      l_zup = 0.
    ENDIF.
    gs_ownadmit-zup     = l_zup.

    APPEND gs_ownadmit TO gs_context-ownadmit.
    CLEAR: gs_ownadmit.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CONVERT_AMOUNT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_GT_DTL_SPLIT_ZTOTAL  text
*      -->P_IT_ZTSD0101_ZCUR  text
*      <--P_GT_DTL_SPLIT_ZTOTAL  text
*----------------------------------------------------------------------*
FORM convert_amount  USING    pi_amt
                              pi_waers
                     CHANGING po_amt.
  DATA: p_currency LIKE  tcurr-tcurr,
        p_factor   TYPE p DECIMALS 3.

  p_currency = pi_waers.
  CLEAR p_factor.
  CALL FUNCTION 'CURRENCY_CONVERTING_FACTOR'
    EXPORTING
      currency          = p_currency
    IMPORTING
      factor            = p_factor
    EXCEPTIONS
      too_many_decimals = 1
      OTHERS            = 2.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.
  po_amt = pi_amt * p_factor.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_CURRENCY_FACTOR
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_LT_ZTSD0101_ZCUR  text
*      <--P_G_FACTOR  text
*----------------------------------------------------------------------*
FORM get_currency_factor  USING    pi_waers
                          CHANGING po_factor.
  DATA: p_currency LIKE  tcurr-tcurr.

  p_currency = pi_waers.
  CLEAR po_factor.
  CALL FUNCTION 'CURRENCY_CONVERTING_FACTOR'
    EXPORTING
      currency          = p_currency
    IMPORTING
      factor            = po_factor
    EXCEPTIONS
      too_many_decimals = 1
      OTHERS            = 2.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CONCATENATE_CN_NO
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      <--P_GT_DTL_SPLIT_ZCNNO  text
*----------------------------------------------------------------------*
FORM concatenate_cn_no  USING    p_zdcno
                        CHANGING p_zcnno.

  CHECK p_zdcno NE space.
  IF p_zcnno = ''.
    p_zcnno = p_zdcno.
  ELSE.
    CONCATENATE p_zcnno '/' p_zdcno INTO p_zcnno.
  ENDIF.
*重覆單號排除取消
*  READ TABLE GT_CN WITH KEY ZDCNO = P_ZDCNO.
*  IF SY-SUBRC <> 0.
*    GT_CN-ZDCNO = P_ZDCNO.
*    APPEND GT_CN.
*    IF P_ZCNNO = ''.
*      P_ZCNNO = P_ZDCNO.
*    ELSE.
*      CONCATENATE P_ZCNNO '/' P_ZDCNO INTO P_ZCNNO.
*    ENDIF.
*  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CONCATENATE_CN_XQ
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_LT_ZTSD0101_ZXQNO  text
*      -->P_LT_ZTSD0101_ZXQSEQ  text
*      -->P_LT_ZTSD0101_ZXQDCTYPE  text
*      -->P_LT_ZTSD0101_ZQTY  text
*      <--P_GT_DTL_SPLIT_ZCNTYBALACE  text
*----------------------------------------------------------------------*
FORM concatenate_cn_xq  USING    p_zxqno
                                 p_zxqseq
                                 p_zxqdctype
                                 p_zqty
                                 p_zirmk
                        CHANGING p_zcntybalace.
  DATA: l_text(1000).
  DATA: l_type_text(20).
  CLEAR: l_text, l_type_text.
  PERFORM convert_qty USING p_zqty
                   CHANGING l_text.

*  WRITE: P_ZQTY TO L_TEXT  DECIMALS 0.
  PERFORM get_domain_text USING 'ZTSD0101-ZXQDCTYPE' p_zxqdctype
                        CHANGING l_type_text.
  CONDENSE: l_text, l_type_text.
  CONCATENATE p_zxqno '-' p_zxqseq+3(3) '(' l_type_text ':' l_text
              INTO l_text.
  IF p_zirmk <> ''.
    CONCATENATE l_text ':' p_zirmk ')'
                INTO l_text.
  ELSE.
    CONCATENATE l_text  ')'
                INTO l_text.
  ENDIF.
  IF p_zcntybalace = ''.
    p_zcntybalace = l_text.
  ELSE.
    CONCATENATE  p_zcntybalace '／' l_text INTO p_zcntybalace.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_DOMAIN_TEXT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_1084   text
*      -->P_P_ZXQDCTYPE  text
*      <--P_L_TYPE_TEXT  text
*----------------------------------------------------------------------*
FORM get_domain_text  USING    p_field
                               p_value
                      CHANGING p_text.
  DATA: l_tabname    TYPE  ddobjname.
  DATA: l_fieldname  TYPE  dfies-fieldname.
  DATA: l_lfieldname TYPE  dfies-lfieldname.
  DATA: l_x030l_wa   TYPE  x030l.
  DATA: l_ddobjtype  TYPE  dd02v-tabclass.
  DATA: l_dfies_wa   TYPE  dfies.
  DATA: lt_values    TYPE  ddfixvalues.
  DATA: wa_values    TYPE  ddfixvalue.

  CLEAR: l_tabname, l_fieldname, l_lfieldname,
         l_x030l_wa, l_ddobjtype, l_dfies_wa,
         lt_values, wa_values.
  SPLIT p_field AT '-' INTO l_tabname l_fieldname.
  l_lfieldname = l_fieldname.
  CALL FUNCTION 'DDIF_FIELDINFO_GET'
    EXPORTING
      tabname        = l_tabname
      fieldname      = l_fieldname
      langu          = sy-langu
      lfieldname     = l_lfieldname
*     ALL_TYPES      = ' '
*     GROUP_NAMES    = ' '
*     UCLEN          =
*     DO_NOT_WRITE   = ' '
    IMPORTING
      x030l_wa       = l_x030l_wa
      ddobjtype      = l_ddobjtype
      dfies_wa       = l_dfies_wa
*     LINES_DESCR    =
    TABLES
*     DFIES_TAB      =
      fixed_values   = lt_values
    EXCEPTIONS
      not_found      = 1
      internal_error = 2
      OTHERS         = 3.
  IF sy-subrc <> 0.
* Implement suitable error handling here
    DATA(p_error) = 'X'.
  ENDIF.
  READ TABLE lt_values INTO wa_values WITH KEY low = p_value.
  IF sy-subrc = 0.
    p_text = wa_values-ddtext.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PREPARE_DETAIL_SPLIT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM prepare_detail_split .
  DATA: BEGIN OF lt_split_key OCCURS 0,
*>> V012 modify start
*          zauthorg LIKE ztsd0101-zauthorg,
          werks    like ztsd0101-werks,
*<< V012 modify end
          zxqno    LIKE ztsd0101-zxqno,
          zxqseq   LIKE ztsd0101-zxqseq,
          zdcno_dn TYPE zdcno_dn,
          zdnno    TYPE zdnno,
          zdndc    TYPE zdndc,
        END OF lt_split_key.
  DATA: lt_ztsd0101 LIKE TABLE OF it_ztsd0101 WITH HEADER LINE.
  DATA: wa_ztsd0101 LIKE it_ztsd0101.

  DATA: w_qty      TYPE ztsd0101-zqty,
        w_qty14    TYPE ztsd0101-zqty,
        w_qty24567 TYPE ztsd0101-zqty,
        w_99qty    TYPE ztsd0099-zqty,
        w_qtyp     TYPE ztsd0099-zqty,
        w_qty2     TYPE ztsd0099-zqty.

  DATA: w_day1     TYPE sy-datum.
  DATA: w_day2     TYPE sy-datum.

* 2022/06/14     V007 Begin
  DATA : w_qty57 TYPE ztsd0101-zqty.
* 2022/06/14     V007 End

** GT_MAIN Keys: DN no, 客戶件號(SAP NO) ZTSD0098-ZCPNO、預採件號(料號) ZTSD0099-ZPNO
** 相同的MAIN Keys會有多筆的XQ no，Detail Split不合併，但Detail會合併
** 所以Detail Split要再拆出XQ No
  SORT gt_main BY zdnno zcpno zpno.
*>> V012 modify start
*  SORT it_ztsd0130 BY zauthorg zpno.
* ??   SORT it_ztsd0130 BY werks zpno.   "待補
*<< V012 modify end
  LOOP AT gt_main.
    REFRESH: lt_split_key.  CLEAR: lt_split_key.
    LOOP AT it_ztsd0101 WHERE  zbcust     = gt_main-zbcust
                          AND  zdcno_dn   = gt_main-zdcno_i
                          AND  zdnno      = gt_main-zdnno
                          AND  zdndc      = gt_main-zdc
                          AND  zpno       = gt_main-zpno
                          AND  zcpno      = gt_main-zcpno
                          AND  zxqdctype <> '3'.

      MOVE-CORRESPONDING it_ztsd0101 TO lt_split_key.
      COLLECT lt_split_key. CLEAR lt_split_key.
    ENDLOOP.
**LT_SPLIT_KEY: XQ no, XQ Seq(不同的Debit note no)
    LOOP AT lt_split_key.
      REFRESH: lt_ztsd0101, gt_cn.  CLEAR: lt_ztsd0101, gt_cn.

      LOOP AT it_ztsd0101
*>> V012 modify start
*      WHERE  zauthorg   = lt_split_key-zauthorg
              where
*>> V012 modify end
                             zxqno      = lt_split_key-zxqno
                            AND  zxqseq     = lt_split_key-zxqseq
                            AND  zxqdctype <> '3'
                            AND  zdcno_dn   = lt_split_key-zdcno_dn
                            AND  zdnno      = lt_split_key-zdnno
                            AND  zdndc      = lt_split_key-zdndc.
        MOVE-CORRESPONDING it_ztsd0101 TO lt_ztsd0101.
        APPEND lt_ztsd0101. CLEAR lt_ztsd0101.
      ENDLOOP.
** 一筆XQ+XQ seq會有一筆Debit# and 多筆Credit# ，以ZXQDCTYPE 1,4為主(Debit note)
** 抓其他的Credit#
      CLEAR: wa_ztsd0101, w_qty, w_qty14, w_qty24567,w_99qty,w_qtyp,w_qty2.
* 2022/06/14     V007 Begin
      CLEAR: w_qty57.
* 2022/06/14     V007 End

      READ TABLE lt_ztsd0101 INTO wa_ztsd0101 WITH KEY zdnno      = lt_split_key-zdnno
                                                       zxqdctype = '1'.
      IF sy-subrc <> 0.
        READ TABLE lt_ztsd0101 INTO wa_ztsd0101 WITH KEY zdnno      = lt_split_key-zdnno
                                                         zxqdctype = '4'.
      ENDIF.
** Get Currency Factor
      CLEAR g_factor.
      PERFORM get_currency_factor USING lt_ztsd0101-zcur
                               CHANGING g_factor.

      CLEAR: wa_ztsd0098, wa_ztsd0099.
*>> V012 modify start
*      READ TABLE it_ztsd0098 INTO wa_ztsd0098 WITH KEY zauthorg  = wa_ztsd0101-zauthorg
*                                                          zxqno  = wa_ztsd0101-zxqno BINARY SEARCH.
*      READ TABLE it_ztsd0099 INTO wa_ztsd0099 WITH KEY  zauthorg = wa_ztsd0101-zauthorg
*                                                        zxqno    = wa_ztsd0101-zxqno
*                                                        zxqseq   = wa_ztsd0101-zxqseq BINARY SEARCH.
      READ TABLE it_ztsd0098 INTO wa_ztsd0098 WITH KEY werks  = wa_ztsd0101-werks
                                                          zxqno  = wa_ztsd0101-zxqno BINARY SEARCH.
      READ TABLE it_ztsd0099 INTO wa_ztsd0099 WITH KEY  werks = wa_ztsd0101-werks
                                                        zxqno    = wa_ztsd0101-zxqno
                                                        zxqseq   = wa_ztsd0101-zxqseq BINARY SEARCH.
*<< V012 modify end
      w_99qty                     = wa_ztsd0099-zqty.         "庫存數量
      w_qtyp                      = wa_ztsd0099-zp653bqty.    "收款後轉出數量
      gt_dtl_split-zcpnocn        = wa_ztsd0098-zcpnocn.   "對應型號
      gt_dtl_split-zdesc          = wa_ztsd0099-zdesc.     "英文說明
      gt_dtl_split-zpno           = wa_ztsd0101-zpno.      "預採件號
      gt_dtl_split-zcpno          = wa_ztsd0101-zcpno.     "客戶件號
      gt_dtl_split-zdcno          = wa_ztsd0101-zdcdocno.  "ZDNNO               "改印處理後的單號(加上前置及後綴字)    "DN#
      gt_dtl_split-zdnno          = wa_ztsd0101-zdnno.     "原DN單號
      gt_dtl_split-zfinaldat      = wa_ztsd0101-dndate.    "DN FINAL DATE
      gt_dtl_split-zbcust         = wa_ztsd0101-zbcust.    "客戶
      gt_dtl_split-zdcno_i        = wa_ztsd0101-zdcno_i.    "借貸項通知單號
      gt_dtl_split-zdcrmk         = wa_ztsd0101-zdcrmk.    "借貸項通知單詳細備註
*>> V012 modify start
*      gt_dtl_split-zauthorg       = wa_ztsd0101-zauthorg.    "Authority organization
      gt_dtl_split-werks =   wa_ztsd0101-werks.
*<< V012 modify end
      gt_dtl_split-zdndc          = wa_ztsd0101-zdndc.     "原DN DC TYPE
*V008 added
      gt_dtl_split-doc_curr          = wa_ztsd0101-doc_curr.
      IF wa_ztsd0101-doc_curr = ''.
        gt_dtl_split-doc_curr = 'USD'.
      ENDIF.
      gt_dtl_split-doc_amt           = wa_ztsd0101-doc_amt.
      gt_dtl_split-doc_rate          = wa_ztsd0101-doc_rate.
      IF wa_ztsd0101-doc_rate        = 0.
        gt_dtl_split-doc_rate = 1.
      ENDIF.
*V008 end off
*>> V012 modify start
*     SORT lt_ztsd0101 BY zauthorg zxqno zxqseq zfinaldat zxqdctype.
      SORT lt_ztsd0101 BY werks zxqno zxqseq zfinaldat zxqdctype.
*<< V012 modify end
      LOOP AT lt_ztsd0101.
        CASE lt_ztsd0101-zxqdctype.
          WHEN '1'.
            gt_dtl_split-zqty     = gt_dtl_split-zqty   + lt_ztsd0101-zqty.           "ORG. QTY
            gt_dtl_split-ztotal   = gt_dtl_split-ztotal + ( lt_ztsd0101-ztotal * g_factor ).    "ORG. AMOUNT
            w_qty14               = w_qty14             + lt_ztsd0101-zqty.

          WHEN '4'.
            gt_dtl_split-zqty     = gt_dtl_split-zqty   + lt_ztsd0101-zqty.           "ORG. QTY
            gt_dtl_split-ztotal   = gt_dtl_split-ztotal + ( lt_ztsd0101-ztotal * g_factor ).    "ORG. AMOUNT

            gt_dtl_split-scqty    = gt_dtl_split-scqty  + lt_ztsd0101-zqty.            "SCRAP QTY
            gt_dtl_split-scamt    = gt_dtl_split-scamt  + ( lt_ztsd0101-ztotal * g_factor ).       "Scrap AMT

            w_qty14               = w_qty14             + lt_ztsd0101-zqty.
            w_qty24567            = w_qty24567          + lt_ztsd0101-zqty.

          WHEN '2'.
            gt_dtl_split-cnqty    = gt_dtl_split-cnqty  + lt_ztsd0101-zqty.            "CN QTY
            gt_dtl_split-cnamt    = gt_dtl_split-cnamt  + ( lt_ztsd0101-ztotal * g_factor ).       "CN AMT

            w_qty24567            = w_qty24567          + lt_ztsd0101-zqty.
            w_qty2                = w_qty2              + lt_ztsd0101-zqty.

            PERFORM concatenate_cn_no USING lt_ztsd0101-zdcdocno  "ZDCNO               "改印處理後的單號(加上前置及後綴字)
                                   CHANGING gt_dtl_split-zcnno.                        "CN#

            PERFORM concatenate_cn_xq USING lt_ztsd0101-zxqno
                                            lt_ztsd0101-zxqseq
                                            lt_ztsd0101-zxqdctype
                                            lt_ztsd0101-zqty
                                            lt_ztsd0101-zirmk
                                   CHANGING gt_dtl_split-zcntybalace.                  "CN-XQ
          WHEN '5'. "不還款報廢
            gt_dtl_split-scqty    = gt_dtl_split-scqty  + lt_ztsd0101-zqty.            "SCRAP QTY
            gt_dtl_split-scamt    = gt_dtl_split-scamt  + ( lt_ztsd0101-ztotal * g_factor ).       "Scrap AMT

            w_qty24567            = w_qty24567          + lt_ztsd0101-zqty.
* V011 Marked by Tristan 2023/11/16 *
* Return數量= 收款後轉出數量 – 已還款數量(2)– 不還款出貨數量(7) ，不需納入不還款報廢數量(5)
** 2022/06/14     V007 Begin
*            w_qty57               = w_qty57             + lt_ztsd0101-zqty.
** 2022/06/14     V007 End
* V011 End off *
            PERFORM concatenate_cn_no USING lt_ztsd0101-zdcdocno  "ZDCNO               "改印處理後的單號(加上前置及後綴字)
                                   CHANGING gt_dtl_split-zcnno.                        "CN#

            PERFORM concatenate_cn_xq USING lt_ztsd0101-zxqno
                                            lt_ztsd0101-zxqseq
                                            lt_ztsd0101-zxqdctype
                                            lt_ztsd0101-zqty
                                            lt_ztsd0101-zirmk
                                   CHANGING gt_dtl_split-zcntybalace.                  "CN-XQ
          WHEN '6'.  "6的數量是負數,所以用減的
            gt_dtl_split-scqty    = gt_dtl_split-scqty  - lt_ztsd0101-zqty.            "SCRAP QTY
*手動報廢金額要捨入到第2位
            g_scrpamt             = gt_dtl_split-scamt  - ( lt_ztsd0101-ztotal * g_factor ).       "Scrap AMT
            gt_dtl_split-scamt    = g_scrpamt.

            w_qty24567            = w_qty24567          - lt_ztsd0101-zqty.

          WHEN '7'. "不還款出貨
            gt_dtl_split-shqty    = gt_dtl_split-shqty  + lt_ztsd0101-zqty.            "SHIPPED QTY
            gt_dtl_split-shamt    = gt_dtl_split-shamt  + ( lt_ztsd0101-ztotal * g_factor ).       "Ship AMT

            w_qty24567            = w_qty24567          + lt_ztsd0101-zqty.
* 2022/06/14     V007 Begin
            w_qty57               = w_qty57             + lt_ztsd0101-zqty.
* 2022/06/14     V007 End

            PERFORM concatenate_cn_no USING lt_ztsd0101-zdcdocno  "ZDCNO               "改印處理後的單號(加上前置及後綴字)
                                   CHANGING gt_dtl_split-zcnno.                        "CN#

            PERFORM concatenate_cn_xq USING lt_ztsd0101-zxqno
                                            lt_ztsd0101-zxqseq
                                            lt_ztsd0101-zxqdctype
                                            lt_ztsd0101-zqty
                                            lt_ztsd0101-zirmk
                                   CHANGING gt_dtl_split-zcntybalace.                  "CN-XQ
        ENDCASE.
      ENDLOOP.
*ztsd0101-zxqdctype 的zqty
*if (1+4) - 對應的(2+4+5+6+7) <= 0
*則為0  => 表示收款都已還完
*
*若尚未結清：
*取 ZTSD0099-ZP653BQTY 減 2,4,5,6,7 ==> 如果小於等於0 則為0
*
*若(ZTSD0099-ZP653BQTY >  (1+4)  則為 (1+4) -減 2,4,5,6,7
*若(ZTSD0099-ZP653BQTY <=  (1+4)  則為 (ZTSD0099-ZP653BQTY -減 2,4,5,6,7
*      W_QTY                       = W_QTY14 - W_QTY24567.
*      IF W_QTY <= 0 AND ( W_QTY14 <> 0 OR W_QTY24567 <> 0 ).
*        GT_DTL_SPLIT-RETQTY       = 0.
*      ELSE.
*        IF WA_ZTSD0099-ZP653BQTY > W_QTY14. "收款後轉出數量超過收款數量，表示應該還款
*          GT_DTL_SPLIT-RETQTY       = W_QTY14 - W_QTY24567.
*        ELSE.
*          GT_DTL_SPLIT-RETQTY       = WA_ZTSD0099-ZP653BQTY - W_QTY24567.
**若(ZTSD0099-ZP653BQTY -減 2,4,5,6,7 < 0, 則為 (1+4) -減 2,4,5,6,7
*          IF GT_DTL_SPLIT-RETQTY < 0. "表示尚未有足夠的轉出，不需要還款，但會有剩餘未還款數量
*            GT_DTL_SPLIT-RETQTY       = 0.
*            "GT_DTL_SPLIT-RETQTY       = W_QTY14 - W_QTY24567.
*          ENDIF.
*        ENDIF.
*      ENDIF.
**以上邏輯先remark ,改成以下邏輯
*1. Return Qty計算邏輯調整(原本的算法是矇對，這邊提供較嚴謹的邏輯，progress已調整比對出來都是正確的) # 原邏輯先mark 保留
*先計算剩餘還款的總數量X_A = 收款數量(1+4) – 報廢數量(4+5+6) – 不還款出貨(7) – 已還款數量(2)
*                                                              = (1+4) – (2+4+5+6+7)
*If X_A <= 0.  /* 已還清*/
*還款數量 = 0。
*Else
*
*計算收款後轉出的總數量 X_P
*
*If X_P >= 已還款數量(2) .  /*收款後轉出超過已還款數量，表示需要做還款*/
*
*           If X_P >= 收款數量(1+4)  -->還款數量Return_Qty = (1+4)  -  2   /*如果轉出數量超過收款數量，表示要全還，用收款數量減收款後轉出數量*/
*           Else  還款數量Return_Qty -->還款數量Return_Qty = X_P – 2   /*否則表示為分批轉出還款，用轉出數量扣掉已還款數量*/
*
*Else.  /*本期無轉出，不需還款*/
*   還款數量 = 0
*Endif.
*Endif.
      w_qty                       = w_qty14 - w_qty24567.
      IF w_qty <= 0 AND ( w_qty14 <> 0 OR w_qty24567 <> 0 ).
        gt_dtl_split-retqty       = 0.
      ELSEIF w_qtyp >= w_qty2.   "收款後轉出的數量超過已還款款數量，代表要還款

*20200630 yinglung V003 begin
*        IF W_QTYP >= W_QTY14.
*          GT_DTL_SPLIT-RETQTY       = W_QTY14 - W_QTY2.
*        ELSE.
*          GT_DTL_SPLIT-RETQTY       = W_QTYP - W_QTY2.
*        ENDIF.
        IF w_qtyp >= w_qty14. "如果收款後轉出數量大於已收款數量，代表全部轉出，應該全部還款，故用收款數量去扣
          gt_dtl_split-retqty       = w_qty14 - w_qty24567.
        ELSE. "如果沒有完全轉出，代表沒辦法全部還款，要用實際收款後轉出數量去扣
          "20200806 yinglung V004 begin
          "GT_DTL_SPLIT-RETQTY       = W_QTYP - W_QTY24567.
* 2022/06/14     V007 Begin
*          gt_dtl_split-retqty       = w_qtyp - w_qty2.
          gt_dtl_split-retqty       = w_qtyp - w_qty2 - w_qty57.
* 2022/06/14     V007 End
          "20200806 yinglung V004 end
        ENDIF.
        IF gt_dtl_split-retqty <= 0.
          gt_dtl_split-retqty = 0.
        ENDIF.
*20200630 yinglung V003 end

      ELSE.
        gt_dtl_split-retqty       = 0.
      ENDIF.

*還款金額要捨入到第2位
      IF wa_ztsd0101-zup_per <> 0.
        g_retamt                    = wa_ztsd0101-zup * g_factor / wa_ztsd0101-zup_per *
                                      gt_dtl_split-retqty.   "RETURN AMOUNT
      ELSE.
        g_retamt = 0.   "RETURN AMOUNT
      ENDIF.

      gt_dtl_split-retamt         = g_retamt.  "RETURN AMOUNT



      gt_dtl_split-balqty         = gt_dtl_split-zqty   - gt_dtl_split-retqty -
                                    gt_dtl_split-scqty  - gt_dtl_split-shqty  -
                                    gt_dtl_split-cnqty.                                 "BALANCE QTY
      gt_dtl_split-balamt         = gt_dtl_split-ztotal - gt_dtl_split-retamt -
                                    gt_dtl_split-scamt  - gt_dtl_split-shamt  -
                                    gt_dtl_split-cnamt.
      "BALANCE AMOUNT
*小於0有提示作用，避免多還款，故不調成0
*      IF GT_DTL_SPLIT-BALQTY <= 0.
*        GT_DTL_SPLIT-BALQTY = 0.
*      ENDIF.

      gt_dtl_split-zdat           = wa_ztsd0099-zdat.                                   "INVENTORY OCCUR DATE
      w_day1                      = gt_dtl_split-zfinaldat.
      w_day2                      = gt_dtl_split-zdat.
      gt_dtl_split-zdays          = w_day1 - w_day2.                                    "DN FINAL DATE - INVENTORY OCCUR DATE
      TRANSLATE wa_ztsd0099-zxqdtyp TO UPPER CASE.
      SELECT SINGLE zxqdtypnam FROM ztsd0111 INTO gt_dtl_split-zxqdtypnam
      WHERE zxqdtyp = wa_ztsd0099-zxqdtyp.
*          GT_DTL_SPLIT-ZQTYBALACE  =   DN-XQ
*      PERFORM CONVERT_QTY  USING WA_ZTSD0099-ZQTYBALACE
*                        CHANGING GT_DTL_SPLIT-ZQTYBALACE.
*      CONDENSE GT_DTL_SPLIT-ZQTYBALACE.
*      CONCATENATE WA_ZTSD0099-ZXQNO '-' WA_ZTSD0099-ZXQSEQ+3(3) '(' GT_DTL_SPLIT-ZQTYBALACE ')'
*                  INTO GT_DTL_SPLIT-ZQTYBALACE.
      CONCATENATE wa_ztsd0099-zxqno '-' wa_ztsd0099-zxqseq+3(3)
                 INTO gt_dtl_split-zqtybalace.

      CASE wa_ztsd0101-zdcvkorg.  "銷售組織Name
        WHEN '1130'.
          gt_dtl_split-zdcvkorg       = 'HK'.
        WHEN '1321'.
          gt_dtl_split-zdcvkorg       = 'BVI'.
        WHEN '1110'.
          gt_dtl_split-zdcvkorg       = 'TP'.
*20200828 yinglung V005 begin
        WHEN '2311'.
          IF gt_main-zbcust EQ 'C01'.
            gt_dtl_split-zdcvkorg       = 'C客戶 BVI'.
          ENDIF.
          IF gt_main-zbcust EQ 'J01'.
            gt_dtl_split-zdcvkorg       = 'Joie BVI'.
          ENDIF.
*20200828 yinglung V005 begin
        WHEN OTHERS.
          gt_dtl_split-zdcvkorg       = wa_ztsd0101-zdcvkorg.
      ENDCASE.
      gt_dtl_split-zarea          = wa_ztsd0101-zarea.                                  "DN區域別
*>> V012 modify start
*      PERFORM get_sql USING p_zauth
*                            gt_dtl_split-zpno
*                            CHANGING gt_dtl_split-pno_cn    "中文品名
*                                     gt_dtl_split-m020_nam. "廠內顏色

      perform read_ztmara  USING gt_dtl_split-zpno
                          CHANGING gt_dtl_split-pno_cn    "中文品名
                                   gt_dtl_split-m020_nam. "廠內顏色
*<< V012 modify end

      APPEND gt_dtl_split. CLEAR gt_dtl_split.
    ENDLOOP.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PREPARE_DETAIL
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM prepare_detail .
  DATA: w_day1     TYPE sy-datum.
  DATA: w_day2     TYPE sy-datum.

  SORT gt_dtl_split BY zdnno zcpno zpno zqtybalace.

  IF gt_dtl_split[] IS NOT INITIAL.
** GT_MAIN Keys: DN no, 客戶件號、預採件號
** 相同的MAIN Keys會有多筆的XQ no，Detail Split不合併，但Detail會合併
    SORT gt_main BY zdnno zcpno zpno.
    LOOP AT gt_main.
      LOOP AT gt_dtl_split WHERE zbcust   = gt_main-zbcust
                             AND zdcno_i  = gt_main-zdcno_i
                             AND zdnno    = gt_main-zdnno
                             AND zdndc    = gt_main-zdc
                             AND zpno     = gt_main-zpno
                             AND zcpno    = gt_main-zcpno.
*                             AND ZCPNOCN  = GT_MAIN-ZCPNOCN.
        gt_detail-zpno           = gt_dtl_split-zpno.      "預採件號
        gt_detail-zcpno          = gt_dtl_split-zcpno.     "客戶件號
        gt_detail-zcpnocn        = gt_dtl_split-zcpnocn.   "對應型號
        gt_detail-zdesc          = gt_dtl_split-zdesc.     "英文說明
        gt_detail-zdnno          = gt_dtl_split-zdnno.     "DN#
        gt_detail-zdndc          = gt_dtl_split-zdndc.     "DN# DC TYPE
        gt_detail-zbcust         = gt_dtl_split-zbcust.    "客戶
        gt_detail-zdcno_i        = gt_dtl_split-zdcno_i.   "借貸項通知單號
        gt_detail-zdcno          = gt_dtl_split-zdcno.     "DN#
        gt_detail-zfinaldat      = gt_dtl_split-zfinaldat. "DN FINAL DATE
        gt_detail-zqty           = gt_detail-zqty   + gt_dtl_split-zqty.     "ORG. QTY
        gt_detail-ztotal         = gt_detail-ztotal + gt_dtl_split-ztotal.   "ORG. AMOUNT
        gt_detail-scqty          = gt_detail-scqty  + gt_dtl_split-scqty.    "SCRAP QTY
        gt_detail-scamt          = gt_detail-scamt  + gt_dtl_split-scamt.    "SCRAP AMOUNT
        gt_detail-shqty          = gt_detail-shqty  + gt_dtl_split-shqty.    "SHIPPED QTY
        gt_detail-shamt          = gt_detail-shamt  + gt_dtl_split-shamt.    "SHIPPED AMOUNT
        gt_detail-cnqty          = gt_detail-cnqty  + gt_dtl_split-cnqty.    "CN QTY
        gt_detail-cnamt          = gt_detail-cnamt  + gt_dtl_split-cnamt.    "CN AMOUNT
        gt_detail-retqty         = gt_detail-retqty + gt_dtl_split-retqty.   "RETURN QTY
        gt_detail-retamt         = gt_detail-retamt + gt_dtl_split-retamt.   "RETURN AMOUNT
        gt_detail-zxqdtypnam     = gt_dtl_split-zxqdtypnam.
*        GT_DETAIL-BALQTY         = GT_DETAIL-BALQTY + GT_DETAIL-ZQTY   - GT_DETAIL-RETQTY -
*                                   GT_DETAIL-SCQTY  - GT_DETAIL-SHQTY  -
*                                   GT_DETAIL-CNQTY.                          "BALANCE QTY
*        GT_DETAIL-BALAMT         = GT_DETAIL-BALAMT + GT_DETAIL-ZTOTAL - GT_DETAIL-RETAMT -
*                                   GT_DETAIL-SCAMT  - GT_DETAIL-SHAMT  -
*                                   GT_DETAIL-CNAMT.                          "BALANCE AMOUNT
        gt_detail-balqty         = gt_detail-balqty +  gt_dtl_split-balqty.
        gt_detail-balamt         = gt_detail-balamt +  gt_dtl_split-balamt.
        IF gt_detail-zcnno       = ''.                                       "CN#
          gt_detail-zcnno        = gt_dtl_split-zcnno.
        ELSE.
          IF gt_dtl_split-zcnno <> ''.
            CONCATENATE gt_detail-zcnno '/' gt_dtl_split-zcnno
                        INTO gt_detail-zcnno.
          ENDIF.
        ENDIF.
        IF gt_detail-zcpnocn = ''.
          gt_detail-zcpnocn = gt_dtl_split-zcpnocn.
        ENDIF.
        IF gt_detail-zcntybalace = ''.                                       "CN-XQ
          gt_detail-zcntybalace  = gt_dtl_split-zcntybalace.
        ELSE.
          IF gt_dtl_split-zcntybalace <> ''.
            CONCATENATE gt_detail-zcntybalace '／' gt_dtl_split-zcntybalace
                        INTO gt_detail-zcntybalace.
          ENDIF.
        ENDIF.
*GT_DETAIL-ZDAT 合併時取最早的日期
        IF gt_detail-zdat        = ''.
          gt_detail-zdat         = gt_dtl_split-zdat.
          w_day1                   = gt_detail-zfinaldat.
          w_day2                   = gt_detail-zdat.
          gt_detail-zdays          = w_day1 - w_day2.                          "DN FINAL DATE - INVENTORY OCCUR DATE
        ELSEIF gt_detail-zdat    > gt_dtl_split-zdat.                        "INVENTORY OCCUR DATE
          gt_detail-zdat         = gt_dtl_split-zdat.
          w_day1                   = gt_detail-zfinaldat.
          w_day2                   = gt_detail-zdat.
          gt_detail-zdays          = w_day1 - w_day2.                          "DN FINAL DATE - INVENTORY OCCUR DATE
        ENDIF.
        IF gt_detail-zqtybalace  = ''.                                       "DN-XQ
          gt_detail-zqtybalace   = gt_dtl_split-zqtybalace.
        ELSE.
          CONCATENATE gt_detail-zqtybalace '／' gt_dtl_split-zqtybalace
                      INTO gt_detail-zqtybalace.
        ENDIF.

        gt_detail-zdcvkorg       = gt_dtl_split-zdcvkorg.                     "銷售組織
        gt_detail-zarea          = gt_dtl_split-zarea.                        "DN區域別
        gt_detail-pno_cn         = gt_dtl_split-pno_cn.                       "中文品名
        gt_detail-m020_nam       = gt_dtl_split-m020_nam.                     "廠內顏色
        gt_detail-zdcrmk         = gt_dtl_split-zdcrmk.                       "借貸項通知單詳細備註
*>> V012 modify start
*        gt_detail-zauthorg       = gt_dtl_split-zauthorg.                     "Authority organization
        gt_detail-werks       = gt_dtl_split-werks.
*<< V012 modify end
* 2022/04/22  V006  Kiwi  Begin
        gt_detail-zdndc_remark = ''.
        SELECT SINGLE zrem1 INTO gt_detail-zdndc_remark
          FROM ztsd0118
        WHERE zdcno = gt_dtl_split-zdcno_i.
* 2022/04/22  V006  Kiwi  End
*V008 added
        gt_detail-doc_curr          = gt_dtl_split-doc_curr.
        gt_detail-doc_amt           = gt_detail-doc_amt + gt_dtl_split-doc_amt.
        gt_detail-doc_rate          = gt_dtl_split-doc_rate.
*V008 end off
      ENDLOOP.
      CHECK sy-subrc EQ 0.
      IF gt_detail-balqty <= 0.
        gt_detail-balqty = 0.
      ENDIF.
* V011 Added by Tristan 2023/11/20 *
      IF gt_detail-balamt <= 0.
        gt_detail-balamt = 0.
      ENDIF.
* V011 End off *
      APPEND gt_detail. CLEAR gt_detail.
    ENDLOOP.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PREPARE_SUMMARY
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM prepare_summary .
  DATA: lt_summary LIKE gt_summary  OCCURS 0 WITH HEADER LINE.
  DATA: lt_scrap   LIKE gt_summary OCCURS 0 WITH HEADER LINE.
  DATA: BEGIN OF lt_cn OCCURS 0.
          INCLUDE STRUCTURE gt_summary.
  DATA:  zamt_s     TYPE ztotal,   "Shipped Amount
         zamt_s_doc TYPE ztotal, "Shipped Amount(交易幣別) V008 added
         END OF lt_cn.
  DATA: w_line  LIKE sy-index,
        w_line1 LIKE sy-index.
*>> V012 modify start
*  DATA: l_zauthorg LIKE it_ztsd0101-zauthorg.
*<< V012 modify end
  DATA: l_zdcvkorg(20).
  DATA: l_zdcrmk   LIKE it_ztsd0101-zdcrmk.
  DATA: l_zcndat   TYPE zcndat.
  DATA: l_flag(1).
  DATA: l_date TYPE sy-datum.

  CLEAR: lt_summary[], lt_summary.
  LOOP AT gt_detail.
    lt_summary-area      = gt_detail-zarea.     "DN區域別 V008 added
    lt_summary-zarea     = gt_detail-zarea.     "DN區域別
*V008 added
*若交易幣別不為USD，則再依幣別分區&拆sheets
    IF gt_detail-doc_curr <> ''
    AND gt_detail-doc_curr <> 'USD'.
      IF gt_detail-zarea = ''.
        lt_summary-zarea = gt_detail-doc_curr.
      ELSE.
        lt_summary-zarea = gt_detail-zarea && '-' && gt_detail-doc_curr.     "DN區域別
      ENDIF.
      lt_summary-doc_curr = gt_detail-doc_curr.
    ELSE.
      lt_summary-doc_curr = ''. "代表是USD
    ENDIF.
*V008 end off
    lt_summary-zfinaldat = gt_detail-zfinaldat. "DN Final Date
    lt_summary-zdcno_i   = gt_detail-zdcno_i.
    lt_summary-zdnno     = gt_detail-zdnno.     "原DN單號
    lt_summary-zdndc     = gt_detail-zdndc.     "原DN單號 DC TYPE
    lt_summary-zdcno     = gt_detail-zdcno.     "DN#
    lt_summary-ztotal    = gt_detail-ztotal.    "Org. DN Amount
    lt_summary-zdcnobk   = gt_detail-zdcno.     "DN#
    lt_summary-zdcrmk    = gt_detail-zdcrmk.
    lt_summary-zauthorg  = gt_detail-zdcvkorg.

    lt_summary-zdcvkorg  = gt_detail-zdcvkorg.
* 2022/04/22  V006  Kiwi  Begin
    lt_summary-zdndc_remark = gt_detail-zdndc_remark.
* 2022/04/22  V006  Kiwi  End
*V008 added
    lt_summary-ztotal_doc    = gt_detail-ztotal * gt_detail-doc_rate.    "DN Amount(交易幣別)
*V008 end off
    COLLECT lt_summary. CLEAR lt_summary.
  ENDLOOP.

*  SORT lt_summary BY zarea zfinaldat zdcno_i zdcno. "V008 marked
  SORT lt_summary BY doc_curr area zarea zfinaldat zdcno_i zdcno. "V008 added
  SORT it_ztsd0101 BY zdnno zxqno zxqseq zxqdctype.
  LOOP AT lt_summary.
** Get scrap. ship, CN data for each DN#
    REFRESH:  lt_scrap, lt_cn.
    CLEAR: lt_scrap, lt_cn, w_line, w_line1.
    LOOP AT it_ztsd0101 WHERE zdcno_dn = lt_summary-zdcno_i
                          AND zdnno    = lt_summary-zdnno
                          AND zdndc    = lt_summary-zdndc.
*V008 added
      IF it_ztsd0101-doc_rate = 0.
        it_ztsd0101-doc_rate = 1.
      ENDIF.
*V008 end off
      CASE it_ztsd0101-zxqdctype. "收還款類別
        WHEN '1'.
*          L_ZCNDAT = IT_ZTSD0101-ZCNDAT.
        WHEN '2'.               "CN
          MOVE-CORRESPONDING lt_summary TO lt_cn.
          lt_cn-cndate = it_ztsd0101-zfinaldat.  "L_ZCNDAT.
          lt_cn-ztotal = it_ztsd0101-ztotal.
          lt_cn-zcur   = it_ztsd0101-zcur.
          lt_cn-zcnno  = it_ztsd0101-zdcdocno.  "ZDCNO.
*V008 added
          lt_cn-ztotal_doc = lt_cn-ztotal * it_ztsd0101-doc_rate.    "CN Amount(交易幣別)
*V008 end off
          COLLECT lt_cn. CLEAR lt_cn.
        WHEN '4' OR '5'. "Scrap
          MOVE-CORRESPONDING lt_summary TO lt_scrap.
          lt_scrap-cndate = it_ztsd0101-zfinaldat.  "L_ZCNDAT.
          lt_scrap-ztotal = it_ztsd0101-ztotal.
          lt_scrap-zcur   = it_ztsd0101-zcur.
*V008 added
          lt_scrap-ztotal_doc = lt_scrap-ztotal * it_ztsd0101-doc_rate.    "Scrap Amount(交易幣別)
*V008 end off
          COLLECT lt_scrap. CLEAR lt_scrap.
        WHEN '6'. "Scrap  "6內容為負數,需轉成正數
          MOVE-CORRESPONDING lt_summary TO lt_scrap.
          lt_scrap-cndate = it_ztsd0101-zfinaldat.  "L_ZCNDAT.
          lt_scrap-ztotal = it_ztsd0101-ztotal * -1.
          lt_scrap-zcur   = it_ztsd0101-zcur.
*V008 added
          lt_scrap-ztotal_doc = lt_scrap-ztotal * it_ztsd0101-doc_rate.    "Scrap Amount(交易幣別)
*V008 end off
          COLLECT lt_scrap. CLEAR lt_scrap.
        WHEN '7'.               "Ship
          MOVE-CORRESPONDING lt_summary TO lt_cn.
          lt_cn-cndate = it_ztsd0101-zfinaldat.  "L_ZCNDAT.
          lt_cn-zamt_s = it_ztsd0101-ztotal.
          lt_cn-ztotal = 0.
          lt_cn-zcur   = it_ztsd0101-zcur.
          lt_cn-zcnno  = it_ztsd0101-zdcdocno.  "ZDCNO.
*V008 added
          lt_cn-ztotal_doc = 0.
          lt_cn-zamt_s_doc = lt_cn-zamt_s * it_ztsd0101-doc_rate.    "Shipped Amount(交易幣別)
*V008 end off
          COLLECT lt_cn. CLEAR lt_cn.

      ENDCASE.
    ENDLOOP.
    SORT lt_cn    BY cndate zcnno.
    SORT lt_scrap BY cndate zcnno.

** 最大筆數
    DESCRIBE TABLE lt_cn LINES w_line1.
    IF w_line1 > w_line.
      w_line = w_line1.
    ENDIF.
    DESCRIBE TABLE lt_scrap LINES w_line1.
    IF w_line1 > w_line.
      w_line = w_line1.
    ENDIF.

    DO w_line TIMES.
      MOVE-CORRESPONDING lt_summary TO gt_summary.
***** Scrap
      READ TABLE lt_scrap INDEX sy-index.
      IF sy-subrc = 0.
** Get Currency Factor
        CLEAR g_factor.
        PERFORM get_currency_factor USING lt_scrap-zcur
                                 CHANGING g_factor.
        gt_summary-scdate = lt_scrap-cndate.
        gt_summary-scamt  = lt_scrap-ztotal * g_factor.
*V008 added
** Get Currency Factor
        CLEAR g_factor.
        PERFORM get_currency_factor USING lt_scrap-doc_curr
                                 CHANGING g_factor.
        gt_summary-scamt_doc  = lt_scrap-ztotal_doc * g_factor.
*V008 end off
      ENDIF.
***** CN & Ship  : 兩者都會顯示 CN# & CN Date
      READ TABLE lt_cn INDEX sy-index.
      IF sy-subrc = 0.
** Get Currency Factor
        CLEAR g_factor.
        PERFORM get_currency_factor USING lt_cn-zcur
                                 CHANGING g_factor.
        gt_summary-cndate = lt_cn-cndate.
        gt_summary-cnamt  = lt_cn-ztotal * g_factor.
        gt_summary-shamt  = lt_cn-zamt_s * g_factor.
        gt_summary-zcnno  = lt_cn-zcnno.
*V008 added
** Get Currency Factor
        CLEAR g_factor.
        PERFORM get_currency_factor USING lt_cn-doc_curr
                                 CHANGING g_factor.
        gt_summary-cnamt_doc  = lt_cn-ztotal_doc * g_factor.
        gt_summary-shamt_doc  = lt_cn-zamt_s_doc * g_factor.
*V008 end off
      ENDIF.
      APPEND gt_summary. CLEAR gt_summary.
    ENDDO.
    IF w_line = 0.
      MOVE-CORRESPONDING lt_summary TO gt_summary.
      APPEND gt_summary. CLEAR gt_summary.
    ENDIF.
  ENDLOOP.

*** 處理sub-total and balance amount
*  SORT GT_SUMMARY BY ZAREA ZDCNO_I ZDCNO.
  LOOP AT gt_summary WHERE sub_total = ''.
    AT NEW zdcno.
      CLEAR w_line.
    ENDAT.
    ADD 1 TO w_line.
*>> V012 modify start
*    l_zauthorg = gt_summary-zauthorg.
*<< V012 modify end
    l_zdcvkorg = gt_summary-zdcvkorg.
    l_zdcrmk   = gt_summary-zdcrmk.
    l_date     = gt_summary-zfinaldat.
    AT END OF zdcno.
      IF w_line > 1.
        SUM.
        CLEAR: gt_summary-scdate,    "GT_SUMMARY-ZFINALDAT,
               gt_summary-zcnno,     gt_summary-zauthorg,
               gt_summary-seqno,     gt_summary-zcur,
               gt_summary-doc_curr. "V008 add
        gt_summary-zfinaldat = l_date.
        gt_summary-ztotal    = gt_summary-ztotal / w_line.
        gt_summary-cndate    = '99991231'.
        gt_summary-sub_total = 'X'.
        gt_summary-balamt    = gt_summary-ztotal - gt_summary-scamt -
                               gt_summary-shamt  - gt_summary-cnamt.
        gt_summary-zauthorg  = l_zdcvkorg.  "列印銷售組織名稱
        gt_summary-zdcrmk    = l_zdcrmk.
        gt_summary-zdcnobk   = gt_summary-zdcno.
*V008 added
        gt_summary-ztotal_doc    = gt_summary-ztotal_doc / w_line.
        gt_summary-balamt_doc    = gt_summary-ztotal_doc - gt_summary-scamt_doc -
                                 gt_summary-shamt_doc  - gt_summary-cnamt_doc.
*V008 end off
        APPEND gt_summary. CLEAR gt_summary.
      ELSE.
        READ TABLE gt_summary INDEX sy-tabix.
        gt_summary-balamt = gt_summary-ztotal - gt_summary-scamt -
                            gt_summary-shamt  - gt_summary-cnamt.
        gt_summary-sub_total = 'X'.
*V008 added
        gt_summary-balamt_doc    = gt_summary-ztotal_doc - gt_summary-scamt_doc -
                                 gt_summary-shamt_doc  - gt_summary-cnamt_doc.
        MODIFY gt_summary INDEX sy-tabix TRANSPORTING balamt sub_total balamt_doc.
*V008 end off
*        MODIFY gt_summary INDEX sy-tabix TRANSPORTING balamt sub_total. "V008 marked
      ENDIF.
    ENDAT.
  ENDLOOP.

*  SORT GT_SUMMARY BY ZAREA ZDCNO_I ZDCNO CNDATE.
  SORT gt_summary BY zarea zfinaldat zdcno_i zdcno cndate.
  CLEAR w_line.
  LOOP AT gt_summary.
    AT NEW zdcno.
      ADD 1 TO w_line.
      WRITE w_line TO gt_summary-seqno NO-ZERO.
      CONDENSE gt_summary-seqno.
      MODIFY gt_summary INDEX sy-tabix TRANSPORTING seqno.
      CLEAR w_line1.
    ENDAT.
  ENDLOOP.
  CLEAR l_flag.
  LOOP AT gt_summary.
    IF gt_summary-seqno IS INITIAL AND gt_summary-sub_total = ''.
      CLEAR: gt_summary-zdcno, gt_summary-zfinaldat,
             gt_summary-ztotal,
             gt_summary-ztotal_doc. "V008 added
    ENDIF.
    AT NEW zdnno.
      l_flag = 'X'.
    ENDAT.
    IF gt_summary-sub_total = ''.
      CLEAR: gt_summary-zauthorg.
    ENDIF.
**每張dn第一筆才印備註
    IF l_flag = ''.
      CLEAR: gt_summary-zdcrmk.
* 2022/04/22  V006  Kiwi  Begin
      CLEAR: gt_summary-zdndc_remark.
* 2022/04/22  V006  Kiwi  End

    ELSE.
      CLEAR l_flag.
    ENDIF.
    IF gt_summary-cndate    = '99991231'.
      gt_summary-zdcno      = 'Sub-Total'.
      CLEAR: gt_summary-cndate,gt_summary-zfinaldat.
    ENDIF.
    MODIFY gt_summary INDEX sy-tabix.
  ENDLOOP.


ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PREPARE_OWNADMIT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM prepare_ownadmit .
  LOOP AT it_ztsd0101 WHERE zxqdctype  = '3'.
    MOVE-CORRESPONDING it_ztsd0101 TO gt_ownadmit.
    gt_ownadmit-zdcno    = it_ztsd0101-zdcdocno.
    gt_ownadmit-zupc     = it_ztsd0101-zup.
    gt_ownadmit-zup_perc = it_ztsd0101-zup_per.
    gt_ownadmit-zxqseq   = it_ztsd0101-zxqseq+3(3).
    CASE it_ztsd0101-zdcvkorg.  "銷售組織Name
      WHEN '1130'.
        gt_ownadmit-zdcvkorg       = 'HK'.
      WHEN '1321'.
        gt_ownadmit-zdcvkorg       = 'BVI'.
      WHEN '1110'.
        gt_ownadmit-zdcvkorg       = 'TP'.
*20200828 yinglung V005 begin
      WHEN '2311'.
        IF gt_main-zbcust EQ 'C01'.
          gt_ownadmit-zdcvkorg      = 'C客戶 BVI'.
        ENDIF.
        IF gt_main-zbcust EQ 'J01'.
          gt_ownadmit-zdcvkorg      = 'Joie BVI'.
        ENDIF.
*20200828 yinglung V005 begin
      WHEN OTHERS.
        gt_ownadmit-zdcvkorg       = it_ztsd0101-zdcvkorg.
    ENDCASE.
    COLLECT gt_ownadmit. CLEAR gt_ownadmit.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_SQL
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_WA_ZTSD0099_ZENTITY  text
*      -->P_WA_ZTSD0099_ZPNO  text
*      <--P_GT_DTL_SPLIT_PNO_CN  text
*      <--P_GT_DTL_SPLIT_M020_NAM  text
*----------------------------------------------------------------------*
*>> V012 modify start  " replace by read_ztmara
*FORM get_sql  USING    p_zentity
*                       p_zpno
*              CHANGING p_pno_cn
*                       p_m020_nam.
*  SORT gt_zpno     BY zauthorg zpno.
*  SORT gt_m020_nam BY zauthorg zpno.
***中文品名
**  IF P_ZENTITY <> '' AND P_ZPNO <> ''.
**    READ TABLE GT_ZPNO WITH KEY ZAUTHORG = P_ZENTITY
**                                ZPNO     = P_ZPNO
**                                BINARY SEARCH.
**    IF SY-SUBRC = 0.
**      P_PNO_CN = GT_ZPNO-PNO_CN.
**    ENDIF.
****廠內顏色
**    READ TABLE GT_M020_NAM WITH KEY ZAUTHORG = P_ZENTITY
**                                       ZPNO  = P_ZPNO
**                                BINARY SEARCH.
**    IF SY-SUBRC = 0.
**      P_M020_NAM = GT_M020_NAM-M020_NAM.
**    ENDIF.
**
**  ENDIF.
**改抓 ZTSD0130
*  IF p_zentity <> '' AND p_zpno <> ''.
*    READ TABLE it_ztsd0130 WITH KEY zauthorg = p_zentity
*                                    zpno     = p_zpno
*                                BINARY SEARCH.
*    IF sy-subrc = 0.
*      p_pno_cn = it_ztsd0130-zpno_cn.
*      p_m020_nam = it_ztsd0130-zpno_colornam.
*    ENDIF.
*  ENDIF.
*
*ENDFORM.
*<< V012 modify start  " replace by read_ztmara

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
*&      Form  GET_SQL_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
*>> V012 modify start  " no use,
*FORM get_sql_data .
*  CLEAR: g_ok.
*  PERFORM connect_pcss USING p_con
*                    CHANGING g_ok.
*
*  IF g_ok = ''.
**英文規格  " V_PNO-PNO_EDESC
**中文品名  "V_PNO-PNO_DESC
*    CLEAR: error_text.
*    TRY.
*        EXEC SQL PERFORMING append_zpno.
*          SELECT ENTITY, PNO_NO, PNO_CN, PNO_EDESC
*            INTO :GT_ZPNO-ZAUTHORG,
*                 :GT_ZPNO-ZPNO,
*                 :GT_ZPNO-PNO_CN,
*                 :GT_ZPNO-PNO_EDESC
*          FROM  dbo.V_PNO
*        ENDEXEC.
*      CATCH cx_sy_native_sql_error INTO exc_ref.
*        error_text = exc_ref->get_text( ).
*    ENDTRY.
**廠內顏色  "V_W1MCOLOR-M020_NAM
*    CLEAR: error_text.
*    TRY.
*        EXEC SQL PERFORMING append_gt_m020_nam.
*          SELECT A.ENTITY, A.W1MPNO_NO, B.M020_NAM
*            INTO :GT_M020_NAM-ZAUTHORG,
*                 :GT_M020_NAM-ZPNO,
*                 :GT_M020_NAM-M020_NAM
**          FROM  dbo.V_W1MCOLOR
*           FROM dbo.V_W1MPNO AS A
*           LEFT JOIN dbo.V_W1MA020 AS B ON A.W1MPNO_COLOR = B.M020_NO AND A.ENTITY = B.ENTITY
*        ENDEXEC.
*      CATCH cx_sy_native_sql_error INTO exc_ref.
*        error_text = exc_ref->get_text( ).
*    ENDTRY.
*  ENDIF.
*** DB DisConnect
*  PERFORM disconnect_pcss USING p_con.
*
*ENDFORM.
*<< V012 modify end
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
*&      Form  CONVERT_QTY
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_P_ZQTY  text
*      <--P_L_TEXT  text
*----------------------------------------------------------------------*
FORM convert_qty  USING    p_qtyin
                  CHANGING p_qtyout.

  DATA: l_qtyin(20).
  DATA: c1(13), c2(4).


  WRITE: p_qtyin TO l_qtyin NO-GROUPING.
  CONDENSE: l_qtyin.

  SPLIT l_qtyin AT '.' INTO c1 c2.
  CONDENSE: c1, c2.
  IF c2 = '0000'.
    CLEAR c2.
    p_qtyout = c1.
  ELSEIF c2+1(3) = '000'.
    c2+1(3) = ''.
    CONCATENATE c1 '.' c2 INTO p_qtyout.
  ELSEIF c2+2(2) = '00'.
    c2+2(2) = ''.
    CONCATENATE c1 '.' c2 INTO p_qtyout.
  ELSEIF c2+3(1) = '0'.
    c2+3(1) = ''.
    CONCATENATE c1 '.' c2 INTO p_qtyout.
  ELSEIF c2 <> space.
    CONCATENATE c1 '.' c2 INTO p_qtyout.
  ELSE.
    p_qtyout = c1.
  ENDIF.

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
*>>V012 modify start , change to select ztmara
*  REFRESH: it_ztsd0130.
*  SELECT *
*    INTO TABLE it_ztsd0130
*    FROM ztsd0130
*   WHERE zauthorg = p_zauth
*  AND zpno IN r_zpno.
*
*  SORT it_ztsd0130   BY zauthorg zpno.
*<< V012 modify end
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
*&      Form  CONVERT_CHAR
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_GT_SUMMARY_SCAMT  text
*      <--P_<SLINES>_SCAMT  text
*----------------------------------------------------------------------*
FORM convert_char  USING    i_amt  i_sum
                   CHANGING o_char.

  IF i_amt = 0.
**Subtotal 時0也要顯示
    IF i_sum = 'X'.
      o_char = '0'.
    ELSE.
      o_char = ''.
    ENDIF.
  ELSE.
    o_char = i_amt.
**負號處理
    CALL FUNCTION 'CLOI_PUT_SIGN_IN_FRONT'
      CHANGING
        value = o_char.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PREPARE_EXCEL_DATA_N
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM prepare_excel_data_n .
  DATA: l_zup     TYPE p DECIMALS 6,
        l_zup_per TYPE p.
  DATA: l_date    TYPE sy-datum.
  DATA: l_zdcnobk(30).
  FIELD-SYMBOLS:
    <split> TYPE zfs061_s_split,
    <lines> TYPE zfs061_s_detail.
  FIELD-SYMBOLS: <summary> TYPE zfs061_s_summary,
                 <slines>  TYPE zfs061_s_summary_lines.

  CLEAR: gs_context-detail[], gs_context-summaryall[],
         gs_context-summary[], gs_context-ownadmit[],
         gs_context-detail_split[].
  CLEAR: gs_detail, gs_ownadmit, gs_split.
** Detail
  LOOP AT gt_detail.
    MOVE-CORRESPONDING gt_detail TO gs_detail.
    l_date = gt_detail-zfinaldat.
    WRITE: l_date TO gs_detail-zfinaldat.
    l_date = gt_detail-zdat.
    WRITE: l_date TO gs_detail-zdat.

    APPEND gs_detail TO gs_context-detail.
    CLEAR: gs_detail.
  ENDLOOP.
  IF p_split = 'X'.
* Detail Split
    APPEND INITIAL LINE TO gs_context-detail_split ASSIGNING <split>.
    <split>-name = 'DetailSplit'.
    LOOP AT gt_dtl_split.
      APPEND INITIAL LINE TO <split>-lines ASSIGNING <lines>.
      MOVE-CORRESPONDING gt_dtl_split TO <lines>.
      l_date = gt_dtl_split-zfinaldat.
      WRITE: l_date TO <lines>-zfinaldat.
      l_date = gt_dtl_split-zdat.
      WRITE: l_date TO <lines>-zdat.
      <lines>-name = 'DetailSplit'.
    ENDLOOP.
  ENDIF.
*V008 added
*  IF p_area = ''.
**所有area +同一doc_curr明細都放在同一頁籤
*    LOOP AT gt_summary.
*      CLEAR: gt_summary-area.
*      gt_summary-zarea = gt_summary-doc_curr.
*      MODIFY gt_summary.
*    ENDLOOP.
*  ENDIF.
*** Summary by Area
**p_area = ''時: 不分area +相同doc_curr明細都放在同一頁籤
**p_area = 'X'時 : 相同area +相同doc_curr明細才能放在同一頁籤
*  READ TABLE gt_summary INDEX 1.
*  l_zdcnobk = gt_summary-zdcnobk.
*  LOOP AT gt_summary.
*    AT NEW zarea.
*      APPEND INITIAL LINE TO gs_context-summary ASSIGNING <summary>.
*      CONCATENATE 'Summary-' gt_summary-zarea INTO <summary>-zarea.
**V008 added
**area為空白但DOC_CURR <> USD的頁籤名稱
*      IF   gt_summary-area = ''.
*        IF gt_summary-zarea = ''.
*          <summary>-zarea = 'Summary All Area'.
*        ELSE.
*          CONCATENATE 'Summary All Area-' gt_summary-zarea INTO <summary>-zarea.
*        ENDIF.
*      ENDIF.
**V008 end off
*    ENDAT.
*    IF l_zdcnobk <> gt_summary-zdcnobk.
*      APPEND INITIAL LINE TO <summary>-lines ASSIGNING <slines>.
*      l_zdcnobk = gt_summary-zdcnobk.
*    ENDIF.

  "=== 讓不分區時，依幣別彙整（避免跳來跳去）===
  IF p_area = ''.
    SORT gt_summary BY doc_curr zfinaldat zdcno_i zdcno cndate.
  ENDIF.

  "=== 追蹤每個頁籤各自的 last zdcnobk，避免跨頁籤干擾 ===
  TYPES: BEGIN OF ty_sheet_state,
           name    TYPE string,
           last_bk TYPE c LENGTH 30,
         END OF ty_sheet_state.
  DATA: lt_state TYPE STANDARD TABLE OF ty_sheet_state WITH DEFAULT KEY,
        ls_state TYPE ty_sheet_state.



  LOOP AT gt_summary.

    "== 依目前這筆決定頁籤名稱（每筆都重算） ==
    DATA(lv_sheetname) = VALUE string( ).
    IF p_area = 'X'.
      IF gt_summary-area = '' AND gt_summary-doc_curr <> ''.
        lv_sheetname = |Summary All Area-{ gt_summary-doc_curr }|.
      ELSE.
        lv_sheetname = |Summary-{ gt_summary-zarea }|.
      ENDIF.
    ELSE.
      IF gt_summary-doc_curr IS INITIAL.
        lv_sheetname = 'Summary All Area'.
      ELSE.
        lv_sheetname = |Summary All Area-{ gt_summary-doc_curr }|.
      ENDIF.
    ENDIF.

    "== 以頁籤名為 key：存在就用，不存在才建 ==
    READ TABLE gs_context-summary ASSIGNING <summary>
         WITH KEY zarea = lv_sheetname.
    IF sy-subrc <> 0.
      APPEND INITIAL LINE TO gs_context-summary ASSIGNING <summary>.
      <summary>-zarea = lv_sheetname.
      CLEAR ls_state.
      ls_state-name = lv_sheetname.
      ls_state-last_bk = ''.
      APPEND ls_state TO lt_state.
    ENDIF.

    "== 取得/維護此頁籤的 last zdcnobk（用來插入分隔空行） ==
    READ TABLE lt_state INTO ls_state WITH KEY name = lv_sheetname.
    IF sy-subrc <> 0.
      CLEAR ls_state.
      ls_state-name = lv_sheetname.
      ls_state-last_bk = ''.
      APPEND ls_state TO lt_state.
    ENDIF.

    "== 若換了 zdcno 背書號，先插一行做視覺分隔 ==
    IF ls_state-last_bk <> gt_summary-zdcnobk.
      APPEND INITIAL LINE TO <summary>-lines ASSIGNING <slines>.
      ls_state-last_bk = gt_summary-zdcnobk.
      MODIFY lt_state FROM ls_state INDEX sy-tabix.
    ENDIF.

    APPEND INITIAL LINE TO <summary>-lines ASSIGNING <slines>.
    MOVE-CORRESPONDING gt_summary TO <slines>.

    PERFORM convert_char USING gt_summary-ztotal gt_summary-sub_total CHANGING <slines>-ztotal.
    PERFORM convert_char USING gt_summary-scamt gt_summary-sub_total CHANGING <slines>-scamt.
    PERFORM convert_char USING gt_summary-shamt gt_summary-sub_total CHANGING <slines>-shamt.
    PERFORM convert_char USING gt_summary-cnamt gt_summary-sub_total CHANGING <slines>-cnamt.
    PERFORM convert_char USING gt_summary-balamt gt_summary-sub_total CHANGING <slines>-balamt.
*V008 added
    PERFORM convert_char USING gt_summary-ztotal_doc gt_summary-sub_total CHANGING <slines>-ztotal_doc.
    PERFORM convert_char USING gt_summary-scamt_doc gt_summary-sub_total CHANGING <slines>-scamt_doc.
    PERFORM convert_char USING gt_summary-shamt_doc gt_summary-sub_total CHANGING <slines>-shamt_doc.
    PERFORM convert_char USING gt_summary-cnamt_doc gt_summary-sub_total CHANGING <slines>-cnamt_doc.
    PERFORM convert_char USING gt_summary-balamt_doc gt_summary-sub_total CHANGING <slines>-balamt_doc.
*V008 end off
    WRITE: gt_summary-zfinaldat TO <slines>-zfinaldat NO-ZERO.
    WRITE: gt_summary-scdate    TO <slines>-scdate    NO-ZERO.
    WRITE: gt_summary-cndate    TO <slines>-cndate    NO-ZERO.
  ENDLOOP.
*V008 end off
** 自行吸收
  LOOP AT gt_ownadmit.
    MOVE-CORRESPONDING gt_ownadmit TO gs_ownadmit.
    l_zup     = gt_ownadmit-zupc.
    l_zup_per = gt_ownadmit-zup_perc.
    IF l_zup_per <> 0.
      l_zup     = l_zup / l_zup_per.
    ELSE.
      l_zup = 0.
    ENDIF.
    gs_ownadmit-zup     = l_zup.

    APPEND gs_ownadmit TO gs_context-ownadmit.
    CLEAR: gs_ownadmit.
  ENDLOOP.

ENDFORM.

*>>V012 modify start
FORM read_ztmara  USING p_zpno
              CHANGING p_pno_cn
                       p_m020_nam.
  READ TABLE it_ztmara WITH KEY matnr = p_zpno
                       BINARY SEARCH.
  IF sy-subrc = 0.
     p_pno_cn = it_ztmara-WL2_THENAMEOFTHEERP.
     read table it_ZTMM0050COLOR
        with key WL2_COLORNO = it_ztmara-FACTORYTHECOLOR.
     if sy-subrc = 0.
        p_m020_nam =  it_ZTMM0050COLOR-OBJECT_NAME.
     endif.
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
     WHERE matnr in r_zpno.
  ENDIF.
  SORT it_ztmara   BY matnr.

  select * into corresponding fields of table it_ZTMM0050COLOR
    from ZTMM0050COLOR order by WL2_COLORNO.
ENDFORM.
*<<V012 modify end


*Selection texts
*----------------------------------------------------------
* PREVIEW         預覽
* PSAVE         存檔
* P_AREA         Summary依區域別分頁
* P_CLOSE         是否顯示已結案DebitNote
* P_FILE         存放路徑及檔名
* P_SPLIT         產生DN-XQ分頁
* P_STATUS         是否顯示已結案 XQ 單
* P_VTWEG D       .
* P_WERKS         工廠
* P_ZBCUST         客戶別
* S_ZDNDT         DN NO Final Day
* S_ZDNNO         DN NO
* S_ZLINE         線別


*Messages
*----------------------------------------------------------
*
* Message class: SY
*002   &

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2025. Sap Release 757
