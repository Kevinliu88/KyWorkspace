REPORT ztwrbc0002.
*&-----------------------------------------------------------------------------*
*& Report  Authorizatiions                                                     *
*------------------------------------------------------------------------------*
* Author      : Three                                                          *
* Date        : 2020/05/25                                                     *
********************************************************************************
* MODIFICATIONS HISTORY :                                                      *
********************************************************************************
* CHANGE DATE VERSION MODIFIER DESCRIPTION
* =========== ======= ======== =================================================
* 2020/11/24  V001    Three    功能增強: 增加判斷Inactive, 重複, 空值
********************************************************************************
INCLUDE ztwibc0004.
INCLUDE ztwibc0005.
INCLUDE ztwrbc0002_top.
* ---------------------------------------------------------------------------- *
* SELECTION SCREEN
* ---------------------------------------------------------------------------- *
SELECT-OPTIONS: s_role    FOR agr_define-agr_name  OBLIGATORY.
SELECT-OPTIONS: s_object  FOR agr_1251-object      OBLIGATORY.
*&**********************************************************************
*& INITIALIZATION
*&**********************************************************************
INITIALIZATION.
  s_role-sign = 'I'. s_role-option = 'CP'.
  s_role-low = 'Z*'. APPEND s_role.
  s_object-sign = 'I'. s_object-option = 'CP'.
  s_object-low = '*'. APPEND s_object.
* ------------------------------------------------------------- *
* Events
* ------------------------------------------------------------- *
START-OF-SELECTION.
  PERFORM prepare_data.
  PERFORM process_data.
  PERFORM display_alv.
*&---------------------------------------------------------------------*
*&      Form  PREPARE_DATA
*&---------------------------------------------------------------------*
FORM prepare_data .
  PERFORM get_agr_define  TABLES s_role.
  CHECK it_agr[] IS NOT INITIAL.

  CONCATENATE 'EEQ' 'S_TCODE' INTO s_object.  APPEND s_object.  CLEAR s_object.
  PERFORM get_agr_1251  TABLES s_role s_object.
  PERFORM get_agr_1252.
  PERFORM combine_object.
  PERFORM get_tobj.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_AGR_1252
*&---------------------------------------------------------------------*
FORM get_agr_1252 .
  REFRESH it_1252.  CLEAR it_1252.

  SELECT *
    INTO TABLE it_1252
    FROM  agr_1252
    WHERE agr_name IN s_role.
  SORT it_1252 BY agr_name counter.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  COMBINE_OBJECT
*&---------------------------------------------------------------------*
FORM combine_object .
  REFRESH: it_agr_object, it_tobjt.  CLEAR: it_agr_object, it_tobjt.

  LOOP AT it_agr.
    MOVE-CORRESPONDING it_agr  TO it_agr_object.
    READ TABLE it_1251 WITH KEY agr_name = it_agr-agr_name.
    IF sy-subrc = 0.
      LOOP AT it_1251 WHERE agr_name = it_agr-agr_name.
        READ TABLE it_agr_object WITH KEY agr_name = it_agr-agr_name
                                      object   = it_1251-object
                                      auth     = it_1251-auth.
        IF sy-subrc <> 0.
          it_tobjt-object = it_1251-object.
          APPEND it_tobjt.  CLEAR it_tobjt.
          it_agr_object-object = it_1251-object.
          it_agr_object-auth   = it_1251-auth.
          IF it_1251-deleted = 'X'.
            it_agr_object-check = 'Inactive'.
          ELSE.
            it_agr_object-check = ''.
          ENDIF.
          APPEND it_agr_object.  CLEAR it_1251.
        ENDIF.
      ENDLOOP.
      CLEAR: it_agr_object, it_1251, it_agr.
    ENDIF.
    CLEAR  it_agr.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PROCESS_DATA
*&---------------------------------------------------------------------*
FORM process_data .
  DATA: w_tabix    LIKE sy-tabix.
  DATA: ls_rult    TYPE c.

  LOOP AT it_agr_object  INTO is_agr_object.
    w_tabix = sy-tabix.
    PERFORM combine_field  USING is_agr_object.
    PERFORM combine_value  USING is_agr_object.
    READ TABLE it_tobjt WITH KEY object = is_agr_object-object.
    IF sy-subrc = 0.
      is_agr_object-ttext = it_tobjt-ttext.
    ENDIF.

    MODIFY it_agr_object FROM is_agr_object INDEX w_tabix.
  ENDLOOP.
*
  LOOP AT it_agr_object  INTO is_agr_object.
    LOOP AT it_agr_object WHERE agr_name =  is_agr_object-agr_name
                            AND object   =  is_agr_object-object
                            AND auth     <> is_agr_object-auth.
      PERFORM find_sting  USING '重複' it_agr_object-check CHANGING ls_rult.
      IF ls_rult = ''.
        CONCATENATE it_agr_object-check '重複'  INTO it_agr_object-check.
        MODIFY it_agr_object INDEX sy-tabix  TRANSPORTING check.
      ENDIF.
    ENDLOOP.
  ENDLOOP.
 SORT it_agr_object BY agr_name fiel1 fiel2 fiel3 fiel4 fiel5 fiel6 fiel7 fiel8 fiel9 fiel0.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  COMBINE_FIELD
*&---------------------------------------------------------------------*
FORM combine_field  USING    u_agr_object  STRUCTURE is_agr_object.
  CHECK u_agr_object-object <> ''.
  READ TABLE it_tobj WITH KEY objct = u_agr_object-object.

  CHECK sy-subrc = 0.
  ASSIGN u_agr_object TO <ls_a_obj>.
  ASSIGN it_tobj      TO <ls_tobj>.

  CLEAR: i_no, c_no, c_f, c_n, c_v.
  DO 10 TIMES.
    i_no = i_no + 1.
    IF i_no = 10.
      c_no = 0.
    ELSE.
      c_no = i_no.
    ENDIF.
    CONCATENATE '<ls_a_obj>-fiel'  c_no INTO c_f.
    ASSIGN (c_f) TO <l_f>.
    CONCATENATE '<ls_a_obj>-ftxt'  c_no INTO c_n.
    ASSIGN (c_n) TO <l_n>.
    CONCATENATE '<ls_tobj>-fiel'   c_no INTO c_v.
    ASSIGN (c_v) TO <l_v>.
    IF <l_v> <> space.
      <l_f> = <l_v>.
      READ TABLE it_tobjft  WITH KEY fieldname = <l_v>.
      IF sy-subrc = 0.
        <l_n> = it_tobjft-text.
      ENDIF.
    ENDIF.
  ENDDO.
  CLEAR: i_no, c_no, c_f, c_n, c_v.
  UNASSIGN: <l_f>, <l_n>, <l_v>, <ls_a_obj>, <ls_tobj>.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  COMBINE_VALUE
*&---------------------------------------------------------------------*
FORM combine_value  USING    u_agr_object  STRUCTURE is_agr_object.
  DATA: ls_rult  TYPE c.

  CHECK u_agr_object-object <> ''.
  ASSIGN u_agr_object TO <ls_a_obj>.

  LOOP AT it_1251  WHERE agr_name = u_agr_object-agr_name
                     AND object   = u_agr_object-object
                     AND auth     = u_agr_object-auth.
    CLEAR: i_no, c_no, c_f, c_v.
    DO 10 TIMES.
      i_no = i_no + 1.
      IF i_no = 10.
        c_no = 0.
      ELSE.
        c_no = i_no.
      ENDIF.
      CONCATENATE '<ls_a_obj>-fiel'  c_no INTO c_f.
      ASSIGN (c_f) TO <l_f>.
      CONCATENATE '<ls_a_obj>-valu'  c_no INTO c_v.
      ASSIGN (c_v) TO <l_v>.
      IF <l_f> <> space AND <l_f> = it_1251-field.
        PERFORM get_value   USING  <l_v> u_agr_object-agr_name
                                  it_1251-low it_1251-high.
        IF <l_v> = ''.
          PERFORM find_sting  USING '空值' u_agr_object-check CHANGING ls_rult.
          IF ls_rult = ''.
            CONCATENATE u_agr_object-check '空值' INTO u_agr_object-check.
          ENDIF.
        ENDIF.
        IF it_1251-low = '*'.
          PERFORM find_sting  USING '值' u_agr_object-check CHANGING ls_rult.
          IF ls_rult = ''.
            CONCATENATE u_agr_object-check '值*' INTO u_agr_object-check.
          ENDIF.
        ENDIF.

        CLEAR: i_no, c_no, c_f, c_v.
        UNASSIGN: <l_f>, <l_v>.
        EXIT.
      ENDIF.
    ENDDO.
  ENDLOOP.
  UNASSIGN: <ls_a_obj>.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_VALUE
*&---------------------------------------------------------------------*
FORM get_value  USING    u_value  u_role  u_low  u_high.
  IF u_low(1) = '$'.
    LOOP AT it_1252  WHERE agr_name = u_role
                       AND varbl    = u_low.
      PERFORM concatenate_value  USING u_value it_1252-low it_1252-high.
    ENDLOOP.
  ELSE.
    PERFORM concatenate_value  USING u_value u_low u_high.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CONCATENATE_VALUE
*&---------------------------------------------------------------------*
FORM concatenate_value  USING    u_value  u_low  u_high.
  DATA: w_value(82)    TYPE c.

  IF     u_low <> '' AND u_high <> ''.
    CONCATENATE u_low '-' u_high INTO w_value.
  ELSEIF u_low <> '' AND u_high =  ''.
    w_value = u_low.
  ENDIF.
  CONDENSE w_value NO-GAPS.
  IF u_value = ''.
    u_value = w_value.
  ELSE.
    CONCATENATE u_value ',' w_value  INTO u_value.
  ENDIF.
  CONDENSE u_value NO-GAPS.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  FIND_STING
*&---------------------------------------------------------------------*
FORM find_sting  USING    u_patt  u_string
                 CHANGING c_find.
  DATA: result_tab TYPE match_result_tab.
  CLEAR: c_find.
  FIND ALL OCCURRENCES OF u_patt  IN u_string
       RESULTS result_tab.
  IF result_tab[] IS NOT INITIAL.
    c_find = 'V'.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  DISPLAY_ALV
*&---------------------------------------------------------------------*
FORM display_alv .
  PERFORM fields_build.
  PERFORM build_layout      USING layout.
  PERFORM display_alv_grid  TABLES it_agr_object.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  FIELDS_BUILD
*&---------------------------------------------------------------------*
FORM fields_build .
  fieldcatset i_pos 'AGR_NAME' ' '  'AGR_DEFINE' ''       '' 'X'.
  fieldcatset i_pos 'TEXT'     ' '  'AGR_TEXTS'  ''       '' 'X'.
  fieldcatset i_pos 'AUTH'     ' '  'AGR_1251'   ''       '' 'X'.
  fieldcatset i_pos 'CHECK'    ' '  'AGR_1251'   'Check'  '' 'X'.
  fieldcatset i_pos 'OBJECT'   ' '  'AGR_1251'   ''       '' 'X'.
  fieldcatset i_pos 'TTEXT'    ' '  'TOBJT'      ''       '' ''.

  DO 10 TIMES.
    i_no = i_no + 1.
    IF i_no = 10.
      c_no = 0.
    ELSE.
      c_no = i_no.
    ENDIF.
    CONCATENATE 'FIEL'  c_no INTO c_f.
    CONCATENATE 'Field' c_no INTO c_n.
    fieldcatset i_pos c_f 'FIELD' 'AGR_1251' c_n '' ''.
    CONCATENATE 'FTXT'  c_no INTO c_f.
    CONCATENATE 'Fname' c_no INTO c_n.
    fieldcatset i_pos c_f 'FIELD' 'AGR_1251' c_n '' ''.
    CONCATENATE 'VALU'  c_no INTO c_f.
    CONCATENATE 'Value' c_no INTO c_n.
    fieldcatset i_pos c_f ' '     ' '        c_n '' ''.
  ENDDO.
ENDFORM.


*Selection texts
*----------------------------------------------------------
* S_OBJECT D       .
* S_ROLE D       .

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
