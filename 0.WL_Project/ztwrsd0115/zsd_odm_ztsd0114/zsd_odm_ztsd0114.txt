FUNCTION ZSD_ODM_ZTSD0114.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(I_Z6PTYP) TYPE  Z6PTYP
*"     REFERENCE(I_VTWEG) TYPE  VTWEG
*"     REFERENCE(I_ZBCUST) TYPE  KUNNR
*"  EXPORTING
*"     REFERENCE(E_ZTSD0114) TYPE  ZTSD0114
*"----------------------------------------------------------------------

  CLEAR: E_ZTSD0114.

  CHECK I_Z6PTYP NE SPACE.

*1.使用傳入的Z6PTYP,ZENTITY,ZBCUST 找 ZTSD0114 ,找到則回傳ZTSD0114 &離開call function
*select * from ZTSD0114 where Z6PTYP = 傳入的 Z6PTYP and zentity = 傳入的zentity and zbcust = 傳入的zbcust
  SELECT SINGLE * FROM ZTSD0114 INTO E_ZTSD0114
                  WHERE Z6PTYP = I_Z6PTYP
                    AND VTWEG = I_VTWEG
                    AND ZBCUST  = I_ZBCUST.
  IF SY-SUBRC <> 0.
*2.step 1找不到時，再使用傳入的Z6PTYP,*,ZBCUST 找 ZTSD0114 ,找到則回傳ZTSD0114 &離開call function
*select * from ZTSD0114 where Z6PTYP = 傳入的 Z6PTYP and zentity = '*' and zbcust = 傳入的zbcust
    SELECT SINGLE * FROM ZTSD0114 INTO E_ZTSD0114
                    WHERE Z6PTYP = I_Z6PTYP
                      AND VTWEG = '*'
                      AND ZBCUST  = I_ZBCUST.
    IF SY-SUBRC <> 0.

*3.step 2找不到時，再使用傳入的Z6PTYP,ZENTITY,* 找 ZTSD0114 ,找到則回傳ZTSD0114 &離開call function
*select * from ZTSD0114 where Z6PTYP = 傳入的 Z6PTYP and zentity = 傳入的zentity and zbcust = '*'
      SELECT SINGLE * FROM ZTSD0114 INTO E_ZTSD0114
                      WHERE Z6PTYP = I_Z6PTYP
                        AND VTWEG = I_VTWEG
                        AND ZBCUST  = '*'.
      IF SY-SUBRC <> 0.
*4.step 4找不到時，再使用傳入的Z6PTYP,*,* 找 ZTSD0114 ,找到則回傳ZTSD0114 &離開call function
*select * from ZTSD0114 where Z6PTYP = 傳入的 Z6PTYP and zentity = '*' AND zbcust = '*'
        SELECT SINGLE * FROM ZTSD0114 INTO E_ZTSD0114
                        WHERE Z6PTYP = I_Z6PTYP
                          AND VTWEG = '*'
                          AND ZBCUST  = '*'.
      ENDIF.
    ENDIF.
  ENDIF.



ENDFUNCTION.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
