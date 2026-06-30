REPORT ztwrbc0005.
*&-----------------------------------------------------------------------------*
*& Report  Authorizatiions                                                     *
*------------------------------------------------------------------------------*
* Author      : Three                                                          *
* Date        : 2020/06/2                                                     *
********************************************************************************
* MODIFICATIONS HISTORY :                                                      *
********************************************************************************
* CHANGE DATE VERSION MODIFIER DESCRIPTION
* =========== ======= ======== =================================================
********************************************************************************
INCLUDE ztwibc0004.
INCLUDE ztwibc0005.
INCLUDE ztwrbc0005_top.
* ---------------------------------------------------------------------------- *
* SELECTION SCREEN
* ---------------------------------------------------------------------------- *
SELECT-OPTIONS: s_role   FOR  agr_define-agr_name  OBLIGATORY.
SELECT-OPTIONS: s_uname  FOR  agr_users-uname      OBLIGATORY.
*&**********************************************************************
*& INITIALIZATION
*&**********************************************************************
INITIALIZATION.
  s_role-sign = 'I'. s_role-option = 'CP'.
  s_role-low = 'Z*'. APPEND s_role.
  s_uname-sign = 'I'. s_uname-option = 'CP'.
  s_uname-low = 'A*'. APPEND s_uname.
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
  PERFORM get_agr_users.
  PERFORM combine_object.
  PERFORM get_usr21.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_AGR_USERS
*&---------------------------------------------------------------------*
FORM get_agr_users.
  REFRESH it_a_user.  CLEAR it_a_user.
*
  SELECT *
    INTO TABLE it_a_user
    FROM  agr_users
    WHERE agr_name IN s_role
      AND uname    IN s_uname.
  SORT it_a_user BY agr_name uname.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  COMBINE_OBJECT
*&---------------------------------------------------------------------*
FORM combine_object .
  REFRESH: it_agr_user, it_user.  CLEAR: it_agr_user, it_user.

  LOOP AT it_agr.
    MOVE-CORRESPONDING it_agr  TO it_agr_user.
    LOOP AT it_a_user WHERE agr_name = it_agr-agr_name.
      it_user-bname = it_agr_user-uname = it_a_user-uname.
      APPEND: it_agr_user, it_user.
    ENDLOOP.
    CLEAR: it_agr, it_agr_user.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_USR21
*&---------------------------------------------------------------------*
FORM get_usr21 .
  DATA: lt_user    LIKE it_user    OCCURS 0  WITH HEADER LINE.

  SORT it_user BY bname.
  DELETE ADJACENT DUPLICATES FROM it_user COMPARING bname.
  CHECK it_user[] IS NOT INITIAL.

  lt_user[] = it_user[].
  REFRESH it_user.  CLEAR it_user.

  SELECT *
    INTO CORRESPONDING FIELDS OF TABLE it_user
    FROM user_addr
     FOR ALL ENTRIES IN lt_user
    WHERE bname = lt_user-bname.
  SORT lt_user BY bname.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PROCESS_DATA
*&---------------------------------------------------------------------*
FORM process_data .
  DATA: w_tabix    LIKE sy-tabix.

  LOOP AT it_agr_user  INTO is_agr_user.
    w_tabix = sy-tabix.
    READ TABLE it_user WITH KEY bname = is_agr_user-uname.
    IF sy-subrc = 0.
      MOVE-CORRESPONDING it_user TO is_agr_user.
      MODIFY it_agr_user FROM is_agr_user INDEX w_tabix.
    ENDIF.
  ENDLOOP.
  SORT it_agr_user BY agr_name uname department.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  DISPLAY_ALV
*&---------------------------------------------------------------------*
FORM display_alv .
  PERFORM fields_build.
  PERFORM build_layout      USING layout.
  PERFORM display_alv_grid  TABLES it_agr_user.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  FIELDS_BUILD
*&---------------------------------------------------------------------*
FORM fields_build .
  fieldcatset i_pos 'AGR_NAME'   ' '  'AGR_DEFINE'  ''  '' 'X'.
  fieldcatset i_pos 'TEXT'       ' '  'AGR_TEXTS'   ''  '' 'X'.
  fieldcatset i_pos 'UNAME'      ' '  'AGR_USERS'   ''  '' 'X'.
  fieldcatset i_pos 'NAME_TEXTC' ' '  'USER_ADDR'   ''  '' 'X'.
  fieldcatset i_pos 'DEPARTMENT' ' '  'USER_ADDR'   ''  '' 'X'.
ENDFORM.


*Selection texts
*----------------------------------------------------------
* S_ROLE D       .
* S_UNAME D       .

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
