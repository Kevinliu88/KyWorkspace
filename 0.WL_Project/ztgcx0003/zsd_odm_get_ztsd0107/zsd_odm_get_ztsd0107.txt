FUNCTION ZSD_ODM_GET_ZTSD0107.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(I_VTWEG) TYPE  VTWEG
*"     VALUE(I_MATKL) TYPE  MATKL
*"     VALUE(I_ZPNO) TYPE  ZPNO OPTIONAL
*"     VALUE(I_ZPNOCODE) TYPE  ZPNOCODE OPTIONAL
*"     VALUE(I_MEINS) TYPE  MEINS OPTIONAL
*"     VALUE(I_ZPCUR) TYPE  ZPCUR OPTIONAL
*"     VALUE(I_ZMOQLINE) TYPE  ZMOQLINE OPTIONAL
*"  EXPORTING
*"     VALUE(E_ZTSD0107) TYPE  ZTSD0107
*"----------------------------------------------------------------------
* 2025/03/05  V001      Francie          S4調整
*                       1. 不再使用ZTSD0107-ZAUTHORG,ZTSD0107-KUNNR
*-----------------------------------------------------------------------
  TABLES: ZTSD0089.
  DATA: ZTSD0107_CUR TYPE ZPCUR,
        GT_ZTSD0107  LIKE ZTSD0107 OCCURS 0 WITH HEADER LINE,
        P_FLAG(1).
  RANGES: R_ZMOQLINE FOR ZTSD0107-ZMOQLINE,
          R_ZPNO FOR ZTSD0107-ZPNO,
          R_ZPCUR FOR ZTSD0107-ZPCUR,
          R_MEINS FOR ZTSD0107-MEINS,
          R_ZPNOCODE_IN FOR ZTSD0107-ZPNOCODE_IN.

*select ztsd0089
*最新一筆ztsd0089中匯率為1的幣別判斷		
*select single * from ztsd0089 whre zauthorg = 傳入的權限組織  order by zprdate descending		
*抓到的ztsd0089 逐個欄位判斷哪個欄位為1，則以該欄位所代表的幣別去select ztsd0107		
  SELECT *
    FROM ZTSD0089
*>> V001 modify start
*   WHERE ZAUTHORG = I_ZAUTHORG
   where vtweg = i_vtweg
*<< V001 modify end
    ORDER BY ZPRDATE DESCENDING.
    EXIT.
  ENDSELECT.
  IF SY-SUBRC = 0.
    IF ZTSD0089-Z_NTRATE = 1.
      ZTSD0107_CUR = 'TWD'.
    ELSEIF ZTSD0089-Z_RMBRATE = 1.
      ZTSD0107_CUR = 'CNY'.
    ELSEIF ZTSD0089-Z_HKRATE = 1.
      ZTSD0107_CUR = 'HKD'.
    ELSEIF ZTSD0089-Z_USRATE = 1.
      ZTSD0107_CUR = 'USD'.
    ELSEIF ZTSD0089-Z_EURRATE = 1.
      ZTSD0107_CUR = 'EUR'.
    ENDIF.
  ENDIF.

  REFRESH: GT_ZTSD0107.
  SELECT *
    INTO TABLE GT_ZTSD0107
    FROM ZTSD0107
*>> V001 modify start
*   WHERE ZAUTHORG = I_ZAUTHORG
*     AND KUNNR = I_ZBCUST.
    where vtweg = i_vtweg
      and matkl = i_matkl.
*<< V001 modify end
  SORT GT_ZTSD0107 BY KOZGF.
  CLEAR: P_FLAG.
  LOOP AT GT_ZTSD0107.
    REFRESH: R_ZMOQLINE,R_ZPNO,R_ZPCUR,R_MEINS,R_ZPNOCODE_IN.
*預採帳線別	range value : IEQ
    IF GT_ZTSD0107-ZMOQLINE <> ''.
      CONCATENATE 'IEQ' GT_ZTSD0107-ZMOQLINE INTO R_ZMOQLINE.
      APPEND R_ZMOQLINE.
    ENDIF.
*廠內件號	range value : ICP
    IF GT_ZTSD0107-ZPNO <> ''.
      CONCATENATE 'ICP' GT_ZTSD0107-ZPNO INTO R_ZPNO.
      APPEND R_ZPNO.
    ENDIF.
*原採購幣別	range value : IEQ
    IF GT_ZTSD0107-ZPCUR <> ''.
      CONCATENATE 'IEQ' GT_ZTSD0107-ZPCUR INTO R_ZPCUR.
      APPEND R_ZPCUR.
    ENDIF.
*基礎計量單位	range value : IEQ
    IF GT_ZTSD0107-MEINS <> ''.
      CONCATENATE 'IEQ' GT_ZTSD0107-MEINS INTO R_MEINS.
      APPEND R_MEINS.
    ENDIF.
*存貨費用類別判斷	依內容值放range value
    IF GT_ZTSD0107-ZPNOCODE_IN <> ''.
      R_ZPNOCODE_IN = GT_ZTSD0107-ZPNOCODE_IN.
      APPEND R_ZPNOCODE_IN.
    ENDIF.
    IF I_ZMOQLINE IN R_ZMOQLINE
    AND I_ZPNO IN R_ZPNO
    AND I_ZPCUR IN R_ZPCUR
    AND I_MEINS IN R_MEINS
    AND I_ZPNOCODE IN R_ZPNOCODE_IN.
      P_FLAG = 'X'.
      EXIT.
    ENDIF.
  ENDLOOP.
  IF P_FLAG = 'X'.
    E_ZTSD0107 = GT_ZTSD0107.
  ENDIF.

ENDFUNCTION.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
