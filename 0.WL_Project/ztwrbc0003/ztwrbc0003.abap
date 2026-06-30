REPORT ztwrbc0003.
*&-----------------------------------------------------------------------------*
*& Report  Authorizatiions                                                     *
*------------------------------------------------------------------------------*
* Author      : Three                                                          *
* Date        : 2020/05/26                                                     *
********************************************************************************
* MODIFICATIONS HISTORY :                                                      *
********************************************************************************
* CHANGE DATE VERSION MODIFIER DESCRIPTION
* =========== ======= ======== =================================================
********************************************************************************
INCLUDE ztwibc0004.
INCLUDE ztwibc0005.
INCLUDE ztwrbc0003_top.
* ---------------------------------------------------------------------------- *
* SELECTION SCREEN
* ---------------------------------------------------------------------------- *
SELECT-OPTIONS: s_tcode   FOR tstc-tcode    OBLIGATORY.
SELECT-OPTIONS: s_object  FOR usobx-object  OBLIGATORY.
*&**********************************************************************
*& INITIALIZATION
*&**********************************************************************
INITIALIZATION.
  s_tcode-sign = 'I'. s_tcode-option = 'CP'.
  s_tcode-low = '*'. APPEND s_tcode.
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
  PERFORM get_usobx.
  CHECK it_usobx[] IS NOT INITIAL.
  PERFORM get_usobt.
  PERFORM get_tstc.
  PERFORM get_tobj.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_USOBX
*&---------------------------------------------------------------------*
FORM get_usobx .
  REFRESH: it_usobx, it_t_obj.  CLEAR: it_usobx, it_t_obj.
  SELECT *
    FROM usobx
    INTO CORRESPONDING FIELDS OF TABLE it_usobx
    WHERE name   IN s_tcode
      AND object IN s_object
      AND type    = 'TR'
      AND okflag  = 'Y'.
  SORT it_usobx BY name object.

  LOOP AT it_usobx.
    it_t_obj-tcode  = it_usobx-name.
    it_t_obj-object = it_usobx-object.
    APPEND it_t_obj.  CLEAR it_t_obj.

    it_tobjt-object = it_usobx-object.
    APPEND it_tobjt.  CLEAR it_tobjt.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_USOBT
*&---------------------------------------------------------------------*
FORM get_usobt .
  REFRESH: it_usobt.  CLEAR: it_usobt.
  SELECT *
    FROM usobt
    INTO CORRESPONDING FIELDS OF TABLE it_usobt
    WHERE name   IN s_tcode
      AND object IN s_object
      AND type    = 'TR'.
  SORT it_usobt BY name object.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_TSTC
*&---------------------------------------------------------------------*
FORM get_tstc .
DATA: w_tabix    LIKE sy-tabix.

  REFRESH: it_tstc.  CLEAR: it_tstc.
  SELECT *
    FROM tstct
    INTO CORRESPONDING FIELDS OF TABLE it_tstc
    WHERE tcode IN s_tcode
      AND sprsl = 'E'.
  SORT it_tstc BY tcode.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PROCESS_DATA
*&---------------------------------------------------------------------*
FORM process_data .
DATA: w_tabix    LIKE sy-tabix.

  LOOP AT it_t_obj  INTO is_t_obj.
    w_tabix = sy-tabix.
    PERFORM combine_field  USING is_t_obj.
    PERFORM combine_value  USING is_t_obj.
    READ TABLE it_tstc WITH KEY tcode = is_t_obj-tcode.
    IF sy-subrc = 0 AND it_tstc-ttext <> space.
      is_t_obj-tctxt = it_tstc-ttext.
    ELSE.
      PERFORM get_tstct  USING 'M' is_t_obj-tcode
                      CHANGING is_t_obj-tctxt.
    ENDIF.
    READ TABLE it_tobjt WITH KEY object = is_t_obj-object.
    IF sy-subrc = 0.
      is_t_obj-ttext = it_tobjt-ttext.
    ENDIF.
    MODIFY it_t_obj FROM is_t_obj INDEX w_tabix.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  COMBINE_FIELD
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_IS_T_OBJ  text
*----------------------------------------------------------------------*
FORM combine_field  USING    u_is_t_obj  STRUCTURE  is_t_obj.
  CHECK u_is_t_obj-object <> ''.
  READ TABLE it_tobj WITH KEY objct = u_is_t_obj-object.

  CHECK sy-subrc = 0.
  ASSIGN u_is_t_obj   TO <ls_t_obj>.
  ASSIGN it_tobj      TO <ls_tobj>.

  CLEAR: i_no, c_no, c_f, c_n, c_v.
  DO 10 TIMES.
    i_no = i_no + 1.
    IF i_no = 10.
      c_no = 0.
    ELSE.
      c_no = i_no.
    ENDIF.
    CONCATENATE '<ls_t_obj>-fiel'  c_no INTO c_f.
    ASSIGN (c_f) TO <l_f>.
    CONCATENATE '<ls_t_obj>-ftxt'  c_no INTO c_n.
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
  UNASSIGN: <l_f>, <l_n>, <l_v>, <ls_t_obj>, <ls_tobj>.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  COMBINE_VALUE
*&---------------------------------------------------------------------*
FORM combine_value  USING    u_t_obj  STRUCTURE is_t_obj.
  CHECK u_t_obj-object <> ''.
  ASSIGN u_t_obj TO <ls_t_obj>.

  LOOP AT it_usobt  WHERE name   = u_t_obj-tcode
                      AND object = u_t_obj-object.
    CLEAR: i_no, c_no, c_f, c_v.
    DO 10 TIMES.
      i_no = i_no + 1.
      IF i_no = 10.
        c_no = 0.
      ELSE.
        c_no = i_no.
      ENDIF.
      CONCATENATE '<ls_t_obj>-fiel'  c_no INTO c_f.
      ASSIGN (c_f) TO <l_f>.
      CONCATENATE '<ls_t_obj>-valu'  c_no INTO c_v.
      ASSIGN (c_v) TO <l_v>.
      IF <l_f> <> space AND <l_f> = it_usobt-field.
        PERFORM concatenate_value IN PROGRAM ztwrbc0002 IF FOUND
                 USING <l_v> it_usobt-low it_usobt-high.
        CLEAR: i_no, c_no, c_f, c_v.
        UNASSIGN: <l_f>, <l_v>.
        EXIT.
      ENDIF.
    ENDDO.
  ENDLOOP.
  UNASSIGN: <ls_t_obj>.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  DISPLAY_ALV
*&---------------------------------------------------------------------*
FORM display_alv .
  PERFORM fields_build.
  PERFORM build_layout      USING layout.
  PERFORM display_alv_grid  TABLES it_t_obj.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  FIELDS_BUILD
*&---------------------------------------------------------------------*
FORM fields_build .
  fieldcatset i_pos 'TCODE'  ' '  'TSTCT' ''     '' 'X'.
  fieldcatset i_pos 'TCTXT'  ' '  'TSTCT' 'Text' '' 'X'.
  fieldcatset i_pos 'OBJECT' ' '  'USOBX' ''     '' 'X'.
  fieldcatset i_pos 'TTEXT'  ' '  'TOBJT' ''     '' ''.

  DO 10 TIMES.
    i_no = i_no + 1.
    IF i_no = 10.
      c_no = 0.
    ELSE.
      c_no = i_no.
    ENDIF.
    CONCATENATE 'FIEL'  c_no INTO c_f.
    CONCATENATE 'Field' c_no INTO c_n.
    fieldcatset i_pos c_f 'FIELD' 'TSTCT' c_n '' ''.
    CONCATENATE 'FTXT'  c_no INTO c_f.
    CONCATENATE 'Fname' c_no INTO c_n.
    fieldcatset i_pos c_f 'FIELD' 'TSTCT' c_n '' ''.
    CONCATENATE 'VALU'  c_no INTO c_f.
    CONCATENATE 'Value' c_no INTO c_n.
    fieldcatset i_pos c_f ' '     ' '        c_n '' ''.
  ENDDO.
ENDFORM.


*Selection texts
*----------------------------------------------------------
* S_OBJECT D       .
* S_TCODE D       .

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
