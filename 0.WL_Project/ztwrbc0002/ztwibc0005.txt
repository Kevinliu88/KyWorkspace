*&---------------------------------------------------------------------*
*&  Include           ZTWIBC0005
*&---------------------------------------------------------------------*
DATA: layout           TYPE slis_layout_alv      OCCURS 0  WITH HEADER LINE.
DATA: it_fieldcat      TYPE slis_t_fieldcat_alv            WITH HEADER LINE.
*
DATA: i_pos            TYPE i  VALUE 0.
*
DEFINE fieldcatset.
  &1 = &1 + 1.
  it_fieldcat-col_pos         = &1.
  it_fieldcat-fieldname       = &2.
  if &3 = ''.
    it_fieldcat-REF_FIELDNAME = &2.
  else.
    it_fieldcat-REF_FIELDNAME = &3.
  endif.
  it_fieldcat-REF_TABNAME     = &4.
  it_fieldcat-seltext_l       = it_fieldcat-seltext_m = it_fieldcat-seltext_s
                              = it_fieldcat-REPTEXT_DDIC = &5.
  it_fieldcat-outputlen       = &6.
  it_fieldcat-fix_column      = &7.
  append it_fieldcat.  clear it_fieldcat.
END-OF-DEFINITION.
*&---------------------------------------------------------------------*
*&      Form  BUILD_LAYOUT
*&---------------------------------------------------------------------*
FORM build_layout  USING    u_layout TYPE slis_layout_alv.
  u_layout-colwidth_optimize  = 'X'.
  u_layout-info_fieldname     = 'COLOR_R'.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  DISPLAY_ALV_GRID
*&---------------------------------------------------------------------*
FORM display_alv_grid  TABLES pt_t_obj .
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program        = sy-repid
      i_callback_user_command   = 'USER_COMMAND'
      is_layout                 = layout
      it_fieldcat               = it_fieldcat[]
      i_save                    = 'A'        "A: both of Global & User Layout can be saved
    TABLES
      t_outtab                  = pt_t_obj.
ENDFORM.
*&--------------------------------------------------------------------*
*&      Form  USER_COMMAND
*&--------------------------------------------------------------------*
FORM user_command  USING ok_code     LIKE sy-ucomm
                         wa_selfield TYPE slis_selfield.
DATA: l_agr_name	TYPE	agr_name.

  CASE ok_code.
    WHEN '&IC1'.
      IF wa_selfield-fieldname = 'AGR_NAME' AND wa_selfield-value <> ''.
         l_agr_name = wa_selfield-value.
         PERFORM call_pfcg  USING l_agr_name.
      ENDIF.
  ENDCASE.
ENDFORM.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
