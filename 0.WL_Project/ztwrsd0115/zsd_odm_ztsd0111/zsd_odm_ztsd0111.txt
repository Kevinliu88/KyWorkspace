FUNCTION ZSD_ODM_ZTSD0111.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(I_ZXQDTYP) TYPE  ZXQDTYP
*"     REFERENCE(I_VTWEG) TYPE  VTWEG
*"     REFERENCE(I_ZBCUST) TYPE  KUNNR
*"  EXPORTING
*"     REFERENCE(E_ZTSD0111) TYPE  ZTSD0111
*"----------------------------------------------------------------------

  CLEAR: E_ZTSD0111.

  CHECK I_ZXQDTYP NE SPACE.

*1.使用傳入的ZXQDTYP,VTWEG,ZBCUST 找 ztsd0111 ,找到則回傳ztsd0111 &離開call function		
*select * from ztsd0111 where ZXQDTYP = 傳入的ZXQDTYP and VTWEG = 傳入的VTWEG and zbcust = 傳入的zbcust		
  SELECT SINGLE * FROM ZTSD0111 INTO E_ZTSD0111
                  WHERE ZXQDTYP = I_ZXQDTYP
                    AND VTWEG = I_VTWEG
                    AND ZBCUST  = I_ZBCUST.
  IF SY-SUBRC <> 0.
*2.step 1找不到時，再使用傳入的ZXQDTYP,*,ZBCUST 找 ztsd0111 ,找到則回傳ztsd0111 &離開call function		
*select * from ztsd0111 where ZXQDTYP = 傳入的ZXQDTYP and VTWEG = '*'	and zbcust = 傳入的zbcust	
    SELECT SINGLE * FROM ZTSD0111 INTO E_ZTSD0111
                    WHERE ZXQDTYP = I_ZXQDTYP
                      AND VTWEG = '*'
                      AND ZBCUST  = I_ZBCUST.
    IF SY-SUBRC <> 0.

*3.step 2找不到時，再使用傳入的ZXQDTYP,VTWEG,* 找 ztsd0111 ,找到則回傳ztsd0111 &離開call function		
*select * from ztsd0111 where ZXQDTYP = 傳入的ZXQDTYP and zentity = 傳入的zentity and zbcust = '*'		
      SELECT SINGLE * FROM ZTSD0111 INTO E_ZTSD0111
                      WHERE ZXQDTYP = I_ZXQDTYP
                        AND VTWEG = I_VTWEG
                        AND ZBCUST  = '*'.
      IF SY-SUBRC <> 0.
*4.step 3找不到時，再使用傳入的ZXQDTYP,*,* 找 ztsd0111 ,找到則回傳ztsd0111 &離開call function		
*select * from ztsd0111 where ZXQDTYP = 傳入的ZXQDTYP and zentity = '*' AND zbcust = '*'		
        SELECT SINGLE * FROM ZTSD0111 INTO E_ZTSD0111
                        WHERE ZXQDTYP = I_ZXQDTYP
                          AND VTWEG = '*'
                          AND ZBCUST  = '*'.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFUNCTION.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
