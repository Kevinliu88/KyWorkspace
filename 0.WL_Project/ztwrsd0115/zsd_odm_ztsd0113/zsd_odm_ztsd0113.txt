FUNCTION ZSD_ODM_ZTSD0113.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(I_ZUNPTYP) TYPE  ZUNPTYP
*"     REFERENCE(I_VTWEG) TYPE  VTWEG
*"     REFERENCE(I_ZBCUST) TYPE  KUNNR
*"  EXPORTING
*"     REFERENCE(E_ZTSD0113) TYPE  ZTSD0113
*"----------------------------------------------------------------------

  CLEAR: E_ZTSD0113.

  CHECK I_ZUNPTYP NE SPACE.

*1.使用傳入的ZUNPTYP,VTWEG,ZBCUST 找 ztsd0113 ,找到則回傳ztsd0113 &離開call function
*select * from ztsd0113 where ZUNPTYP = 傳入的 zunptyp and VTWEG = 傳入的VTWEG and zbcust = 傳入的zbcust
  SELECT SINGLE * FROM ZTSD0113 INTO E_ZTSD0113
                  WHERE ZUNPTYP = I_ZUNPTYP
                    AND VTWEG = I_VTWEG
                    AND ZBCUST  = I_ZBCUST.
  IF SY-SUBRC <> 0.
*2.step 1找不到時，再使用傳入的ZUNPTYP,*,ZBCUST 找 ztsd0113 ,找到則回傳ztsd0113 &離開call function
*select * from ztsd0113 where ZUNPTYP = 傳入的 zunptyp and VTWEG = '*' and zbcust = 傳入的zbcust
    SELECT SINGLE * FROM ZTSD0113 INTO E_ZTSD0113
                    WHERE ZUNPTYP = I_ZUNPTYP
                      AND VTWEG = '*'
                      AND ZBCUST  = I_ZBCUST.
    IF SY-SUBRC <> 0.

*3.step 2找不到時，再使用傳入的ZUNPTYP,ZENTITY,* 找 ztsd0113 ,找到則回傳ztsd0113 &離開call function
*select * from ztsd0113 where ZUNPTYP = 傳入的 zunptyp and VTWEG = 傳入的zentity and zbcust = '*'
      SELECT SINGLE * FROM ZTSD0113 INTO E_ZTSD0113
                      WHERE ZUNPTYP = I_ZUNPTYP
                        AND VTWEG = I_VTWEG
                        AND ZBCUST  = '*'.
      IF SY-SUBRC <> 0.
*4.step 3找不到時，再使用傳入的ZUNPTYP,*,* 找 ztsd0113 ,找到則回傳ztsd0113 &離開call function
*select * from ztsd0113 where ZUNPTYP = 傳入的 zunptyp and VTWEG = '*' AND zbcust = '*'
        SELECT SINGLE * FROM ZTSD0113 INTO E_ZTSD0113
                        WHERE ZUNPTYP = I_ZUNPTYP
                          AND VTWEG = '*'
                          AND ZBCUST  = '*'.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFUNCTION.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
