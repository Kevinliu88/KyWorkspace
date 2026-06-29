*&---------------------------------------------------------------------*
*& Include          ZTGPPEC0006PAI
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE USER_COMMAND_0100 INPUT.

  SAVE_OK = OK_CODE.
  CLEAR OK_CODE.

  CASE SAVE_OK.
    WHEN 'BTN_ADD100'.
      PERFORM BTN_ADD100.
    WHEN 'BTN_DEL100'.
      PERFORM BTN_DEL100.
    WHEN 'BTN_SAVE100'.
      PERFORM BTN_SAVE100.
  ENDCASE.

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  EXIT_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE EXIT_0100 INPUT.

*  CLEAR GV_ANSWER.
*  CALL FUNCTION 'POPUP_TO_CONFIRM_STEP'
*    EXPORTING
**     DEFAULTOPTION  = 'Y'
*      TEXTLINE1 = '請確認是否有數據要保存'
**     TEXTLINE2 = '確認要刪除嗎？'
*      TITEL     = '確認對話框'
**     START_COLUMN   = 25
**     START_ROW = 6
**     CANCEL_DISPLAY = SPACE
*    IMPORTING
*      ANSWER    = GV_ANSWER.
*  IF GV_ANSWER = 'J'.
*    LEAVE TO SCREEN 0.
*  ELSE.
*    RETURN.
*  ENDIF.

  LEAVE TO SCREEN 0.

ENDMODULE.

*&SPWIZARD: INPUT MODULE FOR TC 'GTB_TABKUC0100'. DO NOT CHANGE THIS LIN
*&SPWIZARD: MODIFY TABLE
MODULE GTB_TABKUC0100_MODIFY INPUT.

  PERFORM REFRESH_TABKUC0100 USING GS_TABKUC0100.

  IF GT_MATNRPRICE-BESKZ = 'F' AND GT_MATNRPRICE-SOBSL = ''. "外購，取最新的價格
    CLEAR: GT_MATNRPRICE,GT_MATNRPRICE[].
    GT_MATNRPRICE-MATNR = GS_TABKUC0100-MATNR.
    GT_MATNRPRICE-WERKS = GS_TABKUC0100-WERKS.
    APPEND GT_MATNRPRICE.
    PERFORM GET_PRICE TABLES GT_MATNRPRICE.
    READ TABLE GT_MATNRPRICE WITH KEY MATNR = GS_TABKUC0100-MATNR
                                      WERKS = GS_TABKUC0100-WERKS.
    IF SY-SUBRC = 0.
      GS_TABKUC0100-ZUPRICE = GT_MATNRPRICE-ZUPRICE.
      GS_TABKUC0100-ZUPRICE2 = GT_MATNRPRICE-ZUPRICE2.
      GS_TABKUC0100-WAERS = GT_MATNRPRICE-WAERS.
      GS_TABKUC0100-ISDJCZ = GT_MATNRPRICE-ISDJCZ. "單價是否存在
    ENDIF.
  ENDIF.

  GS_TABKUC0100-AEDAT = SY-DATUM.
  GS_TABKUC0100-AEZET = SY-UZEIT.
  GS_TABKUC0100-AENAM = SY-UNAME.

  IF P_R1 = 'X' OR P_R2 = 'X'.
    GS_TABKUC0100-ZPM_AENAM = SY-UNAME.
    GS_TABKUC0100-ZPM_AEDAT = SY-DATUM.
  ENDIF.

  IF P_R1 = 'X'.
    GS_TABKUC0100-ZREP_AENAM = SY-UNAME.
    GS_TABKUC0100-ZREP_AEDAT = SY-DATUM.
  ENDIF.

  MODIFY GT_TABKUC0100
    FROM GS_TABKUC0100
    INDEX GTB_TABKUC0100-CURRENT_LINE.
ENDMODULE.

*&SPWIZARD: INPUT MODUL FOR TC 'GTB_TABKUC0100'. DO NOT CHANGE THIS LINE
*&SPWIZARD: MARK TABLE
MODULE GTB_TABKUC0100_MARK INPUT.
  DATA: G_GTB_TABKUC0100_WA2 LIKE LINE OF GT_TABKUC0100.
  IF GTB_TABKUC0100-LINE_SEL_MODE = 1
  AND GS_TABKUC0100-SEL = 'X'.
    LOOP AT GT_TABKUC0100 INTO G_GTB_TABKUC0100_WA2
      WHERE SEL = 'X'.
      G_GTB_TABKUC0100_WA2-SEL = ''.
      MODIFY GT_TABKUC0100
        FROM G_GTB_TABKUC0100_WA2
        TRANSPORTING SEL.
    ENDLOOP.
  ENDIF.
  MODIFY GT_TABKUC0100
    FROM GS_TABKUC0100
    INDEX GTB_TABKUC0100-CURRENT_LINE
    TRANSPORTING SEL.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  CHECK_MATNR100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE CHECK_MATNR100 INPUT.

  IF P_R1 = 'X'.
    CLEAR GV_MSGTEXT.
    PERFORM CHECK_DATA USING GV_MSGTEXT.
    IF GV_MSGTEXT <> ''.
      MESSAGE GV_MSGTEXT TYPE 'E'.
    ENDIF.
  ENDIF.

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0200  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE USER_COMMAND_0200 INPUT.

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  EXIT_0200  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE EXIT_0200 INPUT.
  LEAVE TO SCREEN 0.
ENDMODULE.

*&SPWIZARD: INPUT MODULE FOR TC 'GTB_TABKUC0200'. DO NOT CHANGE THIS LIN
*&SPWIZARD: MODIFY TABLE
MODULE GTB_TABKUC0200_MODIFY INPUT.
  MODIFY GT_TABKUC0200
    FROM GS_TABKUC0200
    INDEX GTB_TABKUC0200-CURRENT_LINE.
ENDMODULE.

*&SPWIZARD: INPUT MODUL FOR TC 'GTB_TABKUC0200'. DO NOT CHANGE THIS LINE
*&SPWIZARD: MARK TABLE
MODULE GTB_TABKUC0200_MARK INPUT.
  DATA: G_GTB_TABKUC0200_WA2 LIKE LINE OF GT_TABKUC0200.
  IF GTB_TABKUC0200-LINE_SEL_MODE = 1
  AND GS_TABKUC0200-SEL = 'X'.
    LOOP AT GT_TABKUC0200 INTO G_GTB_TABKUC0200_WA2
      WHERE SEL = 'X'.
      G_GTB_TABKUC0200_WA2-SEL = ''.
      MODIFY GT_TABKUC0200
        FROM G_GTB_TABKUC0200_WA2
        TRANSPORTING SEL.
    ENDLOOP.
  ENDIF.
  MODIFY GT_TABKUC0200
    FROM GS_TABKUC0200
    INDEX GTB_TABKUC0200-CURRENT_LINE
    TRANSPORTING SEL.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  GTB_TABKUC0100_ZSA_REP  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE GTB_TABKUC0100_ZSA_REP INPUT.
  IF P_R3 = 'X'.
    GS_TABKUC0100-ZSA_AENAM = SY-UNAME.
    GS_TABKUC0100-ZSA_AEDAT = SY-DATUM.
  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  GTB_TABKUC0100_ZUPRICE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE GTB_TABKUC0100_ZUPRICE INPUT.
  IF P_R4 = 'X'.
    GS_TABKUC0100-ZPU_AENAM = SY-UNAME.
    GS_TABKUC0100-ZPU_AEDAT = SY-DATUM.
  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  SEARCH_HELP_ZMCNTYPE  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE SEARCH_HELP_ZMCNTYPE INPUT.
*GT_ZMCNTYPE

  DATA:
    BEGIN OF LT_ZMCNTYPE OCCURS 0,
      ZMCNTYPE   LIKE ZTPPEC0015-ZMCNTYPE,
      ZMCNTYPE_T TYPE CHAR20,
    END OF LT_ZMCNTYPE.
  CLEAR: LT_ZMCNTYPE,LT_ZMCNTYPE[].

  LOOP AT GT_ZMCNTYPE.
    LT_ZMCNTYPE-ZMCNTYPE = GT_ZMCNTYPE-DOMVALUE_L.
    LT_ZMCNTYPE-ZMCNTYPE_T = GT_ZMCNTYPE-DDTEXT.
    APPEND LT_ZMCNTYPE.
  ENDLOOP.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      RETFIELD         = 'ZMCNTYPE'
      DYNPPROG         = SY-REPID
      DYNPNR           = SY-DYNNR
      DYNPROFIELD      = 'GS_SCR0100-ZMCNTYPE'
      WINDOW_TITLE     = '單據類別'
      VALUE_ORG        = 'S' "Structure
      CALLBACK_PROGRAM = SY-REPID
*     CALLBACK_FORM    = 'FRM_RELATION_F4'
    TABLES
      VALUE_TAB        = LT_ZMCNTYPE
*     RETURN_TAB       = gT_HELPAUFNR[]
    EXCEPTIONS
      PARAMETER_ERROR  = 1
      NO_VALUES_FOUND  = 2
      OTHERS           = 3.

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  GTB_TABKUC0100_MATNR  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE GTB_TABKUC0100_MATNR INPUT.
  IF P_R1 = 'X'.
*  獲取庫存總數
    DATA LS_ZTPPRP0010 TYPE ZTPPRP0010.
    CLEAR LS_ZTPPRP0010.
    LS_ZTPPRP0010-ZMATNR = GS_TABKUC0100-MATNR.
    LS_ZTPPRP0010-ZPLWRK = GS_TABKUC0100-WERKS.
    SELECT MAX( ZDSDAT ) INTO LS_ZTPPRP0010-ZDSDAT FROM ZTPPRP0010
      WHERE ZMATNR = LS_ZTPPRP0010-ZMATNR
        AND ZPLWRK = LS_ZTPPRP0010-ZPLWRK.
    SELECT MAX( ZDSDATNO ) INTO LS_ZTPPRP0010-ZDSDATNO FROM ZTPPRP0010
      WHERE ZMATNR = LS_ZTPPRP0010-ZMATNR
        AND ZPLWRK = LS_ZTPPRP0010-ZPLWRK
        AND ZDSDAT = LS_ZTPPRP0010-ZDSDAT.
    SELECT SINGLE * INTO LS_ZTPPRP0010 FROM ZTPPRP0010
      WHERE ZMATNR = LS_ZTPPRP0010-ZMATNR
        AND ZPLWRK = LS_ZTPPRP0010-ZPLWRK
        AND ZDSDAT = LS_ZTPPRP0010-ZDSDAT
        AND ZDSDATNO = LS_ZTPPRP0010-ZDSDATNO.
    GS_TABKUC0100-ZTOT_STOCK = LS_ZTPPRP0010-LABST.
  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  GTB_TABKUC0100_ZSTOCK_STAT  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE GTB_TABKUC0100_ZSTOCK_STAT INPUT.

  IF P_R1 = 'X' OR P_R2 = 'X'.
    IF GS_TABKUC0100-ZSTOCK_STAT = '7'.
      IF GS_TABKUC0100-ZZCN = '' OR GS_TABKUC0100-ZUNIT_CONS = '0'.
        MESSAGE '修改類別為7待列，則必須維護型號及單位用量' TYPE 'E'.
      ENDIF.
    ENDIF.
  ENDIF.



ENDMODULE.