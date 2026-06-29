*&-----------------------------------------------------------------------------*
*& Report  預採帳-訂單異動與取消報庫存                                         *
*------------------------------------------------------------------------------*
* Author      : Ron Chang                                                      *
* Purpose     : 預採帳-訂單異動與取消報庫存
********************************************************************************
* MODIFICATIONS HISTORY :                                                      *
********************************************************************************
* CHANGE DATE VERSION MODIFIER DESCRIPTION
* =========== ======= ======== =================================================
* 2024/10/20  V001    Ron Chang Creation
* 2026/06/11  V002    JosephLo  修 collect_upd_data 採購(C)幣別無空白保護:p_upd重匯入幣別欄空白時保留DB既有幣別(不再洗掉採購已維護幣別)
REPORT ztgcx0003 NO STANDARD PAGE HEADING MESSAGE-ID zcx01.
INCLUDE ztgcx0003_top.
INCLUDE ztgcx0003_sub.

INITIALIZATION.
  CLEAR:gt_role,gt_upload,gt_data.
  title01 = TEXT-t01.

  sscrfields-functxt_01 = icon_export && TEXT-t02.
  sscrfields-ucomm      = 'FC01'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM file_open_dialog.

AT SELECTION-SCREEN.
  IF sy-ucomm = 'FC01'.
*  下載模版
    PERFORM frm_download_template.
  ENDIF.

AT SELECTION-SCREEN ON p_file.
  IF p_imp IS NOT INITIAL AND p_file IS INITIAL AND sy-ucomm NE 'FC01'.
    MESSAGE e001(00) WITH '請選擇上傳檔案路徑'(t03).
  ENDIF.

START-OF-SELECTION.
  "PERFORM check_auth.
  "取得人員ROLE
  SELECT * FROM ztcx0003 WHERE uname = @sy-uname INTO TABLE @gt_role.
  SELECT * FROM ztcx0008 INTO TABLE @gt_custmap.
  IF gt_role IS INITIAL AND ( p_imp IS NOT INITIAL OR p_mod IS NOT INITIAL ).
    MESSAGE e005.
  ELSE.
    IF line_exists( gt_role[ role = 'B' ] ) AND ( p_imp IS NOT INITIAL OR p_upd IS NOT INITIAL ).
      MESSAGE e006. "非生管/採購人員不能上傳，請確認
    ENDIF.
  ENDIF.
  IF p_imp IS NOT INITIAL.
    "上傳檔案
    PERFORM excel_upload.
    IF gt_upload IS NOT INITIAL.
      "檢查EXCEL內容
      PERFORM check_upload_data.
      cl_salv_bs_runtime_info=>set( display  = abap_true
                                metadata = abap_false
                                data     = abap_true ).
      LOOP AT gt_upload INTO DATA(ls_u) WHERE zmsg IS NOT INITIAL.ENDLOOP.
      IF sy-subrc = 0.
        "Show error ALV and download to local
        PERFORM show_error_alv.
      ELSE.
        "將上傳檔案內容整理到ALV上
        PERFORM prepare_data.

      ENDIF.
    ELSE.
      MESSAGE s001(00) WITH 'No data upload'.
      RETURN.
    ENDIF.
  ELSEIF p_mod IS NOT INITIAL OR p_dis IS NOT INITIAL.
    PERFORM get_data.
  ELSEIF p_upd IS NOT INITIAL.
    "上傳檔案
    PERFORM excel_upload.
    PERFORM collect_upd_data.
    PERFORM confirm_qty.
  ENDIF.

END-OF-SELECTION.


 "=== 統一補值 (不管走哪個分支，最後都補一次) ===
  LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
    DATA(ls_key1) = VALUE ty_key(
                      matnr = <ls_data>-idnrk
                      werks = <ls_data>-werks ).
    PERFORM update_alv_fields USING ls_key1 CHANGING <ls_data>.
  ENDLOOP.

  DATA ls_tmp TYPE zscx0003_alv.
  LOOP AT gt_report ASSIGNING FIELD-SYMBOL(<ls_rpt>).
    CLEAR ls_tmp.
    MOVE-CORRESPONDING <ls_rpt> TO ls_tmp.

    DATA(ls_key2) = VALUE ty_key(
                      matnr = ls_tmp-idnrk
                      werks = ls_tmp-werks ).
    PERFORM update_alv_fields USING ls_key2 CHANGING ls_tmp.

    MOVE-CORRESPONDING ls_tmp TO <ls_rpt>.
  ENDLOOP.

  "=== 顯示 ALV ===
  IF gt_data IS NOT INITIAL AND gt_report IS INITIAL.
    PERFORM display_alv USING gt_data.
    PERFORM unlock_table.
  ELSEIF gt_data IS INITIAL AND gt_report IS NOT INITIAL.
    PERFORM display_alv USING gt_report.
  ELSE.
    MESSAGE s001(00) WITH 'No data exist.'.
  ENDIF.