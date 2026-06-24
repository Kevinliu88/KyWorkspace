REPORT ztwrbc0004  MESSAGE-ID  zmail.
*&-----------------------------------------------------------------------------*
*& Report  Authorizatiions                                                     *
*------------------------------------------------------------------------------*
* Author      : Three                                                          *
* Date        : 2020/05/28                                                     *
********************************************************************************
* MODIFICATIONS HISTORY :                                                      *
********************************************************************************
* CHANGE DATE VERSION MODIFIER DESCRIPTION
* =========== ======= ======== =================================================
* 2020/08/17  V001    Three    Add select option: T-code base
********************************************************************************
INCLUDE ztwibc0004.
INCLUDE ztwibc0005.
INCLUDE ztwrbc0004_top.
* ---------------------------------------------------------------------------- *
* SELECTION SCREEN
* ---------------------------------------------------------------------------- *
SELECTION-SCREEN: FUNCTION KEY 1, FUNCTION KEY 2.
SELECT-OPTIONS: s_role    FOR agr_define-agr_name  OBLIGATORY.
SELECT-OPTIONS: s_object  FOR agr_1251-object      NO-DISPLAY.
SELECT-OPTIONS: s_tcode   FOR agr_tcodes-tcode     OBLIGATORY.
SELECTION-SCREEN SKIP.
SELECTION-SCREEN COMMENT /1(80) text-s01.
PARAMETERS:     p_days    TYPE oij_def_past         OBLIGATORY  DEFAULT '30'.
SELECT-OPTIONS: s_ernam   FOR zttcode_log-ernam.
SELECTION-SCREEN SKIP.
PARAMETERS:     p_robase  RADIOBUTTON GROUP gr1.
PARAMETERS:     p_tcbase  RADIOBUTTON GROUP gr1.
PARAMETERS:     p_check   AS CHECKBOX.
* ------------------------------------------------------------- *
* Events
* ------------------------------------------------------------- *
INITIALIZATION.
  PERFORM push_button.
  MOVE 'EEQDATALOAD' TO s_ernam. APPEND s_ernam.
  MOVE 'ECPFF*'      TO s_ernam. APPEND s_ernam.
  s_role-sign = 'I'. s_role-option = 'CP'.
  s_role-low = 'Z*'. APPEND s_role.
  s_tcode-sign = 'I'. s_tcode-option = 'CP'.
  s_tcode-low = '*'. APPEND s_tcode.

AT SELECTION-SCREEN.
  CASE sscrfields-ucomm .
    WHEN 'FC01'.
      PERFORM view_maintain  USING 'ZTBC_AGR'.
    WHEN 'FC02'.
      PERFORM view_maintain  USING 'ZTBC_AGR_TCODE'.
  ENDCASE.

START-OF-SELECTION.
  PERFORM check_input.
  PERFORM prepare_data.
  PERFORM process_data.
  PERFORM display_alv.
  PERFORM process_tbase.
*&---------------------------------------------------------------------*
*&      Form  CHECK_INPUT
*&---------------------------------------------------------------------*
FORM check_input .
  IF p_days > 365.
    MESSAGE i000 WITH 'The [Default past days] cannot exceed 365 days.'.
    STOP.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PREPARE_DATA
*&---------------------------------------------------------------------*
FORM prepare_data .
  PERFORM get_agr_define  TABLES s_role.
  CHECK it_agr[] IS NOT INITIAL.
  CONCATENATE 'IEQ' 'S_TCODE' INTO s_object.  APPEND s_object.  CLEAR s_object.
  PERFORM get_agr_1251    TABLES s_role s_object.
  PERFORM get_agr_tcodes  TABLES s_role s_tcode.
  PERFORM combine_object.
  PERFORM get_tstc.
  PERFORM get_ztcode_log.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_AGR_TCODES
*&---------------------------------------------------------------------*
FORM get_agr_tcodes  TABLES pt_role pt_tcode.
  REFRESH it_tcode.  CLEAR it_tcode.
*
  SELECT *
    INTO TABLE it_tcode
    FROM  agr_tcodes
    WHERE agr_name IN pt_role
      AND tcode    IN pt_tcode
      AND type      = 'TR'.
  SORT it_tcode BY agr_name tcode.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  COMBINE_OBJECT
*&---------------------------------------------------------------------*
FORM combine_object .
  CONSTANTS: gc_color_lov(4)  TYPE c VALUE 'C710'.   "Collor Orange

  REFRESH: it_agr_tc, it_tstct.  CLEAR: it_agr_tc, it_tstct.
  LOOP AT it_agr.
    MOVE-CORRESPONDING it_agr  TO it_agr_tc.
    LOOP AT it_1251 WHERE agr_name = it_agr-agr_name.
      CLEAR: it_agr_tc-tctxt.
      it_agr_tc-modified = it_1251-modified.
      REFRESH: ir_tcode, it_tstc.  CLEAR: ir_tcode, it_tstc.
      IF it_1251-low <> space AND it_1251-high <> space.
        ir_tcode-sign   = 'I'.
        ir_tcode-option = 'BT'.
        ir_tcode-low    = it_1251-low.
        ir_tcode-high   = it_1251-high.
      ELSE.
        FIND '*' IN it_1251-low.
        IF sy-subrc = 0.
          IF it_1251-low = '*'.
            MOVE it_1251-low TO it_agr_tc-tcode.
            it_agr_tc-tctxt = 'Cannot search tcode = * '.
            it_agr_tc-check = '異常'.
            it_agr_tc-color_r = gc_color_lov.
            APPEND it_agr_tc.
            CLEAR: it_agr_tc-color_r, it_agr_tc-check.
          ELSE.
            IF sy-subrc = 0.
              CONCATENATE 'ICP' it_1251-low INTO ir_tcode.
            ENDIF.
          ENDIF.
        ELSE.
          CONCATENATE 'IEQ' it_1251-low INTO ir_tcode.
        ENDIF.
      ENDIF.
      IF ir_tcode-low <> space.
        APPEND ir_tcode.  CLEAR ir_tcode.
      ENDIF.
      IF ir_tcode[] IS NOT INITIAL.
        SELECT *
          INTO TABLE it_tstc
          FROM tstc
          WHERE tcode IN ir_tcode.
        IF it_tstc[] IS NOT INITIAL.
          SORT it_tstc BY tcode.
          LOOP AT it_tstc.
            MOVE-CORRESPONDING it_tstc  TO it_agr_tc.
            APPEND it_agr_tc.
            it_tstct-tcode = it_tstc-tcode.
            APPEND it_tstct.  CLEAR it_tstct.
          ENDLOOP.
        ELSE.
          LOOP AT ir_tcode.
            MOVE ir_tcode TO it_agr_tc-tcode.
            it_agr_tc-tctxt = 'T-code is not exist!'.
            it_agr_tc-check = '異常'.
            it_agr_tc-color_r = gc_color_lov.
            APPEND it_agr_tc.
            CLEAR: it_agr_tc-color_r, it_agr_tc-check.
          ENDLOOP.
        ENDIF.
      ENDIF.
    ENDLOOP.
    CLEAR: it_agr, it_agr_tc.
  ENDLOOP.
*
  IF s_tcode[] IS NOT INITIAL.
    DELETE it_agr_tc WHERE tcode NOT IN s_tcode.
  ENDIF.
*
  LOOP AT it_agr.
    MOVE-CORRESPONDING it_agr  TO it_agr_tc.
    LOOP AT it_tcode WHERE agr_name = it_agr-agr_name.
      READ TABLE it_agr_tc WITH KEY agr_name = it_tcode-agr_name
                                    tcode    = it_tcode-tcode.
      IF sy-subrc = 0.
        LOOP AT it_agr_tc WHERE agr_name = it_agr-agr_name
                            AND tcode    = it_tcode-tcode.
          it_agr_tc-menu  = 'V'.
          MODIFY it_agr_tc INDEX sy-tabix.  CLEAR it_agr_tc.
        ENDLOOP.
      ELSE.
        it_agr_tc-agr_name = it_agr-agr_name.
        it_agr_tc-text     = it_agr-text.
        it_agr_tc-tcode    = it_tcode-tcode.
        it_agr_tc-menu     = 'V'.
        APPEND it_agr_tc.  CLEAR it_agr_tc.
        it_tstct-tcode     = it_tcode-tcode.
        APPEND it_tstct.  CLEAR it_tstct.
      ENDIF.
    ENDLOOP.
    CLEAR: it_agr.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_TSTC
*&---------------------------------------------------------------------*
FORM get_tstc .
  DATA: lt_tstct      LIKE tstct     OCCURS 0  WITH HEADER LINE.
  DATA: w_tabix       LIKE sy-tabix.

  SORT it_tstct BY tcode.
  DELETE ADJACENT DUPLICATES FROM it_tstct COMPARING tcode.
  CHECK it_tstct[] IS NOT INITIAL.

  lt_tstct[] = it_tstct[].
  REFRESH it_tstct.  CLEAR it_tstct.

  SELECT *
    INTO TABLE it_tstct
    FROM tstct
     FOR ALL ENTRIES IN lt_tstct
    WHERE tcode = lt_tstct-tcode
      AND sprsl = 'E'.
  SORT it_tstct BY tcode.

  LOOP AT lt_tstct.
    READ TABLE it_tstct WITH KEY tcode = lt_tstct-tcode.
    IF sy-subrc = 0 AND it_tstct-ttext = space.
      PERFORM get_tstct  USING 'M' it_tstct-tcode
                      CHANGING it_tstct-ttext.
      IF it_tstct-ttext <> space.
        it_tstct-sprsl = 'M'.
        MODIFY it_tstct INDEX sy-tabix.  CLEAR it_tstct.
      ENDIF.
    ELSEIF sy-subrc <> 0.
      it_tstct-tcode = lt_tstct-tcode.
      PERFORM get_tstct  USING 'M' lt_tstct-tcode
                      CHANGING it_tstct-ttext.
      IF it_tstct-ttext <> space.
        it_tstct-sprsl = 'M'.
      ELSE.
        it_tstct-sprsl = ''.
      ENDIF.
      APPEND it_tstct.  CLEAR it_tstct.
    ENDIF.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_ZTCODE_LOG
*&---------------------------------------------------------------------*
FORM get_ztcode_log .
  DATA: l_days        TYPE i.

  CHECK it_tstct[] IS NOT INITIAL.
  IF p_days = 0.
    p_days = 1.
  ENDIF.
  l_days = p_days * -1.

  CALL FUNCTION 'BKK_ADD_WORKINGDAY'
    EXPORTING
      i_date = sy-datum
      i_days = l_days
*     I_CALENDAR1       =
*     I_CALENDAR2       =
    IMPORTING
      e_date = g_erdat
*     E_RETURN          =
    .

  REFRESH: it_zlog, it_tlog.  CLEAR: it_zlog, it_tlog.
  SELECT *
    INTO TABLE it_zlog
    FROM zttcode_log
    FOR ALL ENTRIES IN it_tstct
    WHERE erdat BETWEEN g_erdat AND sy-datum
      AND tcode = it_tstct-tcode
      AND ernam IN s_ernam.
  SORT it_zlog BY tcode erdat DESCENDING.

  LOOP AT it_tstct.
    MOVE-CORRESPONDING it_tstct  TO it_tlog.
    READ TABLE it_zlog WITH KEY tcode = it_tstct-tcode.
    IF sy-subrc = 0.
      it_tlog-erdat = it_zlog-erdat.
      it_tlog-ernam = it_zlog-ernam.
    ENDIF.
    APPEND it_tlog.  CLEAR: it_tlog, it_zlog.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PROCESS_DATA
*&---------------------------------------------------------------------*
FORM process_data .
  DATA: w_tabix    LIKE sy-tabix.

  LOOP AT it_agr_tc  INTO is_agr_tc.
    w_tabix = sy-tabix.
    READ TABLE it_tlog WITH KEY tcode = is_agr_tc-tcode.
    IF sy-subrc = 0.
      is_agr_tc-tctxt = it_tlog-ttext.
      is_agr_tc-erdat = it_tlog-erdat.
      is_agr_tc-ernam = it_tlog-ernam.
      MODIFY it_agr_tc FROM is_agr_tc INDEX w_tabix.
    ENDIF.
  ENDLOOP.
  SORT it_agr_tc BY agr_name tcode modified.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PROCESS_TBASE
*&---------------------------------------------------------------------*
FORM process_tbase .
*V001 Addeded by Three 2020/08/17
  DATA: l_agr_name(32)    TYPE c.
  DATA: l_tabix           LIKE sy-tabix.
  FIELD-SYMBOLS: <itfcct> TYPE slis_fieldcat_alv.
  DATA: ls_dyn_fcat       TYPE lvc_s_fcat.
  DATA: lt_dyn_fcat       TYPE lvc_t_fcat.
  DATA: lt_dyn_table      TYPE REF TO data.

  FIELD-SYMBOLS: <itdata> TYPE table.
  FIELD-SYMBOLS: <w_line_fs>, <w_fs1>, <w_fs2>, <w_fs3>.
  DATA: w_line            TYPE REF TO data.
* config data
  CHECK p_tcbase = 'X'.
  IF p_check = 'X'.
    PERFORM get_ztbc_agr        TABLES s_role.
    PERFORM get_ztbc_agr_tcode  TABLES s_tcode.
  ENDIF.
* fields_build
  fieldcatset i_pos 'TCODE'    ' '     'TSTCT'       ''               20 'X'.
  fieldcatset i_pos 'TTEXT'    'TTEXT' 'TSTCT'       'Text'           '' ' '.
  IF p_check = 'X'.
    fieldcatset i_pos 'TEXT'   'TTEXT' 'ZTBC_AGR_TCODE'  'T-Text'     '' ' '.
  ENDIF.
  fieldcatset i_pos 'ERDAT'    ' '     ' '           'Last used date' '' ' '.
  fieldcatset i_pos 'ERNAM'    ' '     ' '           'Last used User' '' ' '.

  LOOP AT it_agr.
    l_tabix = sy-tabix.
    WRITE l_tabix TO l_agr_name LEFT-JUSTIFIED.
    CONCATENATE l_agr_name '-' it_agr-agr_name  INTO l_agr_name.
    fieldcatset i_pos it_agr-agr_name '' '' l_agr_name '' ''.
    IF p_check = 'X'.
      WRITE l_tabix TO l_agr_name LEFT-JUSTIFIED.
      CONCATENATE l_agr_name '-' 'Check'  INTO l_agr_name.
      fieldcatset i_pos l_agr_name '' '' l_agr_name 15 ''.
    ENDIF.
  ENDLOOP.

  LOOP AT it_fieldcat ASSIGNING <itfcct>.
    l_tabix = sy-tabix.
    MOVE-CORRESPONDING <itfcct> TO ls_dyn_fcat.
    CASE ls_dyn_fcat-fieldname.
      WHEN 'TCODE' OR 'TTEXT' OR 'TEXT' OR 'ERDAT' OR 'ERNAM'.
      WHEN OTHERS.
        DATA: l_result TYPE match_result_tab.
        FIND ALL OCCURRENCES OF '-Check' IN ls_dyn_fcat-fieldname RESULTS l_result.
        IF l_result[] IS INITIAL.
          ls_dyn_fcat-inttype = 'P'.
          ls_dyn_fcat-decimals = ls_dyn_fcat-decimals_o = 0.
          <itfcct>-no_zero   = 'X'.
          <itfcct>-just      = 'C'.
          <itfcct>-outputlen = 32.
        ELSE.
          ls_dyn_fcat-inttype = 'C'.
        ENDIF.
        MODIFY it_fieldcat FROM <itfcct> INDEX l_tabix.
    ENDCASE.
    APPEND ls_dyn_fcat TO lt_dyn_fcat.  CLEAR ls_dyn_fcat.
  ENDLOOP.

  CALL METHOD cl_alv_table_create=>create_dynamic_table
    EXPORTING
      i_style_table             = 'X'
      it_fieldcatalog           = lt_dyn_fcat
    IMPORTING
      ep_table                  = lt_dyn_table
    EXCEPTIONS
      generate_subpool_dir_full = 1
      OTHERS                    = 2.
* fields value
  IF sy-subrc EQ 0.
    ASSIGN lt_dyn_table->* TO <itdata>.
    CREATE DATA w_line LIKE LINE OF <itdata>.
    ASSIGN w_line->* TO <w_line_fs>.

    LOOP AT it_tlog.
      MOVE-CORRESPONDING it_tlog TO <w_line_fs>.
      READ TABLE it_agr_tc WITH KEY tcode = it_tlog-tcode.
      IF sy-subrc = 0.
        LOOP AT it_agr_tc WHERE tcode = it_tlog-tcode.
          ASSIGN COMPONENT it_agr_tc-agr_name OF STRUCTURE <w_line_fs> TO <w_fs1>.
          <w_fs1> = 1.

          IF p_check = 'X'.
            ASSIGN COMPONENT 'TEXT' OF STRUCTURE <w_line_fs> TO <w_fs3>.

            READ TABLE it_agr WITH KEY agr_name = it_agr_tc-agr_name.
            l_tabix = sy-tabix.
            WRITE l_tabix TO l_agr_name LEFT-JUSTIFIED.
            CONCATENATE l_agr_name '-' 'Check'  INTO l_agr_name.
            ASSIGN COMPONENT l_agr_name OF STRUCTURE <w_line_fs> TO <w_fs2>.

            READ TABLE itbc_agr WITH KEY agr_name = it_agr_tc-agr_name.
            IF sy-subrc <> 0.
              <w_fs2> = 'Role未設定'.
            ELSE.
              READ TABLE itbc_agr_tcode WITH KEY tcode = it_tlog-tcode.
              IF sy-subrc <> 0.
                <w_fs2> = 'T-code未設定'.
              ELSE.
                <w_fs3> = itbc_agr_tcode-ttext.
                CHECK itbc_agr_tcode-zmodule <> ''.    "tcode-zmodule = 空白: 表示所有Module+function權限
                READ TABLE itbc_agr_tcode WITH KEY tcode = it_tlog-tcode
                                                 zmodule = itbc_agr-zmodule.
                IF sy-subrc <> 0.
                  <w_fs2> = 'Module問題'.
                ELSE.
                  CHECK itbc_agr-zfunc <> ''.          "agr-zfunc = 空白: 表示該模組下, 所有function權限
                  READ TABLE itbc_agr_tcode WITH KEY tcode = it_tlog-tcode
                                                   zmodule = itbc_agr-zmodule  zfunc = itbc_agr-zfunc.
                  IF sy-subrc <> 0.
                    READ TABLE itbc_agr_tcode WITH KEY tcode = it_tlog-tcode
                                                     zmodule = itbc_agr-zmodule  zfunc = ''.  "tcode-zfunc = 空白: 表示跨function權限
                    IF sy-subrc <> 0.
                      <w_fs2> = 'Function問題'.
                    ENDIF.
                  ENDIF.
                ENDIF.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDLOOP.
        APPEND <w_line_fs> TO <itdata>.
        CLEAR: <w_line_fs>.
      ENDIF.
    ENDLOOP.
  ENDIF.
* display alv
  PERFORM display_alv_grid  TABLES <itdata>.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  DISPLAY_ALV
*&---------------------------------------------------------------------*
FORM display_alv .
  CHECK p_robase = 'X'.
  PERFORM fields_build.
  PERFORM build_layout      USING layout.
  PERFORM display_alv_grid  TABLES it_agr_tc.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  FIELDS_BUILD
*&---------------------------------------------------------------------*
FORM fields_build .
  fieldcatset i_pos 'AGR_NAME' ' '     'AGR_DEFINE'  ''               '' 'X'.
  fieldcatset i_pos 'TEXT'     ' '     'AGR_TEXTS'   ''               '' 'X'.
  fieldcatset i_pos 'TCODE'    ' '     'TSTCT'       ''               '' 'X'.
  fieldcatset i_pos 'TCTXT'    'TTEXT' 'TSTCT'       'Text'           '' ' '.
  fieldcatset i_pos 'ERDAT'    ' '     ' '           'Last used date' '' ' '.
  fieldcatset i_pos 'ERNAM'    ' '     ' '           'Last used User' '' ' '.
  fieldcatset i_pos 'MODIFIED' ' '     'AGR_1251'    'Object'         '' ' '.
  fieldcatset i_pos 'MENU'     ' '     ' '           'A-Menu'         '' ' '.
  fieldcatset i_pos 'CHECK'    ' '     ' '           'Check'         '' ' '.
ENDFORM.

*Text elements
*----------------------------------------------------------
* S01 Get data ZTTCODE_LOG


*Selection texts
*----------------------------------------------------------
* P_CHECK         Check
* P_DAYS D       .
* P_ROBASE         Role base
* P_TCBASE         T-code base
* S_ERNAM         User
* S_ROLE D       .
* S_TCODE         T-code

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
