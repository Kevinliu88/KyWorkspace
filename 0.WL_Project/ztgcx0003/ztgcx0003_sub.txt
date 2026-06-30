*----------------------------------------------------------------------*
***INCLUDE ZTGCX0003_SUB.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form file_open_dialog
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM file_open_dialog .
  "FILE_OPEN_DIALOG
  DATA:
    lt_filetable    TYPE   filetable,
    ls_filetable    TYPE   file_table,
    lv_rc           TYPE   sy-subrc,
    lv_filename     TYPE   string,
    lv_initial_path TYPE   string.

  CLEAR lv_filename.
  lv_filename = p_file.
  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      default_filename        = lv_filename
*     INITIAL_DIRECTORY       = LV_INITIAL_PATH
      file_filter             = 'Excel 文件 (*.XLS;*.XLSX;*.XLSM)|*.XLS;*.XLSX;*.XLSM|所有文件 (*.*)|*.*|' ##NO_TEXT
    CHANGING
      file_table              = lt_filetable
      rc                      = lv_rc
    EXCEPTIONS
      file_open_dialog_failed = 1
      cntl_error              = 2
      error_no_gui            = 3
      not_supported_by_gui    = 4.

  IF sy-subrc NE 0 OR lv_rc LT 0.
    MESSAGE e001(00) WITH TEXT-m01.
  ELSE.
    IF lv_rc = 1.
      READ TABLE lt_filetable INTO ls_filetable INDEX 1.
      p_file = ls_filetable-filename.
    ELSE.
      EXIT.
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form frm_download_template
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM frm_download_template .
  DATA: lv_objdata  TYPE wwwdatatab,
        lv_obj_name TYPE wwwdatatab-objid,
        lv_file     TYPE rlgrap-filename,
        lv_subrc    TYPE sy-subrc.
  DATA:lv_fpath  TYPE string,
       lv_fname  TYPE string,
       lv_path   TYPE string,
       lv_title  TYPE string,
       lv_action TYPE i.
  FIELD-SYMBOLS <fs_file> TYPE any.

  MOVE 'ZTGCX0003' TO lv_obj_name.
  ASSIGN p_file TO <fs_file>.


  SELECT SINGLE relid objid
    FROM wwwdata
    INTO CORRESPONDING FIELDS OF lv_objdata
   WHERE srtf2 = 0
  AND relid = 'MI'
  AND objid = lv_obj_name.
  IF sy-subrc <> 0.
    MESSAGE TEXT-e01 TYPE 'E'.
  ENDIF.


  CALL METHOD cl_gui_frontend_services=>file_save_dialog
    EXPORTING
      window_title              = lv_title
      default_extension         = 'xlsx'
*     default_file_name         =
*     with_encoding             =
      file_filter               = '*.XLSX;*.XLS'
*     initial_directory         =
*     prompt_on_overwrite       = 'X'
    CHANGING
      filename                  = lv_fname
      path                      = lv_path
      fullpath                  = lv_fpath
      user_action               = lv_action
*     file_encoding             =
    EXCEPTIONS
      cntl_error                = 1
      error_no_gui              = 2
      not_supported_by_gui      = 3
      invalid_default_file_name = 4
      OTHERS                    = 5.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ELSEIF sy-subrc = 0 AND lv_action NE 0.
    RETURN.
  ENDIF.
  lv_file = lv_fpath.

  CALL FUNCTION 'DOWNLOAD_WEB_OBJECT'
    EXPORTING
      key         = lv_objdata
      destination = lv_file
    IMPORTING
      rc          = lv_subrc.
  IF lv_subrc = 0.
    <fs_file> = lv_file.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form excel_upload
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM excel_upload .
  DATA:lv_filename TYPE rlgrap-filename.
  CONSTANTS: c_begcol TYPE i VALUE 1,
             c_begrow TYPE i VALUE 1,
             c_endcol TYPE i VALUE 30,
             c_endrow TYPE i VALUE 65000.
  DATA: BEGIN OF i_intern OCCURS 0.
          INCLUDE STRUCTURE  alsmex_tabline.
  DATA:  END OF i_intern.
  DATA:lv_index TYPE sy-index.
  IF p_imp IS NOT INITIAL.
    REFRESH i_intern.
    lv_filename = p_file.
    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = lv_filename
        i_begin_col             = c_begcol
        i_begin_row             = c_begrow
        i_end_col               = c_endcol
        i_end_row               = c_endrow
      TABLES
        intern                  = i_intern
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.

    IF sy-subrc <> 0.
      WRITE:/ 'Upload Error ', sy-subrc.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS : <fs>.
    DATA  exception TYPE REF TO cx_root.
    SORT i_intern BY row col.
    DATA:ls_upload LIKE LINE OF gt_upload,
         ls_data   LIKE LINE OF gt_report.
    TRY.
        LOOP AT i_intern WHERE row > 2.
          MOVE i_intern-col TO lv_index.
          ASSIGN COMPONENT lv_index OF STRUCTURE ls_upload TO <fs>.
          IF i_intern-col = 5.
            REPLACE ALL OCCURRENCES OF '/' IN i_intern-value WITH space.
          ENDIF.
          MOVE i_intern-value TO <fs>.
          AT END OF row.
            ls_upload-posnr = |{ ls_upload-posnr ALPHA = IN }|.
            APPEND ls_upload TO gt_upload.
            CLEAR ls_upload.
          ENDAT.
        ENDLOOP.
      CATCH cx_root INTO exception.
        MESSAGE 'Excel data format is wrong,please check' TYPE 'E'.
    ENDTRY.
  ELSEIF p_upd IS NOT INITIAL.
    DATA:lt_intern TYPE TABLE OF zscx_tab.
    DATA:lv_upd_fname TYPE rlgrap-filename.
    lv_upd_fname = p_file.
    DATA:lt_utmp TYPE TABLE OF zscx0004_upd,
         ls_utmp LIKE LINE OF lt_utmp.
*    CALL METHOD z_cx_upload_xslx=>import_document_from_frontend
*      EXPORTING
*        i_filename      = p_file
**       i_sheetname     =
*        i_start_row     = 2
**       i_check_structure =
**      IMPORTING
**       e_error_text    =
*      CHANGING
*        t_tab           = lt_utmp
*      EXCEPTIONS
*        file_open_error = 1
*        OTHERS          = 2.
*    IF sy-subrc <> 0.
**     Implement suitable error handling here
*    ENDIF.
*    LOOP AT lt_utmp INTO DATA(ls_tmp).
*      APPEND INITIAL LINE TO gt_report ASSIGNING FIELD-SYMBOL(<ls_report>).
*      "MOVE-CORRESPONDING ls_tmp TO <ls_report>.'
*      <ls_report>-werks = ls_tmp-werks.
*      <ls_report>-idnrk = ls_tmp-idnrk.
*      <ls_report>-stock_qty = ls_tmp-stock_qty.
*      <ls_report>-pp_remark = ls_tmp-pp_remark.
*      <ls_report>-pur_remark = ls_tmp-pur_remark.
*      <ls_report>-netpr = ls_tmp-netpr.
*      "<ls_report>-kunnr = |{ <ls_report>-kunnr ALPHA = IN }|.
*    ENDLOOP.
    REFRESH i_intern.
    lv_filename = p_file.
    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = lv_filename
        i_begin_col             = c_begcol
        i_begin_row             = c_begrow
        i_end_col               = 100
        i_end_row               = c_endrow
      TABLES
        intern                  = i_intern
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.

    IF sy-subrc <> 0.
      WRITE:/ 'Upload Error ', sy-subrc.
      RETURN.
    ENDIF.

    SORT i_intern BY row col.


    LOOP AT i_intern WHERE row > 1.
      TRY.
          MOVE i_intern-col TO lv_index.
          ASSIGN COMPONENT lv_index OF STRUCTURE ls_utmp TO <fs>.
          REPLACE ALL OCCURRENCES OF ',' IN i_intern-value WITH space.
          MOVE i_intern-value TO <fs>.
        CATCH cx_root INTO exception.
          <fs> = ''.
      ENDTRY.
      AT END OF row.
        APPEND ls_utmp TO lt_utmp.
        CLEAR ls_utmp.
      ENDAT.

    ENDLOOP.

    LOOP AT lt_utmp INTO DATA(ls_tmp).
      APPEND INITIAL LINE TO gt_report ASSIGNING FIELD-SYMBOL(<ls_report>).
      <ls_report>-xj = ls_tmp-xj.
      <ls_report>-xj_item = ls_tmp-xj_item.
      <ls_report>-vbeln = ls_tmp-vbeln.
      <ls_report>-posnr = ls_tmp-posnr.
      <ls_report>-matnr = ls_tmp-matnr.
      <ls_report>-skuitem = ls_tmp-skuitem.
      <ls_report>-maktx = ls_tmp-maktx.
      <ls_report>-beskz = ls_tmp-beskz.
      <ls_report>-werks = ls_tmp-werks.
      <ls_report>-idnrk = ls_tmp-idnrk.
      <ls_report>-meins = ls_tmp-meins.
      <ls_report>-kunnr = ls_tmp-kunnr.
      <ls_report>-vtweg = ls_tmp-vtweg.
      <ls_report>-zseq = ls_tmp-zseq.
      <ls_report>-kwmeng = ls_tmp-kwmeng.
      <ls_report>-vrkme = ls_tmp-vrkme.
      <ls_report>-canc_qty = ls_tmp-canc_qty.
      <ls_report>-stock_qty = ls_tmp-stock_qty.
      <ls_report>-pp_remark = ls_tmp-pp_remark.
      <ls_report>-pur_remark = ls_tmp-pur_remark.
      <ls_report>-netpr = ls_tmp-netpr.
      <ls_report>-waers = ls_tmp-waers.
    ENDLOOP.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form check_upload_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM check_upload_data .
  LOOP AT gt_upload ASSIGNING FIELD-SYMBOL(<ls_upload>).
    "<ls_upload>-kunnr = |{ <ls_upload>-kunnr ALPHA = IN }|.
    "<ls_upload>-idnrk = |{ <ls_upload>-idnrk ALPHA = IN }|.
    <ls_upload>-vbeln = |{ <ls_upload>-vbeln ALPHA = IN CASE = UPPER }|.
    <ls_upload>-posnr = |{ <ls_upload>-posnr ALPHA = IN }|.
    "<ls_upload>-matnr = |{ <ls_upload>-matnr ALPHA = IN }|.
    REPLACE ALL OCCURRENCES OF ',' IN <ls_upload>-menge WITH space.

    SELECT SINGLE * FROM vbap WHERE vbeln = @<ls_upload>-vbeln AND posnr = @<ls_upload>-posnr INTO @DATA(ls_vbap).
    IF sy-subrc NE 0.
      <ls_upload>-zmsg = '訂單+訂單項次不存在'(m02).
      CONTINUE.
    ENDIF.
    "若在上傳相同的訂單時，必須上一張XJ被結案(狀態為E: XJ單確認或F: XJ單保留)才能允許成立下一張XJ單
    SELECT * FROM ztcx0004
      WHERE vbeln = @<ls_upload>-vbeln
        AND posnr = @<ls_upload>-posnr
      ORDER BY xj_erdat DESCENDING ,xj_ertim DESCENDING
      INTO @DATA(ls_003).
      EXIT.
    ENDSELECT.
    IF ls_003 IS NOT INITIAL.
      IF ls_003-xj_status = 'E' OR ls_003-xj_status = 'F'.

      ELSE.
        <ls_upload>-zmsg = '上傳相同的訂單時，必須上一張XJ被結案(狀態為E: XJ單確認或F: XJ單保留)才能允許成立下一張XJ單'.
        CONTINUE.
      ENDIF.
    ELSE.

    ENDIF.
*    SELECT SINGLE * FROM vbak WHERE vbeln = @<ls_upload>-vbeln AND auart LIKE 'ZPP%' INTO @DATA(ls_vbak).
*    IF sy-subrc = 0.
*      <ls_upload>-zmsg = '訂單類型ZPP*不允許建立XJ單'(m04).
*      CONTINUE.
*    ENDIF.
*    SELECT SINGLE * FROM TVTW WHERE vtweg = @<ls_upload>-kunnr INTO @DATA(ls_tvtw).
*    IF sy-subrc NE 0.
*      <ls_upload>-zmsg = '預採帳客戶別不存在'(m03).
*      CONTINUE.
*    ENDIF.
*    SELECT SINGLE * FROM marc WHERE matnr = @<ls_upload>-matnr AND werks = @<ls_upload>-werks INTO @DATA(ls_marc).
*    IF sy-subrc NE 0.
*      <ls_upload>-zmsg = '訂單件號不存在料號主檔'(m04).
*      CONTINUE.
*    ENDIF.
*    SELECT SINGLE * FROM marc WHERE matnr = @<ls_upload>-idnrk AND werks = @<ls_upload>-werks INTO @ls_marc.
*    IF sy-subrc NE 0.
*      <ls_upload>-zmsg = '材料不存在料號主檔'(m05).
*      CONTINUE.
*    ENDIF.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_error_alv
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_error_alv .
  DATA:lt_fieldcat TYPE lvc_t_fcat.
  DATA:ls_fcat   TYPE lvc_s_fcat,
       lv_layout TYPE lvc_s_layo.
  FIELD-SYMBOLS:<fs_fcat> TYPE lvc_s_fcat,
                <fs_val>  TYPE any.
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
*     I_BUFFER_ACTIVE        = I_BUFFER_ACTIVE
      i_structure_name       = 'ZSCX0003_UPLOAD'
*     I_CLIENT_NEVER_DISPLAY = 'X'
*     I_BYPASSING_BUFFER     = I_BYPASSING_BUFFER
*     I_INTERNAL_TABNAME     = I_INTERNAL_TABNAME
    CHANGING
      ct_fieldcat            = lt_fieldcat
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2.
  LOOP AT lt_fieldcat ASSIGNING FIELD-SYMBOL(<ls_fcat>).
    CASE <ls_fcat>-fieldname.
      WHEN 'MENGE'.
        <ls_fcat>-reptext = <ls_fcat>-scrtext_s = <ls_fcat>-scrtext_m = <ls_fcat>-scrtext_l = '訂單異動數量'(f01).
      WHEN 'MATNR'.
        <ls_fcat>-reptext = <ls_fcat>-scrtext_s = <ls_fcat>-scrtext_m = <ls_fcat>-scrtext_l = '訂單件號'(f02).
    ENDCASE.
  ENDLOOP.
  lv_layout-cwidth_opt = 'X'.
  lv_layout-zebra = 'X'.
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
*     I_INTERFACE_CHECK  = ' '
      i_bypassing_buffer = 'X'
*     I_BUFFER_ACTIVE    =
      i_callback_program = sy-repid
*     I_CALLBACK_PF_STATUS_SET          = ' '
*     I_CALLBACK_USER_COMMAND           = ' '
*     I_CALLBACK_TOP_OF_PAGE            = ' '
*     I_CALLBACK_HTML_TOP_OF_PAGE       = ' '
*     I_CALLBACK_HTML_END_OF_LIST       = ' '
*     I_STRUCTURE_NAME   =
*     I_BACKGROUND_ID    = ' '
*     I_GRID_TITLE       =
*     I_GRID_SETTINGS    =
      is_layout_lvc      = lv_layout
      it_fieldcat_lvc    = lt_fieldcat
*     IT_EXCLUDING       =
*     IT_SPECIAL_GROUPS_LVC             =
*     IT_SORT_LVC        =
*     IT_FILTER_LVC      =
*     IT_HYPERLINK       =
*     IS_SEL_HIDE        =
*     I_DEFAULT          = 'X'
      i_save             = 'A'
*     IS_VARIANT         =
*     IT_EVENTS          =
*     IT_EVENT_EXIT      =
*     IS_PRINT_LVC       =
*     IS_REPREP_ID_LVC   =
*     I_SCREEN_START_COLUMN             = 0
*     I_SCREEN_START_LINE               = 0
*     I_SCREEN_END_COLUMN               = 0
*     I_SCREEN_END_LINE  = 0
*     I_HTML_HEIGHT_TOP  =
*     I_HTML_HEIGHT_END  =
*     IT_ALV_GRAPHICS    =
*     IT_EXCEPT_QINFO_LVC               =
*     IR_SALV_FULLSCREEN_ADAPTER        =
*   IMPORTING
*     E_EXIT_CAUSED_BY_CALLER           =
*     ES_EXIT_CAUSED_BY_USER            =
    TABLES
      t_outtab           = gt_upload
    EXCEPTIONS
      program_error      = 1
      OTHERS             = 2.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_alv
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> GT_DATA
*&---------------------------------------------------------------------*
FORM display_alv USING  p_alv TYPE STANDARD TABLE.
  DATA:lt_fcat    TYPE lvc_t_fcat,
       ls_layout  TYPE lvc_s_layo,
       lt_events  TYPE slis_t_event,
       lt_exclude TYPE slis_t_extab.

  PERFORM frm_set_layout   CHANGING ls_layout.
  PERFORM frm_set_fieldcat CHANGING lt_fcat.
  PERFORM frm_set_events   CHANGING lt_events.
  PERFORM frm_alv_display  CHANGING lt_fcat
                                    ls_layout
                                    lt_exclude
                                    lt_events
                                    p_alv.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form frm_set_layout
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- LS_LAYOUT
*&---------------------------------------------------------------------*
FORM frm_set_layout  CHANGING cs_layout TYPE lvc_s_layo.

  cs_layout-cwidth_opt  = 'X'.
  cs_layout-sel_mode    = 'A'.
  cs_layout-zebra       = 'X'.
  cs_layout-stylefname = 'CELLSTYLES'.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form frm_set_fieldcat
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- LT_FCAT
*&---------------------------------------------------------------------*
FORM frm_set_fieldcat  CHANGING ct_fcat TYPE lvc_t_fcat.

  DATA:ls_fcat  TYPE lvc_s_fcat,
       lv_struc TYPE dd02l-tabname.
  FIELD-SYMBOLS:<fs_fcat> TYPE lvc_s_fcat,
                <fs_val>  TYPE any.

  CLEAR:ct_fcat.

  DEFINE m_fcat.
    ls_fcat-fieldname = &1.
    ls_fcat-coltext   = &2.
    ls_fcat-scrtext_l = &2.
    ls_fcat-scrtext_m = &2.
    ls_fcat-scrtext_s = &2.
    ls_fcat-outputlen = &3.
    ls_fcat-col_pos = &4.
    ls_fcat-ref_field = &5.
    ls_fcat-ref_table = &6.
    APPEND ls_fcat TO ct_fcat.
  END-OF-DEFINITION.

  DEFINE m_set_fcat.
    READ TABLE ct_fcat ASSIGNING <fs_fcat> WITH KEY fieldname = &1.
    IF sy-subrc EQ 0.
      ASSIGN COMPONENT &2 OF STRUCTURE <fs_fcat> TO <fs_val>.
      IF sy-subrc EQ 0.
        <fs_val> = &3.
      ENDIF.
    ENDIF.
  END-OF-DEFINITION.
  DEFINE set_field_text.
    <lfs_fcat>-reptext = <lfs_fcat>-scrtext_s = <lfs_fcat>-scrtext_m = <lfs_fcat>-scrtext_l = &1.
  END-OF-DEFINITION.
  IF p_imp IS NOT INITIAL OR p_mod IS NOT INITIAL OR p_upd IS NOT INITIAL.
    lv_struc = 'ZSCX0003_ALV'.
  ELSEIF p_dis IS NOT INITIAL.
    lv_struc = 'ZTCX0004'.
  ENDIF.
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
*     I_BUFFER_ACTIVE        = I_BUFFER_ACTIVE
      i_structure_name       = lv_struc
*     I_CLIENT_NEVER_DISPLAY = 'X'
*     I_BYPASSING_BUFFER     = I_BYPASSING_BUFFER
*     I_INTERNAL_TABNAME     = I_INTERNAL_TABNAME
    CHANGING
      ct_fieldcat            = ct_fcat
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2.
  "訂單表頭展開廠:與既有 WERKS(子件廠)區隔欄名
  READ TABLE ct_fcat ASSIGNING <fs_fcat> WITH KEY fieldname = 'WERKS_SO'.
  IF sy-subrc = 0.
    <fs_fcat>-coltext = <fs_fcat>-scrtext_l = <fs_fcat>-scrtext_m = <fs_fcat>-scrtext_s = <fs_fcat>-reptext = '訂單展開廠'.
  ENDIF.
  READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
  LOOP AT ct_fcat ASSIGNING FIELD-SYMBOL(<lfs_fcat>).
*20260518 Rogney 無論在任何情況下，
*                              採購關卡不可顯示業務單價
*                         　生管關卡不可顯示所有單價幣別．生管確認時卡控
    CASE ls_role-role.
      WHEN 'A'. "生管
        CASE <lfs_fcat>-fieldname.
          WHEN 'NETPR' OR 'CUST_AMT' OR 'SALES_WAERS' OR 'SALES_NETPR' OR 'SALES_NETPR_6'
              OR 'SALES_AMT' OR 'NETPR_CNY' OR 'WAERS_CNY' OR 'NETPR_TWD' OR 'WAERS_TWD'.
            <lfs_fcat>-tech = 'X'.
        ENDCASE.
      WHEN 'C'."採購
        CASE <lfs_fcat>-fieldname.
          WHEN 'SALES_WAERS' OR 'SALES_NETPR' OR  'SALES_AMT' OR 'SALES_NETPR_6'.
            <lfs_fcat>-tech = 'X'.
        ENDCASE.
    ENDCASE.


    IF p_imp IS NOT INITIAL.
      IF ls_role-role = 'A'.
        CASE <lfs_fcat>-fieldname.
          WHEN 'STOCK_QTY' OR 'PP_REMARK'.
            <lfs_fcat>-edit = 'X'.
          WHEN 'NETPR' OR 'CUST_AMT'.
            <lfs_fcat>-tech = 'X'.
          WHEN OTHERS.
        ENDCASE.
      ENDIF.
*20260428 Rogney 排除掉查詢模式有欄位可編輯的情境，查詢就只能查詢
*    ELSEIF p_mod IS NOT INITIAL OR p_dis IS NOT INITIAL OR p_upd IS NOT INITIAL.
    ELSEIF p_mod IS NOT INITIAL OR p_upd IS NOT INITIAL.
      CASE ls_role-role.



        WHEN 'A'. "生管
          CASE <lfs_fcat>-fieldname.
            WHEN 'STOCK_QTY' OR 'PP_REMARK'.
              <lfs_fcat>-edit = 'X'.
            WHEN 'NETPR' OR 'CUST_AMT' OR 'SALES_WAERS' OR 'SALES_NETPR' OR 'SALES_NETPR_6'
                OR 'SALES_AMT' OR 'NETPR_CNY' OR 'WAERS_CNY' OR 'NETPR_TWD' OR 'WAERS_TWD'.
              <lfs_fcat>-tech = 'X'.
          ENDCASE.
        WHEN 'C'."採購
          CASE <lfs_fcat>-fieldname.
            WHEN 'NETPR' OR 'WAERS' OR 'PUR_REMARK' OR 'STOCK_QTY'.
              <lfs_fcat>-edit = 'X'.
            WHEN 'SALES_WAERS' OR 'SALES_NETPR' OR  'SALES_AMT'.
              <lfs_fcat>-tech = 'X'.
          ENDCASE.
        WHEN 'B'."業務
          CASE <lfs_fcat>-fieldname.
            WHEN 'CUST_QTY' OR 'CUST_AMT' OR 'CUST_DATE' OR 'SA_REMARK'.
              IF p_mod IS NOT INITIAL.
                <lfs_fcat>-edit = 'X'.
              ENDIF.

          ENDCASE.

      ENDCASE.
    ENDIF.
    CASE <lfs_fcat>-fieldname.
      WHEN 'MANDT'.
        <lfs_fcat>-tech = 'X'.
      WHEN 'ICON'.
        <lfs_fcat>-icon = 'X'.
        <lfs_fcat>-outputlen = '4'.
      WHEN 'SEL'.
        IF p_mod IS NOT INITIAL OR p_upd IS NOT INITIAL.
          <lfs_fcat>-outputlen = '2'.
          <lfs_fcat>-edit = 'X'.
          <lfs_fcat>-checkbox = 'X'.
          set_field_text '勾選框'(f03).
        ELSEIF p_imp IS NOT INITIAL.
          <lfs_fcat>-tech = 'X'.
        ENDIF.
      WHEN 'IDNRK'.
        set_field_text '材料'(f04).
      WHEN 'LABST'.
        set_field_text '庫存數量'(f05).
      WHEN 'ZTRANS_QTY'.
        set_field_text '理論存量'(f10).
      WHEN 'BSTMI'.
        set_field_text '最小訂購量'(f11).
      WHEN 'BSTRF'.
        set_field_text '倍數'(f12).
      WHEN 'BEBST'.
        set_field_text '採購量'(f13).
      WHEN 'BANFB'.
        set_field_text '請購量'(f14).
      WHEN 'SUB_QTY'.
      WHEN 'ZEX_HIER'.
        set_field_text '展開階層'(f15).
      WHEN 'DEL12'.
        set_field_text '源頭單據號碼'(f16).
      WHEN 'DELNR'.
        set_field_text '展開單據號碼'(f17).
      WHEN 'MSG'.
        IF p_dis IS NOT INITIAL.
          <lfs_fcat>-tech = 'X'.
        ELSE.
          set_field_text '錯誤訊息'(f09).
        ENDIF.
      WHEN 'NETPR_CNY'.
        set_field_text '料價(CNY)'(f18).
      WHEN 'NETPR_TWD'.
        set_field_text '料價(TWD)'(f19).

      WHEN OTHERS.
    ENDCASE.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form frm_set_events
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- LT_EVENTS
*&---------------------------------------------------------------------*
FORM frm_set_events CHANGING ct_events TYPE slis_t_event.

  CLEAR:ct_events.

  ct_events  = VALUE #( ( name = 'CALLER_EXIT'
                          form = 'FRM_REGISTER_EVENTS' ) ).
ENDFORM.
FORM frm_register_events USING is_caller TYPE slis_data_caller_exit.

  DATA:lo_grid TYPE REF TO cl_gui_alv_grid.
  DATA:lt_f4   TYPE lvc_t_f4.
  DATA:ls_f4   TYPE lvc_s_f4.

  CALL FUNCTION 'GET_GLOBALS_FROM_SLVC_FULLSCR'
    IMPORTING
      e_grid = lo_grid.

  IF lo_grid IS NOT INITIAL.
*    ls_f4-fieldname  = 'VERID'.   "窗口时间参数（需要定义F4帮助按钮的字段）
*    ls_f4-register   = 'X'.
*    ls_f4-getbefore  = 'X'.
*    ls_f4-chngeafter = 'X'.
*    INSERT ls_f4 INTO TABLE lt_f4.
*    ls_f4-fieldname  = 'LIFNR'.   "窗口时间参数（需要定义F4帮助按钮的字段）
*    ls_f4-register   = 'X'.
*    ls_f4-getbefore  = 'X'.
*    ls_f4-chngeafter = 'X'.
*    INSERT ls_f4 INTO TABLE lt_f4.


*    lo_grid->register_edit_event( cl_gui_alv_grid=>mc_evt_enter ).
*    lo_grid->register_edit_event( cl_gui_alv_grid=>mc_evt_modified ).
*    "lo_grid->register_f4_for_fields( lt_f4[] ).
*
*    " 单元格编辑
*    CREATE OBJECT gt_event_receiver.
*    "SET HANDLER   gt_event_receiver->handle_f4     FOR lo_grid.
*    SET HANDLER gt_event_receiver->handle_double_click FOR lo_grid.
*    SET HANDLER   gt_event_receiver->handle_change FOR lo_grid.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form frm_alv_display
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- LT_FCAT
*&      <-- LS_LAYOUT
*&      <-- LT_EXCLUDE
*&      <-- LT_EVENTS
*&      <-- P_ALV
*&---------------------------------------------------------------------*
FORM frm_alv_display CHANGING ct_fcat    TYPE lvc_t_fcat
                              cs_layout  TYPE lvc_s_layo
                              ct_exclude TYPE slis_t_extab
                              ct_events  TYPE slis_t_event
                              ct_tab     TYPE STANDARD TABLE.
  DATA:is_variant TYPE  disvariant.
  is_variant-handle = 'A100'.
  cl_salv_bs_runtime_info=>set( display  = abap_true
                                metadata = abap_true
                                data     = abap_true ).
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
      i_callback_program       = sy-repid
      i_bypassing_buffer       = abap_true
      i_callback_pf_status_set = 'FRM_STATUS_SET'
      i_callback_user_command  = 'FRM_USER_COMMAND'
      "i_callback_top_of_page = 'TOP_OF_PAGE'
      is_layout_lvc            = cs_layout
      it_fieldcat_lvc          = ct_fcat
      it_excluding             = ct_exclude
      it_events                = ct_events
      i_default                = 'X'
      i_save                   = 'A'
      is_variant               = is_variant
      "i_grid_title             = gv_grid_title
    TABLES
      t_outtab                 = ct_tab
    EXCEPTIONS
      OTHERS                   = 0.

ENDFORM.
FORM frm_status_set USING it_extab TYPE slis_t_extab.       "#EC CALLED
  READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
  IF ls_role-role = 'B'.
    gv_confrim_text-text = '客戶確認'.
  ELSE.
    gv_confrim_text-text = '確認數量/金額'.
  ENDIF.
  CLEAR:it_extab.
  "重新計算(RECALC)按鈕僅在 p_imp(上傳建立)模式提供,其餘模式排除
  IF p_imp IS INITIAL.
    it_extab = VALUE #( BASE it_extab ( fcode = 'RECALC' ) ).
  ENDIF.
  "重算可轉/適用型號(CALC_REP)僅 p_mod 提供:p_imp 已自動算、p_upd 走 gt_report、p_dis 唯讀 → 排除(不分角色)
  IF p_mod IS INITIAL.
    it_extab = VALUE #( BASE it_extab ( fcode = 'CALC_REP' ) ).
  ENDIF.
  IF p_dis IS NOT INITIAL.
    APPEND INITIAL LINE TO it_extab ASSIGNING FIELD-SYMBOL(<ls_extab>).
    <ls_extab>-fcode = 'CONFIRM'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = '&DATA_SAVE'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'SALL'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'DSAL'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'CANC'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'NOCONFIRM'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'LOCK'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'CONFIRM_1'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'CALC_SALES'.
  ELSEIF p_imp IS NOT INITIAL OR p_upd IS NOT INITIAL.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'CONFIRM'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'CANC'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'NOCONFIRM'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'LOCK'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'CONFIRM_1'.
    IF ls_role-role = 'A'.
      APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
      <ls_extab>-fcode = 'CALC_SALES'.
    ENDIF.
  ELSEIF p_mod IS NOT INITIAL.
*    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
*    <ls_extab>-fcode = '&DATA_SAVE'.
    IF ls_role-role NE 'B'.
      APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
      <ls_extab>-fcode = 'CANC'.
      APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
      <ls_extab>-fcode = 'NOCONFIRM'.
      APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
      <ls_extab>-fcode = 'LOCK'.
      APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
      <ls_extab>-fcode = 'CALC_SALES'.
    ELSE.
      APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
      <ls_extab>-fcode = 'CONFIRM_1'.
    ENDIF.
  ENDIF.
  SET PF-STATUS 'STATUS_ALV' EXCLUDING it_extab.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  FRM_USER_COMMAND
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM frm_user_command USING iv_ucomm    TYPE sy-ucomm       "#EC CALLED
                            is_selfield TYPE slis_selfield.

  DATA:lo_grid TYPE REF TO cl_gui_alv_grid.
  DATA:lv_ans TYPE c.
  DATA:lv_subrc TYPE sy-subrc.

  CALL FUNCTION 'GET_GLOBALS_FROM_SLVC_FULLSCR'
    IMPORTING
      e_grid = lo_grid.

  IF lo_grid IS NOT INITIAL.
    lo_grid->check_changed_data( ).
  ENDIF.
  CALL METHOD lo_grid->get_filtered_entries
    IMPORTING
      et_filtered_entries = gt_filtered.

  CASE iv_ucomm.
    WHEN '&F03' OR '&F15'.
      LEAVE TO SCREEN 0.
    WHEN '&F12'.
      LEAVE PROGRAM.
    WHEN 'SALL'."選擇全部行
      LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
        IF NOT line_exists( <ls_data>-cellstyles[ style = cl_gui_alv_grid=>mc_style_disabled ] ).
          <ls_data>-sel = 'X'.
        ENDIF.
      ENDLOOP.
    WHEN 'DSAL'."取消選擇全部行
      LOOP AT gt_data ASSIGNING <ls_data>.
        IF NOT line_exists( <ls_data>-cellstyles[ style = cl_gui_alv_grid=>mc_style_disabled ] ).
          <ls_data>-sel = ''.
        ENDIF.
      ENDLOOP.
    WHEN '&IC1'.
      PERFORM frm_double_click USING is_selfield .
    WHEN 'CONFIRM'.
      IF line_exists( gt_data[ sel = 'X' ] ).
        PERFORM pop_up_confirm  USING  '確認數量'(t05)
                                        '將勾選的項目確認數量?'(t06)
                                        lv_ans.
        IF lv_ans = '1'.
          PERFORM confirm_qty.
          "V008 報庫存量超過018需求量→條列彈窗軟提醒(不中斷、不影響存檔)
          IF gt_exceed IS NOT INITIAL.
            PERFORM show_exceed_popup.
          ENDIF.
          PERFORM save_data.
        ELSE.
          MESSAGE s001(00) WITH 'User canceled'.
        ENDIF.
      ELSE.
        MESSAGE s001(00) WITH 'Please select items'.
      ENDIF.
    WHEN 'CONFIRM_1'.
      IF line_exists( gt_data[ sel = 'X' ] ).
        PERFORM pop_up_confirm  USING  '確認並送出給業務確認'(t15)
                                        '將勾選的項目確認並送出給業務確認?'(t16)
                                        lv_ans.
        IF lv_ans = '1'.
          PERFORM check_confirm_1 USING lv_subrc.
          IF lv_subrc IS INITIAL.
            PERFORM confirm_1.
            PERFORM save_data.
          ELSE.
            MESSAGE i001 WITH '檢查結果有誤，請看錯誤訊息說明'.
          ENDIF.
        ELSE.
          MESSAGE s001(00) WITH 'User canceled'.
        ENDIF.
      ELSE.
        MESSAGE s001(00) WITH 'Please select items'.
      ENDIF.
    WHEN 'LOCK'. "鎖住
      PERFORM pop_up_confirm  USING  '鎖定?'(t09)
                                      '將鎖定XJ單,生管、採購不能修改'(t10)
                                      lv_ans.
      IF lv_ans = '1'.
        PERFORM lock_xj.
        PERFORM save_data.
      ELSE.
        MESSAGE s001(00) WITH 'User canceled'.
      ENDIF.
    WHEN 'CANC'. "還原
      PERFORM pop_up_confirm  USING  '還原'(t11)
                                      '將鎖定的XJ單還原狀態'(t12)
                                        lv_ans.
      IF lv_ans = '1'.
        PERFORM unlock_xj.
        PERFORM save_data.
      ELSE.
        MESSAGE s001(00) WITH 'User canceled'.
      ENDIF.
    WHEN 'NOCONFIRM'."維持原訂單
      PERFORM pop_up_confirm  USING  '維持原訂單'(t13)
                                     '客戶不接受XJ單(維持原訂單)'(t14)
                                        lv_ans.
      IF lv_ans = '1'.
        PERFORM noconfirm.
        PERFORM save_data.
      ELSE.
        MESSAGE s001(00) WITH 'User canceled'.
      ENDIF.
    WHEN '&DATA_SAVE'.
      PERFORM pop_up_confirm  USING  '確認儲存'(t07)
                                      '確認儲存至外掛表中?'(t08)
                                      lv_ans.
      IF lv_ans = '1'.
        PERFORM save_data.
      ELSE.
        MESSAGE s001(00) WITH 'User canceled'.
      ENDIF.
    WHEN 'CALC_SALES'.
      PERFORM pop_up_confirm  USING  '確認重新計算'(t17)
                                     '確認重新計算業務幣別/金額?'(t18)
                                     lv_ans.
      IF lv_ans = '1'.
        PERFORM calc_sales.
        "PERFORM save_data.
      ELSE.
        MESSAGE s001(00) WITH 'User canceled'.
      ENDIF.

    WHEN 'CALC_REP'. "重算可轉/適用型號(記憶體,不存檔;僅勾選列,p_mod)
      IF line_exists( gt_data[ sel = 'X' ] ).
        PERFORM pop_up_confirm USING '重新計算'
                                     '重算勾選列的可轉/適用型號?'
                                     lv_ans.
        IF lv_ans = '1'.
          PERFORM calc_rep USING abap_true.
          IF gt_calc_skip IS NOT INITIAL.
            PERFORM show_calc_skip.   "彈窗條列未重算/未配到的項目+原因
          ENDIF.
          MESSAGE s001(00) WITH '已重算可轉/適用型號(尚未存檔,請檢視後再儲存)'.
        ELSE.
          MESSAGE s001(00) WITH 'User canceled'.
        ENDIF.
      ELSE.
        MESSAGE s001(00) WITH 'Please select items'.
      ENDIF.

    WHEN 'RECALC'. "重新計算(p_imp):重跑018重建gt_data,畫面重算不存檔
      IF p_imp IS NOT INITIAL.
        "已存檔(save_data把XJ號寫回gt_data)→禁止重算,避免覆寫已進DB的XJ單
        DATA lv_recalc_locked TYPE abap_bool.
        CLEAR lv_recalc_locked.
        LOOP AT gt_data TRANSPORTING NO FIELDS WHERE xj IS NOT INITIAL.
          lv_recalc_locked = abap_true.
          EXIT.
        ENDLOOP.
        IF lv_recalc_locked = abap_true.
          MESSAGE s001(00) WITH '已存檔產生XJ單,不可再重新計算'(t22) DISPLAY LIKE 'E'.
        ELSE.
          PERFORM pop_up_confirm USING '重新計算'(t20)
                                       '將以最新MRP重新展開018重算(尚未存檔);手填的報庫存量/備註會保留,是否繼續?'(t21)
                                       lv_ans.
          IF lv_ans = '1'.
            PERFORM frm_recalc_imp.
            MESSAGE s001(00) WITH '已重新計算(尚未存檔,請檢視後再儲存)'.
          ENDIF.
        ENDIF.
      ENDIF.
    WHEN OTHERS.
  ENDCASE.
  lo_grid->refresh_table_display( ).
  is_selfield-refresh    = 'X'.
  is_selfield-col_stable = 'X'.
  is_selfield-row_stable = 'X'.

ENDFORM. "FRM_USER_COMMAND
*&---------------------------------------------------------------------*
*& Form frm_recalc_imp
*&  p_imp 重新計算:保留手填 → CLEAR gt_data → 重跑 prepare_data
*&  → 補值(同 END-OF-SELECTION) → 還原手填(依 vbeln+posnr+idnrk+werks)
*&  純記憶體重算,不寫 DB(由使用者檢視後自行 &DATA_SAVE)
*&---------------------------------------------------------------------*
FORM frm_recalc_imp.
  TYPES: BEGIN OF lty_keep,
           vbeln     TYPE zscx0003_alv-vbeln,
           posnr     TYPE zscx0003_alv-posnr,
           idnrk     TYPE zscx0003_alv-idnrk,
           werks     TYPE zscx0003_alv-werks,
           stock_qty TYPE zscx0003_alv-stock_qty,
           pp_remark TYPE zscx0003_alv-pp_remark,
         END OF lty_keep.
  DATA: lt_keep TYPE SORTED TABLE OF lty_keep
                WITH NON-UNIQUE KEY vbeln posnr idnrk werks,
        ls_keep TYPE lty_keep.

  "1) 保留生管已手填的 報庫存量 / 生管備註(p_imp 唯二可編欄)
  LOOP AT gt_data INTO DATA(ls_old)
       WHERE stock_qty IS NOT INITIAL OR pp_remark IS NOT INITIAL.
    CLEAR ls_keep.
    ls_keep-vbeln     = ls_old-vbeln.
    ls_keep-posnr     = ls_old-posnr.
    ls_keep-idnrk     = ls_old-idnrk.
    ls_keep-werks     = ls_old-werks.
    ls_keep-stock_qty = ls_old-stock_qty.
    ls_keep-pp_remark = ls_old-pp_remark.
    INSERT ls_keep INTO TABLE lt_keep.
  ENDLOOP.

  "2) 重建:prepare_data 自身不清 gt_data,故先清(否則疊加重複列)
  CLEAR gt_data.
  PERFORM prepare_data.

  "3) 補值(同 END-OF-SELECTION 統一補值)+ 還原手填
  LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_d>).
    DATA(ls_key) = VALUE ty_key( matnr = <ls_d>-idnrk
                                 werks = <ls_d>-werks ).
    PERFORM update_alv_fields USING ls_key CHANGING <ls_d>.

    "料件仍存在才還原手填;新出現的料/已消失的料自然不還原
    READ TABLE lt_keep INTO ls_keep
         WITH KEY vbeln = <ls_d>-vbeln posnr = <ls_d>-posnr
                  idnrk = <ls_d>-idnrk werks = <ls_d>-werks.
    IF sy-subrc = 0.
      <ls_d>-stock_qty = ls_keep-stock_qty.
      <ls_d>-pp_remark = ls_keep-pp_remark.
    ENDIF.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form calc_rep
*&  重算 gt_data 的 rep(可轉不可轉)/ prod(適用型號)— 同通路(vtweg)
*&  範圍:stock_qty>0 且 ( rep 空 OR rep='N' )(保護 rep='Y' 不動)
*&        跳過 xj_status='D'(鎖定)/ 'F'(維持原訂單)
*&  對照表 ZTCX0003_PROD 沒該 idnrk → rep 保持原值(留空/原N),不動
*&  iv_only_sel='X' 只算勾選列(P_MOD ICON);''算全表(P_IMP 自動)
*&  純記憶體,不寫 DB(隨後由 &DATA_SAVE 一起寫)
*&---------------------------------------------------------------------*
FORM calc_rep USING iv_only_sel TYPE abap_bool.
  DATA: lt_prod   TYPE SORTED TABLE OF ztcx0003_prod
                  WITH NON-UNIQUE KEY idnrk,
        lt_sd020  TYPE SORTED TABLE OF ztsd0020
                  WITH NON-UNIQUE KEY zcn matnr vtweg,
        lr_idnrk  TYPE RANGE OF ztcx0003_prod-idnrk,
        lv_reason TYPE c LENGTH 60.

  CLEAR gt_calc_skip.

  " 1) 收集待算列的 idnrk(預讀對照表,避免 N+1)
  "    P_IMP(iv_only_sel='')不卡任何狀態,展開後直接用料號;P_MOD('X')卡勾選/庫存/狀態
  LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<row>).
    IF iv_only_sel = abap_true.
      IF <row>-sel IS INITIAL.                              CONTINUE. ENDIF.
      IF <row>-stock_qty <= 0.                              CONTINUE. ENDIF.
      IF <row>-rep IS NOT INITIAL AND <row>-rep <> 'N'.     CONTINUE. ENDIF.
      IF <row>-xj_status = 'D' OR <row>-xj_status = 'F'.    CONTINUE. ENDIF.
    ELSE.
      IF <row>-idnrk IS INITIAL.                            CONTINUE. ENDIF.
    ENDIF.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = <row>-idnrk ) TO lr_idnrk.
  ENDLOOP.

  " 2) 一次撈對照表 + ZTSD0020(同 idnrk 群)
  IF lr_idnrk IS NOT INITIAL.
    SORT lr_idnrk BY low.
    DELETE ADJACENT DUPLICATES FROM lr_idnrk COMPARING low.
    SELECT * FROM ztcx0003_prod
      WHERE idnrk IN @lr_idnrk
      INTO TABLE @lt_prod.
    IF lt_prod IS NOT INITIAL.
      SELECT * FROM ztsd0020
        FOR ALL ENTRIES IN @lt_prod
        WHERE zcn   = @lt_prod-skuitem
          AND matnr = @lt_prod-matnr
        INTO TABLE @lt_sd020.
    ENDIF.
  ENDIF.

  " 3) 逐列重算 rep/prod;P_MOD('X')卡狀態並收集原因供彈窗;P_IMP('')不卡狀態
  LOOP AT gt_data ASSIGNING <row>.
    IF iv_only_sel = abap_true.
      " P_MOD:卡勾選/庫存/狀態,未配到原因收集到 gt_calc_skip(彈窗)
      IF <row>-sel IS INITIAL. CONTINUE. ENDIF.
      CLEAR lv_reason.
      IF <row>-stock_qty <= 0.
        lv_reason = '報庫存量不大於 0,未重算'.
      ELSEIF <row>-rep IS NOT INITIAL AND <row>-rep <> 'N'.
        lv_reason = '已可轉(rep=Y),保護未變更'.
      ELSEIF <row>-xj_status = 'D'.
        lv_reason = 'XJ 鎖定中(客戶確認中),未重算'.
      ELSEIF <row>-xj_status = 'F'.
        lv_reason = 'XJ 維持原訂單(作廢),未重算'.
      ELSE.
        READ TABLE lt_prod TRANSPORTING NO FIELDS WITH KEY idnrk = <row>-idnrk.
        IF sy-subrc <> 0.
          lv_reason = '對照表尚無此元件,請先執行 ZTGCX0003_PROD'.
        ENDIF.
      ENDIF.
      IF lv_reason IS NOT INITIAL.
        PERFORM add_calc_skip USING <row> lv_reason iv_only_sel.
        CONTINUE.
      ENDIF.
    ELSE.
      " P_IMP:不卡庫存/狀態,展開後直接用料號;對照表沒料 → rep 留空(不算)
      IF <row>-idnrk IS INITIAL. CONTINUE. ENDIF.
      READ TABLE lt_prod TRANSPORTING NO FIELDS WITH KEY idnrk = <row>-idnrk.
      IF sy-subrc <> 0. CONTINUE. ENDIF.
    ENDIF.

    " 對照表有料 → 算同通路適用型號(P_IMP / P_MOD 共用)
    CLEAR <row>-prod.
    LOOP AT lt_prod ASSIGNING FIELD-SYMBOL(<prod>) WHERE idnrk = <row>-idnrk.
      CHECK <prod>-matnr <> <row>-matnr.            "只看別的成品
      READ TABLE lt_sd020 TRANSPORTING NO FIELDS
           WITH KEY zcn   = <prod>-skuitem
                    matnr = <prod>-matnr
                    vtweg = <row>-vtweg.            "同通路才算
      IF sy-subrc = 0.
        CHECK <row>-prod NS <prod>-skuitem.         "未含才加
        IF <row>-prod IS INITIAL.
          <row>-prod = <prod>-skuitem.
        ELSE.
          CONCATENATE <row>-prod <prod>-skuitem
                 INTO <row>-prod SEPARATED BY ';'.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF <row>-prod IS INITIAL.
      <row>-rep = 'N'.
      PERFORM add_calc_skip USING <row> '同通路無其他適用型號(專用件),rep=N' iv_only_sel.
    ELSE.
      <row>-rep = 'Y'.
      PERFORM add_calc_skip USING <row> '成功:已配到適用型號' iv_only_sel.
    ENDIF.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form add_calc_skip
*&  收集 CALC_REP 未配到適用型號的列 + 原因(僅 P_MOD 收集,供彈窗)
*&---------------------------------------------------------------------*
FORM add_calc_skip USING ps_row     TYPE zscx0003_alv
                         pv_reason  TYPE c
                         pv_only_sel TYPE abap_bool.
  CHECK pv_only_sel = abap_true.
  APPEND VALUE #( xj      = ps_row-xj
                  xj_item = ps_row-xj_item
                  idnrk   = ps_row-idnrk
                  matnr   = ps_row-matnr
                  skuitem = ps_row-skuitem
                  vtweg   = ps_row-vtweg
                  rep     = ps_row-rep
                  reason  = pv_reason ) TO gt_calc_skip.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_calc_skip
*&  P_MOD 重算後,彈窗條列勾選列的重算結果(成功 + 未配到)與原因
*&  上方 top-of-page 說明 Y / N / 空白 的意義
*&---------------------------------------------------------------------*
FORM show_calc_skip.
  DATA: lt_fcat  TYPE lvc_t_fcat,
        ls_layo  TYPE lvc_s_layo,
        lv_title TYPE lvc_title.
  lt_fcat = VALUE lvc_t_fcat(
    ( fieldname = 'XJ'      coltext = 'XJ單號' )
    ( fieldname = 'XJ_ITEM' coltext = '項次' )
    ( fieldname = 'IDNRK'   coltext = '元件' )
    ( fieldname = 'MATNR'   coltext = '成品' )
    ( fieldname = 'SKUITEM' coltext = '型號' )
    ( fieldname = 'VTWEG'   coltext = '通路' )
    ( fieldname = 'REP'     coltext = '可轉' )
    ( fieldname = 'REASON'  coltext = '結果/原因' outputlen = 50 ) ).
  ls_layo-cwidth_opt = 'X'.
  ls_layo-zebra      = 'X'.
  lv_title = '勾選列重算結果(成功 + 未配到)'.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
      i_callback_program          = sy-repid
      i_callback_html_top_of_page = 'FRM_CALC_SKIP_TOP'
      i_html_height_top           = 5
      i_bypassing_buffer          = 'X'
      i_grid_title                = lv_title
      is_layout_lvc               = ls_layo
      it_fieldcat_lvc             = lt_fcat
      i_screen_start_column       = 2
      i_screen_start_line         = 2
      i_screen_end_column         = 130
      i_screen_end_line           = 24
      i_save                      = 'A'
    TABLES
      t_outtab                    = gt_calc_skip
    EXCEPTIONS
      program_error               = 1
      OTHERS                      = 2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form frm_calc_skip_top
*&  show_calc_skip 彈窗上方說明(可轉 REP 三態)
*&  html top-of-page 回呼,簽章固定:top TYPE REF TO cl_dd_document(同 ZTGCX0001 hotspot_top_of_page)
*&---------------------------------------------------------------------*
FORM frm_calc_skip_top USING top TYPE REF TO cl_dd_document. "#EC CALLED
  top->add_text( text = '【可轉 REP 說明】' ).
  top->new_line( ).
  top->add_text( text = 'Y = 可轉:同通路下有其他適用型號。' ).
  top->new_line( ).
  top->add_text( text = 'N = 不可轉:同通路下無其他型號(專用件)。' ).
  top->new_line( ).
  top->add_text( text = '空白 = 未建對照(對照表尚無此元件,請先執行 ZTGCX0003_PROD)。' ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form FRM_DOUBLE_CLICK
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> IS_SELFIELD
*&---------------------------------------------------------------------*
FORM frm_double_click USING    is_selfield TYPE slis_selfield.


  READ TABLE gt_data ASSIGNING FIELD-SYMBOL(<fs_tab>) INDEX is_selfield-tabindex.
  IF sy-subrc EQ 0.
    CASE is_selfield-fieldname.
      WHEN 'IDNRK'.
        SET PARAMETER ID 'MXX' FIELD 'D'. "Table T132，决定显示哪个视图
        SET PARAMETER ID 'MAT' FIELD <fs_tab>-idnrk.
        SET PARAMETER ID 'WRK' FIELD <fs_tab>-werks.
*       Set parameter id 'KAR' field '001'.
*       SET PARAMETER ID 'LAG' FIELD im_lgort.
        CALL TRANSACTION 'MM03' AND SKIP FIRST SCREEN.
*      WHEN 'BELNR'. "FB03
*        IF <fs_tab>-belnr IS NOT INITIAL.
*          SET PARAMETER ID 'BLN' FIELD <fs_tab>-belnr.
*          SET PARAMETER ID 'BUK' FIELD <fs_tab>-bukrs.
*          SET PARAMETER ID 'GJR' FIELD <fs_tab>-budat(4).
*          CALL TRANSACTION 'FB03' AND SKIP FIRST SCREEN.
*        ENDIF.
*      WHEN 'XBLNR'.
*        IF <fs_tab>-xblnr IS NOT INITIAL.
**          PERFORM pop_up_alv USING <fs_tab>-xblnr.
*        ENDIF.
      WHEN OTHERS.

    ENDCASE.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form pop_up_confirm
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> P_
*&      --> P_
*&      --> LV_ANS
*&---------------------------------------------------------------------*
FORM pop_up_confirm  USING    VALUE(p_title)
                              VALUE(p_question)
                              p_ans TYPE c.
  CLEAR:p_ans.
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      titlebar              = p_title
*     DIAGNOSE_OBJECT       = ' '
      text_question         = p_question
      text_button_1         = 'Yes'(014)
*     ICON_BUTTON_1         = ' '
      text_button_2         = 'No'(015)
*     ICON_BUTTON_2         = ' '
*     DEFAULT_BUTTON        = '1'
      display_cancel_button = ''
*     USERDEFINED_F1_HELP   = ' '
*     START_COLUMN          = 25
*     START_ROW             = 6
*     POPUP_TYPE            =
*     IV_QUICKINFO_BUTTON_1 = ' '
*     IV_QUICKINFO_BUTTON_2 = ' '
    IMPORTING
      answer                = p_ans
*       TABLES
*     PARAMETER             =
    EXCEPTIONS
      text_not_found        = 1
      OTHERS                = 2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form prepare_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM prepare_data .





  GET TIME STAMP FIELD gv_calc_tstamp.  "快照:記T0(本次018計算時點;RECALC亦走此FORM→自動刷新)

  LOOP AT gt_upload INTO DATA(ls_upload).

    CLEAR :  gt_pp029, ls_data.
    "Submit PP-029抓取訂單取消或異動影響
    PERFORM submit_pp029 USING ls_upload.
    "整理報表欄位
    IF gt_pp029 IS NOT INITIAL.
      LOOP AT gt_pp029 INTO DATA(ls_029).


*--- V006 (JosephLo): 移除「最高版本料號去重」-----------------------------------*
*  原 lv_base/lv_best 計算 +「IF ls_029-matnr NE lv_best. CONTINUE.」會把同基礎碼、
*  只差結尾版本字母的料(如 ...618 vs ...618A)當重複,只留最高版、靜默丟掉其餘。
*  但 018 加總模式(submit_pp029 帶 r_mode1='X')下每 (matnr,werks) 只一列、無真重複,
*  該邏輯只會誤砍有實體庫存要取消的舊版料 → 整段移除,gt_pp029 每列都建入 gt_data。
*  詳: ZTGCX0003_018展開料未進XJ清單_根因分析.md §6


        ls_data-vbeln = ls_029-kdauf.
        ls_data-posnr = ls_029-kdpos.

        SELECT SINGLE vtweg,kunnr,vbap~matnr,kwmeng,vrkme FROM vbak
          INNER JOIN vbap ON vbak~vbeln = vbap~vbeln
          WHERE vbak~vbeln = @ls_029-kdauf
            AND vbap~posnr = @ls_029-kdpos
        INTO CORRESPONDING FIELDS OF @ls_data.
        ls_data-werks = ls_029-werks.
        "V008 訂單表頭展開廠:018 已不提供,改由 VBAP(訂單/項次)補
        SELECT SINGLE werks FROM vbap
          WHERE vbeln = @ls_029-kdauf AND posnr = @ls_029-kdpos
          INTO @ls_data-werks_so.
        ls_data-idnrk = ls_029-matnr.
        "預採帳帳本別
        READ TABLE gt_custmap INTO DATA(ls_map) WITH KEY werks = ls_data-werks vtweg = ls_data-vtweg.
        IF sy-subrc = 0.
          ls_data-zseq = ls_map-zseq.
        ENDIF.


        "成品型號
*        SELECT SINGLE skuitem
*          FROM ztmara
*        WHERE matnr = @ls_data-matnr
*        INTO CORRESPONDING FIELDS OF @ls_data.
        SELECT SINGLE zcn
         FROM ztsd0020
       WHERE vtweg = @ls_data-vtweg
         AND matnr = @ls_data-matnr
       INTO @ls_data-skuitem.

        SELECT SINGLE wl2_erpspecification,maktx,wl2_englishspecifications,mara~meins
          FROM ztmara INNER JOIN makt
          ON ztmara~matnr = makt~matnr AND makt~spras = @sy-langu
          INNER JOIN mara ON ztmara~matnr = mara~matnr
          WHERE ztmara~matnr = @ls_data-idnrk
        INTO CORRESPONDING FIELDS OF @ls_data.

        SELECT SINGLE ztmarc~zdefault_vendor,
                      lfa1~name1
          FROM ztmarc INNER JOIN lfa1 ON ztmarc~zdefault_vendor = lfa1~lifnr
        WHERE ztmarc~werks = @ls_data-werks
          AND ztmarc~matnr = @ls_data-idnrk
        INTO ( @ls_data-zdefault_vendor,@ls_data-name1 ).
        "採購群組
        IF ls_data-beskz = 'F' AND ls_data-sobsl IS INITIAL.
          SELECT SINGLE ekgrp FROM eina
            INNER JOIN eine ON eina~infnr = eine~infnr
          WHERE eina~matnr = @ls_029-matnr
            AND eine~werks = @ls_029-werks
            AND eina~lifnr = @ls_data-zdefault_vendor
            AND eine~esokz = '0'
            AND eine~loekz IS INITIAL
          INTO @ls_data-ekgrp.
        ELSEIF ls_data-beskz = 'F' AND ls_data-sobsl ='30'.
          SELECT SINGLE ekgrp FROM eina
            INNER JOIN eine ON eina~infnr = eine~infnr
          WHERE eina~matnr = @ls_029-matnr
            AND eine~werks = @ls_029-werks
            AND eina~lifnr = @ls_data-zdefault_vendor
            AND eine~esokz = '3'
            AND eine~loekz IS INITIAL
          INTO @ls_data-ekgrp.
        ENDIF.
        "展開階層
        ls_data-zex_hier = ls_029-zex_hier.
        "源頭單據號碼
        ls_data-del12 = ls_029-del12.
        "展開單據號碼
        ls_data-delnr = ls_029-delnr.
        ls_data-beskz = ls_029-beskz.
        ls_data-sobsl = ls_029-sobsl.
        "ls_data-meins = ls_029-meins.
        ls_data-calc_date = ls_upload-calc_date.
        "庫存數量
        ls_data-labst = ls_029-labst.
        "工單數量
        ls_data-feaub = ls_029-feaub.
        "計劃單數量
        ls_data-plafb = ls_029-plafb.
        "IQC待驗量
        ls_data-insme = ls_029-insme.
        "採購量
        ls_data-bebst = ls_029-bebst.
        "請購量
        ls_data-banfb = ls_029-banfb.
        "抓取其餘MRP數量
        PERFORM get_extra_mrp CHANGING ls_data.
        "可轉可不轉/適用型號
        "PERFORM get_where_used_bom USING ls_data.
        "取消数量
        ls_data-canc_qty = ls_upload-menge.
        "需用量
        ls_data-bdmng = ls_029-menge.

        "預設帶出淨價
        PERFORM default_netpr CHANGING ls_data.
        "理論存量
        PERFORM get_trans_qty CHANGING ls_data.
        "最小訂購量
        "倍數
        SELECT SINGLE bstmi,
                      bstrf
          FROM marc
        WHERE matnr = @ls_data-idnrk
          AND werks = @ls_data-werks
        INTO ( @ls_data-bstmi,@ls_data-bstrf ).
        "業務幣別	業務單價
        PERFORM get_sales_price USING ls_data.
        "特殊標記
        SELECT SINGLE  ztcx0004a~zind01, ztcx0004a~zdesc
          INTO ( @ls_data-zind01, @ls_data-zdesc )
        FROM ztcx0004a
          INNER JOIN mara ON ztcx0004a~matkl = mara~matkl
          INNER JOIN marc ON marc~matnr = mara~matnr
                                AND  ztcx0004a~strgr = marc~strgr
          WHERE mara~matnr = @ls_data-idnrk
              AND marc~werks = @ls_data-werks.




        APPEND ls_data TO gt_data.CLEAR ls_data.
      ENDLOOP.
    ENDIF.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_data .
  DATA:lv_subrc TYPE sy-subrc.
  DATA: ls_edit TYPE lvc_s_styl,
        lt_edit TYPE lvc_t_styl.
  SELECT cx~* FROM ztcx0004 AS cx
    WHERE xj_erdat IN @s_erdat  "XJ單建立日期
      AND idnrk IN @s_idnrk	"物料
      AND kunnr IN @s_kunnr	"客戶
      AND vtweg IN @s_vtweg "
      AND xj_status IN @s_status  "狀態
      AND vbeln IN @s_vbeln	"銷售文件
      AND cx~werks IN @s_werks  "工廠
      AND xj IN @s_xj	"XJ單號
      AND xj_ernam IN @s_ernam
      AND beskz IN @s_beskz
      AND stock_qty IN @s_qty
      AND netpr IN @s_netpr
  INTO TABLE @DATA(lt_04).

  IF p_mod IS NOT INITIAL.
    LOOP AT lt_04 INTO DATA(ls_04).

      APPEND INITIAL LINE TO gt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      MOVE-CORRESPONDING ls_04 TO <ls_data>.
      "Get full name from USER_ADDR
      PERFORM get_full_name_uname USING <ls_data>.
      "Lock 資料行，若不能Lock，則顯示錯誤訊息該資料已被鎖住。
      PERFORM lock_table USING ls_04 CHANGING lv_subrc.
      IF lv_subrc IS NOT INITIAL.
        <ls_data>-msg = '該筆資料已被鎖住'(t19).
        ls_edit-fieldname = 'SEL'.
        ls_edit-style = cl_gui_alv_grid=>mc_style_disabled.
        INSERT ls_edit INTO TABLE lt_edit.
        INSERT LINES OF lt_edit INTO TABLE <ls_data>-cellstyles.
      ELSE.
        CLEAR:<ls_data>-msg.
        SELECT SINGLE beskz FROM marc
          WHERE matnr = @ls_04-idnrk
            AND werks = @ls_04-werks
        INTO @DATA(lv_beskz).

        READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
        IF sy-subrc = 0.
          IF ls_role-role = 'A' AND lv_beskz = 'F'.
            "生管只能確認自製件
            ls_edit-fieldname = 'SEL'.
            ls_edit-style = cl_gui_alv_grid=>mc_style_disabled.
            INSERT ls_edit INTO TABLE lt_edit.
            INSERT LINES OF lt_edit INTO TABLE <ls_data>-cellstyles.
          ELSEIF ls_role-role = 'B'.
            "非業務客戶不能維謢
            IF ls_04-vtweg NE ls_role-vtweg AND ls_role-vtweg IS NOT INITIAL.
              ls_edit-fieldname = 'SEL'.
              ls_edit-style = cl_gui_alv_grid=>mc_style_disabled.
              INSERT ls_edit INTO TABLE lt_edit.
              INSERT LINES OF lt_edit INTO TABLE <ls_data>-cellstyles.
            ENDIF.
            "業務修改 XJ 單時，客戶同意數量自動帶「報庫存數量」、客戶同意金額自動帶「報庫存數量」x「料價」
*            <ls_data>-cust_qty = <ls_data>-stock_qty.
*            <ls_data>-cust_amt = <ls_data>-stock_qty * <ls_data>-netpr.
          ELSEIF ls_role-role = 'C'.
            IF lv_beskz = 'E' .
              "採購只能確認外購件,
              ls_edit-fieldname = 'SEL'.
              ls_edit-style = cl_gui_alv_grid=>mc_style_disabled.
              INSERT ls_edit INTO TABLE lt_edit.
              INSERT LINES OF lt_edit INTO TABLE <ls_data>-cellstyles.
            ENDIF.
          ENDIF.
        ENDIF.
        IF <ls_data>-netpr IS INITIAL AND <ls_data>-beskz = 'F'.
          PERFORM default_netpr CHANGING <ls_data>.
          "業務幣別	業務單價
          PERFORM get_sales_price USING <ls_data>.
        ENDIF.
      ENDIF.

    ENDLOOP.
    SORT gt_data BY xj xj_item.
  ELSEIF p_dis IS NOT INITIAL.
    gt_report = lt_04.
    SORT gt_report BY xj xj_item.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form lock_table
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LS_04
*&      <-- LV_SUBRC
*&---------------------------------------------------------------------*
FORM lock_table  USING    p_04 LIKE LINE OF gt_report
                 CHANGING p_subrc TYPE sy-subrc.
  CLEAR:p_subrc.
  DO 100 TIMES.
    CALL FUNCTION 'ENQUEUE_EZ_ZTCX0004'
      EXPORTING
*       MODE_ZTCX0004  = 'E'
*       MANDT          = SY-MANDT
        xj             = p_04-xj
        xj_item        = p_04-xj_item
*       X_XJ           = ' '
*       X_XJ_ITEM      = ' '
*       _SCOPE         = '2'
*       _WAIT          = ' '
*       _COLLECT       = ' '
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    p_subrc = sy-subrc.
    IF sy-subrc = 0.
      EXIT.
    ENDIF.

  ENDDO.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form unlock_table
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM unlock_table .
  CALL FUNCTION 'DEQUEUE_ALL'
* EXPORTING
*   _SYNCHRON       = ' '
    .

ENDFORM.
*&---------------------------------------------------------------------*
*& Form confirm_qty
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM confirm_qty .
  READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
  CLEAR gt_exceed.   "V008 每次確認重算超量清單(供條列彈窗)
  LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>) WHERE sel IS NOT INITIAL.
    CLEAR:<ls_data>-msg.
    CASE ls_role-role.
      WHEN 'A'.
        "V008 放開「報庫存量≤需求量」:018需求常與生管認知不符→不擋,改條列彈窗軟提醒
        "  (不寫msg,確保超量列仍能通過 save_data 的 WHERE msg IS INITIAL 而存檔)
        IF <ls_data>-stock_qty > <ls_data>-bdmng.
          PERFORM collect_exceed USING <ls_data>.   "收集供彈窗條列(不擋)
        ENDIF.
        <ls_data>-pp_chg_date = sy-datum.
        <ls_data>-pp_uname = sy-uname.
        <ls_data>-pp_chg_time = sy-uzeit.
        <ls_data>-xj_status = 'B'.  "生管確認數量
      WHEN 'C'.
        IF <ls_data>-netpr IS NOT INITIAL.
          <ls_data>-pur_chg_date = sy-datum.
          <ls_data>-pur_chg_time = sy-uzeit.
          <ls_data>-pur_uname = sy-uname.

          <ls_data>-xj_status = 'C'.  "採購確認數量
        ENDIF.

      WHEN 'B'.
        <ls_data>-sa_chg_date = sy-datum.
        <ls_data>-sa_chg_time = sy-uzeit.
        <ls_data>-sa_uname = sy-uname.
        <ls_data>-xj_status = 'E'.  "E-客戶確認(同意)
    ENDCASE.
    "Get full name from USER_ADDR
    PERFORM get_full_name_uname USING <ls_data>.

*20260518 Rogney 上傳資料時自動抓價格
    IF <ls_data>-netpr IS INITIAL AND <ls_data>-beskz = 'F'.
      PERFORM default_netpr CHANGING <ls_data>.
      "業務幣別	業務單價
      PERFORM get_sales_price USING <ls_data>.
    ENDIF.


  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form collect_exceed
*&  V008 收集「報庫存量 > 018需求量(bdmng)」的列,即時算超出量/百分比,供條列彈窗。
*&  僅軟提醒,不寫 msg、不擋確認/存檔。
*&---------------------------------------------------------------------*
FORM collect_exceed USING ps TYPE zscx0003_alv.
  APPEND INITIAL LINE TO gt_exceed ASSIGNING FIELD-SYMBOL(<ex>).
  MOVE-CORRESPONDING ps TO <ex>.
  <ex>-over_qty = ps-stock_qty - ps-bdmng.
  IF ps-bdmng > 0.
    <ex>-over_pct = <ex>-over_qty * 100 / ps-bdmng.
  ELSE.
    <ex>-over_pct = 0.   "需求量=0無法算%,僅以超出量表示
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_exceed_popup
*&  V008 確認後若有超量列→ALV popup 條列(比照 show_calc_skip):
*&  列出 XJ/項次/元件/成品/型號/通路/廠 + 018需求量/報庫存量/超出量/超出%。
*&  自帶標準工具列(可匯出 Excel/排序),看完關掉即進報表;純提示不中斷。
*&---------------------------------------------------------------------*
FORM show_exceed_popup.
  DATA: lt_fcat TYPE lvc_t_fcat,
        ls_layo TYPE lvc_s_layo.
  lt_fcat = VALUE lvc_t_fcat(
    ( fieldname = 'XJ'        coltext = 'XJ單號' )
    ( fieldname = 'XJ_ITEM'   coltext = '項次' )
    ( fieldname = 'IDNRK'     coltext = '元件' )
    ( fieldname = 'MATNR'     coltext = '成品' )
    ( fieldname = 'SKUITEM'   coltext = '型號' )
    ( fieldname = 'VTWEG'     coltext = '通路' )
    ( fieldname = 'WERKS'     coltext = '廠' )
    ( fieldname = 'BDMNG'     coltext = '018需求量' )
    ( fieldname = 'STOCK_QTY' coltext = '報庫存量' )
    ( fieldname = 'OVER_QTY'  coltext = '超出量' )
    ( fieldname = 'OVER_PCT'  coltext = '超出%' ) ).
  ls_layo-cwidth_opt = 'X'.
  ls_layo-zebra      = 'X'.
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
      i_callback_program    = sy-repid
      i_grid_title          = '報庫存量超過018需求量提醒(僅提示,不影響存檔)'
      i_bypassing_buffer    = 'X'
      is_layout_lvc         = ls_layo
      it_fieldcat_lvc       = lt_fcat
      i_screen_start_column = 2
      i_screen_start_line   = 2
      i_screen_end_column   = 130
      i_screen_end_line     = 24
      i_save                = 'A'
    TABLES
      t_outtab              = gt_exceed
    EXCEPTIONS
      program_error         = 1
      OTHERS                = 2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form save_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM save_data.
  DATA:lt_db TYPE TABLE OF ztcx0004.
  DATA:lv_xj_item TYPE zscx0003_alv-xj_item.
  DATA:lv_xj      TYPE zscx0003_alv-xj.
*  PERFORM get_number_range USING lv_xj.
  IF p_imp IS NOT INITIAL.
    "快照:存檔=建立XJ;先做「計算↔存檔」時間差提醒(不卡,user可選擇仍存)
    DATA lv_snap_abort TYPE abap_bool.
    PERFORM snap_stale_check CHANGING lv_snap_abort.
    IF lv_snap_abort = abap_true.
      RETURN.
    ENDIF.
    LOOP AT gt_data INTO DATA(ls_d1) WHERE xj IS INITIAL
      GROUP BY ( vbeln = ls_d1-vbeln posnr = ls_d1-posnr size = GROUP SIZE )
      INTO DATA(lg_d1).
      PERFORM get_xj_number USING lg_d1-vbeln lg_d1-posnr CHANGING lv_xj.
      CLEAR: lv_xj_item.
      LOOP AT GROUP lg_d1 ASSIGNING FIELD-SYMBOL(<ls_data1>).
        <ls_data1>-xj = lv_xj.
        <ls_data1>-sel = 'X'.
        ADD 1 TO lv_xj_item.
        <ls_data1>-xj_item = lv_xj_item.
      ENDLOOP.
    ENDLOOP.
  ENDIF.
  "取得ROLE
  READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.

  LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>) WHERE sel = 'X' AND msg IS INITIAL.
    CLEAR:<ls_data>-msg.
    APPEND INITIAL LINE TO lt_db ASSIGNING FIELD-SYMBOL(<ls_db>).
    MOVE-CORRESPONDING <ls_data> TO <ls_db>.
    IF p_imp IS NOT INITIAL.
      <ls_data>-xj_erdat = <ls_db>-xj_erdat = sy-datum.
      <ls_data>-xj_ertim = <ls_db>-xj_ertim = sy-uzeit.
      <ls_data>-xj_ernam = <ls_db>-xj_ernam = sy-uname.
      IF <ls_db>-xj_status IS INITIAL.
        "生管上傳檔案時沒有確認報庫存數量就儲存，程式檢查數量沒有輸入，狀態會放A
        IF <ls_db>-stock_qty IS INITIAL.
          <ls_db>-xj_status = 'A'.  "生管建立
        ELSE.
          <ls_db>-xj_status = 'B'.  "生管確認
          <ls_data>-pp_chg_date = <ls_db>-pp_chg_date = sy-datum.
          <ls_data>-pp_uname = <ls_db>-pp_uname = sy-uname.
          <ls_data>-pp_chg_time = <ls_db>-pp_chg_time = sy-uzeit.
        ENDIF.
      ELSEIF <ls_db>-xj_status IS NOT INITIAL.

      ENDIF.
    ELSEIF p_mod IS NOT INITIAL.

*      CASE ls_role-role.
*        WHEN 'A'."生管
*          IF <ls_db>-xj_status NE 'A' AND <ls_db>-xj_status NE 'B' AND <ls_db>-xj_status NE 'D'
*            AND <ls_db>-xj_status NE 'F' AND <ls_db>-xj_status NE 'E'."20250630: E/F先暫時開放補資料，以後需拿掉
*            <ls_data>-msg = '該行尚未進行確認動作'(m05).
*          ENDIF.
*        WHEN 'B'. "業務
*
*        WHEN 'C'."採購
*          IF <ls_db>-xj_status NE 'C' AND <ls_db>-xj_status NE 'D'
*            AND <ls_db>-xj_status NE 'F' AND <ls_db>-xj_status NE 'E'."20250630: E/F先暫時開放補資料，以後需拿掉
*            <ls_data>-msg = '該行尚未進行確認動作'(m05).
*          ENDIF.
*      ENDCASE.
    ENDIF.
  ENDLOOP.
  "匯總儲存
  DATA:lt_db_sum TYPE TABLE OF ztcx0004.
  IF p_imp IS NOT INITIAL.
    lt_db_sum = lt_db.
    CLEAR:lt_db.
    LOOP AT lt_db_sum INTO DATA(ls_d2)
                    GROUP BY ( xj = ls_d2-xj size = GROUP SIZE )
                    INTO DATA(lg_d2).
      CLEAR:lv_xj_item.

      LOOP AT GROUP lg_d2 INTO DATA(ls_d2b) GROUP BY ( idnrk = ls_d2b-idnrk size = GROUP SIZE )
        INTO DATA(lg_d2a).
        LOOP AT GROUP lg_d2a INTO DATA(ls_d2a).EXIT.ENDLOOP.
        APPEND INITIAL LINE TO lt_db ASSIGNING <ls_db>.
        MOVE-CORRESPONDING ls_d2a TO <ls_db>.
        ADD 1 TO lv_xj_item.
        <ls_db>-xj_item = lv_xj_item.
        CLEAR:<ls_db>-feaub,
              <ls_db>-plafb,
              <ls_db>-insme,
              <ls_db>-bebst,
              <ls_db>-banfb,
              <ls_db>-stock_qty,
*              <ls_db>-netpr,
*              <ls_db>-netpr_cny,
*              <ls_db>-netpr_twd,
              <ls_db>-bmeng,
              <ls_db>-tot_req_qty,
              <ls_db>-sub_qty.
        LOOP AT GROUP lg_d2a INTO ls_d2a.
          ADD: "ls_d2a-labst TO <ls_db>-labst,
               ls_d2a-feaub TO <ls_db>-feaub,
               ls_d2a-plafb TO <ls_db>-plafb,
               ls_d2a-insme TO <ls_db>-insme,
               ls_d2a-bebst TO <ls_db>-bebst,
               ls_d2a-banfb TO <ls_db>-banfb,
               ls_d2a-stock_qty TO <ls_db>-stock_qty,
*               ls_d2a-netpr TO <ls_db>-netpr,
*               ls_d2a-netpr_cny TO <ls_db>-netpr_cny,
*               ls_d2a-netpr_twd TO <ls_db>-netpr_twd,
               ls_d2a-bmeng TO <ls_db>-bmeng,
               ls_d2a-tot_req_qty TO <ls_db>-tot_req_qty,
               ls_d2a-sub_qty TO <ls_db>-sub_qty.
        ENDLOOP.

      ENDLOOP.

    ENDLOOP.
  ENDIF.
  LOOP AT gt_data INTO DATA(ls_d) WHERE msg IS NOT INITIAL.ENDLOOP.
  IF sy-subrc = 0.
    MESSAGE s003 DISPLAY LIKE 'E'. "此次要變更的資料尚有錯誤未處理，請確認!
    RETURN.
  ENDIF.
  IF lt_db IS NOT INITIAL.
    MODIFY ztcx0004 FROM TABLE lt_db.
    MESSAGE s002 WITH '訂單異動與取消報庫存外掛表'(t04).
    CLEAR gv_xj.
  ENDIF.

  "快照:XJ建立後忠實擷取018明細(+MD4C)存快照表;失敗不擋建單
  IF p_imp IS NOT INITIAL AND p_snap = 'X'.
    PERFORM create_calc_snapshot.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_number_range
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LS_DATA
*&---------------------------------------------------------------------*
FORM get_number_range  USING   p_xj TYPE char12.
*  DATA:lv_xj TYPE char12.
*
*  DO.
*    CALL FUNCTION 'NUMBER_RANGE_ENQUEUE'
*      EXPORTING
*        object           = 'ZCX_XJ_NR'
*      EXCEPTIONS
*        foreign_lock     = 1
*        object_not_found = 2
*        system_failure   = 3
*        OTHERS           = 4.
*    IF sy-subrc <> 0.
*      DO 1000 TIMES. ENDDO.
*    ELSE.
*      EXIT.
*    ENDIF.
*  ENDDO.
*
*  DO.
*    CALL FUNCTION 'NUMBER_GET_NEXT'
*      EXPORTING
*        nr_range_nr             = '00'
*        object                  = 'ZCX_XJ_NR'
*      IMPORTING
*        number                  = lv_xj
*      EXCEPTIONS
*        interval_not_found      = 1
*        number_range_not_intern = 2
*        object_not_found        = 3
*        quantity_is_0           = 4
*        quantity_is_not_1       = 5
*        interval_overflow       = 6
*        buffer_overflow         = 7
*        OTHERS                  = 8.
*    IF sy-subrc <> 0.
*      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
*    ELSE.
*      EXIT.
*    ENDIF.
*  ENDDO.
*  p_xj = 'XJ' && lv_xj.
*
*  CALL FUNCTION 'NUMBER_RANGE_DEQUEUE'
*    EXPORTING
*      object           = 'ZCX_XJ_NR'
*    EXCEPTIONS
*      object_not_found = 1
*      OTHERS           = 2.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_xj_number
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- LV_XJ
*&---------------------------------------------------------------------*
FORM get_xj_number USING p_vbeln TYPE vbeln p_posnr TYPE vbap-posnr
                   CHANGING p_xj TYPE ztcx0004-xj.
  DATA:lv_num(3) TYPE n.
  IF gv_xj IS INITIAL.
    SELECT xj FROM ztcx0004
      WHERE substring( xj, 3, 6 ) = @sy-datum+2(6) "XJ250103001
      ORDER BY xj DESCENDING
    INTO @DATA(lv_xj) UP TO 1 ROWS.
      lv_num = lv_xj+8(3) + 1.
      p_xj = lv_xj(8) && lv_num.
    ENDSELECT.
    IF sy-subrc NE 0.
      p_xj = 'XJ' && sy-datum+2 && '001'.
    ENDIF.
  ELSE.
    lv_num = gv_xj+8(3) + 1.
    p_xj = gv_xj(8) && lv_num.
  ENDIF.
  gv_xj = p_xj.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_full_name_uname
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> <LS_DATA>
*&---------------------------------------------------------------------*
FORM get_full_name_uname  USING p_data LIKE LINE OF gt_data.
  SELECT SINGLE name_textc FROM user_addr WHERE bname = @p_data-pp_uname INTO @p_data-pp_name_text.

  SELECT SINGLE name_textc FROM user_addr WHERE bname = @p_data-pur_uname INTO @p_data-pur_name_text.

  SELECT SINGLE name_textc FROM user_addr WHERE bname = @p_data-sa_uname INTO @p_data-sa_name_text.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form submit_pp029
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LS_UPLOAD
*&      <-- LT_PP029
*&---------------------------------------------------------------------*
FORM submit_pp029  USING    p_upload LIKE LINE OF gt_upload.
  DATA:lv_menge TYPE resbd-menge.
  lv_menge = p_upload-menge.
  cl_salv_bs_runtime_info=>set( display  = abap_false
                                metadata = abap_false
                                data     = abap_true ).
  "V007 改呼叫 ZPRP018_V1(ztgpprp0019_v1)取代 ztgpprp0019
  SUBMIT ztgpprp0019_v1 WITH r_bt1 = 'X'
                     WITH p_vbeln = p_upload-vbeln
                     WITH p_posnr = p_upload-posnr
                     WITH p_menge = lv_menge
                     WITH r_mode1 = 'X'
                     WITH r_mode2 = space
    AND RETURN .
  TRY.
      cl_salv_bs_runtime_info=>get_data_ref( IMPORTING r_data = DATA(lobj_data) ).
      ASSIGN lobj_data->* TO FIELD-SYMBOL(<lfs_data>).
    CATCH cx_salv_bs_sc_runtime_info.
  ENDTRY.
  IF <lfs_data> IS ASSIGNED.
    gt_pp029 = CORRESPONDING #( <lfs_data> ).
    "V008 018_v1 已還原為原始版(werks=子件需求廠、移除 werks_yc)→ 拆掉 V007 欄位換位;
    "     werks 直接用 018 子件廠;werks_so(訂單表頭廠)於 prepare_data 由 VBAP 補
  ENDIF.
  "清除SALV攔截單例:每次攔截用完即歸零,避免殘留display=false
  "→ RECALC重跑後開ALV「更改配置」時報「子畫面中不允許SET SCREEN」(SAPLSALV_CUL_COLUMN_SELECTION 0620)
  cl_salv_bs_runtime_info=>clear_all( ).

ENDFORM.
*&---------------------------------------------------------------------*
*& Form snap_stale_check
*&---------------------------------------------------------------------*
*& 快照:計算(T0)↔存檔(now)時間差提醒——超過 gc_stale_min 分鐘提醒(不卡)
*&---------------------------------------------------------------------*
FORM snap_stale_check CHANGING cv_abort TYPE abap_bool.
  DATA: lv_now TYPE timestamp,
        lv_sec TYPE p LENGTH 8 DECIMALS 0,
        lv_ans TYPE char1.
  CLEAR cv_abort.
  "只在:開啟快照 + 有T0 + 有待建XJ(xj空) 時才檢查
  IF p_snap <> 'X' OR gv_calc_tstamp IS INITIAL.
    RETURN.
  ENDIF.
  IF NOT line_exists( gt_data[ sel = 'X' xj = space ] ).
    RETURN.
  ENDIF.
  GET TIME STAMP FIELD lv_now.
  lv_sec = cl_abap_tstmp=>subtract( tstmp1 = lv_now
                                    tstmp2 = gv_calc_tstamp ).
  IF lv_sec > gc_stale_min * 60.
    PERFORM pop_up_confirm USING '計算結果可能過時'(t23)
                                 '距上次計算已超過時限,建議先「重新計算」再存。仍要存檔?'(t24)
                                 lv_ans.
    IF lv_ans <> '1'.
      cv_abort = abap_true.
      MESSAGE s001(00) WITH '已取消,請先「重新計算」再存檔'(t25).
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form create_calc_snapshot(解耦版:存檔端只寫 SNAPH stub)
*&---------------------------------------------------------------------*
*& 存檔當下只 INSERT SNAPH(STATUS='P'),秒回不拖前景。
*& 明細(SNAP018)/供需樹(SNAPMD4)由背景程式 ZTGCX0003_SNAP_CREATE
*&   (SM36 每 3 分、p_num=50)認領 'P' 後建立。
*& ※ 018 r_mode2 + MD4C 擷取邏輯已移到該背景程式,此處不再同步擷取。
*&---------------------------------------------------------------------*
FORM create_calc_snapshot.
  DATA: lt_h    TYPE TABLE OF ztcx0004_snaph,
        ls_h    TYPE ztcx0004_snaph,
        ls_up   LIKE LINE OF gt_upload,
        ls_mem  TYPE zscx0003_alv,
        lv_save TYPE timestamp.

  GET TIME STAMP FIELD lv_save.

  LOOP AT gt_data INTO DATA(ls_g)
       WHERE sel = 'X' AND xj IS NOT INITIAL
       GROUP BY ( xj = ls_g-xj )
       INTO DATA(lg_xj).

    "冪等:此XJ已有 SNAPH(stub 或已完成)→ 跳過
    SELECT SINGLE xj FROM ztcx0004_snaph
      WHERE xj = @lg_xj-xj INTO @DATA(lv_dummy).
    IF sy-subrc = 0.
      CONTINUE.
    ENDIF.

    "取該XJ來源 SO/項次/取消量(由 gt_upload)
    CLEAR ls_mem.
    LOOP AT GROUP lg_xj INTO ls_mem.
      EXIT.
    ENDLOOP.
    CLEAR ls_up.
    READ TABLE gt_upload INTO ls_up
         WITH KEY vbeln = ls_mem-vbeln posnr = ls_mem-posnr.
    IF sy-subrc <> 0.
      CONTINUE.   "找不到輸入來源→跳過該XJ
    ENDIF.

    "寫 stub(STATUS='P';明細/樹由背景 ZTGCX0003_SNAP_CREATE 建)
    CLEAR ls_h.
    ls_h-xj            = lg_xj-xj.
    ls_h-vbeln         = ls_up-vbeln.
    ls_h-posnr         = ls_up-posnr.
    ls_h-menge         = ls_up-menge.
    ls_h-calc_tstamp   = gv_calc_tstamp.   "T0(上傳計算時點)
    ls_h-save_tstamp   = lv_save.
    ls_h-threshold_min = gc_stale_min.
    ls_h-ernam         = sy-uname.
    ls_h-status        = 'P'.
    APPEND ls_h TO lt_h.
  ENDLOOP.

  IF lt_h IS NOT INITIAL.
    TRY.
        INSERT ztcx0004_snaph FROM TABLE lt_h ACCEPTING DUPLICATE KEYS.
      CATCH cx_root.
        "stub 寫入失敗不影響建單(極少;此處靜默)
    ENDTRY.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_where_used_bom
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LS_DATA
*&---------------------------------------------------------------------*
FORM get_where_used_bom  USING    p_data   LIKE LINE OF gt_data.
*  SELECT SINGLE kunnr FROM vbak WHERE vbeln = @p_data-vbeln INTO @DATA(lv_kunnr).
*  SELECT * FROM ztcx0003_prod
*    WHERE werks = @p_data-werks
*      AND idnrk = @p_data-idnrk
*  INTO TABLE @DATA(lt_prod).
*  IF sy-subrc = 0.
*    p_data-rep = 'Y'.
*    LOOP AT lt_prod INTO DATA(ls_prod).
*      CHECK p_data-prod NS ls_prod-skuitem.
*      SELECT * FROM ztsd0020
*        WHERE zcn = @ls_prod-skuitem
*      INTO TABLE @DATA(lt_sd020).
*      IF line_exists( lt_sd020[ kunnr = lv_kunnr ] ).
*        IF p_data-prod IS INITIAL.
*          p_data-prod = ls_prod-skuitem.
*        ELSE.
*          CONCATENATE p_data-prod ls_prod-skuitem INTO p_data-prod SEPARATED BY ';'.
*        ENDIF.
*      ENDIF.
*    ENDLOOP.
*  ENDIF.
*  DATA:lr_idnrk TYPE RANGE OF idnrk.
*  lr_idnrk = VALUE #( sign = 'I' option = 'EQ' ( low = p_data-idnrk ) ).
*  cl_salv_bs_runtime_info=>set( display  = abap_false
*                                metadata = abap_false
*                                data     = abap_true ).
*  SUBMIT rcs15001m WITH s_idnrk IN lr_idnrk
*                   WITH pm_werks = p_data-werks
*                   WITH pm_mehrs = 'X' "Multilevel
*    AND RETURN .
*  TRY.
*      cl_salv_bs_runtime_info=>get_data_ref( IMPORTING r_data = DATA(lobj_data) ).
*      ASSIGN lobj_data->* TO FIELD-SYMBOL(<lfs_data>).
*    CATCH cx_salv_bs_sc_runtime_info.
*  ENDTRY.
*  p_data-rep = 'N'.
*  IF <lfs_data> IS ASSIGNED.
*    DATA: lt_stpov_alv TYPE TABLE OF stpov_alv.
*    lt_stpov_alv = CORRESPONDING #( <lfs_data> ).
*    SELECT SINGLE kunnr FROM vbak WHERE vbeln = @p_data-vbeln INTO @DATA(lv_kunnr).
*    LOOP AT lt_stpov_alv INTO DATA(ls_stpov) WHERE crtfg = 'X'."最上層
*      SELECT SINGLE mara~matnr,ztmara~skuitem
*        FROM mara LEFT OUTER JOIN ztmara ON mara~matnr = ztmara~matnr
*      WHERE mara~matnr = @ls_stpov-dobjt
*        AND mara~mtart = 'ZFRT'
*        AND ( mstae = 'A' OR mstae = 'E' )
*      INTO @DATA(ls_mara).
*      IF sy-subrc = 0.
*        p_data-rep = 'Y'.
*        CHECK p_data-prod NS ls_mara-skuitem.
*        SELECT * FROM ztsd0020
*          WHERE zcn = @ls_mara-skuitem
*        INTO TABLE @DATA(lt_sd020).
*        IF line_exists( lt_sd020[ kunnr = lv_kunnr ] ).
*          IF p_data-prod IS INITIAL.
*            p_data-prod = ls_mara-skuitem.
*          ELSE.
*            CONCATENATE p_data-prod ls_mara-skuitem INTO p_data-prod SEPARATED BY ';'.
*          ENDIF.
*        ENDIF.
*      ENDIF.
*    ENDLOOP.
*
*  ENDIF.
*  DATA:ls_rep LIKE LINE OF gt_rep.
*  ls_rep-werks = p_data-werks.
*  ls_rep-idnrk = p_data-idnrk.
*  ls_rep-rep = p_data-rep.
*  ls_rep-prod = p_data-prod.
*  COLLECT ls_rep INTO gt_rep.
*  SORT gt_rep.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_control
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM display_control .
  READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
  LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
    CASE ls_role-role.
      WHEN 'A'.
        CLEAR: <ls_data>-netpr."<ls_data>-cust_amt.
    ENDCASE.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form default_netpr
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- LS_DATA
*&---------------------------------------------------------------------*
FORM default_netpr  CHANGING p_data LIKE LINE OF gt_data.
*  "取得該期間內最高PO採購價
*  PERFORM get_po_price USING p_data.
*  IF p_data-netpr IS NOT INITIAL.
*    RETURN.
*  ELSE.
*
*    IF p_data-netpr IS INITIAL.
*      "最近一期標準成本
*      PERFORM get_std_cost CHANGING p_data.
*    ENDIF.
*  ENDIF.
  IF p_data-beskz = 'F' AND p_data-sobsl IS INITIAL.
    "20250410改抓取Z_QT_COMP_PRICE_GET取價
    DATA:lt_comp TYPE TABLE OF zsqt0201comp.
    DATA:lv_msg TYPE string.
    APPEND INITIAL LINE TO lt_comp ASSIGNING FIELD-SYMBOL(<ls_comp>).
    <ls_comp>-idnrk = p_data-idnrk.
    <ls_comp>-werks_c = p_data-werks.
    <ls_comp>-menge_c  = p_data-canc_qty.
    <ls_comp>-waers_d = 'CNY'.

    CALL FUNCTION 'Z_QT_COMP_PRICE_GET'
      EXPORTING
        prsdt     = sy-datum
        source_c  = '2'
        priceflag = 'X'
      IMPORTING
        e_msg     = lv_msg
      TABLES
        et_comp   = lt_comp.
    READ TABLE lt_comp ASSIGNING <ls_comp> WITH KEY idnrk = p_data-idnrk.
    IF sy-subrc = 0.
      p_data-waers = <ls_comp>-waers_c. "原始幣別
      p_data-netpr = <ls_comp>-up_m.  "原始幣別 料價
      p_data-waers_cny = <ls_comp>-waers_d.
      p_data-netpr_cny = <ls_comp>-amt_d / <ls_comp>-menge_c."CNY料價
      "有原幣/單價，但無CNY/ TWD 單價者 (不報價)，由FM 回傳的匯率計算 CNY/TWD 單價。
      IF p_data-netpr_cny IS INITIAL.
        p_data-netpr_cny = <ls_comp>-up_m * <ls_comp>-kurrf_c.
        p_data-waers_cny = 'CNY'.
      ENDIF.
      IF <ls_comp>-up_m IS NOT INITIAL.
        p_data-zdefault_vendor = <ls_comp>-zdefault_vendor.
      ELSE.
        SELECT SINGLE ztmarc~zdefault_vendor,
                      lfa1~name1
          FROM ztmarc INNER JOIN lfa1 ON ztmarc~zdefault_vendor = lfa1~lifnr
        WHERE ztmarc~werks = @p_data-werks
          AND ztmarc~matnr = @p_data-idnrk
        INTO ( @p_data-zdefault_vendor,@p_data-name1 ).
      ENDIF.
    ENDIF.
    lt_comp[ 1 ]-waers_d = 'TWD'.
    CALL FUNCTION 'Z_QT_COMP_PRICE_GET'
      EXPORTING
        prsdt     = sy-datum
        source_c  = '2'
        priceflag = 'X'
      IMPORTING
        e_msg     = lv_msg
      TABLES
        et_comp   = lt_comp.
    READ TABLE lt_comp ASSIGNING <ls_comp> WITH KEY idnrk = p_data-idnrk.
    IF sy-subrc = 0.
      p_data-waers_twd = <ls_comp>-waers_d.
      p_data-netpr_twd = <ls_comp>-amt_d / <ls_comp>-menge_c."TWD料價
    ENDIF.
    IF p_data-netpr_twd IS INITIAL.
      p_data-netpr_twd = <ls_comp>-up_m * <ls_comp>-kurrf_c.
      p_data-waers_twd = 'TWD'.
    ENDIF.
    IF p_data-netpr IS INITIAL.
      "有效的INFO RECORD
      PERFORM get_info_record CHANGING p_data.
      "CNY
      DATA:ls_exch_rate TYPE bapi1093_0,
           ls_return    TYPE bapiret1.
      CALL FUNCTION 'BAPI_EXCHANGERATE_GETDETAIL'
        EXPORTING
          rate_type  = 'M'
          from_curr  = p_data-waers
          to_currncy = 'CNY'
          date       = sy-datum
        IMPORTING
          exch_rate  = ls_exch_rate
          return     = ls_return.
      p_data-netpr_cny = p_data-netpr * ls_exch_rate-exch_rate.
      p_data-waers_cny = 'CNY'.
      "TWD
      CALL FUNCTION 'BAPI_EXCHANGERATE_GETDETAIL'
        EXPORTING
          rate_type  = 'M'
          from_curr  = p_data-waers
          to_currncy = 'TWD'
          date       = sy-datum
        IMPORTING
          exch_rate  = ls_exch_rate
          return     = ls_return.
      p_data-netpr_twd = p_data-netpr * ls_exch_rate-exch_rate.
      p_data-waers_twd = 'TWD'.
    ENDIF.
  ENDIF.
  IF p_data-netpr IS NOT INITIAL AND p_data-netpr_cny IS INITIAL.
    CLEAR:ls_exch_rate.
    CALL FUNCTION 'BAPI_EXCHANGERATE_GETDETAIL'
      EXPORTING
        rate_type  = 'M'
        from_curr  = p_data-waers
        to_currncy = 'CNY'
        date       = sy-datum
      IMPORTING
        exch_rate  = ls_exch_rate
        return     = ls_return.
    p_data-netpr_cny = p_data-netpr * ls_exch_rate-exch_rate.
    p_data-waers_cny = 'CNY'.
    "TWD
    CALL FUNCTION 'BAPI_EXCHANGERATE_GETDETAIL'
      EXPORTING
        rate_type  = 'M'
        from_curr  = p_data-waers
        to_currncy = 'TWD'
        date       = sy-datum
      IMPORTING
        exch_rate  = ls_exch_rate
        return     = ls_return.
    p_data-netpr_twd = p_data-netpr * ls_exch_rate-exch_rate.
    p_data-waers_twd = 'TWD'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_po_price
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> P_DATA
*&---------------------------------------------------------------------*
FORM get_po_price  USING    p_data  LIKE LINE OF gt_data.
  DATA:lv_from TYPE sy-datum,
       lv_to   TYPE sy-datum.
  DATA:lv_factor TYPE isoc_factor.
  lv_from = p_data-calc_date(6) && '01'.
  CALL FUNCTION 'RP_LAST_DAY_OF_MONTHS'
    EXPORTING
      day_in            = lv_from
    IMPORTING
      last_day_of_month = lv_to
    EXCEPTIONS
      day_in_no_date    = 1
      OTHERS            = 2.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.
  SELECT SINGLE MAX( ekpo~netpr ) AS netpr,ekpo~peinh,ekko~waers FROM ekpo
    INNER JOIN ekko ON ekko~ebeln = ekpo~ebeln
    WHERE matnr = @p_data-idnrk
      AND werks = @p_data-werks
      AND ekko~loekz IS INITIAL
      AND ekko~aedat BETWEEN @lv_from AND @lv_to
  GROUP BY ekko~waers,ekpo~peinh
  INTO @DATA(ls_po)
.
  IF ls_po-netpr IS NOT INITIAL.
    CALL FUNCTION 'CURRENCY_CONVERTING_FACTOR'
      EXPORTING
        currency          = ls_po-waers
      IMPORTING
        factor            = lv_factor
      EXCEPTIONS
        too_many_decimals = 1
        OTHERS            = 2.
    IF sy-subrc <> 0.
* Implement suitable error handling here
    ENDIF.

    p_data-netpr = ls_po-netpr * lv_factor.
    p_data-waers = ls_po-waers.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_info_record
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- P_DATA
*&---------------------------------------------------------------------*
FORM get_info_record  CHANGING p_data LIKE LINE OF gt_data.
  DATA:lv_factor TYPE isoc_factor.

  SELECT SINGLE eine~effpr,eine~waers,eine~peinh FROM eine
    INNER JOIN eina ON eine~infnr = eina~infnr
    WHERE eina~matnr = @p_data-idnrk
      AND eine~werks = @p_data-werks
      AND eina~lifnr = @p_data-zdefault_vendor
      AND eine~esokz = '0'
      AND eina~loekz IS INITIAL
  INTO @DATA(ls_info).
  IF sy-subrc = 0.
    CALL FUNCTION 'CURRENCY_CONVERTING_FACTOR'
      EXPORTING
        currency          = ls_info-waers
      IMPORTING
        factor            = lv_factor
      EXCEPTIONS
        too_many_decimals = 1
        OTHERS            = 2.
    IF sy-subrc <> 0.
* Implement suitable error handling here
    ENDIF.
    p_data-netpr = ls_info-effpr / ls_info-peinh * lv_factor.
    p_data-waers = ls_info-waers.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_std_cost
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- P_DATA
*&---------------------------------------------------------------------*
FORM get_std_cost  CHANGING p_data LIKE LINE OF gt_data.
  DATA:lv_factor TYPE isoc_factor.
  SELECT stprs,peinh,waers
    FROM ckmlcr INNER JOIN ckmlhd ON ckmlcr~kalnr = ckmlhd~kalnr
  WHERE ckmlcr~curtp = '10'
    AND ckmlhd~matnr = @p_data-idnrk
    AND ckmlhd~bwkey = @p_data-werks
  ORDER BY ckmlcr~bdatj DESCENDING, ckmlcr~poper DESCENDING
  INTO @DATA(ls_cost) UP TO 1 ROWS.
    CALL FUNCTION 'CURRENCY_CONVERTING_FACTOR'
      EXPORTING
        currency          = ls_cost-waers
      IMPORTING
        factor            = lv_factor
      EXCEPTIONS
        too_many_decimals = 1
        OTHERS            = 2.
    IF sy-subrc <> 0.
* Implement suitable error handling here
    ENDIF.
    p_data-netpr = ls_cost-stprs / ls_cost-peinh * lv_factor.
    p_data-waers = ls_cost-waers.
  ENDSELECT.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_extra_sup
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- LS_DATA
*&---------------------------------------------------------------------*
FORM get_extra_mrp  CHANGING p_data LIKE LINE OF gt_data.
  DATA:lv_extra LIKE p_data-stock_qty.
  DATA:lr_delkz_sup TYPE RANGE OF delkz,
       lr_delkz_dem TYPE RANGE OF delkz.
  "多餘供給：抓取ZTPPRP0019，以該料號+工廠+當天日期找到多筆進行累加
  SELECT SUM( quantity ) FROM ztpprp0019
    WHERE article_long = @p_data-idnrk
      AND ztpprp0019~plant = @p_data-werks
      AND zdsdat = @p_data-calc_date
      AND deletion_flag IS INITIAL
  INTO @lv_extra.


  "MRP 總需求/總供給
  lr_delkz_sup = VALUE #( sign = 'I' option = 'EQ'
                            ( low = 'PA' ) "計劃單
                            ( low = 'FE' ) "工單
                            ( low = 'WB' ) "未限制使用庫存
                            ( low = 'LK' ) "供應商庫存
                            ( low = 'QM' ) "檢驗批
                            ( low = 'BA' ) "請購單-市購
                            ( low = 'BA' ) "請購單-外包
                            ( low = 'E1' ) "採購單-市購
                            ( low = 'E1' ) "採購單-外包
                            ( low = 'E1' ) "STO 單收貨廠
                            ( low = 'E1' ) "STO 單收貨廠-外包
                            ( low = 'VJ' ) "交貨單 (Inboound DN)

                        ).
  lr_delkz_dem = VALUE #( sign = 'I' option = 'EQ'
                            ( low = 'VC' ) "銷售訂單
                            ( low = 'VC' ) "出貨單 (Outbound DN)
                            ( low = 'PP' ) "計劃性獨立需求
                            ( low = 'AR' ) "計劃單元件需求
                            ( low = 'AR' ) "工單元件需求
                            "( low = '' ) "限制使用庫存 (Blocked Stock)
                            ( low = 'BB' ) "請購單元件需求-外包
                            ( low = 'BB' ) "採購單元件需求-外包
                            ( low = 'UR' ) "STO 單發貨廠
                            ( low = 'UR' ) "STO 單發貨廠-外包
                            ( low = 'UR' ) "STO 單元件需求-外包 ???
                            ( low = 'MR' ) "人工開立預留單
                            ( low = 'SF' ) "安全存量
  ).
  "總供給
  SELECT zdsdat,SUM( mng01 ) AS mng01 FROM ztpprp0011
    WHERE matnr = @p_data-idnrk
      AND mdwrk = @p_data-werks
      AND mdber = @p_data-werks
      AND delkz IN @lr_delkz_sup
      AND zdsdat = @p_data-calc_date
  GROUP BY zdsdat,zdsdatno
    ORDER BY zdsdat DESCENDING, zdsdatno DESCENDING
  INTO TABLE @DATA(lt_sup).
  READ TABLE lt_sup INTO DATA(ls_sup) INDEX 1.

  "總需求
  SELECT zdsdat,SUM( mng01 ) AS mng01 FROM ztpprp0011
    WHERE matnr = @p_data-idnrk
      AND mdwrk = @p_data-werks
      AND mdber = @p_data-werks
      AND delkz IN @lr_delkz_dem
      AND zdsdat = @p_data-calc_date
  GROUP BY zdsdat,zdsdatno
    ORDER BY zdsdat DESCENDING, zdsdatno DESCENDING
  INTO TABLE @DATA(lt_dem).
  READ TABLE lt_dem INTO DATA(ls_dem) INDEX 1.
  IF sy-subrc = 0.
    p_data-tot_req_qty = ls_sup-mng01.
  ENDIF.
  "多階行動 - 總供給
  p_data-bmeng = lv_extra - ls_sup-mng01.

  "在途量(PO&SC)

  SELECT zdsdat,SUM( mng01 ) AS mng01 FROM ztpprp0011
    WHERE matnr = @p_data-idnrk
      AND mdwrk = @p_data-werks
      AND mdber = @p_data-werks
      AND delkz = 'E1'
      AND zdsdat = @p_data-calc_date
  GROUP BY zdsdat,zdsdatno
    ORDER BY zdsdat DESCENDING, zdsdatno DESCENDING
  INTO TABLE @DATA(lt_sub).
  READ TABLE lt_sub INTO DATA(ls_sub) INDEX 1.
  IF sy-subrc = 0.
    p_data-sub_qty = ls_sub-mng01.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form collect_upd_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM collect_upd_data .
  CLEAR gt_data.
  DATA:lv_max_xjitem TYPE ztcx0004-xj_item.
  READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
  LOOP AT gt_report INTO DATA(ls_d1) GROUP BY ( xj = ls_d1-xj ) INTO DATA(lg_report).
    CLEAR:lv_max_xjitem.
    SELECT MAX( xj_item ) FROM ztcx0004
      WHERE xj = @lg_report-xj
    INTO @lv_max_xjitem.
    LOOP AT GROUP lg_report INTO DATA(ls_report).
      SELECT SINGLE beskz,sobsl FROM marc
        WHERE matnr = @ls_report-idnrk
          AND werks = @ls_report-werks
      INTO @DATA(ls_marc).



      IF ls_role-role = 'A'."生管
        IF ls_marc-beskz = 'E'.
          "生管只能確認自製件
          SELECT SINGLE * FROM ztcx0004
            WHERE xj = @ls_report-xj
              AND xj_item = @ls_report-xj_item
          INTO @DATA(ls_db).
          IF sy-subrc = 0.
            APPEND INITIAL LINE TO gt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
            MOVE-CORRESPONDING ls_db TO <ls_data>.
            <ls_data>-stock_qty = ls_report-stock_qty.
            <ls_data>-pp_remark = ls_report-pp_remark.
            <ls_data>-sel = 'X'.
          ELSE.
            APPEND INITIAL LINE TO gt_data ASSIGNING <ls_data>.

            MOVE-CORRESPONDING ls_report TO <ls_data>.
*20260616 V004 JLO 新列採購屬性(beskz/sobsl)一律取物料主檔,忽略Excel採購屬性
            <ls_data>-beskz = ls_marc-beskz.
            <ls_data>-sobsl = ls_marc-sobsl.
            IF ls_report-xj_item IS INITIAL.
              ADD 1 TO lv_max_xjitem.
              <ls_data>-xj_item = lv_max_xjitem.
            ENDIF.
            <ls_data>-sel = 'X'.
            <ls_data>-bdmng = ls_report-stock_qty.
            <ls_data>-xj_erdat = sy-datum.
            <ls_data>-xj_ertim = sy-uzeit.
            <ls_data>-xj_ernam = sy-uname.
            "V007 上傳新列補訂單表頭展開廠(werks_so);子件廠仍為 werks
            SELECT SINGLE werks FROM vbap
              WHERE vbeln = @<ls_data>-vbeln AND posnr = @<ls_data>-posnr
              INTO @<ls_data>-werks_so.
          ENDIF.

        ENDIF.
      ELSEIF ls_role-role = 'C'."採購
        IF ls_marc-beskz = 'F' OR ls_marc-beskz = 'E'.
          "採購只能確認採購件
          SELECT SINGLE * FROM ztcx0004
            WHERE xj = @ls_report-xj
              AND xj_item = @ls_report-xj_item
          INTO @ls_db.
          IF sy-subrc = 0.
            APPEND INITIAL LINE TO gt_data ASSIGNING <ls_data>.
            MOVE-CORRESPONDING ls_db TO <ls_data>.
            <ls_data>-stock_qty = ls_report-stock_qty.
            <ls_data>-pur_remark = ls_report-pur_remark.
            IF ls_report-netpr IS NOT INITIAL.
              <ls_data>-netpr = ls_report-netpr.
            ELSE.
              <ls_data>-msg = '採購上傳單價不能為0'.
            ENDIF.

*20260611 JosephLo 上傳幣別空白時保留DB既有幣別,避免重匯入洗掉採購已維護幣別
            IF ls_report-waers IS NOT INITIAL.
              <ls_data>-waers = ls_report-waers.
            ENDIF.
            <ls_data>-sel = 'X'.
          ELSE.
            APPEND INITIAL LINE TO gt_data ASSIGNING <ls_data>.

            MOVE-CORRESPONDING ls_report TO <ls_data>.
*20260616 V004 JLO 新列採購屬性(beskz/sobsl)一律取物料主檔,忽略Excel採購屬性
            <ls_data>-beskz = ls_marc-beskz.
            <ls_data>-sobsl = ls_marc-sobsl.
            IF ls_report-xj_item IS INITIAL.
              ADD 1 TO lv_max_xjitem.
              <ls_data>-xj_item = lv_max_xjitem.
            ENDIF.
            <ls_data>-sel = 'X'.
            <ls_data>-bdmng = ls_report-stock_qty.
            <ls_data>-xj_erdat = sy-datum.
            <ls_data>-xj_ertim = sy-uzeit.
            <ls_data>-xj_ernam = sy-uname.
            "V007 上傳新列補訂單表頭展開廠(werks_so);子件廠仍為 werks
            SELECT SINGLE werks FROM vbap
              WHERE vbeln = @<ls_data>-vbeln AND posnr = @<ls_data>-posnr
              INTO @<ls_data>-werks_so.
          ENDIF.

        ENDIF.
      ENDIF.
      "業務金額 = 業務單價 x 該張單報 MOQ or XJ 的數量
      <ls_data>-sales_amt = <ls_data>-sales_netpr * <ls_data>-stock_qty.
    ENDLOOP.
  ENDLOOP.
  CLEAR gt_report.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_trans_qty
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- LS_DATA
*&---------------------------------------------------------------------*
FORM get_trans_qty  CHANGING p_data LIKE LINE OF gt_data.
  SELECT SINGLE * FROM ztcx0005
    WHERE matnr = @p_data-idnrk
      AND werks = @p_data-werks
      AND zdsdat = @p_data-calc_date
    INTO @DATA(ls_005).
  IF sy-subrc = 0.
    p_data-ztrans_qty = ls_005-stock_qty.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form check_auth
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM check_auth .
  IF p_imp IS NOT INITIAL OR p_upd IS NOT INITIAL OR p_mod IS NOT INITIAL.
    AUTHORITY-CHECK OBJECT 'Z_CX01'
    ID 'ACTVT' FIELD '01'.
    IF sy-subrc <> 0.
      MESSAGE s007 DISPLAY LIKE 'E'.
      LEAVE TO TRANSACTION sy-tcode.
    ENDIF.
  ELSEIF p_dis IS NOT INITIAL.
    AUTHORITY-CHECK OBJECT 'Z_CX01'
    ID 'ACTVT' FIELD '03'.
    IF sy-subrc <> 0.
      MESSAGE s008 DISPLAY LIKE 'E'.
      LEAVE TO TRANSACTION sy-tcode.
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form lock_xj
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM lock_xj .
  IF gt_filtered IS NOT INITIAL.
    LOOP AT gt_filtered INTO DATA(lv_index).
      READ TABLE gt_data ASSIGNING FIELD-SYMBOL(<ls_data>) INDEX lv_index.
      IF sy-subrc NE 0 .
        <ls_data>-xj_status = 'D'. "D-客戶確認中(資料鎖住)
      ENDIF.
    ENDLOOP.
  ELSE.
    LOOP AT gt_data ASSIGNING <ls_data> WHERE sel IS NOT INITIAL.
      <ls_data>-xj_status = 'D'. "D-客戶確認中(資料鎖住)
    ENDLOOP.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form unlock_xj
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM unlock_xj .
*  解鎖功能(還原 : 採購類型E，還原為B生管確認；採購類型F，還原為C採購確認)
  IF gt_filtered IS NOT INITIAL.
    LOOP AT gt_filtered INTO DATA(lv_index).
      READ TABLE gt_data ASSIGNING FIELD-SYMBOL(<ls_data>) INDEX lv_index.
      IF sy-subrc NE 0.
        IF <ls_data>-beskz = 'E'.
          <ls_data>-xj_status = 'B'.
        ELSEIF  <ls_data>-beskz = 'F'.
          <ls_data>-xj_status = 'C'.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ELSE.
    LOOP AT gt_data ASSIGNING <ls_data> WHERE sel IS NOT INITIAL.
      IF <ls_data>-beskz = 'E'.
        <ls_data>-xj_status = 'B'.
      ELSEIF  <ls_data>-beskz = 'F'.
        <ls_data>-xj_status = 'C'.
      ENDIF.
    ENDLOOP.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form noconfirm
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM noconfirm .
*  F-維持(不同意)
  IF gt_filtered IS NOT INITIAL.
    LOOP AT gt_filtered INTO DATA(lv_index).
      READ TABLE gt_data ASSIGNING FIELD-SYMBOL(<ls_data>) INDEX lv_index.
      IF sy-subrc NE 0.
        <ls_data>-xj_status = 'F'.
      ENDIF.
    ENDLOOP.
  ELSE.
    LOOP AT gt_data ASSIGNING <ls_data> WHERE sel IS NOT INITIAL.
      <ls_data>-xj_status = 'F'.
    ENDLOOP.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form confirm_1
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM confirm_1 .
  READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
  LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>) WHERE sel IS NOT INITIAL.
    CLEAR:<ls_data>-msg.

    CASE ls_role-role.
      WHEN 'A' .
        <ls_data>-pp_chg_date = sy-datum.
        <ls_data>-pp_uname = sy-uname.
        <ls_data>-pp_chg_time = sy-uzeit.
        <ls_data>-xj_status = 'D'.
      WHEN 'C'.
        <ls_data>-pur_chg_date = sy-datum.
        <ls_data>-pur_chg_time = sy-uzeit.
        <ls_data>-pur_uname = sy-uname.
        <ls_data>-xj_status = 'D'.
    ENDCASE.
    "Get full name from USER_ADDR
    PERFORM get_full_name_uname USING <ls_data>.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form check_confirm_1
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LV_SUBRC
*&---------------------------------------------------------------------*
FORM check_confirm_1  USING    p_subrc.
  "2.	當送出給業務時，針對「報庫存數量」> 0 的項次，檢查「幣別」有值且「料價」 > 0

  LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>) WHERE sel IS NOT INITIAL.
    IF <ls_data>-stock_qty > 0.
      IF <ls_data>-waers IS NOT INITIAL AND <ls_data>-netpr > 0.

      ELSE.
        <ls_data>-msg = '錯誤!「幣別」必須輸入，「料價」 必須 > 0'.
        CONTINUE.
      ENDIF.
    ENDIF.
  ENDLOOP.

  IF NOT line_exists( gt_data[ msg = '' ] ).
    p_subrc = 4.
  ELSE.
    p_subrc = 0.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_sales_price
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LS_DATA
*&---------------------------------------------------------------------*
FORM get_sales_price  USING     p_data LIKE LINE OF gt_data.
  DATA:i_vtweg     TYPE vtweg,
       i_matkl     TYPE matkl,
       i_zpno      TYPE zpno,
       i_zpnocode  TYPE zpnocode,
       i_meins     TYPE meins,
       i_zmoqline  TYPE zmoqline,
       i_prsdt     TYPE prsdt,
       i_zpcur     TYPE zpcur,
       i_zpup      TYPE zpup,
       i_zpup_per  TYPE zpup_per,
       i_zpcnyup   TYPE zpcnyup,
       i_zpcny_per TYPE zpcny_per,
       i_zptwdup   TYPE zptwdup,
       i_zptwd_per TYPE zptwd_per.
  DATA: e_zup_cur TYPE zusdcur,
        e_zup     TYPE zup9,
        e_zup_per TYPE zup_per.
  i_vtweg = p_data-vtweg.
  i_zpno = p_data-idnrk.
  i_zpnocode = 'M'.
  i_meins = p_data-meins.
  i_prsdt = sy-datum."p_data-xj_erdat.
  i_zpcur = p_data-waers.
  i_zpup = 100 * p_data-netpr.
  i_zpup_per = 100.
  "IF p_data-waers = 'CNY'.
  i_zpcnyup = 100 * p_data-netpr_cny.
  i_zpcny_per = 100.
  "ELSEIF p_data-waers = 'TWD'.
  i_zptwdup =  p_data-netpr_twd.
  i_zptwd_per = 100.
  "ENDIF.

  CALL FUNCTION 'ZSD_ODM_XQ_PRICE'
    EXPORTING
      i_vtweg     = i_vtweg
      i_matkl     = i_matkl
      i_zpno      = i_zpno
      i_zpnocode  = i_zpnocode
      i_meins     = i_meins
      i_zmoqline  = i_zmoqline
      i_prsdt     = i_prsdt
      i_zpcur     = i_zpcur
      i_zpup      = i_zpup
      i_zpup_per  = i_zpup_per
      i_zpcnyup   = i_zpcnyup
      i_zpcny_per = i_zpcny_per
      i_zptwdup   = i_zptwdup
      i_zptwd_per = i_zptwd_per
*     I_ZTSD0107  =
    IMPORTING
*     E_ZCALCUR   =
*     E_ZFORMULATYPE       =
      e_zup_cur   = e_zup_cur
      e_zup       = e_zup
      e_zup_per   = e_zup_per
*     E_ZUPFORMULA         =
*     E_ZTSD0107  =
    .
  "業務幣別
  p_data-sales_waers = e_zup_cur.


  "業務單價
  p_data-sales_netpr = e_zup / e_zup_per.

  "業務金額 = 業務單價 x 該張單報 MOQ or XJ 的數量
  p_data-sales_amt = p_data-sales_netpr * p_data-stock_qty.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form calc_sales
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM calc_sales .
  LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>) WHERE sel IS NOT INITIAL.
    "料價/幣別
    "IF <ls_data>-waers IS INITIAL OR <ls_data>-netpr IS INITIAL.
    PERFORM default_netpr CHANGING <ls_data>.
    "ENDIF.
    "業務幣別	業務單價
    PERFORM get_sales_price USING <ls_data>.
  ENDLOOP.
ENDFORM.

FORM update_alv_fields
  USING    is_key TYPE ty_key
  CHANGING cs_alv TYPE zscx0003_alv.

  "==== ZTMARA：完整規格 / 英文規格 / 品名 ====
  DATA: lv_wl2_spec    TYPE ztmara-wl2_erpspecification,
        lv_wl2_spec_en TYPE ztmara-wl2_englishspecifications,
        lv_the_name    TYPE ztmara-wl2_thenameoftheerp.

  IF cs_alv-wl2_erpspecification       IS INITIAL OR cs_alv-wl2_erpspecification = space
   OR cs_alv-wl2_englishspecifications IS INITIAL OR cs_alv-wl2_englishspecifications = space
   OR cs_alv-maktx                     IS INITIAL OR cs_alv-maktx = space.

    SELECT SINGLE
           wl2_erpspecification,
           wl2_englishspecifications,
           wl2_thenameoftheerp
      INTO (@lv_wl2_spec, @lv_wl2_spec_en, @lv_the_name)
      FROM ztmara
     WHERE matnr = @is_key-matnr.

    IF ( cs_alv-wl2_erpspecification IS INITIAL OR cs_alv-wl2_erpspecification = space )
       AND lv_wl2_spec IS NOT INITIAL.
      cs_alv-wl2_erpspecification = lv_wl2_spec.
    ENDIF.

    IF ( cs_alv-wl2_englishspecifications IS INITIAL OR cs_alv-wl2_englishspecifications = space )
       AND lv_wl2_spec_en IS NOT INITIAL.
      cs_alv-wl2_englishspecifications = lv_wl2_spec_en.
    ENDIF.

    IF ( cs_alv-maktx IS INITIAL OR cs_alv-maktx = space )
       AND lv_the_name IS NOT INITIAL.
      cs_alv-maktx = lv_the_name.
    ENDIF.
  ENDIF.

  "==== ZTMARC：預設供應商 ====
  IF cs_alv-zdefault_vendor IS INITIAL OR cs_alv-zdefault_vendor = space.
    SELECT SINGLE zdefault_vendor
      INTO @cs_alv-zdefault_vendor
      FROM ztmarc
     WHERE matnr = @is_key-matnr
       AND werks = @is_key-werks.
  ENDIF.

  "==== LFA1：供應商中文名稱 ====
  DATA lv_lifnr_alpha TYPE lfa1-lifnr.
  IF ( cs_alv-name1 IS INITIAL OR cs_alv-name1 = space )
     AND cs_alv-zdefault_vendor IS NOT INITIAL.
    lv_lifnr_alpha = cs_alv-zdefault_vendor.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = lv_lifnr_alpha
      IMPORTING
        output = lv_lifnr_alpha.

    SELECT SINGLE name1
      INTO @cs_alv-name1
      FROM lfa1
     WHERE lifnr = @lv_lifnr_alpha.
  ENDIF.

  "==== PIR：NETPR/PEINH/WAERS (僅限市購 F+空) ====
  IF ( cs_alv-netpr IS INITIAL OR cs_alv-netpr = 0
    OR cs_alv-waers IS INITIAL OR cs_alv-waers = space )
    AND cs_alv-beskz = 'F'
    AND ( cs_alv-sobsl IS INITIAL OR cs_alv-sobsl = space ).

    IF cs_alv-zdefault_vendor IS NOT INITIAL.
      lv_lifnr_alpha = cs_alv-zdefault_vendor.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING
          input  = lv_lifnr_alpha
        IMPORTING
          output = lv_lifnr_alpha.

      DATA: lv_netpr TYPE eine-netpr,
            lv_peinh TYPE eine-peinh,
            lv_waers TYPE eine-waers.

      CLEAR: lv_netpr, lv_peinh, lv_waers.
      SELECT SINGLE
             eine~netpr,
             eine~peinh,
             eine~waers
        INTO (@lv_netpr, @lv_peinh, @lv_waers)
        FROM eina
        INNER JOIN eine ON eine~infnr = eina~infnr
       WHERE eina~matnr = @is_key-matnr
         AND eina~lifnr = @lv_lifnr_alpha
         AND eine~werks = @is_key-werks
         AND eine~loekz = ''.

      IF sy-subrc = 0
         AND lv_peinh IS NOT INITIAL.

        DATA(lv_price_df) = CONV decfloat34( lv_netpr ).
        DATA(lv_peinh_df) = CONV decfloat34( lv_peinh ).

        IF lv_peinh_df <> 0.
          lv_price_df = lv_price_df / lv_peinh_df.

          " 只在 ALV 金額空白或 = 0 時補值
          IF cs_alv-netpr IS INITIAL OR cs_alv-netpr = 0.
            cs_alv-netpr = round(
                              val  = lv_price_df
                              dec  = 6
                              mode = cl_abap_math=>round_half_up ).
          ENDIF.

          " 只在幣別空白時補值
          IF ( cs_alv-waers IS INITIAL OR cs_alv-waers = space )
             AND lv_waers IS NOT INITIAL.
            cs_alv-waers = lv_waers.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form append_new_matnr
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
FORM append_new_matnr .
*  DATA: BEGIN OF it_matnr OCCURS 0,
*          vbeln     TYPE vbeln,
*          posnr     TYPE posnr,
*          matnr     TYPE matnr,
*          vtweg     TYPE vtweg,
*          kunnr     TYPE kunnr,
*          vrkme     TYPE vrkme,
*          zseq      TYPE zcxseq,
*          skuitem   TYPE zcn,
*          calc_date TYPE zcalc_date,
*          canc_qty  TYPE zcx_canc_qty,
*        END OF it_matnr.
**先彙整要新增的組件列
*  LOOP AT gt_data INTO ls_data.
*    READ TABLE it_matnr WITH KEY vbeln = ls_data-vbeln
*                                                  posnr = ls_data-posnr
*                                                  matnr = ls_data-matnr.
*    IF sy-subrc <> 0.
*      MOVE-CORRESPONDING ls_data TO it_matnr.
*      APPEND it_matnr.
*    ENDIF.
*  ENDLOOP.
*
**然後開始新增列並處理欄位
*  LOOP AT it_matnr.
*    CLEAR : ls_data.
*    MOVE-CORRESPONDING it_matnr TO ls_data.
*
*    SELECT SINGLE werks INTO @ls_data-werks FROM vbap
*         WHERE  vbeln = @ls_data-vbeln
*              AND  posnr = @ls_data-posnr.
*
*    SELECT SINGLE wl2_erpspecification,maktx,wl2_englishspecifications,mara~meins
*         FROM ztmara INNER JOIN makt
*         ON ztmara~matnr = makt~matnr AND makt~spras = @sy-langu
*         INNER JOIN mara ON ztmara~matnr = mara~matnr
*         WHERE ztmara~matnr = @ls_data-matnr
*       INTO CORRESPONDING FIELDS OF @ls_data.
*
*    SELECT SINGLE ztmarc~zdefault_vendor,
*                   lfa1~name1
*       FROM ztmarc INNER JOIN lfa1 ON ztmarc~zdefault_vendor = lfa1~lifnr
*     WHERE ztmarc~werks = @ls_data-werks
*       AND ztmarc~matnr = @ls_data-matnr
*     INTO ( @ls_data-zdefault_vendor,@ls_data-name1 ).
*
*    SELECT SINGLE beskz, sobsl INTO ( @ls_data-beskz, @ls_data-sobsl  )
*       FROM marc
*       WHERE matnr = @ls_data-matnr
*         AND werks = @ls_data-werks.
*
*    IF ls_data-beskz = 'F' AND ls_data-sobsl IS INITIAL.
*      SELECT SINGLE ekgrp FROM eina
*        INNER JOIN eine ON eina~infnr = eine~infnr
*      WHERE eina~matnr = @ls_data-matnr
*        AND eine~werks = @ls_data-werks
*        AND eina~lifnr = @ls_data-zdefault_vendor
*        AND eine~esokz = '0'
*        AND eine~loekz IS INITIAL
*      INTO @ls_data-ekgrp.
*    ELSEIF ls_data-beskz = 'F' AND ls_data-sobsl ='30'.
*      SELECT SINGLE ekgrp FROM eina
*        INNER JOIN eine ON eina~infnr = eine~infnr
*      WHERE eina~matnr = @ls_data-matnr
*        AND eine~werks = @ls_data-werks
*        AND eina~lifnr = @ls_data-zdefault_vendor
*        AND eine~esokz = '3'
*        AND eine~loekz IS INITIAL
*      INTO @ls_data-ekgrp.
*    ENDIF.
*
*     "先將組件寫到元件的
*
*  ENDLOOP.

ENDFORM.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
