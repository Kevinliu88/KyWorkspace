*&---------------------------------------------------------------------*
*& Include          ZTGPPEC0006FRM
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Form CALL_R1
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM CALL_R1.

*  Z_PROD01 權限檢查，


ENDFORM.


*&---------------------------------------------------------------------*
*& Form SEARCHHELP_ZID
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM SEARCHHELP_ZID.

  TYPES:
    BEGIN OF TYPE_ZID,
      ZID    TYPE ZTPPMO0011-ZID,
      ZWERKS TYPE ZTPPMO0011-ZWERKS,
      ZDAT   TYPE ZTPPMO0011-ZDAT,
      ZNAME  TYPE ZTPPMO0011-ZNAME,
    END OF TYPE_ZID.
  DATA LT_ZID TYPE TABLE OF TYPE_ZID.
  SELECT DISTINCT A~ZID,A~ZWERKS,A~ZDAT,A~ZNAME
    INTO CORRESPONDING FIELDS OF TABLE @LT_ZID
    FROM ZTPPMO0011 AS A
    ORDER BY A~ZID DESCENDING.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      RETFIELD        = 'ZID'
      DYNPPROG        = SY-REPID
      DYNPNR          = SY-DYNNR
      VALUE_ORG       = 'S'
      DYNPROFIELD     = 'P_ZID'
    TABLES
      VALUE_TAB       = LT_ZID
    EXCEPTIONS
      PARAMETER_ERROR = 1
      NO_VALUES_FOUND = 2
      OTHERS          = 3.
  IF SY-SUBRC <> 0.
* Implement suitable error handling here
  ENDIF.



ENDFORM.

*&---------------------------------------------------------------------*
*& Form SEARCHHELP_ZMCRID
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM SEARCHHELP_ZMCRID.

  TYPES:
    BEGIN OF TYPE_ZMCRID,
      ZMCRID   TYPE ZTPPEC0005-ZMCRID,
      ZVERSN   TYPE ZTPPEC0017-ZVERSN,
      PUPOFMCR TYPE ZTPPEC0005-PUPOFMCR,
    END OF TYPE_ZMCRID.
  DATA LT_ZMCRID TYPE TABLE OF TYPE_ZMCRID.
  SELECT DISTINCT A~ZMCRID,B~ZVERSN,A~PUPOFMCR
    INTO CORRESPONDING FIELDS OF TABLE @LT_ZMCRID
    FROM ZTPPEC0005 AS A JOIN ZTPPEC0017 AS B ON B~ZMCRID = A~ZMCRID
    ORDER BY A~ZMCRID DESCENDING.


  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      RETFIELD        = 'ZMCRID'
      DYNPPROG        = SY-REPID
      DYNPNR          = SY-DYNNR
      VALUE_ORG       = 'S'
      DYNPROFIELD     = 'P_ZMCRID'
    TABLES
      VALUE_TAB       = LT_ZMCRID
    EXCEPTIONS
      PARAMETER_ERROR = 1
      NO_VALUES_FOUND = 2
      OTHERS          = 3.
  IF SY-SUBRC <> 0.
* Implement suitable error handling here
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form INITIAL
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM INITIAL.

  SSCRFIELDS-FUNCTXT_01 = '批量報庫存模板下载'.
  SSCRFIELDS-FUNCTXT_02 = '批量報庫存單價模板下载'.
*  SSCRFIELDS-FUNCTXT_03 = '發送郵件地址維護'.

  DATA L_SUBRC TYPE SY-SUBRC.
  CLEAR: GT_ZMCNTYPE,GT_ZMCNTYPE[].
  CALL FUNCTION 'DD_DOMVALUES_GET'
    EXPORTING
      DOMNAME        = 'ZMCNTYPE'          "域名称
      TEXT           = 'X'
      LANGU          = SY-LANGU              "语言代码
      BYPASS_BUFFER  = 'X'
    IMPORTING
      RC             = L_SUBRC
    TABLES
      DD07V_TAB      = GT_ZMCNTYPE[]
    EXCEPTIONS
      WRONG_TEXTFLAG = 1
      OTHERS         = 2.

  CLEAR: GT_ZSTOCK_STAT,GT_ZSTOCK_STAT[].
  CALL FUNCTION 'DD_DOMVALUES_GET'
    EXPORTING
      DOMNAME        = 'ZSTOCK_STAT'          "域名称
      TEXT           = 'X'
      LANGU          = SY-LANGU              "语言代码
      BYPASS_BUFFER  = 'X'
    IMPORTING
      RC             = L_SUBRC
    TABLES
      DD07V_TAB      = GT_ZSTOCK_STAT[]
    EXCEPTIONS
      WRONG_TEXTFLAG = 1
      OTHERS         = 2.

  SELECT * INTO TABLE GT_ZTPPEC0025 FROM ZTPPEC0025.
  IF GT_ZTPPEC0025[] IS NOT INITIAL.
    CLEAR: GT_ZSTOCK_STAT,GT_ZSTOCK_STAT[].
    LOOP AT GT_ZTPPEC0025.
      GT_ZSTOCK_STAT-DOMVALUE_L = GT_ZTPPEC0025-Z_STAT.
      GT_ZSTOCK_STAT-DDTEXT = GT_ZTPPEC0025-Z_STAT_DEC.
      APPEND GT_ZSTOCK_STAT.
    ENDLOOP.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form BTN_ADD100
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM BTN_ADD100.

  DATA LS_TABKUC0100 LIKE LINE OF GT_TABKUC0100.
  LOOP AT GT_TABKUC0100 ASSIGNING FIELD-SYMBOL(<LFS_TABKUC0100>).
    IF LS_TABKUC0100-ZSEQ < <LFS_TABKUC0100>-ZSEQ.
      LS_TABKUC0100-ZSEQ = <LFS_TABKUC0100>-ZSEQ.
    ENDIF.
  ENDLOOP.

  LS_TABKUC0100-ZID = GS_SCR0100-ZID.
  LS_TABKUC0100-ZVERSN = GS_SCR0100-ZVERSN.
  LS_TABKUC0100-WERKS = GS_SCR0100-WERKS.
  LS_TABKUC0100-ZSEQ = LS_TABKUC0100-ZSEQ + 1.
  LS_TABKUC0100-ERDAT = SY-DATUM.
  LS_TABKUC0100-ERZET = SY-UZEIT.
  LS_TABKUC0100-ERNAM = SY-UNAME.

  APPEND LS_TABKUC0100 TO GT_TABKUC0100.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form BTN_DEL100
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM BTN_DEL100 .

  DATA IT_DEL LIKE TABLE OF GS_TABKUC0100 WITH HEADER LINE.
  LOOP AT GT_TABKUC0100 INTO GS_TABKUC0100 WHERE SEL = 'X'.
    MOVE-CORRESPONDING GS_TABKUC0100 TO IT_DEL.
    APPEND IT_DEL.
  ENDLOOP.

  IF IT_DEL[] IS INITIAL.
    MESSAGE '至少需要選擇一條數據!' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  DATA LV_LINES1 TYPE I.
  DESCRIBE TABLE GT_TABKUC0100 LINES LV_LINES1.
  DATA LV_LINES2 TYPE I.
  DESCRIBE TABLE IT_DEL LINES LV_LINES2.

  IF LV_LINES2 < LV_LINES1.
    CLEAR GV_ANSWER.
    CALL FUNCTION 'POPUP_TO_CONFIRM_STEP'
      EXPORTING
*       DEFAULTOPTION  = 'Y'
        TEXTLINE1      = '確認要刪除選中的行'
*       TEXTLINE2      = '確認要刪除嗎？'
        TITEL          = '確認對話框'
*       START_COLUMN   = 25
*       START_ROW      = 6
        CANCEL_DISPLAY = SPACE
      IMPORTING
        ANSWER         = GV_ANSWER.
    IF GV_ANSWER = 'J'.
      LOOP AT GT_TABKUC0100 INTO DATA(WA_TABKUC0100) WHERE SEL = 'X'.
        DELETE FROM ZTPPEC0016 WHERE ZID = WA_TABKUC0100-ZID
                                 AND ZVERSN = WA_TABKUC0100-ZVERSN
                                 AND WERKS = WA_TABKUC0100-WERKS
                                 AND ZSEQ = WA_TABKUC0100-ZSEQ
                                 AND MATNR = WA_TABKUC0100-MATNR.
      ENDLOOP.
      DELETE GT_TABKUC0100 WHERE SEL = 'X'.
    ELSE.
      RETURN.
    ENDIF.
  ELSE.
    CLEAR GV_ANSWER.
    CALL FUNCTION 'POPUP_TO_CONFIRM_STEP'
      EXPORTING
*       DEFAULTOPTION  = 'Y'
        TEXTLINE1      = '確認要刪除整張單'
*       TEXTLINE2      = '確認要刪除嗎？'
        TITEL          = '確認對話框'
*       START_COLUMN   = 25
*       START_ROW      = 6
        CANCEL_DISPLAY = SPACE
      IMPORTING
        ANSWER         = GV_ANSWER.
    IF GV_ANSWER = 'J'.
      DELETE FROM ZTPPEC0015 WHERE ZID = GS_SCR0100-ZID
                               AND WERKS = GS_SCR0100-WERKS
                               AND ZVERSN = GS_SCR0100-ZVERSN.
      DELETE FROM ZTPPEC0016 WHERE ZID = GS_SCR0100-ZID
                               AND WERKS = GS_SCR0100-WERKS
                               AND ZVERSN = GS_SCR0100-ZVERSN.
      DELETE GT_TABKUC0100 WHERE SEL = 'X'.
      LEAVE TO SCREEN 0.
    ELSE.
      RETURN.
    ENDIF.
  ENDIF.



ENDFORM.

*&---------------------------------------------------------------------*
*& Form BTN_SAVE100
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM BTN_SAVE100.


  CLEAR GV_MSGTEXT.
  PERFORM CHECK_DATA USING GV_MSGTEXT.
  IF GV_MSGTEXT <> ''.
    MESSAGE GV_MSGTEXT TYPE 'E'.
  ENDIF.

  CLEAR GV_ANSWER.
  CALL FUNCTION 'POPUP_TO_CONFIRM_STEP'
    EXPORTING
*     DEFAULTOPTION  = 'Y'
      TEXTLINE1      = '確認保存有變更的數據？'
*     TEXTLINE2      = '確認要刪除嗎？'
      TITEL          = '確認對話框'
*     START_COLUMN   = 25
*     START_ROW      = 6
      CANCEL_DISPLAY = SPACE
    IMPORTING
      ANSWER         = GV_ANSWER.
  IF GV_ANSWER = 'J'.
  ELSE.
    RETURN.
  ENDIF.

  DATA LS_ZTPPEC0015 LIKE ZTPPEC0015.
  DATA LT_ZTPPEC0016 LIKE TABLE OF ZTPPEC0016 WITH HEADER LINE.

  MOVE-CORRESPONDING GS_SCR0100 TO LS_ZTPPEC0015.
  IF GS_SCR0100-OPTYPE = 'C'.
    LS_ZTPPEC0015-ERDAT = SY-DATUM.
    LS_ZTPPEC0015-ERZET = SY-UZEIT.
    LS_ZTPPEC0015-ERNAM = SY-UNAME.
    LS_ZTPPEC0015-AEDAT = SY-DATUM.
    LS_ZTPPEC0015-AEZET = SY-UZEIT.
    LS_ZTPPEC0015-AENAM = SY-UNAME.
  ELSEIF GS_SCR0100-OPTYPE = 'U'.
    LS_ZTPPEC0015-AEDAT = SY-DATUM.
    LS_ZTPPEC0015-AEZET = SY-UZEIT.
    LS_ZTPPEC0015-AENAM = SY-UNAME.
  ENDIF.
  LS_ZTPPEC0015-TCODE = SY-TCODE.

  DATA:
    BEGIN OF LT_MATNR OCCURS 0,
      MATNR LIKE GS_TABKUC0100-MATNR,
    END OF LT_MATNR.
  CLEAR: LT_MATNR,LT_MATNR[].

  LOOP AT GT_TABKUC0100 INTO GS_TABKUC0100.
    READ TABLE LT_MATNR WITH KEY MATNR = GS_TABKUC0100-MATNR.
    IF SY-SUBRC <> 0.
      LT_MATNR-MATNR = GS_TABKUC0100-MATNR.
      APPEND LT_MATNR.
    ELSE.
      MESSAGE '報庫存不允許多次輸入料號!' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

*  獲取庫存總數

    MOVE-CORRESPONDING GS_TABKUC0100 TO LT_ZTPPEC0016.
    LT_ZTPPEC0016-TCODE = SY-TCODE.
    APPEND LT_ZTPPEC0016.
*    DELETE FROM ZTPPEC0016 WHERE ZID = GS_TABKUC0100-ZID
*                             AND WERKS = GS_TABKUC0100-WERKS
*                             AND ZSEQ = GS_TABKUC0100-ZSEQ
*                             AND MATNR = GS_TABKUC0100-MATNR.
  ENDLOOP.

*  DELETE FROM ZTPPEC0016 WHERE ZID = GS_SCR0100-ZID
*                           AND ZVERSN = GS_SCR0100-ZVERSN
*                           AND WERKS = GS_SCR0100-WERKS.

  MODIFY ZTPPEC0015 FROM LS_ZTPPEC0015.
  MODIFY ZTPPEC0016 FROM TABLE LT_ZTPPEC0016[].

  MESSAGE '保存成功！' TYPE 'S'.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form REFRESH_TABKUC0100
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> GS_TABKUC0100
*&---------------------------------------------------------------------*
FORM REFRESH_TABKUC0100 USING US_TABKUC0100 LIKE GS_TABKUC0100.

  SELECT SINGLE A~MEINS B~MAKTX A~MSTAE
    INTO CORRESPONDING FIELDS OF US_TABKUC0100
    FROM MARA AS A LEFT JOIN MAKT AS B ON B~MATNR = A~MATNR
                                      AND B~SPRAS = 'M'
    WHERE A~MATNR = US_TABKUC0100-MATNR.

*  獲取工廠庫存數(理論存量)
  DATA LS_ZTPPRP0019 LIKE ZTPPRP0019.
  CLEAR LS_ZTPPRP0019.
  LS_ZTPPRP0019-ARTICLE_LONG = US_TABKUC0100-MATNR.
  LS_ZTPPRP0019-PLANT = US_TABKUC0100-WERKS.
  SELECT MAX( ZDSDAT ) INTO LS_ZTPPRP0019-ZDSDAT
    FROM ZTPPRP0019
    WHERE ARTICLE_LONG = LS_ZTPPRP0019-ARTICLE_LONG
      AND PLANT = LS_ZTPPRP0019-PLANT
      AND DELETION_FLAG = ''.
  SELECT SUM( QUANTITY ) INTO LS_ZTPPRP0019-QUANTITY
    FROM ZTPPRP0019
    WHERE ARTICLE_LONG = LS_ZTPPRP0019-ARTICLE_LONG
      AND PLANT = LS_ZTPPRP0019-PLANT
      AND ZDSDAT = LS_ZTPPRP0019-ZDSDAT
      AND DELETION_FLAG = ''.
  US_TABKUC0100-QUANTITY = LS_ZTPPRP0019-QUANTITY.

*  讀取客戶別
  CLEAR US_TABKUC0100-KHB.
  SELECT SINGLE VTWEG INTO US_TABKUC0100-KHB FROM ZTSD0020
    WHERE ZCN = US_TABKUC0100-ZZCN
      AND ZDEFAULT = 'X'
      AND ZCN <> ''
*      AND MATNR = US_TABKUC0100-MATNR
    .
  IF SY-SUBRC <> 0.
    SELECT SINGLE VTWEG INTO US_TABKUC0100-KHB FROM ZTSD0020
      WHERE ZCN = US_TABKUC0100-ZZCN
        AND ZCN <> ''
*      AND ZDEFAULT = 'X'
*      AND MATNR = US_TABKUC0100-MATNR
      .
  ENDIF.

ENDFORM.

FORM GET_PRICE TABLES UT_MATNR STRUCTURE GS_MATNRPRICE.


  DATA LT_COMP LIKE TABLE OF ZSQT0201COMP WITH HEADER LINE.
  CLEAR: LT_COMP,LT_COMP[].

  LOOP AT UT_MATNR.
*    取最新的價格
    DATA LS_MARA LIKE MARA.
    CLEAR LS_MARA.
    SELECT SINGLE * INTO LS_MARA FROM MARA
      WHERE MATNR = UT_MATNR-MATNR.
    DATA LS_MARC LIKE MARC.
    CLEAR LS_MARC.
    SELECT SINGLE * INTO LS_MARC FROM MARC
      WHERE MATNR = UT_MATNR-MATNR
        AND WERKS = UT_MATNR-WERKS.
    UT_MATNR-BESKZ = LS_MARC-BESKZ.
    UT_MATNR-SOBSL = LS_MARC-SOBSL.
    IF LS_MARC-BESKZ = 'F' AND LS_MARC-SOBSL = ''. "外部采購F并且不是特殊采購

      CLEAR LT_COMP.
      LT_COMP-IDNRK = UT_MATNR-MATNR.
      LT_COMP-WERKS_C = UT_MATNR-WERKS.
      LT_COMP-MENGE_C = '1'.
      LT_COMP-MEINS = LS_MARA-MEINS.
*        LT_COMP-WAERS_D = 'CNY'.
      LT_COMP-TAXFLAG_D = 'X'.
      APPEND LT_COMP.
    ENDIF.

  ENDLOOP.

  CHECK LT_COMP[] IS NOT INITIAL.

  CALL FUNCTION 'Z_QT_COMP_PRICE_GET'
    EXPORTING
      PRSDT     = SY-DATUM
**          SOURCE_C        =
      PRICEFLAG = 'X'
*        IMPORTING
*     E_MSG     =
    TABLES
      ET_COMP   = LT_COMP.

  LOOP AT UT_MATNR.
    READ TABLE LT_COMP WITH KEY IDNRK = UT_MATNR-MATNR WERKS_C = UT_MATNR-WERKS.
    IF SY-SUBRC = 0.
      UT_MATNR-ZUPRICE = ( LT_COMP-UP_M + LT_COMP-UP_P + LT_COMP-UP_E ) * ( 1 + LT_COMP-TAXRATE ). " * LV_FACTOR. "單價
      UT_MATNR-WAERS = LT_COMP-WAERS_C.
      DATA LV_FACTOR TYPE P DECIMALS 3. "轉換因子
      CLEAR: LV_FACTOR.
      CALL FUNCTION 'CURRENCY_CONVERTING_FACTOR'
        EXPORTING
          CURRENCY          = UT_MATNR-WAERS
        IMPORTING
          FACTOR            = LV_FACTOR
        EXCEPTIONS
          TOO_MANY_DECIMALS = 1
          OTHERS            = 2.
      IF LV_FACTOR <= 0.
        LV_FACTOR = 1.
      ENDIF.
      UT_MATNR-ZUPRICE = UT_MATNR-ZUPRICE / LV_FACTOR.
      UT_MATNR-ZUPRICE2 = ( LT_COMP-UP_M + LT_COMP-UP_P + LT_COMP-UP_E ) * ( 1 + LT_COMP-TAXRATE ). " * LV_FACTOR. "單價4位小數
    ENDIF.
*  判斷單價是否存在
    IF UT_MATNR-ZUPRICE2 > 0.
      UT_MATNR-ISDJCZ = 'Y'.
    ELSE.
      UT_MATNR-ISDJCZ = 'N'.
    ENDIF.
    MODIFY UT_MATNR.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CHECK_DATA
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> GV_MSGTEXT
*&---------------------------------------------------------------------*
FORM CHECK_DATA USING US_MSGTEXT.

  CLEAR US_MSGTEXT.
  DATA LS_TMPDATA LIKE GS_TABKUC0100.
  SELECT SINGLE A~MEINS B~MAKTX
    INTO CORRESPONDING FIELDS OF LS_TMPDATA
    FROM MARA AS A LEFT JOIN MAKT AS B ON B~MATNR = A~MATNR
                                      AND B~SPRAS = 'M'
    WHERE A~MATNR = GS_TABKUC0100-MATNR.
  IF SY-SUBRC <> 0.
    US_MSGTEXT = '物料號' && GS_TABKUC0100-MATNR && '不存在'.
    RETURN.
  ENDIF.

  IF GS_TABKUC0100-ZDECL_QTY <= 0.
    US_MSGTEXT = '報庫存數量不能為0'.
    RETURN.
  ENDIF.
*  IF  GS_TABKUC0100-ZTOT_STOCK <= 0.
*    US_MSGTEXT = '庫存總數不能為0'.
*    RETURN.
*  ENDIF.
  IF  GS_TABKUC0100-ZSTOCK_STAT = ''.
    US_MSGTEXT = '庫存處理方式不能為空'.
    RETURN.
  ENDIF.
*  IF  GS_TABKUC0100-ZUPRICE <= 0.
*    US_MSGTEXT = '單價不能為0'.
*    RETURN.
*  ENDIF.
*  DATA LS_TCURC LIKE TCURC.
*  SELECT SINGLE * INTO LS_TCURC FROM TCURC
*    WHERE WAERS = GS_TABKUC0100-WAERS.
*  IF SY-SUBRC <> 0.
*    US_MSGTEXT = '幣別輸入錯誤'.
*    RETURN.
*  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CALL_R2
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM CALL_R2.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form REFRESH_TABKUC0200
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> GS_TABKUC0200
*&---------------------------------------------------------------------*
FORM REFRESH_TABKUC0200  USING    P_GS_TABKUC0200.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form GET_DATA
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM GET_DATA.

*  SELECT ZID ZWERKS AS WERKS INTO CORRESPONDING FIELDS OF TABLE GT_ALV
*    FROM ZTPPMO0011
*    WHERE ZID IN S_ZID
*      AND ZWERKS = P_WERKS.
*  LOOP AT GT_ALV.
*    GT_ALV-ZMCNTYPE = '2'. "指定PO
*    MODIFY GT_ALV.
*  ENDLOOP.
*
*  SELECT ZMCRID AS ZID INTO CORRESPONDING FIELDS OF TABLE GT_ALV
*    FROM ZTPPEC0005
*    WHERE ZMCRID IN S_ZMCRID.
*  LOOP AT GT_ALV.
*    GT_ALV-WERKS = P_WERKS.
*    GT_ALV-ZMCNTYPE = '2'. "指定PO
*    MODIFY GT_ALV.
*  ENDLOOP.

*  Z_PROD01 權限檢查，

*  ZQXPEC006



*  AUTHORITY-CHECK OBJECT 'Z_PRODZ01'
*   ID 'ZACTVT' FIELD 'X'.
*  IF SY-SUBRC <> 0.
*    MESSAGE '沒有權限' TYPE 'S' DISPLAY LIKE 'E'.
*    RETURN.
*  ENDIF.


  CLEAR: GS_SCR0100,GS_ZTPPMO0011,GS_ZTPPEC0005.
  IF P_ZID <> ''.
    GS_SCR0100-ZID = P_ZID.
    GS_SCR0100-ZMCNTYPE = '2'.
  ELSEIF P_ZMCRID <> ''.
    GS_SCR0100-ZID = P_ZMCRID.
    GS_SCR0100-ZVERSN = P_ZVERSN.
    GS_SCR0100-ZMCNTYPE = '1'.
  ENDIF.
  GS_SCR0100-WERKS = P_WERKS.

  SELECT SINGLE *
    FROM ZTPPEC0015
    WHERE ZID = @GS_SCR0100-ZID
      AND ZVERSN = @GS_SCR0100-ZVERSN
      AND WERKS = @GS_SCR0100-WERKS
    INTO CORRESPONDING FIELDS OF @GS_SCR0100.
  IF SY-SUBRC = 0.
    GS_SCR0100-OPTYPE = 'U'.
  ELSE.
    GS_SCR0100-OPTYPE = 'C'.
  ENDIF.


  READ TABLE GT_ZMCNTYPE WITH KEY DOMVALUE_L = GS_SCR0100-ZMCNTYPE.
  IF SY-SUBRC = 0.
    GS_SCR0100-ZMCNTYPE_T = GT_ZMCNTYPE-DDTEXT.
  ENDIF.

  SELECT A~* ,B~MAKTX,M~MEINS,E~Z_PRC,E~Z_SALS,E~Z_PUR,E~Z_PRC_STC,F~MCRSTAT,
    C~BESKZ, C~SOBSL
    FROM ZTPPEC0016 AS A JOIN MARA AS M ON M~MATNR = A~MATNR
                         JOIN MARC AS C ON C~MATNR = A~MATNR
                                       AND C~WERKS = A~WERKS
                    LEFT JOIN MAKT AS B ON B~MATNR = A~MATNR
                                       AND B~SPRAS = 'M'
                    LEFT JOIN ZTPPEC0025 AS E ON E~Z_STAT = A~ZSTOCK_STAT
                    LEFT JOIN ZTPPEC0017 AS F ON F~ZMCRID = A~ZID
                                             AND F~ZVERSN = A~ZVERSN
    WHERE A~ZID = @GS_SCR0100-ZID
      AND A~ZVERSN = @GS_SCR0100-ZVERSN
      AND A~WERKS = @GS_SCR0100-WERKS
    INTO CORRESPONDING FIELDS OF TABLE @GT_TABKUC0100.

  SORT GT_TABKUC0100 BY ZSEQ.

  IF P_R1 = 'X'. "6.1生管維護報庫存作業


    IF P_SHOW2 = ''.
      LOOP AT GT_ZTPPEC0025 WHERE Z_PRC = ''. "沒有生管權限的資料刪除
        DELETE GT_TABKUC0100 WHERE ZSTOCK_STAT = GT_ZTPPEC0025-Z_STAT.
      ENDLOOP.
    ENDIF.

    IF GS_SCR0100-OPTYPE = 'C'.
      IF GS_SCR0100-ZMCNTYPE = '2'. "指定PO
        SELECT SINGLE * INTO CORRESPONDING FIELDS OF GS_ZTPPMO0011
          FROM ZTPPMO0011
          WHERE ZID = GS_SCR0100-ZID.
        IF SY-SUBRC <> 0.
          MESSAGE '指定PO號碼不存在或尚未切單變更！' TYPE 'S' DISPLAY LIKE 'E'.
          RETURN.
        ENDIF.
        GS_SCR0100-ZSGZT = GS_ZTPPMO0011-ZSTA. "生管狀態

        SELECT SINGLE B~VTWEG INTO GS_SCR0100-WL2_CUST
          FROM ZTPPMO0015 AS A JOIN VBAK AS B ON B~VBELN = A~VBELN
          WHERE ZID = GS_SCR0100-ZID.

      ELSEIF GS_SCR0100-ZMCNTYPE = '1'. "MCR號碼
        SELECT SINGLE * INTO CORRESPONDING FIELDS OF GS_ZTPPEC0017
          FROM ZTPPEC0017
          WHERE ZMCRID = GS_SCR0100-ZID
            AND ZVERSN = GS_SCR0100-ZVERSN "版次
          .
        IF SY-SUBRC <> 0.
          MESSAGE 'MCR號碼和版次不存在！' TYPE 'S' DISPLAY LIKE 'E'.
          RETURN.
        ENDIF.

        GS_SCR0100-ZSGZT = GS_ZTPPEC0017-MCRSTAT. "生管狀態

        DATA LV_ZTRAN_ID LIKE ZTPPEC0005-ZTRAN_ID.
        CLEAR LV_ZTRAN_ID.
        SELECT MAX( ZTRAN_ID ) INTO LV_ZTRAN_ID FROM ZTPPEC0005
          WHERE ZMCRID = GS_SCR0100-ZID.
        CLEAR GS_ZTPPEC0005.
        SELECT SINGLE * INTO CORRESPONDING FIELDS OF GS_ZTPPEC0005
          FROM ZTPPEC0005
          WHERE ZMCRID = GS_SCR0100-ZID
            AND ZTRAN_ID = LV_ZTRAN_ID.
        IF GS_ZTPPEC0005 IS INITIAL.
          MESSAGE 'MCR號碼不存在或尚未切單變更！' TYPE 'S' DISPLAY LIKE 'E'.
          RETURN.
        ENDIF.

        GS_SCR0100-WL2_CUST = GS_ZTPPEC0005-WL2_CUST. "客戶別

*        業務負責人字段填寫
        IF GS_SCR0100-ZYWFZR IS INITIAL.
          IF GS_ZTPPEC0005-OWN_GROUP CS '業務部'.
            GS_SCR0100-ZYWFZR = GS_ZTPPEC0005-OWN_USER.
          ELSE.
            IF GS_ZTPPEC0005-WL2_PM IS NOT INITIAL.
              GS_SCR0100-ZYWFZR = GS_ZTPPEC0005-WL2_PM.
            ENDIF.
          ENDIF.
        ENDIF.

      ENDIF.
    ENDIF.
  ELSEIF P_R2 = 'X'. "生管維護庫存預採帳作業
    IF P_SHOW2 = ''.
      LOOP AT GT_ZTPPEC0025 WHERE Z_PRC = ''. "沒有生管權限的資料刪除
        DELETE GT_TABKUC0100 WHERE ZSTOCK_STAT = GT_ZTPPEC0025-Z_STAT.
      ENDLOOP.
    ENDIF.
    IF GS_SCR0100-OPTYPE = 'C'.
      MESSAGE '單據號碼不存在，先進行生管維護報庫存作業' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
  ELSEIF P_R3 = 'X'. "業務回覆作業
    IF P_SHOW2 = ''.
      LOOP AT GT_ZTPPEC0025 WHERE Z_SALS = ''. "沒有業務權限的資料刪除
        DELETE GT_TABKUC0100 WHERE ZSTOCK_STAT = GT_ZTPPEC0025-Z_STAT.
      ENDLOOP.
    ENDIF.
    IF GS_SCR0100-OPTYPE = 'C'.
      MESSAGE '該單據無報庫存內容' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    READ TABLE GT_TABKUC0100 INTO GS_TABKUC0100 WITH KEY ZUPRICE2 = 0. "存在報價為0的資料
    IF SY-SUBRC = 0.
      MESSAGE '該單據尚未完成報價' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
  ELSEIF P_R4 = 'X'. "採購單價回覆作業
    IF P_SHOW2 = ''.
      LOOP AT GT_ZTPPEC0025 WHERE Z_PUR = ''. "沒有采購權限的資料刪除
        DELETE GT_TABKUC0100 WHERE ZSTOCK_STAT = GT_ZTPPEC0025-Z_STAT.
      ENDLOOP.
    ENDIF.
    IF GS_SCR0100-OPTYPE = 'C'.
      MESSAGE '單據號碼不存在，先進行生管維護報庫存作業' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
  ELSEIF P_R5 = 'X'. "工程回覆作業
    IF P_SHOW2 = ''.
      LOOP AT GT_ZTPPEC0025 WHERE Z_PRO = ''. "沒有工程權限的資料刪除
        DELETE GT_TABKUC0100 WHERE ZSTOCK_STAT = GT_ZTPPEC0025-Z_STAT.
      ENDLOOP.
    ENDIF.
    IF GS_SCR0100-OPTYPE = 'C'.
      MESSAGE '單據號碼不存在，先進行生管維護報庫存作業' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
  ENDIF.

*  生管狀態
  IF GS_SCR0100-ZSGZT IS INITIAL.
    IF GS_SCR0100-ZMCNTYPE = '2'.
      SELECT SINGLE ZSTA INTO GS_SCR0100-ZSGZT
        FROM ZTPPMO0011
        WHERE ZID = GS_SCR0100-ZID.
*      GS_SCR0100-ZSGZT = GS_ZTPPMO0011-ZSTA.
    ELSEIF GS_SCR0100-ZMCNTYPE = '1'.
      SELECT SINGLE MCRSTAT INTO GS_SCR0100-ZSGZT
        FROM ZTPPEC0017
        WHERE ZMCRID = GS_SCR0100-ZID
          AND ZVERSN = GS_SCR0100-ZVERSN "版次
        .
*      GS_SCR0100-ZSGZT = GS_ZTPPEC0017-MCRSTAT.
    ENDIF.
  ENDIF.

  IF GS_SCR0100-ZSGZT = '2'. "生管狀態2，則不可編輯
*    P_SHOW = 'X'.
  ENDIF.

*  客戶別處理
  CLEAR: GS_SCR0100-VTWEG_T.
  IF GS_SCR0100-WL2_CUST IS INITIAL.
    IF GS_SCR0100-ZMCNTYPE = '1'. "MCR號碼
      CLEAR LV_ZTRAN_ID.
      SELECT MAX( ZTRAN_ID ) INTO LV_ZTRAN_ID FROM ZTPPEC0005
        WHERE ZMCRID = GS_SCR0100-ZID.
      CLEAR GS_ZTPPEC0005.
      SELECT SINGLE WL2_CUST INTO GS_SCR0100-WL2_CUST
        FROM ZTPPEC0005
        WHERE ZMCRID = GS_SCR0100-ZID
          AND ZTRAN_ID = LV_ZTRAN_ID.
    ELSEIF GS_SCR0100-ZMCNTYPE = '2'. "指定PO
      SELECT SINGLE B~VTWEG INTO GS_SCR0100-WL2_CUST
        FROM ZTPPMO0015 AS A JOIN VBAK AS B ON B~VBELN = A~VBELN
        WHERE ZID = GS_SCR0100-ZID.
    ENDIF.
  ENDIF.
  IF GS_SCR0100-WL2_CUST IS NOT INITIAL.
    DATA:
      BEGIN OF LT_SPLIT OCCURS 0,
        STR LIKE ZTSD1011-ZBRAND,
      END OF LT_SPLIT.
    CLEAR: LT_SPLIT,LT_SPLIT[].
    SPLIT GS_SCR0100-WL2_CUST AT '|' INTO TABLE LT_SPLIT.
    DATA LS_SPLIT LIKE LINE OF LT_SPLIT.
    CLEAR LS_SPLIT.
    IF LT_SPLIT[] IS INITIAL.
      LS_SPLIT = GS_SCR0100-WL2_CUST.
      APPEND LS_SPLIT TO LT_SPLIT.
    ENDIF.
    IF LT_SPLIT[] IS NOT INITIAL.
      SELECT DISTINCT VTWEG INTO TABLE @DATA(LT_VTWEG) FROM ZTSD1011
        FOR ALL ENTRIES IN @LT_SPLIT[]
        WHERE ZBRAND = @LT_SPLIT-STR.
    ENDIF.
    LOOP AT LT_VTWEG INTO DATA(LS_VTWEG).
      IF GS_SCR0100-VTWEG_T IS INITIAL.
        GS_SCR0100-VTWEG_T = LS_VTWEG-VTWEG.
      ELSE.
        GS_SCR0100-VTWEG_T = GS_SCR0100-VTWEG_T && '|' && LS_VTWEG-VTWEG.
      ENDIF.
    ENDLOOP.
    CLEAR: LT_VTWEG.
  ENDIF.

*  獲取物料價格
  CLEAR: GT_MATNRPRICE,GT_MATNRPRICE[].
  LOOP AT GT_TABKUC0100 INTO GS_TABKUC0100.
    GT_MATNRPRICE-MATNR = GS_TABKUC0100-MATNR.
    GT_MATNRPRICE-WERKS = GS_TABKUC0100-WERKS.
    APPEND GT_MATNRPRICE.
  ENDLOOP.
  PERFORM GET_PRICE TABLES GT_MATNRPRICE.


  LOOP AT GT_TABKUC0100 INTO GS_TABKUC0100.
    PERFORM REFRESH_TABKUC0100 USING GS_TABKUC0100.
    IF GS_TABKUC0100-BESKZ = 'F' AND GS_TABKUC0100-SOBSL = ''. "外購,取最新價格
      READ TABLE GT_MATNRPRICE WITH KEY MATNR = GS_TABKUC0100-MATNR
                                        WERKS = GS_TABKUC0100-WERKS.
      IF SY-SUBRC = 0 .
        GS_TABKUC0100-ZUPRICE = GT_MATNRPRICE-ZUPRICE.
        GS_TABKUC0100-ZUPRICE2 = GT_MATNRPRICE-ZUPRICE2.
        GS_TABKUC0100-WAERS = GT_MATNRPRICE-WAERS.
        GS_TABKUC0100-ISDJCZ = GT_MATNRPRICE-ISDJCZ. "單價是否存在
      ENDIF.
    ELSE.
    ENDIF.
    MODIFY GT_TABKUC0100 FROM GS_TABKUC0100.
  ENDLOOP.

  CALL FUNCTION 'ENQUEUE_EZ_ZTPPEC0015'
    EXPORTING
      MODE_ZTPPEC0015 = 'X'
      MANDT           = SY-MANDT
      ZID             = GS_SCR0100-ZID
      WERKS           = GS_SCR0100-WERKS
*     X_ZID           = ' '
*     X_WERKS         = ' '
*     _SCOPE          = '2'
*     _WAIT           = ' '
*     _COLLECT        = ' '
    EXCEPTIONS
      FOREIGN_LOCK    = 1
      SYSTEM_FAILURE  = 2
      OTHERS          = 3.
  IF SY-SUBRC <> 0.
    DATA LV_NAMETEXT LIKE SY-MSGV1.
    SELECT SINGLE NAME_TEXT INTO LV_NAMETEXT FROM V_USERNAME
      WHERE BNAME = SY-MSGV1.
    SY-MSGV1 = SY-MSGV1 && LV_NAMETEXT.
    MESSAGE ID SY-MSGID TYPE 'E' NUMBER SY-MSGNO
      WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4 INTO GV_MSGTEXT.
*    GV_MSGTEXT = GS_SCR0100-ZID && GS_SCR0100-WERKS && GV_MSGTEXT.
    MESSAGE GV_MSGTEXT TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  CALL SCREEN 100.

  CALL FUNCTION 'DEQUEUE_EZ_ZTPPEC0015'
    EXPORTING
      MODE_ZTPPEC0015 = 'X'
      MANDT           = SY-MANDT
      ZID             = GS_SCR0100-ZID
      WERKS           = GS_SCR0100-WERKS
*     X_ZID           = ' '
*     X_WERKS         = ' '
*     _SCOPE          = '3'
*     _SYNCHRON       = ' '
*     _COLLECT        = ' '
    .


ENDFORM.

*&---------------------------------------------------------------------*
*& Form FRM_DOWNEXCEL
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM FRM_DOWNEXCEL.

  DATA:
    LV_DESTINATION TYPE RLGRAP-FILENAME,
    LS_KEY         TYPE WWWDATATAB.

  DATA: LV_PATH      TYPE STRING VALUE'',
        LV_FULLPATH  TYPE STRING  VALUE'',
        LV_FILENAME  TYPE  STRING,
        LV_EXTENSION TYPE  STRING,
        LV_OBJID     TYPE  W3OBJID.


  CASE SSCRFIELDS-UCOMM.
    WHEN 'FC01'.
      LV_FILENAME = 'ZPEC006_template1'.
      LV_EXTENSION = 'XLSX'.
      LV_OBJID = 'ZPEC006_EXCEL1'.
    WHEN 'FC02'.
      LV_FILENAME = 'ZPEC006_template2'.
      LV_EXTENSION = 'XLSX'.
      LV_OBJID = 'ZPEC006_EXCEL2'.
  ENDCASE.

  CALL METHOD CL_GUI_FRONTEND_SERVICES=>FILE_SAVE_DIALOG "调用保存对话框
    EXPORTING
      DEFAULT_EXTENSION    = LV_EXTENSION
      DEFAULT_FILE_NAME    = LV_FILENAME
    CHANGING
      FILENAME             = LV_FILENAME
      PATH                 = LV_PATH
      FULLPATH             = LV_FULLPATH
    EXCEPTIONS
      CNTL_ERROR           = 1
      ERROR_NO_GUI         = 2
      NOT_SUPPORTED_BY_GUI = 3
      OTHERS               = 4.
  IF SY-SUBRC EQ 0.
  ELSE.
  ENDIF.

  IF LV_FULLPATH = ''.
    MESSAGE  'Error! download template failed.' TYPE 'E'.
  ENDIF.

  LV_DESTINATION = LV_FULLPATH.

  LS_KEY-RELID = 'MI'.
  LS_KEY-OBJID = LV_OBJID.

  CALL FUNCTION 'DOWNLOAD_WEB_OBJECT'
    EXPORTING
      KEY         = LS_KEY
      DESTINATION = LV_DESTINATION.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form SET_FILEPATH
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM SET_FILEPATH.

  DATA:
    LV_FILES   TYPE FILETABLE,
    LV_FILE    TYPE LINE OF FILETABLE,
    LV_SUBRC   TYPE SY-SUBRC,
    LV_DEFNAME TYPE STRING.


  LV_DEFNAME  = 'C:\Temp\PO_' && SY-DATUM && SY-UZEIT.
  CALL METHOD CL_GUI_FRONTEND_SERVICES=>FILE_OPEN_DIALOG
    EXPORTING
      WINDOW_TITLE            = 'Please select a file'
      DEFAULT_EXTENSION       = '*.xlsx'
*     DEFAULT_FILENAME        = LV_DEFNAME
      FILE_FILTER             = 'Excel Files (*.xlsx)|*.xlsx|All Files (*.*)|*.*|Excel Files (*.xls)|*.xls'
*     WITH_ENCODING           =
*     INITIAL_DIRECTORY       =
*     MULTISELECTION          =
    CHANGING
      FILE_TABLE              = LV_FILES
      RC                      = LV_SUBRC
*     USER_ACTION             =
*     FILE_ENCODING           =
    EXCEPTIONS
      FILE_OPEN_DIALOG_FAILED = 1
      CNTL_ERROR              = 2
      ERROR_NO_GUI            = 3
      NOT_SUPPORTED_BY_GUI    = 4
      OTHERS                  = 5.
  IF SY-SUBRC = 0 AND LV_SUBRC = 1.
    LOOP AT LV_FILES INTO LV_FILE.
      P_PATH = LV_FILE.
    ENDLOOP.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form UPLOAD_R6
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM UPLOAD_R6.


  DATA:
    GD_SCOL TYPE I VALUE '2',
    GD_SROW TYPE I VALUE '3',
    GD_ECOL TYPE I VALUE '10',
    GD_EROW TYPE I VALUE '65536'.

  FIELD-SYMBOLS: <FS>.
  DATA: LT_INTERN TYPE ALSMEX_TABLINE OCCURS 0 WITH HEADER LINE,
        LD_INDEX  TYPE I.
* Upload Data from EXCEL to SAP ITAB
  DATA LV_PATH LIKE RLGRAP-FILENAME.
  LV_PATH = P_PATH.
  CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
    EXPORTING
      FILENAME                = P_PATH
      I_BEGIN_COL             = GD_SCOL
      I_BEGIN_ROW             = GD_SROW
      I_END_COL               = GD_ECOL
      I_END_ROW               = GD_EROW
    TABLES
      INTERN                  = LT_INTERN
    EXCEPTIONS
      INCONSISTENT_PARAMETERS = 1
      UPLOAD_OLE              = 2
      OTHERS                  = 3.

  IF SY-SUBRC <> 0.
* Implement suitable error handling here
    MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
    WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
  ENDIF.

  IF LT_INTERN[] IS INITIAL.
    RETURN.
  ENDIF.


  DATA: LT_EXCEL LIKE TABLE OF GS_EXCEL_R1 WITH HEADER LINE.

  SORT LT_INTERN BY ROW COL.
  LOOP AT LT_INTERN.
    MOVE LT_INTERN-COL TO LD_INDEX.
    ASSIGN COMPONENT LD_INDEX OF STRUCTURE LT_EXCEL TO <FS>.
    MOVE LT_INTERN-VALUE TO <FS>.
    AT END OF ROW.
      APPEND LT_EXCEL TO LT_EXCEL.
      CLEAR: LT_EXCEL.
    ENDAT.
  ENDLOOP.
  CLEAR: LT_INTERN[].

  CLEAR: GT_MATNRPRICE,GT_MATNRPRICE[].

  LOOP AT LT_EXCEL.

    IF LT_EXCEL-ZDECL_QTY <= 0.
      IF LT_EXCEL-MSG_TYPE = ''.
        LT_EXCEL-MSG_TYPE = 'E'.
        LT_EXCEL-MSG_TEXT = '報庫存數量必須大於0'.
      ENDIF.
    ENDIF.

    IF LT_EXCEL-ZSTOCK_STAT = '1' OR
      LT_EXCEL-ZSTOCK_STAT = '2' OR
      LT_EXCEL-ZSTOCK_STAT = '3' OR
      LT_EXCEL-ZSTOCK_STAT = '4' OR
      LT_EXCEL-ZSTOCK_STAT = '5' OR
      LT_EXCEL-ZSTOCK_STAT = '6' OR
      LT_EXCEL-ZSTOCK_STAT = '7'
      .
    ELSE.
      IF LT_EXCEL-MSG_TYPE = ''.
        LT_EXCEL-MSG_TYPE = 'E'.
        LT_EXCEL-MSG_TEXT = '庫存處理方式只能是1到7'.
      ENDIF.
    ENDIF.

    IF LT_EXCEL-ISOK = '' OR LT_EXCEL-ISOK = 'X'.
    ELSE.
      IF LT_EXCEL-MSG_TYPE = ''.
        LT_EXCEL-MSG_TYPE = 'E'.
        LT_EXCEL-MSG_TEXT = '是否處理OK，只能是空或X'.
      ENDIF.
    ENDIF.
    IF LT_EXCEL-ZREPL_INV = '' OR LT_EXCEL-ZREPL_INV = 'X'.
    ELSE.
      IF LT_EXCEL-MSG_TYPE = ''.
        LT_EXCEL-MSG_TYPE = 'E'.
        LT_EXCEL-MSG_TEXT = '是否補報庫存，只能是空或X'.
      ENDIF.
    ENDIF.

    DATA LS_ZTPPEC0015 LIKE ZTPPEC0015.
    CLEAR LS_ZTPPEC0015.
    SELECT SINGLE *
      FROM ZTPPEC0015
      WHERE ZID = @LT_EXCEL-ZID
        AND ZVERSN = @LT_EXCEL-ZVERSN
        AND WERKS = @LT_EXCEL-WERKS
      INTO @LS_ZTPPEC0015.
    IF SY-SUBRC = 0.
*ZTPPEC0015表字段
      LT_EXCEL-OPTYPE = 'U'. "修改
      LT_EXCEL-ZYWFZR = LS_ZTPPEC0015-ZYWFZR.        "業務負責人
      LT_EXCEL-ZSGZT = LS_ZTPPEC0015-ZSGZT.         "生管狀態
      LT_EXCEL-WL2_CUST = LS_ZTPPEC0015-WL2_CUST.      "客戶別
      LT_EXCEL-ZMCNTYPE = LS_ZTPPEC0015-ZMCNTYPE.      "單據類別（指定PO或MCR變更）
      LT_EXCEL-ERDAT = LS_ZTPPEC0015-ERDAT.
      LT_EXCEL-ERZET = LS_ZTPPEC0015-ERZET.
      LT_EXCEL-ERNAM = LS_ZTPPEC0015-ERNAM.
      LT_EXCEL-AEDAT = LS_ZTPPEC0015-AEDAT.
      LT_EXCEL-AEZET = LS_ZTPPEC0015-AEZET.
      LT_EXCEL-AENAM = LS_ZTPPEC0015-AENAM.
      LT_EXCEL-TCODE = LS_ZTPPEC0015-TCODE.

      CLEAR GS_TABKUC0100.
      SELECT SINGLE A~*,B~MAKTX,M~MEINS,E~Z_PRC,E~Z_SALS,E~Z_PUR,E~Z_PRC_STC
        FROM ZTPPEC0016 AS A JOIN MARA AS M ON M~MATNR = A~MATNR
                        LEFT JOIN MAKT AS B ON B~MATNR = A~MATNR
                                           AND B~SPRAS = 'M'
                        LEFT JOIN ZTPPEC0025 AS E ON E~Z_STAT = A~ZSTOCK_STAT
        WHERE A~ZID = @LT_EXCEL-ZID
          AND A~ZVERSN = @LT_EXCEL-ZVERSN
          AND A~WERKS = @LT_EXCEL-WERKS
          AND A~MATNR = @LT_EXCEL-MATNR
        INTO CORRESPONDING FIELDS OF @GS_TABKUC0100.

      IF GS_TABKUC0100 IS NOT INITIAL.
*ZTPPEC0016表字段
        LT_EXCEL-ZSEQ = GS_TABKUC0100-ZSEQ.
        LT_EXCEL-ZTOT_STOCK = GS_TABKUC0100-ZTOT_STOCK.
        LT_EXCEL-ZSTOCK_STAT2 = GS_TABKUC0100-ZSTOCK_STAT2.
        LT_EXCEL-ZUPRICE = GS_TABKUC0100-ZUPRICE.
        LT_EXCEL-WAERS = GS_TABKUC0100-WAERS.
        LT_EXCEL-ZZCN = GS_TABKUC0100-ZZCN.
        LT_EXCEL-KUNAG = GS_TABKUC0100-KUNAG.
        LT_EXCEL-ZUNIT_CONS = GS_TABKUC0100-ZUNIT_CONS.
        LT_EXCEL-ZTF_PREPO = GS_TABKUC0100-ZTF_PREPO.
        LT_EXCEL-ZPM_AENAM = GS_TABKUC0100-ZPM_AENAM.
        LT_EXCEL-ZPM_AEDAT = GS_TABKUC0100-ZPM_AEDAT.
        LT_EXCEL-ZREP_AENAM = GS_TABKUC0100-ZREP_AENAM.
        LT_EXCEL-ZREP_AEDAT = GS_TABKUC0100-ZREP_AEDAT.
        LT_EXCEL-ZSA_REP = GS_TABKUC0100-ZSA_REP.
        LT_EXCEL-ZSA_AENAM = GS_TABKUC0100-ZSA_AENAM.
        LT_EXCEL-ZSA_AEDAT = GS_TABKUC0100-ZSA_AEDAT.
        LT_EXCEL-ZPU_AENAM = GS_TABKUC0100-ZPU_AENAM.
        LT_EXCEL-ZPU_AEDAT = GS_TABKUC0100-ZPU_AEDAT.
        LT_EXCEL-ZDNNO = GS_TABKUC0100-ZDNNO.
        LT_EXCEL-ERDAT2 = GS_TABKUC0100-ERDAT.
        LT_EXCEL-ERZET2 = GS_TABKUC0100-ERZET.
        LT_EXCEL-ERNAM2 = GS_TABKUC0100-ERNAM.
        LT_EXCEL-AEDAT2 = GS_TABKUC0100-AEDAT.
        LT_EXCEL-AEZET2 = GS_TABKUC0100-AEZET.
        LT_EXCEL-AENAM2 = GS_TABKUC0100-AENAM.
        LT_EXCEL-TCODE2 = GS_TABKUC0100-TCODE.

        LT_EXCEL-MAKTX = GS_TABKUC0100-MAKTX.
        LT_EXCEL-MEINS = GS_TABKUC0100-MEINS.
        LT_EXCEL-MSTAE = GS_TABKUC0100-MSTAE.
        LT_EXCEL-QUANTITY = GS_TABKUC0100-QUANTITY. "工廠庫存數（理論存量）
        LT_EXCEL-ISDJCZ = GS_TABKUC0100-ISDJCZ. "單價是否存在
        LT_EXCEL-KHB = GS_TABKUC0100-KHB. "客戶別
        LT_EXCEL-Z_PRC = GS_TABKUC0100-Z_PRC. "生管权限
        LT_EXCEL-Z_SALS = GS_TABKUC0100-Z_SALS. "業務权限
        LT_EXCEL-Z_PUR = GS_TABKUC0100-Z_PUR. "採購权限
        LT_EXCEL-Z_PRC_STC = GS_TABKUC0100-Z_PRC_STC. "待列权限

        LT_EXCEL-ZDECL_QTY_O = GS_TABKUC0100-ZDECL_QTY.     "報庫存數量
        LT_EXCEL-ZSTOCK_STAT_O = GS_TABKUC0100-ZSTOCK_STAT.   "報庫處理方式
        LT_EXCEL-ZPMREMARK_O = GS_TABKUC0100-ZPMREMARK.     "生管備注
        LT_EXCEL-ISOK_O = GS_TABKUC0100-ISOK.          "是否處理OK，
        LT_EXCEL-ZREPL_INV_O = GS_TABKUC0100-ZREPL_INV.     "是否補報庫存
      ENDIF.
    ELSE.
      LT_EXCEL-OPTYPE = 'C'. "創建
      CLEAR GS_ZTPPMO0011.
      SELECT SINGLE * INTO CORRESPONDING FIELDS OF GS_ZTPPMO0011
        FROM ZTPPMO0011
        WHERE ZID = LT_EXCEL-ZID.
      IF GS_ZTPPMO0011 IS NOT INITIAL.
        LT_EXCEL-ZMCNTYPE = '2'. "指定PO
      ELSE.
        CLEAR GS_ZTPPEC0017.
        SELECT SINGLE * INTO CORRESPONDING FIELDS OF GS_ZTPPEC0017
          FROM ZTPPEC0017
          WHERE ZMCRID = LT_EXCEL-ZID
            AND ZVERSN = LT_EXCEL-ZVERSN "版次
          .
        IF GS_ZTPPEC0017 IS NOT INITIAL.
          LT_EXCEL-ZMCNTYPE = '1'. "MCR號碼
        ENDIF.
      ENDIF.

      IF LT_EXCEL-ZMCNTYPE IS INITIAL.
        IF LT_EXCEL-MSG_TYPE = ''.
          LT_EXCEL-MSG_TYPE = 'E'.
          LT_EXCEL-MSG_TEXT = '單據不屬於指定PO也不屬於MCR變更'.
        ENDIF.
      ENDIF.

      IF LT_EXCEL-ZMCNTYPE = '2'. "指定PO
        LT_EXCEL-ZSGZT = GS_ZTPPMO0011-ZSTA. "生管狀態
        SELECT SINGLE B~VTWEG INTO LT_EXCEL-WL2_CUST
          FROM ZTPPMO0015 AS A JOIN VBAK AS B ON B~VBELN = A~VBELN
          WHERE ZID = LT_EXCEL-ZID.
      ELSEIF LT_EXCEL-ZMCNTYPE = '1'. "MCR號碼
        LT_EXCEL-ZSGZT = GS_ZTPPEC0017-MCRSTAT. "生管狀態
        DATA LV_ZTRAN_ID LIKE ZTPPEC0005-ZTRAN_ID.
        CLEAR LV_ZTRAN_ID.
        SELECT MAX( ZTRAN_ID ) INTO LV_ZTRAN_ID FROM ZTPPEC0005
          WHERE ZMCRID = LT_EXCEL-ZID.
        CLEAR GS_ZTPPEC0005.
        SELECT SINGLE * INTO CORRESPONDING FIELDS OF GS_ZTPPEC0005
          FROM ZTPPEC0005
          WHERE ZMCRID = LT_EXCEL-ZID
            AND ZTRAN_ID = LV_ZTRAN_ID.
        LT_EXCEL-WL2_CUST = GS_ZTPPEC0005-WL2_CUST. "客戶別
*        業務負責人字段填寫
        IF GS_ZTPPEC0005-OWN_GROUP CS '業務部'.
          LT_EXCEL-ZYWFZR = GS_ZTPPEC0005-OWN_USER.
        ELSE.
          IF GS_ZTPPEC0005-WL2_PM IS NOT INITIAL.
            LT_EXCEL-ZYWFZR = GS_ZTPPEC0005-WL2_PM.
          ENDIF.
        ENDIF.
      ENDIF.

    ENDIF.

*   單據類型描述
    READ TABLE GT_ZMCNTYPE WITH KEY DOMVALUE_L = LT_EXCEL-ZMCNTYPE.
    IF SY-SUBRC = 0.
      LT_EXCEL-ZMCNTYPE_T = GT_ZMCNTYPE-DDTEXT.
    ENDIF.


*  生管狀態
    IF LT_EXCEL-ZSGZT IS INITIAL.
      IF LT_EXCEL-ZMCNTYPE = '2'.
        SELECT SINGLE ZSTA INTO LT_EXCEL-ZSGZT
          FROM ZTPPMO0011
          WHERE ZID = LT_EXCEL-ZID.
*      GS_SCR0100-ZSGZT = GS_ZTPPMO0011-ZSTA.
      ELSEIF LT_EXCEL-ZMCNTYPE = '1'.
        SELECT SINGLE MCRSTAT INTO LT_EXCEL-ZSGZT
          FROM ZTPPEC0017
          WHERE ZMCRID = LT_EXCEL-ZID
            AND ZVERSN = LT_EXCEL-ZVERSN "版次
          .
      ENDIF.
    ENDIF.

*  客戶別處理
    CLEAR: LT_EXCEL-VTWEG_T.
    IF LT_EXCEL-WL2_CUST IS INITIAL.
      IF LT_EXCEL-ZMCNTYPE = '1'. "MCR號碼
        CLEAR LV_ZTRAN_ID.
        SELECT MAX( ZTRAN_ID ) INTO LV_ZTRAN_ID FROM ZTPPEC0005
          WHERE ZMCRID = LT_EXCEL-ZID.
        CLEAR GS_ZTPPEC0005.
        SELECT SINGLE WL2_CUST INTO LT_EXCEL-WL2_CUST
          FROM ZTPPEC0005
          WHERE ZMCRID = LT_EXCEL-ZID
            AND ZTRAN_ID = LV_ZTRAN_ID.
      ELSEIF LT_EXCEL-ZMCNTYPE = '2'. "指定PO
        SELECT SINGLE B~VTWEG INTO LT_EXCEL-WL2_CUST
          FROM ZTPPMO0015 AS A JOIN VBAK AS B ON B~VBELN = A~VBELN
          WHERE ZID = LT_EXCEL-ZID.
      ENDIF.
    ENDIF.
    IF LT_EXCEL-WL2_CUST IS NOT INITIAL.
      DATA:
        BEGIN OF LT_SPLIT OCCURS 0,
          STR LIKE ZTSD1011-ZBRAND,
        END OF LT_SPLIT.
      CLEAR: LT_SPLIT,LT_SPLIT[].
      SPLIT LT_EXCEL-WL2_CUST AT '|' INTO TABLE LT_SPLIT.
      DATA LS_SPLIT LIKE LINE OF LT_SPLIT.
      CLEAR LS_SPLIT.
      IF LT_SPLIT[] IS INITIAL.
        LS_SPLIT = LT_EXCEL-WL2_CUST.
        APPEND LS_SPLIT TO LT_SPLIT.
      ENDIF.
      IF LT_SPLIT[] IS NOT INITIAL.
        SELECT DISTINCT VTWEG INTO TABLE @DATA(LT_VTWEG) FROM ZTSD1011
          FOR ALL ENTRIES IN @LT_SPLIT[]
          WHERE ZBRAND = @LT_SPLIT-STR.
      ENDIF.
      LOOP AT LT_VTWEG INTO DATA(LS_VTWEG).
        IF LT_EXCEL-VTWEG_T IS INITIAL.
          LT_EXCEL-VTWEG_T = LS_VTWEG-VTWEG.
        ELSE.
          LT_EXCEL-VTWEG_T = LT_EXCEL-VTWEG_T && '|' && LS_VTWEG-VTWEG.
        ENDIF.
      ENDLOOP.
      CLEAR: LT_VTWEG.
    ENDIF.

*    行項目取值

    SELECT SINGLE A~MEINS B~MAKTX A~MSTAE
      INTO CORRESPONDING FIELDS OF LT_EXCEL
      FROM MARA AS A LEFT JOIN MAKT AS B ON B~MATNR = A~MATNR
                                        AND B~SPRAS = 'M'
      WHERE A~MATNR = LT_EXCEL-MATNR.

*  獲取工廠庫存數(理論存量)
    DATA LS_ZTPPRP0019 LIKE ZTPPRP0019.
    CLEAR LS_ZTPPRP0019.
    LS_ZTPPRP0019-ARTICLE_LONG = LT_EXCEL-MATNR.
    LS_ZTPPRP0019-PLANT = LT_EXCEL-WERKS.
    SELECT MAX( ZDSDAT ) INTO LS_ZTPPRP0019-ZDSDAT
      FROM ZTPPRP0019
      WHERE ARTICLE_LONG = LS_ZTPPRP0019-ARTICLE_LONG
        AND PLANT = LS_ZTPPRP0019-PLANT
        AND DELETION_FLAG = ''.
    SELECT SUM( QUANTITY ) INTO LS_ZTPPRP0019-QUANTITY
      FROM ZTPPRP0019
      WHERE ARTICLE_LONG = LS_ZTPPRP0019-ARTICLE_LONG
        AND PLANT = LS_ZTPPRP0019-PLANT
        AND ZDSDAT = LS_ZTPPRP0019-ZDSDAT
        AND DELETION_FLAG = ''.
    LT_EXCEL-QUANTITY = LS_ZTPPRP0019-QUANTITY.

*  讀取客戶別
    CLEAR LT_EXCEL-KHB.
    SELECT SINGLE VTWEG INTO LT_EXCEL-KHB FROM ZTSD0020
      WHERE ZCN = LT_EXCEL-ZZCN
        AND ZDEFAULT = 'X'
        AND ZCN <> ''
*      AND MATNR = US_TABKUC0100-MATNR
      .
    IF SY-SUBRC <> 0.
      SELECT SINGLE VTWEG INTO LT_EXCEL-KHB FROM ZTSD0020
        WHERE ZCN = LT_EXCEL-ZZCN
        AND ZCN <> ''
*      AND ZDEFAULT = 'X'
*      AND MATNR = US_TABKUC0100-MATNR
        .
    ENDIF.


*    IF LT_EXCEL-ZUPRICE = 0.
*      DATA LS_MARC LIKE MARC.
*      CLEAR LS_MARC.
*      SELECT SINGLE * INTO LS_MARC FROM MARC
*        WHERE MATNR = LT_EXCEL-MATNR
*          AND WERKS = LT_EXCEL-WERKS.
*      IF LS_MARC-BESKZ = 'F' AND LS_MARC-SOBSL = ''. "外部采購F并且不是特殊采購
*        DATA LS_ZTMARC LIKE ZTMARC.
*        CLEAR LS_ZTMARC.
*        SELECT SINGLE * INTO LS_ZTMARC FROM ZTMARC
*          WHERE MATNR = LT_EXCEL-MATNR
*            AND WERKS = LT_EXCEL-WERKS.
*
*        DATA L_INFO_REC LIKE BAPIEINE-INFO_REC.
*        CLEAR L_INFO_REC.
*        IF LS_ZTMARC-ZDEFAULT_VENDOR <> ''.
*          SELECT SINGLE A~INFNR INTO L_INFO_REC
*            FROM EINA AS A JOIN EINE AS B ON B~INFNR = B~INFNR
*            WHERE A~MATNR = LT_EXCEL-MATNR
*              AND A~LIFNR = LS_ZTMARC-ZDEFAULT_VENDOR
*              AND B~EKORG = '1200'
*              AND B~WERKS = LT_EXCEL-WERKS
*              AND B~ESOKZ = '0'.
*        ENDIF.
*
*        DATA LS_A017 LIKE A017.
*        CLEAR LS_A017.
*        IF L_INFO_REC IS NOT INITIAL.
*          SELECT SINGLE * INTO LS_A017 FROM A017
*            WHERE KSCHL = 'PB00'
*              AND MATNR = LT_EXCEL-MATNR
*              AND LIFNR = LS_ZTMARC-ZDEFAULT_VENDOR
*              AND EKORG = '1200'
*              AND WERKS = LT_EXCEL-WERKS
*              AND ESOKZ = '0'
*              AND DATAB <= SY-DATUM
*              AND DATBI >= SY-DATUM.
*        ENDIF.
*
*        DATA LS_KONP LIKE KONP.
*        CLEAR LS_KONP.
*        SELECT SINGLE * INTO LS_KONP FROM KONP
*          WHERE KNUMH = LS_A017-KNUMH
*            AND KSCHL = LS_A017-KSCHL.
*        LT_EXCEL-ZUPRICE = LS_KONP-KBETR.
*      ENDIF.
*    ENDIF.

*  獲取物料價格
    CLEAR GT_MATNRPRICE.
    GT_MATNRPRICE-MATNR = LT_EXCEL-MATNR.
    GT_MATNRPRICE-WERKS = LT_EXCEL-WERKS.
    APPEND GT_MATNRPRICE.

*    IF LT_EXCEL-WAERS = ''.
*      SELECT SINGLE WAERS INTO LT_EXCEL-WAERS FROM LFM1
*        WHERE LIFNR = LS_ZTMARC-ZDEFAULT_VENDOR
*          AND EKORG = '1200'.
*    ENDIF.

**  判斷單價是否存在
*    IF LT_EXCEL-ZUPRICE > 0.
*      LT_EXCEL-ISDJCZ = 'Y'.
*    ELSE.
*      LT_EXCEL-ISDJCZ = 'N'.
*    ENDIF.

    MODIFY LT_EXCEL.
  ENDLOOP.

  PERFORM GET_PRICE TABLES GT_MATNRPRICE.
  LOOP AT LT_EXCEL.
    READ TABLE GT_MATNRPRICE WITH KEY MATNR = LT_EXCEL-MATNR
                                      WERKS = LT_EXCEL-WERKS.
    IF SY-SUBRC = 0 .
      IF GT_MATNRPRICE-BESKZ = 'F' AND GT_MATNRPRICE-SOBSL = ''. "外購,取最新價格
        LT_EXCEL-ZUPRICE = GT_MATNRPRICE-ZUPRICE.
*        LT_EXCEL-ZUPRICE2 = GT_MATNRPRICE-ZUPRICE2.
        LT_EXCEL-WAERS = GT_MATNRPRICE-WAERS.
        LT_EXCEL-ISDJCZ = GT_MATNRPRICE-ISDJCZ. "單價是否存在
      ENDIF.
    ENDIF.
    MODIFY LT_EXCEL.
  ENDLOOP.


  APPEND LINES OF LT_EXCEL TO GT_EXCEL_R1.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form UPLOAD_R7
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM UPLOAD_R7.

  DATA:
    GD_SCOL TYPE I VALUE '2',
    GD_SROW TYPE I VALUE '3',
    GD_ECOL TYPE I VALUE '5',
    GD_EROW TYPE I VALUE '65536'.

  FIELD-SYMBOLS: <FS>.
  DATA: LT_INTERN TYPE ALSMEX_TABLINE OCCURS 0 WITH HEADER LINE,
        LD_INDEX  TYPE I.
* Upload Data from EXCEL to SAP ITAB
  DATA LV_PATH LIKE RLGRAP-FILENAME.
  LV_PATH = P_PATH.
  CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
    EXPORTING
      FILENAME                = P_PATH
      I_BEGIN_COL             = GD_SCOL
      I_BEGIN_ROW             = GD_SROW
      I_END_COL               = GD_ECOL
      I_END_ROW               = GD_EROW
    TABLES
      INTERN                  = LT_INTERN
    EXCEPTIONS
      INCONSISTENT_PARAMETERS = 1
      UPLOAD_OLE              = 2
      OTHERS                  = 3.

  IF SY-SUBRC <> 0.
* Implement suitable error handling here
    MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
    WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
  ENDIF.

  IF LT_INTERN[] IS INITIAL.
    RETURN.
  ENDIF.


  DATA:
    BEGIN OF LT_TMP OCCURS 0,
      WERKS   LIKE ZTPPEC0015-WERKS,         "工廠
      MATNR   LIKE ZTPPEC0016-MATNR,         "料號
      ZUPRICE LIKE ZTPPEC0016-ZUPRICE,       "單價
      WAERS   LIKE ZTPPEC0016-WAERS,         "幣別
    END OF LT_TMP.

  SORT LT_INTERN BY ROW COL.
  LOOP AT LT_INTERN.
    MOVE LT_INTERN-COL TO LD_INDEX.
    ASSIGN COMPONENT LD_INDEX OF STRUCTURE LT_TMP TO <FS>.
    MOVE LT_INTERN-VALUE TO <FS>.
    AT END OF ROW.
      APPEND LT_TMP TO LT_TMP.
      CLEAR: LT_TMP.
    ENDAT.
  ENDLOOP.
  CLEAR: LT_INTERN[].

  SORT LT_TMP BY WERKS MATNR.
  DELETE ADJACENT DUPLICATES FROM LT_TMP COMPARING WERKS MATNR.

  IF LT_TMP[] IS INITIAL.
    MESSAGE '沒有資料' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  DATA: LT_EXCEL LIKE TABLE OF GS_EXCEL_R2 WITH HEADER LINE.
  LOOP AT LT_TMP.
    SELECT A~WERKS,B~ZUPRICE2 AS ZUPRICE_O,B~WAERS AS WAERS_O,B~MATNR,A~ZID,A~ZVERSN,
      A~ZYWFZR,A~ZSGZT,A~WL2_CUST,A~ZMCNTYPE,A~ERDAT,A~ERZET,A~ERNAM,A~AEDAT,A~AEZET,
      A~AENAM,A~TCODE,B~ZDECL_QTY,B~ZSTOCK_STAT,B~ZPMREMARK,B~ISOK,B~ZREPL_INV,B~ZSEQ,
      B~ZTOT_STOCK,B~ZSTOCK_STAT2,B~ZZCN,B~KUNAG,B~ZUNIT_CONS,B~ZTF_PREPO,B~ZPM_AENAM,
      B~ZPM_AEDAT,B~ZREP_AENAM,B~ZREP_AEDAT,B~ZSA_REP,B~ZSA_AENAM,B~ZSA_AEDAT,B~ZPU_AENAM,
      B~ZPU_AEDAT,B~ZDNNO,B~ERDAT AS ERDAT2,B~ERZET AS ERZET2,B~ERNAM AS ERNAM2,
      B~AEDAT AS AEDAT2,B~AEZET AS AEZET2,B~AENAM AS AENAM2,B~TCODE AS TCODE2,C~MAKTX,
      M~MEINS,E~Z_PRC,E~Z_SALS,E~Z_PUR,E~Z_PRC_STC
      FROM ZTPPEC0015 AS A JOIN ZTPPEC0016 AS B ON B~ZID = A~ZID
                                               AND B~WERKS = A~WERKS
                                               AND B~ZVERSN = A~ZVERSN
                            LEFT JOIN MAKT AS C ON C~MATNR = B~MATNR
                                               AND C~SPRAS = 'M'
                            LEFT JOIN MARA AS M ON M~MATNR = B~MATNR
                      LEFT JOIN ZTPPEC0025 AS E ON E~Z_STAT = B~ZSTOCK_STAT
      WHERE A~WERKS = @LT_TMP-WERKS
        AND B~MATNR = @LT_TMP-MATNR
      APPENDING CORRESPONDING FIELDS OF TABLE @LT_EXCEL.
  ENDLOOP.

  SORT LT_EXCEL BY ZID WERKS ZVERSN.

  IF LT_EXCEL[] IS INITIAL.
    MESSAGE '沒有資料' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  LOOP AT LT_EXCEL.

    READ TABLE LT_TMP WITH KEY WERKS = LT_EXCEL-WERKS MATNR = LT_EXCEL-MATNR.
    IF SY-SUBRC = 0.
      LT_EXCEL-ZUPRICE = LT_TMP-ZUPRICE.
      LT_EXCEL-WAERS = LT_TMP-WAERS.
    ENDIF.

    DATA LS_ZTPPEC0015 LIKE ZTPPEC0015.
    CLEAR LS_ZTPPEC0015.
    SELECT SINGLE *
      FROM ZTPPEC0015
      WHERE ZID = @LT_EXCEL-ZID
        AND ZVERSN = @LT_EXCEL-ZVERSN
        AND WERKS = @LT_EXCEL-WERKS
      INTO @LS_ZTPPEC0015.
    IF SY-SUBRC = 0.
      LT_EXCEL-OPTYPE = 'U'. "修改
    ELSE.
      LT_EXCEL-OPTYPE = 'C'. "創建
      IF LT_EXCEL-MSG_TYPE = ''.
        LT_EXCEL-MSG_TYPE = 'E'.
        LT_EXCEL-MSG_TEXT = '單據號碼不存在，先進行生管維護報庫存作業'.
      ENDIF.
    ENDIF.

    IF LT_EXCEL-ZUPRICE <= 0.
      IF LT_EXCEL-MSG_TYPE = ''.
        LT_EXCEL-MSG_TYPE = 'E'.
        LT_EXCEL-MSG_TEXT = '單價不能為0'.
      ENDIF.
    ENDIF.

*    data ls_t005u
    IF LT_EXCEL-WAERS = ''.
      DATA LS_ZTMARC LIKE ZTMARC.
      CLEAR LS_ZTMARC.
      SELECT SINGLE * INTO LS_ZTMARC FROM ZTMARC
        WHERE MATNR = LT_EXCEL-MATNR
          AND WERKS = LT_EXCEL-WERKS.
      SELECT SINGLE WAERS INTO LT_EXCEL-WAERS FROM LFM1
        WHERE LIFNR = LS_ZTMARC-ZDEFAULT_VENDOR
          AND EKORG = '1200'.
    ENDIF.
    DATA LS_TCURC LIKE TCURC.
    CLEAR LS_TCURC.
    SELECT SINGLE * INTO LS_TCURC FROM TCURC
      WHERE WAERS = LT_EXCEL-WAERS.
    IF SY-SUBRC <> 0.
      IF LT_EXCEL-MSG_TYPE = ''.
        LT_EXCEL-MSG_TYPE = 'E'.
        LT_EXCEL-MSG_TEXT = '幣別不存在'.
      ENDIF.
    ENDIF.


    IF LS_ZTPPEC0015 IS NOT INITIAL.
      LOOP AT GT_ZTPPEC0025 WHERE Z_PUR = ''. "沒有采購權限的資料刪除
*          DELETE GT_TABKUC0100 WHERE ZSTOCK_STAT = GT_ZTPPEC0025-Z_STAT.
        IF LT_EXCEL-ZSTOCK_STAT = GT_ZTPPEC0025-Z_STAT.
*          IF LT_EXCEL-MSG_TYPE = ''.
*            LT_EXCEL-MSG_TYPE = 'E'.
*            LT_EXCEL-MSG_TEXT = '沒有采購權限'.
*          ENDIF.
          LT_EXCEL-DEL = 'X'. "刪除
        ENDIF.
      ENDLOOP.
    ENDIF.

    MODIFY LT_EXCEL.
  ENDLOOP.

  DELETE LT_EXCEL WHERE DEL = 'X'.

  IF LT_EXCEL[] IS INITIAL.
    MESSAGE '沒有資料' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  APPEND LINES OF LT_EXCEL TO GT_EXCEL_R2.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form SHOW_ALV
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM SHOW_ALV.


  DATA LV_LAYOUT      TYPE SLIS_LAYOUT_ALV.

  DATA LV_FIELDCAT LIKE LINE OF GT_FIELDCAT.
  DATA LV_INDEX TYPE I.
  CLEAR LV_INDEX.

  DEFINE FIELDCAT_ADD.
    lv_index = lv_index + 1.
    clear lv_fieldcat.
    lv_fieldcat-fieldname = &1.
    lv_fieldcat-col_pos = lv_index.
    lv_fieldcat-REF_TABNAME = &2.
    lv_fieldcat-REF_FIELDNAME = &3.
    lv_fieldcat-SELTEXT_L = &4.
    lv_fieldcat-OUTPUTLEN = &5.
    lv_fieldcat-hotspot = &6.
    lv_fieldcat-no_zero = ''.
    lv_fieldcat-lzero = 'X'. "需要顯示0，
    if lv_fieldcat-fieldname = 'LIGHT'.
      lv_fieldcat-icon = 'X'.
    elseif lv_fieldcat-fieldname = 'SEL'.
      lv_fieldcat-checkbox = 'X'.
      lv_fieldcat-edit = 'X'.
    elseif lv_fieldcat-fieldname = 'NETPR'.
      lv_fieldcat-cfieldname = 'WAERS'.
    endif.
    append lv_fieldcat to GT_FIELDCAT.
  END-OF-DEFINITION.

  IF P_R6 = 'X'.
    IF GT_EXCEL_R1[] IS INITIAL.
      MESSAGE '沒有數據！' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    FIELDCAT_ADD 'SEL'           ''           ''             '選擇'                 '10'  ''.
    FIELDCAT_ADD 'MSG_TYPE'      ''           ''             '消息類型'             '10'  ''.
    FIELDCAT_ADD 'MSG_TEXT'      ''           ''             '消息文本'             '10'  ''.
    FIELDCAT_ADD 'ZID'           'ZTPPEC0015' 'ZID'          '單據號碼'             '10'  ''.
    FIELDCAT_ADD 'ZVERSN'        'ZTPPEC0015' 'ZVERSN'       '版次'                 '10'  ''.
    FIELDCAT_ADD 'WERKS'         'ZTPPEC0015' 'WERKS'        '工廠'                 '10'  ''.
    FIELDCAT_ADD 'MATNR'         'ZTPPEC0016' 'MATNR'        '料號'                 '10'  ''.
    FIELDCAT_ADD 'ZDECL_QTY'     'ZTPPEC0016' 'ZDECL_QTY'    '報庫存數量'           '10'  ''.
    FIELDCAT_ADD 'ZDECL_QTY_O'   ''           ''             '舊報庫存數量'         '10'  ''.
    FIELDCAT_ADD 'ZSTOCK_STAT'   'ZTPPEC0016' 'ZSTOCK_STAT'  '報庫處理方式'         '10'  ''.
    FIELDCAT_ADD 'ZSTOCK_STAT_O' ''           ''             '舊報庫處理方式'       '10'  ''.
    FIELDCAT_ADD 'ZPMREMARK'     'ZTPPEC0016' 'ZPMREMARK'    '生管備注'             '10'  ''.
    FIELDCAT_ADD 'ZPMREMARK_O'   ''           ''             '舊生管備注'           '10'  ''.
    FIELDCAT_ADD 'ISOK'          'ZTPPEC0016' 'ISOK'         '處理OK'               '10'  ''.
    FIELDCAT_ADD 'ISOK_O'        ''           ''             '舊處理OK'             '10'  ''.
    FIELDCAT_ADD 'ZREPL_INV'     'ZTPPEC0016' 'ZREPL_INV'    '補報庫存'             '10'  ''.
    FIELDCAT_ADD 'ZREPL_INV_O'   ''           ''             '舊補報庫存'           '10'  ''.
*    FIELDCAT_ADD 'OPTYPE'        ''           ''             'C創建U修改'           '10'  ''.
*    FIELDCAT_ADD 'ZSGZT'         'ZTPPEC0015' 'ZSGZT'        '生管狀態'             '10'  ''.
*    FIELDCAT_ADD 'ZMCNTYPE'      'ZTPPEC0015' 'ZMCNTYPE'     '單據類別'             '10'  ''.
*    FIELDCAT_ADD 'WL2_CUST'      'ZTPPEC0015' 'WL2_CUST'     '客戶別'               '10'  ''.
*    FIELDCAT_ADD 'ZYWFZR'        'ZTPPEC0015' 'ZYWFZR'       '業務負責人'           '10'  ''.
*    FIELDCAT_ADD 'VTWEG_T'       ''           ''             '單據客戶別'           '10'  ''.
*    FIELDCAT_ADD 'ZMCNTYPE_T'    ''           ''             '單據類型描述'         '10'  ''.
*    FIELDCAT_ADD 'ZSEQ'          'ZTPPEC0016' 'ZSEQ'         '序號'                 '10'  ''.
*    FIELDCAT_ADD 'MAKTX'         'MAKT'       'MAKTX'        ''                     '10'  ''.
*    FIELDCAT_ADD 'ZTOT_STOCK'    'ZTPPEC0016' 'ZTOT_STOCK'   '庫存總數'             '10'  ''.
*    FIELDCAT_ADD 'ZSTOCK_STAT_T' 'ZTPPEC0016' 'ZSTOCK_STAT'  ''                     '10'  ''.
*    FIELDCAT_ADD 'ZUPRICE'      'ZTPPEC0016'  'ZUPRICE'      '單價'                 '10'  ''.

    LV_LAYOUT-COLWIDTH_OPTIMIZE = 'X'.
    LV_LAYOUT-ZEBRA = 'X'.
*  LV_LAYOUT-BOX_FIELDNAME = 'SELEC'.

    G_SAVE = 'A'.
    G_REPID = SY-REPID.

    CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
      EXPORTING
        I_CALLBACK_PROGRAM       = G_REPID
*       I_BACKGROUND_ID          = 'BUTTON_UP_BACK'
        I_BYPASSING_BUFFER       = 'X'
        I_CALLBACK_PF_STATUS_SET = 'SET_PF_STATUS'
        I_CALLBACK_USER_COMMAND  = 'USER_COMMAND'
        IS_LAYOUT                = LV_LAYOUT
        IS_PRINT                 = G_PRINT
        IT_FIELDCAT              = GT_FIELDCAT[]
        IT_SORT                  = GT_SORTINFO[]
        IT_EVENTS                = GT_EVENTS
*       I_GRID_SETTINGS          = GRID_SETTINGS
        I_DEFAULT                = 'X'
        I_SAVE                   = 'A'
        IS_VARIANT               = G_VARIANT
      TABLES
        T_OUTTAB                 = GT_EXCEL_R1[]
      EXCEPTIONS
        PROGRAM_ERROR            = 1
        OTHERS                   = 2.
    IF SY-SUBRC <> 0.
      MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
      WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
    ENDIF.

  ELSEIF P_R7 = 'X'.
    IF  GT_EXCEL_R2[] IS INITIAL.
      MESSAGE '沒有數據！' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    FIELDCAT_ADD 'SEL'           ''           ''             '選擇'                 '10'  ''.
    FIELDCAT_ADD 'MSG_TYPE'      ''           ''             '消息類型'             '10'  ''.
    FIELDCAT_ADD 'MSG_TEXT'      ''           ''             '消息文本'             '10'  ''.
    FIELDCAT_ADD 'ZID'           'ZTPPEC0015' 'ZID'          '單據號碼'             '10'  ''.
    FIELDCAT_ADD 'ZVERSN'        'ZTPPEC0015' 'ZVERSN'       '版次'                 '10'  ''.
    FIELDCAT_ADD 'WERKS'         'ZTPPEC0015' 'WERKS'        '工廠'                 '10'  ''.
    FIELDCAT_ADD 'MATNR'         'ZTPPEC0016' 'MATNR'        '料號'                 '10'  ''.
    FIELDCAT_ADD 'ZUPRICE2'       'ZTPPEC0016' 'ZUPRICE2'      '單價'                 '10'  ''.
    FIELDCAT_ADD 'WAERS'         'ZTPPEC0016' 'WAERS'        '幣別'                 '10'  ''.
    FIELDCAT_ADD 'ZUPRICE_O'     ''           ''             '舊單價'               '10'  ''.
    FIELDCAT_ADD 'WAERS_O'       ''           ''             '舊幣別'               '10'  ''.
    FIELDCAT_ADD 'ZDECL_QTY'     'ZTPPEC0016' 'ZDECL_QTY'    '報庫存數量'           '10'  ''.
    FIELDCAT_ADD 'ZSTOCK_STAT'   'ZTPPEC0016' 'ZSTOCK_STAT'  '報庫處理方式'         '10'  ''.
    FIELDCAT_ADD 'ZPMREMARK'     'ZTPPEC0016' 'ZPMREMARK'    '生管備注'             '10'  ''.
    FIELDCAT_ADD 'ISOK'          'ZTPPEC0016' 'ISOK'         '處理OK'               '10'  ''.
    FIELDCAT_ADD 'ZREPL_INV'     'ZTPPEC0016' 'ZREPL_INV'    '補報庫存'             '10'  ''.
    FIELDCAT_ADD 'OPTYPE'        ''           ''             'C創建U修改'           '10'  ''.
    FIELDCAT_ADD 'ZSGZT'         'ZTPPEC0015' 'ZSGZT'        '生管狀態'             '10'  ''.
    FIELDCAT_ADD 'ZMCNTYPE'      'ZTPPEC0015' 'ZMCNTYPE'     '單據類別'             '10'  ''.
    FIELDCAT_ADD 'WL2_CUST'      'ZTPPEC0015' 'WL2_CUST'     '客戶別'               '10'  ''.
    FIELDCAT_ADD 'ZYWFZR'        'ZTPPEC0015' 'ZYWFZR'       '業務負責人'           '10'  ''.
    FIELDCAT_ADD 'VTWEG_T'       ''           ''             '單據客戶別'           '10'  ''.
    FIELDCAT_ADD 'ZMCNTYPE_T'    ''           ''             '單據類型描述'         '10'  ''.
    FIELDCAT_ADD 'ZSEQ'          'ZTPPEC0016' 'ZSEQ'         '序號'                 '10'  ''.
    FIELDCAT_ADD 'MAKTX'         'MAKT'       'MAKTX'        ''                     '10'  ''.
    FIELDCAT_ADD 'ZTOT_STOCK'    'ZTPPEC0016' 'ZTOT_STOCK'   '庫存總數'             '10'  ''.
    FIELDCAT_ADD 'ZSTOCK_STAT_T' 'ZTPPEC0016' 'ZSTOCK_STAT'  ''                     '10'  ''.


    LV_LAYOUT-COLWIDTH_OPTIMIZE = 'X'.
    LV_LAYOUT-ZEBRA = 'X'.
*  LV_LAYOUT-BOX_FIELDNAME = 'SELEC'.

    G_SAVE = 'A'.
    G_REPID = SY-REPID.

    CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
      EXPORTING
        I_CALLBACK_PROGRAM       = G_REPID
*       I_BACKGROUND_ID          = 'BUTTON_UP_BACK'
        I_BYPASSING_BUFFER       = 'X'
        I_CALLBACK_PF_STATUS_SET = 'SET_PF_STATUS'
        I_CALLBACK_USER_COMMAND  = 'USER_COMMAND'
        IS_LAYOUT                = LV_LAYOUT
        IS_PRINT                 = G_PRINT
        IT_FIELDCAT              = GT_FIELDCAT[]
        IT_SORT                  = GT_SORTINFO[]
        IT_EVENTS                = GT_EVENTS
*       I_GRID_SETTINGS          = GRID_SETTINGS
        I_DEFAULT                = 'X'
        I_SAVE                   = 'A'
        IS_VARIANT               = G_VARIANT
      TABLES
        T_OUTTAB                 = GT_EXCEL_R2[]
      EXCEPTIONS
        PROGRAM_ERROR            = 1
        OTHERS                   = 2.
    IF SY-SUBRC <> 0.
      MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
      WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
    ENDIF.

  ENDIF.



ENDFORM.

FORM USER_COMMAND USING UCOM LIKE SY-UCOMM
                        SELFD TYPE SLIS_SELFIELD.
  CONSTANTS: C_X VALUE 'X'.
* Define Checkbox-->CHECKBOX = 'X' + EDIT = 'X'
  DATA: REF_GRID TYPE REF TO CL_GUI_ALV_GRID,
        REF_STBL TYPE LVC_S_STBL.
  IF REF_GRID IS INITIAL.
    CALL FUNCTION 'GET_GLOBALS_FROM_SLVC_FULLSCR'
      IMPORTING
        E_GRID = REF_GRID.
  ENDIF.
  IF NOT REF_GRID IS INITIAL.
    CALL METHOD REF_GRID->CHECK_CHANGED_DATA.
  ENDIF.
  CLEAR SEL_INDEX.
  SEL_INDEX = SELFD-TABINDEX.

  IF UCOM = '&F03'.
  ELSEIF UCOM = 'ALL'.
    PERFORM SEL_ALL.
  ELSEIF UCOM = 'SAL'.
    PERFORM SEL_SAL.
  ELSEIF UCOM = 'POST'.
    PERFORM POST_DATA.
  ENDIF.


  CALL METHOD REF_GRID->CHECK_CHANGED_DATA.

  REF_STBL-ROW = C_X.
  REF_STBL-COL = C_X.
  CALL METHOD REF_GRID->REFRESH_TABLE_DISPLAY
    EXPORTING
      IS_STABLE = REF_STBL.

ENDFORM.

FORM SET_PF_STATUS USING TAB TYPE SLIS_T_EXTAB.
  DATA FCODE TYPE TABLE OF SY-UCOMM.
*  IF P_R2 = 'X'.
*    APPEND 'ALL' TO TAB.
*    APPEND 'SAL' TO TAB.
*    APPEND 'POST' TO TAB.
*  ENDIF.
  SET PF-STATUS 'STANDARD2' EXCLUDING TAB.
*  SET PF-STATUS 'STANDARD'.
*  SET TITLEBAR 'TITLE' WITH 'Mass upload to create Sales Order'.
ENDFORM.                    "SET_PF_STATUS

*&---------------------------------------------------------------------*
*& Form POST_DATA
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM POST_DATA.
  DATA LS_ZTPPEC0015 LIKE ZTPPEC0015.
  DATA LS_ZTPPEC0016 LIKE ZTPPEC0016.
  IF P_R6 = 'X'.
    LOOP AT GT_EXCEL_R1 INTO GS_EXCEL_R1 WHERE SEL = 'X'.
      IF GS_EXCEL_R1-MSG_TYPE = 'E'.
        MESSAGE '不能選擇錯誤數據' TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
    ENDLOOP.
    LOOP AT GT_EXCEL_R1 INTO GS_EXCEL_R1 WHERE SEL = 'X'.
*    ZSTOCK_STAT_O LIKE ZTPPEC0016-ZSTOCK_STAT,   "報庫處理方式
*    ZPMREMARK_O   LIKE ZTPPEC0016-ZPMREMARK,     "生管備注
*    ISOK_O        LIKE ZTPPEC0016-ISOK,          "是否處理OK，
*    ZREPL_INV_O   LIKE ZTPPEC0016-ZREPL_INV,     "是否補報庫存

      CLEAR: LS_ZTPPEC0015,LS_ZTPPEC0016.
      SELECT SINGLE * INTO LS_ZTPPEC0015 FROM ZTPPEC0015
        WHERE ZID = GS_EXCEL_R1-ZID
          AND WERKS = GS_EXCEL_R1-WERKS
          AND ZVERSN = GS_EXCEL_R1-ZVERSN.
      SELECT SINGLE * INTO LS_ZTPPEC0016 FROM ZTPPEC0016
        WHERE ZID = GS_EXCEL_R1-ZID
          AND WERKS = GS_EXCEL_R1-WERKS
          AND ZVERSN = GS_EXCEL_R1-ZVERSN
          AND ZSEQ = GS_EXCEL_R1-ZSEQ
          AND MATNR = GS_EXCEL_R1-MATNR.
      IF LS_ZTPPEC0016 IS NOT INITIAL. "修改
        UPDATE ZTPPEC0016 SET ZDECL_QTY = GS_EXCEL_R1-ZDECL_QTY
                              ZSTOCK_STAT = GS_EXCEL_R1-ZSTOCK_STAT
                              ZPMREMARK = GS_EXCEL_R1-ZPMREMARK
                              ISOK = GS_EXCEL_R1-ISOK
                              ZREPL_INV = GS_EXCEL_R1-ZREPL_INV
                              ZPM_AENAM = SY-UNAME
                              ZPM_AEDAT = SY-DATUM
                              AEDAT = SY-DATUM
                              AEZET = SY-UZEIT
                              AENAM = SY-UNAME
                              TCODE = SY-TCODE
        WHERE ZID = GS_EXCEL_R1-ZID
          AND WERKS = GS_EXCEL_R1-WERKS
          AND ZVERSN = GS_EXCEL_R1-ZVERSN
          AND ZSEQ = GS_EXCEL_R1-ZSEQ
          AND MATNR = GS_EXCEL_R1-MATNR.
        GS_EXCEL_R1-MSG_TYPE = 'S'.
        GS_EXCEL_R1-MSG_TEXT = '修改成功'.
      ELSEIF LS_ZTPPEC0016 IS INITIAL AND LS_ZTPPEC0015 IS NOT INITIAL.
        CLEAR LS_ZTPPEC0016.
        LS_ZTPPEC0016-ZID = GS_EXCEL_R1-ZID.
        LS_ZTPPEC0016-ZVERSN = GS_EXCEL_R1-ZVERSN.
        LS_ZTPPEC0016-WERKS = GS_EXCEL_R1-WERKS.
        LS_ZTPPEC0016-MATNR = GS_EXCEL_R1-MATNR.
        SELECT MAX( ZSEQ ) INTO LS_ZTPPEC0016-ZSEQ FROM ZTPPEC0016
          WHERE ZID = GS_EXCEL_R1-ZID
          AND WERKS = GS_EXCEL_R1-WERKS
          AND ZVERSN = GS_EXCEL_R1-ZVERSN.
        LS_ZTPPEC0016-ZSEQ = LS_ZTPPEC0016-ZSEQ + 1.
        LS_ZTPPEC0016-ZDECL_QTY = GS_EXCEL_R1-ZDECL_QTY.
        LS_ZTPPEC0016-ZTOT_STOCK = GS_EXCEL_R1-ZTOT_STOCK.
        LS_ZTPPEC0016-ZSTOCK_STAT = GS_EXCEL_R1-ZSTOCK_STAT.
        LS_ZTPPEC0016-ZSTOCK_STAT2 = GS_EXCEL_R1-ZSTOCK_STAT2.
        LS_ZTPPEC0016-ISOK = GS_EXCEL_R1-ISOK.
        LS_ZTPPEC0016-ZPMREMARK = GS_EXCEL_R1-ZPMREMARK.
        LS_ZTPPEC0016-ZREPL_INV = GS_EXCEL_R1-ZREPL_INV.
        LS_ZTPPEC0016-ZUPRICE = GS_EXCEL_R1-ZUPRICE.
        LS_ZTPPEC0016-ZUPRICE2 = GS_EXCEL_R1-ZUPRICE.
        LS_ZTPPEC0016-WAERS = GS_EXCEL_R1-WAERS.
        LS_ZTPPEC0016-ZZCN = GS_EXCEL_R1-ZZCN.
        LS_ZTPPEC0016-KUNAG = GS_EXCEL_R1-KUNAG.
        LS_ZTPPEC0016-ZUNIT_CONS = GS_EXCEL_R1-ZUNIT_CONS.
        LS_ZTPPEC0016-ZTF_PREPO = GS_EXCEL_R1-ZTF_PREPO.
        LS_ZTPPEC0016-ZPM_AENAM = SY-UNAME.
        LS_ZTPPEC0016-ZPM_AEDAT = SY-DATUM.
        LS_ZTPPEC0016-ZREP_AENAM = SY-UNAME.
        LS_ZTPPEC0016-ZREP_AEDAT = SY-DATUM.
        LS_ZTPPEC0016-ZSA_REP = ''.
        LS_ZTPPEC0016-ZSA_AENAM = ''.
        LS_ZTPPEC0016-ZSA_AEDAT = ''.
        LS_ZTPPEC0016-ZPU_AENAM = ''.
        LS_ZTPPEC0016-ZPU_AEDAT = ''.
        LS_ZTPPEC0016-ZDNNO = ''.
        LS_ZTPPEC0016-ERDAT = SY-DATUM.
        LS_ZTPPEC0016-ERZET = SY-UZEIT.
        LS_ZTPPEC0016-ERNAM = SY-UNAME.
        LS_ZTPPEC0016-AEDAT = SY-DATUM.
        LS_ZTPPEC0016-AEZET = SY-UZEIT.
        LS_ZTPPEC0016-AENAM = SY-UNAME.
        LS_ZTPPEC0016-TCODE = SY-TCODE.
        MODIFY ZTPPEC0016 FROM LS_ZTPPEC0016.
        GS_EXCEL_R1-MSG_TYPE = 'S'.
        GS_EXCEL_R1-MSG_TEXT = '添加成功'.
      ELSEIF LS_ZTPPEC0016 IS INITIAL AND LS_ZTPPEC0015 IS INITIAL.
        CLEAR LS_ZTPPEC0015.
        LS_ZTPPEC0015-ZID = GS_EXCEL_R1-ZID.
        LS_ZTPPEC0015-WERKS = GS_EXCEL_R1-WERKS.
        LS_ZTPPEC0015-ZVERSN = GS_EXCEL_R1-ZVERSN.
        LS_ZTPPEC0015-ZYWFZR = GS_EXCEL_R1-ZYWFZR.
        LS_ZTPPEC0015-ZSGZT = GS_EXCEL_R1-ZSGZT.
        LS_ZTPPEC0015-WL2_CUST = GS_EXCEL_R1-WL2_CUST.
        LS_ZTPPEC0015-ZMCNTYPE = GS_EXCEL_R1-ZMCNTYPE.
        LS_ZTPPEC0015-ERDAT = SY-DATUM.
        LS_ZTPPEC0015-ERZET = SY-UZEIT.
        LS_ZTPPEC0015-ERNAM = SY-UNAME.
        LS_ZTPPEC0015-AEDAT = SY-DATUM.
        LS_ZTPPEC0015-AEZET = SY-UZEIT.
        LS_ZTPPEC0015-AENAM = SY-UNAME.
        LS_ZTPPEC0015-TCODE = SY-TCODE.
        MODIFY ZTPPEC0015 FROM LS_ZTPPEC0015.

        CLEAR LS_ZTPPEC0016.
        LS_ZTPPEC0016-ZID = GS_EXCEL_R1-ZID.
        LS_ZTPPEC0016-ZVERSN = GS_EXCEL_R1-ZVERSN.
        LS_ZTPPEC0016-WERKS = GS_EXCEL_R1-WERKS.
        LS_ZTPPEC0016-MATNR = GS_EXCEL_R1-MATNR.
        SELECT MAX( ZSEQ ) INTO LS_ZTPPEC0016-ZSEQ FROM ZTPPEC0016
          WHERE ZID = GS_EXCEL_R1-ZID
          AND WERKS = GS_EXCEL_R1-WERKS
          AND ZVERSN = GS_EXCEL_R1-ZVERSN.
        LS_ZTPPEC0016-ZSEQ = LS_ZTPPEC0016-ZSEQ + 1.
        LS_ZTPPEC0016-ZDECL_QTY = GS_EXCEL_R1-ZDECL_QTY.
        LS_ZTPPEC0016-ZTOT_STOCK = GS_EXCEL_R1-ZTOT_STOCK.
        LS_ZTPPEC0016-ZSTOCK_STAT = GS_EXCEL_R1-ZSTOCK_STAT.
        LS_ZTPPEC0016-ZSTOCK_STAT2 = GS_EXCEL_R1-ZSTOCK_STAT2.
        LS_ZTPPEC0016-ISOK = GS_EXCEL_R1-ISOK.
        LS_ZTPPEC0016-ZPMREMARK = GS_EXCEL_R1-ZPMREMARK.
        LS_ZTPPEC0016-ZREPL_INV = GS_EXCEL_R1-ZREPL_INV.
        LS_ZTPPEC0016-ZUPRICE = GS_EXCEL_R1-ZUPRICE.
        LS_ZTPPEC0016-ZUPRICE2 = GS_EXCEL_R1-ZUPRICE.
        LS_ZTPPEC0016-WAERS = GS_EXCEL_R1-WAERS.
        LS_ZTPPEC0016-ZZCN = GS_EXCEL_R1-ZZCN.
        LS_ZTPPEC0016-KUNAG = GS_EXCEL_R1-KUNAG.
        LS_ZTPPEC0016-ZUNIT_CONS = GS_EXCEL_R1-ZUNIT_CONS.
        LS_ZTPPEC0016-ZTF_PREPO = GS_EXCEL_R1-ZTF_PREPO.
        LS_ZTPPEC0016-ZPM_AENAM = SY-UNAME.
        LS_ZTPPEC0016-ZPM_AEDAT = SY-DATUM.
        LS_ZTPPEC0016-ZREP_AENAM = SY-UNAME.
        LS_ZTPPEC0016-ZREP_AEDAT = SY-DATUM.
        LS_ZTPPEC0016-ZSA_REP = ''.
        LS_ZTPPEC0016-ZSA_AENAM = ''.
        LS_ZTPPEC0016-ZSA_AEDAT = ''.
        LS_ZTPPEC0016-ZPU_AENAM = ''.
        LS_ZTPPEC0016-ZPU_AEDAT = ''.
        LS_ZTPPEC0016-ZDNNO = ''.
        LS_ZTPPEC0016-ERDAT = SY-DATUM.
        LS_ZTPPEC0016-ERZET = SY-UZEIT.
        LS_ZTPPEC0016-ERNAM = SY-UNAME.
        LS_ZTPPEC0016-AEDAT = SY-DATUM.
        LS_ZTPPEC0016-AEZET = SY-UZEIT.
        LS_ZTPPEC0016-AENAM = SY-UNAME.
        LS_ZTPPEC0016-TCODE = SY-TCODE.
        MODIFY ZTPPEC0016 FROM LS_ZTPPEC0016.
        GS_EXCEL_R1-MSG_TYPE = 'S'.
        GS_EXCEL_R1-MSG_TEXT = '新建成功'.
      ENDIF.
      MODIFY GT_EXCEL_R1 FROM GS_EXCEL_R1.
    ENDLOOP.
  ELSEIF P_R7 = 'X'.
    LOOP AT GT_EXCEL_R2 INTO GS_EXCEL_R2 WHERE SEL = 'X'.
      IF GS_EXCEL_R2-MSG_TYPE = 'E'.
        MESSAGE '不能選擇錯誤數據' TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
    ENDLOOP.
    LOOP AT GT_EXCEL_R2 INTO GS_EXCEL_R2 WHERE SEL = 'X'.
      UPDATE ZTPPEC0016 SET ZUPRICE = GS_EXCEL_R2-ZUPRICE
                            ZUPRICE2 = GS_EXCEL_R2-ZUPRICE
                            WAERS = GS_EXCEL_R2-WAERS
                            ZPU_AENAM = SY-UNAME
                            ZPU_AEDAT = SY-DATUM
                            AEDAT = SY-DATUM
                            AEZET = SY-UZEIT
                            AENAM = SY-UNAME
                            TCODE = SY-TCODE
      WHERE ZID = GS_EXCEL_R2-ZID
        AND WERKS = GS_EXCEL_R2-WERKS
        AND ZVERSN = GS_EXCEL_R2-ZVERSN
        AND ZSEQ = GS_EXCEL_R2-ZSEQ
        AND MATNR = GS_EXCEL_R2-MATNR.
      GS_EXCEL_R2-MSG_TYPE = 'S'.
      GS_EXCEL_R2-MSG_TEXT = '修改成功'.
      MODIFY GT_EXCEL_R2 FROM GS_EXCEL_R2.
    ENDLOOP.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form SEL_ALL
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM SEL_ALL.

  IF P_R6 = 'X'.
    LOOP AT GT_EXCEL_R1 INTO GS_EXCEL_R1.
      GS_EXCEL_R1-SEL = 'X'.
      MODIFY GT_EXCEL_R1 FROM GS_EXCEL_R1.
    ENDLOOP.
  ELSEIF P_R7 = 'X'.
    LOOP AT GT_EXCEL_R2 INTO GS_EXCEL_R2.
      GS_EXCEL_R2-SEL = 'X'.
      MODIFY GT_EXCEL_R2 FROM GS_EXCEL_R2.
    ENDLOOP.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form SEL_SAL
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM SEL_SAL.

  IF P_R6 = 'X'.
    LOOP AT GT_EXCEL_R1 INTO GS_EXCEL_R1.
      GS_EXCEL_R1-SEL = ''.
      MODIFY GT_EXCEL_R1 FROM GS_EXCEL_R1.
    ENDLOOP.
  ELSEIF P_R7 = 'X'.
    LOOP AT GT_EXCEL_R2 INTO GS_EXCEL_R2.
      GS_EXCEL_R2-SEL = ''.
      MODIFY GT_EXCEL_R2 FROM GS_EXCEL_R2.
    ENDLOOP.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form FRM_SETEMAIL
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM FRM_SETEMAIL.


*  DATA LT_ZEMAILIST LIKE TABLE OF ZEMAILIST4 WITH HEADER LINE.
*  SELECT * INTO TABLE LT_ZEMAILIST FROM ZEMAILIST4.

  DATA IT_VIMSELLIST LIKE VIMSELLIST OCCURS 0 WITH HEADER LINE.
  DATA IT_VIMDESC LIKE VIMDESC OCCURS 0 WITH HEADER LINE.
  DATA IT_VIMNAMTAB LIKE VIMNAMTAB OCCURS 0 WITH HEADER LINE.

*  FREE MEMORY ID 'LT_ZEMAILIST'.
*  EXPORT LT_ZEMAILIST[] TO MEMORY ID 'LT_ZEMAILIST'.

  CALL FUNCTION 'VIEW_GET_DDIC_INFO'
    EXPORTING
      VIEWNAME        = 'ZEMAILIST4'
*     VARIANT_FOR_SELECTION           = ' '
*     ZDM_CALL        =
*     IGNORE_SSCUI_RESTRICTIONS       = ABAP_FALSE
    TABLES
      SELLIST         = IT_VIMSELLIST
      X_HEADER        = IT_VIMDESC
      X_NAMTAB        = IT_VIMNAMTAB
    EXCEPTIONS
      NO_TVDIR_ENTRY  = 1
      TABLE_NOT_FOUND = 2
      OTHERS          = 3.
  IF SY-SUBRC <> 0.
* Implement suitable error handling here
  ENDIF.

  DATA IT_VIMEXCLFUN LIKE VIMEXCLFUN OCCURS 0 WITH HEADER LINE.

  CALL FUNCTION 'VIEW_MAINTENANCE'
    EXPORTING
*     CORR_NUMBER               = ' '
      VIEW_ACTION               = 'U'
      VIEW_NAME                 = 'ZEMAILIST4'
*     RFC_DESTINATION_FOR_UPGRADE       = ' '
*     CLIENT_FOR_UPGRADE        = ' '
*     COMPLEX_SELCONDS_USED     = ' '
*     NO_WARNING_FOR_CLIENTINDEP        = ' '
*     OC_INST                   =
    TABLES
      DBA_SELLIST               = IT_VIMSELLIST
      EXCL_CUA_FUNCT            = IT_VIMEXCLFUN
      X_HEADER                  = IT_VIMDESC
      X_NAMTAB                  = IT_VIMNAMTAB
*     DPL_SELLIST               =
    EXCEPTIONS
      MISSING_CORR_NUMBER       = 1
      NO_DATABASE_FUNCTION      = 2
      NO_EDITOR_FUNCTION        = 3
      NO_VALUE_FOR_SUBSET_IDENT = 4
      OTHERS                    = 5.
  IF SY-SUBRC <> 0.
* Implement suitable error handling here
  ENDIF.

ENDFORM.