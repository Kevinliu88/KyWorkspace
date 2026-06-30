FUNCTION ZSD_ODM_ZTSD0109.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(I_ZXQLINE) TYPE  ZMOQLINE
*"     REFERENCE(I_VTWEG) TYPE  VTWEG
*"     REFERENCE(I_ZBCUST) TYPE  KUNNR
*"     REFERENCE(I_ZWAERS) TYPE  WAERS
*"  EXPORTING
*"     REFERENCE(E_ZTSD0109) TYPE  ZTSD0109
*"----------------------------------------------------------------------


  CLEAR: E_ZTSD0109.

  CHECK I_ZXQLINE NE SPACE.

*V001 added
*1.使用傳入的ZXQLINE,VTWEG,ZBCUST,ZWAERS 找 ztsd0109 ,找到則回傳ztsd0109 &離開call function
*select * from ztsd0109 where ZXQLINE = 傳入的ZXQLINE and VTWEG =  傳入的VTWEG and zbcust = 傳入的zbcust
  SELECT SINGLE * FROM ZTSD0109 INTO E_ZTSD0109
                  WHERE ZXQLINE = I_ZXQLINE
                    AND VTWEG = i_VTWEG
                    AND ZBCUST  = I_ZBCUST
                    AND WAERS   = I_ZWAERS.
  IF SY-SUBRC <> 0.
*2.step 1找不到時，再使用傳入的ZXQLINE,*,ZBCUST,ZWAERS 找 ztsd0109 ,找到則回傳ztsd0109 &離開call function
*select * from ztsd0109 where ZXQLINE = 傳入的ZXQLINE and vtweg = '*' AND zbcust = 傳入的zbcust
    SELECT SINGLE * FROM ZTSD0109 INTO E_ZTSD0109
                    WHERE ZXQLINE = I_ZXQLINE
                      AND VTWEG =  '*'
                      AND ZBCUST  = I_ZBCUST
                      AND WAERS   = I_ZWAERS.
    IF SY-SUBRC <> 0.

*3.step 2找不到時，再使用傳入的ZXQLINE,VTWEG ,* ,ZWAERS找 ztsd0109 ,找到則回傳ztsd0109 &離開call function
*select * from ztsd0109 where ZXQLINE = 傳入的ZXQLINE and vtweg = 傳入的vtweg and zbcust = '*'
      SELECT SINGLE * FROM ZTSD0109 INTO E_ZTSD0109
                      WHERE ZXQLINE = I_ZXQLINE
                        AND VTWEG = I_VTWEG
                        AND ZBCUST  = '*'
                        AND WAERS   = I_ZWAERS.
      IF SY-SUBRC <> 0.
*4.step 3找不到時，再使用傳入的ZXQLINE,*,* ,ZWAERS找 ztsd0109 ,找到則回傳ztsd0109 &離開call function
*select * from ztsd0109 where ZXQLINE = 傳入的ZXQLINE and VTWEG = '*' AND zbcust = '*'
        SELECT SINGLE * FROM ZTSD0109 INTO E_ZTSD0109
                       WHERE ZXQLINE = I_ZXQLINE
                         AND VTWEG =  '*'
                         AND ZBCUST  = '*'
                         AND WAERS   = I_ZWAERS.
      ENDIF.
    ENDIF.
  ENDIF.
  IF sy-subrc <> 0.
*V001 end off
*1.使用傳入的ZXQLINE,VTWEG,ZBCUST 找 ztsd0109 ,找到則回傳ztsd0109 &離開call function
*select * from ztsd0109 where ZXQLINE = 傳入的ZXQLINE and VTWEG = 傳入的vtweg and zbcust = 傳入的zbcust
  SELECT SINGLE * FROM ZTSD0109 INTO E_ZTSD0109
                  WHERE ZXQLINE = I_ZXQLINE
                    AND VTWEG = I_VTWEG
                    AND ZBCUST  = I_ZBCUST
                    AND WAERS   = '*'.  "V001 added field waers
  IF SY-SUBRC <> 0.
*2.step 1找不到時，再使用傳入的ZXQLINE,*,ZBCUST 找 ztsd0109 ,找到則回傳ztsd0109 &離開call function
*select * from ztsd0109 where ZXQLINE = 傳入的ZXQLINE and VTWEG = '*' AND zbcust = 傳入的zbcust
    SELECT SINGLE * FROM ZTSD0109 INTO E_ZTSD0109
                    WHERE ZXQLINE = I_ZXQLINE
                      AND VTWEG = '*'
                      AND ZBCUST  = I_ZBCUST
                      AND WAERS   = '*'.  "V001 added field waers
    IF SY-SUBRC <> 0.

*3.step 2找不到時，再使用傳入的ZXQLINE,VTWEG,* 找 ztsd0109 ,找到則回傳ztsd0109 &離開call function
*select * from ztsd0109 where ZXQLINE = 傳入的ZXQLINE and VTWEG = 傳入的vtweg and zbcust = '*'
      SELECT SINGLE * FROM ZTSD0109 INTO E_ZTSD0109
                      WHERE ZXQLINE = I_ZXQLINE
                        AND VTWEG = I_VTWEG
                        AND ZBCUST  = '*'
                        AND WAERS   = '*'.  "V001 added field waers
      IF SY-SUBRC <> 0.
*4.step 3找不到時，再使用傳入的ZXQLINE,*,* 找 ztsd0109 ,找到則回傳ztsd0109 &離開call function
*select * from ztsd0109 where ZXQLINE = 傳入的ZXQLINE and VTWEG =  '*' AND zbcust = '*'
        SELECT SINGLE * FROM ZTSD0109 INTO E_ZTSD0109
                       WHERE ZXQLINE = I_ZXQLINE
                         AND VTWEG =  '*'
                         AND ZBCUST  = '*'
                         AND WAERS   = '*'.  "V001 added field waers
      ENDIF.
    ENDIF.
  ENDIF.
*V001 added
  ENDIF.   "
  IF e_ztsd0109 IS NOT INITIAL
  AND ( e_ztsd0109-waers = ''
       OR e_ztsd0109-waers = '*' ).
    e_ztsd0109-waers = i_zwaers.
  ENDIF.
*V001 end off



ENDFUNCTION.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
