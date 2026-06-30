FUNCTION z_qt_comp_price_get.
*"----------------------------------------------------------------------
*"*"區域介面：
*"  IMPORTING
*"     VALUE(PRSDT) TYPE  PRSDT
*"     VALUE(SOURCE_C) TYPE  ZSOURCE_COMP OPTIONAL
*"     VALUE(PRICEFLAG) TYPE  FLAG DEFAULT 'X'
*"  EXPORTING
*"     REFERENCE(E_MSG) TYPE  STRING
*"  TABLES
*"      ET_COMP STRUCTURE  ZSQT0201COMP OPTIONAL
*"      ET_LOG STRUCTURE  ZTQT0201LOG OPTIONAL
*"      ET_LOG2 STRUCTURE  ZTQT0201LOG2 OPTIONAL
*"      ET_DATA STRUCTURE  ZSQT0201D OPTIONAL
*"      ET_LOG3 STRUCTURE  ZTQT0201LOG3 OPTIONAL
*"      ET_LOG4 STRUCTURE  ZTQT0201LOG4 OPTIONAL
*"      ET_LOG5 STRUCTURE  ZTQT0201LOG5 OPTIONAL
*"----------------------------------------------------------------------
*注意事項
*1.若新增不報價判斷邏輯時(et_comp-zero = 'X')，需同時調整 FUNCTION Z_QT_COMPPRICE_GET_MONTHLY
*"----------------------------------------------------------------------
************************************************************************
* MODIFICATION LOG
************************************************************************
* CHANGE DATE VERSION MODIFIER DESCRIPTION
* =========== ======= ======== =========================================
* 2025/10/27  V001    Fangchyi 增加傳入 I_WERKS & ET_DATA 判斷是否計算泰國運費
*                              增加傳入ET_LOG3
*                              增加PERFORM get_th_data & cal_th_data
* 2025/11/18  V002    Fangchyi 取得鐵管加工計算內容
*                              增加傳入ET_LOG4
*                              增加perform get_new_formula & cal_new_price
* 2026/05/11  V003    Fangchyi 取得工塑計算內容
*                              增加傳入ET_LOG5
*                              增加perform get_a04_formula & cal_a04_price
************************************************************************

  DATA: process_stage(100),
        pre_comp LIKE et_comp.

  CHECK et_comp[] IS NOT INITIAL.

  CHECK priceflag = 'X'.  "才往下取得價格

  SORT et_comp BY cono coseq compseq.

  process_stage = '取得計算元件單價的相關資料中...'.
  CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
    EXPORTING
      text = process_stage.

  IF gt_sql[] IS INITIAL.  "
**取得SQL上自製件工費及非BOM料號的料費
    PERFORM get_sql_data USING source_c
                         CHANGING e_msg.
    CHECK e_msg IS INITIAL.  "缺SQL資料，則不往下執行
  ENDIF.
**Get PIR
  PERFORM get_pir TABLES et_comp gt_pir
                  USING prsdt.

**取得泰國運費相關資料: ztqt0031 & pir V001 added
  PERFORM get_th_data TABLES et_data et_comp
                      USING prsdt.

**取得鐵管加工相關資料: ztqt0032  V002 added
  PERFORM get_new_formula TABLES et_data et_comp
                          USING prsdt.

**取得工塑件相關資料: V003 added
  PERFORM get_a04_formula TABLES et_data et_comp
                          USING prsdt.

**取得顏色&印花布資訊
  PERFORM get_color TABLES gt_color et_comp.

**抓ztmara
  PERFORM get_ztmara TABLES et_comp gt_ztmara.

**抓ztmarc
  PERFORM get_ztmarc TABLES et_comp gt_ztmarc.

  DATA: fix_source(1),
        l_source LIKE ztqt0201comp-source_c.
  LOOP AT et_comp ASSIGNING FIELD-SYMBOL(<fs>) WHERE idnrk IS NOT INITIAL.

    process_stage = '項次' && <fs>-coseq && '，取得元件單價中:' && <fs>-idnrk.
    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING
        text = process_stage.

*若元件類別有值，則以傳入值為準
    IF source_c = ''.
      l_source = <fs>-source_c.
    ELSE.
      l_source = source_c.
    ENDIF.
    PERFORM init_comp USING l_source
                      CHANGING <fs>
                               fix_source.

*採購成本估算單取價邏輯
    CASE <fs>-source_c.
      WHEN '1'. "自製
**自製件取得的單價放在加工費欄位
        PERFORM get_production_price TABLES et_log et_log2 et_log4 et_log5
                                     USING prsdt ''
                                     CHANGING <fs>.
      WHEN '2'  "市購
        OR '3'. "外包
*外購/外包件單價
        PERFORM get_purchase_price USING fix_source ''
                                   CHANGING <fs>.
        IF <fs>-source_c = '1'.  "自製.
**為友廠自製的市購/外包件，取自製件價格
          PERFORM get_production_price TABLES et_log et_log2 et_log4 et_log5
                                       USING prsdt 'X'
                                       CHANGING <fs>.
        ELSE.
*取得關稅/增值稅率資料
          PERFORM get_tax_data CHANGING <fs>.
        ENDIF.
      WHEN OTHERS.
    ENDCASE.

*V001 added: 計算泰國運費: 運往泰國的元件都要計算(自製&市購&外包)
    PERFORM cal_th_data TABLES et_data et_log3
                        USING prsdt
                        CHANGING <fs>.
*V001 end off
*取得元件其他欄位值&計算估算金額欄位
    PERFORM assign_comp_fields USING prsdt CHANGING <fs> pre_comp.

  ENDLOOP.

*元件是否報價邏輯處理
  CALL FUNCTION 'Z_QT_ITEMAMT_ZERO'
    EXPORTING
      prsdt   = prsdt
    TABLES
      et_comp = et_comp
      et_data = et_data.

*2025/12/15 marked : 以FUNCTION 'Z_QT_ITEMAMT_ZERO'取代
*  PERFORM assign_zero_comp TABLES et_comp.
*
**上下階是否報價邏輯處理
*  PERFORM assign_zero_bom TABLES et_comp.
*
*  LOOP AT et_comp ASSIGNING <fs>.
**取得元件其他欄位值&計算估算金額欄位
*    PERFORM assign_comp_fields USING prsdt CHANGING <fs> pre_comp.
*  ENDLOOP.
*2025/12/15 end off
ENDFUNCTION.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
