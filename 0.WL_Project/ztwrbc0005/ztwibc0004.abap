*&---------------------------------------------------------------------*
*&  Include           ZTWIBC0004
*&---------------------------------------------------------------------*
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
* 2020/08/17  V001    Three    Change select syntax
********************************************************************************
INCLUDE: <icon>.
TABLES: agr_define, agr_1251, tobjt, sscrfields.
*
DATA: BEGIN OF it_agr  OCCURS 0,
        agr_name    LIKE agr_define-agr_name,
        text        LIKE agr_texts-text,
      END OF it_agr.
*
DATA: it_1251         LIKE agr_1251        OCCURS 0  WITH HEADER LINE.
DATA: itbc_agr        LIKE ztbc_agr        OCCURS 0  WITH HEADER LINE.
DATA: itbc_agr_tcode  LIKE ztbc_agr_tcode  OCCURS 0  WITH HEADER LINE.
DATA: it_tobjt        LIKE tobjt           OCCURS 0  WITH HEADER LINE.
DATA: it_tobj         LIKE tobj            OCCURS 0  WITH HEADER LINE.
DATA: BEGIN OF it_tobjft  OCCURS 0,
        fieldname     LIKE tobj-fiel1,
        text          LIKE dfies-fieldtext,
      END OF it_tobjft.
*
DATA: BEGIN OF is_object,
        object      LIKE tobj-objct,
        ttext       LIKE tobjt-ttext,
        fiel1       LIKE tobj-fiel1,
        ftxt1       LIKE dd01t-ddtext,
        valu1       TYPE string,
        fiel2       LIKE tobj-fiel1,
        ftxt2       LIKE dd01t-ddtext,
        valu2       TYPE string,
        fiel3       LIKE tobj-fiel1,
        ftxt3       LIKE dd01t-ddtext,
        valu3       TYPE string,
        fiel4       LIKE tobj-fiel1,
        ftxt4       LIKE dd01t-ddtext,
        valu4       TYPE string,
        fiel5       LIKE tobj-fiel1,
        ftxt5       LIKE dd01t-ddtext,
        valu5       TYPE string,
        fiel6       LIKE tobj-fiel1,
        ftxt6       LIKE dd01t-ddtext,
        valu6       TYPE string,
        fiel7       LIKE tobj-fiel1,
        ftxt7       LIKE dd01t-ddtext,
        valu7       TYPE string,
        fiel8       LIKE tobj-fiel1,
        ftxt8       LIKE dd01t-ddtext,
        valu8       TYPE string,
        fiel9       LIKE tobj-fiel1,
        ftxt9       LIKE dd01t-ddtext,
        valu9       TYPE string,
        fiel0       LIKE tobj-fiel1,
        ftxt0       LIKE dd01t-ddtext,
        valu0       TYPE string,
      END OF is_object.
*
FIELD-SYMBOLS: <ls_tobj>,
               <l_f>   TYPE any,
               <l_n>   TYPE any,
               <l_v>   TYPE any.
DATA: i_no     TYPE i  VALUE 0,
      c_no     TYPE c,
      c_f(20)  TYPE c,
      c_n(20)  TYPE c,
      c_v(20)  TYPE c.
*&---------------------------------------------------------------------*
*&      Form  PUSH_BUTTON
*&---------------------------------------------------------------------*
FORM push_button .
DATA: l_sel_button TYPE smp_dyntxt.
  l_sel_button-icon_id   = icon_role.
  l_sel_button-quickinfo = l_sel_button-icon_text = 'ºûÅ@Role'.
  sscrfields-functxt_01  = l_sel_button.
  l_sel_button-icon_id   = icon_checked.
  l_sel_button-quickinfo = l_sel_button-icon_text = 'ºûÅ@Tcode'.
  sscrfields-functxt_02  = l_sel_button.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  VIEW_MAINTAIN
*&---------------------------------------------------------------------*
FORM view_maintain  USING    u_view.
  CALL FUNCTION 'VIEW_MAINTENANCE_CALL'
    EXPORTING
      action                       = 'U'
      view_name                    = u_view
*   TABLES
*     dba_sellist                  = dba_sellist
    EXCEPTIONS
      client_reference             = 1
      foreign_lock                 = 2
      invalid_action               = 3
      no_clientindependent_auth    = 4
      no_database_function         = 5
      no_editor_function           = 6
      no_show_auth                 = 7
      no_tvdir_entry               = 8
      no_upd_auth                  = 9
      only_show_allowed            = 10
      system_failure               = 11
      unknown_field_in_dba_sellist = 12
      view_not_found               = 13
      maintenance_prohibited       = 14
      OTHERS                       = 15.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE 'W' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_AGR_DEFINE
*&---------------------------------------------------------------------*
FORM get_agr_define  TABLES pt_role.
DATA: w_tabix    LIKE sy-tabix.
*V001 Changed by Three 2020/08/17
  REFRESH: it_agr.  CLEAR: it_agr.
  SELECT *
    FROM agr_define
    INTO CORRESPONDING FIELDS OF TABLE @it_agr
    WHERE agr_name IN @pt_role.
  SORT it_agr BY agr_name.

  LOOP AT it_agr.
    w_tabix = sy-tabix.
    PERFORM get_text     USING 'E' it_agr-agr_name
                      CHANGING it_agr-text.
    IF it_agr-text = space.
      PERFORM get_text     USING 'M' it_agr-agr_name
                        CHANGING it_agr-text.
    ENDIF.
    IF it_agr-text <> ''.
      MODIFY it_agr  INDEX w_tabix.
    ENDIF.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_ZTBC_AGR
*&---------------------------------------------------------------------*
FORM get_ztbc_agr  TABLES pt_role.
  REFRESH: itbc_agr.  CLEAR: itbc_agr.
  SELECT *
    FROM ztbc_agr
    INTO CORRESPONDING FIELDS OF TABLE @itbc_agr
    WHERE agr_name IN @pt_role.
  SORT itbc_agr BY agr_name.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_ZTBC_AGR_TCODE
*&---------------------------------------------------------------------*
FORM get_ztbc_agr_tcode  TABLES   pt_tcode.
  REFRESH: itbc_agr_tcode.  CLEAR: itbc_agr_tcode.
  SELECT *
    FROM ztbc_agr_tcode
    INTO CORRESPONDING FIELDS OF TABLE @itbc_agr_tcode
    WHERE tcode IN @pt_tcode.
  SORT itbc_agr_tcode BY tcode zmodule zfunc.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_TEXT
*&---------------------------------------------------------------------*
FORM get_text  USING    u_sprsl u_agr_name
               CHANGING c_text.
  CLEAR c_text.
  SELECT SINGLE text INTO c_text
    FROM agr_texts
    WHERE agr_name = u_agr_name
      AND spras = u_sprsl.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_AGR_1251
*&---------------------------------------------------------------------*
FORM get_agr_1251  TABLES pt_role pt_object.
  REFRESH it_1251.  CLEAR it_1251.
*
  SELECT *
    INTO TABLE it_1251
    FROM  agr_1251
    WHERE agr_name IN pt_role
      AND object   IN pt_object.
  SORT it_1251 BY agr_name object auth counter.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_TOBJ
*&---------------------------------------------------------------------*
FORM get_tobj .
DATA: w_tabix  LIKE sy-tabix.

  REFRESH: it_tobj, it_tobjft.
  CLEAR:   it_tobj, it_tobjft.

  SORT it_tobjt BY object.
  DELETE ADJACENT DUPLICATES FROM it_tobjt COMPARING object.
  CHECK it_tobjt[] IS NOT INITIAL.

  SELECT *
    INTO TABLE it_tobj
    FROM  tobj
     FOR ALL ENTRIES IN it_tobjt
    WHERE objct = it_tobjt-object.
*
  LOOP AT it_tobjt.
    w_tabix = sy-tabix.
    PERFORM get_tobjt  USING it_tobjt-object
                    CHANGING it_tobjt-langu  it_tobjt-ttext.
    IF it_tobjt-ttext <> ''.
      MODIFY it_tobjt INDEX w_tabix.
    ENDIF.
  ENDLOOP.
*
  LOOP AT it_tobj  ASSIGNING <ls_tobj>.
    CLEAR: i_no, c_no, c_f.
    DO 10 TIMES.
      i_no = i_no + 1.
      IF i_no = 10.
        c_no = 0.
      ELSE.
        c_no = i_no.
      ENDIF.
      CONCATENATE '<ls_tobj>-fiel'  c_no INTO c_f.
      ASSIGN (c_f) TO <l_f>.
      IF <l_f> <> space.
        it_tobjft-fieldname = <l_f>.
        APPEND it_tobjft.  CLEAR it_tobjft.
      ENDIF.
    ENDDO.
  ENDLOOP.
  CLEAR: i_no, c_no, c_f.
  UNASSIGN: <l_f>, <ls_tobj>.
  SORT it_tobjft BY fieldname.
  DELETE ADJACENT DUPLICATES FROM it_tobjft COMPARING fieldname.

  LOOP AT it_tobjft.
    w_tabix = sy-tabix.
    SELECT SINGLE t~ddtext  INTO it_tobjft-text
      FROM authx AS a JOIN dd04l AS l  ON a~rollname = l~rollname
                                      AND l~as4local = 'A'
                      JOIN dd04t AS t  ON l~rollname = t~rollname
                                      AND l~as4local = t~as4local
                                      AND ddlanguage = 'E'
      WHERE fieldname = it_tobjft-fieldname.
    IF sy-subrc = 0.
      MODIFY it_tobjft INDEX w_tabix.  CLEAR it_tobjft.
    ENDIF.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_TOBJT
*&---------------------------------------------------------------------*
FORM get_tobjt  USING    u_object
                CHANGING c_langu c_ttext.

  CLEAR: c_langu, c_ttext.
  SELECT SINGLE *
    FROM tobjt
    WHERE object = u_object
    AND langu = 'E'
    AND ttext <> ''.
  IF sy-subrc <> 0.
    SELECT SINGLE *
      FROM tobjt
      WHERE object = u_object
      AND langu <> 'E'
      AND ttext <> ''.
  ENDIF.
  IF tobjt-ttext <> ''.
    c_langu = tobjt-langu.
    c_ttext = tobjt-ttext.
    CLEAR tobjt.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_TSTCT
*&---------------------------------------------------------------------*
FORM get_tstct  USING    u_sprsl  u_tcode
                CHANGING c_ttext.
  CLEAR c_ttext.
  SELECT SINGLE ttext INTO c_ttext
    FROM tstct
    WHERE sprsl = u_sprsl
      AND tcode = u_tcode.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CALL_PFCG
*&---------------------------------------------------------------------*
FORM call_pfcg  USING    u_agr_name.
  CHECK u_agr_name IS NOT INITIAL.
   CALL FUNCTION 'PRGN_SHOW_EDIT_AGR'
     EXPORTING
       agr_name            = u_agr_name
*      MODE                = 'A'
*      SCREEN              = '1'
*      SICHT               = ' '
     EXCEPTIONS
       agr_not_found       = 1
       OTHERS              = 2.
ENDFORM.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
