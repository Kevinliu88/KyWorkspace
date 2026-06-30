*----------------------------------------------------------------------*
***INCLUDE ZTGCX0001_SUB.
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

  MOVE 'ZTGCX0001' TO lv_obj_name.
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
             c_endcol TYPE i VALUE 6,
             c_endrow TYPE i VALUE 65000.
  DATA:lv_endcol TYPE i.
  DATA: BEGIN OF i_intern OCCURS 0.
          INCLUDE STRUCTURE  alsmex_tabline.
  DATA:  END OF i_intern.
  DATA:lv_index TYPE sy-index.

  REFRESH i_intern.
  lv_filename = p_file.
  IF p_imp IS NOT INITIAL.
    lv_endcol = 7.
  ELSE.
    lv_endcol = 56.
  ENDIF.
  CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
    EXPORTING
      filename                = lv_filename
      i_begin_col             = c_begcol
      i_begin_row             = c_begrow
      i_end_col               = lv_endcol
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
  DATA:ls_upload LIKE LINE OF gt_upload.
  DATA:ls_report LIKE LINE OF gt_report.
  TRY.
      IF p_imp IS NOT INITIAL.
        LOOP AT i_intern WHERE row > 2.
          MOVE i_intern-col TO lv_index.
          ASSIGN COMPONENT lv_index OF STRUCTURE ls_upload TO <fs>.
          IF lv_index = 5.

            CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
              EXPORTING
                date_external            = i_intern-value
*               ACCEPT_INITIAL_DATE      =
              IMPORTING
                date_internal            = <fs>
              EXCEPTIONS
                date_external_is_invalid = 1
                OTHERS                   = 2.
            IF sy-subrc <> 0.
              REPLACE ALL OCCURRENCES OF '-' IN i_intern-value WITH space.
              REPLACE ALL OCCURRENCES OF '/' IN i_intern-value WITH space.
              <fs> = i_intern-value(8).
            ENDIF.

          ELSE.
            MOVE i_intern-value TO <fs>.
          ENDIF.
          AT END OF row.
            ls_upload-matnr = |{ ls_upload-matnr ALPHA = IN CASE = UPPER }|.
            APPEND ls_upload TO gt_upload.
            CLEAR ls_upload.
          ENDAT.
        ENDLOOP.
      ELSE.
        DATA:ls_upload_a TYPE zscx0001_alv_a."生管上傳格式
        READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
        LOOP AT i_intern WHERE row > 1.
          MOVE i_intern-col TO lv_index.
          lv_index = lv_index + 3.
          IF ls_role-role = 'A'."生管
            ASSIGN COMPONENT lv_index OF STRUCTURE ls_upload_a TO <fs>.
          ELSE.
            ASSIGN COMPONENT lv_index OF STRUCTURE ls_report TO <fs>.
          ENDIF.
          REPLACE ALL OCCURRENCES OF ',' IN i_intern-value WITH space.
          IF lv_index = 19.
            REPLACE ALL OCCURRENCES OF '-' IN i_intern-value WITH space.
            REPLACE ALL OCCURRENCES OF '/' IN i_intern-value WITH space.
            <fs> = i_intern-value(8).
          ELSE.
            MOVE i_intern-value TO <fs>.
          ENDIF.
          AT END OF row.
            IF ls_role-role = 'A'.
              MOVE-CORRESPONDING ls_upload_a TO ls_report.
            ENDIF.
            APPEND ls_report TO gt_report.
            CLEAR ls_report.
          ENDAT.
        ENDLOOP.
      ENDIF.
    CATCH cx_root INTO exception.
      MESSAGE 'Excel data format is wrong,please check' TYPE 'E'.
  ENDTRY.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form convert_upload_2_itab
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM check_upload_data .


  LOOP AT gt_upload ASSIGNING FIELD-SYMBOL(<ls_upload>).


    IF <ls_upload>-matnr IS INITIAL.
      <ls_upload>-zmsg = '大貨件號必填'.
      CONTINUE.
    ELSE.

      <ls_upload>-matnr = |{ <ls_upload>-matnr ALPHA = IN }|.
      SELECT SINGLE matnr FROM mara WHERE matnr = @<ls_upload>-matnr INTO @DATA(lv_matnr).
      IF sy-subrc NE 0.
        <ls_upload>-zmsg = '料號主檔不存在'.
        CONTINUE.
      ENDIF.
    ENDIF.
    SELECT SINGLE mstae FROM mara
      WHERE matnr = @<ls_upload>-matnr
    INTO @DATA(lv_mstae).
    IF lv_mstae NP '*A*'.
* 20260522 JosephLo 需求3：單個(無BOM)零件市購F件號(非1120/2120兩廠互買)，W狀態也允許上傳 Start
      DATA(lv_allow_w) = abap_false.
      IF lv_mstae = 'W' AND <ls_upload>-werks IS NOT INITIAL.
        " (a) 單個零件 = 沒有 BOM（該料號在該廠 MAST 無連結）
        SELECT SINGLE matnr FROM mast
          WHERE matnr = @<ls_upload>-matnr
            AND werks = @<ls_upload>-werks
          INTO @DATA(lv_mast).
        IF sy-subrc <> 0.
          " (b) 市購F(非F30) 且 非1120/2120兩廠互買
          " marc 為主、ztmarc 改 LEFT JOIN：市購F件常未在 ztmarc 維護預設供應商，
          " 而「未維護(空)」本就屬於非1120/2120兩廠互買，故不可用 INNER JOIN / IS NOT INITIAL 擋
          SELECT SINGLE marc~beskz, marc~sobsl, ztmarc~zdefault_vendor
            FROM marc
            LEFT OUTER JOIN ztmarc ON  ztmarc~matnr = marc~matnr
                                   AND ztmarc~werks = marc~werks
            WHERE marc~matnr = @<ls_upload>-matnr
              AND marc~werks = @<ls_upload>-werks
            INTO ( @DATA(lv_beskz), @DATA(lv_sobsl), @DATA(lv_defven) ).
          IF sy-subrc = 0
             AND lv_beskz  = 'F'
             AND lv_sobsl  = ''
             AND lv_defven <> '0000011200'
             AND lv_defven <> '0000021200'.
            lv_allow_w = abap_true.
* 20260524 JosephLo 階段3 W統一：不再記 gt_self_moq；放行後由 assign_rem_data(lines(lt_stpox)=0)
*   統一處理(查 ZTSD0020 客戶型號→有則建自身項報MOQ、無則出口5異常)。
          ENDIF.
        ENDIF.
      ENDIF.
      IF lv_allow_w = abap_false.
        <ls_upload>-zmsg = '成品物料的跨廠物料狀態不為A，不允許上傳'.
        CONTINUE.
      ENDIF.
* 20260522 JosephLo 需求3 End
    ENDIF.
    IF <ls_upload>-vtweg IS INITIAL.
      <ls_upload>-zmsg = '預採帳客戶別代碼必填'.
      CONTINUE.
    ELSE.
*      <ls_upload>-kunnr = |{ <ls_upload>-kunnr ALPHA = IN }|.
*      SELECT SINGLE partner FROM but000 WHERE partner = @<ls_upload>-kunnr INTO @DATA(lv_partner).
*      IF sy-subrc NE 0.
*        <ls_upload>-zmsg = 'BP主檔不存在'.
*        CONTINUE.
*      ENDIF.
      SELECT SINGLE * FROM tvtw WHERE vtweg = @<ls_upload>-vtweg INTO @DATA(ls_tvtw).
      IF sy-subrc NE 0.
        <ls_upload>-zmsg = '通路主檔不存在'.
        CONTINUE.
      ENDIF.
      READ TABLE gt_custmap WITH KEY vtweg = <ls_upload>-vtweg werks = <ls_upload>-werks TRANSPORTING NO FIELDS.
      IF sy-subrc NE 0.
        <ls_upload>-zmsg = '通路+工廠未維護於預採帳客戶資訊(ZTGCX0008)'.
        CONTINUE.
      ENDIF.
    ENDIF.
    IF <ls_upload>-werks IS INITIAL.
      <ls_upload>-zmsg = '工廠必填'.
      CONTINUE.
    ENDIF.
    IF <ls_upload>-menge IS INITIAL.
      <ls_upload>-zmsg = '大貨需求數量必填'.
      CONTINUE.
    ELSE.
      REPLACE ALL OCCURRENCES OF ',' IN <ls_upload>-menge WITH space .
    ENDIF.
    IF <ls_upload>-req_date IS INITIAL.
      <ls_upload>-zmsg = '需求日期必填'.
      CONTINUE.
    ENDIF.

    "針對詢單號碼的檢查 > 若該詢單號碼已存在、有相關的 QQ 單號產生、且詢單已轉正，
    "則提醒「該詢單號碼已存在、已轉正訂單 OOXX，不允許重新報 MOQ」；
    DATA:lv_ans TYPE c,
         lv_msg TYPE string.
    SELECT SINGLE * FROM ztcx0001
      WHERE zportalno = @<ls_upload>-zportalno
        AND qq IS NOT INITIAL
        AND qq_status = 'B'
        AND loekz IS INITIAL
    INTO @DATA(ls_prexist).
    IF sy-subrc = 0.
      lv_msg = '該詢單號碼已存在、已轉正訂單' && ls_prexist-vbeln &&' ，不允許重新報 MOQ'.
      <ls_upload>-zmsg = lv_msg.
      CONTINUE.
    ENDIF.
    "若該詢單號碼已存在、但未轉正，則提醒「該詢單號碼已存在，是否重新報 MOQ ?」Yes 則將清除該詢單記錄。
    READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
    IF ls_role-role = 'A'."生管
      SELECT SINGLE * FROM ztcx0001
        WHERE zportalno = @<ls_upload>-zportalno
*          AND qq IS NOT INITIAL
*          AND qq_status NE 'B'
          AND loekz IS INITIAL
          AND beskz = 'E'
* V016 Added by Tristan 2026/05/19 *
          AND ismoq = ''
* V016 End off *
      INTO @ls_prexist.
    ELSEIF ls_role-role = 'C'.
      SELECT SINGLE * FROM ztcx0001
        WHERE zportalno = @<ls_upload>-zportalno
*          AND qq IS NOT INITIAL
*          AND qq_status NE 'B'
          AND loekz IS INITIAL
          AND beskz = 'F'
* V016 Added by Tristan 2026/05/19 *
          AND ismoq = ''
* V016 End off *
      INTO @ls_prexist.
    ENDIF.
    IF sy-subrc = 0.
* V019 Changed by Tristan 2026/05/18 *
*      lv_msg = '該詢單號碼' && <ls_upload>-zportalno && '存在，是否重新報 MOQ ?'.
*      PERFORM pop_up_confirm  USING  '確認清除'(t10)
*                                     lv_msg
*                                     lv_ans.
*      IF lv_ans = '1'.
*        IF ls_role-role = 'A'."生管
*          DELETE FROM ztcx0001
*            WHERE zportalno = @<ls_upload>-zportalno
*              AND qq IS INITIAL
*              AND beskz = 'E'.
*        ELSEIF ls_role-role = 'C'.
*          DELETE FROM ztcx0001
*            WHERE zportalno = @<ls_upload>-zportalno
*              AND qq IS INITIAL
*              AND beskz = 'F'.
*        ENDIF.
*        COMMIT WORK AND WAIT.
*      ELSE.
*        <ls_upload>-zmsg = '該詢單號碼已存在'.
*        CONTINUE.
*      ENDIF.
* 20260524 JosephLo 階段3：詢單重複不再 MESSAGE+LEAVE 整批中斷，改標 zmsg
*   (本FORM結尾統一收集到 gt_excluded、從 gt_upload 移除)，其餘正常件續跑。
      <ls_upload>-zmsg = '該詢單號碼' && <ls_upload>-zportalno && '已存在，請先刪除'.
      CONTINUE.
*      PERFORM pop_up_confirm  USING  '確認執行'(t10)
*                                     lv_msg
*                                     lv_ans.
*      IF lv_ans <> '1'.
*        LEAVE LIST-PROCESSING.
*      ENDIF.
** 搬到存檔時再刪除
*      IF ls_role-role = 'A'."生管
*        SELECT * FROM ztcx0001
*         WHERE zportalno = @<ls_upload>-zportalno
*           AND qq IS INITIAL
*           AND beskz = 'E'
*               APPENDING TABLE @del_log.
*      ELSEIF ls_role-role = 'C'.
*        SELECT * FROM ztcx0001
*          WHERE zportalno = @<ls_upload>-zportalno
*            AND qq IS INITIAL
*            AND beskz = 'F'
*                APPENDING TABLE @del_log.
*      ENDIF.
* V019 End off *
    ENDIF.
  ENDLOOP.
* 20260526 JosephLo 檔案內重複卡控：同 客戶別(vtweg)+大貨件號(matnr)+工廠(werks)+詢單號碼(zportalno)
*   在上傳檔出現 ≥2 次 → 該 key 的「所有」列全部標「檔案重複」、都不進報表(請清理後重傳)，
*   隨下方 DELETE 移出 gt_upload，避免重複展BOM/重複計算。只比對通過前面檢查(zmsg 空)的列；
*   matnr 此時已 ALPHA 轉換、比對一致。
* 20260526 JosephLo 放行規則集中於 is_check_bypassed：若本次 t-code 對 'FILE_DUP' 放行，整段 skip。
  DATA lv_bp_filedup TYPE abap_bool.
  PERFORM is_check_bypassed USING 'FILE_DUP' CHANGING lv_bp_filedup.
  IF lv_bp_filedup = abap_false.
    TYPES: BEGIN OF ty_dupcnt,
             key TYPE string,
             cnt TYPE i,
           END OF ty_dupcnt.
    DATA lt_dup_cnt TYPE HASHED TABLE OF ty_dupcnt WITH UNIQUE KEY key.
* Pass1：統計每個 key 出現次數
    LOOP AT gt_upload ASSIGNING FIELD-SYMBOL(<dup>) WHERE zmsg IS INITIAL.
      DATA(lv_dupkey) = |{ <dup>-vtweg }#{ <dup>-matnr }#{ <dup>-werks }#{ <dup>-zportalno }|.
      READ TABLE lt_dup_cnt ASSIGNING FIELD-SYMBOL(<cnt>) WITH KEY key = lv_dupkey.
      IF sy-subrc = 0.
        <cnt>-cnt = <cnt>-cnt + 1.
      ELSE.
        INSERT VALUE #( key = lv_dupkey cnt = 1 ) INTO TABLE lt_dup_cnt.
      ENDIF.
    ENDLOOP.
* Pass2：出現 >1 次的 key，其所有列全部標檔案重複(全擋)
    LOOP AT gt_upload ASSIGNING <dup> WHERE zmsg IS INITIAL.
      lv_dupkey = |{ <dup>-vtweg }#{ <dup>-matnr }#{ <dup>-werks }#{ <dup>-zportalno }|.
      READ TABLE lt_dup_cnt ASSIGNING <cnt> WITH KEY key = lv_dupkey.
      IF sy-subrc = 0 AND <cnt>-cnt > 1.
        <dup>-zmsg = '檔案重複：同客戶別/大貨件號/工廠/詢單號碼在上傳檔出現多次，全部不予處理，請清理後重傳'.
      ENDIF.
    ENDLOOP.
  ENDIF.
* 20260524 JosephLo 階段3 L2部分通過：上傳檢查/詢單重複的錯誤列，統一收集到 gt_excluded
*   (供進主ALV前 popup 條列)後從 gt_upload 移除；剩餘正常件由 process_data 續展BOM。
*   sort_seq(重要性遞減,大者在前)：含「檔案重複」→99、含「詢單」→98、其餘→99 上傳檢查。menge 為 char 不轉避免 dump。
  LOOP AT gt_upload ASSIGNING FIELD-SYMBOL(<err>) WHERE zmsg IS NOT INITIAL.
    APPEND VALUE #( sort_seq  = COND #( WHEN <err>-zmsg CS '檔案重複' THEN '99'
                                        WHEN <err>-zmsg CS '詢單'     THEN '98'
                                        ELSE '99' )
                    category  = COND #( WHEN <err>-zmsg CS '檔案重複' THEN '檔案重複'
                                        WHEN <err>-zmsg CS '詢單'     THEN '詢單號重複'
                                        ELSE '上傳檢查' )
                    matnr_fg  = <err>-matnr
                    idnrk     = <err>-matnr
                    vtweg     = <err>-vtweg
                    werks     = <err>-werks
                    zportalno = <err>-zportalno
                    reason    = <err>-zmsg ) TO gt_excluded.
  ENDLOOP.
  DELETE gt_upload WHERE zmsg IS NOT INITIAL.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form display_alv
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> GT_DATA
*&---------------------------------------------------------------------*
FORM display_alv  USING  p_alv TYPE STANDARD TABLE.
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
* 20260616 JosephLo 各欄分開賦值(勿用鏈式 reptext=scrtext_s=...=&1):鏈式由右往左,reptext 會繼承
*   scrtext_s(CHAR10)已被截的值 → 欄名>10字(如「Liability結餘」)時 reptext/Excel下載標題變「Liability結」。
*   分開賦值後 reptext/scrtext_l/m 各取完整 &1(到自身長度),只有 scrtext_s 受 CHAR10 物理限制無法避免。
    <lfs_fcat>-scrtext_l = &1.
    <lfs_fcat>-scrtext_m = &1.
    <lfs_fcat>-scrtext_s = &1.
    <lfs_fcat>-reptext   = &1.
  END-OF-DEFINITION.

  lv_struc = 'ZSCX0001_ALV'.
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

  LOOP AT ct_fcat ASSIGNING FIELD-SYMBOL(<lfs_fcat>).

    CASE <lfs_fcat>-fieldname.
      WHEN 'MANDT'.
        <lfs_fcat>-tech = 'X'.
      WHEN 'LOEKZ'.
        <lfs_fcat>-checkbox = 'X'.
      WHEN 'REMARK_DEL'.
        IF p_mod IS NOT INITIAL.
          <lfs_fcat>-edit = 'X'.
        ENDIF.
      WHEN 'SALES_NETPR'.
        <lfs_fcat>-tech = 'X'.
      WHEN 'SEL'.
        IF p_imp IS NOT INITIAL OR p_mod IS NOT INITIAL OR p_upd IS NOT INITIAL.
          <lfs_fcat>-outputlen = '2'.
          <lfs_fcat>-edit = 'X'.
          <lfs_fcat>-checkbox = 'X'.
          set_field_text '勾選框'(f09).
        ELSEIF p_dis IS NOT INITIAL.
          <lfs_fcat>-tech = 'X'.
        ENDIF.
      WHEN 'ICON'.
        IF p_imp IS NOT INITIAL.
          set_field_text 'ICON'.
          <lfs_fcat>-icon = 'X'.
          <lfs_fcat>-outputlen = '4'.
        ELSE.
          <lfs_fcat>-tech = 'X'.
        ENDIF.
      WHEN 'NETPR_CNY'.
        set_field_text '料價(CNY)'(f15).
      WHEN 'NETPR_TWD'.
        set_field_text '料價(TWD)'(f16).
      WHEN 'VENDOR_NAME1'.
        set_field_text '供應商名稱'(f10).
      WHEN 'WL2_THENAMEOFTHEERP'.
        set_field_text '物料短文說明'(f11).
      WHEN 'MNGLG'.
        set_field_text '單位用量'(f12).
      WHEN 'PLIFZ'.
        set_field_text '前置時間'(f13).
      WHEN 'ZMOQ'.
        set_field_text 'MOQ基本資料'(f14).
        <lfs_fcat>-decimals_o = 0.
      WHEN 'ZMSG'.
        set_field_text '訊息'.
        IF p_dis IS NOT INITIAL.
          <lfs_fcat>-tech = 'X'.
        ENDIF.
      WHEN 'MOQ_CONFIRM'.
        IF p_imp IS NOT INITIAL OR p_upd IS NOT INITIAL.
          <lfs_fcat>-edit = 'X'.
        ENDIF.
      WHEN 'MOQ_QTY'.
        <lfs_fcat>-decimals_o = 0.
      WHEN 'QQ_ORI'.
        <lfs_fcat>-tech = 'X'.
* V023 Added by JosephLo 20260527 *
      WHEN 'MOQ_PRIOR_LINK'.
* V026 Changed by JosephLo 20260609 — §8 淨額重算不再用「前期結餘」滾動,此 hotspot 欄停用、隱藏不顯示。
*   欄位仍保留於結構(calc_moq_net 已 CLEAR 不填;'S' 理論庫存路徑 calc_7day_qq 仍會填,僅不顯示)。
*   原 V023 hotspot 設定(hotspot/outputlen/set_field_text '前期結餘 (點選)')停用。
*   雙擊 handler frm_double_click WHEN 'MOQ_PRIOR_LINK' 因欄位隱藏而觸發不到,保留無害。
        <lfs_fcat>-tech = 'X'.
      WHEN 'Z_BASIS_USED'.
        " 本期 MOQ 計算基準 — 純顯示,標示這列實際用了哪個基準(L/S/前期結餘)
        " 由 calc_7day_qq 在兩個分支內各自填值,使用者看 ALV 即知道計算依據,
        "   不用看狀態列訊息(訊息只在按下按鈕當下顯示),特別方便 ZTGCX0001A 對比測試
* V026 JosephLo 20260610 — DDIC Z_BASIS_USED 已加寬至 CHAR100,欄寬同步放大,避免公式字串被截。
* 20260616 JosephLo 公式改詳細版「淨額…=Liability…+7天報MOQ…-7天總需求…」(字串變長),outputlen 80→100 同步放大。
        <lfs_fcat>-outputlen = 100.
        set_field_text '本期計算基準'.
* 20260612 JosephLo Link(點開「7天報MOQ明細」彈窗)改掛在「本期計算基準」欄(較嚴謹:此欄即淨額公式,點它看明細最直覺);
*   原掛在 MOQ_QTY_7DAY 的 hotspot 移除。雙擊 handler frm_double_click 對應 WHEN 也改為 'Z_BASIS_USED'。
        <lfs_fcat>-hotspot   = 'X'.
* V023 End off *
* 20260610 JosephLo §9.1 7天報MOQ供給(calc_moq_net 的 lv_supply_all,只 'L' 淨額模型填值)
      WHEN 'MOQ_QTY_7DAY'.
        set_field_text '7天報MOQ供給'.
        <lfs_fcat>-decimals_o = 0.
* V026 JosephLo 20260611 — 欄名覆寫:Z_END_BALANCE→「Liability」(原Liability raw);Z_NET_BALANCE→「Liability結餘」
*   (Z_NET_BALANCE 沿用 Z_END_BALANCE 資料元素,不覆寫會顯示同一個 DDIC 短文,故兩欄都明確覆寫)。
*   20260612 改名:「當筆詢單扣除後Liability」→「Liability結餘」(值改為 淨額+本次報MOQ,夾0)。
      WHEN 'Z_END_BALANCE'.
        set_field_text 'Liability'.
      WHEN 'Z_NET_BALANCE'.
        set_field_text 'Liability結餘'.
* 20260616 JosephLo Excel下載抓 scrtext_s(CHAR10),'Liability結餘'(11字)會被截成「Liability結」;
*   scrtext_s 改完整短名「Liab結餘」(不破),scrtext_m/l 仍是完整「Liability結餘」→ 欄位拉寬即顯示完整。
        <lfs_fcat>-scrtext_s = 'Liab結餘'.
      WHEN OTHERS.
    ENDCASE.
  ENDLOOP.
  LOOP AT ct_fcat ASSIGNING <lfs_fcat>.
    CASE <lfs_fcat>-fieldname.
      WHEN  'NETPR' OR 'WAERS' OR 'NETPR_CNY' OR 'NETPR_TWD' OR  'WAERS_CNY' OR 'WAERS_TWD' OR 'SALES_NETPR' OR 'SALES_NETPR_6' OR 'SALES_WAERS'  OR 'SALES_AMT' .
        READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
        CASE ls_role-role.
          WHEN 'A'.
            <lfs_fcat>-tech = 'X'.
        ENDCASE.
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
  CLEAR:it_extab.
* 20260526 JosephLo ZTGCX0001A(整機買賣)預覽:只擋「會寫DB」的按鈕(CONFIRM/&DATA_SAVE/DELETE)；
*   RECALC(重新計算報MOQ量)、CALC_SALES(計算業務單價/金額) 只刷新 ALV、不寫 DB,維持原行為不擋
*   (其中 CALC_SALES 對 p_imp+角色A 原本就擋,沿用)。SALL/DSAL 等亦沿用各模式分支。
*   作法:此處只加會寫DB的3個 fcode,fall-through 到下方 p_dis/p_mod/p_imp/p_upd 分支照常跑。
* V025 JosephLo 2026/06/01 改讀 gs_mode-allow_write:任何不可寫模式(模擬/SE38/未知)都擋掉會寫DB的3顆按鈕
  IF gs_mode-allow_write = ''.
    APPEND VALUE #( fcode = 'CONFIRM' )    TO it_extab.
    APPEND VALUE #( fcode = '&DATA_SAVE' ) TO it_extab.
    APPEND VALUE #( fcode = 'DELETE' )     TO it_extab.
  ENDIF.
  IF p_dis IS NOT INITIAL.
    APPEND INITIAL LINE TO it_extab ASSIGNING FIELD-SYMBOL(<ls_extab>).
    <ls_extab>-fcode = 'CONFIRM'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'SALL'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'DSAL'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = '&DATA_SAVE'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'DELETE'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'RECALC'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'CALC_SALES'.
  ELSEIF p_mod IS NOT INITIAL.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'CONFIRM'.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'RECALC'.
    CASE ls_role-role.
      WHEN 'A'.
        APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
        <ls_extab>-fcode = 'CALC_SALES'.
    ENDCASE.
  ELSEIF p_imp IS NOT INITIAL.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'DELETE'.
    CASE ls_role-role.
      WHEN 'A'.
        APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
        <ls_extab>-fcode = 'CALC_SALES'.
    ENDCASE.
  ELSEIF p_upd IS NOT INITIAL.
    APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
    <ls_extab>-fcode = 'DELETE'.
    CASE ls_role-role.
      WHEN 'A'.
        APPEND INITIAL LINE TO it_extab ASSIGNING <ls_extab>.
        <ls_extab>-fcode = 'CALC_SALES'.
    ENDCASE.

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
* V028 Added by JosephLo 20260614 — 並行鎖(EZGCX0001LOCK)用:鎖鍵(角色推導E/F分區,C/D合併)+取鎖結果旗標
  DATA:lv_lock_key TYPE char10,
       lv_locked   TYPE abap_bool.

  CALL FUNCTION 'GET_GLOBALS_FROM_SLVC_FULLSCR'
    IMPORTING
      e_grid = lo_grid.

  IF lo_grid IS NOT INITIAL.
    lo_grid->check_changed_data( ).
  ENDIF.

* 20260524 JosephLo 空主alv 時，資料操作直接提示、不再跑確認對話框(避免空表還問「確認儲存」造成困擾)
  IF gt_data IS INITIAL
     AND ( iv_ucomm = 'CONFIRM'    OR iv_ucomm = '&DATA_SAVE'
        OR iv_ucomm = 'RECALC'     OR iv_ucomm = 'CALC_SALES'
        OR iv_ucomm = 'DELETE' ).
    MESSAGE s001(00) WITH '無資料可操作'.
    RETURN.
  ENDIF.

* V025 JosephLo 2026/06/01 雙保險:不可寫模式(模擬ZTGCX0001A/SE38/未知)即使按鈕意外被觸發,寫DB類動作一律擋下。
*   罩住 CONFIRM(產QQ+save)/&DATA_SAVE(save)/DELETE(刪) 三條寫入路徑;與 frm_status_set 擋按鈕互為雙保險。
  IF gs_mode-allow_write = ''
     AND ( iv_ucomm = 'CONFIRM' OR iv_ucomm = '&DATA_SAVE' OR iv_ucomm = 'DELETE' ).
    MESSAGE s001(00) WITH '模擬模式不寫入資料' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  CASE iv_ucomm.
    WHEN 'F03' OR 'F15'.
      IF gv_save IS INITIAL AND ( p_imp IS NOT INITIAL OR p_mod IS NOT INITIAL ).
        PERFORM pop_up_confirm  USING  '確認離開'(t08)
                                       '未儲存的資料即將消失，確定?'(t09)
                                          lv_ans.
        IF lv_ans = '1'.
          ROLLBACK WORK.
          LEAVE TO SCREEN 0.
        ENDIF.
      ELSE.
        LEAVE TO SCREEN 0.
      ENDIF.
    WHEN 'F12'.
      LEAVE PROGRAM.
    WHEN 'SALL'."選擇全部行
      LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
        IF NOT line_exists( <ls_data>-cellstyles[ style = cl_gui_alv_grid=>mc_style_disabled ] ).
          <ls_data>-sel = 'X'.
        ENDIF.
        "<ls_data>-sel = 'X'.
      ENDLOOP.
    WHEN 'DSAL'."取消選擇全部行
      LOOP AT gt_data ASSIGNING <ls_data>.
        IF NOT line_exists( <ls_data>-cellstyles[ style = cl_gui_alv_grid=>mc_style_disabled ] ).
          <ls_data>-sel = ''.
        ENDIF.
        "<ls_data>-sel = ''.
      ENDLOOP.
    WHEN '&IC1'.
      PERFORM frm_double_click USING is_selfield .
    WHEN 'CONFIRM'.
      IF line_exists( gt_data[ sel = 'X' ] ).
        PERFORM pop_up_confirm  USING  '確認產生QQ單號'(t04)
                                        '將勾選的項目確認產生QQ單號?'(t05)
                                        lv_ans.
        IF lv_ans = '1'.
* 20260525 JosephLo 移除確認QQ時的 check_sku_err 提示：無客戶型號件已在上傳 popup(gt_excluded)
*   列出、且不進主ALV、save_data 逐列防呆不寫DB；此處再提示一次屬多餘且易誤解(會列出不在ALV的件)，故移除。
* V028 Added by JosephLo 20260614 — 並行鎖:同分區(生管E/採購F,C/D合併)一次只允許一人計算/產QQ,防多人讀同一
*   未提交基準各報一個ZMOQ雙報。寫入路徑 _scope='2'(預設):save_data 的 COMMIT WORK 自動釋放;撞鎖(_wait預設
*   SPACE)立即丟 foreign_lock→訊息帶持有者→不執行。詳見「報MOQ計算與產生QQ_並行鎖設計_EZGCX0001LOCK.md」。
          PERFORM get_moq_lock_key CHANGING lv_lock_key.
          PERFORM lock_moq_calc USING lv_lock_key '2' CHANGING lv_locked.
          IF lv_locked = 'X'.
* V022 Added by JosephLo 20260526 *
* CONFIRM (確認產生QQ單號) 流程：先 choose_moq_basis 決定本次 MOQ 計算基準
*   (sy-tcode='ZTGCX0001A' 才彈窗讓 user 選；其他 t-code(含本主程式 ZTGCX0001) 固定 Liability)
*   ※ ZTGCX0001A 中本 CONFIRM 按鈕已被 frm_status_set 擋掉、實際走不到這支 PERFORM；
*     此處保留呼叫一致性,以防未來 ZTGCX0001A 解擋。
*   再走 recalc_data → confirm_get_qq → save_data。詳見 FORM choose_moq_basis 註解。
            PERFORM choose_moq_basis.
* V022 End off *
            PERFORM recalc_data.
            PERFORM confirm_get_qq.
            PERFORM save_data.            "內含 COMMIT WORK AND WAIT → _scope='2' 鎖自動釋放
            lo_grid->refresh_table_display( ).
          ENDIF.                          "撞鎖:lock_moq_calc 已發訊息,不動作
        ELSE.
          MESSAGE s001(00) WITH 'User canceled'.
        ENDIF.
      ELSE.
        MESSAGE s001(00) WITH 'Please select items'.
      ENDIF.
    WHEN '&DATA_SAVE'.
      PERFORM pop_up_confirm  USING  '確認儲存'(t06)
                                      '確認儲存至外掛表中?'(t07)
                                      lv_ans.
      IF lv_ans = '1'.
* V028 Added by JosephLo 20260614 — 並行鎖:&DATA_SAVE 亦是寫入路徑(save_data 寫 moq_qty),比照 CONFIRM 罩鎖。
*   _scope='2':save_data 的 COMMIT WORK 自動釋放;撞鎖立即提示、不執行。
        PERFORM get_moq_lock_key CHANGING lv_lock_key.
        PERFORM lock_moq_calc USING lv_lock_key '2' CHANGING lv_locked.
        IF lv_locked = 'X'.
          PERFORM save_data.
          lo_grid->refresh_table_display( ).
        ENDIF.
      ELSE.

      ENDIF.
    WHEN 'DELETE'.
      PERFORM pop_up_confirm  USING  '確認刪除'(t10)
                                     '確認刪除該詢單資料?'(t11)
                                     lv_ans.
      IF lv_ans = '1'.
        PERFORM delete_data.
        lo_grid->refresh_table_display( ).
      ELSE.
        MESSAGE s001(00) WITH 'User canceled'.
      ENDIF.
    WHEN 'RECALC'.
      PERFORM pop_up_confirm  USING  '確認重新計算'(t12)
                                     '確認重新計算詢單資料?'(t13)
                                     lv_ans.
      IF lv_ans = '1'.
* V028 Added by JosephLo 20260614 — 並行鎖:RECALC 純讀不寫,用 _scope='1'(不靠 COMMIT 釋放)→ 算完明確 unlock。
*   仍取鎖以維持「同分區一次一人計算」;撞鎖立即提示、不執行。
*   (註:模擬 ZTGCX0001A 的 RECALC 亦會短暫取鎖;如不希望預覽擋到正式,可加 gs_mode-allow_write='X' 守門。)
        PERFORM get_moq_lock_key CHANGING lv_lock_key.
        PERFORM lock_moq_calc USING lv_lock_key '1' CHANGING lv_locked.
        IF lv_locked = 'X'.
* V022 Added by JosephLo 20260526 *
* RECALC (重新計算報MOQ量) 流程：先 choose_moq_basis 決定本次 MOQ 計算基準
*   (sy-tcode='ZTGCX0001A' 才彈窗讓 user 選；其他 t-code(含本主程式 ZTGCX0001) 固定 Liability)
*   ※ ZTGCX0001A 中 RECALC 按鈕未被擋,是 ZTGCX0001A 觸發本 FORM 彈窗的唯一入口。
*   再走 recalc_data 重算。詳見 FORM choose_moq_basis 註解。
          PERFORM choose_moq_basis.
* V022 End off *
          PERFORM recalc_data.
          PERFORM unlock_moq_calc USING lv_lock_key '1'.   "純讀算完立即釋放
          lo_grid->refresh_table_display( ).
        ENDIF.
      ELSE.
        MESSAGE s001(00) WITH 'User canceled'.
      ENDIF.
    WHEN 'CALC_SALES'.
      PERFORM pop_up_confirm  USING  '確認重新計算'(t12)
                                     '確認重新計算業務金額相關欄位?'(t14)
                                     lv_ans.
      IF lv_ans = '1'.
        PERFORM recalc_sales_data.
        lo_grid->refresh_table_display( ).
      ELSE.
        MESSAGE s001(00) WITH 'User canceled'.
      ENDIF.
    WHEN OTHERS.
  ENDCASE.

  is_selfield-refresh    = 'X'.
  is_selfield-col_stable = 'X'.
  is_selfield-row_stable = 'X'.

ENDFORM. "FRM_USER_COMMAND
*&---------------------------------------------------------------------*
*& Form get_moq_lock_key  (V028 JosephLo 20260614)
*&---------------------------------------------------------------------*
*& 由角色推導「報MOQ並行鎖」鎖鍵 = 寫入分區(非3角色):生管(A)守E件→'A';
*&   採購(C)守F件→'C';當地採購(D)與採購共守同一批F件→併入'C'(C/D合併)。
*&   真正不重疊的寫入分區是採購類型 E vs F(見 explode_bom/assign_rem_data 角色過濾),
*&   故 C、D 必須共用同一把鎖,否則兩人對同一F件同時報MOQ會雙報。
*&   ★鎖鍵刻意用 CHAR10:日後若細化成 role+vtweg 不必改 DDIC,只換傳入值。
*&---------------------------------------------------------------------*
FORM get_moq_lock_key CHANGING cv_key TYPE char10.
  READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
  cv_key = SWITCH #( ls_role-role
                     WHEN 'A' THEN 'A'      "生管    → E 件
                     WHEN 'C' THEN 'C'      "採購    → F 件
                     WHEN 'D' THEN 'C'      "當地採購 → 與採購共用 F 件鎖(C/D 合併)
                     ELSE        ls_role-role ).
ENDFORM.
*&---------------------------------------------------------------------*
*& Form lock_moq_calc  (V028 JosephLo 20260614)
*&---------------------------------------------------------------------*
*& 取得「報MOQ計算/產QQ」獨占鎖(非阻塞);cv_ok='X'=成功、''=撞鎖或失敗(已發訊息)。
*&   iv_scope:'2'=寫入路徑(CONFIRM/&DATA_SAVE)→ save_data 的 COMMIT WORK 自動釋放;
*&            '1'=純讀(RECALC)→ 需呼叫 unlock_moq_calc 明確釋放。
*&   _wait 不帶(預設 SPACE)= 撞鎖立即丟 foreign_lock、不凍結 GUI;sy-msgv1=持鎖者帳號。
*&   鎖物件 EZGCX0001LOCK(mode E)/錨表 ZTGCX0001_LOCK。詳見並行鎖設計文件。
*&---------------------------------------------------------------------*
FORM lock_moq_calc USING    iv_key   TYPE char10
                            iv_scope TYPE char1
                   CHANGING cv_ok    TYPE abap_bool.
  CLEAR cv_ok.
  CALL FUNCTION 'ENQUEUE_EZGCX0001LOCK'
    EXPORTING
      mode_ztgcx0001_lock = 'E'
      zlockkey            = iv_key
      _scope              = iv_scope
    EXCEPTIONS
      foreign_lock        = 1
      system_failure      = 2
      OTHERS              = 3.
  IF sy-subrc = 1.                       "撞鎖:ENQUEUE 把持鎖者帳號放 sy-msgv1
*   ★先把 sy-msgv1 組進字串再發:MESSAGE ... WITH 會由左到右把 &1..&4 回寫 sy-msgv1..4;
*     若直接 WITH '目前' sy-msgv1,&2 讀到的 sy-msgv1 已被 &1('目前')覆寫 → 顯示「目前目前…」且漏帳號。
    DATA(lv_lock_msg) = |目前 { sy-msgv1 } 正在計算/產生QQ,請稍候再試|.
    MESSAGE s001(00) WITH lv_lock_msg DISPLAY LIKE 'E'.
    RETURN.
  ELSEIF sy-subrc <> 0.
    MESSAGE s001(00) WITH '取得計算鎖失敗,請稍後再試' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  cv_ok = 'X'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form unlock_moq_calc  (V028 JosephLo 20260614)
*&---------------------------------------------------------------------*
*& 釋放「報MOQ計算/產QQ」鎖。RECALC(_scope='1')純讀算完明確呼叫;
*&   寫入路徑(_scope='2')由 COMMIT WORK 自動釋放,呼叫亦無害(已釋放→no-op)。
*&---------------------------------------------------------------------*
FORM unlock_moq_calc USING iv_key   TYPE char10
                           iv_scope TYPE char1.
  CALL FUNCTION 'DEQUEUE_EZGCX0001LOCK'
    EXPORTING
      mode_ztgcx0001_lock = 'E'
      zlockkey            = iv_key
      _scope              = iv_scope.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form FRM_DOUBLE_CLICK
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> IS_SELFIELD
*&---------------------------------------------------------------------*
FORM frm_double_click USING    is_selfield TYPE slis_selfield.

* 20260610 JosephLo §9 顯示來源表依模式:p_dis(查詢)顯示 gt_report、其餘(p_imp/p_mod/p_upd)顯示 gt_data。
*   原本寫死 READ gt_data → 查詢模式 gt_data 為空,雙擊/hotspot 讀不到列(畫面只閃一下即恢復)而無反應;
*   改依 p_dis 取對應表,讓 VBELN/IDNRK/MOQ_QTY_7DAY 等雙擊/hotspot 在查詢模式也能用。
  FIELD-SYMBOLS <fs_tab> TYPE zscx0001_alv.
  IF p_dis IS NOT INITIAL.
    READ TABLE gt_report ASSIGNING <fs_tab> INDEX is_selfield-tabindex.
  ELSE.
    READ TABLE gt_data   ASSIGNING <fs_tab> INDEX is_selfield-tabindex.
  ENDIF.
  IF sy-subrc EQ 0.
    CASE is_selfield-fieldname.
      WHEN 'VBELN'.
        IF <fs_tab>-vbeln IS NOT INITIAL.
          SET PARAMETER ID 'AUN' FIELD <fs_tab>-vbeln.
          CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN.
        ENDIF.
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
* V023 Added by JosephLo 20260527 *
      WHEN 'MOQ_PRIOR_LINK'.
        " 雙擊「前期結餘」hotspot 欄 → 彈出 popup 顯示同 (vtweg, zseq, idnrk) 在過去 7 天內
        "   所有未刪除的 ZTCX0001 列(放寬版,不限 qq_status / moq_remain),依日期排序、
        "   實際被本期計算採用的列以淡藍背景標示。詳見 FORM hotspot_show_prior_moq。
        " 只有「有前期結餘」分支會把 moq_prior_link 填字串,所以這個 IF 防呆是必要的——
        "   首次分支/qq_seq 已設等列雖然 fieldcat 開了 hotspot,但欄位為空、雙擊也不該動作。
        IF <fs_tab>-moq_prior_link IS NOT INITIAL.
          PERFORM hotspot_show_prior_moq
                  USING <fs_tab>-vtweg <fs_tab>-zseq <fs_tab>-idnrk <fs_tab>-zportalno.
        ENDIF.
* V023 End off *
* 20260612 JosephLo Link 改掛「本期計算基準(Z_BASIS_USED)」欄:雙擊 → 彈同子件7天內 ZTCX0001 明細(7天報MOQ明細),
*   沿用 hotspot_show_prior_moq。(原掛 MOQ_QTY_7DAY 已改;fieldcat 的 hotspot 也同步移到 Z_BASIS_USED。)
      WHEN 'Z_BASIS_USED'.
        PERFORM hotspot_show_prior_moq
                USING <fs_tab>-vtweg <fs_tab>-zseq <fs_tab>-idnrk <fs_tab>-zportalno.
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
*& Form show_error_alv
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
* 20260524 JosephLo 階段3：已不再由主流程呼叫(上傳錯誤改收集到 gt_excluded、併入 show_excluded_popup)。
*   暫保留此 FORM 以備回退；確認穩定後可刪。
FORM show_error_alv .
  DATA:lt_fieldcat TYPE lvc_t_fcat.
  DATA:ls_fcat   TYPE lvc_s_fcat,
       lv_layout TYPE lvc_s_layo.
  FIELD-SYMBOLS:<fs_fcat> TYPE lvc_s_fcat,
                <fs_val>  TYPE any.



  DEFINE m_add_fcat.
    ls_fcat-fieldname = &1.
    ls_fcat-coltext   = &2.
    ls_fcat-scrtext_l = &2.
    ls_fcat-scrtext_m = &2.
    ls_fcat-scrtext_s = &2.
    ls_fcat-outputlen = &3.
    ls_fcat-col_pos = &4.
    ls_fcat-ref_field = &5.
    ls_fcat-ref_table = &6.
    APPEND ls_fcat TO lt_fieldcat.
  END-OF-DEFINITION.
  m_add_fcat: 'VTWEG' '客戶'(f01) 4 1 'TVTW' 'VTWEG',
              'MATNR' '大貨件號'(f02) 40 2 'MARA' 'MATNR',
              'WERKS' '工廠'(f03) 4 3 'T001W' 'WERKS',
              'MENGE' '大貨需求數量'(f04) 15 4 '' '',
              'REQ_DATE' '需求日期'(f05) 8 5 'MSEG' 'BUDAT',
              'ZPORTALNO' '詢單號碼'(f06) 12 6 '' '',
              'ZMSG' '錯誤訊息'(f07) 50 7 '' ''.
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
*& Form show_excluded_popup
*&   20260524 JosephLo 統一異常訊息顯示重構：進主ALV前，把所有「沒進主ALV的件」
*&   (gt_excluded)以 popup 小視窗條列(不中斷)。用 REUSE_ALV_GRID_DISPLAY_LVC + popup
*&   參數(I_SCREEN_START_*)，且不指定 pf-status → 自帶標準工具列(可匯出 Excel/排序/篩選)；
*&   排序靠 sort_seq、隱藏 sort_seq；看完按確認/關閉進主ALV
*&---------------------------------------------------------------------*
FORM show_excluded_popup .
  DATA: lt_fcat   TYPE lvc_t_fcat,
        lt_sort   TYPE lvc_t_sort,
        ls_sort   TYPE lvc_s_sort,
        ls_layout TYPE lvc_s_layo.

* 20260525 JosephLo 排序改「重要性遞減」(數字大者在前)：99上傳檢查/98詢單重複/97無客戶型號 為高重要性；
*   09無可報子件/08非本角色/07不報MOQ 為低重要性。顯示用副本 lt_disp：若有低重要性件(sort_seq<50)，
*   在高低之間插一條分隔列(sort_seq=50)，讓「只剩低重要性」時分隔列即第一行、user 一眼可直接按 X。
*   gt_excluded 本身保持乾淨(不含分隔列)供匯出 Excel。
  SORT gt_excluded BY sort_seq DESCENDING.
  DATA lt_disp LIKE gt_excluded.
  lt_disp = gt_excluded.
  LOOP AT lt_disp TRANSPORTING NO FIELDS WHERE sort_seq < 50.
    EXIT.
  ENDLOOP.
  IF sy-subrc = 0.   "有低重要性件 → 插分隔列
    APPEND VALUE #( sort_seq = '50'
                    category = '低重要性'
                    reason   = '################## 以下為低重要性（無可報子件／非本角色／不報MOQ），########################'
                  ) TO lt_disp.
  ENDIF.

  PERFORM build_excl_fcat CHANGING lt_fcat.   "fieldcat 與「匯出 Excel」共用

  ls_sort-fieldname = 'SORT_SEQ'.
  ls_sort-down      = 'X'.        "20260525 遞減：重要性大者在前
  ls_sort-spos      = 1.
  APPEND ls_sort TO lt_sort.

  ls_layout-cwidth_opt = 'X'.
  ls_layout-zebra      = 'X'.

* popup 小視窗(I_SCREEN_START_*) + 不指定 pf-status → 自帶標準工具列(含匯出 Excel)
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
      i_callback_program      = sy-repid
      i_callback_user_command = 'EXCL_UCOMM'   "20260524 ✓確認(&ONT)→詢問匯出 Excel；X/列印照原本動作
      i_grid_title            = '未進報表清單：按 ✓ 可匯出 Excel、按 X 直接進報表'
      i_bypassing_buffer      = 'X'
      is_layout_lvc           = ls_layout
      it_fieldcat_lvc         = lt_fcat
      it_sort_lvc             = lt_sort
      i_save                  = 'A'
      i_screen_start_column   = 5
      i_screen_start_line     = 3
      i_screen_end_column     = 200
      i_screen_end_line       = 22
    TABLES
      t_outtab                = lt_disp
    EXCEPTIONS
      program_error           = 1
      OTHERS                  = 2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form excl_ucomm — 異常清單 popup 的 user_command
*&   20260524 JosephLo：實測「✓ 確認」觸發 fcode='&ONT'(會進此 callback)；
*&   X 關閉、列印等不進 callback、照原本動作。故僅在 &ONT 時詢問是否匯出 Excel。
*&---------------------------------------------------------------------*
FORM excl_ucomm USING r_ucomm     LIKE sy-ucomm
                      rs_selfield TYPE slis_selfield.
  CHECK r_ucomm = '&ONT'.            "只在按「✓ 確認」時詢問匯出；X/列印照原本動作
  PERFORM export_excluded_excel.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form export_excluded_excel — 詢問並把 gt_excluded 匯出成真 .xlsx
*&   20260524 JosephLo：用 cl_salv_bs_tt_util 把 internal table 轉成 xlsx xstring
*&   (S/4 必備、欄位正確分欄)，再 gui_download 成 .xlsx。fieldcat 與 popup 共用。
*&---------------------------------------------------------------------*
FORM export_excluded_excel.
  DATA lv_ans TYPE c.
  PERFORM pop_up_confirm USING '匯出 Excel'
                               '是否將上傳異常清單匯出成 Excel？'
                               lv_ans.
  CHECK lv_ans = '1'.

* 1) fieldcat(與 popup 共用) → 產 SALV result data
  DATA lt_fcat TYPE lvc_t_fcat.
  PERFORM build_excl_fcat CHANGING lt_fcat.
  DATA(lo_result) = cl_salv_ex_util=>factory_result_data_table(
                      r_data         = REF #( gt_excluded )
                      t_fieldcatalog = lt_fcat ).

* 2) internal table → 真 .xlsx(xstring)；欄位正確分欄
  DATA lv_xstring TYPE xstring.
  TRY.
      cl_salv_bs_tt_util=>if_salv_bs_tt_util~transform(
        EXPORTING
          xml_type      = if_salv_bs_xml=>c_type_xlsx
          xml_version   = cl_salv_bs_a_xml_base=>get_version( )
          r_result_data = lo_result
          xml_flavour   = if_salv_bs_c_tt=>c_tt_xml_flavour_export
          gui_type      = if_salv_bs_xml=>c_gui_type_gui
        IMPORTING
          xml           = lv_xstring ).
    CATCH cx_root.
      MESSAGE '產生 Excel 失敗' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.

* 3) 選存檔路徑(.xlsx)
  DATA: lv_fname    TYPE string,
        lv_path     TYPE string,
        lv_fullpath TYPE string,
        lv_action   TYPE i.
  cl_gui_frontend_services=>file_save_dialog(
    EXPORTING
      default_extension = 'xlsx'
      default_file_name = |上傳異常清單_{ sy-datum }_{ sy-uzeit }.xlsx|
    CHANGING
      filename    = lv_fname
      path        = lv_path
      fullpath    = lv_fullpath
      user_action = lv_action
    EXCEPTIONS
      OTHERS      = 1 ).
  IF sy-subrc <> 0 OR lv_action <> cl_gui_frontend_services=>action_ok OR lv_fullpath IS INITIAL.
    RETURN.
  ENDIF.

* 4) xstring → binary → 下載 .xlsx
  DATA(lt_bin) = cl_bcs_convert=>xstring_to_solix( lv_xstring ).
  cl_gui_frontend_services=>gui_download(
    EXPORTING
      filename     = lv_fullpath
      filetype     = 'BIN'
      bin_filesize = xstrlen( lv_xstring )
    CHANGING
      data_tab     = lt_bin
    EXCEPTIONS
      OTHERS       = 1 ).
  IF sy-subrc = 0.
    MESSAGE |已匯出：{ lv_fullpath }| TYPE 'S'.
  ELSE.
    MESSAGE '匯出失敗，請確認路徑/權限' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form build_excl_fcat — gt_excluded 的 LVC fieldcat(popup 與匯出 Excel 共用)
*&---------------------------------------------------------------------*
FORM build_excl_fcat CHANGING ct_fcat TYPE lvc_t_fcat.
  DATA ls_fcat TYPE lvc_s_fcat.
  CLEAR ct_fcat.
  DEFINE m_fcat.
    CLEAR ls_fcat.
    ls_fcat-fieldname = &1.
    ls_fcat-coltext   = &2.
    ls_fcat-scrtext_l = &2.
    ls_fcat-scrtext_m = &2.
    ls_fcat-scrtext_s = &2.
    ls_fcat-outputlen = &3.
    ls_fcat-col_pos   = &4.
    ls_fcat-ref_field = &5.
    ls_fcat-ref_table = &6.
    ls_fcat-no_out    = &7.
    APPEND ls_fcat TO ct_fcat.
  END-OF-DEFINITION.
  "       欄位        標題        寬  位 ref_field ref_table 隱藏
  m_fcat: 'SORT_SEQ'  ''          3   1 ''      ''      'X',
          'CATEGORY'  '異常分類'  12  2 ''      ''      '',
          'REASON'    '原因'      50  3 ''      ''      '',
          'MATNR_FG'  '成品料號'  20  4 'MATNR' 'MARA'  '',
          'PARENT'    '上階料號'  20  5 'MATNR' 'MARA'  '',
          'IDNRK'     '料號'      20  6 'MATNR' 'MARA'  '',
          'BESKZ'     '採購類型'   8  7 'BESKZ' 'MARC'  '',
          'SOBSL'     '特殊採購'   8  8 'SOBSL' 'MARC'  '',
          'LIFNR'     '供應商'    12  9 'LIFNR' 'LFA1'  '',
          'MNGLG'     '單位用量'  13 10 ''      ''      '',
          'MENGE'     '需求數量'  13 11 ''      ''      '',
          'WERKS'     '工廠'       5 12 'WERKS' 'T001W' '',
          'VTWEG'     '通路'       4 13 'VTWEG' 'TVTW'  '',
          'ZPORTALNO' '詢單號碼'  14 14 ''      ''      ''.
ENDFORM.
*---------------------------------------------------------------------*
* FORM process_data — 含 PATCH F (PIR 批次) + PATCH G (電子件判斷)
*---------------------------------------------------------------------*
FORM process_data .
* V022 Added by JosephLo 20260526 *
* 跨次執行防護：清空 it_liab。
*   原因：全程式無其他 CLEAR it_liab。同 session 連續多次 p_imp 上傳時，上次累積在
*         it_liab 的 ZTCX0026 餘額會殘留進這次的 get_stock_qty REDUCE 計算，
*         導致 z_end_balance 把舊上傳的餘額也加進來 → 偏大。
*   配套：本次同時在 get_liability 內加上 APPEND 前去重(見該 FORM V022 註解區塊)。
  CLEAR it_liab.
* V022 End off *
* V014 Added by Tristan 2026/04/22 *
  DATA: tmp_bom TYPE TABLE OF ztcx0001_bom,
        wa_bom  TYPE ztcx0001_bom.
  INSERT VALUE #( sign = 'I' option = 'EQ' low = '0000011200' ) INTO TABLE r_lifnr.
  INSERT VALUE #( sign = 'I' option = 'EQ' low = '0000021200' ) INTO TABLE r_lifnr.
* V014 End off *
  DATA: lt_stpox  TYPE TABLE OF stpox,
        ls_topmat TYPE cstmat,
        ls_data   LIKE LINE OF gt_data,
        lt_step1  LIKE gt_data,
        ls_edit   TYPE lvc_s_styl,
        lt_edit   TYPE lvc_t_styl.

  "=== PATCH F: PIR 批次需求的暫存表 ===
  DATA: lt_keys   TYPE tt_key,
        lt_demand TYPE tt_result,
        ls_dmd    TYPE ty_result.

  FIELD-SYMBOLS: <ls_d>    LIKE LINE OF gt_data,
                 <ls_data> LIKE LINE OF gt_data.
* V013 Added by Tristan 2026/04/24 *
* 特殊標記設定表
  SELECT * FROM ztcx0004a INTO TABLE @DATA(it_004a).
  SORT it_004a BY matkl strgr.
  r_zportalno = VALUE #( FOR lv_upload IN gt_upload
                   ( sign = 'I'
                     option = 'EQ'
                     low = lv_upload-zportalno )
                   ).
* V013 End off *
  CLEAR gt_sku_err.   " V020 JosephLo 2026/05/22 重置客戶型號錯誤清單
  LOOP AT gt_upload INTO DATA(ls_upload).
*    CLEAR: lt_step1, lt_stpox. " V020 Ky. 2026/5/8  客戶型號不存在訊息處理
    "Step 1: 展 BOM
    PERFORM explode_bom TABLES lt_stpox USING ls_upload ls_topmat.
* 20260524 JosephLo 階段3 W統一：原「無BOM市購F件補自身項到 lt_stpox」區塊已移除。
*   無BOM件一律讓 lt_stpox 維持空，交給 assign_rem_data(lines(lt_stpox)=0)統一建自身項(查客戶型號)。

* V013 Added by Tristan 2026/04/17 *
* 抓Liability
    IF lt_stpox[] IS NOT INITIAL.
      PERFORM get_liability TABLES lt_stpox USING ls_upload.
* 在PERFORM explode_bom已經有撈
*      SELECT marc~matnr, marc~werks, ztmarc~zdefault_vendor
*        FROM marc INNER JOIN ztmarc
*          ON marc~matnr = ztmarc~matnr
*         AND marc~werks = ztmarc~werks
*         FOR ALL ENTRIES IN @lt_stpox
*       WHERE marc~matnr = @lt_stpox-idnrk
*         AND marc~werks = @lt_stpox-werks
*         AND marc~beskz = 'F'  " 採購類型
*         AND marc~sobsl = ''   " 特殊採購類型
*        INTO TABLE @it_marc.
*
      SELECT marc~matnr, marc~werks, mara~matkl, marc~strgr
        FROM mara INNER JOIN marc
          ON mara~matnr = marc~matnr
         FOR ALL ENTRIES IN @lt_stpox
       WHERE marc~matnr = @lt_stpox-idnrk
         AND marc~werks = @lt_stpox-werks
        INTO TABLE @DATA(it_mara).
      SORT it_mara BY matnr werks.
    ENDIF.
* V013 End off *
    LOOP AT lt_stpox INTO DATA(ls_stpox).
* V014 Added by Tristan 2026/04/22 *
** 供應商 <> "11200" or "21200"
*      IF ls_stpox-lifnr NOT IN r_lifnr.
*        READ TABLE it_marc INTO DATA(ls_marc) WITH KEY matnr = ls_stpox-idnrk
*                                                       werks = ls_stpox-werks
*                                              BINARY SEARCH.
*        IF sy-subrc = 0.
*          ls_data-loekz = 'X'.
*        ENDIF.
*      ENDIF.
      READ TABLE it_mara INTO DATA(wa_mara) WITH KEY matnr = ls_stpox-idnrk
                                                     werks = ls_stpox-werks
                                              BINARY SEARCH.
      IF sy-subrc = 0.
        READ TABLE it_004a INTO DATA(wa_0014a) WITH KEY matkl = wa_mara-matkl
                                                        strgr = wa_mara-strgr
                                               BINARY SEARCH.
        IF sy-subrc = 0.
          ls_data-zind01 = wa_0014a-zind01.
        ENDIF.
      ENDIF.
* V014 End off *

      "Step 1.1: 檢查是否已有資料
      SELECT SINGLE * FROM ztcx0001
        WHERE werks     = @ls_upload-werks
          AND vtweg     = @ls_upload-vtweg
          AND zportalno = @ls_upload-zportalno
          AND idnrk     = @ls_stpox-idnrk
          AND loekz     IS INITIAL
          AND qq        IS NOT INITIAL
        INTO @DATA(ls_001).
      IF sy-subrc = 0.
        MOVE-CORRESPONDING ls_001 TO ls_data.
        APPEND ls_data TO gt_data.
        CLEAR ls_data.
        CONTINUE.
      ENDIF.
      "主要欄位帶入
      ls_data-matnr          = ls_upload-matnr.
      ls_data-werks          = ls_upload-werks.
      ls_data-idnrk          = ls_stpox-idnrk.
      ls_data-vtweg          = ls_upload-vtweg.
      ls_data-req_date       = ls_upload-req_date.
      ls_data-zportalno_qty  = ls_upload-menge.

      "物料狀態
      SELECT SINGLE mstae FROM mara
        WHERE matnr = @ls_stpox-idnrk
        INTO @ls_data-mstae.

      " 主要圖號 MAINDRAWINGNO   KY V009
      SELECT SINGLE  maindrawingno FROM ztmara
        WHERE matnr = @ls_stpox-idnrk
        INTO @ls_data-maindrawingno.
      IF sy-subrc <> 0 OR ls_data-maindrawingno IS INITIAL.
        ls_data-maindrawingno = 'N/A'.
      ENDIF.
      "單位用量 / 子階需求
      ls_data-mnglg = ls_stpox-menge.
* V018 Changed by Tristan 2026/05/14 *
** V004 Changed by Tristan 2026/01/21 *
**      ls_data-menge = ls_stpox-mnglg / 1000 * ls_upload-menge.
** 單位用量 * 需求量
*      ls_data-menge = ls_stpox-menge * ls_upload-menge.
** V004 End off *

      " 20260522 JosephLo 修正單位用量與需求數量不匹配的問題 Start
      " ls_data-menge = ls_stpox-mnglg / 1000 * ls_upload-menge. "20260522 先mark
      ls_data-menge = ls_stpox-menge * ls_upload-menge.
      " 20260522 JosephLo 修正單位用量與需求數量不匹配的問題 End

* V018 End off *
* V024 Added by JosephLo 20260528 *
* 從 LOOP AT lt_stpox 尾段(原 APPEND 之前那段 SELECT) 搬上來。
*   bug 現象：V022 切換 MOQ 基準為 z_end_balance 後,首張詢單算出來全為 0。
*   根因：get_stock_qty 在 zind01='C' 分支用 `zcpnocn = p_data-skuitem` 過濾 it_liab,
*         但 skuitem 過去只在 LOOP AT lt_stpox 結尾的 APPEND 前才 SELECT 填入 →
*         對 Step 2 (本行下方) 的 get_stock_qty 而言永遠是空字串 →
*         REDUCE 比對失敗 → z_end_balance = 0。
*   為何之前沒爆：V013 加入 z_end_balance + 該 REDUCE 時就埋下;但 V013 後來被改回,
*         z_end_balance 沒被當 MOQ 基準用,bug 只影響 ALV 顯示、未被注意。V022 把基準
*         改成 z_end_balance,才透過「首張單跑 0」浮上來。
*   修法：只搬位置,WHERE 條件不動 (維持與 assign_rem_data 的差異;ztype 過濾留待後續討論)。
*         原位置改為註解保留歷史。
      SELECT SINGLE zcn
        FROM ztsd0020
      WHERE vtweg = @ls_data-vtweg
        AND matnr = @ls_data-matnr
      INTO @ls_data-skuitem.
* V024 End off *
      "Step 2: 理論庫存 (MRP)
      PERFORM get_stock_qty USING ls_data.

      "Step 3 (PATCH F-1): 收集 PIR Key
      APPEND VALUE ty_key(
        matnr    = ls_data-idnrk
        werks    = ls_data-werks
        req_date = ls_data-req_date ) TO lt_keys.

      "Step 4: 取 MOQ / 採購類型等
      SELECT SINGLE marc~bstmi AS zmoq,
                     marc~beskz,
                     marc~fevor,
                     t024f~txt,
                     marc~sobsl,
                     marc~plifz,
* V014 Added by Tristan 2026/05/06 *
                     ztmarc~zdefault_vendor
* V014 End off *
        FROM ztmarc
        INNER JOIN marc
           ON ztmarc~werks = marc~werks
          AND ztmarc~matnr = marc~matnr
        LEFT OUTER JOIN t024f
           ON marc~werks = t024f~werks
          AND marc~fevor = t024f~fevor
        WHERE ztmarc~werks = @ls_stpox-werks
          AND ztmarc~matnr = @ls_stpox-idnrk
        INTO ( @ls_data-zmoq,
               @ls_data-beskz,
               @ls_data-fevor,
               @ls_data-txt_fevor,
               @ls_data-sobsl,
               @ls_data-plifz,
* V014 Added by Tristan 2026/05/06 *
               @DATA(zdefault_vendor) ).
* V014 End off *

      "詢單號碼 / 單位
      ls_data-zportalno = ls_upload-zportalno.
      ls_data-meins     = ls_stpox-meins.

      "帳本編號
      READ TABLE gt_custmap INTO DATA(ls_custmap)
           WITH KEY vtweg = ls_data-vtweg
                    werks = ls_data-werks.
      IF sy-subrc = 0.
        ls_data-zseq = ls_custmap-zseq.
      ENDIF.

      "MOQ 確認
      ls_data-moq_confirm = ls_data-menge.

      "權限控制
      READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
      IF sy-subrc = 0.
        CLEAR: ls_edit, lt_edit.
* 20260526 JosephLo 壓縮 IF/ELSEIF→CASE：兩分支只差 fieldname 字串、其餘相同 Start
        CASE ls_role-role.
          WHEN 'A'.    ls_edit-fieldname = 'REMARK_PP'.   "生管
          WHEN 'C'.    ls_edit-fieldname = 'REMARK_PUR'.  "採購
          WHEN OTHERS. CLEAR ls_edit.
        ENDCASE.
        IF ls_edit-fieldname IS NOT INITIAL.
          ls_edit-style = cl_gui_alv_grid=>mc_style_enabled.
          INSERT ls_edit INTO TABLE lt_edit.
          INSERT LINES OF lt_edit INTO TABLE ls_data-cellstyles.
        ENDIF.
*        IF ls_role-role = 'A'. "生管
*          ls_edit-fieldname = 'REMARK_PP'.
*          ls_edit-style     = cl_gui_alv_grid=>mc_style_enabled.
*          INSERT ls_edit INTO TABLE lt_edit.
*          INSERT LINES OF lt_edit INTO TABLE ls_data-cellstyles.
*        ELSEIF ls_role-role = 'C'. "採購
*          ls_edit-fieldname = 'REMARK_PUR'.
*          ls_edit-style     = cl_gui_alv_grid=>mc_style_enabled.
*          INSERT ls_edit INTO TABLE lt_edit.
*          INSERT LINES OF lt_edit INTO TABLE ls_data-cellstyles.
*        ENDIF.
* 20260526 JosephLo 壓縮 End
      ENDIF.

      "PO / 價格
      ls_data-ebeln = ls_upload-ebeln.
      PERFORM get_default_netprice USING ls_data.
      PERFORM get_sales_price      USING ls_data.

* V014 Added by Tristan 2026/05/06 *
* 市購F不展下階(兩廠互買除外)
* 判斷：父階: (只需判斷父階)
* 採購類型 (MARC-BESKZ) = F and
* 特殊採購 (MARC-SOBSL)= ''
* And
* 預設供應商 (ZDEFAULT_VENDOR) not in ('11200', '21200')
* 代表此筆為供應商備料，則此筆的確認子階需求數量(MOQ_CONFIRM) =0 。
*-----------------------------------------------------------------------------*
* 20260522 JosephLo Mark Start
* 原因：reassign_moq_confirm 只抓「單一父階」(lt_bom 第一筆)，當子件掛在多個父階下時，
*       會因其中「一個」有預設供應商的父階，就把「整筆」需求/單位用量/MOQ_CONFIRM 歸 0，
*       誤殺其他「無供應商父階」的合理需求 (例：A1501-005382B 掛在玩具-小星星 B/C 兩父階，
*       B 有供應商被抓到→整筆歸0，C 的 72 被連帶清掉)。
* 取代：explode_bom (約 line 3562) 已逐位置 (per-position) 做相同的 V014 父階供應商歸零，
*       並只把「該位置」的 mngko 歸 0 後累加成 Σmngko；配合需求數量已改用 ls_stpox-menge
*       (= Σmngko/bmeng × 台數)，需求/單位用量/MOQ_CONFIRM 均已 per-position V014-aware。
*       故此處 (彙總後、單一父階、全有全無) 已重複且有害，整段 Mark 掉，
*       V014 統一由 explode_bom 處理。
*      IF zdefault_vendor <> '' AND zdefault_vendor NOT IN r_lifnr.
*        PERFORM reassign_moq_confirm CHANGING ls_data.
*      ENDIF.
* 20260522 JosephLo Mark End
*-----------------------------------------------------------------------------*
* V014 End off *
      "存入暫存
      APPEND ls_data TO lt_step1.
      CLEAR ls_data.

    ENDLOOP. "lt_stpox
* V013 Added by Tristan 2026/05/12 *
    PERFORM assign_rem_data TABLES lt_step1 lt_stpox USING ls_upload.
* 詢單展BOM階層資料
    IF lt_bom[] IS NOT INITIAL.
      CLEAR tmp_bom.
      PERFORM reassign_parent_idnrk TABLES tmp_bom USING ls_upload ls_topmat.
      APPEND LINES OF tmp_bom TO it_bom.
    ENDIF.
* V013 End off *
  ENDLOOP. "gt_upload
* V022 Changed by JosephLo 20260526 *
* 移除 V013 的 SORT it_liab + DELETE ADJACENT DUPLICATES — 經全代碼核對為死碼：
*   - it_liab 唯二的 read 點在 get_stock_qty 的 REDUCE，透過 3 個 caller
*     (process_data 主迴圈 LOOP AT lt_stpox、assign_rem_data 的兩個 Block)觸發，
*     全部在本 ENDLOOP gt_upload 之前就已執行完畢。
*   - 本段(ENDLOOP gt_upload 之後)再無任何路徑讀 it_liab：grep 確認無
*     LOOP AT / READ TABLE / FOR ALL ENTRIES IN @it_liab；後續 PATCH F/G、
*     calc_moq_qty、ALV 設定、所有按鈕(RECALC/CONFIRM/SAVE)路徑也都不讀 it_liab。
*   - 等於這段去重跑得太晚、清掉的資料沒人讀，對 z_end_balance 過度累加沒有救。
* 去重邏輯改放在 get_liability 內 APPEND 之前(從源頭防止重複累加)，
*   並配套加 CLEAR it_liab 於本 FORM 開頭(防跨次殘留)。
* 原 V013 碼以註解保留為歷史:
** V013 Added by Tristan 2026/04/17 *
**  SORT it_liab.
**  DELETE ADJACENT DUPLICATES FROM it_liab COMPARING period vtweg werks zcpnocn ztunyn zportalno zqty_sy.
** V013 End off *
* V022 End off *
  "Step 3 (PATCH F-2): 批次取 PIR
  IF lt_keys IS NOT INITIAL.
    PERFORM get_independent_demand_batch
      USING lt_keys
      CHANGING lt_demand.

    "Step 5 (PATCH G): 只針對電子件才補 PIR
    LOOP AT gt_data ASSIGNING <ls_d>.
      READ TABLE lt_demand INTO ls_dmd
           WITH KEY matnr    = <ls_d>-idnrk
                    werks    = <ls_d>-werks
                    req_date = <ls_d>-req_date.
      IF sy-subrc = 0 AND ls_dmd-qty IS NOT INITIAL.

        "呼叫 PATCH G 判斷是否電子件
        DATA(lv_is_elec) = abap_false.
        PERFORM is_electronic_part USING <ls_d>-idnrk CHANGING lv_is_elec.

        IF lv_is_elec = abap_true.
          <ls_d>-stock_qty = <ls_d>-stock_qty + ls_dmd-qty.
        ENDIF.

      ENDIF.
    ENDLOOP.
  ENDIF.

  "Step 6: MOQ/可做台數計算
  PERFORM calc_moq_qty TABLES lt_step1 USING ''.
* V013 Added by Tristan 2026/04/17 *
* LT_DATA就是ISMOQ = 'X'的資料
*  APPEND LINES OF pt_data TO gt_data.
* V013 End off *
  "Step 7: ALV 燈號 & 欄位控制
  LOOP AT gt_data ASSIGNING <ls_data>.
    CLEAR: lt_edit.
    IF <ls_data>-qq IS NOT INITIAL.
      <ls_data>-icon = icon_green_light.
      ls_edit-fieldname = 'SEL'.
      ls_edit-style     = cl_gui_alv_grid=>mc_style_disabled.
      INSERT ls_edit INTO TABLE lt_edit.
      INSERT LINES OF lt_edit INTO TABLE <ls_data>-cellstyles.
    ENDIF.
* V013 Added by Tristan 2026/04/24 *
    IF <ls_data>-ismoq IS NOT INITIAL.
*      ls_edit-fieldname = 'MOQ_CONFIRM'.
*      ls_edit-style     = cl_gui_alv_grid=>mc_style_disabled.
*      INSERT ls_edit INTO TABLE lt_edit.

      ls_edit-fieldname = 'SEL'.
      ls_edit-style     = cl_gui_alv_grid=>mc_style_enabled.
      INSERT ls_edit INTO TABLE lt_edit.
      INSERT LINES OF lt_edit INTO TABLE <ls_data>-cellstyles.
    ENDIF.
* V013 End off *
  ENDLOOP.

ENDFORM.  "process_data


*&---------------------------------------------------------------------*
*& Form confirm_get_qq
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM confirm_get_qq .
* ┌─ 設計決策 20260622 V032 JosephLo:取號 busy-spin「本次刻意不改」的原因(供日後要改時參考)─────────┐
* │ 現況:本 FORM 及其呼叫的 get_qq_seq,取 QQ 號/序號時對號碼範圍 ZCX_QQ_NR / ZCX_QQ_SEQ 手動 ENQUEUE,
* │   搶不到時用「DO 1000 TIMES. ENDDO.」空轉(忙等待、非 WAIT)重試。這段是 MOQ 並行鎖(V028 EZGCX0001LOCK)
* │   設計「之前」就有的舊取號碼邏輯。
* │ 已做(V032 b):取號失敗時原 MESSAGE-E 會中斷→跳過 DEQUEUE 與 save_data 的 COMMIT→孤鎖卡人。已改成
* │   MESSAGE-I + LEAVE TO TRANSACTION 結束本交易、自動釋放所有鎖→堵掉「孤鎖」的主要來源。
* │ 本次「不動」那段 DO 1000 空轉,理由:
* │  (1) 加 MOQ 鎖後,「同分區」(生管E/採購F)的下一個人被鎖在外、進不到這裡→同分區不可能撞號碼鎖。
* │  (2) 唯一殘留撞鎖=「跨角色(生管+採購)同時產QQ」——MOQ 鎖是分區、ZCX_QQ_NR 是全域,粒度不對齊;
* │      但這種撞是毫秒級、會自己解開,不是凍結。
* │  (3) 真正「無限空轉凍結」只在號碼鎖被『孤掉』(系統異常)才會發生;主因已由 V032 b 堵掉、dump 也會
* │      rollback 自動放鎖→殘留風險極低。
* │  (4) 不用 WAIT('真 sleep')取代空轉:WAIT 會觸發隱性 COMMIT→提早放掉外層 _scope='2' 的 MOQ 鎖→破壞防雙報。
* │  (5) 改這段=動到老的號碼範圍邏輯(風險:跳號/行為變動),為極罕見的殘留風險不划算。
* │ 將來若真要根治(讓撞鎖「完全不可能」),較大但乾淨的兩條路:
* │   (a) 把號碼鎖也做成分區(生管/採購各一條號碼範圍),與 MOQ 鎖粒度對齊;或
* │   (b) 把 MOQ 鎖改成全域單鎖(一次只一人計算/產QQ),自然涵蓋號碼鎖。
* └────────────────────────────────────────────────────────────────────────┘
  "取QQ單序號
  PERFORM get_qq_seq.


  DATA:lv_qq TYPE char12.
  LOOP AT gt_data INTO DATA(ls_d) WHERE sel IS NOT INITIAL AND qq IS INITIAL AND moq_qty IS NOT INITIAL
                  GROUP BY ( vtweg = ls_d-vtweg ) INTO DATA(lg_data).

    CLEAR:lv_qq.

    IF lv_qq IS INITIAL.
      DO.
        CALL FUNCTION 'NUMBER_RANGE_ENQUEUE'
          EXPORTING
            object           = 'ZCX_QQ_NR'
          EXCEPTIONS
            foreign_lock     = 1
            object_not_found = 2
            system_failure   = 3
            OTHERS           = 4.
        IF sy-subrc <> 0.
          DO 1000 TIMES. ENDDO.
        ELSE.
          EXIT.
        ENDIF.
      ENDDO.

      DO.
        CALL FUNCTION 'NUMBER_GET_NEXT'
          EXPORTING
            nr_range_nr             = '00'
            object                  = 'ZCX_QQ_NR'
          IMPORTING
            number                  = lv_qq
          EXCEPTIONS
            interval_not_found      = 1
            number_range_not_intern = 2
            object_not_found        = 3
            quantity_is_0           = 4
            quantity_is_not_1       = 5
            interval_overflow       = 6
            buffer_overflow         = 7
            OTHERS                  = 8.
        IF sy-subrc <> 0.
* 20260622 V032 JosephLo 取QQ號失敗→原 MESSAGE-E 中斷會跳過下方 DEQUEUE 與 save_data 的 COMMIT→孤鎖(EZGCX0001LOCK
*   +號碼鎖)卡住別人。改 MESSAGE-I + LEAVE TO TRANSACTION 結束本交易→LUW 結束→所有鎖自動釋放(罕見:號碼範圍異常才觸發)。
*MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
          MESSAGE '取QQ號失敗(號碼範圍 ZCX_QQ_NR 異常),系統將重啟本交易以釋放鎖' TYPE 'I'.
          LEAVE TO TRANSACTION sy-tcode.
        ELSE.
          EXIT.
        ENDIF.
      ENDDO.
      CALL FUNCTION 'NUMBER_RANGE_DEQUEUE'
        EXPORTING
          object           = 'ZCX_QQ_NR'
        EXCEPTIONS
          object_not_found = 1
          OTHERS           = 2.
    ENDIF.
    READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
    LOOP AT GROUP lg_data ASSIGNING   FIELD-SYMBOL(<ls_data>).
      <ls_data>-qq = 'QQ' && lv_qq.
      <ls_data>-qq_status = SWITCH #( ls_role-role WHEN 'A' THEN 'A' WHEN 'C' THEN 'D' ).
      IF <ls_data>-erdat IS NOT INITIAL.
        <ls_data>-chdat = sy-datum.
        <ls_data>-chtim = sy-uzeit.
        <ls_data>-chnam = sy-uname.
      ELSE.
        <ls_data>-erdat = sy-datum.
        <ls_data>-ernam = sy-uname.
        <ls_data>-ertim = sy-uzeit.
      ENDIF.
      <ls_data>-icon = icon_green_light.
    ENDLOOP.

  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form save_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM save_data .
  DATA:lt_moq TYPE TABLE OF ztcx0001.

* 20260524 JosephLo 統一異常顯示重構(D6=b 逐筆擋)：不再因 gt_sku_err 有料就整批 RETURN；
*   改於寫入迴圈逐列比對 gt_sku_err 跳過(缺客戶型號件絕不寫DB)，正常件照存。

  LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>) WHERE sel IS NOT INITIAL." AND qq IS NOT INITIAL AND erdat IS NOT INITIAL.
* d6 逐列防呆：無客戶型號件絕不寫db(理論上不在 gt_data，保險 + 防未來改建列)
    IF line_exists( gt_sku_err[ matnr = <ls_data>-matnr vtweg = <ls_data>-vtweg ] ).
      CONTINUE.
    ENDIF.
* V011 add by Ky 出現 Divid by 0 Dump
* V026 JosephLo 20260611 — ★可做台數必須在 MOVE-CORRESPONDING 之前算妥(順序修正)。
*   否則 calc_out_qty 更新的 OUT_QTY 來不及進 <ls_moq>→lt_moq,MODIFY ztcx0001 會寫到舊值
*   (此順序問題改版前就潛在:舊的 out_qty 重算也在 MOVE-CORRESPONDING 之後)。
*   共用 FORM calc_out_qty 讀本列 moq_remain(=報的MOQ數量−不足額),確保顯示=寫入 DB 一致。
    PERFORM calc_out_qty CHANGING <ls_data>.
    APPEND INITIAL LINE TO lt_moq ASSIGNING FIELD-SYMBOL(<ls_moq>).
    MOVE-CORRESPONDING <ls_data> TO <ls_moq>.
    IF <ls_moq>-erdat IS INITIAL.
      <ls_data>-erdat = <ls_moq>-erdat = sy-datum.
      <ls_data>-ertim = <ls_moq>-ertim = sy-uzeit.
      <ls_data>-ernam = <ls_moq>-ernam = sy-uname.
    ELSE.
      IF p_mod IS NOT INITIAL.
        <ls_data>-chdat = <ls_moq>-chdat = sy-datum.
        <ls_data>-chtim = <ls_moq>-chtim = sy-uzeit.
        <ls_data>-chnam = <ls_moq>-chnam = sy-uname.
      ENDIF.
    ENDIF.
  ENDLOOP.
  IF lt_moq IS NOT INITIAL.
* V015 Added by Tristan 2026/04/29 *
* 詢單展BOM階層資料
    IF it_bom[] IS NOT INITIAL.
      IF r_zportalno[] IS NOT INITIAL.
        DELETE FROM ztcx0001_bom WHERE zportalno IN r_zportalno.
      ENDIF.
      MODIFY ztcx0001_bom FROM TABLE it_bom.
    ENDIF.
* V015 End off *
* V013 Added by Tristan 2026/05/12 *
* 撈出既有已經存在的資料 如果已經存在就不要回寫 避免資料被不報MOQ的覆蓋
    IF pt_data[] IS NOT INITIAL.
      SELECT werks, vtweg, zseq, zportalno, idnrk
        FROM ztcx0001
         FOR ALL ENTRIES IN @pt_data
       WHERE werks = @pt_data-werks
         AND vtweg = @pt_data-vtweg
         AND zseq = @pt_data-zseq
         AND zportalno = @pt_data-zportalno
         AND idnrk = @pt_data-idnrk
        INTO TABLE @DATA(it_exist).
      SORT it_exist BY werks vtweg zseq zportalno idnrk.
    ENDIF.
    LOOP AT pt_data INTO DATA(wa_data).
* d6 逐列防呆：無客戶型號件絕不寫db(pt_data 理論上不含此類，保險)
      IF line_exists( gt_sku_err[ matnr = wa_data-matnr vtweg = wa_data-vtweg ] ).
        CONTINUE.
      ENDIF.
      READ TABLE it_exist TRANSPORTING NO FIELDS WITH KEY werks = wa_data-werks
                                                          vtweg = wa_data-vtweg
                                                          zseq = wa_data-zseq
                                                          zportalno = wa_data-zportalno
                                                          idnrk = wa_data-idnrk
                                                 BINARY SEARCH.
      CHECK sy-subrc <> 0.
      APPEND INITIAL LINE TO lt_moq ASSIGNING <ls_moq>.
      MOVE-CORRESPONDING wa_data TO <ls_moq>.
      <ls_moq>-erdat = sy-datum.
      <ls_moq>-ertim = sy-uzeit.
      <ls_moq>-ernam = sy-uname.
    ENDLOOP.
* V013 End off *
* V019 Added by Tristan 2026/05/18 *
    IF del_log[] IS NOT INITIAL.
      DELETE ztcx0001 FROM TABLE del_log.
    ENDIF.
* V019 End off *
    MODIFY ztcx0001 FROM TABLE lt_moq.
    COMMIT WORK AND WAIT.
    MESSAGE s001(00) WITH 'Update complete'.
    gv_save = 'X'.
  ELSE.
* 20260622 V032 JosephLo Fix 並行鎖孤鎖:寫入路徑(_scope='2')靠本 FORM 的 COMMIT WORK 釋放 EZGCX0001LOCK;但原 COMMIT
*   只在「有寫入(lt_moq 非空)」時跑 → 若這次實際寫 0 筆(選到的列全被 gt_sku_err 逐列跳過等)→ 不 COMMIT → 鎖不放
*   → 孤鎖卡住別人(SM12 殘留 ZTGCX0001_LOCK)。補:寫 0 筆時也做一次空 COMMIT WORK(無 DB 變更,純釋放 _scope='2' 鎖)。
    COMMIT WORK AND WAIT.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form check_sku_err
*&   ⚠ 20260525 JosephLo 已無呼叫端(確認QQ的提示已移除；無客戶型號改由上傳 popup 呈現)。暫保留以備回退。
*&   V020 JosephLo 2026/05/22
*&   交易(Save/產生QQ)前檢查 global 清單 gt_sku_err（上傳時記錄的
*&   「無 BOM 且 ZTSD0020 ZTYPE=2 查無客戶型號」件號）。
*&   有資料則回傳訊息（前 5 筆 + 總筆數），呼叫端據此擋下不寫 DB。
*&---------------------------------------------------------------------*
FORM check_sku_err CHANGING cv_msg TYPE string.
  CLEAR cv_msg.
  IF gt_sku_err IS INITIAL.
    RETURN.
  ENDIF.
  DATA lv_i TYPE i.
  CLEAR lv_i.
  LOOP AT gt_sku_err INTO DATA(ls_e).
    lv_i = lv_i + 1.
    IF lv_i > 5.
      EXIT.
    ENDIF.
    IF cv_msg IS INITIAL.
      cv_msg = ls_e-matnr.
    ELSE.
      cv_msg = |{ cv_msg }, { ls_e-matnr }|.
    ENDIF.
  ENDLOOP.
  cv_msg = |客戶型號不存在(共 { lines( gt_sku_err ) } 筆)，請洽業務：{ cv_msg }|.
  IF lines( gt_sku_err ) > 5.
    cv_msg = |{ cv_msg } …等|.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_report_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_report_data .
  DATA:lr_loekz TYPE RANGE OF loekz.
  IF p_mod IS NOT INITIAL.
    lr_loekz = VALUE #( sign = 'I' option = 'EQ' ( low = '' ) ).
  ENDIF.
  SELECT * FROM ztcx0001
    WHERE werks IN @s_werks
      AND vtweg IN @s_vtweg
      AND beskz IN @s_beskz
      AND idnrk IN @s_idnrk
      AND zportalno IN @s_pr
      AND qq IN @s_qq
      AND vbeln IN @s_so
      AND qq_status IN @s_status
      AND erdat IN @s_erdat
      AND skuitem IN @s_sku
      AND loekz IN @lr_loekz
* V017 Added by Tristan 2026/05/14 *
      AND ismoq = ''
* V017 End off *
   INTO TABLE @DATA(lt_data).

  LOOP AT lt_data INTO DATA(ls_data).
    IF p_dis IS NOT INITIAL.
      APPEND INITIAL LINE TO gt_report ASSIGNING FIELD-SYMBOL(<ls_report>).
      MOVE-CORRESPONDING ls_data TO <ls_report>.
      SELECT SINGLE
             wl2_thenameoftheerp,
             wl2_erpspecification,
             zdefault_vendor
        FROM ztmara INNER JOIN ztmarc ON ztmara~matnr = ztmarc~matnr
      WHERE ztmara~matnr = @ls_data-idnrk
        AND ztmarc~werks = @ls_data-werks
      INTO CORRESPONDING FIELDS OF @<ls_report>.

      SELECT SINGLE name1 FROM lfa1
        WHERE lifnr = @<ls_report>-zdefault_vendor
      INTO @<ls_report>-vendor_name1.
    ELSEIF p_mod IS NOT INITIAL.
      APPEND INITIAL LINE TO gt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      MOVE-CORRESPONDING ls_data TO <ls_data>.
    ENDIF.


  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form calc_7day_qq
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      --> <LS_DATA>
*&---------------------------------------------------------------------*
FORM calc_7day_qq  TABLES pt_tab
                    USING p_data LIKE LINE OF gt_data
                          p_tot_req LIKE p_data-moq_7day_req.
  DATA:pt_exist_moq TYPE TABLE OF zscx0001_alv. "和本次上傳調整的子件相同的資料
  DATA:lv_from_date TYPE sy-datum.
  DATA:lv_remain_qty LIKE p_data-menge. "餘數
  DATA:lv_moq_qty LIKE p_data-moq_qty.
  DATA:lt_ztcx0008 TYPE TABLE OF ztcx0008.
  DATA:lv_tabix TYPE sy-tabix.
  lv_from_date = sy-datum - 6.
* V006 Added by Tristan 2026/02/13  春節假期要跳過,所以移動了起算日*
* V006 Add by Ky 2026/4/1 清明假期*
  IF sy-datum >= '20260407' AND sy-datum <= '20260410'.
    lv_from_date = sy-datum - 8.
  ENDIF.
* V006 End off *
  pt_exist_moq = pt_tab[].
  READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
  CLEAR lt_ztcx0008.
  LOOP AT gt_custmap INTO DATA(ls_custmap) WHERE vtweg = p_data-vtweg AND zseq = p_data-zseq.
    APPEND ls_custmap TO lt_ztcx0008.
  ENDLOOP.
  SELECT * FROM ztcx0001
    FOR ALL ENTRIES IN @lt_ztcx0008
    WHERE vtweg = @p_data-vtweg
      AND idnrk = @p_data-idnrk
      AND werks = @lt_ztcx0008-werks
      AND ( qq_status = 'A' OR qq_status = 'D' ) "A-  生管已確認
      AND erdat BETWEEN @lv_from_date AND @sy-datum
      AND moq_remain > 0 "MOQ結餘=0的 就不用考慮，當成新的計算
      AND loekz IS INITIAL
  INTO TABLE @DATA(lt_moq).

  LOOP AT lt_moq INTO DATA(ls_moq).
    lv_tabix = sy-tabix.
    READ TABLE pt_exist_moq WITH KEY werks = ls_moq-werks
                                     vtweg = ls_moq-vtweg
                                     zseq = ls_moq-zseq
                                     zportalno = ls_moq-zportalno
                                     idnrk = ls_moq-idnrk TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      DELETE lt_moq INDEX lv_tabix.
    ENDIF.
  ENDLOOP.
  SORT lt_moq BY qq_seq chdat chtim erdat ertim.
  SELECT * FROM ztcx0001
    FOR ALL ENTRIES IN @lt_ztcx0008
    WHERE vtweg = @p_data-vtweg
      AND werks = @lt_ztcx0008-werks
      AND zportalno NE @p_data-zportalno
      AND idnrk = @p_data-idnrk
      AND qq_status IS INITIAL
      AND qq IS INITIAL
      AND erdat BETWEEN @lv_from_date AND @sy-datum
      AND loekz IS INITIAL
      AND qq_seq IS NOT INITIAL
  INTO TABLE @DATA(lt_7day_comp).
  LOOP AT lt_7day_comp INTO DATA(ls_7day).
    lv_tabix = sy-tabix.
    READ TABLE pt_exist_moq WITH KEY werks = ls_7day-werks
                                     vtweg = ls_7day-vtweg
                                     zseq = ls_7day-zseq
                                     zportalno = ls_7day-zportalno
                                     idnrk = ls_7day-idnrk TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      DELETE lt_7day_comp INDEX lv_tabix.
    ENDIF.
  ENDLOOP.
  SORT lt_7day_comp BY qq_seq chdat chtim erdat ertim.

  IF lt_moq IS NOT INITIAL.
    "取最新的那筆報MOQ數量以及MOQ結餘
    LOOP AT lt_moq INTO DATA(ls_lastmoq).
      lv_moq_qty = ls_lastmoq-moq_qty.
      lv_remain_qty = ls_lastmoq-moq_remain.
    ENDLOOP.

* V023 Added by JosephLo 20260527 *
* ALV 顯示欄填值 — 走「有前期結餘」分支:
*   moq_prior_link: hotspot 文字,使用者點選 → 觸發 FORM hotspot_show_prior_moq
*                   彈 popup 顯示同子件過去 7 天內所有 ZTCX0001 列(放寬版)
*   z_basis_used:   本期 MOQ 計算實際採用的基準。此分支用前期結餘,完全不碰
*                   stock_qty/z_end_balance,所以標「前期結餘 (xxx)」更精準
* 注意:此分支以下還會分 3 個 sub-case(不需報/缺口>=MOQ/缺口<MOQ),不管走哪個
*   sub-case,計算用的都是前期 lv_remain_qty (從 ls_lastmoq),basis 都用不到 →
*   所以這兩欄在 LOOP 結束、進入 sub-case 判斷之前就可以一次設好。
    p_data-moq_prior_link = |→ 上期結餘 { lv_remain_qty } ({ ls_lastmoq-qq }) 點選看明細|.
    p_data-z_basis_used   = |前期結餘 ({ lv_remain_qty })|.
* V023 End off *

    "這次上傳詢單的 7 天內總需求 <= 結餘
    IF lv_remain_qty >= p_data-moq_7day_req.
      "不需報MOQ
      p_data-moq_qty = 0.
      p_data-qq = ls_lastmoq-qq.
      IF p_data-erdat IS NOT INITIAL.
        p_data-chdat = sy-datum.
        p_data-chtim = sy-uzeit.
        p_data-chnam = sy-uname.
      ELSE.
        p_data-erdat = sy-datum.
        p_data-ertim = sy-uzeit.
        p_data-ernam = sy-uname.
      ENDIF.
      "MOQ 結餘 =  結餘 - 這次上傳詢單的 7 天內總需求
      p_data-moq_remain = lv_remain_qty - p_data-moq_7day_req.
      p_data-icon = icon_green_light.
      p_data-qq_status = SWITCH #( ls_role-role WHEN 'A' THEN 'A' WHEN 'C' THEN 'D' ).
    ELSE.
      lv_remain_qty = p_data-moq_7day_req - lv_remain_qty.
      "這次上傳詢單的 7 天內總需求 - 上期結餘 > MOQ 設定->不報，QQ單直接帶上期QQ單
      IF lv_remain_qty >= p_data-zmoq.
        p_data-moq_qty = 0.
        p_data-qq_status = SWITCH #( ls_role-role WHEN 'A' THEN 'A' WHEN 'C' THEN 'D' ).
        p_data-qq = ls_lastmoq-qq.
        "如果前一次是有報MOQ，直接設定剩餘MOQ量=前一次的剩餘MOQ量
        IF lt_7day_comp IS INITIAL.
          "p_data-moq_remain = ls_lastmoq-moq_remain.
          "20250527 modify: 1.1 本次詢單需求-上次MOQ結餘 >= MOQ，則 MOQ結餘 = 0
          p_data-moq_remain = 0.
        ELSE.
          "如果前7天還有不報MOQ的詢單，把剩餘MOQ量設為0，7天內總需求扣掉之前的剩餘MOQ量
          p_data-moq_remain = 0.
          LOOP AT lt_7day_comp INTO ls_7day.
            p_data-moq_7day_req = p_data-moq_7day_req - ls_7day-moq_remain.
            EXIT.
          ENDLOOP.
        ENDIF.

      ELSE.
        "這次上傳詢單的 7 天內總需求 - 結餘 <= MOQ 設定-> 報MOQ 且成立新的 QQ 單
        p_data-moq_qty = p_data-zmoq.
        p_data-qq = ''.
        p_data-qq_status = ''.
        "20250527 modify: 1.2 本次詢單需求-上次MOQ結餘 > 0 & < MOQ，則 MOQ結餘 = 上期MOQ結餘+MOQ -本期需求
        p_data-moq_remain = ls_lastmoq-moq_remain + p_data-moq_qty - p_data-moq_7day_req.
      ENDIF.

      IF p_data-erdat IS NOT INITIAL.
        p_data-chdat = sy-datum.
        p_data-chtim = sy-uzeit.
        p_data-chnam = sy-uname.
      ELSE.
        p_data-erdat = sy-datum.
        p_data-ertim = sy-uzeit.
        p_data-ernam = sy-uname.
      ENDIF.
      p_data-icon = icon_green_light.
    ENDIF.
  ELSE.
    "MOQ結餘 = 報MOQ - 7天內總需求
* V023 Added by JosephLo 20260527 *
* ALV 顯示欄填值 — 走「首次分支」(lt_moq IS INITIAL,無前期結餘):
*   z_basis_used: 依 gv_moq_basis 顯示對應的庫存類型與當前數值
*     'L' → Liability 餘額 (z_end_balance 的值)
*     'S' → 理論庫存 (stock_qty 的值)
*   moq_prior_link: 維持空白(首次分支沒有前期紀錄、不需要 hotspot)
* 這欄不管 moq_qty 是否 > 0、不管後續 §5.1 公式怎麼算,都要填——讓使用者
*   一眼看出「本期 MOQ 是用哪個基準算的」,便於 dev/qa (ZTGCX0001A 預覽 t-code)
*   切換 L/S 對比驗證。
    IF gv_moq_basis = 'L'.
      p_data-z_basis_used = |Liability 餘額 ({ p_data-z_end_balance })|.
    ELSE.
      p_data-z_basis_used = |理論庫存 ({ p_data-stock_qty })|.
    ENDIF.
* V023 End off *
* V022 Changed by JosephLo 20260526 *
* §5.1 MOQ 結餘 (moq_remain) 計算基準動態切換 — 依 gv_moq_basis 選用
*   (參見 FORM choose_moq_basis)
*   gv_moq_basis = 'L': 用 z_end_balance (Liability 餘額,本案目標的新基準)
*   gv_moq_basis = 'S': 用 stock_qty (理論庫存,V013 改回後維持的舊基準)
* 此分支是 calc_7day_qq 的「首次分支」(lt_moq IS INITIAL,前期無同子件 MOQ 結餘紀錄)。
* 用中介變數 lv_basis_qty 收斂基準取值,避免下方 IF/ELSE 對 (moq_qty+基準) 跟 (基準) 兩種
*   公式各寫兩遍 (一個 stock_qty 版、一個 z_end_balance 版)。
* 理由同 §5.2 lv_req_qty (calc_moq_qty)：取代 V013 註解+改回 stock_qty 的單一基準寫法,
*   保留 dev/qa 對比能力。原 V013 註解版保留於下方雙 * 註解區。
    IF p_data-moq_qty > 0.
      DATA lv_basis_qty LIKE p_data-z_end_balance.
      IF gv_moq_basis = 'L'.
        lv_basis_qty = p_data-z_end_balance.
      ELSE.
        lv_basis_qty = p_data-stock_qty.
      ENDIF.
      IF p_tot_req - lv_basis_qty > 0.
        p_data-moq_remain = p_data-moq_qty + lv_basis_qty - p_tot_req.
      ELSE.
        p_data-moq_remain = lv_basis_qty - p_tot_req.
      ENDIF.
    ENDIF.
* V022 End off *
** V013 changed by tristan 2026/04/17 (V022 已用 lv_basis_qty + IF 分流取代,原碼保留為歷史) *
**      IF p_tot_req - p_data-z_end_balance > 0.
**        p_data-moq_remain = p_data-moq_qty  + p_data-z_end_balance - p_tot_req.
**      ELSE.
**        p_data-moq_remain = p_data-z_end_balance - p_tot_req.
**      ENDIF.
** V013 end off *
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_stock_qty
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LS_DATA
*&---------------------------------------------------------------------*
FORM get_stock_qty  USING    p_data LIKE LINE OF gt_data.
  DATA:lv_extra LIKE p_data-stock_qty.
  DATA:lr_delkz_sup TYPE RANGE OF delkz,
       lr_delkz_dem TYPE RANGE OF delkz.
  "多餘供給：抓取ZTPPRP0019，以該料號+工廠+當天日期找到多筆進行累加
  SELECT SUM( quantity ) FROM ztpprp0019
    INNER JOIN @gt_custmap AS custmap
      ON ztpprp0019~plant = custmap~werks ##ITAB_KEY_IN_SELECT
    WHERE article_long = @p_data-idnrk
      AND custmap~vtweg = @p_data-vtweg
      AND zdsdat = @sy-datum
      AND deletion_flag IS INITIAL
  INTO @lv_extra.
  p_data-extra_sup = lv_extra.

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
                            ( low = 'BE' ) "採購單-外包
                            ( low = 'E1' ) "STO 單收貨廠
                            ( low = 'E1' ) "STO 單收貨廠-外包
                            ( low = 'VJ' ) "交貨單 (Inboound DN)

                        ).
  lr_delkz_dem = VALUE #( sign = 'I' option = 'EQ'
                            ( low = 'VC' ) "銷售訂單
                            ( low = 'VC' ) "出貨單 (Outbound DN)
                            ( low = 'PP' ) "計劃性獨立需求
                            ( low = 'SB' ) "計劃單元件需求
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
*  SELECT zdsdat,SUM( mng01 ) AS mng01 FROM ztpprp0011
*    INNER JOIN @gt_custmap AS custmap
*      ON ztpprp0011~mdwrk = custmap~werks ##ITAB_KEY_IN_SELECT
*    WHERE matnr = @p_data-idnrk
*      AND custmap~vtweg = @p_data-vtweg
*      AND mdwrk = @p_data-werks
*      AND delkz IN @lr_delkz_sup
*  GROUP BY zdsdat,zdsdatno
*    ORDER BY zdsdat DESCENDING, zdsdatno DESCENDING
*  INTO TABLE @DATA(lt_sup).
*  READ TABLE lt_sup INTO DATA(ls_sup) INDEX 1.
*
*  SELECT zdsdat,SUM( mng01 ) AS mng01 FROM ztpprp0011
*    INNER JOIN @gt_custmap AS custmap
*      ON ztpprp0011~mdwrk = custmap~werks ##ITAB_KEY_IN_SELECT
*    WHERE matnr = @p_data-idnrk
*      AND custmap~vtweg = @p_data-vtweg
*      AND mdwrk = @p_data-werks
*      AND delkz IN @lr_delkz_dem
*      "AND zdsdat = @p_data-req_date
*  GROUP BY zdsdat,zdsdatno
*    ORDER BY zdsdat DESCENDING, zdsdatno DESCENDING
*  INTO TABLE @DATA(lt_dem).
*  READ TABLE lt_dem INTO DATA(ls_dem) INDEX 1.
  "理論庫存：MRP總供給 - MRP總需求
  "p_data-stock_qty = ls_sup-mng01 - ls_dem-mng01.
  "理論庫存：20250410: call ZPRP016 可用供給
  PERFORM get_stock_qty_call_zprp016 CHANGING p_data.
* V013 Added by Tristan 2026/04/17 *
  IF p_data-zind01 = 'C'.
    p_data-z_end_balance = REDUCE #( INIT zqty_sy TYPE ze_zqty_sy
                         FOR ls_liab IN it_liab WHERE ( vtweg = p_data-vtweg
                                                    AND werks = p_data-werks
                                                    AND zpno = p_data-idnrk
                                                    AND ztunyn = 'C'
                                                    AND zcpnocn = p_data-skuitem )
                        NEXT zqty_sy = zqty_sy + ls_liab-zqty_sy ).
  ELSE.
    p_data-z_end_balance = REDUCE #( INIT zqty_sy TYPE ze_zqty_sy
                         FOR ls_liab IN it_liab WHERE ( vtweg = p_data-vtweg
                                                    AND werks = p_data-werks
                                                    AND zpno = p_data-idnrk )
*                                                    AND zcpnocn = p_data-skuitem )
                        NEXT zqty_sy = zqty_sy + ls_liab-zqty_sy ).
  ENDIF.
* V013 End off *
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
  IF p_imp IS NOT INITIAL.
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
*& Form get_global_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_global_data .
* V002 Added by Tristan 2026/01/15 *
  CHECK p_fix = ''.
* V002 End off *
  SELECT * FROM ztcx0008 INTO TABLE @gt_custmap.
  IF gt_custmap IS INITIAL.
    MESSAGE e010.
  ENDIF.
  SELECT * FROM ztcx0014 INTO TABLE @gt_nomoq.

  SELECT * FROM ztcx0003 WHERE uname = @sy-uname INTO TABLE @gt_role.
* 2026/06/01 JosephLo 修正 p_upd 權限缺口:原 (p_imp OR p_mod OR p_mod) p_mod重複漏p_upd→無角色使用者在「上傳確認(p_upd)」也能CONFIRM寫ZTCX0001/取QQ;第二個p_mod改p_upd
  IF gt_role IS INITIAL  AND ( p_imp IS NOT INITIAL OR p_mod IS NOT INITIAL  OR p_upd IS NOT INITIAL ).
    MESSAGE e005.
  ELSE.
* 20260622 V031 JosephLo 詢單上傳(p_imp/p_upd)白名單:只允許生管(A)/採購(C);有角色但非 A/C(如業務 B)直接擋。
*   取代原註解掉的「只擋 role B」。get_global_data 為 ZTGCX0001 與 ZTGCX0001A(模擬)共用入口 →
*   模擬版上傳同樣只限 A/C;且 B 擋在此入口→到不了 check_upload_data,原 sy-subrc 殘留誤擋成「詢單號重覆」的 bug 對 B 失效。
*   訊息用 literal(不走 ZCX01-006:其文字僅「非生管」未含採購)。
    IF ( p_imp IS NOT INITIAL OR p_upd IS NOT INITIAL )
       AND NOT ( line_exists( gt_role[ role = 'A' ] ) OR line_exists( gt_role[ role = 'C' ] ) ).
      MESSAGE '非生管/採購人員不能上傳，請確認' TYPE 'E'.
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_stock_qty_call_ZPRP016
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      <-- P_DATA
*&---------------------------------------------------------------------*
FORM get_stock_qty_call_zprp016  CHANGING p_data LIKE LINE OF gt_data.
  DATA:lt_result TYPE TABLE OF zsgpprp0017_a.

  cl_salv_bs_runtime_info=>set( display  = abap_false
                                metadata = abap_false
                                data     = abap_true ).
  DATA:lr_zmatnr TYPE RANGE OF ztpprp0010-zmatnr,
       lr_zplwrk TYPE RANGE OF ztpprp0010-zplwrk,
       ls_zplwrk LIKE LINE OF lr_zplwrk.
  LOOP AT gt_custmap INTO DATA(ls_custmap) WHERE vtweg = p_data-vtweg .
    ls_zplwrk-sign = 'I'.
    ls_zplwrk-option = 'EQ'.
    ls_zplwrk-low = ls_custmap-werks.
    APPEND ls_zplwrk TO lr_zplwrk.
  ENDLOOP.
  lr_zmatnr = VALUE #( sign = 'I' option = 'EQ' ( low = p_data-idnrk ) ).
  "lr_zplwrk = VALUE #( sign = 'I' option = 'EQ' ( low = p_data-werks ) ).
  SUBMIT ztgpprp0017 WITH p_rpt1 = 'X'
                     WITH s_zmatnr IN lr_zmatnr
                     WITH s_zplwrk IN lr_zplwrk
                     WITH p_zdsdat = sy-datum
                     WITH p_chk_1 = space
    AND RETURN .
  TRY.
      cl_salv_bs_runtime_info=>get_data_ref( IMPORTING r_data = DATA(lobj_data) ).
      ASSIGN lobj_data->* TO FIELD-SYMBOL(<lfs_data>).
    CATCH cx_salv_bs_sc_runtime_info.
  ENDTRY.
  IF <lfs_data> IS ASSIGNED.
    lt_result = CORRESPONDING #( <lfs_data> ).
  ENDIF.
  LOOP AT lt_result INTO DATA(ls_result) WHERE zmatnr = p_data-idnrk .
    p_data-stock_qty = p_data-stock_qty + ls_result-avlb_suply.
  ENDLOOP.
*  READ TABLE lt_result WITH KEY zmatnr = p_data-idnrk
*                                zplwrk = p_data-werks INTO DATA(ls_result).
*  IF sy-subrc = 0.
*    p_data-stock_qty = ls_result-avlb_suply.
*  ENDIF.
  cl_salv_bs_runtime_info=>set( display  = abap_true
                                metadata = abap_true
                                data     = abap_true ).

ENDFORM.

*&---------------------------------------------------------------------*
*&  Form  GET_DEFAULT_NETPRICE — 修正版 (含 F30 判斷)
*&  目的 : 依規則取得預設淨價（僅 F 且 SOBSL≠30 才取 Info Record）
*&         並補齊 CNY/TWD 之匯率換算欄位
*&---------------------------------------------------------------------*
FORM get_default_netprice
  CHANGING p_data LIKE LINE OF gt_data.

  "========================================================
  " 1) 僅在 外購(F)，排除分包(30) 與 F30 外包，且尚無淨價時，以 PIR 補價
  "========================================================
  IF     p_data-netpr IS INITIAL
     AND p_data-beskz = 'F'
     AND p_data-sobsl <> '30'.     " 排除 F30

    PERFORM get_info_record CHANGING p_data.

  ENDIF.

  "========================================================
  " 2) 若已有淨價與幣別，補齊 CNY / TWD 之換算值
  "========================================================
  IF p_data-netpr IS NOT INITIAL
     AND p_data-waers IS NOT INITIAL.

    DATA: ls_rate_cny TYPE bapi1093_0,
          ls_rate_twd TYPE bapi1093_0,
          ls_ret      TYPE bapiret1.

    "---- 轉 CNY ----
    IF p_data-waers = 'CNY'.
      p_data-netpr_cny = p_data-netpr.
      p_data-waers_cny = 'CNY'.
    ELSE.
      CLEAR: ls_rate_cny, ls_ret.
      CALL FUNCTION 'BAPI_EXCHANGERATE_GETDETAIL'
        EXPORTING
          rate_type  = 'M'
          from_curr  = p_data-waers
          to_currncy = 'CNY'
          date       = sy-datum
        IMPORTING
          exch_rate  = ls_rate_cny
          return     = ls_ret.
      IF ls_rate_cny-exch_rate IS NOT INITIAL AND ls_ret-type IS INITIAL.
        p_data-netpr_cny = p_data-netpr * ls_rate_cny-exch_rate.
        p_data-waers_cny = 'CNY'.
      ENDIF.
    ENDIF.

    "---- 轉 TWD ----
    IF p_data-waers = 'TWD'.
      p_data-netpr_twd = p_data-netpr.
      p_data-waers_twd = 'TWD'.
    ELSE.
      CLEAR: ls_rate_twd, ls_ret.
      CALL FUNCTION 'BAPI_EXCHANGERATE_GETDETAIL'
        EXPORTING
          rate_type  = 'M'
          from_curr  = p_data-waers
          to_currncy = 'TWD'
          date       = sy-datum
        IMPORTING
          exch_rate  = ls_rate_twd
          return     = ls_ret.
      IF ls_rate_twd-exch_rate IS NOT INITIAL AND ls_ret-type IS INITIAL.
        p_data-netpr_twd = p_data-netpr * ls_rate_twd-exch_rate.
        p_data-waers_twd = 'TWD'.
      ENDIF.
    ENDIF.

  ENDIF.

ENDFORM.





*&---------------------------------------------------------------------*
*& Form delete_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM delete_data .
  DATA:lt_ztcx0008 TYPE TABLE OF ztcx0008.
  DATA:lv_from TYPE sy-datum.
  lv_from = sy-datum - 7.
  LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>) WHERE sel IS NOT INITIAL .
    <ls_data>-loekz = 'X'.
    IF <ls_data>-qq IS NOT INITIAL.
      LOOP AT gt_custmap INTO DATA(ls_custmap) WHERE vtweg = <ls_data>-vtweg AND zseq = <ls_data>-zseq.
        APPEND ls_custmap TO lt_ztcx0008.
      ENDLOOP.
      "將刪除的QQ單上的需求量加回最新的QQ單上的MOQ結餘
      SELECT * FROM ztcx0001
        FOR ALL ENTRIES IN @lt_ztcx0008
        WHERE vtweg = @<ls_data>-vtweg
          AND zseq = @<ls_data>-zseq
          AND werks = @lt_ztcx0008-werks
          AND idnrk = @<ls_data>-idnrk
          AND loekz IS INITIAL
          AND qq IS NOT INITIAL
          AND erdat BETWEEN @lv_from AND @sy-datum
      INTO TABLE @DATA(lt_qq).
      IF sy-subrc = 0.
        SORT lt_qq BY erdat DESCENDING ertim DESCENDING.
        LOOP AT lt_qq ASSIGNING FIELD-SYMBOL(<ls_qq>).
          ADD <ls_data>-menge TO <ls_qq>-moq_remain.
          EXIT.
        ENDLOOP.
        MODIFY ztcx0001 FROM TABLE lt_qq.
      ENDIF.
    ENDIF.
    <ls_data>-chdat = sy-datum.
    <ls_data>-chtim = sy-uzeit.
    <ls_data>-chnam = sy-uname.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form collect_upload_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM collect_gt_data .
  DATA: lt_data LIKE gt_data.
  DATA:ls_data LIKE LINE OF gt_data.
  DATA: ls_edit TYPE lvc_s_styl,
        lt_edit TYPE lvc_t_styl.
  LOOP AT gt_report INTO DATA(ls_upload).
    SELECT SINGLE * FROM ztcx0001
      WHERE werks = @ls_upload-werks
        AND vtweg = @ls_upload-vtweg
        AND zseq = @ls_upload-zseq
        AND zportalno = @ls_upload-zportalno
        AND idnrk = @ls_upload-idnrk
        AND loekz IS INITIAL
    INTO @DATA(ls_001).
    IF sy-subrc = 0.
      MOVE-CORRESPONDING ls_001 TO ls_data.

      ls_data-moq_confirm = ls_upload-moq_confirm.

      "MOQ
      DATA:lv_zmoq TYPE marc-bstmi.
      CLEAR:lv_zmoq.
      SELECT SINGLE bstmi FROM marc
        WHERE werks = @ls_upload-werks
          AND matnr = @ls_upload-idnrk
      INTO @lv_zmoq.
      IF sy-subrc = 0 AND lv_zmoq IS NOT INITIAL.
        ls_data-zmoq = lv_zmoq.
      ELSE.
        ls_data-zmoq = ls_upload-zmoq.
      ENDIF.
      READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
      IF sy-subrc = 0.
        CLEAR:ls_edit,lt_edit.
        IF ls_role-role = 'A'.
          "生管
          ls_edit-fieldname = 'REMARK_PP'.
          ls_edit-style = cl_gui_alv_grid=>mc_style_enabled.
          INSERT ls_edit INTO TABLE lt_edit.
          INSERT LINES OF lt_edit INTO TABLE ls_data-cellstyles.
          ls_data-remark_pp = ls_upload-remark_pp.
        ELSEIF ls_role-role = 'C'.

          "採購
          ls_edit-fieldname = 'REMARK_PUR'.
          ls_edit-style = cl_gui_alv_grid=>mc_style_enabled.
          INSERT ls_edit INTO TABLE lt_edit.
          INSERT LINES OF lt_edit INTO TABLE ls_data-cellstyles.

          ls_data-netpr = ls_upload-netpr.
          ls_data-waers = ls_upload-waers.
          ls_data-remark_pur = ls_upload-remark_pur.
*         ★防呆(20260628 V034):採購上傳料價(NETPR)卻沒填幣別(WAERS)→收 gt_excluded、跳過該列
*           (不載入可編輯 ALV、不寫 DB);進 ALV 前 show_excluded_popup 條列,採購於 Excel 補幣別後重新上傳。
*           理由:waers 空→下游 ZTGCX0032 折算 from_curr='' 必失敗、業務價算不出;詳 AAA_上傳料價幣別防呆.md。
          IF ls_data-netpr IS NOT INITIAL AND ls_data-waers IS INITIAL.
            APPEND VALUE #( sort_seq  = '96'  category = '料價缺幣別'
                            matnr_fg  = ls_data-matnr   idnrk = ls_data-idnrk
                            beskz     = ls_data-beskz   sobsl = ls_data-sobsl
                            vtweg     = ls_data-vtweg   werks = ls_data-werks
                            zportalno = ls_data-zportalno
                            reason    = '料價有但未填幣別(WAERS)，請於 Excel 補幣別後重新上傳' ) TO gt_excluded.
            CLEAR ls_data.
            CONTINUE.
          ENDIF.
        ENDIF.
      ENDIF.
      IF ls_data-erdat IS NOT INITIAL.
        ls_data-chdat = sy-datum.
        ls_data-chtim = sy-uzeit.
        ls_data-chnam = sy-uname.
      ELSE.
        ls_data-erdat = sy-datum.
        ls_data-ertim = sy-uzeit.
        ls_data-ernam = sy-uname.
      ENDIF.
      APPEND ls_data TO lt_data.CLEAR ls_data.
    ENDIF.
  ENDLOOP.
**依各子階件號+工廠加總其子階需求數量後可得到總需求數量，進一步計算理論庫存，判斷是否需要多生產或多採購。
  PERFORM calc_moq_qty TABLES lt_data   USING ''.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form calc_moq_qty
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LT_STEP1
*&---------------------------------------------------------------------*
FORM calc_moq_qty  TABLES   p_step
                    USING p_moq_flag TYPE c "抓取和計算MOQ相關欄位,X: 需計算，空白:不需計算(即上傳詢單時)
                          .
  DATA:lt_step1 LIKE gt_data.
  DATA:ls_data    LIKE LINE OF gt_data,
       lv_tot_req LIKE ls_data-moq_7day_req,
       lv_moq_qty TYPE ztcx0001-moq_qty,
       lv_req_qty LIKE ls_data-menge.
  DATA:lt_this_moq  LIKE gt_data,  "本次同子件的詢單
       lt_7day_comp TYPE TABLE OF ztcx0001,
       lt_7day_moq  TYPE TABLE OF ztcx0001,
       ls_7day_moq  LIKE LINE OF lt_7day_moq.
  DATA:lv_datetime1 TYPE char14,
       lv_datetime2 TYPE char14.
  DATA:lv_from TYPE sy-datum.
  DATA:lt_ztcx0008 TYPE TABLE OF ztcx0008.
  DATA:lr_iq TYPE RANGE OF ztcx0001-zportalno,
       ls_iq LIKE LINE OF lr_iq.
* V026 Added by JosephLo 20260609 *
* §8 淨額重算模型(僅 gv_moq_basis='L') 用的群組級供需加總。
* V027 Changed by JosephLo 20260613 — 本批合併模型:同次上傳同子件視為「一筆」(不再逐列累加)。
*   原 lv_cum_req/lv_cum_moq(序列逐列累計)→ 改 lv_batch_req/lv_batch_moq(整批一次合計),所有本批列共用同一淨額判斷。
*   供給改以 QQ 去重(一個 QQ 算一個 ZMOQ);lt_batch_qq 為本批供給去重用的 QQ 集合。詳見「分析_同次上傳多詢單應合併計算與群組QQ.md」。
  DATA:lv_supmoq_sum TYPE ztcx0001-moq_7day_req, "Σ7天報MOQ供給(別批,★QQ去重:一個QQ算一個ZMOQ,未轉XQ,已產生QQ,排除本批)
       lv_reqdb_sum  TYPE ztcx0001-moq_7day_req, "Σ7天需求(別批DB,各列加總,排除本批/轉SO/轉正/軟刪)
       lv_batch_req  TYPE ztcx0001-moq_7day_req, "本批合併需求(同次上傳同子件 Σmoq_confirm,取代逐列cum)
       lv_batch_moq  TYPE ztcx0001-moq_7day_req, "本批已confirm列供給(以QQ去重,取代逐列cum;全新上傳=0)
       lt_batch_qq   TYPE SORTED TABLE OF ztcx0001-qq WITH UNIQUE KEY table_line, "本批供給去重用QQ集合
       lv_seed_req   TYPE ztcx0001-moq_confirm,  "Pass1 暫存:本列需求(p_upd空=menge,否則=moq_confirm)
       lv_last_qq    TYPE ztcx0001-qq.           "最近一筆未轉XQ報MOQ的QQ(不報時沿用)
* V026 End off *
* V026 Added by JosephLo 20260612 — 方案D(效能):per-row 預設供應商/WL2規格(ztmara⋈ztmarc)+供應商名(lfa1)
*   原為 SELECT SINGLE 每列各一支(N+1,同 idnrk+werks/同 lifnr 重複撈)。改快取:命中不再撈 → DB 查詢由 2×列數 降為 distinct 數。
  TYPES: BEGIN OF ty_mara_c,
           idnrk                     TYPE ztcx0001-idnrk,
           werks                     TYPE ztcx0001-werks,
           wl2_thenameoftheerp       TYPE ztcx0001-wl2_thenameoftheerp,
           wl2_erpspecification      TYPE ztcx0001-wl2_erpspecification,
           wl2_englishspecifications TYPE ztcx0001-wl2_englishspecifications,
           zdefault_vendor           TYPE ztcx0001-zdefault_vendor,
         END OF ty_mara_c.
  TYPES: BEGIN OF ty_lfa1_c,
           lifnr TYPE lfa1-lifnr,
           name1 TYPE lfa1-name1,
         END OF ty_lfa1_c.
  DATA: lt_mara_c TYPE HASHED TABLE OF ty_mara_c WITH UNIQUE KEY idnrk werks,
        ls_mara_c TYPE ty_mara_c,
        lt_lfa1_c TYPE HASHED TABLE OF ty_lfa1_c WITH UNIQUE KEY lifnr,
        ls_lfa1_c TYPE ty_lfa1_c.

  lt_step1 = p_step[].
  CLEAR:gt_data.
  LOOP AT lt_step1 INTO DATA(ls_d1)
    GROUP BY ( vtweg = ls_d1-vtweg zseq = ls_d1-zseq idnrk = ls_d1-idnrk size = GROUP SIZE index = GROUP INDEX )
    INTO DATA(lg_step1).
    CLEAR:lv_tot_req,lt_this_moq,lt_7day_comp,lv_moq_qty,lt_7day_moq,ls_7day_moq,lv_datetime1.
    CLEAR:lv_supmoq_sum,lv_reqdb_sum,lv_batch_req,lv_batch_moq,lt_batch_qq,lv_last_qq. "V026/V027 §8 群組重置
*取得該子件7天內報詢單的資料
    lv_from = sy-datum - 6.
    CLEAR: lt_ztcx0008,lr_iq.
    LOOP AT GROUP lg_step1 INTO DATA(ls_step1).
      "取得客戶對應的多個工廠
      LOOP AT gt_custmap INTO DATA(ls_custmap) WHERE vtweg = ls_step1-vtweg AND zseq = ls_step1-zseq.
        COLLECT ls_custmap INTO lt_ztcx0008.
      ENDLOOP.
      ls_iq-sign = 'E'.
      ls_iq-option = 'EQ'.
      ls_iq-low = ls_step1-zportalno.
      COLLECT ls_iq INTO lr_iq.
    ENDLOOP.

* V026 Changed by JosephLo 20260612 — 方案A(效能):#1 lt_7day_comp / #2 lt_7day_moq 兩支 SELECT 只在
*   p_moq_flag='X' 用到(消費者全在下方 IF p_moq_flag='X' 區塊),故整段 gate 在此 →
*   process_data 等傳 '' 的呼叫不再白撈這兩支(詳見 calc_moq_qty_select優化.md 方案A)。
* 20260612 JosephLo ★+ lt_ztcx0008 IS NOT INITIAL 防呆:FOR ALL ENTRIES 空表會忽略 werks/vtweg 條件、撈出全部 →
*   custmap(ZTCX0008) 查無此帳本廠群時跳過 SELECT(供需留 0),避免誤撈全廠資料。
    IF p_moq_flag = 'X' AND lt_ztcx0008 IS NOT INITIAL.
    SELECT * FROM ztcx0001
      FOR ALL ENTRIES IN @lt_ztcx0008
      WHERE vtweg = @lt_ztcx0008-vtweg
        AND werks = @lt_ztcx0008-werks
        AND zportalno IN @lr_iq
        AND idnrk = @lg_step1-idnrk
        "AND qq_status IS INITIAL
        AND qq IS INITIAL
        AND erdat BETWEEN @lv_from AND @sy-datum
        AND loekz IS INITIAL
        AND qq_seq IS NOT INITIAL "有計算過報QQ單數量
        AND vbeln IS INITIAL AND posnr IS INITIAL AND qq_status NE 'B' "已轉正的詢單不計算入7天內需求
    APPENDING TABLE @lt_7day_comp.

    SORT lt_7day_comp BY erdat ertim.

* #2 lt_7day_moq 用途：撈本子件 7 天內「已確認(qq_status A/D)且還有 MOQ 結餘(moq_remain>0)」的列,
*   取其中最早一筆的時間戳 → lv_datetime1。lv_datetime1 當「時間下限」過濾 #1 lt_7day_comp 要顯示哪些 7 天詢單列
*   (早於此時間的其他詢單列不長進 ALV)。★只用到時間戳,不用 moq_remain 值;'L' 淨額決策用不到(僅影響顯示)。
* V026 Changed by JosephLo 20260612 — 輕量化:只撈 4 個時間欄(原 SELECT * 取全欄)→ INTO CORRESPONDING FIELDS。
*   (FOR ALL ENTRIES 不能配非主鍵 ORDER BY 取最早,故保留 ABAP SORT+INDEX 1;結果列數通常少,SORT 可忽略。)
    SELECT erdat, ertim, chdat, chtim FROM ztcx0001
      FOR ALL ENTRIES IN @lt_ztcx0008
      WHERE vtweg = @lt_ztcx0008-vtweg
        AND idnrk = @lg_step1-idnrk
        AND werks = @lt_ztcx0008-werks
        AND zportalno IN @lr_iq
        AND ( qq_status = 'A' OR qq_status = 'D' ) "A- 生管已確認
        AND erdat BETWEEN @lv_from AND @sy-datum
        AND moq_remain > 0 "MOQ結餘=0的不考慮,當成新的計算(此欄只當條件,不放 SELECT 清單)
        AND loekz IS INITIAL
    INTO CORRESPONDING FIELDS OF TABLE @lt_7day_moq.
    SORT lt_7day_moq BY erdat ertim.
    READ TABLE lt_7day_moq INTO ls_7day_moq INDEX 1.
    IF sy-subrc = 0.
      IF ls_7day_moq-chdat IS NOT INITIAL.
        lv_datetime1 = ls_7day_moq-chdat && ls_7day_moq-chtim.
      ELSE.
        lv_datetime1 = ls_7day_moq-erdat && ls_7day_moq-ertim.
      ENDIF.
    ENDIF.
    ENDIF. "p_moq_flag='X'(方案A gate)
* V026 Added by JosephLo 20260609 *
* §8 淨額重算(僅 gv_moq_basis='L'):算本群組(同子件)的供給與需求加總。
* V027 20260613 — 本批合併:同次上傳同子件視為「一筆」,不再逐列累加(cum)→ 改整批合計(lv_batch_req/lv_batch_moq)。
*   供給 lv_supmoq_sum = Σ7天已報MOQ(別批),條件:已產生QQ(qq非空)/未轉XQ(zxqno空)/未軟刪/排除本批。
*     ★V027 以 QQ 去重——一個 QQ 只算「一個」ZMOQ:本批每列都記同一ZMOQ是 robust(刪一列不失),實際只買一批,加總須去重否則同批被重複計。
*     ZXQNO 排除=去重命門(轉XQ後該供給已進 Liability/ZTCX0026,不可重複加)。lv_last_qq 取時間最新者,不報時沿用。
*   需求 lv_reqdb_sum = Σ7天「其他詢單」需求(moq_confirm,各列加總),條件:排除轉SO(vbeln/posnr)/轉正(qq_status=B)/軟刪/轉XQ/本批/★未確認草稿(qq_seq空,V029 20260614加回)。
*     ★排除本批 ≠ 總需求不含本批！本批需求另由 lv_batch_req(Pass1 一次 Σ全本批合格列)算,不再逐列累加。
*       總需求 lv_req_all = lv_reqdb_sum(其他詢單) + lv_batch_req(本批合併);所有本批列共用同一合併數 → 同一淨額判斷 → 要報就每列都報(共用 QQ)。
*     不篩 qq IS INITIAL(qq 不當閘門)、不做 datetime 過濾(滾動模型產物);但 qq_seq 非空(=已確認)為閘門 → 草稿不算,與供給「qq 非空=已確認」同屬「已確認」population,守恆。
*   lr_iq 為 E/EQ 排除式 range → zportalno IN lr_iq 即排除本批詢單(防重入,比照現行 lt_7day_comp)。
*   僅在 p_moq_flag='X'(真正重算 MOQ)時計算;'' 的顯示呼叫不需要,省兩支 SELECT。
*   20260612 JosephLo + lt_ztcx0008 IS NOT INITIAL 防呆:空 custmap 時 FOR ALL ENTRIES 會撈全部,故「DB 供需兩支 SELECT」跳過(別批供需留 0)。
*   V027 20260613 — 防呆只罩「DB SELECT」(inner IF);Pass1 本批合併(lv_batch_req/moq 來源=記憶體群組 lg_step1,非 custmap)
*     移到 inner ENDIF 之後,確保 custmap 空時「本批需求仍被扣」(否則淨額漏扣本批需求 → 少報 MOQ;舊版逐列 cum 一直有扣)。
    IF gv_moq_basis = 'L' AND p_moq_flag = 'X'.
      IF lt_ztcx0008 IS NOT INITIAL.
      SELECT * FROM ztcx0001
        FOR ALL ENTRIES IN @lt_ztcx0008
        WHERE vtweg     = @lt_ztcx0008-vtweg
          AND werks     = @lt_ztcx0008-werks
          AND zportalno IN @lr_iq
          AND idnrk     = @lg_step1-idnrk
          AND erdat BETWEEN @lv_from AND @sy-datum
          AND moq_qty   > 0
          AND qq        IS NOT INITIAL
          AND zxqno     IS INITIAL
          AND loekz     IS INITIAL
        INTO TABLE @DATA(lt_supmoq).
* V027 fix(b) Added by JosephLo 20260614 — 已轉XQ的QQ「整批」排除供給(供給做 QQ 級排除;解 §7.3 供給重複計)。
*   背景:V027 同 QQ 報MOQ鋪多列;ZTGCX0019 轉XQ只標其中一列 zxqno → 同批其餘列 zxqno 仍空,
*     會被上方 lt_supmoq(zxqno IS INITIAL)撈到;但該批已進 Liability(z_end_balance)→ 同批被算兩次 → 供給虛高少報。
*   解法:撈「同子件/帳本廠群、任一列 zxqno<>''」的 QQ(=整批已轉XQ),下方加總/取 lv_last_qq 時整個 QQ 跳過。
*   ★只排「供給」不碰「需求」:供給=整批一個 ZMOQ(QQ 級);需求=逐張詢單(per-row,B/C 未轉SO 的開放需求要留),兩者不對稱。
* ★★key=werks-scoped(FOR ALL ENTRIES IN lt_ztcx0008 → vtweg+werks+idnrk)——【刻意與 ZTGCX0019 不同,reviewer 2】:
*     ZTGCX0019 的去重/防重複轉用 (vtweg,qq,idnrk)「不綁 werks」;這裡綁帳本廠群是【效能考量】
*       (werks 是 ZTCX0001 主鍵首欄,FOR ALL ENTRIES 帶 werks 才走得到 index;拿掉 werks 會掃描)。
*     ☆前提假設:同一 QQ+同子件「不跨廠/跨帳本」(都落在同一帳本廠群 lt_ztcx0008 內)→ 成立則此版正確且較快。
*     ⚠若日後 QQ+子件「可能跨帳本」(某帳本已轉XQ、但另一帳本的同QQ兄弟列在此撈不到 → 會漏排、繼續算供給),
*       則需鏡射 0019:拿掉 werks、改 FOR ALL ENTRIES IN lt_supmoq + WHERE vtweg/idnrk/qq(詳見分析 doc §7.5 reviewer 2)。
*   (0019 重複轉出另有 lt_ztcx0001 防呆,與此無關。)
      SELECT DISTINCT qq FROM ztcx0001
        FOR ALL ENTRIES IN @lt_ztcx0008
        WHERE vtweg = @lt_ztcx0008-vtweg
          AND werks = @lt_ztcx0008-werks
          AND idnrk = @lg_step1-idnrk
          AND qq    IS NOT INITIAL
          AND zxqno IS NOT INITIAL
        INTO TABLE @DATA(lt_xferred_qq).
*   lv_last_qq:取「時間最新且『仍算供給(未轉XQ)』」的 QQ(reviewer 1)。
*     原本直接取 lt_supmoq 最後一筆,會帶到已轉XQ的QQ(其 zxqno=''的兄弟列仍在 lt_supmoq);
*     不報列會把 p_last_qq 寫回 qq(calc_moq_net),導致新列沿用到已轉XQ的QQ → 故先跳過已轉QQ。
      SORT lt_supmoq BY erdat ertim.
      LOOP AT lt_supmoq INTO DATA(ls_supmoq).
        READ TABLE lt_xferred_qq WITH KEY qq = ls_supmoq-qq TRANSPORTING NO FIELDS.
        IF sy-subrc = 0.
          CONTINUE.                          "已轉XQ的QQ不當 lv_last_qq
        ENDIF.
        lv_last_qq = ls_supmoq-qq.
      ENDLOOP.
* V027 Changed by JosephLo 20260613 — 供給以 QQ 去重:一個 QQ 只算「一個」ZMOQ。
*   同 QQ 各列 moq_qty 相同(同批同ZMOQ;舊資料一個QQ僅一列 moq_qty>0),DELETE ADJACENT DUPLICATES 留一筆即該批 ZMOQ。
*   (lt_supmoq 此後不再使用,就地去重即可,免複製。)
      SORT lt_supmoq BY qq.
      DELETE ADJACENT DUPLICATES FROM lt_supmoq COMPARING qq.
      LOOP AT lt_supmoq INTO ls_supmoq.
*       V027 fix(b):該 QQ 已轉XQ(任一列 zxqno<>'')→ 整批不算供給(已在 Liability,避免重複計)。
        READ TABLE lt_xferred_qq WITH KEY qq = ls_supmoq-qq TRANSPORTING NO FIELDS.
        IF sy-subrc = 0.
          CONTINUE.
        ENDIF.
        ADD ls_supmoq-moq_qty TO lv_supmoq_sum.
      ENDLOOP.

      SELECT * FROM ztcx0001
        FOR ALL ENTRIES IN @lt_ztcx0008
        WHERE vtweg     = @lt_ztcx0008-vtweg
          AND werks     = @lt_ztcx0008-werks
          AND zportalno IN @lr_iq
          AND idnrk     = @lg_step1-idnrk
          AND erdat BETWEEN @lv_from AND @sy-datum
* V026 Changed 20260612 / ★V029 Added by JosephLo 20260614 — qq_seq 閘門「加回來」:未確認草稿不計入別批需求。
*   20260614 使用者(業務)親自確認:**僅暫存、未按「產生QQ」的列(qq_seq 空)= 草稿,不應計入別批 7 天需求**。
*     (2026-06-12 曾以「連草稿也算」移除 qq_seq 閘門、舉例 JLOIQ202606111114 漏 84.350;但那是 JLO 驗算時的判斷、非業務需求,今反轉。)
*   ★回到舊邏輯一致:舊 calc_7day_qq 的 lt_7day_comp、主畫面顯示 lt_7day_comp 本來就帶 qq_seq IS NOT INITIAL;
*     當初只有 V026 新 lt_reqdb 拿掉造成不一致,現加回 → 三處一致(只算「已確認(qq_seq 非空)」的別批需求)。
*   排除條件:轉SO(vbeln/posnr)、轉正(qq_status='B')、軟刪(loekz)、★轉XQ(zxqno)、★未確認草稿(qq_seq 空)。
*   ☆只加在「別批 lt_reqdb」;本批 lv_batch_req 不加(本批=當下要看的數據,其 qq_seq 本來也是空)。
*   供給 lt_supmoq 不動:本就 qq IS NOT INITIAL(=已確認)→ 草稿(報MOQ列 qq 空)本就進不了供給,免再加 qq_seq。
          AND vbeln     IS INITIAL
          AND posnr     IS INITIAL
          AND qq_status NE 'B'
          AND zxqno     IS INITIAL
          AND loekz     IS INITIAL
          AND qq_seq    IS NOT INITIAL "★V029 20260614:未確認草稿(qq_seq空)不計入別批需求(回到舊邏輯,業務確認)
        INTO TABLE @DATA(lt_reqdb).
      LOOP AT lt_reqdb INTO DATA(ls_reqdb).
        ADD ls_reqdb-moq_confirm TO lv_reqdb_sum.
      ENDLOOP.
      ENDIF. "lt_ztcx0008 非空:DB 別批供需 SELECT 到此結束(以下 Pass1 本批合併不需 custmap,custmap 空時照跑)

* V027 Changed by JosephLo 20260613 — Pass1 本批合併:同次上傳同子件視為一筆,一次算完整批需求/供給(取代逐列 cum)。
*   需求 lv_batch_req = Σ本批「全部」合格列需求(不分 qq_seq);此後 per-row 各列共用此合併數判斷淨額 → 要報就每列都報。
*     ★需求取值比照 per-row:p_upd 空(RECALC)用 menge,否則用上傳的 moq_confirm;p_upd 模式只算使用者自己上傳(gt_report)列。
*     排除轉SO(vbeln/posnr)/轉正(qq_status=B)/軟刪(loekz)/轉XQ(zxqno)——同上方 DB 需求條件。
*   供給 lv_batch_moq = 本批「已confirm(qq非空)」列 moq_qty,以 QQ 去重(lt_batch_qq)。
*     新列(qq_seq 空、moq_qty 尚未決定)不計——其報MOQ是本次輸出,不回授自身;全新上傳此值=0。
*   (取代舊「種子」:舊需先種 qq_seq 非空列入 cum,再 per-row 逐列 ADD;本批合併後一次算完,語意更直接。)
      LOOP AT GROUP lg_step1 INTO DATA(ls_seed).
        "p_upd 模式:只算使用者自己上傳(gt_report)的列,比照 per-row 過濾
        IF p_upd IS NOT INITIAL.
          READ TABLE gt_report WITH KEY vtweg = ls_seed-vtweg zseq = ls_seed-zseq
                                        werks = ls_seed-werks idnrk = ls_seed-idnrk
                                        zportalno = ls_seed-zportalno TRANSPORTING NO FIELDS.
          IF sy-subrc NE 0.
            CONTINUE.
          ENDIF.
        ENDIF.
        "本列需求:p_upd 空→menge(RECALC 與 per-row 一致),否則→上傳 moq_confirm
        IF p_upd IS INITIAL.
          lv_seed_req = ls_seed-menge.
        ELSE.
          lv_seed_req = ls_seed-moq_confirm.
        ENDIF.
        "需求合併(排除轉SO/轉正/軟刪/轉XQ)
        IF ls_seed-vbeln IS INITIAL AND ls_seed-posnr IS INITIAL
           AND ls_seed-qq_status NE 'B' AND ls_seed-zxqno IS INITIAL AND ls_seed-loekz IS INITIAL.
          ADD lv_seed_req TO lv_batch_req.
        ENDIF.
        "供給合併(本批已confirm列,以QQ去重:一個QQ算一個ZMOQ)
        IF ls_seed-moq_qty > 0 AND ls_seed-qq IS NOT INITIAL
           AND ls_seed-zxqno IS INITIAL AND ls_seed-loekz IS INITIAL.
          READ TABLE lt_batch_qq TRANSPORTING NO FIELDS WITH KEY table_line = ls_seed-qq.
          IF sy-subrc <> 0.
            INSERT ls_seed-qq INTO TABLE lt_batch_qq.
            ADD ls_seed-moq_qty TO lv_batch_moq.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDIF.
* V026 End off *

    IF p_moq_flag  = 'X'.
      LOOP AT lt_7day_comp INTO DATA(ls_7day_comp).
        IF lv_datetime1 IS NOT INITIAL.
          IF ls_7day_comp-chdat IS NOT INITIAL.
            lv_datetime2 = ls_7day_comp-chdat && ls_7day_comp-chtim.
          ELSE.
            lv_datetime2 = ls_7day_comp-erdat && ls_7day_comp-ertim.
          ENDIF.
          IF lv_datetime2 < lv_datetime1.
            CONTINUE.
          ENDIF.
        ENDIF.
        MOVE-CORRESPONDING ls_7day_comp TO ls_data.
        APPEND ls_data TO gt_data.CLEAR ls_data.
        ADD ls_7day_comp-moq_confirm TO lv_tot_req.
      ENDLOOP.


      "7天內總需求
      LOOP AT GROUP lg_step1 INTO ls_data.
        ADD ls_data-moq_confirm TO lv_tot_req.
        APPEND ls_data TO lt_this_moq.
      ENDLOOP.
    ENDIF.
    LOOP AT GROUP lg_step1 INTO ls_data.


      IF p_moq_flag  = 'X' AND ls_data-qq_seq IS INITIAL.
        CLEAR: ls_data-moq_qty,ls_data-moq_7day_req,ls_data-qq,ls_data-moq_remain,ls_data-icon,ls_data-qq_status.
        "需要報 MOQ:理論庫存 - 7 天內總需求, if 不足，需下單,if < MOQ, 取ZTMARC.ZMOQ
        "不是自己本身的IQ單不再重新計算MOQ相關數量(兩基準共用,先擋外來IQ;V026 由原下方上提)
        IF p_upd IS NOT INITIAL.
          READ TABLE gt_report WITH KEY vtweg = ls_data-vtweg zseq = ls_data-zseq
                                        werks = ls_data-werks idnrk = ls_data-idnrk
                                        zportalno = ls_data-zportalno TRANSPORTING NO FIELDS.
          IF sy-subrc NE 0.
            CONTINUE.
          ENDIF.
        ENDIF.
* V026 Changed by JosephLo 20260612 — ★預設「確認需求量 = menge」上提到「算淨額/報MOQ 之前」(reviewer 指出順序問題)。
*   原本此覆寫排在 calc_moq_net/calc_7day_qq 之後 → 計算用的是覆寫前的 moq_confirm、畫面卻顯示覆寫後(menge);
*   p_imp 可編輯欄位下,使用者改 moq_confirm 再 RECALC 會「算的」與「看到的」不一致。上提後計算與顯示同用 menge。
*   (p_upd 的 moq_confirm 來自上傳檔,不覆寫,故僅 p_upd IS INITIAL 才設。)
        IF p_upd IS INITIAL.
          ls_data-moq_confirm = ls_data-menge.
        ENDIF.
* V026 Added by JosephLo 20260609 *
* §8 淨額重算 — 僅 gv_moq_basis='L'(正式機固定 L)。取代滾動讀 moq_remain:
*   剩餘 = z_end_balance + Σ7天報MOQ(供給,QQ去重) − Σ7天需求,剩餘<0 且 |剩餘|<zmoq 報「一個」zmoq(20260610定義更正,非多批;|剩餘|>=zmoq→正常採購報0)。
*   V027:本批合併(lv_batch_req/lv_batch_moq 由 Pass1 一次算完)→ 本批所有列共用同一淨額 → 要報就每列都報(共用 QQ),下批以 QQ 去重算一筆。
*   'S'(理論庫存) 維持 V022 原邏輯不動,當 dev/qa 對比基準線。詳見問題doc §8 與「分析_同次上傳多詢單應合併計算與群組QQ.md」。
        IF gv_moq_basis = 'L'.
          PERFORM calc_moq_net USING    lv_supmoq_sum lv_reqdb_sum lv_batch_req lv_batch_moq lv_last_qq
                               CHANGING ls_data.
        ELSE.
* V022 §5.2(原碼,'S' 走 stock_qty;'L' 已改走上方 calc_moq_net)
*   原 V022 對 z_end_balance/stock_qty 的 IF 分流,'L' 抽走後此處僅剩 stock_qty。
*   原 V013 註解版(z_end_balance - lv_tot_req)歷史見 git/問題doc。
          lv_req_qty = ls_data-stock_qty - lv_tot_req.
          IF lv_req_qty < 0."不足，需下單
            IF abs( lv_req_qty ) < ls_data-zmoq.
              lv_moq_qty = ls_data-moq_qty = round( val = ls_data-zmoq dec = 9 mode = cl_abap_math=>round_up ).
            ENDIF.
          ENDIF.
          ls_data-moq_7day_req = lv_tot_req.
          "計算報MOQ數量和MOQ餘數
          PERFORM calc_7day_qq TABLES lt_this_moq USING ls_data lv_tot_req.
        ENDIF.
* V026 End off *
        "20250516: user反映若確認需求量=0，報MOQ也放為0
        IF ls_data-moq_confirm IS INITIAL.
          ls_data-moq_qty = 0.
        ENDIF.
        "無條件捨去至整數位
        ls_data-moq_qty = round( val = ls_data-moq_qty dec = 0 mode = cl_abap_math=>round_floor ).

      ENDIF.
      " 可做台數 — 共用 FORM calc_out_qty(V026,與 save_data 同一支,避免漏改)。
* V026 Changed by JosephLo 20260611 — 淨額÷單位用量(其他單位−50台);詳見 calc_out_qty。
      PERFORM calc_out_qty CHANGING ls_data.

      "業務金額 = 業務單價 x 數量基準
* V033 Changed by JosephLo 20260626 — 分母 moq_remain → 'L' 淨額(z_net_balance,Liability結餘);'S' 維持 moq_remain。
*   比照 calc_out_qty:'L'(正式機)z_net_balance 為權威淨額;'S'(ZTGCX0001A 預覽)不跑 calc_moq_net→z_net_balance=0,沿用 moq_remain。
*   'L' 數字不變(moq_remain==z_net_balance)。詳見 AAA_業務金額分母改用Z_NET_BALANCE_分析.md。
      IF gv_moq_basis = 'L'.
        ls_data-sales_amt = ls_data-sales_netpr_6 * ls_data-z_net_balance.
      ELSE.
        ls_data-sales_amt = ls_data-sales_netpr_6 * ls_data-moq_remain.
      ENDIF.
* V026 Changed by JosephLo 20260612 — 方案D(效能):預設供應商/WL2規格 改快取(原 per-row SELECT SINGLE 是 N+1)。
*   以 idnrk+werks 為鍵,命中不再撈 ztmara⋈ztmarc。⚠無對應料時 4 欄留空(真實子件必有對應,差異可忽略)。
      "預設供應商 + WL2 規格(快取 by idnrk+werks)
      READ TABLE lt_mara_c INTO ls_mara_c WITH TABLE KEY idnrk = ls_data-idnrk werks = ls_data-werks.
      IF sy-subrc <> 0.
        CLEAR ls_mara_c.
        ls_mara_c-idnrk = ls_data-idnrk.
        ls_mara_c-werks = ls_data-werks.
        SELECT SINGLE
             wl2_thenameoftheerp,
             wl2_erpspecification,
             wl2_englishspecifications, "英文詳細規格
             zdefault_vendor
          FROM ztmara INNER JOIN ztmarc ON ztmara~matnr = ztmarc~matnr
        WHERE ztmara~matnr = @ls_data-idnrk
          AND ztmarc~werks = @ls_data-werks
        INTO CORRESPONDING FIELDS OF @ls_mara_c.
        INSERT ls_mara_c INTO TABLE lt_mara_c.
      ENDIF.
      ls_data-wl2_thenameoftheerp       = ls_mara_c-wl2_thenameoftheerp.
      ls_data-wl2_erpspecification      = ls_mara_c-wl2_erpspecification.
      ls_data-wl2_englishspecifications = ls_mara_c-wl2_englishspecifications.
      ls_data-zdefault_vendor           = ls_mara_c-zdefault_vendor.
      "Vendor name1(快取 by lifnr;zdefault_vendor 已由上方快取填好)
      READ TABLE lt_lfa1_c INTO ls_lfa1_c WITH TABLE KEY lifnr = ls_data-zdefault_vendor.
      IF sy-subrc <> 0.
        CLEAR ls_lfa1_c.
        ls_lfa1_c-lifnr = ls_data-zdefault_vendor.
        SELECT SINGLE name1 FROM lfa1
          WHERE lifnr = @ls_data-zdefault_vendor
        INTO @ls_lfa1_c-name1.
        INSERT ls_lfa1_c INTO TABLE lt_lfa1_c.
      ENDIF.
      ls_data-vendor_name1 = ls_lfa1_c-name1.
      "成品型號
*      SELECT SINGLE
*           skuitem
*        FROM ztmara INNER JOIN ztmarc ON ztmara~matnr = ztmarc~matnr
*      WHERE ztmara~matnr = @ls_data-matnr
*        AND ztmarc~werks = @ls_data-werks
*      INTO CORRESPONDING FIELDS OF @ls_data.
* V024 Changed by JosephLo 20260528 *
* 原 SELECT 已搬到 process_data 主迴圈 Step 2 (PERFORM get_stock_qty) 之前 ——
*   理由：該 SELECT 填的 skuitem 必須在 get_stock_qty 的 REDUCE 跑之前準備好,
*         不然 zind01='C' 分支用 zcpnocn = p_data-skuitem 比對會永遠失敗 → z_end_balance=0。
*   保留原碼為註解作為歷史,完整修法說明見搬上去那段的 V024 Added 區塊。
*      SELECT SINGLE zcn
*        FROM ztsd0020
*      WHERE vtweg = @ls_data-vtweg
*        AND matnr = @ls_data-matnr
*      INTO @ls_data-skuitem.
* V024 End off *
      APPEND ls_data TO gt_data.
      CLEAR ls_data.
    ENDLOOP.

  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form calc_moq_net
*&---------------------------------------------------------------------*
*& V026 Added by JosephLo 20260609 / V027 Changed 20260613(本批合併)
*& §8 淨額重算模型(取代 calc_7day_qq 滾動前期結餘判斷,僅 gv_moq_basis='L' 走本 FORM)。
*&
*& 模型:不讀 MOQ_REMAIN 滾動,改重算淨額決定是否報 MOQ。
*&   剩餘 = z_end_balance(Liability) + 供給 − 需求
*&     供給 = p_supmoq_db(別批:7天已報MOQ,QQ去重,未轉XQ,已產生QQ,排除本批) + p_batch_moq(本批已confirm列,QQ去重)
*&     需求 = p_reqdb(別批:7天詢單需求加總,排除轉SO/轉正/軟刪/本批) + p_batch_req(本批合併需求)
*&   報量規則(20260610 定義更正)：報 MOQ＝「需求未達供應商最小訂購量(ZMOQ)時被迫整批買」。
*&     剩餘<0 且 |剩餘|<ZMOQ → 報「一個」ZMOQ;  剩餘>=0(Liability足) 或 |剩餘|>=ZMOQ(缺口已達最小量→正常採購) → 不報。
*&     ★報量永遠是 0 或剛好一個 ZMOQ,不報多批(舊 ceil 多批模型已作廢)。
*&
*& ★V027 本批合併(同次上傳同子件視為一筆):p_batch_req/p_batch_moq 由 calc_moq_qty 的 Pass1「一次」算完整批,
*&   非逐列累加 → 本批每一列拿到「同一個淨額」→ 要報就「每列都報一個 ZMOQ」(共用 QQ;confirm 時賦同號)。
*&   下批以 QQ 去重(供給 DELETE ADJACENT DUPLICATES BY qq)把同批多列算「一個」ZMOQ → 不重複計。
*&   robust 理由:MOQ 記在多列,Sync SO/轉XQ 過程刪一列仍不失。詳見「分析_同次上傳多詢單應合併計算與群組QQ.md」。
*& MOQ_REMAIN 降級為衍生輸出=本列剩餘,下游 OUT_QTY/業務金額照舊消費。
*& 不報時 moq_qty=0 但沿用最近未轉XQ報MOQ的 QQ(p_last_qq);首次無供給則 p_last_qq 空→qq 留空白。
*&---------------------------------------------------------------------*
FORM calc_moq_net  USING    p_supmoq_db TYPE ztcx0001-moq_7day_req
                            p_reqdb     TYPE ztcx0001-moq_7day_req
                            p_batch_req TYPE ztcx0001-moq_7day_req
                            p_batch_moq TYPE ztcx0001-moq_7day_req
                            p_last_qq   TYPE ztcx0001-qq
                   CHANGING p_data      LIKE LINE OF gt_data.
  DATA:lv_net        TYPE ztcx0001-z_end_balance, "較大型別防溢位
       lv_short      TYPE ztcx0001-z_end_balance, "缺口絕對值 |剩餘|,報量判斷用(預先算避免 IF 內放函式)
       lv_supply_all TYPE ztcx0001-moq_7day_req,
       lv_req_all    TYPE ztcx0001-moq_7day_req.

  READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.

  "V027 本批合併:供需用整批合計(同次上傳同子件視為一筆),本批每列拿到同一淨額,不再逐列累加。
  lv_supply_all = p_supmoq_db + p_batch_moq.   "別批(QQ去重) + 本批已confirm(QQ去重)
  lv_req_all    = p_reqdb     + p_batch_req.    "別批(加總)  + 本批合併需求
  lv_net        = p_data-z_end_balance + lv_supply_all - lv_req_all.

  lv_short = abs( lv_net ).                     "缺口絕對值,供下方報量判斷

  "20260610 JosephLo 報MOQ定義更正：報量永遠 0 或「一個」ZMOQ,不報多批。
  "  報 ZMOQ 四條件全要成立:(1)剩餘<0(有缺口) (2)|剩餘|<ZMOQ(缺口未達最小量→被迫整批買)
  "  (3)ZMOQ>0(無 ZMOQ 無法定批) (4)本列需求>0(確認需求量=0則本列不報;只有「有需求」的本批列才記 ZMOQ)。
  "  |剩餘|>=ZMOQ → 缺口已達/超過最小量,走正常採購,不報(走 ELSE)。
  "  ★V027:本批所有列共用同一 lv_net → 條件成立時每一「有需求」列都報一個 ZMOQ(共用 QQ);供給去重確保下批只算一筆。
  IF lv_net < 0 AND lv_short < p_data-zmoq AND p_data-zmoq > 0 AND p_data-moq_confirm IS NOT INITIAL.
    p_data-moq_qty    = p_data-zmoq.            "報「一個」最小批量(本批每列同值)
    p_data-moq_remain = lv_net + p_data-moq_qty. "= ZMOQ − |剩餘|,多買的 excess
    p_data-qq         = ''.                      "產新 QQ(confirm_get_qq 屆時賦同號)
    p_data-qq_status  = ''.
  ELSE.
    "剩餘>=0(Liability足) 或 |剩餘|>=ZMOQ(正常採購) 或 需求=0 / zmoq=0 → 不報,沿用既有 QQ
    p_data-moq_qty    = 0.
    p_data-moq_remain = lv_net.                  "覆蓋→剩餘額度;缺口>=ZMOQ→負值,下方夾0
    p_data-qq         = p_last_qq.
    p_data-qq_status  = SWITCH #( ls_role-role WHEN 'A' THEN 'A' WHEN 'C' THEN 'D' ).
  ENDIF.

  "夾0:不報且淨額為負時(|剩餘|>=ZMOQ 走正常採購、或 zmoq=0 無法報)避免負的 MOQ結餘/業務金額,與舊版顯示一致。
  "  (報的列 moq_remain=淨額+moq_qty 本就>=0,不受影響;轉XQ 用 moq_qty,不讀此值。)
  IF p_data-moq_remain < 0.
    p_data-moq_remain = 0.
  ENDIF.

* V026 Changed by JosephLo 20260612 — Liability結餘(欄 Z_NET_BALANCE):= 淨額 + 本次報的MOQ,夾0。
*   報MOQ列 = lv_net + zmoq(=報的MOQ數量−不足額,正值);不報列 = lv_net + 0 = 淨額(夾0)。
*   ★與 moq_remain 同義但「分開算、不抄 moq_remain」,供後續觀察兩欄一致性(使用者要求)。
*   故須擺在報量決策(設 moq_qty)之後;可做台數改讀本欄(見 calc_out_qty)。
  p_data-z_net_balance = lv_net + p_data-moq_qty.
  IF p_data-z_net_balance < 0.
    p_data-z_net_balance = 0.
  ENDIF.

  p_data-moq_7day_req = lv_req_all.             "顯示:本批合併需求 + 別批7天需求(本批每列相同)

  "時間戳/燈號(比照 calc_7day_qq)
  IF p_data-erdat IS NOT INITIAL.
    p_data-chdat = sy-datum.
    p_data-chtim = sy-uzeit.
    p_data-chnam = sy-uname.
  ELSE.
    p_data-erdat = sy-datum.
    p_data-ertim = sy-uzeit.
    p_data-ernam = sy-uname.
  ENDIF.
  p_data-icon = icon_green_light.

  "V023 顯示欄:標明本列淨額組成(取代「前期結餘」字樣)
* 20260616 JosephLo 使用者要求:欄位文字改詳細版(Liab→Liability、報MOQ→7天報MOQ、需求→7天總需求)
  p_data-z_basis_used = |淨額 { lv_net } = Liability { p_data-z_end_balance } + 7天報MOQ { lv_supply_all } - 7天總需求 { lv_req_all }|.
* 20260610 JosephLo §9.1 落欄:本列淨額算入的「7天報MOQ供給」(=別批供給 p_supmoq_db(QQ去重) + 本批已confirm供給 p_batch_moq(QQ去重)),供事後追溯/查詢
  p_data-moq_qty_7day = lv_supply_all.
  CLEAR p_data-moq_prior_link.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form calc_out_qty
*&---------------------------------------------------------------------*
*& V026 Added by JosephLo 20260611 — 可做台數計算抽成共用(原 calc_moq_qty 與 save_data 各一份,易漏改)。
*&   'L'(淨額模型,正式機固定):★只算「本次有報MOQ(moq_qty>0)」的列,其餘=0。
*&        可做台數 = Liability結餘(z_net_balance,報MOQ列=淨額+ZMOQ) ÷ 單位用量;非 PC/ST(如 Y 碼) 再 −50 台(★台層級,除完才扣)。
*&   'S'(ZTGCX0001A 預覽對比):維持舊 moq_remain ÷ 單位用量。
*&   共同:<0 夾 0;floor 取整(不做半台);可做台數落 (0,50) 標示安全門檻警示(不歸零)。
*& 20260612 改:分子由 moq_remain 改讀 Liability結餘(z_net_balance),讓報MOQ列「可做台數 × 單位用量 = Liability結餘」、
*&   報表來源一致(使用者要求);不再依賴 moq_remain(改觀察 Liability結餘 vs MOQ結餘 兩欄一致性)。
*&   ★維持「只報MOQ列才顯示可做台數」(20260612 使用者定);非報MOQ列=0。
*&---------------------------------------------------------------------*
FORM calc_out_qty CHANGING p_data LIKE LINE OF gt_data.
  DATA lv_can TYPE p LENGTH 9 DECIMALS 3.

  IF gv_moq_basis = 'L'.
*   可做台數 = Liability結餘(z_net_balance) ÷ 單位用量;非 PC/ST 再 −50 台。
*   ★只算「本次有報MOQ(moq_qty>0)」的列,其餘列=0(20260612 使用者定:維持只報MOQ列顯示可做台數)。
*   分子改讀 Liability結餘(取代 moq_remain)讓報表來源一致;報MOQ列 Liability結餘=淨額+ZMOQ 必為正。
    IF p_data-moq_qty > 0 AND p_data-mnglg <> 0.
      lv_can = p_data-z_net_balance / p_data-mnglg.
      IF p_data-meins NE 'ST' AND p_data-meins NE 'PC'.
        lv_can = lv_can - 50.                         " 其他單位(如 Y 碼/布料):留 50 台安全緩衝
      ENDIF.
      p_data-out_qty = floor( lv_can ).
    ELSE.
      p_data-out_qty = 0.
    ENDIF.
  ELSE.
* V011 Ky 除零 Dump 防呆(原 'S' 基準邏輯)
    IF p_data-mnglg = 0.                             " 分母為0
      p_data-out_qty = p_data-moq_remain.
    ELSEIF p_data-moq_remain = 0.                    " 分子為0
      p_data-out_qty = 0.
    ELSE.                                            " 分母不為0
      p_data-out_qty = p_data-moq_remain / p_data-mnglg.
    ENDIF.
  ENDIF.

  " 若小於等於 0，設為 0
  IF p_data-out_qty <= 0.
    p_data-out_qty = 0.
  ENDIF.

  " 若低於安全門檻 50，標示提示訊息，不要直接歸零
  IF p_data-out_qty < 50 AND p_data-out_qty > 0.
    p_data-zmsg = '可做台數不足安全門檻'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form choose_moq_basis
*&---------------------------------------------------------------------*
*& V022 Added by JosephLo 20260526
*& V022 Changed by JosephLo 20260526 — gate 從 mandt 改為 t-code
*&   (僅 ZTGCX0001A 預覽 t-code 開放彈窗對比)
*&
*& 目的：決定本次 MOQ 計算要用哪個基準，並設定全域旗標 gv_moq_basis
*&   'L' = Liability 餘額 (z_end_balance) — 本案目標的新基準
*&   'S' = 理論庫存 (stock_qty) — V013 改回後維持的舊基準
*&
*& 設定規則：
*&   - sy-tcode = 'ZTGCX0001A' (預覽 t-code,擋 CONFIRM/&DATA_SAVE/DELETE 寫DB按鈕,
*&     只有 RECALC 可觸發本 FORM) →
*&       彈出 Yes/No 對話框讓 user 選 (Yes=Liability、No=理論庫存,預設 Yes)
*&       用意：開發/測試時方便對同一張詢單對比兩種基準算出來的數字;且因
*&       ZTGCX0001A 已擋寫DB按鈕,實驗不會誤寫 DB。
*&   - 其他所有 t-code (含主程式 ZTGCX0001 與正式機) →
*&       固定走 'L' (Liability)，不彈窗
*&
*& 顯示提示：
*&   設定完後狀態列(左下)顯示綠色 S 型訊息提示本次基準
*&
*& 影響的下游 (依 gv_moq_basis 分流取 stock_qty 或 z_end_balance)：
*&   - calc_moq_qty 內 lv_req_qty 計算 (§5.2)
*&   - calc_7day_qq 首次分支 (lt_moq IS INITIAL) 的 moq_remain 計算 (§5.1)
*&
*& 呼叫時機：
*&   每次按 [重新計算報MOQ量](RECALC) 或 [確認產生QQ單號](CONFIRM) 按鈕
*&   都先呼叫一次設定本次基準。在 ZTGCX0001A 中 CONFIRM 被擋,只有 RECALC 會觸發彈窗。
*&---------------------------------------------------------------------*
FORM choose_moq_basis.
  DATA: lv_ans TYPE c,
        lv_msg TYPE string.

* V025 JosephLo 2026/06/01 改讀 gs_mode-pick_basis(僅模擬模式彈窗挑基準;其餘固定 Liability)
  IF gs_mode-pick_basis = 'X'.
    " 預覽/模擬 t-code (擋寫DB按鈕,實驗安全)：彈窗讓 user 選 (Yes 預設,Enter 即可)
    PERFORM pop_up_confirm  USING  '選擇 MOQ 計算基準'
                                    'Yes=Liability 餘額(z_end_balance,新) / No=理論庫存(stock_qty,舊)'
                                    lv_ans.
    " lv_ans='1' (Yes/Enter) → 'L'； '2' (No) → 'S'
    gv_moq_basis = COND #( WHEN lv_ans = '1' THEN 'L' ELSE 'S' ).
  ELSE.
    " 其他 t-code (含主程式 ZTGCX0001 與正式機)：固定走 Liability,不彈窗
    gv_moq_basis = 'L'.
  ENDIF.

  " 狀態列顯示本次基準 (S 型訊息 = 綠色,左下角)
  lv_msg = COND #( WHEN gv_moq_basis = 'L'
                   THEN '本次 MOQ 計算基準: Liability 餘額 (z_end_balance, 新)'
                   ELSE '本次 MOQ 計算基準: 理論庫存 (stock_qty, 舊)' ).
  MESSAGE s001(00) WITH lv_msg.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form hotspot_show_prior_moq
*&---------------------------------------------------------------------*
*& V023 Added by JosephLo 20260527
*&
*& 目的:點 ALV 的 MOQ_PRIOR_LINK hotspot 欄時彈出 popup,顯示同(vtweg, zseq, idnrk)
*&   在過去 7 天內所有未刪除的 ZTCX0001 列(放寬版),方便使用者一眼看出
*&   「本期 MOQ 結餘是怎麼算出來的」,不必另外開 SE16 撈 DB 對照。
*&
*& 撈資料範圍(放寬版):
*&   - 同 vtweg / 同 idnrk / 帳本廠群(由 gt_custmap WHERE vtweg=. zseq=. 撈)
*&   - erdat 在過去 7 天(sy-datum-6 ~ sy-datum,跟 calc_7day_qq 的 lv_from 一致)
*&   - loekz IS INITIAL (未刪除)
*&   - 不限 qq_status / 不限 moq_remain,讓使用者看全貌
*&     (vs calc_7day_qq lt_moq 嚴格條件 = qq_status='A'/'D' + moq_remain>0)
*&
*& 標色:
*&   實際被 calc_7day_qq 取用的列(=「ls_lastmoq」: 符合嚴格 lt_moq 條件且
*&   依 erdat ertim qq_seq 排序後最後一筆)用 'C310'(淡藍/黃)標示整列。
*&
*& 排序: erdat ↗ → ertim ↗ → qq_seq ↗ (時間軸由舊到新)
*&
*& 呼叫時機:
*&   frm_double_click 內 WHEN 'MOQ_PRIOR_LINK' 觸發,僅在 ALV 列的
*&   moq_prior_link 欄位非空(=本列走「有前期結餘」分支)才呼叫。
*&---------------------------------------------------------------------*
FORM hotspot_show_prior_moq USING iv_vtweg     TYPE ztcx0001-vtweg
                                   iv_zseq      TYPE ztcx0001-zseq
                                   iv_idnrk     TYPE ztcx0001-idnrk
                                   iv_zportalno TYPE ztcx0001-zportalno. " 20260612 標題顯示:詢單號
* 註:範圍是「帳本廠群」(vtweg+zseq→可能多廠,見 ZTCX0008),非單一工廠;標題用帳本(zseq)代表整個廠群,不傳 werks。
  TYPES: BEGIN OF ty_show,
           erdat       TYPE ztcx0001-erdat,
           ertim       TYPE ztcx0001-ertim,
           zportalno   TYPE ztcx0001-zportalno,
           qq          TYPE ztcx0001-qq,
           qq_seq      TYPE ztcx0001-qq_seq,
           qq_status   TYPE ztcx0001-qq_status,
           werks       TYPE ztcx0001-werks,
           matnr       TYPE ztcx0001-matnr,
           menge       TYPE ztcx0001-menge,
           moq_confirm TYPE ztcx0001-moq_confirm,
           moq_qty     TYPE ztcx0001-moq_qty,
* V029 20260614 JosephLo 使用者要求:彈窗拿掉 MOQ結餘(moq_remain)、改放 Liability(z_end_balance)。
           z_end_balance TYPE ztcx0001-z_end_balance,  " Liability(取代原 MOQ結餘欄)
           ismoq       TYPE ztcx0001-ismoq,
           zxqno       TYPE ztcx0001-zxqno,           " 轉XQ判定/顯示(轉XQ列不計供給/需求)
           vbeln       TYPE ztcx0001-vbeln,           " 20260612 SO單號(轉SO→不計需求)
           posnr       TYPE ztcx0001-posnr,           " 20260612 SO項目
           info_color  TYPE c LENGTH 4,               " row-level 顏色
         END OF ty_show.

  DATA: lt_show     TYPE STANDARD TABLE OF ty_show,
        lt_fieldcat TYPE lvc_t_fcat,
        ls_fcat     TYPE lvc_s_fcat,
        ls_layout   TYPE lvc_s_layo,
        lt_zplwrk   TYPE TABLE OF ztcx0008.

  " (a) 取該帳本對應的廠群 (同 calc_7day_qq 的 lt_ztcx0008 邏輯)
  LOOP AT gt_custmap INTO DATA(ls_custmap) WHERE vtweg = iv_vtweg AND zseq = iv_zseq.
    APPEND ls_custmap TO lt_zplwrk.
  ENDLOOP.
  IF lt_zplwrk IS INITIAL.
    MESSAGE s001(00) WITH '查無對應廠別 (ZTCX0008)'.
    RETURN.
  ENDIF.

  " (b) 撈 7 天內同子件未刪除全部列(放寬版,不限 qq_status / moq_remain)
  DATA(lv_from) = sy-datum - 6.
  SELECT zportalno, qq, qq_seq, qq_status, werks, erdat, ertim,
         matnr, menge, moq_confirm, moq_qty, z_end_balance, ismoq, zxqno, vbeln, posnr
    FROM ztcx0001
     FOR ALL ENTRIES IN @lt_zplwrk
   WHERE vtweg = @iv_vtweg
     AND werks = @lt_zplwrk-werks
     AND idnrk = @iv_idnrk
     AND erdat BETWEEN @lv_from AND @sy-datum
     AND loekz IS INITIAL
    INTO CORRESPONDING FIELDS OF TABLE @lt_show.

  "唯一能跑到 lt_show IS INITIAL 的情境：RECALC 後到使用者點 hotspot 之間，DB 那筆被刪除/標 loekz
  IF lt_show IS INITIAL.
    MESSAGE s001(00) WITH '查無前期 MOQ 記錄'.
    RETURN.
  ENDIF.

  " (c) 主排序(依時間軸,讓使用者由舊到新看演進)
  SORT lt_show BY erdat ertim qq_seq.

  " (d) 標色: ★只標黃 = 「實際計入 7天報MOQ供給」= moq_qty>0 AND qq非空 AND zxqno空 AND【該QQ整批未轉XQ】。
  "     對齊 fix(b) 供給閘門:供給以 QQ 為單位,同一個 QQ 只要有任一列已轉XQ(zxqno<>''),整批已進 Liability、
  "       不再計入供給 → 其 zxqno='' 的兄弟列也不該標黃(否則看起來計入供給、實際沒有 → 誤導;使用者 2026-06-14 反映)。
  "     ★V027:供給以 QQ 去重 → 同一個 QQ「未轉XQ」的多列都標黃(忠實顯示供給池),「同 QQ 算一個」由 top-of-page 文字說明。
  "     20260612 使用者定:其餘狀態(暫存未產QQ/轉正不計需求/轉XQ都不計)改由 top-of-page 文字說明,不再多色標示。
  " (d.1) 先收「整批已轉XQ的QQ」= 本明細內任一列 zxqno<>'' 的 QQ(lt_show 已含轉XQ列,免再撈DB)
  DATA lt_xq_qq TYPE SORTED TABLE OF ztcx0001-qq WITH NON-UNIQUE KEY table_line.
  LOOP AT lt_show INTO DATA(ls_xq) WHERE zxqno IS NOT INITIAL AND qq IS NOT INITIAL.
    INSERT ls_xq-qq INTO TABLE lt_xq_qq.
  ENDLOOP.
  " (d.2) 標黃:計入供給的列(報MOQ>0/有QQ/本列未轉XQ);但整批已轉XQ的QQ跳過(對齊 fix(b))
  LOOP AT lt_show ASSIGNING FIELD-SYMBOL(<fs_show>)
       WHERE moq_qty > 0 AND qq IS NOT INITIAL AND zxqno IS INITIAL.
    READ TABLE lt_xq_qq TRANSPORTING NO FIELDS WITH KEY table_line = <fs_show>-qq.
    IF sy-subrc = 0.
      CONTINUE.            "該QQ整批已轉XQ → 不計入供給 → 不標黃
    ENDIF.
    <fs_show>-info_color = 'C310'.
  ENDLOOP.

  " (e) fieldcat — LVC 版 (跟同檔 show_excluded_popup / build_excl_fcat 同 pattern)
  DEFINE _fc.
    CLEAR ls_fcat.
    ls_fcat-fieldname = &1.
    ls_fcat-coltext   = &2.
    ls_fcat-scrtext_l = &2.
    ls_fcat-scrtext_m = &2.
    ls_fcat-scrtext_s = &2.
    ls_fcat-outputlen = &3.
    APPEND ls_fcat TO lt_fieldcat.
  END-OF-DEFINITION.
  _fc: 'ERDAT'       '建立日期'  10,
       'ERTIM'       '建立時間'   8,
       'ZPORTALNO'   'RR詢單號'  20,
       'QQ'          'QQ單號'    12,
       'QQ_SEQ'      'QQ序號'     5,
       'QQ_STATUS'   '狀態'       4,
       'WERKS'       '廠'         4,
       'MATNR'       '物料'      18,
       'MENGE'       '需求數量'    13,
       'MOQ_CONFIRM' '確認子階需求' 13,
       'MOQ_QTY'     '報MOQ'     13,
       'Z_END_BALANCE' 'Liability' 15,
       'ISMOQ'       '不報'       5,
       'ZXQNO'       'XQ單號'    12,
       'VBELN'       'SO單號'    10,
       'POSNR'       'SO項目'     6.
  " 20260612 加 XQ單號(zxqno)/SO單號(vbeln)/SO項目(posnr):讓使用者直接看出哪些列因轉XQ/轉SO而不計(對照上方說明)。

  " (f) layout LVC — info_fname 指向 ty_show 的 info_color 欄,達到 row-level 染色
  "     ※ LVC 結構欄名是 info_fname (SLIS 才是 info_fieldname);先前用 SLIS 名稱
  "       在 LVC 結構上不存在(編譯通過但 runtime 行為不對)。
  CLEAR ls_layout.
  ls_layout-zebra      = 'X'.
  ls_layout-cwidth_opt = 'X'.    " 欄寬自動最佳化 (跟 show_excluded_popup 一致)
  ls_layout-info_fname = 'INFO_COLOR'.

  " (g) popup ALV — 改用 REUSE_ALV_GRID_DISPLAY_LVC + i_screen_start_* 配 popup 螢幕參數
  "     ※ 原想用 REUSE_ALV_POPUP_TO_SELECT 但該 FM 不支援 IS_LAYOUT 參數
  "       (call 會 dump: CALL_FUNCTION_PARM_UNKNOWN / "IS_LAYOUT" is unknown)。
  "       為了 row-level 染色必須改用 _LVC 版,跟同檔 show_excluded_popup 同 pattern。
  " (g.1) 標題先存到 CHAR 變數,不能直接把 string template (TYPE STRING) 傳給
  "       I_GRID_TITLE (TYPE LVC_TITLE = CHAR70) — FM 參數型別檢查嚴格,
  "       直接傳 STRING 會 dump (CALL_FUNCTION_CONFLICT_TYPE)。
  DATA lv_title TYPE lvc_title.
  lv_title = |7天列入資料明細: 詢單 { iv_zportalno } / 子件 { iv_idnrk } / 通路 { iv_vtweg } / 帳本 { iv_zseq }|.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
      i_callback_program       = sy-repid
* 20260612 JosephLo 表格上方放供需計算說明(取代多色標示);20260614 加「轉XQ整批不標黃」+V029「有QQ無序號=草稿」說明後共 8 行,高度提到 13。
      i_callback_html_top_of_page = 'HOTSPOT_TOP_OF_PAGE'
      i_html_height_top        = 13
      i_bypassing_buffer       = 'X'
      i_grid_title             = lv_title
      is_layout_lvc            = ls_layout
      it_fieldcat_lvc          = lt_fieldcat
      i_save                   = 'A'
      i_screen_start_column    = 5
      i_screen_start_line      = 3
      i_screen_end_column      = 200
      i_screen_end_line        = 22
    TABLES
      t_outtab              = lt_show
    EXCEPTIONS
      program_error         = 1
      OTHERS                = 2.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form hotspot_top_of_page
*&---------------------------------------------------------------------*
*& V026 Added by JosephLo 20260612 — 7天報MOQ明細彈窗「表格上方說明」(top-of-page)。
*&   放 供給/需求/淨額公式 + 黃色意義 + 即時撈取差異提醒;取代原暫存橘/轉XQ灰多色標示(使用者定)。
*&   由 REUSE_ALV_GRID_DISPLAY_LVC 的 i_callback_html_top_of_page 回呼(簽章固定:top TYPE REF TO cl_dd_document)。
*& V027 Changed by JosephLo 20260613 — 配合本批合併模型修正說明:
*&   ★供給改「以 QQ 去重」——同一個 QQ 的多列雖都標黃,只算「一個」ZMOQ(本批每列都記 MOQ 是 robust,實際只買一批)。
*&   ★需求改「本批(同次上傳同子件)合併計」+ 其他詢單各列加總。避免使用者把同 QQ 多列的報MOQ重複加而誤判。
*& V027 Changed by JosephLo 20260614 — 黃色對齊 fix(b):同一QQ只要有任一列已轉XQ→整批不計供給→該QQ各列(含未轉XQ兄弟列)都不標黃。
*&   (原只逐列排 zxqno,該QQ未轉XQ的兄弟列仍標黃,看起來計入供給實際沒有 → 使用者反映誤導。)
*& V029 Changed by JosephLo 20260614 — 加「有QQ單號、無QQ序號=草稿」現象說明(使用者反映易誤讀):
*&   recalc 對不報列做 p_data-qq=p_last_qq(沿用/繼承 QQ單號顯示),但 qq_seq 只有按「產生QQ」走 get_qq_seq 才配;
*&   故 qq_seq 才是「已確認」依據;有QQ單號卻無qq_seq=暫存草稿,V029 不計入別批需求。qq_status=D/A 是 recalc 蓋的角色別,非確認依據。
*&---------------------------------------------------------------------*
FORM hotspot_top_of_page USING top TYPE REF TO cl_dd_document.
  top->add_text( text = '【供給 7天報MOQ】=黃列:報MOQ>0、有QQ、且「整批未轉XQ」。★同一QQ多列只算「一個」ZMOQ(去重),勿重複加。' ).
  top->new_line( ).
  top->add_text( text = '  ★同一QQ只要有任一列已轉XQ → 整批已進 Liability、不計供給 → 該QQ各列(含未轉XQ兄弟列)都不標黃。' ).
  top->new_line( ).
  top->add_text( text = '【需求 7天總需求】本批(同次上傳同子件)合併計 + 別批各列加總;★別批排除 轉SO/轉正(狀態B)/轉XQ/軟刪/未確認草稿(qq_seq空)。' ).
  top->new_line( ).
  top->add_text( text = '  ★「有QQ單號、無QQ序號」=暫存草稿:recalc 會讓「不報列」沿用(繼承)一個 QQ單號顯示,但只有按「產生QQ」才會配 QQ序號(qq_seq)。' ).
  top->new_line( ).
  top->add_text( text = '    故判定『是否已確認』看「QQ序號」,不是「QQ單號」;有QQ單號卻無QQ序號=只暫存未產生QQ → 草稿,不計入別批需求。(狀態D/A是recalc蓋的角色別,非確認依據)' ).
  top->new_line( ).
  top->add_text( text = '【淨額】= Liability + 供給 − 需求。淨額<0 且 |淨額|<ZMOQ → 報一個 ZMOQ(本批每列都報、共用同一 QQ)。' ).
  top->new_line( ).
  top->add_text( text = '黃底=計入供給;同QQ多列雖都黃只算一個ZMOQ。未標黃=不計(暫存未產QQ/轉正/該QQ整批已轉XQ 等)。' ).
  top->new_line( ).
  top->add_text( text = '※ 本明細為即時撈取(放寬版),數字可能與主畫面略有差異。' ).
ENDFORM.

*&---------------------------------------------------------------------*
*& Form recalc_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM recalc_data .
  DATA:lt_data LIKE gt_data.
  DATA:lv_index TYPE  sy-tabix.
  lt_data = gt_data.
  LOOP AT lt_data INTO DATA(ls_data)." WHERE sel IS NOT INITIAL.
    lv_index = sy-tabix.
    IF gt_report IS NOT INITIAL.
      READ TABLE gt_report WITH KEY zportalno = ls_data-zportalno TRANSPORTING NO FIELDS.
      IF sy-subrc NE 0.
        DELETE lt_data INDEX lv_index.
      ENDIF.
    ENDIF.
  ENDLOOP.
  gt_data = lt_data.
  PERFORM calc_moq_qty TABLES lt_data USING 'X'.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_sales_price
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LS_DATA
*&---------------------------------------------------------------------*
FORM get_sales_price  USING    p_data LIKE LINE OF gt_data.
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
  IF p_data-sales_netpr_6 IS INITIAL.
    i_vtweg = p_data-vtweg.
    i_zpno = p_data-idnrk.
    i_zpnocode = 'M'.
    i_meins = p_data-meins.
    i_prsdt = sy-datum.
    i_zpcur = p_data-waers.
    i_zpup = 100 * p_data-netpr.
    i_zpup_per = 100.
    i_zpcnyup = 100 * p_data-netpr_cny.
    i_zpcny_per = 100.
    i_zptwdup = p_data-netpr_twd.
    i_zptwd_per = 100.

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
*       I_ZTSD0107  =
      IMPORTING
*       E_ZCALCUR   =
*       E_ZFORMULATYPE       =
        e_zup_cur   = e_zup_cur
        e_zup       = e_zup
        e_zup_per   = e_zup_per
*       E_ZUPFORMULA         =
*       E_ZTSD0107  =
      .
    TRY.
        "業務幣別
        p_data-sales_waers = e_zup_cur.


        "業務單價
        p_data-sales_netpr_6 = e_zup / e_zup_per.

        "業務金額 = 業務單價 x 數量基準
* V033 Changed by JosephLo 20260626 — 分母 moq_remain → 'L' 淨額(z_net_balance);'S' 維持 moq_remain(比照 calc_out_qty / calc_moq_qty 同款切換)。
        IF gv_moq_basis = 'L'.
          p_data-sales_amt = p_data-sales_netpr_6 * p_data-z_net_balance.
        ELSE.
          p_data-sales_amt = p_data-sales_netpr_6 * p_data-moq_remain.
        ENDIF.
      CATCH  cx_sy_conversion_overflow INTO DATA(lr_cx).

    ENDTRY.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form recalc_sales_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM recalc_sales_data .
  "業務幣別	業務單價
  LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>) WHERE sel IS NOT INITIAL.
    "淨價、幣別 > 同訂單取消報庫存時的處理邏輯
    "CLEAR:<Ls_data>-netpr,<ls_data>-waers,<ls_data>-netpr_cny,<ls_data>-netpr_twd.
    PERFORM get_default_netprice USING <ls_data>.
    "CLEAR:<ls_data>-sales_netpr_6.
    PERFORM get_sales_price USING <ls_data>.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form get_qq_seq
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_qq_seq .
  DATA:lv_qq_seq TYPE numc05."ztcx0001-qq_seq."QQ單序號

  "若此批有計算過QQ單，QQ單序號+1
  LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>) WHERE sel IS NOT INITIAL AND qq_seq IS INITIAL.

  ENDLOOP.
  IF sy-subrc = 0.
    DO.
      CALL FUNCTION 'NUMBER_RANGE_ENQUEUE'
        EXPORTING
          object           = 'ZCX_QQ_SEQ'
        EXCEPTIONS
          foreign_lock     = 1
          object_not_found = 2
          system_failure   = 3
          OTHERS           = 4.
      IF sy-subrc <> 0.
        DO 1000 TIMES. ENDDO.
      ELSE.
        EXIT.
      ENDIF.
    ENDDO.

    DO.
      CALL FUNCTION 'NUMBER_GET_NEXT'
        EXPORTING
          nr_range_nr             = '00'
          object                  = 'ZCX_QQ_SEQ'
        IMPORTING
          number                  = lv_qq_seq
        EXCEPTIONS
          interval_not_found      = 1
          number_range_not_intern = 2
          object_not_found        = 3
          quantity_is_0           = 4
          quantity_is_not_1       = 5
          interval_overflow       = 6
          buffer_overflow         = 7
          OTHERS                  = 8.
      IF sy-subrc <> 0.
* 20260622 V032 JosephLo 取QQ序號失敗→同 confirm_get_qq:改 MESSAGE-I + LEAVE TO TRANSACTION 結束本交易,自動釋放所有鎖。
* MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        MESSAGE '取QQ序號失敗(號碼範圍 ZCX_QQ_SEQ 異常),系統將重啟本交易以釋放鎖' TYPE 'I'.
        LEAVE TO TRANSACTION sy-tcode.
      ELSE.
        EXIT.
      ENDIF.
    ENDDO.
    CALL FUNCTION 'NUMBER_RANGE_DEQUEUE'
      EXPORTING
        object           = 'ZCX_QQ_SEQ'
      EXCEPTIONS
        object_not_found = 1
        OTHERS           = 2.
  ENDIF.
  LOOP AT gt_data ASSIGNING <ls_data> WHERE sel IS NOT INITIAL AND qq_seq IS INITIAL.
    <ls_data>-qq_seq = lv_qq_seq.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*&  Form  GET_INFO_RECORD
*&  目的 : 依 料/廠/供應商 取標準採購 Info Record 價格（EINA/EINE）
*&         僅允許 外購(F) 且 非分包(≠ '30') 的料件取 PIR
*&---------------------------------------------------------------------*
FORM get_info_record
  CHANGING p_data LIKE LINE OF gt_data.

  "---------------- 守門條件：只允許 F 且 SOBSL≠'30' ----------------
  IF p_data-beskz <> 'F' OR p_data-sobsl = '30'.
    RETURN.
  ENDIF.

  "---------------- 無供應商則無法取 PIR ----------------
  IF p_data-zdefault_vendor IS INITIAL.
    RETURN.
  ENDIF.

  DATA: ls_eine  TYPE eine,
        ls_eina  TYPE eina,
        lv_peinh TYPE eine-peinh.

  CLEAR: ls_eine, ls_eina, lv_peinh.

  " 新式 Open SQL：欄位以逗號分隔，host variable 需加 @
  SELECT SINGLE
         a~infnr, a~werks, a~esokz, a~loekz,
         a~peinh, a~waers, a~netpr
    FROM eine AS a
    INNER JOIN eina AS b
      ON a~infnr = b~infnr
    WHERE a~werks = @p_data-werks             " 工廠
      AND b~matnr = @p_data-idnrk             " 料號
      AND b~lifnr = @p_data-zdefault_vendor   " 供應商
      AND a~esokz = '0'                       " 標準採購
      AND a~loekz = @space                    " 未刪除
      AND b~loekz = @space
    INTO CORRESPONDING FIELDS OF @ls_eine.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  " (如需 EINA 其他欄位，可再取；此處僅示意)
  SELECT SINGLE * FROM eina INTO @ls_eina
    WHERE infnr = @ls_eine-infnr AND loekz = @space.

  "------------------- 計價：每 1 單位之淨價 -------------------
  lv_peinh = ls_eine-peinh.
  IF lv_peinh IS INITIAL OR lv_peinh = 0.
    lv_peinh = 1.
  ENDIF.

  p_data-waers = ls_eine-waers.
  p_data-netpr = ls_eine-netpr / lv_peinh.

  " 若你偏好有效價(EFFPR)且系統版本有此欄位，可改用：
  "* p_data-netpr = ls_eine-effpr.

ENDFORM.



*---------------------------------------------------------------------*
*  Form  CALC_MOQ_FIELDS_FOR_ALL — V026 整支停用(remark) 20260611 JosephLo
*---------------------------------------------------------------------*
* V026 JosephLo 20260611 — 整支 remark。本 FORM 自始空轉:下方 ASSIGN COMPONENT 用的欄名
*   ZMOQ_BASE/ZTHEORY_STOCK/ZUNIT_USE/ZMOQ_REMAIN/ZCAN_MAKE 與實際結構欄
*   ZMOQ/STOCK_QTY/MNGLG/MOQ_REMAIN/OUT_QTY 全不符 → 每列第一個 ASSIGN 即失敗、CONTINUE,從未計算。
*   可做台數/MOQ結餘已統一由共用 FORM calc_out_qty(V026 淨額公式)處理;主程式 3 處 PERFORM 呼叫亦一併 remark。
*   原碼(含從未執行的 out_qty=floor(理論庫存/單位用量) 與 moq_remain−50)保留為註解備查。
*FORM calc_moq_fields_for_all
*  CHANGING ct_tab TYPE STANDARD TABLE.
*
*  CONSTANTS:
*    c_f_moq_base     TYPE fieldname VALUE 'ZMOQ_BASE',
*    c_f_theory_stock TYPE fieldname VALUE 'ZTHEORY_STOCK',
*    c_f_unit_use     TYPE fieldname VALUE 'ZUNIT_USE',
*    c_f_moq_remain   TYPE fieldname VALUE 'ZMOQ_REMAIN',
*    c_f_can_make     TYPE fieldname VALUE 'ZCAN_MAKE'.
*
*  FIELD-SYMBOLS: <row>          TYPE any,
*                 <moq_base>     TYPE any,
*                 <theory_stock> TYPE any,
*                 <unit_use>     TYPE any,
*                 <moq_remain>   TYPE any,
*                 <can_make>     TYPE any.
*
*  DATA: lv_moq   TYPE p DECIMALS 3,
*        lv_stock TYPE p DECIMALS 3,
*        lv_unit  TYPE p DECIMALS 3,
*        lv_can   TYPE p DECIMALS 3,
*        lv_mod   TYPE p DECIMALS 3.
*
*  LOOP AT ct_tab ASSIGNING <row>.
*
*    "--- 綁定欄位
*    ASSIGN COMPONENT c_f_moq_base     OF STRUCTURE <row> TO <moq_base>.
*    ASSIGN COMPONENT c_f_theory_stock OF STRUCTURE <row> TO <theory_stock>.
*    ASSIGN COMPONENT c_f_unit_use     OF STRUCTURE <row> TO <unit_use>.
*    ASSIGN COMPONENT c_f_moq_remain   OF STRUCTURE <row> TO <moq_remain>.
*    ASSIGN COMPONENT c_f_can_make     OF STRUCTURE <row> TO <can_make>.
*    IF <moq_base> IS NOT ASSIGNED OR <theory_stock> IS NOT ASSIGNED
*       OR <moq_remain> IS NOT ASSIGNED OR <can_make> IS NOT ASSIGNED.
*      CONTINUE.
*    ENDIF.
*
*    "--- 取值/預設
*    lv_moq   = <moq_base>.
*    lv_stock = <theory_stock>.
*    IF <unit_use> IS ASSIGNED AND <unit_use> IS NOT INITIAL.
*      lv_unit = <unit_use>.
*    ELSE.
*      lv_unit = 1. " 預設單位用量=1
*    ENDIF.
*
*    "--- 可做台數：INT(理論庫存 ÷ 單位用量)，不受 50 常數影響
*    lv_can = floor( lv_stock / lv_unit ).
*    <can_make> = lv_can.
*
*    "--- MOQ結餘：考慮 50 常數
*    IF lv_moq IS INITIAL.
*      <moq_remain> = 0.
*    ELSE.
*      lv_mod = lv_stock - ( lv_moq * floor( lv_stock / lv_moq ) ).
*      IF lv_mod = 0.
*        <moq_remain> = 0.
*      ELSE.
*        <moq_remain> = lv_moq - lv_mod.
*
*        "--- 套用 50 常數：若剩餘 > 50，則減去 50
*        IF <moq_remain> > 50.
*          <moq_remain> = <moq_remain> - 50.
*        ELSE.
*          <moq_remain> = 0.
*        ENDIF.
*
*      ENDIF.
*    ENDIF.
*
*  ENDLOOP.
*
*ENDFORM.


*---------------------------------------------------------------------*
* PATCH F : GET_INDEPENDENT_DEMAND_BATCH
* 批次抓取多筆料號+工廠+需求日期的獨立需求 (PBIM+PBED)
*---------------------------------------------------------------------*
FORM get_independent_demand_batch
  USING    it_keys   TYPE tt_key
  CHANGING ct_demand TYPE tt_result.

  "JOIN 結構 (PBIM+PBED 選取的欄位)
  TYPES: BEGIN OF ty_join,
           matnr TYPE matnr,
           werks TYPE werks_d,
           wdatu TYPE dats,
           plnmg TYPE plnmg,
         END OF ty_join.

  DATA: lt_join   TYPE STANDARD TABLE OF ty_join,
        lt_result TYPE tt_result,
        ls_result TYPE ty_result.

  FIELD-SYMBOLS: <ls_key>  TYPE ty_key,
                 <ls_join> TYPE ty_join.

  IF it_keys IS INITIAL.
    RETURN.
  ENDIF.

  "Step 1: PBIM + PBED 批次查詢 (FOR ALL ENTRIES)
  SELECT a~matnr,
         a~werks,
         b~wdatu,
         b~plnmg
    FROM pbim AS a
    INNER JOIN pbed AS b
       ON a~bdzei = b~bdzei
    FOR ALL ENTRIES IN @it_keys
   WHERE a~matnr = @it_keys-matnr
     AND a~werks = @it_keys-werks
     AND a~versb = '00'
     AND a~loevr = @space
     AND b~loevr = @space
     AND b~wdatu <= @it_keys-req_date
    INTO TABLE @lt_join.

  IF lt_join IS INITIAL.
    RETURN.
  ENDIF.

  "Step 2: 按 matnr/werks/req_date 聚合數量
  LOOP AT it_keys ASSIGNING <ls_key>.
    CLEAR ls_result.
    ls_result-matnr    = <ls_key>-matnr.
    ls_result-werks    = <ls_key>-werks.
    ls_result-req_date = <ls_key>-req_date.

    LOOP AT lt_join ASSIGNING <ls_join>
         WHERE matnr = <ls_key>-matnr
           AND werks = <ls_key>-werks
           AND wdatu <= <ls_key>-req_date.

      ls_result-qty = ls_result-qty + <ls_join>-plnmg.
    ENDLOOP.

    APPEND ls_result TO lt_result.
  ENDLOOP.

  ct_demand = lt_result.

ENDFORM.  "get_independent_demand_batch


*---------------------------------------------------------------------*
* PATCH G : 判斷是否電子件 (依物料群組 A0701~A0710)
*---------------------------------------------------------------------*
FORM is_electronic_part
  USING    iv_matnr TYPE matnr
  CHANGING cv_flag  TYPE abap_bool.

  DATA(lv_matkl) = VALUE matkl( ).
  CLEAR cv_flag.

  SELECT SINGLE matkl
    FROM mara
    WHERE matnr = @iv_matnr
    INTO @lv_matkl.

  IF sy-subrc = 0 AND lv_matkl BETWEEN 'A0701' AND 'A0710'.
    cv_flag = abap_true.
  ENDIF.

ENDFORM.  "PATCH G is_electronic_part



FORM frm_fix_missing_materials.

  TYPES: BEGIN OF ty_unique_header,
           zportalno     TYPE ztcx0001-zportalno,
           qq            TYPE ztcx0001-qq,
           matnr         TYPE ztcx0001-matnr,
           werks         TYPE ztcx0001-werks,
           vtweg         TYPE ztcx0001-vtweg,
           req_date      TYPE ztcx0001-req_date,
           zportalno_qty TYPE ztcx0001-zportalno_qty,
         END OF ty_unique_header,
         BEGIN OF ty_exist_key,
           zportalno TYPE ztcx0001-zportalno,
           idnrk     TYPE ztcx0001-idnrk,
         END OF ty_exist_key,
         BEGIN OF ty_collected,
           idnrk TYPE matnr,
           werks TYPE werks_d,
           meins TYPE meins,
           menge TYPE menge_d,
         END OF ty_collected.

  DATA: lt_raw        TYPE TABLE OF ztcx0001,
        ls_raw        TYPE ztcx0001,
        lt_header     TYPE SORTED TABLE OF ty_unique_header
                           WITH UNIQUE KEY zportalno qq matnr werks vtweg req_date zportalno_qty,
        ls_header     TYPE ty_unique_header,
        lt_stpox      TYPE TABLE OF stpox,
        ls_stpox      TYPE stpox,
        ls_topmat     TYPE cstmat,
        lt_to_insert  TYPE TABLE OF ztcx0001,
        ls_to_insert  TYPE ztcx0001,
        lt_exist      TYPE HASHED TABLE OF ty_exist_key WITH UNIQUE KEY zportalno idnrk,
        ls_exist      TYPE ty_exist_key,
        lt_display    TYPE TABLE OF ztcx0001,
        lv_count      TYPE i VALUE 0,
        lv_skip_count TYPE i VALUE 0,
        lv_tabix      TYPE sy-tabix,
        lo_alv        TYPE REF TO cl_salv_table,
        lo_functions  TYPE REF TO cl_salv_functions,
        lo_columns    TYPE REF TO cl_salv_columns_table,
        lx_msg        TYPE REF TO cx_salv_msg.

  DATA: lv_header_qty_int TYPE i,
        lv_emeng          TYPE menge_d,
        lv_base_qty       TYPE menge_d,
        lv_unit_qty       TYPE menge_d,
        lv_total_demand   TYPE menge_d,
        lv_first_erdat    TYPE erdat.          " V012 KY

  DATA: lt_collected TYPE HASHED TABLE OF ty_collected
                          WITH UNIQUE KEY idnrk werks meins,
        ls_collected TYPE ty_collected.

  "=== Step 1：檢查輸入 ===
* V005 Changed by Tristan 2026/02/04 *
*  IF s_pr[] IS INITIAL.
*    MESSAGE e001(00) WITH '請輸入 RR 詢單單號 (S_PR) 後再執行補回'.
*  ENDIF.
*  "=== Step 2：查詢並同時處理去重 + 提取已存在子件 ===
*  DELETE FROM ztcx0001
*    WHERE zportalno IN @s_pr
*      AND beskz      = ''
*      AND mstae      = ''.
*
*  SELECT *
*    FROM ztcx0001
*    WHERE zportalno IN @s_pr
*    INTO TABLE @lt_raw.
  IF s_pr[] IS INITIAL AND s_erdat[] IS INITIAL.
    MESSAGE e001(00) WITH '請輸入RR詢單單號(S_PR)或是"建立日期"後再執行補回'.
  ENDIF.
  "=== Step 2：查詢並同時處理去重 + 提取已存在子件 ===
  DELETE FROM ztcx0001
    WHERE zportalno IN @s_pr
      AND beskz      = ''
      AND mstae      = ''
      AND erdat IN @s_erdat.

  SELECT *
    FROM ztcx0001
    WHERE zportalno IN @s_pr
      AND erdat IN @s_erdat
    INTO TABLE @lt_raw.
* V005 End off *

  IF lt_raw IS INITIAL.
    MESSAGE e001(00) WITH 'ZTCX0001 無此詢單單號的資料'.
    RETURN.
  ENDIF.

  LOOP AT lt_raw INTO ls_raw.
    ls_header-zportalno     = ls_raw-zportalno.
    ls_header-qq            = ls_raw-qq.
    ls_header-matnr         = ls_raw-matnr.
    ls_header-werks         = ls_raw-werks.
    ls_header-vtweg         = ls_raw-vtweg.
    ls_header-req_date      = COND #( WHEN ls_raw-req_date IS INITIAL THEN sy-datum ELSE ls_raw-req_date ).
    ls_header-zportalno_qty = ls_raw-zportalno_qty.
    INSERT ls_header INTO TABLE lt_header.

    ls_exist-zportalno = ls_raw-zportalno.
    ls_exist-idnrk     = ls_raw-idnrk.
    INSERT ls_exist INTO TABLE lt_exist.
  ENDLOOP.

  IF lt_header IS INITIAL.
    MESSAGE e001(00) WITH '去重後無資料'.
    RETURN.
  ENDIF.

* V012 Added by Tristan 2026/04/07 *
  SORT lt_raw BY zportalno erdat ASCENDING.
* V012 End off *

  "=== Step 3：展 BOM 並收集要插入的資料 ===
  LOOP AT lt_header INTO ls_header.
* V012 KY 取 lt_raw RR 詢單單號第一筆記錄的建立日期，作為所有補回子件的 建立日期 *
    AT NEW zportalno.
      lv_first_erdat = VALUE #( lt_raw[ zportalno = ls_header-zportalno ]-erdat OPTIONAL ).
      lv_first_erdat = COND #( WHEN lv_first_erdat IS INITIAL THEN my_erdat
                               ELSE lv_first_erdat ).
    ENDAT.
* V012 KY End *

    CLEAR: lt_stpox, ls_topmat, lv_header_qty_int, lv_emeng, lv_base_qty, lt_collected.
    REFRESH: lt_stpox.

    "=== 詢單台數處理 ===
    IF ls_header-zportalno_qty IS NOT INITIAL AND ls_header-zportalno_qty > 0.
      lv_header_qty_int = CONV i( ls_header-zportalno_qty ).
      lv_emeng = lv_header_qty_int.
    ELSE.
      lv_header_qty_int = 1.
      lv_emeng = 1.
    ENDIF.

    "=== BOM 展開 ===
    CALL FUNCTION 'CS_BOM_EXPL_MAT_V2'
      EXPORTING
        capid                 = 'PP01'
        datuv                 = ls_header-req_date
        emeng                 = lv_emeng
        mehrs                 = 'X'
        mtnrv                 = ls_header-matnr
        werks                 = ls_header-werks
      IMPORTING
        topmat                = ls_topmat
      TABLES
        stb                   = lt_stpox
      EXCEPTIONS
        alt_not_found         = 1
        call_invalid          = 2
        material_not_found    = 3
        missing_authorization = 4
        no_bom_found          = 5
        no_plant_data         = 6
        no_suitable_bom_found = 7
        conversion_error      = 8
        OTHERS                = 9.

    IF sy-subrc <> 0 OR lt_stpox IS INITIAL.
      CONTINUE.
    ENDIF.

    "=== 取得 BOM 基礎數量 ===
    lv_base_qty = ls_topmat-bmeng.
    IF lv_base_qty IS INITIAL OR lv_base_qty = 0.
      lv_base_qty = 1.
    ENDIF.

    "=== ✅ Step 3-0: 手動彙總重複料號（只以料號+工廠+單位為 KEY） ===
    CLEAR lt_collected.

    LOOP AT lt_stpox INTO ls_stpox.

      " 嘗試讀取已存在的記錄
      READ TABLE lt_collected INTO ls_collected
           WITH TABLE KEY idnrk = ls_stpox-idnrk
                          werks = ls_stpox-werks
                          meins = ls_stpox-meins.

      IF sy-subrc = 0.
        " 已存在：累加數量
        ls_collected-menge = ls_collected-menge + ls_stpox-menge.
        MODIFY TABLE lt_collected FROM ls_collected.
      ELSE.
        " 不存在：新增記錄
        ls_collected-idnrk = ls_stpox-idnrk.
        ls_collected-werks = ls_stpox-werks.
        ls_collected-meins = ls_stpox-meins.
        ls_collected-menge = ls_stpox-menge.
        INSERT ls_collected INTO TABLE lt_collected.
      ENDIF.

    ENDLOOP.

    " 將彙總結果轉回 STPOX 格式
    CLEAR lt_stpox.
    LOOP AT lt_collected INTO ls_collected.
      CLEAR ls_stpox.
      ls_stpox-idnrk = ls_collected-idnrk.
      ls_stpox-werks = ls_collected-werks.
      ls_stpox-meins = ls_collected-meins.
      ls_stpox-menge = ls_collected-menge.
      APPEND ls_stpox TO lt_stpox.
    ENDLOOP.

    "=== Step 3-1：過濾已存在子件 ===
    LOOP AT lt_stpox INTO ls_stpox.
      lv_tabix = sy-tabix.
      READ TABLE lt_exist WITH TABLE KEY
                               zportalno = ls_header-zportalno
                               idnrk     = ls_stpox-idnrk
                           TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        DELETE lt_stpox INDEX lv_tabix.
      ENDIF.
    ENDLOOP.

    IF lt_stpox IS INITIAL.
      CONTINUE.
    ENDIF.

    "=== Step 4：組合要插入的資料 ===
    LOOP AT lt_stpox INTO ls_stpox.

      CLEAR ls_to_insert.

      ls_to_insert-mandt         = sy-mandt.
      ls_to_insert-zportalno     = ls_header-zportalno.
      ls_to_insert-qq            = ls_header-qq.
      ls_to_insert-matnr         = ls_header-matnr.
      ls_to_insert-werks         = ls_header-werks.
      ls_to_insert-vtweg         = ls_header-vtweg.
      ls_to_insert-req_date      = ls_header-req_date.
      ls_to_insert-zportalno_qty = lv_header_qty_int.

      ls_to_insert-idnrk = ls_stpox-idnrk.

      " 數量(BUN) = STPOX-MENGE / BMENG (MENGE 已彙總)
      lv_unit_qty = ls_stpox-menge / lv_base_qty.
      ls_to_insert-mnglg = lv_unit_qty.

      " 子階需求數量 = 詢單台數 × 數量(BUN)
      lv_total_demand = lv_emeng * lv_unit_qty.
      ls_to_insert-menge = lv_total_demand.

      ls_to_insert-meins = ls_stpox-meins.

      READ TABLE gt_custmap INTO DATA(ls_custmap)
           WITH KEY vtweg = ls_to_insert-vtweg
                    werks = ls_to_insert-werks.
      IF sy-subrc = 0.
        ls_to_insert-zseq = ls_custmap-zseq.
      ENDIF.

      CLEAR ls_to_insert-qq_seq.
      ls_to_insert-loekz = ''.
*      ls_to_insert-erdat = sy-datum.
*      ls_to_insert-erdat = my_erdat. " V008 KY
      ls_to_insert-erdat = lv_first_erdat.               " V012 KY
      ls_to_insert-ernam = sy-uname.

      IF strlen( ls_to_insert-qq ) > 12.
        ls_to_insert-qq = ls_to_insert-qq(12).
      ENDIF.

      APPEND ls_to_insert TO lt_to_insert.

    ENDLOOP.

  ENDLOOP.

  IF lt_to_insert IS INITIAL.
    MESSAGE s001(00) WITH 'BOM 展開後無新子件需補回' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

* V002 Changed by Tristan 2026/01/15 *
*  "=== Step 5：逐筆插入 ZTCX0001 ===
*  LOOP AT lt_to_insert INTO ls_to_insert.
*    INSERT ztcx0001 FROM ls_to_insert.
*    IF sy-subrc = 0.
*      ADD 1 TO lv_count.
*      APPEND ls_to_insert TO lt_display.
*    ELSE.
*      ADD 1 TO lv_skip_count.
*    ENDIF.
*  ENDLOOP.
*  IF lv_count > 0.
*    COMMIT WORK.
*    IF lv_skip_count > 0.
*      MESSAGE s001(00) WITH |已補回 { lv_count } 筆，跳過 { lv_skip_count } 筆重複資料|.
*    ELSE.
*      MESSAGE s001(00) WITH |已補回 { lv_count } 筆子件至 ZTCX0001|.
*    ENDIF.
*  ELSE.
*    MESSAGE s001(00) WITH '無新資料補回或全部重複'.
*    RETURN.
*  ENDIF.
  IF lt_to_insert[] IS INITIAL.
    MESSAGE s001(00) WITH '無新資料補回或全部重複'.
    RETURN.
  ELSE.
    lv_count = lines( lt_to_insert ).
    MODIFY ztcx0001 FROM TABLE lt_to_insert.
    IF sy-subrc = 0.
      COMMIT WORK.
      lt_display[] = CORRESPONDING #( BASE ( lt_display[] ) lt_to_insert[] ).
      MESSAGE s001(00) WITH |已補回 { lv_count } 筆子件至 ZTCX0001|.
    ENDIF.
  ENDIF.
* V002 End off *

  "=== Step 6：用原生 SALV 顯示 ===
  IF lt_display IS NOT INITIAL.
    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = lo_alv
          CHANGING t_table = lt_display ).
        lo_functions = lo_alv->get_functions( ).
        lo_functions->set_all( abap_true ).
        lo_columns = lo_alv->get_columns( ).
        lo_columns->set_optimize( abap_true ).
        lo_alv->get_display_settings( )->set_list_header( '補回子件結果' ).
        lo_alv->display( ).
      CATCH cx_salv_msg INTO lx_msg.
        MESSAGE lx_msg->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDIF.

ENDFORM.



*&---------------------------------------------------------------------*
*& Form explode_bom
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LS_UPLOAD
*&      <-- LT_STPOX
*&---------------------------------------------------------------------*
FORM explode_bom TABLES pt_stpox STRUCTURE stpox
                  USING  p_upload LIKE LINE OF gt_upload
                         p_topmat TYPE cstmat.
  CLEAR: pt_stpox[], p_topmat, it_stpox.
  DATA:lt_stpox  TYPE TABLE OF stpox,
       lt_matcat TYPE TABLE OF cscmat,
       ls_topmat TYPE cstmat,
       lv_datuv  TYPE sy-datum,
       lv_matnr  TYPE mast-matnr,
       lv_werks  TYPE mast-werks,
       lv_menge  TYPE stpox-menge,
       lv_found  TYPE c,
       lv_pass   TYPE c.
  "=== ↓↓↓ 新增：用於正確累加的 HASH TABLE ↓↓↓ ===
  TYPES: BEGIN OF ty_collect,
           idnrk TYPE matnr,
           werks TYPE werks_d,
           meins TYPE meins,
           mngko TYPE menge_d,  " 只累加總數量
         END OF ty_collect.
  DATA: lt_collect TYPE HASHED TABLE OF ty_collect
                        WITH UNIQUE KEY idnrk werks meins,
        ls_collect TYPE ty_collect.
  "=== ↑↑↑ 新增結束 ↑↑↑ ===
  lv_datuv = p_upload-req_date.
  lv_matnr = p_upload-matnr.
  lv_werks = p_upload-werks.
  lv_menge = 1000."p_upload-menge.
  CALL FUNCTION 'CS_BOM_EXPL_MAT_V2'
    EXPORTING
*     FTREL                 = ' '               " Limited multi-level - stop explosion at items not relevant to production
*     ALEKZ                 = ' '               " Checkbox
*     ALTVO                 = ' '               " Alternative Priority
*     AUFSW                 = ' '               " Determine and enter order level and channel
*     AUMGB                 = ' '               " Calculate scrap quantity  " 是否计算损耗
*     AUMNG                 = 0                 " Scrap quantity
*     AUSKZ                 = ' '               " Take Scrap into Account
*     AMIND                 = ' '               " Checkbox
*     BAGRP                 = ' '               " Assembly restriction
*     BEIKZ                 = ' '               " Material Provision Indicator
*     BESSL                 = ' '               " Material provision selection indicator
*     BGIXO                 = ' '               " Load assembly information for exploded assemblies only
*     BREMS                 = ' '               " Limited Explosion
      capid                 = 'PP01'            " Application ID    " BOM用途：（E-BOM 例:STD1 M-BOM.例:PP01 PP02) 必须字段：BOM类型
*     CHLST                 = ' '               " Checkbox
*     COSPR                 = ' '               " Internal: (CO) order-spec. MatPreRead
*     CUOBJ                 = 000000000000000   " Configuration     " 与特性相关的组态
*     CUOVS                 = 0                 " IB: Time stamp of owner's or observer's version
*     CUOLS                 = ' '               " Checkbox
      datuv                 = lv_datuv          " Valid On必须字段：BOM有效日期
*     DELNL                 = ' '               " Delete items not kept in stock from list
*     DRLDT                 = ' '               " Checkbox
      ehndl                 = 'X'               " Checkbox  V010 替代料
      emeng                 = lv_menge                 " Required quantity" 其他字段：计算材料需求时，可以传入具体的成品数量
*     ERSKZ                 = ' '               " Spare part indicator
*     ERSSL                 = ' '               " Spare part selection indicator
*     FBSTP                 = ' '               " Limited multi-level - stop explosion at externally procured item
*     KNFBA                 = ' '               " Checkbox
*     KSBVO                 = ' '               " Checkbox
*     MBWLS                 = ' '               " Read Material Valuation
*     MKTLS                 = 'X'               " Read Material Description
*     MDMPS                 = ' '               " Limited multi-level - explode phantom assemblies at least   " 虚拟件标识" 限制字段：限制BOM只展1层，但下层是虚拟件的则再往下展开一层，默认为空不限制
      mehrs                 = 'X'               " Multilevel Explosion    " 多阶展开 'X'-多阶； ''-单阶" 重要字段：BOM多级展开，默认为空，只展开一层
*     MKMAT                 = ' '               " Limited multi-level; explode KMAT
*     MMAPS                 = ' '               " Limited multi-level - explode at least M assembly (M order)
*     SALWW                 = ' '               " Checkbox
*     SPLWW                 = ' '               " Checkbox
*     MMORY                 = ' '               " Memory Mgmt ('1'=On;'0'=Off;' '=No Reaction)
      mtnrv                 = lv_matnr          " Material" 必须字段：物料号
*     NLINK                 = ' '               " Checkbox
*     POSTP                 = ' '               " Item category
*     RNDKZ                 = ' '               " Round off: ' '=always, '1'=never, '2'=only levels > 1
*     RVREL                 = ' '               " Relevant to sales
*     SANFR                 = ' '               " Production
*     SANIN                 = ' '               " Maintenance
*     SANKA                 = ' '               " Costing
*     SANKO                 = ' '               " Engineering/design
*     SANVS                 = ' '               " Shipping
*     SCHGT                 = ' '               " Bulk material
*     STKKZ                 = ' '               " PM assembly
*     STLAL                 = ' '               " Alternative BOM   " 备选物料清单
*     STLAN                 = ' '               " BOM usage         " BOM用途
*     STPST                 = 0                 " Level (in multi-level BOM explosions)" 限制字段：限定BOM展开层数，默认0表示全展，1表示展开1层，以此类推；实测负数全部为展1层
*     SVWVO                 = 'X'               " Checkbox
      werks                 = lv_werks          " Plant必须字段：工厂号
*     NORVL                 = ' '               " Checkbox
*     MDNOT                 = ' '               " Restriction on MDMPS: do not explode M phantom
*     PANOT                 = ' '               " Restriction on MDMPS: no parallel discontinue
*     QVERW                 = ' '               " Quota arrangement usage
*     VERID                 = ' '               " Production Version
*     VRSVO                 = 'X'               " Checkbox
*   SGT_SCAT                    =	                " Stock Segment
*     SGT_REL               =                   " Segmentation Relevant
*     CALLER_APP            =                   " Caller Application
*     BOM_VERSN             =                   " BOM Version
    IMPORTING
      topmat                = ls_topmat                   " Data for start material
*     DSTST                 =                   " Structure destroyed by filter
    TABLES
      stb                   = lt_stpox                 " Collective item data table必须接收的表：BOM展开明细
      matcat                = lt_matcat                  " Material catalog (sub-assemblies)" 父级物料清单：参与BOM展开的父级物料清单，即含有组件的物料
    EXCEPTIONS
      alt_not_found         = 1
      call_invalid          = 2
      material_not_found    = 3
      missing_authorization = 4
      no_bom_found          = 5
      no_plant_data         = 6
      no_suitable_bom_found = 7
      conversion_error      = 8
      OTHERS                = 9.
  IF sy-subrc <> 0.
* Implement suitable error handling here
* V014 Marked by Tristan 2026/04/28 *
*    MESSAGE s009 WITH p_upload-vtweg p_upload-matnr p_upload-werks p_upload-req_date DISPLAY LIKE 'E'.
* V014 End off *
  ELSE.
    READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname .
    "check ZTMARC.ZMOQ
    LOOP AT lt_stpox INTO DATA(ls_stpox).
      SELECT SINGLE marc~matnr,beskz,sobsl,makt~maktx
        FROM marc INNER JOIN makt
          ON makt~matnr = marc~matnr
         AND makt~spras = @sy-langu
      WHERE werks = @ls_stpox-werks
        AND marc~matnr = @ls_stpox-idnrk
       INTO @DATA(ls_marc).
      IF sy-subrc = 0.
*        SELECT SINGLE zmoq FROM ztmarc WHERE matnr = @ls_stpox-idnrk AND werks = @ls_stpox-werks INTO @DATA(lv_zmoq).
*        IF sy-subrc = 0 AND ( lv_zmoq IS INITIAL OR lv_zmoq = 1 )."MOQ = 1 的需排除
*          DELETE lt_stpox WHERE idnrk = ls_stpox-idnrk AND werks = ls_stpox-werks.
*          CONTINUE.
*        ENDIF.
        "不報 MOQ 的檢查
* V025 JosephLo 2026/06/01 改讀 gs_mode-do_filter(此IF同時控制不報MOQ標記+下方角色PATCH2;ZTGCX0001A勾P_FILT才過濾,預設不勾=顯示全部)
        IF gs_mode-do_filter = 'X'.
          DATA:lr_meins TYPE RANGE OF mara-meins,
               lr_maktx TYPE RANGE OF makt-maktx.
          CLEAR:lv_found.
* V013 Changed by Tristan 2026/04/17 *
*          SORT gt_nomoq BY  maktx DESCENDING matkl DESCENDING meins DESCENDING sobsl DESCENDING beskz DESCENDING .
*          LOOP AT gt_nomoq INTO DATA(ls_q1) WHERE  matkl = ls_stpox-matkl
*                                             AND beskz = ls_marc-beskz AND sobsl = ls_marc-sobsl.
          SORT gt_nomoq BY  maktx DESCENDING matkl DESCENDING meins DESCENDING sobsl DESCENDING beskz DESCENDING .
* LS_STPOX-MATKL不是IDNRK的MATKL要用MATMK這個才對
          LOOP AT gt_nomoq INTO DATA(ls_q1) WHERE matkl = ls_stpox-matmk
                                              AND beskz = ls_marc-beskz
                                              AND sobsl = ls_marc-sobsl.
* V013 End off *
            CLEAR:lr_meins,lr_maktx.

            APPEND INITIAL LINE TO lr_meins ASSIGNING FIELD-SYMBOL(<r1>).
            APPEND INITIAL LINE TO lr_maktx ASSIGNING FIELD-SYMBOL(<r2>).

            IF ls_q1-meins IS NOT INITIAL.
              <r1>-sign = 'I'.
              <r1>-option = 'EQ'.
              <r1>-low = ls_q1-meins.
            ELSE.
              <r1>-sign = 'I'.
              <r1>-option = 'CP'.
              <r1>-low = '*'.
            ENDIF.
            IF ls_q1-maktx IS NOT INITIAL.
              <r2>-sign = 'I'.
              <r2>-option = 'CP'.
              <r2>-low = |*{ ls_q1-maktx }*|.
            ELSE.
              <r2>-sign = 'I'.
              <r2>-option = 'CP'.
              <r2>-low = '*'.
            ENDIF.

            IF ls_stpox-meins IN lr_meins AND ls_marc-maktx IN lr_maktx.
              IF ls_q1-ismoq = 'X'.
                lv_found = 'X'.
              ELSE.
                lv_found = ''.
              ENDIF.
              EXIT.
            ENDIF.

          ENDLOOP.
          "=== PATCH 1: 不刪除不報MOQ料號，改為標記 ===
          IF lv_found = 'X'.
            READ TABLE gt_nomoq INTO ls_q1 WITH KEY matnr = ls_stpox-idnrk  .
            IF sy-subrc = 0.
              IF ls_q1-ismoq = 'X'.
                " 原本是 DELETE，現在改為標記
                LOOP AT lt_stpox ASSIGNING FIELD-SYMBOL(<fs_stpox>) WHERE idnrk = ls_stpox-idnrk.
                  <fs_stpox>-loekz = 'M'.  " M = 不報MOQ標記
                ENDLOOP.
              ELSE.

              ENDIF.
            ELSE.
              " 原本是 DELETE，現在改為標記
              LOOP AT lt_stpox ASSIGNING FIELD-SYMBOL(<fs_stpox2>) WHERE idnrk = ls_stpox-idnrk.
                <fs_stpox2>-loekz = 'M'.  " M = 不報MOQ標記
              ENDLOOP.
            ENDIF.
          ELSE.
            READ TABLE gt_nomoq INTO ls_q1 WITH KEY matnr = ls_stpox-idnrk  .
            IF sy-subrc = 0 AND ls_q1-ismoq = 'X'.
              " 原本是 DELETE，現在改為標記
              LOOP AT lt_stpox ASSIGNING FIELD-SYMBOL(<fs_stpox3>) WHERE idnrk = ls_stpox-idnrk.
                <fs_stpox3>-loekz = 'M'.  " M = 不報MOQ標記
              ENDLOOP.
            ENDIF.
          ENDIF.

          "料號 DESC,
          "物料說明 DESC,
          "物料群組 DESC,
          "計量單位 DESC,
          "特殊採購 DESC,
          "採購類型 DESC
*          CLEAR:lv_found,lv_pass.
*          lv_pass = 'X'.
*          SORT gt_nomoq BY matnr DESCENDING maktx DESCENDING matkl DESCENDING meins DESCENDING sobsl DESCENDING beskz DESCENDING .
*          LOOP AT gt_nomoq INTO DATA(ls_q1) WHERE matnr = ls_stpox-idnrk AND matkl = ls_stpox-matkl
*                                              AND beskz = ls_marc-beskz AND sobsl = ls_marc-sobsl
*                                              AND meins = ls_stpox-meins AND maktx IS NOT INITIAL.
*            IF ls_marc-maktx CS |{ ls_q1-maktx }|.
*              IF ls_q1-ismoq = 'X'.
*                lv_pass = ''.
*                lv_found = 'X'.
*              ELSE.
*                lv_pass = 'X'.
*                lv_found = 'X'.
*              ENDIF.
*            ELSE.
*              lv_found = ''.
*            ENDIF.
*            EXIT.
*          ENDLOOP.
*          IF sy-subrc NE 0.
*            LOOP AT gt_nomoq INTO ls_q1 WHERE matkl = ls_stpox-matkl
*                                              AND beskz = ls_marc-beskz AND sobsl = ls_marc-sobsl
*                                              AND meins = ls_stpox-meins AND maktx IS NOT INITIAL.
*              IF ls_marc-maktx CS |{ ls_q1-maktx }|.
*                IF ls_q1-ismoq = 'X'.
*                  lv_pass = ''.
*                  lv_found = 'X'.
*                ELSE.
*                  lv_pass = 'X'.
*                  lv_found = 'X'.
*                ENDIF.
*              ELSE.
*                lv_found = ''.
*              ENDIF.
*              EXIT.
*            ENDLOOP.
*          ENDIF.
*          IF lv_found IS INITIAL.
*            LOOP AT gt_nomoq INTO ls_q1 WHERE matnr = ls_stpox-idnrk AND matkl = ls_stpox-matkl
*                                              AND beskz = ls_marc-beskz AND sobsl = ls_marc-sobsl
*                                              AND meins = ls_stpox-meins AND maktx IS INITIAL.
*              IF ls_q1-ismoq = 'X'.
*                lv_pass = ''.
*                lv_found = 'X'.
*              ELSE.
*                lv_pass = 'X'.
*                lv_found = 'X'.
*              ENDIF.
*
*              EXIT.
*
*            ENDLOOP.
*            IF sy-subrc NE 0.
*              LOOP AT gt_nomoq INTO ls_q1 WHERE matkl = ls_stpox-matkl
*                                              AND beskz = ls_marc-beskz AND sobsl = ls_marc-sobsl
*                                              AND meins = ls_stpox-meins AND maktx IS INITIAL.
*                IF ls_q1-ismoq = 'X'.
*                  lv_pass = ''.
*                  lv_found = 'X'.
*                ELSE.
*                  lv_pass = 'X'.
*                  lv_found = 'X'.
*                ENDIF.
*
*                EXIT.
*
*              ENDLOOP.
*            ENDIF.
*
*          ENDIF.
*          IF lv_pass = ''.
*            DELETE lt_stpox WHERE idnrk = ls_stpox-idnrk.
*          ENDIF.
*          CLEAR:lv_found,lv_pass.
*          IF line_exists( gt_nomoq[ matkl = ls_stpox-matkl matnr = ls_marc-matnr ] ).
*            READ TABLE gt_nomoq INTO DATA(ls_mat) WITH KEY matkl = ls_stpox-matkl matnr = ls_marc-matnr.
*            IF ls_mat-ismoq = 'X'.
*              DELETE lt_stpox WHERE idnrk = ls_stpox-idnrk.
*            ENDIF.
*          ELSE.
*            LOOP AT gt_nomoq INTO DATA(ls_q1) WHERE matkl = ls_stpox-matkl AND beskz = ls_marc-beskz AND sobsl = ls_marc-sobsl AND meins = ls_stpox-meins.
*              IF ls_q1-maktx IS NOT INITIAL.
*                IF ls_marc-maktx CP |*{ ls_q1-maktx }*|.
*                  IF ls_q1-ismoq = 'X'.
*                    lv_pass = ''.
*                  ELSE.
*                    lv_pass = 'X'.
*                  ENDIF.
*                ELSE.
*                  "lv_pass = 'X'.
*                ENDIF.
*              ELSE.
*                IF ls_q1-ismoq = 'X'.
*                  lv_pass = ''.
*                ELSE.
*                  lv_pass = 'X'.
*                ENDIF.
*              ENDIF.
*            ENDLOOP.
*            IF lv_pass = ''.
*              DELETE lt_stpox WHERE idnrk = ls_stpox-idnrk.
*            ENDIF.
*          ENDIF.
*          CLEAR:lv_found.
*          IF line_exists( gt_nomoq[ matkl = ls_stpox-matkl beskz = ls_marc-beskz sobsl = ls_marc-sobsl ismoq = 'X' ] ).
*            LOOP AT gt_nomoq INTO DATA(ls_nomoq) WHERE matkl = ls_stpox-matkl AND ismoq = '' AND maktx IS NOT INITIAL.
*              EXIT.
*            ENDLOOP.
*            IF sy-subrc = 0.
*              LOOP AT gt_nomoq INTO DATA(ls_nomoq1) WHERE matkl = ls_stpox-matkl AND ismoq = '' AND maktx IS NOT INITIAL.
*                IF ls_marc-maktx CP |*{ ls_nomoq1-maktx }*|.
*                  lv_found = 'X'.
*                  EXIT.
*                ENDIF.
*              ENDLOOP.
*              IF lv_found IS INITIAL.
*                DELETE lt_stpox WHERE idnrk = ls_stpox-idnrk.
*                CONTINUE.
*              ENDIF.
*            ELSE.
*              DELETE lt_stpox WHERE idnrk = ls_stpox-idnrk.
*              CONTINUE.
*            ENDIF.
*          ELSE.
*            IF line_exists( gt_nomoq[ matnr = ls_stpox-idnrk beskz = ls_marc-beskz sobsl = ls_marc-sobsl ismoq = 'X' ] ).
*              DELETE lt_stpox WHERE idnrk = ls_stpox-idnrk.
*              CONTINUE.
*            ENDIF.
*          ENDIF.
          "生管上傳後，只能確認採購類型E的子件
          "採購上傳後，只能確認採購類型F、F-30的子件
          "當地採購上傳後，只能確認當地採購(非11200/21200)的F、F-30子件
          "=== PATCH 2: 角色權限過濾改為標記 ===
          CASE ls_role-role.
            WHEN 'A'. "生管：只確認 E 類
              IF ls_marc-beskz NE 'E'.
                " 原本是 DELETE，改為標記
                LOOP AT lt_stpox ASSIGNING FIELD-SYMBOL(<fs_role>)
                     WHERE idnrk = ls_stpox-idnrk AND werks = ls_stpox-werks.
                  <fs_role>-loekz = 'M'.
                ENDLOOP.
                CONTINUE.
              ENDIF.

            WHEN 'C'. "採購：F 與 F-30
              IF NOT ( ( ls_marc-beskz = 'F' AND ls_marc-sobsl = '30' )
                    OR ( ls_marc-beskz = 'F' AND ls_marc-sobsl = '' ) ).
                " 原本是 DELETE，改為標記
                LOOP AT lt_stpox ASSIGNING FIELD-SYMBOL(<fs_role2>)
                     WHERE idnrk = ls_stpox-idnrk AND werks = ls_stpox-werks.
                  <fs_role2>-loekz = 'M'.
                ENDLOOP.
                CONTINUE.
              ENDIF.

            WHEN 'D'. "當地採購：與C相同，只確認 F 與 F-30（不過濾供應商）
              IF NOT ( ( ls_marc-beskz = 'F' AND ls_marc-sobsl = '30' )
                    OR ( ls_marc-beskz = 'F' AND ls_marc-sobsl = '' ) ).
                " 原本是 DELETE，改為標記
                LOOP AT lt_stpox ASSIGNING FIELD-SYMBOL(<fs_role3>)
                     WHERE idnrk = ls_stpox-idnrk AND werks = ls_stpox-werks.
                  <fs_role3>-loekz = 'M'.
                ENDLOOP.
                CONTINUE.
              ENDIF.



          ENDCASE.
        ENDIF.
      ENDIF.
    ENDLOOP.
    p_topmat = ls_topmat.
  ENDIF.
* V014 Added by Tristan 2026/05/18 *
  IF lt_stpox[] IS NOT INITIAL.
    SELECT marc~matnr, marc~werks, ztmarc~zdefault_vendor
      FROM marc INNER JOIN ztmarc
        ON marc~matnr = ztmarc~matnr
       AND marc~werks = ztmarc~werks
       FOR ALL ENTRIES IN @lt_stpox
     WHERE marc~matnr = @lt_stpox-idnrk
       AND marc~werks = @lt_stpox-werks
       AND marc~beskz = 'F'  " 採購類型
       AND marc~sobsl = ''   " 特殊採購類型
      INTO TABLE @it_marc.
  ENDIF.
* V014 End off *
  "=== ↓↓↓ 修正：先累加 mngko，再計算 menge ↓↓↓ ===
  CLEAR: ls_stpox, lt_collect.

  " Step 1: 只累加總需求量（mngko）
  LOOP AT lt_stpox INTO ls_stpox WHERE loekz NE 'M'.  " 排除標記為不報MOQ的
* V014 Added by Tristan 2026/05/18 *
    DATA(lv_plevel) = CONV histu( ls_stpox-stufe - 1 ).
    IF lv_plevel = 0 OR ls_stpox-vwegx = 0.
      DATA(ls_parent) = ls_stpox.
* 因為BOM表裡面 如果這個元件是最上階的話不會有父階 所以要拿原始展BOM的那個料當成是父階
      ls_parent-idnrk = p_upload-matnr.
    ELSE.
      ls_parent = VALUE #( lt_stpox[ stufe = lv_plevel
                                     wegxx = ls_stpox-vwegx ] OPTIONAL ).
    ENDIF.
    DATA(lv_marc) = VALUE #( it_marc[ matnr = ls_parent-idnrk
                                      werks = ls_parent-werks ] OPTIONAL ).
    IF lv_marc-zdefault_vendor <> '' AND lv_marc-zdefault_vendor NOT IN r_lifnr.
      ls_stpox-mngko = 0.
      ls_stpox-mnglg = 0.
    ENDIF.
* V014 End off *
    READ TABLE lt_collect INTO ls_collect
         WITH TABLE KEY idnrk = ls_stpox-idnrk
                        werks = ls_stpox-werks
                        meins = ls_stpox-meins.
    IF sy-subrc = 0.
      " 已存在：只累加 mngko
      ls_collect-mngko = ls_collect-mngko + ls_stpox-mngko.
      MODIFY TABLE lt_collect FROM ls_collect.
    ELSE.
      " 新記錄
      ls_collect-idnrk = ls_stpox-idnrk.
      ls_collect-werks = ls_stpox-werks.
      ls_collect-meins = ls_stpox-meins.
      ls_collect-mngko = ls_stpox-mngko.
      INSERT ls_collect INTO TABLE lt_collect.
    ENDIF.
  ENDLOOP.

  " Step 2: 根據累加結果重新計算 pt_stpox
  LOOP AT lt_collect INTO ls_collect.
    CLEAR pt_stpox.
    pt_stpox-idnrk = ls_collect-idnrk.
    pt_stpox-werks = ls_collect-werks.
    pt_stpox-meins = ls_collect-meins.
    pt_stpox-mngko = ls_collect-mngko.

    " ✅ 重新計算單位用量（不累加）
    pt_stpox-menge = round( val = ls_collect-mngko / ls_topmat-bmeng
                           dec = 3
                           mode = cl_abap_math=>round_up ).

    " ✅ mnglg 從原始 BOM 取值（不累加）
    READ TABLE lt_stpox INTO ls_stpox
         WITH KEY idnrk = ls_collect-idnrk
                  werks = ls_collect-werks
                  meins = ls_collect-meins.
    IF sy-subrc = 0.
      pt_stpox-mnglg = ls_stpox-mnglg.  " 保持原始 BOM 定義值
    ENDIF.

    " 檢查是否標記為不報MOQ
    READ TABLE lt_stpox INTO ls_stpox
         WITH KEY idnrk = ls_collect-idnrk
                  werks = ls_collect-werks
                  loekz = 'M'.
    IF sy-subrc = 0.
      pt_stpox-loekz = 'M'.
    ENDIF.

    APPEND pt_stpox.
  ENDLOOP.
  "=== ↑↑↑ 修正結束 ↑↑↑ ===
* V013 Added by Tristan 2026/04/16 *
* 拿來判斷父階->確認子階需求數量
  it_stpox[] = lt_bom[] = lt_stpox[].
  DELETE it_stpox WHERE loekz <> 'M'.
* V013 End off *
ENDFORM.
*&---------------------------------------------------------------------*
*& Form init_param
*&---------------------------------------------------------------------*
FORM init_param .
  IF sy-tcode <> 'ZTGCX0001B'.
    LOOP AT SCREEN.
      IF screen-name = 'P_FIX'.
        screen-active = 0.
        MODIFY SCREEN.
      ENDIF.
    ENDLOOP.
  ENDIF.
* V025 JosephLo 2026/06/01 P_FILT 畫面顯示控制抽到 include ZTGCX0001F00(adjust_screen_filt)
  PERFORM adjust_screen_filt.
* V012 Added by Tristan 2026/04/07 *
  RANGES: r_ernam FOR ztcx0001-ernam,
          r_erdat FOR ztcx0001-erdat.
  DATA: lv_del, lv_upd.
*  IF lv_del = 'X'.
*    r_ernam-sign = 'I'. r_ernam-option = 'EQ'.
*    r_ernam-low = ' FKYL__260411'. APPEND r_ernam.
*    SELECT * INTO TABLE @DATA(it_ztcx0001)
*      FROM ztcx0001
*     WHERE ernam IN @r_ernam
*       AND erdat IN @r_erdat.
*    IF sy-subrc = 0.
*      DELETE ztcx0001 FROM TABLE it_ztcx0001.
*      COMMIT WORK.
*    ENDIF.
*  ENDIF.
  IF lv_upd = 'X'.
    r_ernam-sign = 'I'. r_ernam-option = 'EQ'.
    r_ernam-low = 'FKYL__260208'. APPEND r_ernam.
    r_ernam-low = 'FKYL__260301'. APPEND r_ernam.
    r_ernam-low = 'FKYL__260411'. APPEND r_ernam.

    SELECT * INTO TABLE @DATA(it_ztcx0001)
      FROM ztcx0001
     WHERE ernam IN @r_ernam
       AND erdat IN @r_erdat.
    DATA: r_zportalno TYPE RANGE OF ztcx0001-zportalno.
    r_zportalno = VALUE #( FOR ls_ztcx0001 IN it_ztcx0001
                     ( sign = 'I'
                       option = 'EQ'
                       low = ls_ztcx0001-zportalno )
                     ).
    SORT r_zportalno. DELETE ADJACENT DUPLICATES FROM r_zportalno.
    SELECT zportalno, erdat
      INTO TABLE @DATA(it_log)
      FROM ztcx0001
     WHERE zportalno IN @r_zportalno
     ORDER BY zportalno, erdat ASCENDING.
    DELETE ADJACENT DUPLICATES FROM it_log COMPARING zportalno.
    SORT it_log BY zportalno.
    LOOP AT it_ztcx0001 ASSIGNING FIELD-SYMBOL(<fs_ztcx0001>).
      READ TABLE it_log INTO DATA(ls_log) WITH KEY zportalno = <fs_ztcx0001>-zportalno
                                          BINARY SEARCH.
      IF sy-subrc = 0.
        <fs_ztcx0001>-erdat = ls_log-erdat.
      ENDIF.
    ENDLOOP.
    IF sy-subrc = 0.
      MODIFY ztcx0001 FROM TABLE it_ztcx0001.
      COMMIT WORK.
    ENDIF.
  ENDIF.
* V012 End off *
* V007 Marked by Tristan 2026/02/13 *
** V005 Added by Tristan 2026/02/24 *
*  DATA: i_date    LIKE p0001-begda,
*        i_days    LIKE t5a4a-dlydy,
*        i_months  LIKE t5a4a-dlymo VALUE 1,
*        i_signum  LIKE t5a4a-split,
*        i_years   LIKE t5a4a-dlyyr,
*        calc_date LIKE p0001-begda.
*  i_date = sy-datum.
*  CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
*    EXPORTING
*      date      = i_date
*      days      = i_days
*      months    = i_months
*      signum    = '-'
*      years     = i_years
*    IMPORTING
*      calc_date = calc_date.
*  s_erdat-low = calc_date(6) && '01'.
*  DATA: day_in LIKE sy-datum.
*  day_in = calc_date.
*  CALL FUNCTION 'RP_LAST_DAY_OF_MONTHS'
*    EXPORTING
*      day_in            = day_in
*    IMPORTING
*      last_day_of_month = s_erdat-high
*    EXCEPTIONS
*      day_in_no_date    = 1
*      OTHERS            = 2.
*  IF sy-subrc <> 0.
** Implement suitable error handling here
*  ENDIF.
*  s_erdat-sign = 'I'. s_erdat-option = 'BT'.
*  APPEND s_erdat. CLEAR s_erdat.
** V005 End off *
* V007 End off *
ENDFORM.
*&---------------------------------------------------------------------*
*& Form reassign_moq_confirm
*&---------------------------------------------------------------------*
FORM reassign_moq_confirm  CHANGING ls_data TYPE zscx0001_alv.
  RANGES: r_lifnr FOR lfa1-lifnr.
  INSERT VALUE #( sign = 'I' option = 'EQ' low = '0000011200' ) INTO TABLE r_lifnr.
  INSERT VALUE #( sign = 'I' option = 'EQ' low = '0000021200' ) INTO TABLE r_lifnr.
* 判斷：父階: (只需判斷父階)
* 採購類型 (MARC-BESKZ) = F and
* 特殊採購 (MARC-SOBSL)= ''
* And
* 預設供應商 (ZDEFAULT_VENDOR) not in ('11200', '21200')
* 代表此筆為供應商備料，則此筆的確認子階需求數量(MOQ_CONFIRM) =0 。
* MOQ_CONFIRM
  DATA(ls_bom) = VALUE #( lt_bom[ idnrk = ls_data-idnrk ] OPTIONAL ).
  CHECK ls_bom IS NOT INITIAL.
  DATA(lv_plevel) = CONV histu( ls_bom-stufe - 1 ).
  IF lv_plevel = 0 OR ls_bom-vwegx = 0.
    DATA(ls_parent) = ls_bom.
* 因為BOM表裡面 如果這個元件是最上階的話不會有父階 所以要拿原始展BOM的那個料當成是父階
    ls_parent-idnrk = ls_data-matnr.
  ELSE.
    ls_parent = VALUE #( lt_bom[ stufe = lv_plevel
                                 wegxx = ls_bom-vwegx ] OPTIONAL ).
  ENDIF.
  DATA(ls_marc) = VALUE #( it_marc[ matnr = ls_parent-idnrk
                                    werks = ls_parent-werks ] OPTIONAL ).
  IF ls_marc IS NOT INITIAL AND ( ls_marc-zdefault_vendor <> '' AND ls_marc-zdefault_vendor NOT IN r_lifnr ).
    ls_data-moq_confirm = ls_data-menge = 0.
    ls_data-mnglg = 0.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form assign_rem_data
*&---------------------------------------------------------------------*
FORM assign_rem_data TABLES lt_step1
                            lt_stpox
                     USING ls_upload TYPE ty_upload.
  DATA: ls_data TYPE zscx0001_alv,
        ls_edit TYPE lvc_s_styl,
        lt_edit TYPE lvc_t_styl.
  DATA lv_found.
  RANGES: r_lifnr FOR lfa1-lifnr.
  INSERT VALUE #( sign = 'I' option = 'EQ' low = '0000011200' ) INTO TABLE r_lifnr.
  INSERT VALUE #( sign = 'I' option = 'EQ' low = '0000021200' ) INTO TABLE r_lifnr.
*  BREAK ct_tristan.
* 20260525 JosephLo 記錄這次上傳「被排除子件」的類型，供「子件全濾掉」時組成品摘要原因
  DATA: lv_has_role TYPE abap_bool,   "有子件因非本角色被排除
        lv_has_rem  TYPE abap_bool.   "有子件因不報MOQ被排除
  CLEAR: lv_has_role, lv_has_rem.
  LOOP AT it_stpox INTO DATA(wa_stpox).
    ls_data-zseq = 1.
    "主要欄位帶入
    ls_data-zportalno = ls_upload-zportalno.
    ls_data-matnr = ls_upload-matnr.
    ls_data-werks = ls_upload-werks.
    ls_data-idnrk = wa_stpox-idnrk.
    ls_data-vtweg = ls_upload-vtweg.
    ls_data-req_date = ls_upload-req_date.
    ls_data-ismoq = 'X'.

*    READ TABLE it_mara INTO DATA(wa_mara) WITH KEY matnr = ls_data-idnrk
*                                                   werks = ls_data-werks
*                                            BINARY SEARCH.
*    IF sy-subrc = 0.
*      READ TABLE it_004a INTO DATA(wa_0014a) WITH KEY matkl = wa_mara-matkl
*                                                      strgr = wa_mara-strgr
*                                             BINARY SEARCH.
*      IF sy-subrc = 0.
*        ls_data-zind01 = wa_0014a-zind01.
*      ENDIF.
*    ENDIF.

    "物料狀態
    SELECT SINGLE * FROM mara
      WHERE matnr = @ls_data-idnrk
      INTO @DATA(wa_mara).
    ls_data-mstae = wa_mara-mstae.

    " 主要圖號 MAINDRAWINGNO   KY V009
*    SELECT SINGLE maindrawingno FROM ztmara
*      WHERE matnr = @ls_data-idnrk
*      INTO @ls_data-maindrawingno.
*    IF sy-subrc <> 0 OR ls_data-maindrawingno IS INITIAL.
*      ls_data-maindrawingno = 'N/A'.
*    ENDIF.
    SELECT SINGLE * FROM ztmara
      WHERE matnr = @ls_data-idnrk
      INTO @DATA(wa_ztmara).
    IF sy-subrc = 0.
      ls_data-maindrawingno = wa_ztmara-maindrawingno.
      ls_data-wl2_thenameoftheerp = wa_ztmara-wl2_thenameoftheerp.
      ls_data-wl2_erpspecification = wa_ztmara-wl2_erpspecification.
      ls_data-wl2_englishspecifications = wa_ztmara-wl2_englishspecifications.
    ENDIF.
    ls_data-maindrawingno = COND #( WHEN ls_data-maindrawingno = '' THEN 'N/A'
                                    ELSE ls_data-maindrawingno ).

    "單位用量 / 子階需求
*    ls_data-mnglg = ls_data-menge.
*    ls_data-menge = ls_data-menge * ls_upload-menge.
    ls_data-mnglg = wa_stpox-menge.
    ls_data-menge = wa_stpox-mnglg / 1000 * ls_upload-menge.
    ls_data-zportalno_qty = ls_upload-menge.

    "Step 2: 理論庫存 (MRP)
    PERFORM get_stock_qty USING ls_data.

    "Step 4: 取 MOQ / 採購類型等
    SELECT SINGLE marc~bstmi AS zmoq,
                   marc~beskz,
                   marc~fevor,
                   t024f~txt,
                   marc~sobsl,
                   marc~plifz,
                   ztmarc~zdefault_vendor
      FROM ztmarc
      INNER JOIN marc
         ON ztmarc~werks = marc~werks
        AND ztmarc~matnr = marc~matnr
      LEFT OUTER JOIN t024f
         ON marc~werks = t024f~werks
        AND marc~fevor = t024f~fevor
      WHERE ztmarc~werks = @ls_data-werks
        AND ztmarc~matnr = @ls_data-idnrk
      INTO ( @ls_data-zmoq,
             @ls_data-beskz,
             @ls_data-fevor,
             @ls_data-txt_fevor,
             @ls_data-sobsl,
             @ls_data-plifz,
             @ls_data-zdefault_vendor ).
*
    SELECT SINGLE name1 INTO ls_data-vendor_name1
      FROM lfa1
     WHERE lifnr = ls_data-zdefault_vendor.

    "詢單號碼 / 單位
    ls_data-zportalno = ls_upload-zportalno.
*    ls_data-meins     = ls_data-meins.
    ls_data-meins     = wa_mara-meins.

    "帳本編號
    READ TABLE gt_custmap INTO DATA(ls_custmap)
         WITH KEY vtweg = ls_data-vtweg
                  werks = ls_data-werks.
    IF sy-subrc = 0.
      ls_data-zseq = ls_custmap-zseq.
    ENDIF.

    "MOQ 確認
    ls_data-moq_confirm = ls_data-menge.

    "權限控制
    READ TABLE gt_role INTO DATA(ls_role) WITH KEY uname = sy-uname.
    IF sy-subrc = 0.
      CLEAR: ls_edit, lt_edit.
      IF ls_role-role = 'A'. "生管
        ls_edit-fieldname = 'REMARK_PP'.
        ls_edit-style     = cl_gui_alv_grid=>mc_style_enabled.
        INSERT ls_edit INTO TABLE lt_edit.
        INSERT LINES OF lt_edit INTO TABLE ls_data-cellstyles.
      ELSEIF ls_role-role = 'C'. "採購
        ls_edit-fieldname = 'REMARK_PUR'.
        ls_edit-style     = cl_gui_alv_grid=>mc_style_enabled.
        INSERT ls_edit INTO TABLE lt_edit.
        INSERT LINES OF lt_edit INTO TABLE ls_data-cellstyles.
      ENDIF.
    ENDIF.

*    "PO / 價格
    ls_data-ebeln = ls_upload-ebeln.
    PERFORM get_default_netprice USING ls_data.
    PERFORM get_sales_price      USING ls_data.
    IF ls_data-zdefault_vendor <> '' AND ls_data-zdefault_vendor NOT IN r_lifnr.
      PERFORM reassign_moq_confirm CHANGING ls_data.
    ENDIF.

* 20260522 JosephLo 修正：不報MOQ記錄(pt_data)也要依角色卡控採購類型 Start
*   背景：本迴圈處理 it_stpox(= explode_bom 結尾「DELETE it_stpox WHERE loekz <> 'M'」
*         留下、被標 loekz='M' 而排除的子件)，把它們補成「不報MOQ(ISMOQ='X')」記錄
*         塞進全域 pt_data。it_stpox 同時含「nomoq 規則排除」與「角色過濾排除」兩種；
*         原碼只設可編輯欄樣式(REMARK_PP/REMARK_PUR)、並未依角色排除，於是被角色濾掉
*         的件(對採購C 而言即 BESKZ=E)也被塞進 pt_data。
*   流向：pt_data 不進上傳 ALV(主程式「APPEND LINES OF pt_data TO gt_data」那行已註解)，
*         但 save_data 會把 pt_data 寫入 ztcx0001、並於顯示/報表模式呈現
*         → 等於採購C 的存檔/顯示資料仍混入 E 件。
*   對策：比照 explode_bom 角色過濾(PATCH 2) 與 Block 2 自身列守門 ──
*         生管A 只留 BESKZ=E；採購C/當地採購D 只留 BESKZ=F 且 SOBSL '' 或 '30'；
*         其餘角色維持原行為(不過濾)。不符者不寫入 pt_data。
*   備註1：對採購C，被角色排除的件必為非F(不會是F)，故此守門只擋掉「角色排除」的件，
*          不影響「nomoq 規則排除的 F 件」仍正常保留為不報MOQ記錄。
*   備註2：僅在 ZTGCX0001 / SE38 才依角色過濾(與 explode_bom 同一個 sy-tcode 閘門)；
*          ZTGCX0001A 不過濾。(實務上 ZTGCX0001A 在 explode_bom 未標 loekz='M'，
*          it_stpox 為空、本迴圈不會執行；此閘門為一致性與防呆。)
    DATA(lv_rem_role_ok) = abap_true.
* V025 JosephLo 2026/06/01 改讀 gs_mode-do_filter(原 sy-tcode 角色閘門)
    IF gs_mode-do_filter = 'X'.
      CASE ls_role-role.
        WHEN 'A'.            "生管：只確認採購類型 E
          IF ls_data-beskz <> 'E'.
            lv_rem_role_ok = abap_false.
          ENDIF.
        WHEN 'C' OR 'D'.     "採購 / 當地採購：只確認 F、F-30
          IF NOT ( ls_data-beskz = 'F'
               AND ( ls_data-sobsl = '' OR ls_data-sobsl = '30' ) ).
            lv_rem_role_ok = abap_false.
          ENDIF.
      ENDCASE.
    ENDIF.
* 20260524 JosephLo 上階料號：比照 reassign_parent_idnrk 的 stufe-1 推導法找「直接上階」。
*   查 typed 全域 lt_bom(完整BOM樹)；不可用 untyped 的 TABLES 參數 lt_stpox(無結構、取不到 -idnrk)。
*   找不到父階(最上階子件、直掛成品下)時，上階即上傳成品料號。
    DATA(lv_plevel) = CONV histu( wa_stpox-stufe - 1 ).
    DATA lv_parent TYPE matnr.
    IF lv_plevel = 0 OR wa_stpox-vwegx = 0.
      lv_parent = ls_upload-matnr.
    ELSE.
      lv_parent = VALUE #( lt_bom[ stufe = lv_plevel
                                   wegxx = wa_stpox-vwegx ]-idnrk OPTIONAL ).
    ENDIF.
    IF lv_rem_role_ok = abap_true.
      lv_has_rem = abap_true.            "20260525 子件因不報MOQ被排除(供成品摘要)
      APPEND ls_data TO pt_data.
* 20260524 JosephLo 統一異常顯示重構：出口3 被標m子件、角色符合＝不報moq規則命中(隨存檔寫db ismoq=x)
      APPEND VALUE #( sort_seq  = '07'  category = '不報MOQ'
                      matnr_fg  = ls_upload-matnr  idnrk = wa_stpox-idnrk
                      parent    = lv_parent
                      beskz     = ls_data-beskz    sobsl = ls_data-sobsl
                      lifnr     = ls_data-zdefault_vendor
                      mnglg     = ls_data-mnglg    menge = ls_data-menge
                      vtweg     = ls_upload-vtweg  werks = ls_upload-werks
                      zportalno = ls_upload-zportalno
                      reason    = '子件不報MOQ(隨存檔寫入 ISMOQ=X)' ) TO gt_excluded.
    ELSE.
      lv_has_role = abap_true.           "20260525 子件因非本角色被排除(供成品摘要)
* 20260524 JosephLo 統一異常顯示重構：出口4 被標M子件、角色不符＝非本角色(不寫pt_data/DB)；收集供顯示
      APPEND VALUE #( sort_seq  = '08'  category = '非本角色'
                      matnr_fg  = ls_upload-matnr  idnrk = wa_stpox-idnrk
                      parent    = lv_parent
                      beskz     = ls_data-beskz    sobsl = ls_data-sobsl
                      lifnr     = ls_data-zdefault_vendor
                      mnglg     = ls_data-mnglg    menge = ls_data-menge
                      vtweg     = ls_upload-vtweg  werks = ls_upload-werks
                      zportalno = ls_upload-zportalno
                      reason    = |非本角色(採購類型 { ls_data-beskz }，不在你的清單)| ) TO gt_excluded.
    ENDIF.
    CLEAR ls_data.
* 20260522 JosephLo 修正：不報MOQ記錄(pt_data)也要依角色卡控採購類型 End
  ENDLOOP.
* 沒有BOM也要塞一筆資料
* 20260518 Ky add ZTGCX0001A 出現客戶型號不存在

* 20260525 JosephLo 區分「真無BOM(it_stpox 也空)」vs「有BOM但子件全被濾掉(it_stpox 非空)」：
*   前者才查客戶型號/組自身項；後者(全濾掉)由下方 ELSE 把成品本身摘要一筆(子件已逐筆列在上方)。
  IF lines( lt_stpox ) = 0.
    IF lines( it_stpox ) = 0.
*  IF sy-subrc <> 0.
      CLEAR ls_data.
      SELECT SINGLE zcn INTO @DATA(lv_skuitem)
        FROM ztsd0020
      WHERE vtweg = @ls_upload-vtweg
        AND matnr = @ls_upload-matnr
        AND ztype = '2'.
      IF sy-subrc <> 0.
* V020 JosephLo 2026/05/22 不跳訊息/不中斷，記錄到 global 清單，交易(Save/QQ)時才檢查
        IF NOT line_exists( gt_sku_err[ matnr = ls_upload-matnr vtweg = ls_upload-vtweg ] ).
          APPEND VALUE #( matnr = ls_upload-matnr vtweg = ls_upload-vtweg ) TO gt_sku_err.
* 20260524 JosephLo 統一異常訊息顯示重構：出口5 無客戶型號 → 同步收集 gt_excluded 供進alv前 popup
          APPEND VALUE #( sort_seq  = '97'
                          category  = '無客戶型號'
                          matnr_fg  = ls_upload-matnr
                          idnrk     = ls_upload-matnr
                          vtweg     = ls_upload-vtweg
                          werks     = ls_upload-werks
                          zportalno = ls_upload-zportalno
                          reason    = '此件無BOM、又查無客戶型號，無法報MOQ，請洽業務維護 ZTSD0020(ZTYPE=2)' ) TO gt_excluded.
        ENDIF.
      ELSE.
* 20260525 JosephLo ★自身項(self-item)：只用於「真正無bom的單層市購件」——
*   外層已用 it_stpox=0 把關(確定完全沒有展開子件)，且本件有客戶型號(ZTSD0020)。
*   此時讓「上傳料號本身」當一列報MOQ(idnrk = ls_upload-matnr = 成品本身)。
*   ⚠ 絕不可套用在「有BOM但子件被角色/不報MOQ濾光」的成品——那種走外層 ELSE 的「無可報子件」
*     成品摘要，不會自身報MOQ；自身項與有BOM件務必分清楚，不要混用。
        ls_data-zseq = 1.
        ls_data-zportalno = ls_upload-zportalno.
        ls_data-matnr = ls_upload-matnr.
        ls_data-werks = ls_upload-werks.
        ls_data-vtweg = ls_upload-vtweg.
        ls_data-req_date = ls_upload-req_date.
        ls_data-idnrk = ls_upload-matnr. "自身項：料號=上傳料號本身(非子件)
        ls_data-skuitem = lv_skuitem.
* 沒有BOM也要長一筆 但是 不報MOQ不能給值 不然畫面顯示不出來
*      ls_data-ismoq = 'X'.

*    READ TABLE it_mara INTO DATA(wa_mara) WITH KEY matnr = ls_data-idnrk
*                                                   werks = ls_data-werks
*                                            BINARY SEARCH.
*    IF sy-subrc = 0.
*      READ TABLE it_004a INTO DATA(wa_0014a) WITH KEY matkl = wa_mara-matkl
*                                                      strgr = wa_mara-strgr
*                                             BINARY SEARCH.
*      IF sy-subrc = 0.
*        ls_data-zind01 = wa_0014a-zind01.
*      ENDIF.
*    ENDIF.
*
*      DATA(lv_nomoq) = VALUE #( gt_nomoq[] OPTIONAL ).
        PERFORM check_nomoq_rule USING ls_data CHANGING lv_found.
        IF lv_found = 'X'.
* 20260524 JosephLo 統一異常訊息顯示重構：無bom件命中不報moq
*   原為 MESSAGE+LEAVE 整批中斷 → 改收集到 gt_excluded(不中斷)；不建 lt_step1 故維持不寫DB
          APPEND VALUE #( sort_seq  = '07'
                          category  = '不報MOQ'
                          matnr_fg  = ls_upload-matnr
                          idnrk     = ls_upload-matnr
                          vtweg     = ls_upload-vtweg
                          werks     = ls_upload-werks
                          zportalno = ls_upload-zportalno
                         reason    = '大貨件號本身不報MOQ(展不出可報子件、不寫入DB)' ) TO gt_excluded.
          RETURN.
        ENDIF.

        "物料狀態
        SELECT SINGLE * FROM mara
          WHERE matnr = @ls_data-idnrk
          INTO @wa_mara.
        ls_data-mstae = wa_mara-mstae.

        " 主要圖號 MAINDRAWINGNO   KY V009
*      SELECT SINGLE  maindrawingno FROM ztmara
*        WHERE matnr = @ls_data-idnrk
*        INTO @ls_data-maindrawingno.
*      IF sy-subrc <> 0 OR ls_data-maindrawingno IS INITIAL.
*        ls_data-maindrawingno = 'N/A'.
*      ENDIF.
        SELECT SINGLE * FROM ztmara
          WHERE matnr = @ls_data-idnrk
          INTO @wa_ztmara.
        IF sy-subrc = 0.
          ls_data-maindrawingno = wa_ztmara-maindrawingno.
          ls_data-wl2_thenameoftheerp = wa_ztmara-wl2_thenameoftheerp.
          ls_data-wl2_erpspecification = wa_ztmara-wl2_erpspecification.
          ls_data-wl2_englishspecifications = wa_ztmara-wl2_englishspecifications.
        ENDIF.
        ls_data-maindrawingno = COND #( WHEN ls_data-maindrawingno = '' THEN 'N/A'
                                        ELSE ls_data-maindrawingno ).
        "單位用量 / 子階需求
*      ls_data-mnglg = ls_data-menge.
*      ls_data-menge = ls_data-menge * ls_upload-menge.
*      ls_data-mnglg = ls_upload-menge.
        ls_data-mnglg = 1.
        ls_data-menge = ls_upload-menge.
        ls_data-zportalno_qty = ls_upload-menge.

        "Step 2: 理論庫存 (MRP)
        PERFORM get_stock_qty USING ls_data.

        "Step 4: 取 MOQ / 採購類型等
        SELECT SINGLE marc~bstmi AS zmoq,
                       marc~beskz,
                       marc~fevor,
                       t024f~txt,
                       marc~sobsl,
                       marc~plifz,
                       ztmarc~zdefault_vendor
          FROM ztmarc
          INNER JOIN marc
             ON ztmarc~werks = marc~werks
            AND ztmarc~matnr = marc~matnr
          LEFT OUTER JOIN t024f
             ON marc~werks = t024f~werks
            AND marc~fevor = t024f~fevor
          WHERE ztmarc~werks = @ls_data-werks
            AND ztmarc~matnr = @ls_data-idnrk
          INTO ( @ls_data-zmoq,
                 @ls_data-beskz,
                 @ls_data-fevor,
                 @ls_data-txt_fevor,
                 @ls_data-sobsl,
                 @ls_data-plifz,
                 @ls_data-zdefault_vendor ).

        SELECT SINGLE name1 INTO ls_data-vendor_name1
          FROM lfa1
         WHERE lifnr = ls_data-zdefault_vendor.

        "詢單號碼 / 單位
        ls_data-zportalno = ls_upload-zportalno.
*      ls_data-meins     = ls_data-meins.
        ls_data-meins     = wa_mara-meins.

        "帳本編號
        READ TABLE gt_custmap INTO ls_custmap
             WITH KEY vtweg = ls_data-vtweg
                      werks = ls_data-werks.
        IF sy-subrc = 0.
          ls_data-zseq = ls_custmap-zseq.
        ENDIF.

        "MOQ 確認
        ls_data-moq_confirm = ls_data-menge.

        "權限控制
        READ TABLE gt_role INTO ls_role WITH KEY uname = sy-uname.
        IF sy-subrc = 0.
          CLEAR: ls_edit, lt_edit.
          IF ls_role-role = 'A'. "生管
            ls_edit-fieldname = 'REMARK_PP'.
            ls_edit-style     = cl_gui_alv_grid=>mc_style_enabled.
            INSERT ls_edit INTO TABLE lt_edit.
            INSERT LINES OF lt_edit INTO TABLE ls_data-cellstyles.
          ELSEIF ls_role-role = 'C'. "採購
            ls_edit-fieldname = 'REMARK_PUR'.
            ls_edit-style     = cl_gui_alv_grid=>mc_style_enabled.
            INSERT ls_edit INTO TABLE lt_edit.
            INSERT LINES OF lt_edit INTO TABLE ls_data-cellstyles.
          ENDIF.
        ENDIF.

*    "PO / 價格
        ls_data-ebeln = ls_upload-ebeln.
        PERFORM get_default_netprice USING ls_data.
        PERFORM get_sales_price      USING ls_data.
        IF ls_data-zdefault_vendor <> '' AND ls_data-zdefault_vendor NOT IN r_lifnr.
          PERFORM reassign_moq_confirm CHANGING ls_data.
        ENDIF.
* 20260522 JosephLo 修正：採購(C)會看到採購類型E件(例 AS014-001055) Start
*   背景：本段「沒有BOM也要塞一筆資料」(此 IF lines(lt_stpox)=0；20260518 Ky 為
*         ZTGCX0001A 客戶型號檢核而加) 會在「展不出可報子件」時，把『上傳件本身』
*         補成一列(matnr=idnrk=上傳料號、單位用量=1)。但原碼僅設定可編輯欄位樣式
*         (REMARK_PP/REMARK_PUR)，並未依角色做採購類型過濾，導致 BESKZ 與角色不符者
*         也被塞進報表(現象：角色C 採購卻看到 BESKZ=E 的成品 AS014-001055)。
*   對策：自身列比照 explode_bom 角色過濾(PATCH 2)── 生管A 只留 E；採購C/當地採購D
*         只留 F 與 F-30；其餘角色維持原行為(不過濾)。不符者不 APPEND。
*   ⚠ 僅在 ZTGCX0001 / SE38 才依角色過濾(與 explode_bom PATCH 2 同一個 sy-tcode 閘門)；
*      ZTGCX0001A(整機買賣 / 不展 BOM)不過濾、全部顯示 —— 本段原本就是為 ZTGCX0001A 而加。
        DATA(lv_self_role_ok) = abap_true.
* V025 JosephLo 2026/06/01 改讀 gs_mode-do_filter(原 sy-tcode 角色閘門)
        IF gs_mode-do_filter = 'X'.
          CASE ls_role-role.
            WHEN 'A'.            "生管：只確認採購類型 E
              IF ls_data-beskz <> 'E'.
                lv_self_role_ok = abap_false.
              ENDIF.
            WHEN 'C' OR 'D'.     "採購 / 當地採購：只確認 F、F-30
              IF NOT ( ls_data-beskz = 'F'
                   AND ( ls_data-sobsl = '' OR ls_data-sobsl = '30' ) ).
                lv_self_role_ok = abap_false.
              ENDIF.
          ENDCASE.
        ENDIF.
        IF lv_self_role_ok = abap_true.
*       自身項進主alv → calc_moq 報moq → 可勾選/確認qq/存db(僅限真無bom單層市購件，見上方★說明)
          APPEND ls_data TO lt_step1.
        ELSE.
* 20260524 JosephLo 統一異常顯示重構：出口7 無BOM有客戶型號自身項、角色不符＝非本角色(不進主ALV)；收集供顯示
          APPEND VALUE #( sort_seq  = '08'  category = '非本角色'
                          matnr_fg  = ls_upload-matnr  idnrk = ls_upload-matnr
                          beskz     = ls_data-beskz    sobsl = ls_data-sobsl
                          lifnr     = ls_data-zdefault_vendor
                          mnglg     = ls_data-mnglg    menge = ls_data-menge
                          vtweg     = ls_upload-vtweg  werks = ls_upload-werks
                          zportalno = ls_upload-zportalno
                          reason    = |非本角色(採購類型 { ls_data-beskz }，不在你的清單)| ) TO gt_excluded.

        ENDIF.
        CLEAR ls_data.
* 20260522 JosephLo 修正：採購(C)會看到採購類型E件(例 AS014-001055) End
      ENDIF.
* 20260525 JosephLo 全濾掉分支(lt_stpox 空但 it_stpox 非空)：成品(上傳料號)本身摘要一筆入清單；
*   各子件明細已於上方 it_stpox 迴圈逐筆收集(非本角色/不報MOQ)。原因依 lv_has_role/lv_has_rem 區分。
    ELSE.
      DATA lv_excl_detail TYPE string.
      IF lv_has_role = abap_true AND lv_has_rem = abap_true.
        lv_excl_detail = '非本角色＋不報MOQ'.
      ELSEIF lv_has_role = abap_true.
        lv_excl_detail = '非本角色'.
      ELSE.
        lv_excl_detail = '不報MOQ'.
      ENDIF.
      APPEND VALUE #( sort_seq  = '09'  category = '無可報子件'
                      matnr_fg  = ls_upload-matnr  idnrk = ls_upload-matnr
                      vtweg     = ls_upload-vtweg  werks = ls_upload-werks
                      zportalno = ls_upload-zportalno
                      reason    = |此件可展BOM但子件全部未進報表（{ lv_excl_detail }），詳見下方各子件| ) TO gt_excluded.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form reassign_parent_idnrk
*&---------------------------------------------------------------------*
FORM reassign_parent_idnrk  TABLES tmp_bom STRUCTURE ztcx0001_bom
                            USING ls_upload TYPE ty_upload
                                  ls_topmat TYPE cstmat.
*  BREAK ct_tristan.
  DATA wa_bom TYPE ztcx0001_bom.
  LOOP AT lt_bom INTO DATA(ls_bom).
    CLEAR wa_bom.
    wa_bom = CORRESPONDING #( ls_bom ).
    wa_bom-vtweg = ls_upload-vtweg.
    wa_bom-zportalno = ls_upload-zportalno.

    DATA(lv_plevel) = CONV histu( ls_bom-stufe - 1 ).
    IF lv_plevel = 0 OR ls_bom-vwegx = 0.
      DATA(ls_parent) = ls_bom.
    ELSE.
      ls_parent = VALUE #( lt_bom[ stufe = lv_plevel
                                   wegxx = ls_bom-vwegx ] OPTIONAL ).
    ENDIF.
    DATA(ls_marc) = VALUE #( it_marc[ matnr = ls_parent-idnrk
                                      werks = ls_parent-werks ] OPTIONAL ).
    IF ls_marc IS NOT INITIAL.
      wa_bom-menge = 0.
    ENDIF.
    wa_bom-matnr = COND #( WHEN ls_parent-idnrk <> '' THEN ls_parent-idnrk
                           ELSE wa_bom-matnr ).
    wa_bom-matnr = COND #( WHEN wa_bom-matnr = wa_bom-idnrk THEN ls_upload-matnr
                           ELSE wa_bom-matnr ).
    wa_bom-bmeng = ls_topmat-bmeng.
    wa_bom-ernam = sy-uname.
    wa_bom-erdat = sy-datum.
    APPEND wa_bom TO tmp_bom.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form check_nomoq_rule
*&---------------------------------------------------------------------*
FORM check_nomoq_rule USING ls_data TYPE zscx0001_alv CHANGING lv_found.
  CLEAR lv_found.
  SELECT SINGLE matkl INTO @DATA(lv_matkl)
    FROM mara
   WHERE matnr = @ls_data-matnr.
  SELECT SINGLE marc~matnr,beskz,sobsl,makt~maktx
    FROM marc INNER JOIN makt
      ON makt~matnr = marc~matnr
     AND makt~spras = @sy-langu
  WHERE werks = @ls_data-werks
    AND marc~matnr = @ls_data-idnrk
   INTO @DATA(ls_marc).
  IF sy-subrc = 0.
    "不報 MOQ 的檢查
* V025 JosephLo 2026/06/01 改讀 gs_mode-do_filter
    IF gs_mode-do_filter = 'X'.
      DATA:lr_meins TYPE RANGE OF mara-meins,
           lr_maktx TYPE RANGE OF makt-maktx.
      SORT gt_nomoq BY maktx DESCENDING matkl DESCENDING meins DESCENDING sobsl DESCENDING beskz DESCENDING .
* LS_STPOX-MATKL不是IDNRK的MATKL要用MATMK這個才對
      LOOP AT gt_nomoq INTO DATA(ls_q1) WHERE matkl = lv_matkl
                                          AND beskz = ls_marc-beskz
                                          AND sobsl = ls_marc-sobsl.
        CLEAR:lr_meins,lr_maktx.

        APPEND INITIAL LINE TO lr_meins ASSIGNING FIELD-SYMBOL(<r1>).
        APPEND INITIAL LINE TO lr_maktx ASSIGNING FIELD-SYMBOL(<r2>).

        IF ls_q1-meins IS NOT INITIAL.
          <r1>-sign = 'I'.
          <r1>-option = 'EQ'.
          <r1>-low = ls_q1-meins.
        ELSE.
          <r1>-sign = 'I'.
          <r1>-option = 'CP'.
          <r1>-low = '*'.
        ENDIF.
        IF ls_q1-maktx IS NOT INITIAL.
          <r2>-sign = 'I'.
          <r2>-option = 'CP'.
          <r2>-low = |*{ ls_q1-maktx }*|.
        ELSE.
          <r2>-sign = 'I'.
          <r2>-option = 'CP'.
          <r2>-low = '*'.
        ENDIF.

        IF ls_data-meins IN lr_meins AND ls_marc-maktx IN lr_maktx.
          IF ls_q1-ismoq = 'X'.
            lv_found = 'X'.
          ELSE.
            lv_found = ''.
          ENDIF.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form is_check_bypassed
*&   20260526 JosephLo 集中管理「特定 t-code 對特定異常檢查放行」的規則。
*&   要新增放行只在這支 FORM 的 CASE 加分支，不用散到各檢查點。
*&   exc_id 規格(全大寫，新增時請補進這份清單與下方 CASE):
*&     'FILE_DUP'  — check_upload_data 檔案內重複(同 vtweg+matnr+werks+zportalno ≥2筆)
*&   用法:
*&     DATA lv_bp TYPE abap_bool.
*&     PERFORM is_check_bypassed USING '<exc_id>' CHANGING lv_bp.
*&     IF lv_bp = abap_false.  " 未放行 → 跑該檢查
*&       ...
*&     ENDIF.
*&---------------------------------------------------------------------*
FORM is_check_bypassed USING    p_exc_id    TYPE string
                       CHANGING rv_bypassed TYPE abap_bool.
  CLEAR rv_bypassed.
* V025 JosephLo 2026/06/01 改讀 gs_mode-relax_check(放寬檢查模式);放行清單照舊,日後加 p_exc_id 即可
  IF gs_mode-relax_check = 'X'.
    IF p_exc_id = 'FILE_DUP'.
      rv_bypassed = abap_true.
    ENDIF.
  ENDIF.
ENDFORM.