FUNCTION ZSD_ODM_ZTSD0088.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(I_VTWEG) TYPE  VTWEG
*"     REFERENCE(I_ZBCUST) TYPE  KUNNR
*"  EXPORTING
*"     REFERENCE(E_ZTSD0088) TYPE  ZTSD0088
*"----------------------------------------------------------------------

  DATA: LS_ZTSD0098 LIKE ZTSD0098.

  CLEAR: E_ZTSD0088, LS_ZTSD0098.
*1.抓取最新一筆ztsd0098-ZYM
* select * from ztsd0098 where ZAUTHORG = 傳入的zauthorg and ZBCUST = 傳入的 zbcust order by zym descending ZPERIOD descending
  SELECT * UP TO 1 ROWS FROM ZTSD0098 INTO LS_ZTSD0098
           WHERE vtweg = I_vtweg
             AND ZBCUST   = I_ZBCUST
           ORDER BY ZYM DESCENDING ZPERIOD DESCENDING.
  ENDSELECT.
  IF SY-SUBRC <> 0.
*2.若抓不到step 1的 ztsd0098，則抓取最新一筆ztsd0088回傳  &離開call function
*select * from ztsd0088 where  ZAUTHORG = 傳入的zauthorg and ZBCUST = 傳入的 zbcust order by zym descending ZPERIOD descending
    SELECT * UP TO 1 ROWS FROM ZTSD0088 INTO E_ZTSD0088
             WHERE  vtweg = I_vtweg
               AND ZBCUST   = I_ZBCUST
             ORDER BY ZYM DESCENDING ZPERIOD DESCENDING.
    ENDSELECT.
  ELSE.
*2.若抓到step 1的 ztsd0098，則抓取對應的ztsd0088回傳  &離開call function
*select * from ztsd0088 where  ZAUTHORG = 傳入的zauthorg and ZBCUST = 傳入的 zbcust and ZYM = ztsd0098-zym and ZPERIOD = ztsd0098-ZPERIOD
    SELECT SINGLE * FROM ZTSD0088 INTO E_ZTSD0088
                    WHERE  vtweg = I_vtweg
                      AND ZBCUST   = I_ZBCUST
                      AND ZYM      = LS_ZTSD0098-ZYM
                      AND ZPERIOD  = LS_ZTSD0098-ZPERIOD.
    IF SY-SUBRC <> 0.
      SELECT * UP TO 1 ROWS FROM ZTSD0088 INTO E_ZTSD0088
               WHERE  vtweg = I_vtweg
                 AND ZBCUST   = I_ZBCUST
               ORDER BY ZYM DESCENDING ZPERIOD DESCENDING.
      ENDSELECT.
    ENDIF.
  ENDIF.

ENDFUNCTION.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
