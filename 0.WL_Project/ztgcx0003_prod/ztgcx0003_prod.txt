*&---------------------------------------------------------------------*
*& Report ZTGCX0003_PROD
*&---------------------------------------------------------------------*
REPORT ztgcx0003_prod MESSAGE-ID zcx01.

TABLES: ztcx0003_prod,ztcx0004.

SELECT-OPTIONS:s_idnrk FOR ztcx0003_prod-idnrk,
                s_werks FOR ztcx0003_prod-werks,
                s_erdat FOR ztcx0004-xj_erdat .

DATA:lr_idnrk TYPE RANGE OF ztcx0004-idnrk.
DATA:gt_data TYPE TABLE OF ztcx0003_prod,
     ls_data LIKE LINE OF gt_data.
DATA:gt_xj TYPE TABLE  OF ztcx0004.

TYPES:BEGIN OF ty_mat,
        werks TYPE werks_d,
        idnrk TYPE matnr,
      END OF ty_mat.

DATA:gt_mat TYPE TABLE  OF  ty_mat,
     ls_mat LIKE LINE OF gt_mat.

INITIALIZATION.

START-OF-SELECTION.
  " 移除 prod IS INITIAL 條件
  SELECT * FROM ztcx0004
    WHERE idnrk IN @s_idnrk
      AND werks IN @s_werks
      AND xj_erdat IN @s_erdat
      AND stock_qty > 0
      AND rep IS INITIAL
  INTO TABLE @gt_xj.

  " 移除 prod IS INITIAL 條件
  SELECT * FROM ztcx0001
    WHERE idnrk IN @s_idnrk
      AND werks IN @s_werks
      AND erdat IN @s_erdat
      AND moq_qty > 0
  INTO TABLE @DATA(gt_qq).

  LOOP AT gt_xj INTO DATA(ls_xj).
    ls_mat-idnrk = ls_xj-idnrk.
    ls_mat-werks = ls_xj-werks.
    COLLECT ls_mat INTO gt_mat.
    CLEAR ls_mat.
  ENDLOOP.

  LOOP AT gt_qq INTO DATA(ls_qq).
    ls_mat-idnrk = ls_qq-idnrk.
    ls_mat-werks = ls_qq-werks.
    COLLECT ls_mat INTO gt_mat.
    CLEAR ls_mat.
  ENDLOOP.

  LOOP AT gt_mat INTO DATA(ls_d) GROUP BY ( werks = ls_d-werks idnrk = ls_d-idnrk )
                                INTO DATA(lg_mat).

    lr_idnrk = VALUE #( sign = 'I' option = 'EQ' ( low = lg_mat-idnrk ) ).

    cl_salv_bs_runtime_info=>set( display  = abap_false
                                  metadata = abap_false
                                  data     = abap_true ).

    SUBMIT rcs15001m WITH s_idnrk IN lr_idnrk
                     WITH pm_werks = lg_mat-werks
                     WITH pm_mehrs = 'X' "Multilevel
      AND RETURN .

    TRY.
        cl_salv_bs_runtime_info=>get_data_ref( IMPORTING r_data = DATA(lobj_data) ).
        ASSIGN lobj_data->* TO FIELD-SYMBOL(<lfs_data>).
      CATCH cx_salv_bs_sc_runtime_info.
    ENDTRY.

    IF <lfs_data> IS ASSIGNED.
      DATA: lt_stpov_alv TYPE TABLE OF stpov_alv.
      lt_stpov_alv = CORRESPONDING #( <lfs_data> ).

      LOOP AT lt_stpov_alv INTO DATA(ls_stpov) WHERE crtfg = 'X'."最上層
        SELECT SINGLE mara~matnr,ztmara~skuitem,ztmara~wl2_brand
          FROM mara LEFT OUTER JOIN ztmara ON mara~matnr = ztmara~matnr
        WHERE mara~matnr = @ls_stpov-dobjt
          AND mara~mtart = 'ZFRT'
          AND ( mstae = 'A' OR mstae = 'E' )
        INTO @DATA(ls_mara).

        IF sy-subrc = 0.
          ls_data-werks = ls_stpov-werks.
          ls_data-matnr = ls_mara-matnr.
          ls_data-idnrk = lg_mat-idnrk.
          ls_data-skuitem = ls_mara-skuitem.
          ls_data-wl2_brand = ls_mara-wl2_brand.
          COLLECT ls_data INTO gt_data.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDLOOP.

  IF gt_data IS NOT INITIAL.
    MODIFY ztcx0003_prod FROM TABLE gt_data.
    IF sy-subrc = 0.
      COMMIT WORK.
    ENDIF.
    MESSAGE s000 WITH '更新完成'.
  ELSE.
    MESSAGE s000 WITH 'No data found'.
  ENDIF.


*Messages
*----------------------------------------------------------
*
* Message class: ZCX01
*000   &1 &2 &3 &4

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
