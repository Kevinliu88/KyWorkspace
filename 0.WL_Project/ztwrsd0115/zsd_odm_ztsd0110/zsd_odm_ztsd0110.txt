FUNCTION ZSD_ODM_ZTSD0110.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(I_ZKINDS) TYPE  ZKINDS
*"     REFERENCE(I_VTWEG) TYPE  VTWEG
*"     REFERENCE(I_ZBCUST) TYPE  KUNNR
*"  EXPORTING
*"     REFERENCE(E_ZTSD0110)
*"----------------------------------------------------------------------
  CLEAR: E_ZTSD0110.

  CHECK I_ZKINDS NE SPACE.

*1.使用傳入的ZKINDS,VTWEG,ZBCUST 找 ztsd0110 ,找到則回傳ztsd0110 &離開call function
*select * from ztsd0110 where ZKINDS = 傳入的ZKINDS and VTWEG = 傳入的VTWEG and zbcust = 傳入的zbcust
  SELECT SINGLE * FROM ZTSD0110 INTO E_ZTSD0110
                  WHERE ZKINDS  = I_ZKINDS
                    AND VTWEG = I_VTWEG
                    AND ZBCUST  = I_ZBCUST.
  IF SY-SUBRC <> 0.
*2.step 1找不到時，再使用傳入的ZKINDS,*,ZBCUST找 ztsd0110 ,找到則回傳ztsd0110 &離開call function
*select * from ztsd0110 where ZKINDS = 傳入的ZKINDS and VTWEG = '*' AND zbcust = 傳入的zbcust
    SELECT SINGLE * FROM ZTSD0110 INTO E_ZTSD0110
                    WHERE ZKINDS  = I_ZKINDS
                      AND VTWEG = '*'
                      AND ZBCUST  = I_ZBCUST.
    IF SY-SUBRC <> 0.

*2.step 1找不到時，再使用傳入的ZKINDS,VTWEG,*找 ztsd0110 ,找到則回傳ztsd0110 &離開call function
*select * from ztsd0110 where ZKINDS = 傳入的ZKINDS and VTWEG = 傳入的VTWEG and zbcust = '*'
      SELECT SINGLE * FROM ZTSD0110 INTO E_ZTSD0110
                      WHERE ZKINDS  = I_ZKINDS
                        AND VTWEG = I_VTWEG
                        AND ZBCUST  = '*'.
      IF SY-SUBRC <> 0.
*3.step 2找不到時，再再使用傳入的ZKINDS,*,*找 ztsd0110 ,找到則回傳ztsd0110 &離開call function
*select * from ztsd0110 where ZKINDS = 傳入的ZKINDS and VTWEG = '*' AND zbcust = '*'
        SELECT SINGLE * FROM ZTSD0110 INTO E_ZTSD0110
                        WHERE ZKINDS  = I_ZKINDS
                          AND VTWEG = '*'
                          AND ZBCUST  = '*'.
      ENDIF.
    ENDIF.
  ENDIF.


ENDFUNCTION.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
