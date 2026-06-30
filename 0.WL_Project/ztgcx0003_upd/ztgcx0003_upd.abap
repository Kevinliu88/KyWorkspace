*&---------------------------------------------------------------------*
*& Report ZTGCX0003_PROD
*&---------------------------------------------------------------------*
* 2026/05/29 V002 JosephLo  P_QQ/P_XJ 分支 MODIFY 整列 → UPDATE SET 單欄, 避免洗掉 ZTCX0001/ZTCX0004 其他欄位
*&---------------------------------------------------------------------*
REPORT ztgcx0003_upd MESSAGE-ID zcx01.
TABLES: ztcx0003_prod,ztcx0004.
SELECT-OPTIONS: s_idnrk FOR ztcx0003_prod-idnrk OBLIGATORY,
                s_werks FOR ztcx0003_prod-werks,
                s_erdat FOR ztcx0004-xj_erdat DEFAULT sy-datum.
PARAMETERS: p_qq TYPE char1 RADIOBUTTON GROUP rg1,
            p_xj TYPE char1 RADIOBUTTON GROUP rg1.
DATA:gt_xj TYPE TABLE  OF ztcx0004.
DATA:gv_vtweg TYPE ztcx0004-vtweg.

INITIALIZATION.

START-OF-SELECTION.
  IF p_xj IS NOT INITIAL.
    SELECT * FROM ztcx0004
      WHERE idnrk IN @s_idnrk
        AND werks IN @s_werks
        AND xj_erdat IN @s_erdat
        AND ( rep IS INITIAL OR prod IS INITIAL )
    INTO TABLE @gt_xj.
    LOOP AT gt_xj INTO DATA(ls_d) GROUP BY ( werks = ls_d-werks idnrk = ls_d-idnrk )
                                  INTO DATA(lg_xj).
      SELECT * FROM ztcx0003_prod
        WHERE "werks = @lg_xj-werks
          idnrk = @lg_xj-idnrk
      INTO TABLE @DATA(lt_prod).
      IF sy-subrc = 0.
        LOOP AT GROUP lg_xj ASSIGNING FIELD-SYMBOL(<ls_xj>).
          IF <ls_xj>-stock_qty > 0.
*            SELECT SINGLE kunnr FROM vbak WHERE vbeln = @<ls_xj>-vbeln INTO @DATA(lv_kunnr).

            LOOP AT lt_prod INTO DATA(ls_prod) WHERE  matnr NE <ls_xj>-matnr.
*              CASE ls_prod-wl2_brand.
*                WHEN 'TAVO'. gv_vtweg = 'T1'.
*                WHEN 'GRACO'. gv_vtweg =  'G1'.
*                WHEN 'OTHER'. gv_vtweg = 'Z1'.
*                WHEN 'CHICCO'. gv_vtweg =  'C1'.
*                WHEN 'JOIE'. gv_vtweg =  'J1'.
*                WHEN 'NUNA'. gv_vtweg = 'N1'.
*              ENDCASE.
              SELECT * FROM ztsd0020
                WHERE zcn = @ls_prod-skuitem
                  AND matnr = @ls_prod-matnr
              INTO TABLE @DATA(lt_sd020).
              IF line_exists( lt_sd020[ vtweg = <ls_xj>-vtweg ] ).
*              CHECK gv_vtweg = <ls_xj>-vtweg.
                CHECK <ls_xj>-prod NS ls_prod-skuitem.
*              SELECT * FROM ztsd0020
*                WHERE zcn = @ls_prod-skuitem
*              INTO TABLE @DATA(lt_sd020).
*              IF line_exists( lt_sd020[ kunnr = lv_kunnr ] ).
                IF <ls_xj>-prod IS INITIAL.
                  <ls_xj>-prod = ls_prod-skuitem.
                ELSE.
                  CONCATENATE <ls_xj>-prod ls_prod-skuitem INTO <ls_xj>-prod SEPARATED BY ';'.
                ENDIF.
                <ls_xj>-rep = 'Y'.
              ENDIF.
            ENDLOOP.
            IF <ls_xj>-rep NE 'Y'.
              <ls_xj>-rep = 'N'.
            ENDIF.
          ELSE.
            <ls_xj>-rep = ''.
            <ls_xj>-prod = ''.
          ENDIF.
        ENDLOOP.
      ELSE.

      ENDIF.

    ENDLOOP.
* v002 Added by JosephLo 20260529 *
* 同 1A 原則: MODIFY 整列 → UPDATE SET 單欄, 避免洗掉 ZTCX0004 其他欄位。
*   WHERE 用 SELECT 同樣 4 個條件 (idnrk / werks / xj_erdat / rep|prod 仍空) 鎖定本筆,
*   兼作樂觀鎖: 若本批處理期間別人已填過 rep/prod, 本程式不再覆蓋。
    IF gt_xj IS NOT INITIAL.
      DATA lv_xj_cnt TYPE i.
      LOOP AT gt_xj ASSIGNING FIELD-SYMBOL(<fs_xj_upd>).
        UPDATE ztcx0004
           SET rep  = @<fs_xj_upd>-rep,
               prod = @<fs_xj_upd>-prod
         WHERE idnrk    = @<fs_xj_upd>-idnrk
           AND werks    = @<fs_xj_upd>-werks
           AND xj_erdat = @<fs_xj_upd>-xj_erdat
           AND ( rep IS INITIAL OR prod IS INITIAL ).
        IF sy-subrc = 0.
          lv_xj_cnt = lv_xj_cnt + 1.
        ENDIF.
      ENDLOOP.
      COMMIT WORK.
      MESSAGE s000 WITH |更新完成 { lv_xj_cnt } 筆|.
    ELSE.
      MESSAGE s000 WITH 'No data found'.
    ENDIF.
* v002 End off *

  else.

    SELECT * FROM ztcx0001
        WHERE idnrk IN @s_idnrk
          AND werks IN @s_werks
          AND erdat IN @s_erdat
          AND prod IS INITIAL
    INTO TABLE @DATA(gt_qq).
    LOOP AT gt_qq INTO DATA(ls_d1) GROUP BY ( werks = ls_d1-werks idnrk = ls_d1-idnrk )
                                  INTO DATA(lg_qq).
      SELECT * FROM ztcx0003_prod
        WHERE  idnrk = @lg_qq-idnrk
      INTO TABLE @lt_prod.
      IF sy-subrc = 0.
        LOOP AT GROUP lg_qq ASSIGNING FIELD-SYMBOL(<ls_qq>).

          LOOP AT lt_prod INTO ls_prod WHERE  matnr NE <ls_qq>-matnr.
*            CASE ls_prod-wl2_brand.
*              WHEN 'TAVO'. gv_vtweg = 'T1'.
*              WHEN 'GRACO'. gv_vtweg =  'G1'.
*              WHEN 'OTHER'. gv_vtweg = 'Z1'.
*              WHEN 'CHICCO'. gv_vtweg =  'C1'.
*              WHEN 'JOIE'. gv_vtweg =  'J1'.
*              WHEN 'NUNA'. gv_vtweg = 'N1'.
*            ENDCASE.
*            CHECK gv_vtweg = <ls_qq>-vtweg.
            SELECT * FROM ztsd0020
              WHERE zcn = @ls_prod-skuitem
                AND matnr = @ls_prod-matnr
            INTO TABLE @lt_sd020.
            IF line_exists( lt_sd020[ vtweg = <ls_qq>-vtweg ] ).
              CHECK <ls_qq>-prod NS ls_prod-skuitem.
              IF <ls_qq>-prod IS INITIAL.
                <ls_qq>-prod = ls_prod-skuitem.
              ELSE.
                CONCATENATE <ls_qq>-prod ls_prod-skuitem INTO <ls_qq>-prod SEPARATED BY ';'.
              ENDIF.
            ENDIF.
          ENDLOOP.
        ENDLOOP.
      ENDIF.
    ENDLOOP.
* v002 Added by JosephLo 20260529 *
* 改 MODIFY 整列 → UPDATE SET 單欄, 避免 race condition 洗掉 ZTCX0001 其他欄位
*   (qq/qq_seq/moq_qty/moq_remain/moq_7day_req 等)。
*   起因: 5/27 Alma case, BTCUSER 跑本程式 11:49:30 對 222 筆 ZTCX0001 做 UPDATE,
*         race window 內 ZTGCX0001 CONFIRM 寫入的欄位被整列覆蓋洗掉。
*   chdat/chtim/chnam 順便寫入, 之後 SE16 看「chnam=BTCUSER」即可定位本程式改的。
    IF gt_qq IS NOT INITIAL.
      DATA lv_qq_cnt TYPE i.
      LOOP AT gt_qq ASSIGNING FIELD-SYMBOL(<fs_qq_upd>).
        UPDATE ztcx0001
           SET prod  = @<fs_qq_upd>-prod,
               chdat = @sy-datum,
               chtim = @sy-uzeit,
               chnam = @sy-uname
         WHERE werks     = @<fs_qq_upd>-werks
           AND vtweg     = @<fs_qq_upd>-vtweg
           AND zseq      = @<fs_qq_upd>-zseq
           AND zportalno = @<fs_qq_upd>-zportalno
           AND idnrk     = @<fs_qq_upd>-idnrk.
        IF sy-subrc = 0.
          lv_qq_cnt = lv_qq_cnt + 1.
        ENDIF.
      ENDLOOP.
      COMMIT WORK.
      MESSAGE s000 WITH |更新完成 { lv_qq_cnt } 筆|.
    ELSE.
      MESSAGE s000 WITH 'No data found'.
    ENDIF.
* v002 End off *
  ENDIF.


*Messages
*----------------------------------------------------------
*
* Message class: ZCX01
*000   &1 &2 &3 &4

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
