*&---------------------------------------------------------------------*
*&  Include           ZTWIBC0001
*&---------------------------------------------------------------------*
TYPE-POOLS slis.
DATA: ls_addr_key       LIKE addr_key,
      ls_control_param  TYPE ssfctrlop,
      ls_composer_param TYPE ssfcompop,
      ls_recipient      TYPE swotobjid,
      job_output_info   TYPE ssfcrescl,
      ls_sender         TYPE swotobjid,
      lf_formname       TYPE tdsfname,
      lf_retcode        TYPE sy-subrc,
      fm_name           TYPE rs38l_fnam,
      sav_sy_repid      TYPE sy-repid,
      l_repid           TYPE sy-repid,
      l_lines           LIKE sy-tfill,
      gt_fieldcat       TYPE slis_t_fieldcat_alv,
      gt_sortinfo       TYPE slis_t_sortinfo_alv,
      gt_events         TYPE slis_t_event,
      gt_comments       TYPE slis_t_listheader,
      gs_layout         TYPE slis_layout_alv,
      gs_variant        TYPE disvariant,
      g_repid           TYPE sy-repid,
      sel_index         LIKE sy-index,
      p_lignam          TYPE slis_fieldname VALUE 'LIGHTS',
      layout            TYPE slis_layout_alv,
      class             TYPE REF TO zalv_gui_custom_class,  "#EC NEEDED
      g_tabname_header  TYPE slis_tabname VALUE 'ITAB',
      g_tabname_item    TYPE slis_tabname VALUE 'ITAB1',
      g_tabname_chk     TYPE slis_tabname VALUE 'ITAB_CHK',
      gs_keyinfo        TYPE slis_keyinfo_alv.
DATA: otf            TYPE TABLE OF itcoo WITH HEADER LINE,
      doctab_archive TYPE TABLE OF docs WITH HEADER LINE,
      lines          TYPE TABLE OF tline WITH HEADER LINE,
      bin_filesize   TYPE i,
      pdf_xstring    TYPE xstring,
      it_binary      TYPE STANDARD TABLE OF raw255.
DATA: it_fieldcat  TYPE lvc_t_fcat,
      wa_fieldcat  TYPE lvc_s_fcat,
      it_sortinfo  TYPE lvc_t_sort,
      gd_tab_group TYPE slis_t_sp_group_alv,
      gd_layout    TYPE lvc_s_layo,     "slis_layout_alv
      ls_stylerow  TYPE lvc_s_styl,
      lt_styletab  TYPE lvc_t_styl.
DATA: long_text   TYPE scrtext_l,
      medium_text TYPE scrtext_m,
      short_text  TYPE scrtext_s.
TYPES: BEGIN OF ty_layout,
         repid     TYPE syrepid,
         display   TYPE i,
         restrict  TYPE salv_de_layout_restriction,
         default   TYPE sap_bool,
         layout    TYPE disvariant-variant,
         load_layo TYPE sap_bool,
       END OF ty_layout.
DATA: ls_layout TYPE ty_layout.
DATA: lo_gr_alv       TYPE REF TO cl_salv_table,
      lo_gr_functions TYPE REF TO cl_salv_functions_list.
DATA: g_boxnam      TYPE slis_fieldname VALUE  'BOX',
      p_f2code      LIKE sy-ucomm VALUE  '&ETA',
      g_save(1)     TYPE c, g_default(1) TYPE c,
      g_exit(1)     TYPE c, gx_variant LIKE disvariant,
      g_variant     LIKE disvariant,
      set_vari      TYPE slis_vari,
      uname(20),
      info_text(50),
      l_tabix       LIKE sy-tabix,
      p_lines       LIKE sy-tfill,
      p_tabix       LIKE sy-tabix,
      title         LIKE sy-title,
      p_total       LIKE sy-tfill,
      p_suces       LIKE sy-tfill,
      p_error       LIKE sy-tfill,
      p_flag,
      l_index       LIKE sy-index,
      w_message(80),
      subject       LIKE sodocchgi1-obj_descr,
      desc          LIKE sodocchgi1-obj_descr,
      g_doc_type    LIKE soodk-objtp.
DATA: bdcdata LIKE bdcdata OCCURS 0 WITH HEADER LINE,
      messtab LIKE bdcmsgcoll OCCURS 0 WITH HEADER LINE.
DEFINE cls.
  CLEAR &1. REFRESH &1.
END-OF-DEFINITION.
DEFINE assign_range_table.
  &1-sign = &2. &1-option = &3.
  &1-low  = &4. &1-high = &5.
  APPEND &1. CLEAR &1.
END-OF-DEFINITION.
CONSTANTS: c_form_top_of_page TYPE slis_formname VALUE 'TOP_OF_PAGE',
           c_form_end_of_page TYPE slis_formname VALUE 'END_OF_PAGE',
           c_form_top_of_list TYPE slis_formname VALUE 'TOP_OF_LIST',
           c_form_end_of_list TYPE slis_formname VALUE 'END_OF_LIST'.
DEFINE message_text_build.
  CALL FUNCTION 'MESSAGE_TEXT_BUILD'
    EXPORTING
      msgid               = &1
      msgnr               = &2
      msgv1               = &3
      msgv2               = &4
      msgv3               = &5
      msgv4               = &6
    IMPORTING
      message_text_output = &7.
END-OF-DEFINITION.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
