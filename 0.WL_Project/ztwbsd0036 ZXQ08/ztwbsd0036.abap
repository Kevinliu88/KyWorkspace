***********************************************************************
*PROGRAM ID         ZTWBSD0036       T-CODE : ZXQ08
*DESCRIPTION    預採帳-整批匯入轉出明細
*Change History
*    DATE     VERSION      AUTHOR                  DESCRIPTION
* ========== ========  ==============  =================================
* 2023/01/10 V006      Joseph          轉出數量有小數的轉換處理
* 2026/04/27 V007      Tristan         XQ轉出序號不限制95開頭,直接取ZTSD0100最大號+1 (ZTSD0100-ZSEQ)
* 2026/06/09 V008      Tristan         寫入ZTSD0100時須補上VTWEG
*&---------------------------------------------------------------------*
REPORT ztwbsd0036 MESSAGE-ID zodmsd01.


FIELD-SYMBOLS:<dyn_table> TYPE STANDARD TABLE,
              <dyn_wa>,
              <dyn_field>.
DATA: dy_table TYPE REF TO data,
      dy_line  TYPE REF TO data,
      wa_fcat  TYPE lvc_s_fcat,
      it_fcat  TYPE lvc_t_fcat.

DATA: BEGIN OF rt_events OCCURS 0,
        name(30),
        form(30),
      END OF rt_events.

DATA: gt_events   LIKE rt_events OCCURS 0 WITH HEADER LINE,
      gt_fieldcat TYPE slis_t_fieldcat_alv,
      gt_sortinfo TYPE slis_t_sortinfo_alv,
      l_layout    TYPE slis_layout_alv,
      g_variant   TYPE disvariant,
      g_title     TYPE lvc_title,
      gt_extab    TYPE  slis_t_extab.

**ALV
DATA:BEGIN OF gt_alv OCCURS 0,
       vtweg         LIKE ztsd0098-vtweg,
       werks         LIKE ztsd0098-werks.
       INCLUDE STRUCTURE zssd_excel_upload_xq100.
DATA:  zqty          LIKE ztsd0100-zqty,
       zptyp         LIKE ztsd0100-zptyp,
       zbcust        LIKE ztsd0100-zbcust,
       zm090pno      LIKE ztsd0100a-zm090pno,
       zcnt          TYPE i,
       light         TYPE icon-name,
       colinfo       TYPE slis_t_specialcol_alv,
       line_color(4). " Line color
DATA:  END OF gt_alv.

* Kiwi
DATA:BEGIN OF gt_alv_log OCCURS 0,
       vtweg         LIKE ztsd0098-vtweg,
       werks         LIKE ztsd0098-werks.
       INCLUDE STRUCTURE zssd_excel_upload_xq100.
DATA:  zqty          LIKE ztsd0100-zqty,
       zptyp         LIKE ztsd0100-zptyp,
       zbcust        LIKE ztsd0100-zbcust,
       zm090pno      LIKE ztsd0100a-zm090pno,
       zcnt          TYPE i,
       light         TYPE icon-name,
       colinfo       TYPE slis_t_specialcol_alv,
       line_color(4). " Line color
DATA:  END OF gt_alv_log.


DATA: itxq LIKE gt_alv OCCURS 0 WITH HEADER LINE.
DATA: xq_flag(1).

DATA: lock_100n LIKE ztsd0100n OCCURS 0 WITH HEADER LINE.

************************************************************************
* SELECT-OPTIONS / PARAMETERS                                          *
************************************************************************
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME.

  PARAMETERS: p_werks  LIKE ztsd0098-werks MEMORY ID zpwerks,
              p_vtweg  LIKE ztsd0098-vtweg MEMORY ID zpvtweg,
              p_zbcust LIKE ztsd0098-zbcust  MEMORY ID kun.

  PARAMETERS: p_upload RADIOBUTTON GROUP gp1 DEFAULT 'X' USER-COMMAND ucomm,
              p_downld RADIOBUTTON GROUP gp1.
SELECTION-SCREEN END OF BLOCK b1.
SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME.
  PARAMETERS:p_fname  LIKE rlgrap-filename DEFAULT 'C:\temp\ZXQ08_template.xls' OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b2.
************************************************************************
* INITIALIZATION Event                                                 *
************************************************************************
INITIALIZATION.

************************************************************************
* AT SELECTION-SCREEN Events                                           *
************************************************************************
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_fname.
  PERFORM query_filename USING p_fname 'O'.

AT SELECTION-SCREEN OUTPUT.

AT SELECTION-SCREEN ON p_vtweg.
  IF p_upload = 'X'.
    IF p_vtweg IS INITIAL.
      MESSAGE e002(sy) WITH '銷售通路必填'.
    ENDIF.
*檢查權限
    ""  AUTHORITY-CHECK OBJECT 'Z_AUTHORG'
    ""         ID 'ZAUTHORG' FIELD p_vtweg
    ""         ID 'ACTVT' FIELD '01'.
    ""  IF sy-subrc <> 0.
    ""    MESSAGE e002(sy) WITH '無此權限組織的新增權限'.
    ""  ENDIF.
  ENDIF.

AT SELECTION-SCREEN ON p_zbcust.
  IF p_upload = 'X'.
    IF p_zbcust IS INITIAL.
      MESSAGE e002(sy) WITH '客戶必填'.
    ENDIF.
  ENDIF.
************************************************************************
* START-OF-SELECTION Event                                             *
************************************************************************
START-OF-SELECTION.
  CASE 'X'.
    WHEN p_upload.
      PERFORM upload_data.
      PERFORM data_process.
      IF itxq[] IS NOT INITIAL.
        PERFORM output_alv USING 'XQ'.
      ELSE.
        MESSAGE s002(sy) WITH 'No Data'.
      ENDIF.
    WHEN p_downld.
      PERFORM download_template.
  ENDCASE.
************************************************************************
* END-OF-SELECTION Event                                               *
************************************************************************
END-OF-SELECTION.



*&---------------------------------------------------------------------*
*&      Form  QUERY_FILENAME
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_P_DATA  text
*      -->P_0088   text
*----------------------------------------------------------------------*
FORM query_filename USING pi_path  pi_mode.
  DATA:lt_files     TYPE filetable,
       l_file       TYPE file_table,
       l_title      TYPE string,
       l_def_file   TYPE string,
       l_df_directo TYPE string,
       l_subrc      TYPE i.

  DATA: l_string TYPE string.

  l_title = '開啟檔案'.

  MOVE '*.*|*.*' TO l_string.
  l_df_directo  = pi_path.

  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      window_title            = l_title
      default_filename        = l_def_file
      file_filter             = l_string
      initial_directory       = l_df_directo
    CHANGING
      file_table              = lt_files
      rc                      = l_subrc
    EXCEPTIONS
      file_open_dialog_failed = 1
      cntl_error              = 2
      error_no_gui            = 3
      OTHERS                  = 4.
  CHECK sy-subrc = 0.

  LOOP AT lt_files INTO l_file .
    pi_path = l_file.
    EXIT.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  DOWNLOAD_TEMPLATE
*&---------------------------------------------------------------------*
FORM download_template .
  DATA: g_fldnam(25).
  FIELD-SYMBOLS: <fs_value>, <fs_field>.
* Table Schema
  PERFORM assign_field_catalog.
* Create dynamic internal table and assign to FS
  CALL METHOD cl_alv_table_create=>create_dynamic_table
    EXPORTING
      it_fieldcatalog = it_fcat
    IMPORTING
      ep_table        = dy_table.
  ASSIGN dy_table->* TO <dyn_table>.
* Create dynamic work area and assign to FS
  CREATE DATA dy_line LIKE LINE OF <dyn_table>.
  ASSIGN dy_line->* TO <dyn_wa>.

* Field Description
  LOOP AT it_fcat INTO wa_fcat.
    g_fldnam = '<dyn_wa>-' && wa_fcat-fieldname.
    ASSIGN (g_fldnam) TO <fs_field>.
* Description
    READ TABLE gt_fieldcat INTO DATA(wa_fieldcat)
                           WITH KEY fieldname = wa_fcat-fieldname.
    ASSIGN wa_fieldcat-seltext_l TO <fs_value>.
    <fs_field> = <fs_value>.
    AT LAST.
      APPEND <dyn_wa> TO <dyn_table>.
    ENDAT.
  ENDLOOP.

  PERFORM gui_download TABLES <dyn_table>
                        USING p_fname.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  ASSIGN_FIELD_CATALOG
*&---------------------------------------------------------------------*
FORM assign_field_catalog .
  DATA: st_fieldcat TYPE slis_fieldcat_alv,
        wa_fieldcat LIKE st_fieldcat.
  RANGES: r_fieldname FOR st_fieldcat-fieldname.
  DEFINE assign_range_table.
    &1-sign = &2. &1-option = &3.
    &1-low  = &4. &1-high = &5.
    APPEND &1. CLEAR &1.
  END-OF-DEFINITION.
  DEFINE assign_seltext.
    IF wa_fieldcat-fieldname = &1.
      wa_fieldcat-seltext_s = wa_fieldcat-seltext_m =
      wa_fieldcat-seltext_l = wa_fieldcat-reptext_ddic = &2.
      ENDIF.
  END-OF-DEFINITION.

  CALL FUNCTION 'REUSE_ALV_FIELDCATALOG_MERGE'
    EXPORTING
      i_program_name         = sy-repid
      i_structure_name       = 'ZSSD_EXCEL_UPLOAD_XQ100'
      i_inclname             = sy-repid
      i_bypassing_buffer     = 'X'
    CHANGING
      ct_fieldcat            = gt_fieldcat
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2.
  assign_range_table r_fieldname 'I' 'EQ' 'MESSAGE' ''.
  DELETE gt_fieldcat WHERE fieldname IN r_fieldname.
  LOOP AT gt_fieldcat INTO wa_fieldcat.

    assign_seltext: 'ZXQNO'      'XQ 單號',
                    'ZXQSEQ'     'XQ 單序號',
                    'ZYM'        '處理年月',
                    'ZPERIOD'    '期別',
                    'ZQTY_C'     '轉出數量',
                    'ZCORD'      '客戶 PO',
                    'ZSDAT'      '轉出日期',
                    'ZSONO'      '訂單',
                    'ZSOSEQ'     '訂單項目',
                    'ZPNO'       '預採件號',
                    'ZRDAT'      '預計交貨日',
                    'ZREM2'      '備註',
                    'ZINVO'      'Invoice No',
                    'ZETD'       'ETD Date'.

    MODIFY gt_fieldcat FROM wa_fieldcat.
    MOVE-CORRESPONDING wa_fieldcat TO wa_fcat.
    wa_fcat-datatype = 'C'.
    wa_fcat-inttype = 'C'.
    wa_fcat-intlen = 100.
    APPEND wa_fcat TO it_fcat.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GUI_DOWNLOAD
*&---------------------------------------------------------------------*
FORM gui_download TABLES it_out
                  USING  i_filename.
  PERFORM delete_file USING i_filename.

* 如果要下載成EXCEL 所有的欄位屬性都要宣告成CHAR
  CALL FUNCTION 'SAP_CONVERT_TO_XLS_FORMAT'
    EXPORTING
      i_field_seperator = '#' "Field seprator in internal table
      i_line_header     = 'X'
      i_filename        = i_filename
    TABLES
      i_tab_sap_data    = it_out
    EXCEPTIONS
      conversion_failed = 1
      OTHERS            = 2.

  IF sy-subrc <> 0.
    MESSAGE 'Template Download Fail' TYPE 'S' DISPLAY LIKE 'E'.
    LEAVE LIST-PROCESSING.
  ELSE.
    MESSAGE s000 WITH 'Template Download Successfully'.
    LEAVE LIST-PROCESSING.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  DELETE_FILE
*&---------------------------------------------------------------------*
FORM delete_file USING i_file.
  DATA: rc LIKE sy-subrc .
  DATA: rs TYPE abap_bool .
  DATA: fn TYPE string .
  DATA: ifz  LIKE  file_table OCCURS 0 . " WITH HEADER LINE .
  DATA: wfz  LIKE  file_table . " WITH HEADER LINE .
  DATA: y    TYPE  abap_bool VALUE 'X'  .
  DATA: cnt TYPE i .
  DATA: dir TYPE string .
  DATA: flt TYPE string .
  DATA: len(5) TYPE n.
  DATA: lt_split TYPE TABLE OF char300,
        lr_split TYPE REF TO char300.
*拆分路徑及檔名
  SPLIT i_file AT '\' INTO: TABLE lt_split.
  LOOP AT lt_split REFERENCE INTO lr_split.
    AT LAST.
      flt = lr_split->*.
      EXIT.
    ENDAT.
    CONCATENATE dir lr_split->* '\' INTO dir.
  ENDLOOP.
*檢查檔案是否存在
  CALL METHOD cl_gui_frontend_services=>directory_list_files
    EXPORTING
      directory                   = dir              " c:\tmp\2018-12\
      filter                      = flt              " J4KID-BP18037-1130_*.PDF
      files_only                  = y                "
    CHANGING
      file_table                  = ifz              " Type	STANDARD TABLE
      count                       = cnt              " Changing Type  I
    EXCEPTIONS
      cntl_error                  = 1                " #Control error
      directory_list_files_failed = 2
      wrong_parameter             = 3            " #Incorrect parameter
      error_no_gui                = 4               " #Disk full
      not_supported_by_gui        = 5.       " #Access Denied to Source or Destination File
  IF ifz[] IS INITIAL.
    EXIT.
  ENDIF.
*刪除檔案
  fn = i_file.
  CALL METHOD cl_gui_frontend_services=>file_delete
    EXPORTING
      filename             = fn
    CHANGING
      rc                   = rc
    EXCEPTIONS
      file_delete_failed   = 2 "  Could not delete file
      cntl_error           = 2 "  Control error
      error_no_gui         = 3 "  Error: No GUI
      file_not_found       = 4 "  File not found
      access_denied        = 5 "  Access denied
      unknown_error        = 6 "  Unknown error
      not_supported_by_gui = 7 "  GUI does not support this
      wrong_parameter      = 8. "   Wrong parameter
  IF rc = 0 OR rc = 4 .
  ELSE .
    MESSAGE e002(sy) WITH '檔案開啟中無法重新下載'.
  ENDIF .

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  UPLOAD_DATA
*&---------------------------------------------------------------------*
FORM upload_data .
  DATA: l_index TYPE i.
  FIELD-SYMBOLS: <fs>.
  DATA:lt_upload LIKE TABLE OF zssd_excel_upload_xq100 WITH HEADER LINE.
  DATA : lt_data TYPE truxs_t_text_data.
  DATA: l_tabix TYPE sy-tabix.
  DATA: l_end(1).

  DATA:tmp_output_str TYPE string.
  DATA:tmp_type LIKE dd01v-datatype.
  DATA: tmp_p TYPE p DECIMALS 6."V006

  REFRESH: lt_upload.
  CALL FUNCTION 'TEXT_CONVERT_XLS_TO_SAP'
    EXPORTING
      i_field_seperator    = 'X'
      i_line_header        = 'X'
      i_tab_raw_data       = lt_data
      i_filename           = p_fname
    TABLES
      i_tab_converted_data = lt_upload
    EXCEPTIONS
      conversion_failed    = 1
      OTHERS               = 2.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

  REFRESH: gt_alv.
  CLEAR gt_alv.
  LOOP AT lt_upload.
    MOVE-CORRESPONDING lt_upload TO gt_alv.
    gt_alv-zcnt = sy-tabix.
    gt_alv-vtweg = p_vtweg.
    gt_alv-werks = p_werks.
    TRANSLATE gt_alv-zxqno TO UPPER CASE.
    TRANSLATE gt_alv-zsono TO UPPER CASE.
    TRANSLATE gt_alv-zpno TO UPPER CASE.

*若為空白預設系統年月
    IF gt_alv-zym IS INITIAL.
      gt_alv-zym = sy-datum+0(6).
    ENDIF.
*若空白則為01
    IF gt_alv-zperiod IS INITIAL
    OR gt_alv-zperiod = '0'.
      gt_alv-zperiod = '01'.
    ENDIF.

*    V006 Start

    CALL FUNCTION 'NUMERIC_CHECK'
      EXPORTING
        string_in  = gt_alv-zqty_c
      IMPORTING
        string_out = tmp_output_str
        htype      = tmp_type.

    IF tmp_type = 'CHAR'.
      tmp_p = gt_alv-zqty_c.
      gt_alv-zqty_c = tmp_p.
      SHIFT gt_alv-zqty_c LEFT DELETING LEADING space.
    ENDIF.

*    V006 End

*若為空白預設系統日期     2022/07/11 CaroL -Ivy取消預設,強迫必填
*    IF gt_alv-zsdat IS INITIAL.
*     gt_alv-zsdat = sy-datum.
*    ENDIF.


    APPEND gt_alv.
    CLEAR gt_alv.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  DATA_PROCESS
*----------------------------------------------------------------------*
FORM data_process.
  DATA: lock_flag(1),
        l_msg(100)   TYPE c,
        lock_user    TYPE sy-msgv1,
        ls98         TYPE ztsd0098,
        ls99         TYPE ztsd0099,
        ls101        TYPE ztsd0101,
        t_qty        LIKE ztsd0100-zqty,
        p_qty        LIKE ztsd0100-zqty,
        n_qty        LIKE ztsd0100-zqty,
        l_flag(1).

  REFRESH: itxq.
  SORT gt_alv BY vtweg zxqno zym zperiod zcnt.
  LOOP AT gt_alv ASSIGNING FIELD-SYMBOL(<wa>).

    <wa>-light = '2'.  "YELLOW LIGHT   2022/07/11 CaroL

*必填欄位檢查
    PERFORM check_required_field USING '權限組織' <wa>-vtweg
                                 CHANGING l_msg.
    PERFORM assign_msg USING    l_msg
                      CHANGING <wa>-light <wa>-message.

    PERFORM check_required_field USING 'XQ單號' <wa>-zxqno
                                 CHANGING l_msg.
    PERFORM assign_msg USING    l_msg
                      CHANGING <wa>-light <wa>-message.

    PERFORM check_required_field USING '轉出日期' <wa>-zsdat  "2022/07/11 CaroL
                                 CHANGING l_msg.
    PERFORM assign_msg USING    l_msg
                      CHANGING <wa>-light <wa>-message.


    AT NEW zxqno.
      CLEAR: lock_flag,lock_user,xq_flag,ls98.
      REFRESH: lock_100n.
      PERFORM lock_xq USING   <wa>-vtweg
                              <wa>-werks
                              <wa>-zxqno
                      CHANGING l_msg
                               ls98
                               lock_flag.
    ENDAT.
    IF lock_flag = 'X'.
      PERFORM assign_msg USING    l_msg
                         CHANGING <wa>-light <wa>-message.
    ENDIF.

    IF  ls98 IS NOT INITIAL
    AND ls98-zbcust <> p_zbcust.
      CONCATENATE '該 XQ 單不屬於客戶' p_zbcust INTO l_msg.
      PERFORM assign_msg USING    l_msg
                         CHANGING <wa>-light <wa>-message.
    ENDIF.

    PERFORM check_zxqseq CHANGING <wa>-zxqseq
                                  l_msg.
    PERFORM assign_msg USING    l_msg
                       CHANGING <wa>-light <wa>-message.

    PERFORM check_zsoseq CHANGING <wa>-zsoseq
                                  l_msg.
    PERFORM assign_msg USING    l_msg
                       CHANGING <wa>-light <wa>-message.

    CLEAR: ls99.
    SELECT SINGLE *
      INTO ls99
      FROM ztsd0099
     WHERE vtweg = <wa>-vtweg
       AND zxqno = <wa>-zxqno
       AND zxqseq = <wa>-zxqseq.
    IF sy-subrc <> 0.
      l_msg = '該 XQ 單項次不存在'.
      PERFORM assign_msg USING l_msg
                      CHANGING <wa>-light <wa>-message.
    ELSE.
      IF ls99-zxqwrktyp = '8'.
        l_msg = '該 XQ 單項次已結案，不可新增轉出數量'.
        PERFORM assign_msg USING l_msg
                        CHANGING <wa>-light <wa>-message.
      ENDIF.

      IF ls99-zpno <> <wa>-zpno.   "2022/07/11 CaroL
        l_msg = '該 XQ 單件號不一致，不可新增轉出數量'.
        PERFORM assign_msg USING l_msg
                        CHANGING <wa>-light <wa>-message.
      ENDIF.

    ENDIF.

    <wa>-zbcust = ls98-zbcust.
    <wa>-zm090pno = ls99-zpno.

*日期格式檢查
    PERFORM check_yymm  USING '處理年月' CHANGING <wa>-zym l_msg.
    PERFORM assign_msg USING l_msg
                    CHANGING <wa>-light <wa>-message.

    PERFORM check_date_format CHANGING <wa>-zsdat.
    PERFORM check_plausibility USING '轉出日期' CHANGING <wa>-zsdat l_msg.
    PERFORM assign_msg USING l_msg
                    CHANGING <wa>-light <wa>-message.
    PERFORM check_yyyy USING '轉出日期' <wa>-zsdat CHANGING l_msg.
    PERFORM assign_msg USING l_msg
                    CHANGING <wa>-light <wa>-message.

    PERFORM check_date_format CHANGING <wa>-zrdat.
    PERFORM check_plausibility USING '預計交貨日' CHANGING <wa>-zrdat l_msg.
    PERFORM assign_msg USING l_msg
                    CHANGING <wa>-light <wa>-message.
    PERFORM check_yyyy USING '預計交貨日' <wa>-zrdat CHANGING l_msg.
    PERFORM assign_msg USING l_msg
                    CHANGING <wa>-light <wa>-message.

    PERFORM check_date_format CHANGING <wa>-zetd.
    PERFORM check_plausibility USING 'ETD Date' CHANGING <wa>-zetd l_msg.
    PERFORM assign_msg USING l_msg
                    CHANGING <wa>-light <wa>-message.
    PERFORM check_yyyy USING 'ETD Date' <wa>-zetd CHANGING l_msg.
    PERFORM assign_msg USING l_msg
                    CHANGING <wa>-light <wa>-message.

*數量欄位檢查
    PERFORM convert_to_num CHANGING <wa>-zqty_c <wa>-zqty l_msg.
    PERFORM assign_msg USING l_msg
                    CHANGING <wa>-light <wa>-message.

    AT NEW zperiod.
      PERFORM lock_100n USING <wa>-vtweg ls98-zbcust <wa>-zym <wa>-zperiod
                      CHANGING l_msg.
    ENDAT.
    PERFORM assign_msg USING l_msg
                    CHANGING <wa>-light <wa>-message.


*XQ項次總轉出數量檢查:該項次都無錯誤，才檢查總轉出數量
    AT NEW zxqseq.
      CLEAR: l_flag,ls101,t_qty,p_qty,n_qty.
      SELECT SINGLE *
        INTO ls101
        FROM ztsd0101
       WHERE vtweg = <wa>-vtweg
         AND zxqno = <wa>-zxqno
         AND zxqseq = <wa>-zxqseq.
    ENDAT.
    IF <wa>-message = ''
    OR <wa>-light <> '1'.  "Red light.
      t_qty = t_qty + <wa>-zqty.
      IF ls101 IS NOT INITIAL.
        <wa>-zptyp = 'P'.
        p_qty =  p_qty + <wa>-zqty.
      ELSE.
        <wa>-zptyp = 'N'.
        n_qty =  n_qty + <wa>-zqty.
      ENDIF.

    ELSE.
      l_flag = 'X'.
    ENDIF.

    AT END OF zxqseq.
      IF l_flag = ''.
        PERFORM check_zqty USING ls99 t_qty p_qty n_qty
                          CHANGING l_msg.
      ENDIF.
    ENDAT.
    PERFORM assign_msg USING l_msg
                    CHANGING <wa>-light <wa>-message.

    AT END OF zxqno.
      IF xq_flag = ''.
*整張XQ單無錯誤時，才新增轉出明細到DB & 產生傳輸TG資料
        PERFORM proc_ztsd0100 USING <wa>-vtweg
                                    <wa>-zxqno.

        <wa>-light = '3'.  "GREEN LIGHT   2022/07/11 CaroL

      ELSE.
        PERFORM crt_itxq USING <wa>-vtweg
                               <wa>-werks
                               <wa>-zxqno
                               '1'
                               '上傳資料有錯誤，詳見 LOG'.
        PERFORM unlock_xq USING <wa>-vtweg <wa>-werks <wa>-zxqno.
        PERFORM unlock_100n.

      ENDIF.
    ENDAT.
  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  LOCK_XQ
*&---------------------------------------------------------------------*
FORM lock_xq  USING    i_vtweg i_werks i_zxqno
              CHANGING e_msg
                       e_98 STRUCTURE ztsd0098
                       e_flag.


  CLEAR: e_msg,e_flag,e_98.

  SELECT SINGLE *
    INTO e_98
    FROM ztsd0098
   WHERE vtweg = i_vtweg
     AND zxqno = i_zxqno.

  CHECK e_98 IS NOT INITIAL.

  CALL FUNCTION 'ENQUEUE_EZ_ZTSD0098'
    EXPORTING
      mode_ztsd0098  = 'E'
      mandt          = sy-mandt
      werks          = i_werks
      zxqno          = i_zxqno
    EXCEPTIONS
      foreign_lock   = 1
      system_failure = 2
      OTHERS         = 3.
  IF sy-subrc <> 0.
    e_flag = 'X'.  "lock fail
    CONCATENATE 'XQ 單正在處理中，使用者' sy-msgv1 INTO e_msg.
  ENDIF.


ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  ASSIGN_MSG
*&---------------------------------------------------------------------*
FORM assign_msg  USING    i_msg
                 CHANGING e_light
                          e_msg.

  CHECK i_msg <> space.
  IF e_msg <> ''.
    e_msg = e_msg && ';'.
  ENDIF.
  e_light = '1'.  "RED LIGHT
  CONCATENATE e_msg i_msg INTO e_msg.

  xq_flag = 'X'.  "代表整張XQ有存在錯誤


ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  CHECK_ZXQSEQ
*&---------------------------------------------------------------------*
FORM check_zxqseq CHANGING p_xqseq p_msg.

  DATA: l_xqseq LIKE ztsd0099-zxqseq.
  DATA: l_num TYPE p.

  CLEAR: p_msg.

  IF p_xqseq IS INITIAL.
    p_xqseq = '0'.
  ENDIF.

  CALL FUNCTION 'MOVE_CHAR_TO_NUM'
    EXPORTING
      chr             = p_xqseq
    IMPORTING
      num             = l_num
    EXCEPTIONS
      convt_no_number = 1
      convt_overflow  = 2
      OTHERS          = 3.
  IF sy-subrc <> 0.
    MESSAGE e002(sy) WITH 'XQ 項次格式錯誤' INTO p_msg.
  ELSE.
    l_xqseq = p_xqseq.
    PERFORM convert_input  CHANGING l_xqseq.
    p_xqseq = l_xqseq.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CHECK_ZSOSEQ
*&---------------------------------------------------------------------*
FORM check_zsoseq CHANGING p_soseq p_msg.

  DATA: l_soseq LIKE ztsd0100a-zsoseq.
  DATA: l_num TYPE p.

  CLEAR: p_msg.

  IF p_soseq IS INITIAL.
    p_soseq = '0'.
  ENDIF.

  CALL FUNCTION 'MOVE_CHAR_TO_NUM'
    EXPORTING
      chr             = p_soseq
    IMPORTING
      num             = l_num
    EXCEPTIONS
      convt_no_number = 1
      convt_overflow  = 2
      OTHERS          = 3.
  IF sy-subrc <> 0.
    MESSAGE e002(sy) WITH 'SO 項次格式錯誤' INTO p_msg.
  ELSE.
    l_soseq = p_soseq.
    PERFORM convert_input  CHANGING l_soseq.
    p_soseq = l_soseq.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CONVERT_INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      <--P_GT_ALV_ZPOSEX  text
*----------------------------------------------------------------------*
FORM convert_input  CHANGING e_field.
  CHECK e_field IS NOT INITIAL.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = e_field
    IMPORTING
      output = e_field.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CHECK_YYMM
*&---------------------------------------------------------------------*
FORM check_yymm USING i_type CHANGING e_yymm e_msg.
  DATA: yy(4) TYPE n,
        mm(2) TYPE n,
        l_len TYPE i,
        l_num TYPE p.
  CLEAR: e_msg.

  CHECK e_yymm IS NOT INITIAL.

  CALL FUNCTION 'MOVE_CHAR_TO_NUM'
    EXPORTING
      chr             = e_yymm
    IMPORTING
      num             = l_num
    EXCEPTIONS
      convt_no_number = 1
      convt_overflow  = 2
      OTHERS          = 3.
  IF sy-subrc = 0.
    yy = e_yymm+0(4).
    mm = e_yymm+4(2).
  ELSEIF e_yymm CA '/'.
    SPLIT e_yymm AT '/' INTO: yy mm.
  ELSEIF e_yymm CA '.'.
    SPLIT e_yymm AT '.' INTO: yy mm.
  ELSE.
    CONCATENATE i_type '格式錯誤' INTO e_msg.
    EXIT.
  ENDIF.

  SHIFT mm RIGHT DELETING TRAILING space.
  OVERLAY mm WITH '00' ONLY space.
  CONCATENATE yy mm INTO e_yymm.

  l_len = strlen( e_yymm ).
  IF l_len <> 6
  OR yy = 0.
    CONCATENATE i_type '格式錯誤' INTO e_msg.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CHECK_DATE_FORMAT
*&---------------------------------------------------------------------*
FORM check_date_format  CHANGING p_ketdat.
  DATA: result_tab TYPE match_result_tab.
  DATA: patt  TYPE string VALUE '/'.
  DATA:pos1 TYPE i,
       pos2 TYPE i.
  DATA:w_lines LIKE sy-tabix.
  DATA:w_date(10) TYPE c.
  DATA w_date_d TYPE d.


  REFRESH result_tab.
  FIND ALL OCCURRENCES OF patt IN p_ketdat
       RESULTS result_tab.


  DESCRIBE TABLE result_tab LINES w_lines.
**只能有兩個'/ '
  IF w_lines = 2.
**只能有數字,/,跟空白
    IF p_ketdat CO '/0123456789 '.
      SHIFT p_ketdat RIGHT DELETING TRAILING space.

      READ TABLE result_tab INTO DATA(w_tab) INDEX 1.
      pos1 = w_tab-offset.
      READ TABLE result_tab INTO w_tab INDEX 2.
      pos2 = w_tab-offset.
**如果月份小於十，有0或無0都要可以接受
*Ex: 2017/8/30  -> 系統補0
*2017/08/30
      SHIFT p_ketdat LEFT DELETING LEADING space.
      DATA(w_len) = pos2 - pos1.
      IF w_len = 2. "yyyy/m/d or yyyy/m/dd
        w_date(5) = p_ketdat(5).   "yyyy/
        w_date+5(1) = '0'.         "0
        w_date+6(1) = p_ketdat+5(1). "M
        w_date+7(1) = p_ketdat+6(1). "/
        w_date+8(2) = p_ketdat+7(2). "dd
        SHIFT w_date+8(2) RIGHT DELETING TRAILING space.
        OVERLAY w_date+8(2) WITH '00' ONLY space.
      ELSEIF w_len = 3. "yyyy/mm/d or yyyy/mm/dd
        w_date = p_ketdat.
        w_date+8(2) = p_ketdat+8(2). "dd
        SHIFT w_date+8(2) RIGHT DELETING TRAILING space.
        OVERLAY w_date+8(2) WITH '00' ONLY space.
      ENDIF.
      OVERLAY w_date WITH '          ' ONLY '/'.
      CONDENSE w_date NO-GAPS.
      p_ketdat = w_date.
    ENDIF.

  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CHECK_PLAUSIBILITY
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_W_DATE_D  text
*      <--P_P_LIGHT  text
*----------------------------------------------------------------------*
FORM check_plausibility  USING    i_type
                         CHANGING e_date
                                  e_msg.
  DATA:w_date_d TYPE d.

  CLEAR e_msg.
  CHECK e_date IS NOT INITIAL.

  WRITE e_date TO w_date_d.

**合理日期檢查
  CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
    EXPORTING
      date                      = w_date_d
    EXCEPTIONS
      plausibility_check_failed = 1
      OTHERS                    = 2.
  IF sy-subrc <> 0.
    CONCATENATE i_type '格式錯誤' INTO e_msg.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CHECK_YYYY
*&---------------------------------------------------------------------*
FORM check_yyyy  USING    i_type
                          i_date
                 CHANGING e_msg.
  CLEAR: e_msg.
  CHECK i_date IS NOT INITIAL.
*檢查前四碼是否為年yyyy
  IF i_date CA '/'.
    SPLIT i_date AT '/' INTO: DATA(yy)  DATA(mm) DATA(dd).
    DATA(l_len) = strlen( yy ).
    IF l_len <> 4.  "YYYY
      CONCATENATE i_type '格式錯誤' INTO e_msg.
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CONVERT_TO_NUM
*&---------------------------------------------------------------------*
FORM convert_to_num  CHANGING e_qty_c e_qty_n
                              e_msg.
  "DATA: num TYPE p.
  DATA: lv_num_dec TYPE decfloat34.  "或: TYPE p DECIMALS 6
  CLEAR: e_msg.

  " 先清格式（移除逗號、空白）
  PERFORM change_chr_format CHANGING e_qty_c.  "移掉千分位逗號並壓縮空白

  " 允許像 '.43' 這種寫法 → 補 0
  IF e_qty_c CP '.*' AND e_qty_c(1) = '.'.
    e_qty_c = |0{ e_qty_c }|.
  ENDIF.

  " 嘗試轉成十進位浮點/具小數的 Packed
  TRY.
      lv_num_dec = CONV decfloat34( e_qty_c ).
    CATCH cx_sy_conversion_no_number cx_sy_conversion_overflow.
      e_msg = '轉出數量格式錯誤'.
      RETURN.
  ENDTRY.

  " 合法性檢查（含小數）
  IF lv_num_dec <= 0.
    e_msg = '轉出數量不可 <= 0'.
    RETURN.
  ENDIF.

  " 回寫數值欄位與字串欄位
  e_qty_n = CONV #( lv_num_dec ).   "型別會依 ZTSD0100-ZQTY 自動轉
  e_qty_c = |{ lv_num_dec }|.       "或用適合的格式字串
  SHIFT e_qty_c LEFT DELETING LEADING space.

  ""  CALL FUNCTION 'MOVE_CHAR_TO_NUM'
  ""    EXPORTING
  ""      chr             = e_qty_c
  ""    IMPORTING
  ""      num             = num
  ""    EXCEPTIONS
  ""      convt_no_number = 1
  ""      convt_overflow  = 2
  ""      OTHERS          = 3.
  ""  IF sy-subrc <> 0.
  ""    e_msg = '轉出數量格式錯誤'.
  ""  ELSE.
  ""    PERFORM change_chr_format CHANGING e_qty_c.
  ""
  ""    IF num <= 0.
  ""      e_msg = '轉出數量不可 <= 0'.
  ""    ENDIF.
  ""    e_qty_n = e_qty_c.
  ""    SHIFT e_qty_c LEFT DELETING LEADING space.
  ""  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CHANGE_CHR_FORMAT
*&---------------------------------------------------------------------*
FORM change_chr_format CHANGING p_chr.
  CONSTANTS:
    con_comma TYPE c VALUE ','.

  CONDENSE p_chr NO-GAPS.
*清除,千分位
  OVERLAY p_chr WITH '          ' ONLY  con_comma.

  CONDENSE p_chr NO-GAPS.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CHECK_ZQTY
*&---------------------------------------------------------------------*
FORM check_zqty  USING    i_99 STRUCTURE ztsd0099
                          i_t_qty
                          i_p_qty
                          i_n_qty
                 CHANGING e_msg.
  DATA: lqqty07     TYPE zcn7qty,
        lqqty08     TYPE zcn7qty,
        lcvalu1(16),
        lcvalu2(16),
        lqscrap     TYPE zqty100,
        lqtotal     TYPE zqty100,
        ls101       TYPE ztsd0101,
        ls100       TYPE ztsd0100.
  DATA: l_updflag TYPE c.

  CLEAR: e_msg.


*已存在的轉出明細加總
  SELECT *
    INTO ls100
    FROM ztsd0100
   WHERE vtweg = i_99-vtweg
     AND zxqno = i_99-zxqno
     AND zxqseq = i_99-zxqseq
     AND zopr_new <> 'ZXQ08A'.  " 有被迴轉處理過的 不要再撈進來
    CASE ls100-zptyp.
      WHEN 'P'.
        lqqty07 = lqqty07 + ls100-zqty.   "收款後轉出 :P
      WHEN 'N'.
        lqqty08 = lqqty08 + ls100-zqty.   "收款前轉出 :N
    ENDCASE.
    lqtotal = lqtotal + ls100-zqty.
  ENDSELECT.
  lqtotal = lqtotal + i_t_qty.

  lqqty07 = lqqty07 + i_p_qty.   "收款後轉出 :P
  lqqty08 = lqqty08 + i_n_qty.   "收款前轉出 :N

  i_99-zp653bqty = lqqty07.
  i_99-zn653bqty = lqqty08.
  i_99-zqtybalace = i_99-zqty - i_99-zn653bqty - i_99-zp653bqty -
                      i_99-zdn3qty - i_99-zdn4qty - i_99-zcn5qty +
                      i_99-zdn6qty.

  IF i_99-zdn1qty = 0 AND i_99-zdn3qty = 0 AND i_99-zdn4qty = 0.
    IF lqtotal > i_99-zqty.
      WRITE lqtotal TO lcvalu1 NO-GROUPING LEFT-JUSTIFIED.
      CONDENSE lcvalu1.
      WRITE i_99-zqty TO lcvalu2 NO-GROUPING LEFT-JUSTIFIED.
      CONDENSE lcvalu2.
      MESSAGE e038(zmm01) WITH i_99-zxqno i_99-zxqseq lcvalu1 lcvalu2 INTO e_msg.
    ENDIF.
  ELSE.
    lqscrap = i_99-zdn3qty  + i_99-zdn4qty + i_99-zcn5qty + i_99-zdn6qty.
    lqtotal = lqtotal + lqscrap.
    IF lqtotal > i_99-zqty.
      WRITE lqtotal TO lcvalu1 NO-GROUPING LEFT-JUSTIFIED.
      CONDENSE lcvalu1.
      WRITE i_99-zqty TO lcvalu2 NO-GROUPING LEFT-JUSTIFIED.
      CONDENSE lcvalu2.
      MESSAGE e039(zmm01) WITH i_99-zxqno i_99-zxqseq lcvalu1 lcvalu2 INTO e_msg.
    ENDIF.
  ENDIF.
  IF i_99-zcn2qty = 0 AND i_99-zcn7qty = 0.
  ELSE.
    lqtotal = i_99-zcn2qty  + i_99-zcn7qty.
    IF lqtotal > lqqty07.
      WRITE lqqty07 TO lcvalu1 NO-GROUPING LEFT-JUSTIFIED.
      CONDENSE lcvalu1.
      WRITE lqtotal TO lcvalu2 NO-GROUPING LEFT-JUSTIFIED.
      CONDENSE lcvalu2.
      MESSAGE e040(zmm01) WITH i_99-zxqno i_99-zxqseq lcvalu1 lcvalu2 INTO e_msg.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  OUTPUT_ALV
*&---------------------------------------------------------------------*
FORM output_alv USING i_type.

  REFRESH: gt_fieldcat,gt_extab,gt_events,gt_sortinfo.
**顯示欄位資訊
  PERFORM crt_field USING i_type.
**輸出設定
  PERFORM layout_init USING l_layout.

**按鈕控制
  PERFORM exclude_but USING i_type CHANGING gt_extab.

  g_title = TEXT-t02.

  CASE i_type.
    WHEN 'XQ'.
      CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
        EXPORTING
          i_callback_program       = sy-repid
          i_callback_pf_status_set = 'PF_STATUS_SET'
          i_grid_title             = g_title
          is_layout                = l_layout
          it_fieldcat              = gt_fieldcat[]
          it_sort                  = gt_sortinfo[]
          it_events                = gt_events[]
          i_save                   = 'A'
          is_variant               = g_variant
          i_callback_user_command  = 'USER_COMMAND'
        TABLES
          t_outtab                 = itxq[]
        EXCEPTIONS
          program_error            = 1
          OTHERS                   = 2.
    WHEN 'LOG'.
      SORT gt_alv BY zcnt.  "依上傳順序顯示LOG
* Kiwi
      gt_alv_log[] = gt_alv[].
      DELETE gt_alv_log WHERE light = '3'.

      CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
        EXPORTING
          i_callback_program       = sy-repid
          i_callback_pf_status_set = 'PF_STATUS_SET'
          i_grid_title             = g_title
          is_layout                = l_layout
          it_fieldcat              = gt_fieldcat[]
          it_sort                  = gt_sortinfo[]
          it_events                = gt_events[]
          i_save                   = 'A'
          is_variant               = g_variant
          i_screen_start_column    = 10
          i_screen_start_line      = 3
          i_screen_end_column      = 150
          i_screen_end_line        = 20
          i_callback_user_command  = 'USER_COMMAND'
          it_excluding             = gt_extab[]
        TABLES
* Kiwi
*         t_outtab                 = gt_alv[]
          t_outtab                 = gt_alv_log[]
        EXCEPTIONS
          program_error            = 1
          OTHERS                   = 2.
  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CRT_FIELD
*&---------------------------------------------------------------------*
FORM crt_field USING i_type.
  PERFORM assign_field USING 'LIGHT'      ''       'X' ''.
  PERFORM assign_field USING 'MESSAGE'    TEXT-f01 'X' ''.
  PERFORM assign_field USING 'VTWEG'      TEXT-f02 'X' ''.
  PERFORM assign_field USING 'WERKS'      TEXT-f18 'X' ''.
  PERFORM assign_field USING 'ZXQNO'      TEXT-f03 'X' ''.
  IF i_type = 'LOG'.
    PERFORM assign_field USING 'ZXQSEQ'   TEXT-f04 'X' ''.
    PERFORM assign_field USING 'ZYM'      TEXT-f05 '' ''.
    PERFORM assign_field USING 'ZPERIOD'  TEXT-f06 '' ''.
    PERFORM assign_field USING 'ZCORD'    TEXT-f07 '' ''.
    PERFORM assign_field USING 'ZQTY'     TEXT-f08 '' ''.
    PERFORM assign_field USING 'ZSDAT'    TEXT-f09 '' ''.
    PERFORM assign_field USING 'ZSONO'    TEXT-f10 '' ''.
    PERFORM assign_field USING 'ZSOSEQ'   TEXT-f11 '' ''.
    PERFORM assign_field USING 'ZPNO'     TEXT-f12 '' ''.
    PERFORM assign_field USING 'ZRDAT'    TEXT-f13 '' ''.
    PERFORM assign_field USING 'ZREM2'    TEXT-f14 '' ''.
    PERFORM assign_field USING 'ZINVo'    TEXT-f15 '' ''.
    PERFORM assign_field USING 'ZETD'     TEXT-f16 '' ''.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  ASSIGN_FIELD
*&---------------------------------------------------------------------*
FORM assign_field USING i_field i_text i_key i_cfield.
  DATA: st_fieldcate TYPE slis_fieldcat_alv.
*
  st_fieldcate-fieldname  = i_field.
  st_fieldcate-seltext_l  = i_text.
  st_fieldcate-key        = i_key.
  st_fieldcate-cfieldname = i_cfield.
  APPEND st_fieldcate TO gt_fieldcat.
  CLEAR  st_fieldcate.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  LAYOUT_INIT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_L_LAYOUT  text
*----------------------------------------------------------------------*
FORM layout_init USING p_l_layout TYPE slis_layout_alv.
  p_l_layout-colwidth_optimize = 'X'.
  p_l_layout-coltab_fieldname = 'COLINFO'.
  p_l_layout-info_fieldname = 'LINE_COLOR'.
  p_l_layout-lights_fieldname = 'LIGHT'.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  EXCLUDE_BUT
*&---------------------------------------------------------------------*
FORM exclude_but  USING i_type CHANGING pt_extab TYPE slis_t_extab.
  DATA:w_slis_extab TYPE slis_extab.
  REFRESH pt_extab.

  IF i_type = 'LOG'.
    w_slis_extab-fcode = '&LOG'.
    COLLECT w_slis_extab INTO pt_extab.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  user_command
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->W_UCOMM      text
*      -->LS_SELFIELD  text
*----------------------------------------------------------------------*
FORM user_command USING w_ucomm LIKE sy-ucomm
                ls_selfield TYPE slis_selfield.
  CASE w_ucomm.
    WHEN '&LOG'.  "display log
      PERFORM output_alv USING 'LOG'.
    WHEN '&IC1'.
      READ TABLE itxq INDEX ls_selfield-tabindex.
      IF sy-subrc = 0.
        CASE ls_selfield-fieldname.
          WHEN 'ZXQNO'.
            SUBMIT ztwbsd0021 AND RETURN    "ZXQ02
              WITH pcautho = itxq-vtweg
              WITH sczxqno = itxq-zxqno.

        ENDCASE.
      ENDIF.
  ENDCASE.

ENDFORM.                    "user_command
*---------------------------------------------------------------------*
*       FORM PF_STATUS_SET                                            *
*---------------------------------------------------------------------*
FORM pf_status_set USING  extab TYPE slis_t_extab.
  SET PF-STATUS 'ZTWBSD0036' EXCLUDING extab.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PROC_ZTSD0100
*&---------------------------------------------------------------------*
FORM proc_ztsd0100  USING    i_vtweg
                             i_zxqno.
  DATA: wt98     LIKE ztsd0098,
        it99     LIKE ztsd0099 OCCURS 0 WITH HEADER LINE,
        it100    LIKE ztsd0100 OCCURS 0 WITH HEADER LINE,
        it100a   LIKE ztsd0100a OCCURS 0 WITH HEADER LINE,
        it100n   LIKE ztsd0100n OCCURS 0 WITH HEADER LINE,
        wt100n   LIKE ztsd0100n,
        it101    LIKE ztsd0101 OCCURS 0 WITH HEADER LINE,
        max_zseq LIKE ztsd0100n-zseq,
        l_ym     LIKE ztsd0100-zym,
        l_per    LIKE ztsd0100-zperiod,
        gt_out   LIKE gt_alv OCCURS 0 WITH HEADER LINE,
        itou99   LIKE ztsd0099_out OCCURS 0 WITH HEADER LINE,
        ito100   LIKE ztsd0100_out OCCURS 0 WITH HEADER LINE,
        ito10a   LIKE ztsd0100a_out OCCURS 0 WITH HEADER LINE,
        ito101   LIKE ztsd0101_out OCCURS 0 WITH HEADER LINE,
        stcr98   TYPE ztsd0098_crt,
        itcr98   TYPE ztsd0098_crt OCCURS 0 WITH HEADER LINE,
        stou98   TYPE ztsd0098_out,
        itou98   TYPE ztsd0098_out OCCURS 0 WITH HEADER LINE,
        ituomp   LIKE ztmm_uom_map OCCURS 0 WITH HEADER LINE,
        itsd23   LIKE ztsd0023 OCCURS 0 WITH HEADER LINE,
        itsd15   LIKE ztsd0015 OCCURS 0 WITH HEADER LINE,
        lnverno  TYPE zverno.

*Get 已存在的 ztsd0098, ztsd0099 ,ztsd0100,ztsd0100a,ztsd0101
  REFRESH: it99,it100,it100,it100a,it100n,it101,itou99,ito100,ito10a,ito101,itcr98,itou98,ituomp,itsd23,itsd15,gt_out.
  CLEAR : wt98,stcr98,stou98,wt100n.
  SELECT SINGLE *
    INTO wt98
    FROM ztsd0098
   WHERE vtweg = i_vtweg
     AND zxqno = i_zxqno.
  SELECT *
    INTO TABLE it99
    FROM ztsd0099
   WHERE vtweg = i_vtweg
     AND zxqno = i_zxqno.
  SELECT *
    INTO TABLE it100
    FROM ztsd0100
   WHERE vtweg = i_vtweg
     AND zxqno = i_zxqno.
  SELECT *
    INTO TABLE it100a
    FROM ztsd0100a
   WHERE "vtweg = i_vtweg
     "AND
    zxqno = i_zxqno.
  SELECT *
    INTO TABLE it101
    FROM ztsd0101
   WHERE vtweg = i_vtweg
     AND zxqno = i_zxqno.

  LOOP AT gt_alv INTO gt_out WHERE vtweg = i_vtweg
                   AND zxqno = i_zxqno.
    APPEND gt_out.
    CLEAR gt_out.
  ENDLOOP.
  SORT gt_out BY vtweg zxqno zym zperiod zxqseq zcnt.
  LOOP AT gt_out.

    IF  gt_out-zym <> l_ym
    OR gt_out-zperiod <> l_per.
*取得目前ztsd0100n序號最大號
      PERFORM get_101n USING gt_out
                       CHANGING wt100n.
    ENDIF.

    wt100n-zseq  = wt100n-zseq + 1.
    READ TABLE it100n WITH KEY vtweg    = wt100n-vtweg
                               zbcust   = wt100n-zbcust
                               zym      = wt100n-zym
                               zperiod  = wt100n-zperiod.
    IF sy-subrc <> 0.
      APPEND wt100n TO it100n.
    ELSE.
      MODIFY it100n INDEX sy-tabix FROM wt100n
      TRANSPORTING zseq.
    ENDIF.

*Create 轉出明細:it100,it100a
    MOVE-CORRESPONDING gt_out TO it100.

    it100-zseq = wt100n-zseq.
    it100-zopr_new = sy-uname.
    it100-zopd_new = sy-datum.
    it100-zotm_new = sy-uzeit.
* V008 Added by Tristan 2026/06/09 *
    it100-vtweg = i_vtweg.
* V008 End off *

    MOVE-CORRESPONDING gt_out TO it100a.
    it100a-zseq = it100-zseq.
    it100a-zopr_new = it100-zopr_new.
    it100a-zopd_new = it100-zopd_new.
    it100a-zopt_new = it100-zotm_new.

    l_ym = it100-zym.
    l_per = it100-zperiod.
    APPEND: it100,it100a.
    CLEAR: it100,it100a.
  ENDLOOP.

*Update XQ ITEM :it99
  LOOP AT it99.
    CLEAR: it99-zp653bqty,it99-zn653bqty.
    LOOP AT it100 WHERE vtweg  = it99-vtweg
                    AND zxqno  = it99-zxqno
                    AND zxqseq = it99-zxqseq.
      IF it100-zptyp = 'N'.
        it99-zn653bqty = it99-zn653bqty + it100-zqty.
      ELSEIF it100-zptyp = 'P'.
        it99-zp653bqty = it99-zp653bqty + it100-zqty.
      ENDIF.
    ENDLOOP.
    it99-zqtybalace = it99-zqty - it99-zn653bqty - it99-zp653bqty -
                        it99-zdn3qty - it99-zdn4qty - it99-zcn5qty +
                        it99-zdn6qty.
    IF it99-zqtybalace <= 0.
      it99-zqtybalace = 0.
      it99-zxqwrktyp = '8'. "結案
    ELSE.
      it99-zxqwrktyp = '1'. "開立
    ENDIF.
    it99-zopr = sy-uname.
    it99-zopd = sy-datum.
    it99-zopt = sy-uzeit.
    MODIFY it99.
    CLEAR it99.
  ENDLOOP.
*Update XQ: it98
  IF wt98 IS NOT INITIAL.
    LOOP AT it99 WHERE vtweg  = wt98-vtweg
                   AND zxqno  = wt98-zxqno
                   AND zxqwrktyp <> '8'.
      EXIT.
    ENDLOOP.
*XQ項次全部結案時，XQ單為結案
    IF sy-subrc <> 0.
      wt98-zxqsta = '8'.
      wt98-zopr = sy-uname.
      wt98-zopd = sy-datum.
      wt98-zopt = sy-uzeit.
    ENDIF.
  ENDIF.

*建立傳輸檔
*ztsd0098_crt,ztsd0098_out,ztsd0099_out,ztsd0100_out,ztsd0100a_out,ztsd0101_out.

  SELECT * INTO TABLE ituomp FROM ztmm_uom_map.
  SELECT * INTO TABLE itsd23 FROM ztsd0023.
  SELECT * INTO TABLE itsd15 FROM ztsd0015.

*Create ztsd0098_crt,ztsd0098_out.
  IF wt98 IS NOT INITIAL.
    MOVE-CORRESPONDING wt98 TO stou98.
    MOVE-CORRESPONDING wt98 TO stcr98.
    SELECT MAX( zverno )
     INTO lnverno
     FROM ztsd0098_crt
    WHERE "vtweg = wt98-vtweg
      "AND
      zxqno = wt98-zxqno.
    lnverno = lnverno + 1.
    stcr98-zverno = lnverno.
    stcr98-uuid = /bobf/cl_frw_factory=>get_new_key( ).
    stcr98-zout_proc_status = 'N'.
    stcr98-zout_trans_num = stcr98-uuid.
    stcr98-zout_trans_date = sy-datum.
    stcr98-zout_trans_time = sy-uzeit.
    stcr98-zout_trans_name = sy-uname.
    MOVE-CORRESPONDING stcr98 TO stou98.
    CALL FUNCTION 'Z_SD_CONVERT_KUNNR_TO_WLPNO'
      EXPORTING
        i_kunnr                    = stou98-zbcust
      IMPORTING
        e_altkn                    = stou98-zbcust
      EXCEPTIONS
        customer_mapping_not_found = 1
        OTHERS                     = 2.
    CALL FUNCTION 'Z_SD_CONVERT_KUNNR_TO_WLPNO'
      EXPORTING
        i_kunnr                    = stou98-zscust
      IMPORTING
        e_altkn                    = stou98-zscust
      EXCEPTIONS
        customer_mapping_not_found = 1
        OTHERS                     = 2.
    READ TABLE ituomp WITH KEY msehi = stou98-zpnouq.
    IF sy-subrc = 0.
      stou98-zpnouq = ituomp-pguom.
    ENDIF.
    stou98-zaction = 'U'.
    APPEND stcr98 TO itcr98.
    APPEND stou98 TO itou98.

*Create ztsd0099_out.
    LOOP AT it99 WHERE vtweg    = wt98-vtweg
                   AND zxqno    = wt98-zxqno.
      MOVE-CORRESPONDING it99 TO itou99.
      itou99-uuid = stcr98-uuid.
      itou99-zout_proc_status = 'N'.
      itou99-zverno           = stcr98-zverno.
      itou99-zout_trans_num   = stcr98-uuid.
      itou99-zout_trans_date  = sy-datum.
      itou99-zout_trans_time  = sy-uzeit.
      itou99-zout_trans_name  = sy-uname.
      READ TABLE ituomp WITH KEY msehi = itou99-zuq.
      IF sy-subrc = 0.
        itou99-zuq = ituomp-pguom.
      ENDIF.
      READ TABLE itsd23 WITH KEY waers = itou99-zpcur.
      IF sy-subrc = 0.
        itou99-zpcur = itsd23-zcur.
      ENDIF.
      READ TABLE itsd23 WITH KEY waers = itou99-zptwdcur.
      IF sy-subrc = 0.
        itou99-zptwdcur = itsd23-zcur.
      ENDIF.
      READ TABLE itsd23 WITH KEY waers = itou99-zpcnycur.
      IF sy-subrc = 0.
        itou99-zpcnycur = itsd23-zcur.
      ENDIF.
      READ TABLE itsd23 WITH KEY waers = itou99-zusdcur.
      IF sy-subrc = 0.
        itou99-zusdcur = itsd23-zcur.
      ENDIF.
      READ TABLE itsd23 WITH KEY waers = itou99-zwrkcur.
      IF sy-subrc = 0.
        itou99-zwrkcur = itsd23-zcur.
      ENDIF.
      itou99-zaction = 'U'.
      CALL FUNCTION 'Z_SD_CONVERT_KUNNR_TO_WLPNO'
        EXPORTING
          i_kunnr                    = itou99-zbcust
        IMPORTING
          e_altkn                    = itou99-zbcust
        EXCEPTIONS
          customer_mapping_not_found = 1
          OTHERS                     = 2.
      APPEND itou99.
    ENDLOOP.
*Create ztsd0100_out.
    LOOP AT it100 WHERE vtweg = wt98-vtweg AND zxqno = wt98-zxqno.
      MOVE-CORRESPONDING it100 TO ito100.
      ito100-uuid = stcr98-uuid.
      ito100-zverno = lnverno.
      ito100-zout_proc_status = 'N'.
      ito100-zout_trans_num = ito100-uuid.
      ito100-zout_trans_date = sy-datum.
      ito100-zout_trans_time = sy-uzeit.
      ito100-zout_trans_name = sy-uname.
      APPEND ito100.
    ENDLOOP.
*Create ztsd0100a_out.
    LOOP AT it100a WHERE  zxqno = wt98-zxqno. " vtweg = wt98-vtweg AND
      MOVE-CORRESPONDING it100a TO ito10a.
      ito10a-uuid = stcr98-uuid.
      ito10a-zout_proc_status = 'N'.
      ito10a-zverno           = stcr98-zverno.
      ito10a-zout_trans_num   = stcr98-uuid.
      ito10a-zout_trans_date  = sy-datum.
      ito10a-zout_trans_time  = sy-uzeit.
      ito10a-zout_trans_name  = sy-uname.
      ito10a-zaction = 'U'.
      APPEND ito10a.
    ENDLOOP.
*Create ztsd0101_out.
    LOOP AT it101 WHERE vtweg = wt98-vtweg AND zxqno = wt98-zxqno.
      MOVE-CORRESPONDING it101 TO ito101.
      ito101-uuid = stcr98-uuid.
      ito101-zout_proc_status = 'N'.
      ito101-zverno           = stcr98-zverno.
      ito101-zout_trans_num   = stcr98-uuid.
      ito101-zout_trans_date  = sy-datum.
      ito101-zout_trans_time  = sy-uzeit.
      ito101-zout_trans_name  = sy-uname.
      ito101-zaction = 'U'.
      IF ito101-kunrg IS NOT INITIAL.
        CALL FUNCTION 'Z_SD_CONVERT_KUNNR_TO_WLPNO'
          EXPORTING
            i_kunnr                    = ito101-kunrg
          IMPORTING
            e_altkn                    = ito101-kunrg
          EXCEPTIONS
            customer_mapping_not_found = 1
            OTHERS                     = 2.
      ENDIF.
      IF ito101-zbcust IS NOT INITIAL.
        CALL FUNCTION 'Z_SD_CONVERT_KUNNR_TO_WLPNO'
          EXPORTING
            i_kunnr                    = ito101-zbcust
          IMPORTING
            e_altkn                    = ito101-zbcust
          EXCEPTIONS
            customer_mapping_not_found = 1
            OTHERS                     = 2.
      ENDIF.
      READ TABLE ituomp WITH KEY msehi = ito101-zuq.
      IF sy-subrc = 0.
        ito101-zuq = ituomp-pguom.
      ENDIF.
      READ TABLE itsd23 WITH KEY waers = ito101-zcur.
      IF sy-subrc = 0.
        ito101-zcur = itsd23-zcur.
      ENDIF.
      READ TABLE itsd15 WITH KEY vkorg = ito101-zdcvkorg.
      IF sy-subrc = 0.
        ito101-zdcvkorg = itsd15-zp_entity.
      ENDIF.
      READ TABLE itsd15 WITH KEY vkorg = ito101-zdnvkorg.
      IF sy-subrc = 0.
        ito101-zdnvkorg = itsd15-zp_entity.
      ENDIF.
      APPEND ito101.
    ENDLOOP.
  ENDIF.

  MODIFY ztsd0098 FROM wt98.
  MODIFY ztsd0099 FROM TABLE it99.
  MODIFY ztsd0100 FROM TABLE it100.
  MODIFY ztsd0100a FROM TABLE it100a.
  MODIFY ztsd0100n FROM TABLE it100n.

  MODIFY ztsd0098_crt FROM stcr98.
  MODIFY ztsd0098_out FROM TABLE itou98.
  MODIFY ztsd0099_out FROM TABLE itou99.
  MODIFY ztsd0100_out FROM TABLE ito100.
  MODIFY ztsd0100a_out FROM TABLE ito10a.
  MODIFY ztsd0101_out FROM TABLE ito101.

  COMMIT WORK.
  IF sy-subrc <> 0.
    ROLLBACK WORK.
    PERFORM crt_itxq USING wt98-vtweg
                           wt98-werks
                           wt98-zxqno
                           '1'
                           '無法寫入資料庫，請再上傳一次'.
  ELSE.
    PERFORM crt_itxq USING wt98-vtweg
                           wt98-werks
                           wt98-zxqno
                           '3'
                           '轉出明細新增成功'.
  ENDIF.

  PERFORM unlock_xq USING wt98-vtweg wt98-werks wt98-zxqno.
  PERFORM unlock_100n.

  CALL FUNCTION 'Z_SD_ODM_DNCN_XQ_INTERFACE'
    EXPORTING
      i_zauthorg      = wt98-werks
    TABLES
      it_ztsd0098_crt = itcr98.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  LOCK_100N
*&---------------------------------------------------------------------*
FORM lock_100n  USING i_vtweg
                      i_zbcust
                      i_zym
                      i_zperiod
                CHANGING e_msg.
  DATA: l_100n LIKE ztsd0100n.

  CLEAR: e_msg.

  CHECK i_vtweg IS NOT INITIAL
    AND i_zbcust IS NOT INITIAL
    AND i_zym IS NOT INITIAL
    AND i_zperiod IS NOT INITIAL.

  l_100n-vtweg = i_vtweg.
  l_100n-zbcust   = i_zbcust.
  l_100n-zym   = i_zym.
  l_100n-zperiod   = i_zperiod.

*同一張XQ時，相同處理年月只需LOCK一次
  READ TABLE lock_100n WITH KEY vtweg = i_vtweg
                                zbcust   = i_zbcust
                                zym      = i_zym
                                zperiod  = i_zperiod.
  DATA: l100n LIKE ztsd0100n.

  CHECK sy-subrc NE 0.

  CALL FUNCTION 'ENQUEUE_EZ_ZTSD0100N'
    EXPORTING
      mode_ztsd0100n = 'E'
      mandt          = sy-mandt
      vtweg          = l_100n-vtweg
      zbcust         = l_100n-zbcust
      zym            = l_100n-zym
      zperiod        = l_100n-zperiod
      _wait          = 'X'
    EXCEPTIONS
      foreign_lock   = 1
      system_failure = 2
      OTHERS         = 3.
  IF sy-subrc <> 0.
    e_msg =  '轉出明細序號取號失敗(ztsd0100n)'.
  ELSE.
*UNLOCK TABLE使用
    lock_100n-vtweg = i_vtweg.
    lock_100n-zbcust   = i_zbcust.
    lock_100n-zym      = i_zym.
    lock_100n-zperiod  = i_zperiod.
    APPEND lock_100n.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CHECK_REQUIRED_FIELD
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_0980   text
*      -->P_<WA>_ZXQNO  text
*      <--P_L_MSG  text
*----------------------------------------------------------------------*
FORM check_required_field  USING  i_name
                                  i_value
                           CHANGING e_msg.
  CLEAR e_msg.
  IF i_value IS INITIAL.
    CONCATENATE i_name '必填' INTO e_msg.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_101N
*&---------------------------------------------------------------------*
FORM get_101n  USING    ialv STRUCTURE gt_alv
               CHANGING e100n STRUCTURE ztsd0100n.
  DATA: gnouseq LIKE ztsd0100-zseq,
        st100n  LIKE ztsd0100n.

  CLEAR: e100n.
*取得每個客戶已使用的最大序號 (依處理年月+期別分別取號)
*業務新增的轉出明細序號都是從95001編起
  SELECT MAX( zseq )
    INTO gnouseq
    FROM ztsd0100
   WHERE vtweg = ialv-vtweg
     AND zbcust = ialv-zbcust
     AND zym = ialv-zym
     AND zperiod = ialv-zperiod.
* V002 Changed by Tristan 2026/04/27 *
*  IF gnouseq IS INITIAL OR gnouseq < 95000.
*    gnouseq = '95000'.
*  ENDIF.
  IF sy-subrc <> 0.
    CLEAR gnouseq.
  ENDIF.
* V002 End off *
  SELECT SINGLE *
    INTO e100n
    FROM ztsd0100n
   WHERE vtweg  = ialv-vtweg
     AND zbcust = ialv-zbcust
     AND zym = ialv-zym
     AND zperiod = ialv-zperiod.
  IF sy-subrc = 0.
    IF gnouseq > e100n-zseq.
      e100n-zseq = gnouseq.
    ENDIF.
  ELSE.
    MOVE-CORRESPONDING ialv TO e100n.
    e100n-zseq = gnouseq.
  ENDIF.
  e100n-zopr = sy-uname.
  e100n-zopd = sy-datum.
  e100n-zopt = sy-uzeit.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CRT_ITXQ
*&---------------------------------------------------------------------*
FORM crt_itxq USING i_vtweg
                    i_werks
                    i_zxqno
                    i_light
                    i_msg.
  itxq-vtweg = i_vtweg.
  itxq-werks = i_werks.
  itxq-zxqno = i_zxqno.
  itxq-message = i_msg.
  itxq-light = i_light.
  APPEND itxq.
  CLEAR itxq.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  UNLOCK_XQ
*&---------------------------------------------------------------------*
FORM unlock_xq  USING  i_vtweg i_werks i_xqno.

  CHECK i_vtweg IS NOT INITIAL
    AND i_werks IS NOT INITIAL
    AND i_xqno  IS NOT INITIAL.

*unlock XQ
  CALL FUNCTION 'DEQUEUE_EZ_ZTSD0098'
    EXPORTING
      "" vtweg = i_vtweg
      werks = i_werks
      zxqno = i_xqno.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  UNLOCK_XQ
*&---------------------------------------------------------------------*
FORM unlock_100n.

*unlock XQ轉出明細取號
  LOOP AT lock_100n.
    CALL FUNCTION 'DEQUEUE_EZ_ZTSD0100N'
      EXPORTING
        mode_ztsd0100n = 'E'
        mandt          = sy-mandt
        vtweg          = lock_100n-vtweg
        zbcust         = lock_100n-zbcust
        zym            = lock_100n-zym
        zperiod        = lock_100n-zperiod.
  ENDLOOP.

ENDFORM.

*Text elements
*----------------------------------------------------------
* F01 處理訊息
* F02 銷售通路
* F03 XQ 單號
* F04 XQ 項次
* F05 處理年月
* F06 期別
* F07 客戶PO
* F08 轉出數量
* F09 轉出日期
* F10 訂單
* F11 訂單項目
* F12 預採件號
* F13 預計交貨日
* F14 備註
* F15 Invoice No
* F16 ETD Date
* F18 工廠


*Selection texts
*----------------------------------------------------------
* P_DOWNLD         下載模板
* P_FNAME         檔案名稱(*.xls)
* P_UPLOAD         上傳 XQ 轉出明細
* P_VTWEG         配銷通路
* P_WERKS         Plant
* P_ZBCUST         Customer


*Messages
*----------------------------------------------------------
*
* Message class: Hard coded
*   Template Download Fail
*
* Message class: SY
*002   &
*
* Message class: ZMM01
*038   XQ & item &, Turn qty & is more than stock qty &.
*039   XQ & item &, Turn qty(include scrap qty) & is more than stock qty &.
*040   XQ & item &, Turn qty after received & is less than paid qty &.
*
* Message class: ZODMSD01
*000   & & & &

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
