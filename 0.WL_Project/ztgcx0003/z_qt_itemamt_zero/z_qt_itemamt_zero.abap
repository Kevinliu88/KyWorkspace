FUNCTION z_qt_itemamt_zero.
*"----------------------------------------------------------------------
*"*"區域介面：
*"  IMPORTING
*"     VALUE(PRSDT) TYPE  PRSDT OPTIONAL
*"  TABLES
*"      ET_COMP STRUCTURE  ZSQT0201COMP OPTIONAL
*"      ET_DATA STRUCTURE  ZSQT0201D OPTIONAL
*"----------------------------------------------------------------------
* 2026/05/11  V001    Fangchyi 增加工塑件發泡不良率計算
*"----------------------------------------------------------------------
  DATA: process_stage(100),
        pre_comp LIKE et_comp.

*元件是否報價邏輯處理
  PERFORM assign_zero_comp TABLES et_comp.

*上下階是否報價邏輯處理
  PERFORM assign_zero_bom TABLES et_comp.

  LOOP AT et_comp ASSIGNING FIELD-SYMBOL(<fs>).
*取得元件其他欄位值&計算估算金額欄位
    PERFORM assign_comp_fields USING prsdt CHANGING <fs> pre_comp.

*判斷對應估算明細是否缺價格
    PERFORM assign_lack_up USING <fs>
                           CHANGING et_data-lack_up.
    IF et_data-lack_up = 'X'.
      MODIFY et_data TRANSPORTING lack_up WHERE coseq = <fs>-coseq.
    ENDIF.
  ENDLOOP.

*V001 added
*工塑件的發泡不良率需反映在下階的金額上，下階的金額 = 原下階的金額 * (1+發泡不良率)
  DATA(tmp_comp) = et_comp[].
  DELETE tmp_comp WHERE evadefectrate = 0.
  SORT tmp_comp BY coseq compseq.
  LOOP AT tmp_comp INTO DATA(w_tmp).
    LOOP AT et_comp ASSIGNING <fs> WHERE coseq = w_tmp-coseq
                                     AND compseq > w_tmp-compseq.
      IF <fs>-stufe <= w_tmp-stufe.  "非下階元件時，則跳出
        EXIT.
      ENDIF.
      CHECK <fs>-zero = ''.  "僅處理需報價項次
      <fs>-amt_c = ( <fs>-up_m + <fs>-up_p + <fs>-up_e )
                   * <fs>-menge_c.
*下階的金額 = 原下階的金額 * (1+發泡不良率)
      <fs>-amt_c = <fs>-amt_c * ( 1 + w_tmp-evadefectrate ).
      <fs>-amt_d = <fs>-amt_c * <fs>-kurrf_c.
      <fs>-tax_amt_c     = <fs>-amt_c * <fs>-taxrate.
      <fs>-tax_amt_d     = <fs>-tax_amt_c * <fs>-kurrf_c.
      <fs>-customs_amt_c = <fs>-amt_c * <fs>-customs_rate.
      <fs>-customs_amt_d = <fs>-customs_amt_c * <fs>-kurrf_c.

*不含稅時，清空稅額
      IF <fs>-taxflag_d = ''.
        CLEAR: <fs>-customs_amt_c,<fs>-customs_amt_d,
               <fs>-tax_amt_c,<fs>-tax_amt_d.
      ENDIF.
    ENDLOOP.
  ENDLOOP.
*V001 end off

*重新計算et_data各金額小計欄位
  DATA: l_amt_c LIKE ztqt0201comp-amt_c,
        l_amt   LIKE ztqt0201d-amt_m.
  LOOP AT et_data ASSIGNING FIELD-SYMBOL(<fs_data>).
    CLEAR: <fs_data>-amt, <fs_data>-customs_amt, <fs_data>-tax_amt, <fs_data>-amt_m, <fs_data>-amt_p, <fs_data>-amt_e.

    LOOP AT  et_comp ASSIGNING FIELD-SYMBOL(<fs_comp>) WHERE coseq = <fs_data>-coseq.
      IF <fs_comp>-zero = 'X'.  "不報價
        CLEAR: <fs_comp>-amt_c,<fs_comp>-amt_d,<fs_comp>-customs_amt_c,<fs_comp>-customs_amt_d,
               <fs_comp>-tax_amt_c,<fs_comp>-tax_amt_d.
      ELSE.
**重算稅額
        IF <fs_data>-taxflag_d = 'X'.
          <fs_comp>-tax_amt_c     = <fs_comp>-amt_c * <fs_comp>-taxrate.
          <fs_comp>-tax_amt_d     = <fs_comp>-tax_amt_c * <fs_comp>-kurrf_c.
          <fs_comp>-customs_amt_c = <fs_comp>-amt_c * <fs_comp>-customs_rate.
          <fs_comp>-customs_amt_d = <fs_comp>-customs_amt_c * <fs_comp>-kurrf_c.
        ELSE.
          CLEAR: <fs_comp>-customs_amt_c,<fs_comp>-customs_amt_d,
                 <fs_comp>-tax_amt_c,<fs_comp>-tax_amt_d.
        ENDIF.

        IF <fs_comp>-plmin_mcn = '-'.
          SUBTRACT <fs_comp>-amt_d FROM <fs_data>-amt.
          SUBTRACT <fs_comp>-customs_amt_d FROM <fs_data>-customs_amt.
          SUBTRACT <fs_comp>-tax_amt_d FROM <fs_data>-tax_amt.
*料、工、其他加價小計 = <fs_comp>-up_m  * <fs_comp>-menge_c = 先取得 amt_c = amt_c * <fs_comp>-kurrf
          l_amt_c = <fs_comp>-up_m * <fs_comp>-menge_c.
          l_amt = l_amt_c * <fs_comp>-kurrf_c.
          SUBTRACT l_amt FROM <fs_data>-amt_m .
          l_amt_c = <fs_comp>-up_p * <fs_comp>-menge_c.
          l_amt = l_amt_c * <fs_comp>-kurrf_c.
          SUBTRACT l_amt FROM <fs_data>-amt_p .
          l_amt_c = <fs_comp>-up_e * <fs_comp>-menge_c.
          l_amt = l_amt_c * <fs_comp>-kurrf_c.
          SUBTRACT l_amt FROM <fs_data>-amt_e .
        ELSE.
          ADD <fs_comp>-amt_d TO <fs_data>-amt .
          ADD <fs_comp>-customs_amt_d TO <fs_data>-customs_amt .
          ADD <fs_comp>-tax_amt_d TO <fs_data>-tax_amt .
*料、工、其他加價小計 = <fs_comp>-up_m * <fs_comp>-kurrf * <fs_comp>-menge_c
          l_amt_c = <fs_comp>-up_m * <fs_comp>-menge_c.
          l_amt = l_amt_c * <fs_comp>-kurrf_c.
          ADD l_amt TO <fs_data>-amt_m .
          l_amt_c = <fs_comp>-up_p * <fs_comp>-menge_c.
          l_amt = l_amt_c * <fs_comp>-kurrf_c.
          ADD l_amt TO <fs_data>-amt_p .
          l_amt_c = <fs_comp>-up_e * <fs_comp>-menge_c.
          l_amt = l_amt_c * <fs_comp>-kurrf_c.
          ADD l_amt TO <fs_data>-amt_e .
        ENDIF.
      ENDIF.
    ENDLOOP .
    IF <fs_data>-taxflag_d = ''.
      CLEAR: <fs_data>-customs_amt,<fs_data>-tax_amt.
    ENDIF.
  ENDLOOP .

ENDFUNCTION.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
