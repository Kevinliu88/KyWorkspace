************************************************************************
* PROGRAM NAME :  ZUSRSD0007               START DATE    : XXXX/XX/XX
* TRANS. CORD  :  ZUSRSD0007               FINISHED DATE : XXXX/XX/XX
* MODULE       :
* AUTHOR       :                           SYSTEM ANALYST:
* TITLE        :
* OPTION       :
* PURPOSE      :
* FREQUENCY    :
* CHANGE       :
************************************************************************
* MODIFICATION LOG
************************************************************************
* CHANGE DATE VERSION MODIFIER DESCRIPTION
* =========== ======= ======== =========================================
*
************************************************************************
REPORT zusrsd0007 MESSAGE-ID zfi01.
*&**********************************************************************
*& TABLE DECLARATION
*&**********************************************************************
TABLES: t001, edidc, edoc_stli, edoc_stat, ttzcu, tvarvc, edids.
*&**********************************************************************
*& INCLUDE PROGRAM
*&**********************************************************************
INCLUDE: ztwibc0001, <icon>.
*&**********************************************************************
*& GLOBAL DATA DECLARATION
*&**********************************************************************
DATA: BEGIN OF itab OCCURS 0,
        docnum LIKE edidc-docnum,
        status LIKE edidc-status,
        direct LIKE edidc-direct,
        rcvpor LIKE edidc-rcvpor,
        rcvprt LIKE edidc-rcvprt,
        rcvprn LIKE edidc-rcvprn,
        stdmes LIKE edidc-stdmes,
        outmod LIKE edidc-outmod,
        sndpor LIKE edidc-sndpor,
        sndprt LIKE edidc-sndprt,
        sndprn LIKE edidc-sndprn,
        credat LIKE edidc-credat,
        cretim LIKE edidc-cretim,
        mestyp LIKE edidc-mestyp,
        idoctp LIKE edidc-idoctp,
        cimtyp LIKE edidc-cimtyp,
        rcvpfc LIKE edidc-rcvpfc,
        sndpfc LIKE edidc-sndpfc,
        upddat LIKE edidc-upddat,
        updtim LIKE edidc-updtim,
        statxt LIKE edids-statxt,
      END OF itab.
DATA: it_zemailist LIKE zemailist OCCURS 0 WITH HEADER LINE,
      it_edids     LIKE edids OCCURS 0 WITH HEADER LINE,
      it_edidc     LIKE edidc OCCURS 0 WITH HEADER LINE.
DATA: sender    TYPE REF TO if_sender_bcs,
      c_sender  TYPE ad_smtpadr ,
      c_display TYPE ad_smtpadr ,
      g_print   TYPE slis_print_alv.
CONSTANTS:
  gc_tab  TYPE c VALUE cl_bcs_convert=>gc_tab,
  gc_crlf TYPE c VALUE cl_bcs_convert=>gc_crlf.
DATA: objpack        LIKE sopcklsti1 OCCURS 2 WITH HEADER LINE,
      objhead        LIKE solisti1 OCCURS 1 WITH HEADER LINE,
      objtxt         LIKE solisti1 OCCURS 10 WITH HEADER LINE,
      doc_chng       LIKE sodocchgi1,
      tab_lines      LIKE sy-tabix, body_start TYPE i,
      reclist        LIKE somlreci1 OCCURS 0 WITH HEADER LINE,
      send_request   TYPE REF TO cl_bcs,
      document       TYPE REF TO cl_document_bcs,
      recipient      TYPE REF TO if_recipient_bcs,
      bcs_exception  TYPE REF TO cx_bcs,
      main_text      TYPE bcsy_text,
      binary_content TYPE solix_tab,
      size           TYPE so_obj_len,
      sent_to_all    TYPE os_boolean,
      mailto         TYPE ad_smtpadr,
      lv_string      TYPE string,
      ls_t100        TYPE t100, p_length TYPE i,
      file_start     TYPE i.
DATA: BEGIN OF objbin OCCURS 0,
        line TYPE string,
      END OF objbin.
RANGES: r_erzet FOR sy-uzeit, r_vbtyp FOR vbfa-vbtyp_n,
        r_credat FOR edidc-credat, r_upddat FOR edidc-upddat.
DATA: e_date_lcl  TYPE e_edmdatefrom, e_time_lcl TYPE e_edmtimefrom,
"      cprog_title TYPE tvarvc-name VALUE 'ZUSRSD0007_EMAIL_TITLE',
      e_datlo     LIKE sy-datlo, e_timlo LIKE sy-timlo,
      p_uzeit     LIKE sy-timlo, e_dathi_lo LIKE sy-datlo,
      e_dathi_hi  LIKE sy-datlo.
DATA: e_object     LIKE borident,
      it_links     LIKE relgraphlk OCCURS 0 WITH HEADER LINE,
      it_roles     LIKE relroles OCCURS 0 WITH HEADER LINE,
      it_appllinks LIKE borident OCCURS 0 WITH HEADER LINE.
DATA: time_0  LIKE edidc-updtim VALUE '000000',
      time_24 LIKE edidc-updtim VALUE '240000'.

*&**********************************************************************
*& SELECTION SCREEN
*&**********************************************************************
SELECTION-SCREEN BEGIN OF BLOCK bk1 WITH FRAME TITLE text-t01.
SELECT-OPTIONS: cretim  FOR edidc-cretim DEFAULT time_0 TO time_24.
SELECT-OPTIONS: credat  FOR edidc-credat DEFAULT sy-datum TO sy-datum,
                updtim  FOR edidc-updtim DEFAULT time_0 TO time_24,
                upddat  FOR edidc-upddat.
SELECTION-SCREEN SKIP.
SELECT-OPTIONS: direct  FOR edidc-direct NO-EXTENSION NO INTERVALS,
                docnum  FOR edidc-docnum,
                status  FOR edidc-status.
SELECTION-SCREEN SKIP.
SELECT-OPTIONS: idoctp  FOR edidc-idoctp,
                cimtyp  FOR edidc-cimtyp,
                mestyp  FOR edidc-mestyp,
                mescod  FOR edidc-mescod,
                mesfct  FOR edidc-mesfct.
SELECTION-SCREEN SKIP.
SELECT-OPTIONS: pppor  FOR edoc_stli-rcvpor,
                ppprn  FOR edoc_stat-rcvprn,
                ppprt  FOR edoc_stli-rcvprt,
                pppfc  FOR edoc_stli-rcvpfc.
SELECTION-SCREEN SKIP.
SELECT-OPTIONS s_tzone FOR ttzcu-tzonesys DEFAULT 'EST' NO INTERVALS
                                                        NO-EXTENSION
                                           OBLIGATORY.
"PARAMETERS: p_repid LIKE zemailist-repid.
SELECTION-SCREEN END OF BLOCK bk1.

SELECTION-SCREEN BEGIN OF BLOCK bk3 WITH FRAME TITLE text-t03.
PARAMETERS: p_email AS CHECKBOX USER-COMMAND ucomm DEFAULT ''.
PARAMETERS: p_repid  LIKE zemailist-repid DEFAULT 'ZUSRSD0007'
                    MODIF ID mal,
            p_title TYPE c LENGTH 50
                    DEFAULT '[System] iDoc Errors - All'
                    MODIF ID mal lower case,
            p_file type c length 50
                    default 'IDoc Erros List'
                    MODIF ID mal LOWER CASE,
            p_disply TYPE c LENGTH 30
                    DEFAULT 'SAP Auto Job'
                    MODIF ID mal LOWER CASE,
            p_sender TYPE c LENGTH 50
                    DEFAULT 'no-reply@wonderland.com.tw'
                    MODIF ID mal LOWER CASE.
SELECTION-SCREEN END OF BLOCK bk3.
*&**********************************************************************
*& INITIALIZATION
*&**********************************************************************
INITIALIZATION.
  CREATE OBJECT class.
  g_save = 'A'. g_repid = sy-repid.
  p_uzeit = sy-uzeit.
*&**********************************************************************
*& AT SELECTION-SCREEN
*&**********************************************************************
AT SELECTION-SCREEN.
AT SELECTION-SCREEN OUTPUT.
  PERFORM set_screen_attribute.
*&**********************************************************************
*& START-OF-SELECTION
*&**********************************************************************
START-OF-SELECTION.
  PERFORM convert_timezone.
  PERFORM extract_data.
  PERFORM combine_data.
  IF itab[] IS NOT INITIAL and P_email = 'X'.
    PERFORM send_email.
  ENDIF.
  if sy-batch = ''.
  PERFORM slis_alv_layout.
  endif.
*&**********************************************************************
*& END-OF-SELECTION
*&**********************************************************************
END-OF-SELECTION.
*&---------------------------------------------------------------------*
*&      Form  TOP_OF_PAGE
*&---------------------------------------------------------------------*
FORM top_of_page.
  CALL METHOD class->report_title.
  CALL METHOD class->reuse_alv_commentary_write
    CHANGING
      gt_comments = gt_comments.
ENDFORM.                    " TOP_OF_PAGE
*&---------------------------------------------------------------------*
*&      Form  END_OF_PAGE
*&---------------------------------------------------------------------*
FORM end_of_page.

ENDFORM.                    " END_OF_PAGE
*&---------------------------------------------------------------------*
*&      Form  END_OF_LIST
*&---------------------------------------------------------------------*
FORM end_of_list.

ENDFORM.                    " END_OF_LIST
*&---------------------------------------------------------------------*
*&      Form  SLIS_ALV_LAYOUT
*&---------------------------------------------------------------------*
FORM slis_alv_layout.
  PERFORM: fieldcat_init,
*           sortinfo_init,
*           events_init,
*           comment_build,
           build_layout,
           reuse_alv_list_display.
ENDFORM.                    " SLIS_ALV_LAYOUT
*&---------------------------------------------------------------------*
*&      Form  FIELDCAT_INIT
*&---------------------------------------------------------------------*
FORM fieldcat_init.
  DATA: st_fieldcat TYPE slis_fieldcat_alv,
        wa_fieldcat LIKE st_fieldcat,
        tabname     LIKE st_fieldcat-tabname VALUE 'ITAB',
        fieldname   LIKE st_fieldcat-fieldname,
        seltext_l   LIKE st_fieldcat-seltext_l,
        outputlen   LIKE st_fieldcat-outputlen,
        key         LIKE st_fieldcat-key,
        cfieldname  LIKE st_fieldcat-cfieldname.
  RANGES: r_fieldname FOR st_fieldcat-fieldname.
  cls gt_fieldcat.
  DEFINE st_fieldcat.
    MOVE: &1 TO FIELDNAME, &2 TO SELTEXT_L, &3 TO OUTPUTLEN,
          &4 TO KEY,       &5 TO CFIELDNAME.
    CALL METHOD CLASS->FIELDCAT_INIT
      EXPORTING
        TABNAME     = TABNAME
        FIELDNAME   = FIELDNAME
        SELTEXT_L   = SELTEXT_L
        OUTPUTLEN   = OUTPUTLEN
        KEY         = KEY
        CFIELDNAME  = CFIELDNAME
      CHANGING
        GT_FIELDCAT = GT_FIELDCAT.
  END-OF-DEFINITION.
  CALL FUNCTION 'REUSE_ALV_FIELDCATALOG_MERGE'
    EXPORTING
      i_program_name         = sy-repid
      i_internal_tabname     = 'ITAB'
      i_inclname             = sy-repid
    CHANGING
      ct_fieldcat            = gt_fieldcat
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2.
ENDFORM.                    " FIELDCAT_INIT
*&---------------------------------------------------------------------*
*&      Form  SORTINFO_INIT
*&---------------------------------------------------------------------*
FORM sortinfo_init.
  DATA: st_sort   TYPE slis_sortinfo_alv,
        group     LIKE st_sort-group,
        spos      LIKE st_sort-spos,
        fieldname LIKE st_sort-fieldname,
        up        LIKE st_sort-up,
        subtot    LIKE st_sort-subtot.
  cls gt_sortinfo.
  DEFINE st_sort.
    MOVE: &1 TO SPOS, &2 TO FIELDNAME, &3 TO UP,
          &4 TO SUBTOT, &5 TO GROUP.
    CALL METHOD CLASS->SORTINFO_INIT
      EXPORTING
        SPOS        = SPOS
        FIELDNAME   = FIELDNAME
        UP          = UP
        SUBTOT      = SUBTOT
        GROUP       = GROUP
      CHANGING
        GT_SORTINFO = GT_SORTINFO.
  END-OF-DEFINITION.
  st_sort: 1 'GJAHR' 'X' ' ' ' ', 2 'MONAT' 'X' ' ' ' ',
           3 'LIGHTS' ' ' ' ' '*'.
ENDFORM.                    " SORTINFO_INIT
*&---------------------------------------------------------------------*
*&      Form  EVENTS_INIT
*&---------------------------------------------------------------------*
FORM events_init.
  CALL METHOD class->events_init
    CHANGING
      gt_events = gt_events.
*  DATA LS_EVENT TYPE SLIS_ALV_EVENT.
*    CALL FUNCTION 'REUSE_ALV_EVENTS_GET'
*      EXPORTING
*        I_LIST_TYPE     = 0
*      IMPORTING
*        ET_EVENTS       = GT_EVENTS
*      EXCEPTIONS
*        LIST_TYPE_WRONG = 1
*        OTHERS          = 2.
*    IF SY-SUBRC <> 0.
** Implement suitable error handling here
*    ENDIF.
*  LOOP AT GT_EVENTS INTO LS_EVENT
*                   WHERE NAME = 'USER_COMMAND'.
*    MOVE 'USER_COMMAND' TO LS_EVENT-FORM.
*    MODIFY GT_EVENTS FROM LS_EVENT INDEX SY-TABIX.
*  ENDLOOP.
ENDFORM.                    " EVENTS_INIT
*&---------------------------------------------------------------------*
*&      Form  COMMENT_BUILD
*&---------------------------------------------------------------------*
FORM comment_build.
  DATA: ls_line     TYPE slis_listheader,
        info        LIKE ls_line-info,
        wa_comments TYPE slis_listheader.
*  CONCATENATE 'Fiscal Year: ' P_GJAHR INTO INFO.
  CALL METHOD class->comment_build
    EXPORTING
      info        = info
    CHANGING
      gt_comments = gt_comments.
*  LOOP AT gt_comments INTO wa_comments.
*    wa_comments-typ = 'H'.
*    MODIFY gt_comments FROM wa_comments.
*  ENDLOOP.
ENDFORM.                    " COMMENT_BUILD
*&---------------------------------------------------------------------*
*&      Form  BUILD_LAYOUT
*&---------------------------------------------------------------------*
FORM build_layout.
  DATA: numc_sum         LIKE layout-numc_sum VALUE 'X',
        box_fieldname    LIKE layout-box_fieldname VALUE 'SELEC',
        lights_fieldname LIKE layout-lights_fieldname VALUE 'LIGHTS'.
  CALL METHOD class->build_layout
    EXPORTING
      numc_sum = numc_sum
*     box_fieldname = box_fieldname
*     LIGHTS_FIELDNAME = LIGHTS_FIELDNAME
    IMPORTING
      layout   = layout.
ENDFORM.                    " BUILD_LAYOUT
*&---------------------------------------------------------------------*
*&      Form  REUSE_ALV_LIST_DISPLAY
*&---------------------------------------------------------------------*
FORM reuse_alv_list_display.
  DATA grid_settings TYPE lvc_s_glay.
*  g_print-no_print_listinfos = 'X'.
  grid_settings-edt_cll_cb = 'X'.
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program = g_repid
*     I_BACKGROUND_ID    = 'BUTTON_UP_BACK'
      i_bypassing_buffer = 'X'
*     I_CALLBACK_PF_STATUS_SET = 'SET_PF_STATUS'
      is_layout          = layout
      is_print           = g_print
      it_fieldcat        = gt_fieldcat[]
      it_sort            = gt_sortinfo[]
      it_events          = gt_events
      i_grid_settings    = grid_settings
      i_default          = 'X'
      i_save             = 'A'
      is_variant         = g_variant
    TABLES
      t_outtab           = itab
    EXCEPTIONS
      program_error      = 1
      OTHERS             = 2.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.
ENDFORM.                    " REUSE_ALV_LIST_DISPLAY
*---------------------------------------------------------------------*
*       FORM USER_COMMAND                                             *
*---------------------------------------------------------------------*
FORM user_command USING ucom LIKE sy-ucomm
                        selfd TYPE slis_selfield.
* Define Checkbox-->CHECKBOX = 'X' + EDIT = 'X'
  DATA: ref_grid TYPE REF TO cl_gui_alv_grid.
  IF ref_grid IS INITIAL.
    CALL FUNCTION 'GET_GLOBALS_FROM_SLVC_FULLSCR'
      IMPORTING
        e_grid = ref_grid.
  ENDIF.
  IF NOT ref_grid IS INITIAL.
    CALL METHOD ref_grid->check_changed_data.
  ENDIF.
  CLEAR sel_index. sel_index = selfd-tabindex.
  CASE ucom.
    WHEN '&IC1'. " Hotspot
      CASE selfd-sel_tab_field.
        WHEN 'ITAB-ITMNO' OR 'ITAB-CATGY'.
      ENDCASE.
    WHEN '&SAV'. " Save

    WHEN '&CRA'. " Create
      CALL SCREEN 2000
                  STARTING AT 1  1
                  ENDING   AT 70 18.
*  selfd-exit = 'X'.
  ENDCASE.

  selfd-refresh = 'X'.
ENDFORM.                    " USER_COMMAND
*&---------------------------------------------------------------------*
*&      Form  SET_PF_STATUS
*&---------------------------------------------------------------------*
FORM set_pf_status USING tab TYPE slis_t_extab.
  DATA fcode TYPE TABLE OF sy-ucomm.
  APPEND '&SAV' TO tab.
  SET PF-STATUS 'ALVSTAND' EXCLUDING tab.
ENDFORM.                    "SET_PF_STATUS
*&---------------------------------------------------------------------*
*&      Form  EXTRACT_DATA
*&---------------------------------------------------------------------*
FORM extract_data.
  SELECT * FROM edidc INTO TABLE it_edidc
   WHERE docnum  IN docnum
     AND status  IN status
     AND direct  IN direct
     AND idoctp  IN idoctp
     AND cimtyp  IN cimtyp
     AND mestyp  IN mestyp
     AND mescod  IN mescod
     AND mesfct  IN mesfct
     AND sndpor  IN pppor
     AND sndprt  IN ppprt
     AND sndpfc  IN pppfc
     AND sndprn  IN ppprn
     AND credat  IN r_credat
     AND cretim  IN cretim
     AND upddat  IN r_upddat
     AND updtim  IN updtim
   ORDER BY PRIMARY KEY.
ENDFORM.                    " EXTRACT_DATA
*&---------------------------------------------------------------------*
*&      Form  COMBINE_DATA
*&---------------------------------------------------------------------*
FORM combine_data .
  DATA statxt_string TYPE string.
  DEFINE assign_message.
    REPLACE '&' WITH &1 INTO statxt_string.
    CONDENSE statxt_string.
  END-OF-DEFINITION.
  LOOP AT it_edidc.
    MOVE-CORRESPONDING it_edidc TO itab.
    PERFORM convert_by_timezone USING itab-credat itab-cretim.
    itab-credat = e_datlo.
    itab-cretim = e_timlo.
    PERFORM convert_by_timezone USING itab-upddat itab-updtim.
    itab-upddat = e_datlo.
    itab-updtim = e_timlo.
    SELECT * FROM edids WHERE docnum = itab-docnum
                        ORDER BY countr DESCENDING.
      statxt_string = edids-statxt.
      DO 4 TIMES.
        CASE sy-index.
          WHEN 1.
            assign_message edids-stapa1.
          WHEN 2.
            assign_message edids-stapa2.
          WHEN 3.
            assign_message edids-stapa3.
          WHEN 4.
            assign_message edids-stapa4.
        ENDCASE.
      ENDDO.
      itab-statxt = statxt_string.
      EXIT.
    ENDSELECT.

    APPEND itab. CLEAR itab.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  SEND_EMAIL
*&---------------------------------------------------------------------*
FORM send_email .
  PERFORM get_email_list.
  CHECK NOT reclist[] IS INITIAL.
  PERFORM prepare_file.
  PERFORM fulfill_email_para.
  PERFORM document_att_send.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_EMAIL_LIST
*&---------------------------------------------------------------------*
FORM get_email_list .
  cls reclist.
* Get Email List
  SELECT * FROM zemailist INTO TABLE it_zemailist
  WHERE repid = p_repid.
  LOOP AT it_zemailist.
    reclist-receiver = it_zemailist-email.
    reclist-rec_type = 'U'.
    APPEND reclist. CLEAR reclist.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PREPARE_FILE
*&---------------------------------------------------------------------*
FORM prepare_file .
  DATA: BEGIN OF csv_itab OCCURS 0,
          docnum(16),  coma1 VALUE ',',
          status(16),  coma2 VALUE ',',
          direct(16),  coma3 VALUE ',',
          rcvpor(16),  coma4 VALUE ',',
          rcvprt(16),  coma5 VALUE ',',
          rcvprn(16),  coma6 VALUE ',',
          stdmes(16),  coma7 VALUE ',',
          outmod(16),  coma8 VALUE ',',
          sndpor(16),  coma9 VALUE ',',
          sndprt(16),  coma10 VALUE ',',
          sndprn(16),  coma11 VALUE ',',
          credat(16),  coma12 VALUE ',',
          cretim(16),  coma13 VALUE ',',
          mestyp(30),  coma14 VALUE ',',
          idoctp(30),  coma15 VALUE ',',
          cimtyp(30),  coma16 VALUE ',',
          rcvpfc(16),  coma17 VALUE ',',
          sndpfc(16),  coma18 VALUE ',',
          upddat(16),  coma19 VALUE ',',
          updtim(16),  coma20 VALUE ',',
          statxt(255), coma21 VALUE ',',
        END OF csv_itab,
        wa_itab LIKE itab.
  CLEAR p_lines. cls objbin.
  DESCRIBE TABLE objbin LINES p_lines.
  file_start = p_lines + 1.
* Header
  csv_itab-docnum = text-001.
  csv_itab-status = text-002.
  csv_itab-direct = text-003.
  csv_itab-rcvpor = text-004.
  csv_itab-rcvprt = text-005.
  csv_itab-rcvprn = text-006.
  csv_itab-stdmes = text-007.
  csv_itab-outmod = text-008.
  csv_itab-sndpor = text-009.
  csv_itab-sndprt = text-010.
  csv_itab-sndprn = text-011.
  csv_itab-credat = text-012.
  csv_itab-cretim = text-013.
  csv_itab-mestyp = text-014.
  csv_itab-idoctp = text-015.
  csv_itab-cimtyp = text-016.
  csv_itab-rcvpfc = text-017.
  csv_itab-sndpfc = text-018.
  csv_itab-upddat = text-019.
  csv_itab-updtim = text-020.
  csv_itab-statxt = text-021.
  CALL METHOD cl_abap_container_utilities=>fill_container_c
    EXPORTING
      im_value               = csv_itab
    IMPORTING
      ex_container           = objbin-line
    EXCEPTIONS
      illegal_parameter_type = 1
      OTHERS                 = 2.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
               WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.
  APPEND objbin. CLEAR objbin.
* Content
  LOOP AT itab.
    MOVE-CORRESPONDING itab TO csv_itab.
    PERFORM convert_by_timezone USING itab-credat itab-cretim.
    WRITE: e_datlo TO csv_itab-credat,
           e_timlo TO csv_itab-cretim.
    PERFORM convert_by_timezone USING itab-upddat itab-updtim.
    WRITE: e_datlo TO csv_itab-upddat,
           e_timlo TO csv_itab-updtim.
    CALL METHOD cl_abap_container_utilities=>fill_container_c
      EXPORTING
        im_value               = csv_itab
      IMPORTING
        ex_container           = objbin-line
      EXCEPTIONS
        illegal_parameter_type = 1
        OTHERS                 = 2.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                 WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
    APPEND objbin. CLEAR objbin.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  FULFILL_EMAIL_PARA
*&---------------------------------------------------------------------*
FORM fulfill_email_para .
  cls: objpack, objtxt. CLEAR tvarvc.
* Mail Body
  objtxt-line = 'Dears,'.
  APPEND objtxt. CLEAR objtxt.
  APPEND objtxt.

*  SELECT SINGLE * FROM tvarvc
*   WHERE name = cprog_title
*     AND numb = 0.
  objtxt-line = p_title.
  REPLACE '[System]' WITH 'Attached' INTO objtxt-line.
  APPEND objtxt. CLEAR objtxt.
  APPEND objtxt. CLEAR objtxt.

  CONCATENATE 'Time Zone:' s_tzone-low
         INTO objtxt-line SEPARATED BY space.
  APPEND objtxt. CLEAR objtxt.

*  WRITE sy-datum TO objtxt-line.
  PERFORM convert_by_timezone USING sy-datum sy-uzeit.
  WRITE e_datlo TO objtxt-line.
  CONCATENATE 'Execution Date:' objtxt-line INTO objtxt-line
              SEPARATED BY space.
  APPEND objtxt. CLEAR objtxt.

*  WRITE sy-uzeit TO objtxt-line.
  WRITE e_timlo TO objtxt-line.
  CONCATENATE 'Execution Time:' objtxt-line INTO objtxt-line
              SEPARATED BY space.
  APPEND objtxt. CLEAR objtxt.

  CONCATENATE sy-sysid 'Client' sy-mandt
         INTO objtxt-line SEPARATED BY space.
  CONCATENATE 'Source:' objtxt-line
         INTO objtxt-line SEPARATED BY space.
  APPEND objtxt. CLEAR objtxt.
  APPEND objtxt.

  objtxt-line = 'Regards,'.
  APPEND objtxt. CLEAR objtxt.
  objtxt-line = P_disply.
  APPEND objtxt. CLEAR objtxt.
  APPEND objtxt.

* Create the document which is to be sent
  doc_chng-obj_name = 'File'.
*  IF p_rb1 = 'X'.
*    doc_chng-obj_descr = text-101. " Mail subject
*  ELSE.
*    doc_chng-obj_descr = text-102. " Mail subject
*  ENDIF.
  doc_chng-obj_descr = P_title.
  DESCRIBE TABLE objtxt LINES tab_lines.
  tab_lines = 2.
  doc_chng-doc_size = ( tab_lines - 1 ) * 255 + strlen( objtxt ).

  DESCRIBE TABLE itab LINES p_lines.
  tab_lines = p_lines + 1.
  objpack-transf_bin = 'X'.
  objpack-head_start = 1.
  objpack-head_num   = 0.
  objpack-body_start = file_start.
  objpack-body_num   = tab_lines.
  objpack-doc_type   = 'CSV'.
  objpack-obj_name   = 'Attachment'.
  objpack-obj_descr  = p_file. "Attach file name
  objpack-doc_size   = tab_lines * 255.
  APPEND objpack. CLEAR objpack.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  DOCUMENT_ATT_SEND
*&---------------------------------------------------------------------*
FORM document_att_send .
  cls main_text.
  c_sender = p_sender.
  c_display = p_disply.
  TRY.
      send_request = cl_bcs=>create_persistent( ).
      main_text[] = objtxt[].
      document = cl_document_bcs=>create_document(
        i_type    = 'RAW'
        i_text    = main_text
        i_subject = doc_chng-obj_descr ).                   "#EC NOTEXT
      PERFORM assign_binary_content TABLES objpack objbin.
      send_request->set_document( document ).
      LOOP AT reclist.
        mailto = reclist-receiver.
        recipient =
        cl_cam_address_bcs=>create_internet_address( mailto ).
*        SEND_REQUEST->ADD_RECIPIENT( RECIPIENT ).
        send_request->add_recipient(
             EXPORTING
                i_recipient = recipient
                i_express = 'X' ).
      ENDLOOP.
      sender =
      cl_cam_address_bcs=>create_internet_address(
                          i_address_string = c_sender
                          i_address_name = c_display ).
      send_request->set_sender( sender ).
      sent_to_all = send_request->send( i_with_error_screen = 'X' ).
      COMMIT WORK.
      IF sent_to_all IS INITIAL.
        MESSAGE i500(sbcoms) WITH mailto.
      ELSE.
        MESSAGE s022(so).
      ENDIF.
    CATCH cx_bcs INTO bcs_exception.
      MESSAGE i865(so) WITH bcs_exception->error_type.
  ENDTRY.
  CLEAR: main_text, main_text[].
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  ASSIGN_BINARY_CONTENT
*&---------------------------------------------------------------------*
FORM assign_binary_content TABLES tmp_objpack STRUCTURE sopcklsti1
                                  tmp_objbin STRUCTURE objbin.
  DATA: l_bcs_exception TYPE REF TO cx_document_bcs,
        l_reason        TYPE string.
  CLEAR lv_string.
  LOOP AT tmp_objbin.
    p_length = strlen( tmp_objbin-line ).
    p_length = p_length - 2.
    CONCATENATE lv_string tmp_objbin-line gc_crlf INTO lv_string.
  ENDLOOP.
  READ TABLE tmp_objpack INDEX 1.
  IF sy-subrc = 0.
    REFRESH binary_content.
    TRY.
        cl_bcs_convert=>string_to_solix(
          EXPORTING
            iv_string   = lv_string
            iv_codepage = '8300'
*            IV_CODEPAGE = '4103'
            iv_add_bom  = 'X'
          IMPORTING
            et_solix  = binary_content
            ev_size   = size ).
      CATCH cx_bcs.
        RAISE transfer_error.
    ENDTRY.

    TRY.
        document->add_attachment(
*        I_ATTACHMENT_TYPE    = 'xls'
        i_attachment_type    = 'csv'                        "#EC NOTEXT
        i_attachment_subject = tmp_objpack-obj_descr
        i_attachment_size    = size
        i_att_content_hex    = binary_content ).
      CATCH cx_document_bcs INTO l_bcs_exception.
        l_reason = l_bcs_exception->get_text( ).
        MESSAGE l_reason TYPE 'I'.
    ENDTRY.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CONVERT_BY_TIMEZONE
*&---------------------------------------------------------------------*
FORM convert_by_timezone USING p_erdat p_erzet.
  DATA: timezone    TYPE timezone,
        e_timestamp LIKE tzonref-tstamps.
  CLEAR: e_datlo, e_timlo.
  CALL FUNCTION 'GET_SYSTEM_TIMEZONE'
    IMPORTING
      timezone            = timezone
    EXCEPTIONS
      customizing_missing = 1
      OTHERS              = 2.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.
  CALL FUNCTION 'IB_CONVERT_INTO_TIMESTAMP'
    EXPORTING
      i_datlo     = p_erdat
      i_timlo     = p_erzet
      i_tzone     = timezone
    IMPORTING
      e_timestamp = e_timestamp.
  CALL FUNCTION 'IB_CONVERT_FROM_TIMESTAMP'
    EXPORTING
      i_timestamp = e_timestamp
      i_tzone     = s_tzone-low
    IMPORTING
      e_datlo     = e_datlo
      e_timlo     = e_timlo.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CONVERT_SYS_TIMEZONE
*&---------------------------------------------------------------------*
FORM convert_sys_timezone USING p_erdat p_erzet.
  DATA: timezone    TYPE timezone,
        e_timestamp LIKE tzonref-tstamps.
  CLEAR: e_datlo, e_timlo.
  CALL FUNCTION 'GET_SYSTEM_TIMEZONE'
    IMPORTING
      timezone            = timezone
    EXCEPTIONS
      customizing_missing = 1
      OTHERS              = 2.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.

  CALL FUNCTION 'ISU_DATE_TIME_CONVERT_TIMEZONE'
    EXPORTING
      x_date_utc    = p_erdat
      x_time_utc    = p_erzet
      x_timezone    = timezone
    IMPORTING
      y_date_lcl    = e_datlo
      y_time_lcl    = e_timlo
    EXCEPTIONS
      general_fault = 1
      OTHERS        = 2.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.

*  CALL FUNCTION 'IB_CONVERT_INTO_TIMESTAMP'
*    EXPORTING
*      i_datlo     = p_erdat
*      i_timlo     = p_erzet
*      i_tzone     = timezone
*    IMPORTING
*      e_timestamp = e_timestamp.
*  CALL FUNCTION 'IB_CONVERT_FROM_TIMESTAMP'
*    EXPORTING
*      i_timestamp = e_timestamp
*      i_tzone     = timezone
*    IMPORTING
*      e_datlo     = e_datlo
*      e_timlo     = e_timlo.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CONVERT_TIMEZONE
*&---------------------------------------------------------------------*
FORM convert_timezone .
  LOOP AT credat.
    IF NOT credat-low IS INITIAL.
      PERFORM convert_sys_timezone USING credat-low p_uzeit.
      e_dathi_lo = e_datlo + 1.
      assign_range_table r_credat 'I' 'EQ' e_dathi_lo ''.
      r_credat = credat.
      r_credat-low = e_datlo.
    ENDIF.
    IF NOT credat-high IS INITIAL.
      PERFORM convert_sys_timezone USING credat-high p_uzeit.
      e_dathi_hi = e_datlo + 1.
      assign_range_table r_credat 'I' 'EQ' e_dathi_hi ''.
      r_credat = credat.
      r_credat-high = e_datlo.
    ENDIF.
    APPEND r_credat. CLEAR r_credat.
  ENDLOOP.

  LOOP AT upddat.
    IF NOT upddat-low IS INITIAL.
      PERFORM convert_sys_timezone USING upddat-low p_uzeit.
      e_dathi_lo = e_datlo + 1.
      assign_range_table r_upddat 'I' 'EQ' e_dathi_lo ''.
      r_upddat = upddat.
      r_upddat-low = e_datlo.
    ENDIF.
    IF NOT upddat-high IS INITIAL.
      PERFORM convert_sys_timezone USING upddat-high p_uzeit.
      e_dathi_hi = e_datlo + 1.
      assign_range_table r_upddat 'I' 'EQ' e_dathi_hi ''.
      r_upddat = upddat.
      r_upddat-high = e_datlo.
    ENDIF.
    APPEND r_upddat. CLEAR r_upddat.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  SET_SCREEN_ATTRIBUTE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM set_screen_attribute .
  IF p_email = ''.
    LOOP AT SCREEN.
      IF screen-group1 = 'MAL'.
        screen-active = '0'.
        MODIFY SCREEN.
      ENDIF.
    ENDLOOP.
  ENDIF.
ENDFORM.

*Text elements
*----------------------------------------------------------
* 001 Idoc number
* 002 Status
* 003 Direction
* 004 Receiver port
* 005 Part. Type
* 006 Partner Number
* 007 EDI message type
* 008 OutpMod
* 009 Sender port
* 010 Partn.Type
* 011 Partner number
* 012 Created on
* 013 Created at
* 014 Message Type
* 015 Basic type
* 016 Extension
* 017 Partner Role
* 018 Sender partner function
* 019 Changed on
* 020 Time changed
* 021 Message
* 101 [System] Incomplete EDI orders - All
* 102 [System] Incomplete EDI orders - New arrival
* 103 Only for orders that created in the past
* 104 Hours
* E01 Not sent yet
* S01 Completed
* S02 Complet.status set
* T01 Select Options


*Selection texts
*----------------------------------------------------------
* CIMTYP D       .
* CREDAT D       .
* CRETIM D       .
* DIRECT D       .
* DOCNUM D       .
* IDOCTP D       .
* MESCOD D       .
* MESFCT D       .
* MESTYP D       .
* PPPFC D       .
* PPPOR D       .
* PPPRN D       .
* PPPRT D       .
* P_DISPLY         Email Sender Display
* P_EMAIL         Email
* P_FILE         Attachment Filename
* P_REPID         Email Group
* P_SENDER         Email Sender
* P_TITLE         Email Subject
* STATUS D       .
* S_TZONE         Time Zone
* UPDDAT D       .
* UPDTIM D       .


*Messages
*----------------------------------------------------------
*
* Message class: SBCOMS
*500   Document not sent to &1
*
* Message class: SO
*022   Document sent
*865   Error occurred during transmission - return code: <&>

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
