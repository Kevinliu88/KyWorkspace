FUNCTION Z_SD_ODM_DNCN_XQ_INTERFACE .
*"----------------------------------------------------------------------
*"*"區域介面：
*"  IMPORTING
*"     VALUE(I_UUID) TYPE  ZTSD0098_CRT-UUID OPTIONAL
*"     VALUE(I_ZAUTHORG) TYPE  ZTSD0098_CRT-WERKS OPTIONAL
*"  TABLES
*"      IT_ZTSD0098_CRT STRUCTURE  ZTSD0098_CRT OPTIONAL
*"----------------------------------------------------------------------
*&=====================================================================*
* Modification Log - History
*&=====================================================================*
*    DATE     VERSION      AUTHOR                  DESCRIPTION
* ========== ========  ==============  =================================
* 2020/09/15 V001      Fangchyi        一次回傳一個權限組織的XQ單
*                                      (因為dncn已調整成不允許多個權限組織存在同一張DNCN中，
*                                      所以代表一次只會有一個權限組織資料回傳PROGRESS)
* 2024/04/09 V002      Fangchyi        S4調整 : zauthorg >werks
*&---------------------------------------------------------------------*

  DATA: LT_ZTSD0098_CRT LIKE TABLE OF ZTSD0098_CRT.
  DATA: L_EXIST.
  DATA: VJOBNAME  TYPE BTCJOB,
        VJOBCOUNT TYPE BTCJOBCNT,
        SDATE     TYPE TBTCJOB-SDLSTRTDT,
        STIME     TYPE TBTCJOB-SDLSTRTTM.
  RANGES: R_ZXQNO FOR ZTSD0098-ZXQNO.

  REFRESH: R_ZXQNO. CLEAR: R_ZXQNO.

  CHECK IT_ZTSD0098_CRT[] IS NOT INITIAL.

"" ""  LOOP AT IT_ZTSD0098_CRT.
"" ""    R_ZXQNO-SIGN = 'I'.
"" ""    R_ZXQNO-OPTION = 'EQ'.
"" ""    R_ZXQNO-LOW = IT_ZTSD0098_CRT-ZXQNO.
"" ""    COLLECT R_ZXQNO. CLEAR R_ZXQNO.
"" ""  ENDLOOP.
"" ""
"" ""  IF SY-SUBRC = 0.
"" ""    L_EXIST = 'X'.
"" ""  ENDIF.
"" ""
"" ""  CHECK L_EXIST = 'X'.
"" ""   SUBMIT ZTWRSD0124 AND RETURN          "預採帳DN/CN資料傳送介接程式
"" ""          WITH CALLD   = 'X'
"" "" *             WITH S_UUID  = I_UUID
"" ""          WITH S_ZAUTH = I_ZAUTHORG   "V001
"" ""         WITH S_ZXQNO IN R_ZXQNO.

ENDFUNCTION.


*Messages
*----------------------------------------------------------
*
* Message class: ZODMSD01
*000   & & & &

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
