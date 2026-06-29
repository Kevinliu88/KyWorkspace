FUNCTION ZSD_ODM_XQ_PRICE.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(I_VTWEG) TYPE  VTWEG OPTIONAL
*"     VALUE(I_MATKL) TYPE  MATKL OPTIONAL
*"     VALUE(I_ZPNO) TYPE  ZPNO OPTIONAL
*"     VALUE(I_ZPNOCODE) TYPE  ZPNOCODE OPTIONAL
*"     VALUE(I_MEINS) TYPE  MEINS OPTIONAL
*"     VALUE(I_ZMOQLINE) TYPE  ZMOQLINE OPTIONAL
*"     VALUE(I_PRSDT) TYPE  PRSDT
*"     VALUE(I_ZPCUR) TYPE  ZPCUR OPTIONAL
*"     VALUE(I_ZPUP) TYPE  ZPUP OPTIONAL
*"     VALUE(I_ZPUP_PER) TYPE  ZPUP_PER OPTIONAL
*"     VALUE(I_ZPCNYUP) TYPE  ZPCNYUP OPTIONAL
*"     VALUE(I_ZPCNY_PER) TYPE  ZPCNY_PER OPTIONAL
*"     VALUE(I_ZPTWDUP) TYPE  ZPTWDUP OPTIONAL
*"     VALUE(I_ZPTWD_PER) TYPE  ZPTWD_PER OPTIONAL
*"     VALUE(I_ZTSD0107) TYPE  ZTSD0107 OPTIONAL
*"  EXPORTING
*"     VALUE(E_ZCALCUR) TYPE  WAERS
*"     VALUE(E_ZFORMULATYPE) TYPE  ZFORMULATYPE
*"     VALUE(E_ZUP_CUR) TYPE  ZUSDCUR
*"     VALUE(E_ZUP) TYPE  ZUP9
*"     VALUE(E_ZUP_PER) TYPE  ZUP_PER
*"     VALUE(E_ZUPFORMULA) TYPE  ZUPFORMULA
*"     VALUE(E_ZTSD0107) TYPE  ZTSD0107
*"----------------------------------------------------------------------
* 2025/03/05  V001      Francie          S4調整
*                       1. 不再使用ZTSD0107-ZAUTHORG,ZTSD0107-KUNNR
*----------------------------------------------------------------------
  TABLES: KOMV,RV45A.
  DATA: FS_KOMK TYPE KOMK,
        FS_KOMP TYPE KOMP.
  DATA: FT_KOMV         TYPE STANDARD TABLE OF KOMV.
  DATA: WK_AMT(15) TYPE P DECIMALS 6,
        C_AMT(15)  TYPE C,
        C_INT(15)  TYPE C,
        C_DEC(6)   TYPE C,
        I_LEN      TYPE I.
  DATA: WK_BASE TYPE MENGE_D VALUE '1000000'.
  CLEAR: E_ZCALCUR,E_ZFORMULATYPE,E_ZUP_CUR,E_ZUP,E_ZUP_PER,E_ZUPFORMULA,E_ZTSD0107.
  IF I_ZTSD0107 IS INITIAL.
    CALL FUNCTION 'ZSD_ODM_GET_ZTSD0107'
      EXPORTING
*>>V001 modify start
*        I_ZAUTHORG = I_ZAUTHORG
*        I_ZBCUST   = I_ZBCUST
         i_vtweg    = i_vtweg
         i_matkl    = i_matkl
*<<V001 modify end
        I_ZPNO     = I_ZPNO
        I_ZPNOCODE = I_ZPNOCODE
        I_MEINS    = I_MEINS
        I_ZPCUR    = I_ZPCUR
        I_ZMOQLINE = I_ZMOQLINE
      IMPORTING
        E_ZTSD0107 = E_ZTSD0107.
  ELSE.
    E_ZTSD0107 = I_ZTSD0107.
  ENDIF.

  CHECK E_ZTSD0107 IS NOT INITIAL.

*傳入相關欄位決定第一層價格: 採購價加價 & 美金匯率換算  : 當ZTSD0107-ZCALCUR <> 'USD'時
*call function 'Pricing' 決定加價(1) / 匯率/ 匯率base   : 傳入參數詳見 SHEET CALL FUNCTIN PRICING說明 : 項次2
  IF E_ZCALCUR = SPACE.
    E_ZCALCUR = E_ZTSD0107-ZCALCUR.
  ENDIF.
  IF E_ZCALCUR = 'USD'.
    FS_KOMK-KALSM        = 'ZZ03'.
  ELSE.
    FS_KOMK-KALSM        = 'ZZ01'.
  ENDIF.
*>>V001 modify start
*  FS_KOMK-ZAUTHORG     = E_ZTSD0107-ZAUTHORG.
*  FS_KOMK-KUNNR        = E_ZTSD0107-KUNNR.
  FS_KOMK-vtweg     = E_ZTSD0107-VTWEG.
*<<V001 modify end
  FS_KOMK-WAERK        = E_ZTSD0107-WAERS.
  FS_KOMK-ZMOQLINE     = E_ZTSD0107-ZMOQLINE.
  FS_KOMK-PRSDT        = I_PRSDT.
  FS_KOMK-KAPPL        = 'V'.
  FS_KOMK-BELNR        = '$000000001'.
  FS_KOMK-KNUMV        = '$000000001'.
  FS_KOMK-HWAER        = 'USD'. "本國幣別 : 以客戶收款幣別為本國幣別
  FS_KOMP-ZFORMULATYPE = E_ZTSD0107-ZFORMULATYPE.
  FS_KOMP-MGAME        = WK_BASE.  "以1000000為BASE 減少小數位差
  FS_KOMP-MGLME        = WK_BASE.  "以1000000為BASE 減少小數位差
  FS_KOMP-LMENG        = WK_BASE.  "以1000000為BASE 減少小數位差
  FS_KOMP-PRSFD        = 'X'.
  FS_KOMP-PRSOK        = 'X'.
  FS_KOMP-EVRWR        = 'X'.
  FS_KOMP-KURSK        = 1. "匯率固定為1
  FS_KOMP-MEINS        = 'PC'.
  FS_KOMP-LAGME        = 'PC'.
  FS_KOMP-VRKME        = 'PC'.
  FS_KOMP-KPOSN        = '000010'.
  FS_KOMP-TAXPS        = '000010'.
  FS_KOMP-AUPOS        = '000010'.
*>>V001 modify start
  FS_KOMP-matkl     = E_ZTSD0107-MATKL.
*<<V001 modify end

**台幣金額若不為0,以台幣單價放入毛重,針對不同毛重級距取得conditon value
**台幣單價:借用重量當作台幣單價使用
  IF I_ZPTWDUP <> 0.
**轉換為外顯值
    I_ZPTWDUP = I_ZPTWDUP * 100.
**台幣單價放入毛重
    IF I_ZPTWD_PER NE 0.
     FS_KOMP-BRGEW = I_ZPTWDUP / I_ZPTWD_PER.
    ELSE.
     FS_KOMP-BRGEW = 0.
    ENDIF.
  ELSE.
    FS_KOMP-BRGEW        = E_ZTSD0107-KSTBM.
  ENDIF.
  FS_KOMP-GEWEI        = 'KG'.
  FS_KOMP-AUBEL        = '$TEMP'.
  FS_KOMP-IX_KOMK      = 1.
  FS_KOMP-UMVKZ        = 1.
  FS_KOMP-UMVKN        = 1.
  FS_KOMP-ANZ_TAGE     = 1.
  FS_KOMP-ANZ_MONATE   = 1.
  FS_KOMP-ANZ_WOCHEN   = 1.
  FS_KOMP-ANZ_JAHRE    = 1.
  FS_KOMP-STF_TAGE     = 1.
  FS_KOMP-STF_MONATE   = 1.
  FS_KOMP-STF_WOCHEN   = 1.
  FS_KOMP-STF_JAHRE    = 1.
**
  CALL FUNCTION 'PRICING'
    EXPORTING
      CALCULATION_TYPE = 'C'        "Carry out new Pricing
      COMM_HEAD_I      = FS_KOMK
      COMM_ITEM_I      = FS_KOMP
*     PRELIMINARY      = ' '
*     NO_CALCULATION   = ' '
    IMPORTING
      COMM_HEAD_E      = FS_KOMK
      COMM_ITEM_E      = FS_KOMP
    TABLES
      TKOMV            = FT_KOMV
*     SVBAP            =
*   CHANGING
*     REBATE_DETERMINED       = ' '
    EXCEPTIONS
      OTHERS           = 0.  "No SUBRC check required, as we handle this below
*  CALL FUNCTION 'ZSD_ODM_XQ_FORMULA'
*    IMPORTING
*      E_ZUPFORMULA = E_ZUPFORMULA
*    TABLES
*      TKOMV        = FT_KOMV.
  CALL FUNCTION 'ZSD_ODM_XQ_FORMULA'
    EXPORTING
      E_ZTSD0107         = E_ZTSD0107
    IMPORTING
      E_ZUPFORMULA       = E_ZUPFORMULA
    TABLES
      TKOMV        = FT_KOMV.

*P_KSCHL = 'ZZ01'
*P_KBETR = 根據ZTSD0107-WAERS決定要用那個單價欄位    "目前只有CNY單價
*P_KOEIN = ZTSD0107-WAERS
*P_KRECH = 'C'      "Calculation type for condition
*P_Kpein  = 根據ZTSD0107-WAERS決定要用那個單價定價單位欄位    "目前是CNY單價定價單位
  CHECK I_ZPCNYUP NE 0.
  CHECK I_ZPCNY_PER NE 0.
  IF E_ZCALCUR = 'USD'.
    KOMV-KSCHL = 'ZZ07'.
    IF I_ZPCUR = 'USD'.
    KOMV-KBETR = I_ZPUP.
**定價單位長度5 與預採帳7 的處理: 待定
    IF I_ZPCNY_PER > 99999.
      KOMV-KPEIN = 10000.
    ELSE.
      KOMV-KPEIN = I_ZPUP_PER.
    ENDIF.
    ENDIF.
  ELSE.
    KOMV-KSCHL = 'ZZ01'.
    KOMV-KBETR = I_ZPCNYUP.
**定價單位長度5 與預採帳7 的處理: 待定
    IF I_ZPCNY_PER > 99999.
      KOMV-KPEIN = 10000.
    ELSE.
      KOMV-KPEIN = I_ZPCNY_PER.
    ENDIF.
  ENDIF.
  KOMV-KRECH = 'C'.
  RV45A-KOEIN = 'CNY'.

* Remove any statistical or inactive conditions
  CALL FUNCTION 'PRICING_MANUAL_INPUT'
    EXPORTING
      I_KOMK  = FS_KOMK
      I_KOMP  = FS_KOMP
      I_KSCHL = KOMV-KSCHL
      I_KBETR = KOMV-KBETR
      I_WAERS = RV45A-KOEIN
      I_KRECH = KOMV-KRECH
      I_KPEIN = KOMV-KPEIN
*     I_KMEIN =
    IMPORTING
      E_KOMK  = FS_KOMK
      E_KOMP  = FS_KOMP
      E_KSCHL = KOMV-KSCHL
      E_KBETR = KOMV-KBETR
      E_WAERS = RV45A-KOEIN
    TABLES
      TKOMV   = FT_KOMV.
* EXCEPTIONS
*   FIELD_INITIAL         = 1
*   LINE_NOT_UNIQUE       = 2
*   CHECKS_FAILED         = 3
*   OTHERS                = 4
* Call the Pricing module

  E_ZCALCUR = E_ZTSD0107-ZCALCUR.
  E_ZFORMULATYPE = E_ZTSD0107-ZFORMULATYPE.
*計算最終業務單價 (到小數下6位) = 項次5.2 回傳的 fs_komp-netwr / 1000000                              "因為回傳的金額是數量1000000的總金額
  CHECK FS_KOMP-NETWR NE 0.
  WK_AMT = FS_KOMP-NETWR / WK_BASE.  "1000000
  WRITE WK_AMT TO C_AMT LEFT-JUSTIFIED NO-ZERO.
  SHIFT C_AMT RIGHT DELETING TRAILING SPACE.
  SHIFT C_AMT RIGHT DELETING TRAILING '0'.
  SHIFT C_AMT LEFT DELETING LEADING SPACE.
  SPLIT C_AMT AT '.' INTO: C_INT C_DEC.
  I_LEN = STRLEN( C_DEC ).
  E_ZUP_CUR = 'USD'.
  CASE I_LEN.
    WHEN 0 OR 1 OR 2.
      E_ZUP  = WK_AMT.
      E_ZUP_PER = 1.
    WHEN 3.
      E_ZUP  = WK_AMT * 10.
      E_ZUP_PER = 10.
    WHEN 4.
      E_ZUP  = WK_AMT * 100.
      E_ZUP_PER = 100.
    WHEN 5.
      E_ZUP  = WK_AMT * 1000.
      E_ZUP_PER = 1000.
    WHEN 6.
      E_ZUP  = WK_AMT * 10000.
      E_ZUP_PER = 10000.
  ENDCASE.
ENDFUNCTION.