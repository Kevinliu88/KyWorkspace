******************************************************************** 200
* PROGNAME: ZTWBSD0022
* USER    : W O N D E R L A N D
* DISCRIP : 預採帳XQ單明細整批修改作業
* RECORD  :
* VER.    WHEN     WHY                                      WHO
* ------- -------- ---------------------------------------- -----------
*         20190201 Create                                   DENNIS
************************************************************************
* Modification Log - History
*&=====================================================================*
*    DATE     VERSION      AUTHOR                  DESCRIPTION
* ========== ========  ==============  =================================
* 2020/04/23 V001      Fangchyi        檢查權限物件Z_AUTHORG
* 2020/04/30 V002      yinglung        a. 取消單號限制
*                                      b. 顯示所有價格，但已收費不可修改
*                                      c. 增加僅查詢功能，For PM查詢使用
* 2021/04/13 V003       Kiwi           原採購單價若為台幣顥示錯誤
* 2021/06/21 V004      Fangchyi        t-code: ZXQ04_2 只允許查詢單價

************************************************************************

REPORT ztwbsd0022 MESSAGE-ID zmm01 NO STANDARD PAGE HEADING LINE-COUNT 30
                                                            LINE-SIZE 150.

** I N C L U D E   P R O G R A M ***************************************
INCLUDE: ztwrmmi001, <icon>, ztwbsdi022.

** I N I T I A L I Z A T I O N *****************************************
INITIALIZATION.

* AT SELECTION-SCREEN **************************************************
AT SELECTION-SCREEN.
*V001 added by Fangchyi 2020/04/23

  " 250809 移除權限組織的檢查

  "" AUTHORITY-CHECK OBJECT 'Z_AUTHORG'
  ""        ID 'ZAUTHORG' FIELD pcvtweg
  ""        ID 'ACTVT' FIELD '03'.
  "" IF sy-subrc <> 0.
  ""   MESSAGE e000 WITH '無此權限組織的權限'.
  "" ENDIF.

*V001 end off
*V004 marked by Fangchyi
*20200430 yinglung V002 begin
*IF prdtyp1 = 'X'  OR prdtyp2 = 'X' .
*  SELECT SINGLE * FROM ztsd0150
*                  WHERE uname   = sy-uname.
*  IF sy-subrc EQ 0.
*    MESSAGE e000 WITH 'PM無此維護權限'.
*  ENDIF.
*ENDIF.
*20200430 yinglung V002 end
*V004 end off

** S T A R T - O F - S E L E C T I O N *********************************
START-OF-SELECTION.

  PERFORM init.
  PERFORM lesen.
  PERFORM proces.
  IF ithead[] IS INITIAL.
    MESSAGE s001.
    STOP.
  ENDIF.

  CALL SCREEN 6000.
  IF gxdebug = 'X'.
    PERFORM save.
  ENDIF.

** E N D   O F   P R O C E S S *****************************************
END-OF-SELECTION.



** S U B R O U T I N E S ***********************************************
*&---------------------------------------------------------------------*
*&      Form  LESEN
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM lesen .

  DATA: lqtotal TYPE menge_d,
        licount TYPE i,
        steket  LIKE eket,
        litabix TYPE i.

  cls: itsd98, itsd99, ithead.
*  SELECT * INTO CORRESPONDING FIELDS OF TABLE ithead FROM zvsd0003
*   WHERE zauthorg = pcvtweg AND zbcust IN sckunnr
*     AND zxqline IN scxqlin AND zym IN scyyymm
*     AND zperiod IN scperid AND zxqno IN sczxqno
*     AND zxqsta IN scxqsta AND zcpno IN sczcpno
*     AND zcpnocn IN scpnocn AND zxqseq IN snxqseq
*     AND zpno IN sczpnoi AND zxqwrktyp IN scitsts.
  SELECT * INTO TABLE itsd98 FROM ztsd0098
   WHERE vtweg = pcvtweg AND zbcust = pckunnr
     AND zxqline IN scxqlin AND zym IN scyyymm
     AND zperiod IN scperid AND zxqno IN sczxqno
     AND zxqsta IN scxqsta AND zcpno IN sczcpno
     AND zcpnocn IN scpnocn.
*     AND zpno IN sczpnoi.
  IF itsd98[] IS NOT INITIAL.

    SELECT * INTO TABLE itsd99 FROM ztsd0099 FOR ALL ENTRIES IN itsd98
     WHERE vtweg = pcvtweg AND
           zxqno = itsd98-zxqno AND
           zxqseq IN snxqseq AND
           zpno IN sczpnoi AND
           zxqwrktyp IN scitsts.

    LOOP AT itsd98.
      READ TABLE itsd99 WITH KEY vtweg = pcvtweg zxqno = itsd98-zxqno.
      IF sy-subrc <> 0.
        DELETE itsd98.
      ENDIF.
    ENDLOOP.
    IF prdtyp2 = 'X' OR prdtyp3 = 'X'. "20200430 yinglung V002
*20200430 yinglung V002 begin
*      SELECT * APPENDING TABLE itsd99 FROM ztsd0099 FOR ALL ENTRIES IN itsd98
*       WHERE zauthorg = pcvtweg AND
*             zxqno = itsd98-zgroup AND
*             zdn1qty = 0 AND zdn4qty = 0.
*      DELETE itsd99 WHERE ( zdn1qty <> 0 OR zdn4qty <> 0 ).
*20200430 yinglung V002 end
    ENDIF.

  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  PROCES
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM proces .

  DATA: licount     TYPE i,
        lcdname(30) TYPE c,
        lciname(30) TYPE c,
        lcfname(30) TYPE c,
        lcmtype(30) TYPE c,
        lcrtype(30) TYPE c,
        lncount(1)  TYPE n,
        lfdurat     TYPE f,
        lfstday     TYPE f,
        lddatum     TYPE d,
        lcpara0     TYPE char30,
        lcpara1     TYPE char30,
        lddatu2     TYPE d,
        lndayno     TYPE n,
        lxnegat,
        lcmsgv1     TYPE msgv1,
        itkonv      LIKE konv OCCURS 0 WITH HEADER LINE,
        lqlabst     TYPE menge_d,
        lqdmqty     TYPE menge_d,
        lqshqty     TYPE menge_d,
        lqbalan     TYPE menge_d,
        lqtotal     TYPE menge_d,
        lcvbeln     TYPE vbeln,
        litabix     TYPE i.
  FIELD-SYMBOLS: <fs> TYPE any, <fb> TYPE any.

  LOOP AT itsd98.
    CALL FUNCTION 'ENQUEUE_EZ_ZTSD0098'
      EXPORTING
        mode_ztsd0098  = 'E'
        mandt          = sy-mandt
        werks          = itsd98-werks
        zxqno          = itsd98-zxqno
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc <> 0.
      lcmsgv1 = sy-msgv1.
      mm_log_add_message 'E' 'ZMM01' '024' itsd98-zxqno lcmsgv1 '' ''.
      DELETE itsd98.
    ELSE.
      LOOP AT itsd99 WHERE vtweg = itsd98-vtweg AND zxqno = itsd98-zxqno.
        MOVE-CORRESPONDING itsd98 TO sthead.
        MOVE-CORRESPONDING itsd99 TO sthead.
*20200430 yinglung V002 begin
        IF itsd99-zpup_per NE 0.
          sthead-zpup_dis = itsd99-zpup / itsd99-zpup_per.
        ELSE.
          sthead-zpup_dis = itsd99-zpup.
        ENDIF.
* 2021/04/13 V011 Kiwi Begin
        sthead-zpup_amt = sthead-zpup_dis * itsd99-zqty.
        DATA l_zpup TYPE bapicurr-bapicurr.
        CALL FUNCTION 'BAPI_CURRENCY_CONV_TO_EXTERNAL'
          EXPORTING
            currency        = itsd99-zpcur
            amount_internal = sthead-zpup_dis
          IMPORTING
            amount_external = l_zpup.
        sthead-zpup_dis = l_zpup.
* 2021/04/13 V011 Kiwi End

        IF itsd99-zup_per NE 0.
          sthead-zup_dis = itsd99-zup / itsd99-zup_per.
        ELSE.
          sthead-zup_dis = itsd99-zup.
        ENDIF.
        IF itsd99-zptwd_per NE 0.
          sthead-zptwdup_dis = itsd99-zptwdup / itsd99-zptwd_per.
        ELSE.
          sthead-zptwdup_dis = itsd99-zptwdup.
        ENDIF.
* 2021/04/13 V011 Kiwi Begin
        CALL FUNCTION 'BAPI_CURRENCY_CONV_TO_EXTERNAL'
          EXPORTING
            currency        = 'TWD'
            amount_internal = sthead-zptwdup_dis
          IMPORTING
            amount_external = l_zpup.
        sthead-zptwdup_dis = l_zpup.
* 2021/04/13 V011 Kiwi End

        IF itsd99-zpcny_per NE 0.
          sthead-zpcnyup_dis = itsd99-zpcnyup / itsd99-zpcny_per.
        ELSE.
          sthead-zpcnyup_dis = itsd99-zpcnyup.
        ENDIF.
*20200430 yinglung V002 end
        APPEND sthead TO ithead.
      ENDLOOP.
    ENDIF.
  ENDLOOP.

*  LOOP AT ithead INTO sthead.
*    CALL FUNCTION 'ENQUEUE_EZ_ZTSD0098'
*      EXPORTING
*        mode_ztsd0098  = 'E'
*        mandt          = sy-mandt
*        zauthorg       = sthead-zauthorg
*        zxqno          = sthead-zxqno
*      EXCEPTIONS
*        foreign_lock   = 1
*        system_failure = 2
*        OTHERS         = 3.
*    IF sy-subrc <> 0.
*      lcmsgv1 = sy-msgv1.
*      mm_log_add_message 'E' 'ZMM01' '024' sthead-zxqno lcmsgv1 '' ''.
*      DELETE ithead.
*    ENDIF.
*  ENDLOOP.
  post_popup_display.


ENDFORM.                    " PROCES


*&---------------------------------------------------------------------*
*&      Form  INIT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM init .

  DATA: lddatfr     TYPE d,
        lddatto     TYPE d,
        lcfname(30),
        licount     TYPE i,
        lfdec32     TYPE decfloat16,
        loworkr     TYPE REF TO cl_worker_info,
        liwrtyp     TYPE ssi_worker_type,
        lclogin     LIKE sy-batch VALUE 'X',
        lcguion     LIKE sy-batch,
        lcurldr     TYPE string.

  FIELD-SYMBOLS <fs> TYPE any.
  DATA: itline TYPE tline_tab,
        sthead TYPE thead.

  reuse_alv_field_merge 'ZSSD0075' itfloc.
  CASE 'X'.
    WHEN prdtyp1.
      IF sczpnoi[] IS INITIAL AND sczxqno[] IS INITIAL.
        MESSAGE s035.
        STOP.
      ENDIF.
    WHEN prdtyp2.
*2020/04/30 yinglung V002 begin
      IF sczpnoi[] IS INITIAL.
        MESSAGE s035.
        STOP.
      ENDIF.
    WHEN prdtyp3.
      IF sczpnoi[] IS INITIAL.
        MESSAGE s035.
        STOP.
      ENDIF.
*2020/04/30 yinglung V002 end
  ENDCASE.

ENDFORM.



*&---------------------------------------------------------------------*
*&      Module  CCTABS_ACTIVE_TAB_SET OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE cctabs_active_tab_set OUTPUT.
  cctabs-activetab = gstabs-pressed_tab.
  CASE gstabs-pressed_tab.
    WHEN cstabs-tab1.
      gstabs-subscreen = '6001'.
    WHEN cstabs-tab2.
      gstabs-subscreen = '6002'.
    WHEN cstabs-tab3.
      gstabs-subscreen = '6003'.
    WHEN OTHERS.
  ENDCASE.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  STATUS_6000  OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE status_6000 OUTPUT.

  REFRESH itexfc.
  APPEND 'POST' TO itexfc.
  SET PF-STATUS '6000' EXCLUDING itexfc.
  SET TITLEBAR '600'.

  PERFORM create_alv_list.
  PERFORM refresh_alv_list.
ENDMODULE.                 " STATUS_6000  OUTPUT

*&---------------------------------------------------------------------*
*&      Module  STATUS_6000  OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE status_6600 OUTPUT.
  REFRESH itexfc.
  APPEND 'POST' TO itexfc.



  PERFORM create_alv_6600.
  PERFORM refresh_alv_6600.
ENDMODULE.                 " STATUS_6000  OUTPUT


*&---------------------------------------------------------------------*
*&      Form  CREATE_ALV_LIST
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM create_alv_list .
*20200430 YINGLUNG V002 Begin
  DATA: ls_style TYPE lvc_s_styl,
        lt_style TYPE lvc_t_styl.
*20200430 YINGLUNG V002 end

  CHECK orclist IS INITIAL.
  DATA: clhand TYPE REF TO glhandl.
  create_container_object orclist cstlist.
  create_alv_object oralist orclist.
  cls: itfcat.
  lvc_field_merge 'ZSSD0079' itfcat.
*  stlaya-info_fname = 'COLOR'.        "控制某行顏色
  stlaya-stylefname = 'STYLE'.        "控制某行某欄位可否更改
*  stlaya-ctab_fname = 'COLER'.        "控制欄位顏色
  stlaya-sel_mode   = 'A'.
  "A: ALV grid會有最前面的短欄位,可多選, B: 沒有最前面的短欄位,單選
  stlaya-cwidth_opt = 'X'.
  stlaya-no_rowmark = ' '.
  stlaya-zebra = 'X'.
* 不可新增刪除筆數
  stexlu = cl_gui_alv_grid=>mc_fc_loc_copy_row.
  APPEND stexlu TO stexfu.
  stexlu = cl_gui_alv_grid=>mc_fc_loc_delete_row.
  APPEND stexlu TO stexfu.
  stexlu = cl_gui_alv_grid=>mc_fc_loc_append_row.
  APPEND stexlu TO stexfu.
  stexlu = cl_gui_alv_grid=>mc_fc_loc_insert_row.
  APPEND stexlu TO stexfu.
  stexlu = cl_gui_alv_grid=>mc_fc_loc_move_row.
  APPEND stexlu TO stexfu.
  IF prdtyp1 = 'X' OR prdtyp2 = 'X'. "20200430 YINGLUNG V002
    LOOP AT itfcat INTO stfcat.
      CASE stfcat-fieldname.
        WHEN 'KBETF'.
          stfcat-scrtext_s = stfcat-scrtext_m = stfcat-scrtext_l = stfcat-reptext = TEXT-l01.
          MODIFY itfcat FROM stfcat.
        WHEN 'CKBOX'.
          stfcat-edit     = 'X'.
          stfcat-checkbox = 'X'.
          stfcat-outputlen = 4.
          stfcat-scrtext_s = stfcat-scrtext_m = stfcat-scrtext_l = stfcat-reptext = 'SEL'.
          MODIFY itfcat FROM stfcat.
        WHEN 'MANDT' OR 'MENGE' OR 'MEINS' OR 'KNUMV'.
          stfcat-no_out   = 'X'.
          MODIFY itfcat FROM stfcat.
      ENDCASE.
    ENDLOOP.
  ENDIF.
*20200430 YINGLUNG V002 BEGIN
  IF prdtyp3 = 'X'.
    LOOP AT itfcat INTO stfcat.
      CASE stfcat-fieldname.
        WHEN 'ZAUTHORG' OR 'ZXQNO' OR 'ZXQSEQ' OR 'ZYM' OR 'ZBCUST' OR 'ZPNO' OR 'ZSPNO' OR 'ZDESC' OR 'ZPCUR'.
          stfcat-edit     = ''.
          MODIFY itfcat FROM stfcat.
        WHEN 'ZUP_DIS'.
          stfcat-edit     = ''.
          stfcat-scrtext_s = stfcat-scrtext_m = stfcat-scrtext_l = stfcat-reptext = TEXT-l10. "'業務單價'.
          MODIFY itfcat FROM stfcat.
        WHEN 'ZPUP_DIS'.
          stfcat-edit     = ''.
          stfcat-scrtext_s = stfcat-scrtext_m = stfcat-scrtext_l = stfcat-reptext = TEXT-l11. "'原採購單價'.
          MODIFY itfcat FROM stfcat.
        WHEN 'ZPTWDUP_DIS'.
          stfcat-edit     = ''.
          stfcat-scrtext_s = stfcat-scrtext_m = stfcat-scrtext_l = stfcat-reptext = TEXT-l12. "'台幣單價'.
          MODIFY itfcat FROM stfcat.
        WHEN 'ZPCNYUP_DIS'.
          stfcat-edit     = ''.
          stfcat-scrtext_s = stfcat-scrtext_m = stfcat-scrtext_l = stfcat-reptext = TEXT-l13. "'人民幣單價'.
          MODIFY itfcat FROM stfcat.
        WHEN OTHERS.
          stfcat-edit     = ''.
          stfcat-no_out   = 'X'.
          MODIFY itfcat FROM stfcat.
      ENDCASE.
    ENDLOOP.
  ENDIF.
*20200430 YINGLUNG V002 END

*20200430 YINGLUNG V002 BEGIN
  IF prdtyp2 = 'X'.
    LOOP AT ithead INTO sthead WHERE zdn1qty NE 0 OR zdn4qty NE 0.
      ls_style-fieldname = 'CKBOX'.
      ls_style-style = cl_gui_alv_grid=>mc_style_disabled.
      APPEND ls_style TO lt_style.
      sthead-style = lt_style.
      MODIFY ithead FROM sthead.
      CLEAR ls_style.
      REFRESH: lt_style.
    ENDLOOP.
  ENDIF.

*20200430 YINGLUNG V002 END

  CREATE OBJECT clhand.
  SET HANDLER clhand->godetail FOR oralist.
  CALL METHOD oralist->register_edit_event
    EXPORTING
      i_event_id = cl_gui_alv_grid=>mc_evt_modified.
  gs_disvariant-report = sy-repid.
  CALL METHOD oralist->set_table_for_first_display
    EXPORTING
      is_layout            = stlaya
      is_variant           = gs_disvariant
      i_bypassing_buffer   = 'X'
      it_toolbar_excluding = stexfu
      i_save               = 'A'
    CHANGING
      it_fieldcatalog      = itfcat
      it_outtab            = ithead.
*  CALL METHOD oralist->set_ready_for_input
*    EXPORTING
*      i_ready_for_input = 1.
ENDFORM.                    " CREATE_ALV_LIST

*&---------------------------------------------------------------------*
*&      Form  REFRESH_ALV_LIST
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM refresh_alv_list .
  DATA: strowi TYPE lvc_s_row,
        itrowi LIKE strowi OCCURS 0, " WITH HEADER LINE,
        stcolm TYPE lvc_s_col,
        itcolm LIKE stcolm OCCURS 0 WITH HEADER LINE,
        stroid TYPE lvc_s_roid,
        itroid LIKE stroid OCCURS 0 WITH HEADER LINE.
  get_rows oralist itrowi.
  CALL METHOD oralist->refresh_table_display.
  set_rows oralist itrowi 'X'.
  cls itrowi.
ENDFORM.                    " REFRESH_ALV_LIST


*&---------------------------------------------------------------------*
*&      Form  CREATE_ALV_LIST
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM create_alv_6600 .
  CHECK orcdetl IS INITIAL.
  DATA: cl6600 TYPE REF TO glhandl.
  create_container_object orcdetl cstdetl.
  create_alv_object oradetl orcdetl.
  cls: itfcat.
  lvc_field_merge 'ZSSD0075' itfcat.
*  stlaya-info_fname = 'COLOR'.        "控制某行顏色
  stlaya-stylefname = 'STYLE'.        "控制某行某欄位可否更改
*  stlaya-ctab_fname = 'COLER'.        "控制欄位顏色
  stlaya-sel_mode   = 'A'.
  "A: ALV grid會有最前面的短欄位,可多選, B: 沒有最前面的短欄位,單選
  stlaya-cwidth_opt = 'X'.
  stlaya-no_rowmark = ' '.
  stlaya-zebra = 'X'.
* 不可新增刪除筆數
  stexlu = cl_gui_alv_grid=>mc_fc_loc_copy_row.
  APPEND stexlu TO stexfu.
  stexlu = cl_gui_alv_grid=>mc_fc_loc_delete_row.
  APPEND stexlu TO stexfu.
  stexlu = cl_gui_alv_grid=>mc_fc_loc_append_row.
  APPEND stexlu TO stexfu.
  stexlu = cl_gui_alv_grid=>mc_fc_loc_insert_row.
  APPEND stexlu TO stexfu.
  stexlu = cl_gui_alv_grid=>mc_fc_loc_move_row.
  APPEND stexlu TO stexfu.
  stexlu = cl_gui_alv_grid=>mc_fc_loc_cut.
  APPEND stexlu TO stexfu.
  stexlu = cl_gui_alv_grid=>mc_fc_loc_paste.
  APPEND stexlu TO stexfu.
  stexlu = cl_gui_alv_grid=>mc_fc_loc_copy.
  APPEND stexlu TO stexfu.
  stexlu = cl_gui_alv_grid=>mc_fc_loc_paste_new_row.
  APPEND stexlu TO stexfu.
  LOOP AT itfcat INTO stfcat.
    CASE stfcat-fieldname.
      WHEN 'KBETF'.
        stfcat-scrtext_s = stfcat-scrtext_m = stfcat-scrtext_l = stfcat-reptext = TEXT-l01.
        MODIFY itfcat FROM stfcat.
      WHEN 'ZXQSEQ'.
        stfcat-scrtext_s = stfcat-scrtext_m = stfcat-scrtext_l = stfcat-reptext = TEXT-d01.
        MODIFY itfcat FROM stfcat.
      WHEN 'CKBOX'.
        stfcat-edit     = 'X'.
        stfcat-checkbox = 'X'.
        stfcat-outputlen = 4.
        stfcat-scrtext_s = stfcat-scrtext_m = stfcat-scrtext_l = stfcat-reptext = 'SEL'.
        MODIFY itfcat FROM stfcat.
      WHEN 'MANDT' OR 'MENGE' OR 'MEINS' OR 'KNUMV'.
        stfcat-no_out   = 'X'.
        MODIFY itfcat FROM stfcat.
      WHEN 'ZAUTHORG' OR 'ZXQNO' OR 'ZVERNO' OR 'ZBCUST' OR 'ZUNIT' OR 'ZPCNYCUR' OR 'ZUSDCUR'.
      WHEN  'ZOPR' OR 'ZOPD' OR 'ZOPT' OR 'ZOPR_NEW' OR 'ZOPD_NEW' OR 'ZOPT_NEW'.
      WHEN 'ZPUP_DIS' OR 'ZPTWDUP_DIS' OR 'ZPCNYUP_DIS' OR 'ZBASEUP_DIS' OR 'ZUP_DIS' OR 'ZP_ENTITY'.
      WHEN OTHERS.
        stfcat-edit     = 'X'.
        MODIFY itfcat FROM stfcat.
    ENDCASE.
  ENDLOOP.
  CREATE OBJECT cl6600.
  SET HANDLER cl6600->godetail FOR oradetl.
  CALL METHOD oradetl->register_edit_event
    EXPORTING
      i_event_id = cl_gui_alv_grid=>mc_evt_modified.
  gs_disvariant-report = sy-repid.
  CALL METHOD oradetl->set_table_for_first_display
    EXPORTING
      is_layout            = stlaya
      is_variant           = gs_disvariant
      i_bypassing_buffer   = 'X'
      it_toolbar_excluding = stexfu
      i_save               = 'A'
    CHANGING
      it_fieldcatalog      = itfcat
      it_outtab            = itdata.
  CALL METHOD oradetl->set_ready_for_input
    EXPORTING
      i_ready_for_input = 1.
ENDFORM.                    " CREATE_ALV_LIST

*&---------------------------------------------------------------------*
*&      Form  REFRESH_ALV_LIST
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM refresh_alv_6600 .
  DATA: strowi TYPE lvc_s_row,
        itrowi LIKE strowi OCCURS 0, " WITH HEADER LINE,
        stcolm TYPE lvc_s_col,
        itcolm LIKE stcolm OCCURS 0 WITH HEADER LINE,
        stroid TYPE lvc_s_roid,
        itroid LIKE stroid OCCURS 0 WITH HEADER LINE.
  get_rows oradetl itrowi.
  CALL METHOD oradetl->refresh_table_display.
  set_rows oradetl itrowi 'X'.
  cls itrowi.
ENDFORM.                    " REFRESH_ALV_LIST

*&---------------------------------------------------------------------*
*&      Form  SELECT_ALV
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_GCSAVOK  text
*----------------------------------------------------------------------*
FORM select_alv  USING    pcsavok.
  DATA: BEGIN OF itline OCCURS 0,
          fdlin TYPE i,
        END OF itline,
        itfidx  TYPE lvc_t_fidx,
        lifilin TYPE i.
*20200430 yinglung V002 Begin
  DATA: l_chk TYPE c.
  DATA: ls_style         TYPE lvc_s_styl.
  "20200430 yinglung V002 End
  IF pcsavok = 'SALL'.
    CALL METHOD oralist->get_filtered_entries
      IMPORTING
        et_filtered_entries = itfidx.
    LOOP AT itfidx INTO lifilin.
      itline-fdlin = lifilin.
      APPEND itline.
    ENDLOOP.
  ENDIF.
  CASE pcsavok.
    WHEN 'SALL'.
      LOOP AT ithead INTO sthead WHERE ckbox = ''.
        READ TABLE itline TRANSPORTING NO FIELDS WITH KEY fdlin = sy-tabix.
        CHECK sy-subrc NE 0.

*20200430 yinglung V002 Begin
        "sthead-ckbox = 'X'.
        l_chk = 'X'.
        LOOP AT sthead-style INTO ls_style WHERE fieldname EQ 'CKBOX' AND style EQ cl_gui_alv_grid=>mc_style_disabled.
          l_chk = ''.
        ENDLOOP.
        sthead-ckbox = l_chk.
        "20200430 yinglung V002 End
        MODIFY ithead FROM sthead TRANSPORTING ckbox.

      ENDLOOP.
    WHEN 'DALL'.
      LOOP AT ithead INTO sthead WHERE ckbox = 'X'.
        sthead-ckbox = ' '.
        MODIFY ithead FROM sthead TRANSPORTING ckbox.
      ENDLOOP.
  ENDCASE.
ENDFORM.                    " SELECT_ALV


*&---------------------------------------------------------------------*
*&      Module  EXIT_6000  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE exit_6000 INPUT.
  CLEAR ok_code.
  popup_confirm TEXT-i06 TEXT-i07 TEXT-i03 gcanswr.
  IF gcanswr = 'J'.
    IF NOT orclist IS INITIAL.
      cntl_system_method orclist->free.
      cntl_system_method cl_gui_cfw=>flush.
      CLEAR: orclist, orclist.
      cls: ithead.
      CALL FUNCTION 'DEQUEUE_ALL'.
      LEAVE TO SCREEN 0.
    ENDIF.
  ENDIF.
ENDMODULE.                 " EXIT_6000  INPUT

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_6000  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_6000 INPUT.
  CALL METHOD oralist->check_changed_data
    IMPORTING
      e_valid = gxvalid.
  IF gxvalid = ''.
*    CALL METHOD oralvgd->activate_display_protocol.
    EXIT.
  ENDIF.
  gcsavok = ok_code.
  CLEAR: ok_code.
  CASE gcsavok.
    WHEN 'SAVE'.
      PERFORM save.
    WHEN 'MASS'.
*     price
      IF prdtyp3 = 'X'. "20200430 yinglung V002
        "DO NOTHING
      ELSEIF prdtyp2 = 'X'.
        CALL SELECTION-SCREEN '1200' STARTING AT 6 8 ENDING AT 130 16.
        IF sy-subrc <> 0.
          MESSAGE s021.
        ELSE.
          LOOP AT ithead INTO sthead WHERE ckbox = 'X'.
            IF ppzupii IS NOT INITIAL.
              sthead-zup = ppzupii.
            ENDIF.
            IF ppupper IS NOT INITIAL.
              sthead-zup_per = ppupper.
            ENDIF.
            MODIFY ithead FROM sthead TRANSPORTING zpno zdesc zup zup_per.
          ENDLOOP.
          IF sy-subrc <> 0.
            MESSAGE s007.
          ENDIF.
        ENDIF.
*     part no.
      ELSE.
        CALL SELECTION-SCREEN '1100' STARTING AT 6 8 ENDING AT 130 16.
        IF sy-subrc <> 0.
          MESSAGE s021.
        ELSE.
*          SELECT SINGLE * INTO sts130 FROM ztsd0130
*           WHERE zauthorg = pcvtweg AND zpno = pczpnoi.
          IF sy-subrc <> 0.
            MESSAGE s037 WITH pczpnoi.
            EXIT.
          ENDIF.
          IF pczdesc = '' AND pczpnoi <> ''.
            SELECT SINGLE zdesc INTO pczdesc FROM ztsd0093
             WHERE vtweg = pcvtweg AND zbcust = pckunnr AND zpno = pczpnoi.
            IF sy-subrc <> 0.
*              pczdesc = sts130-zpno_cn.
*              pczdesc = sts130-zpno_edesc  && ` ` && sts130-zpno_desc.
              SELECT SINGLE matnr, wl2_thenameoftheerp, wl2_englishspecifications, wl2_erpspecification
                INTO ( @DATA(tmp_matnr), @DATA(tmp_cdesc), @DATA(tmp_espec), @DATA(tmp_cspec) )
                 FROM ztmara WHERE matnr = @pczpnoi.
              IF sy-subrc = 0.
                pczdesc = tmp_espec && ` ` && tmp_cdesc.
              ENDIF.
            ENDIF.
          ENDIF.
          LOOP AT ithead INTO sthead WHERE ckbox = 'X'.
            IF pczpnoi IS NOT INITIAL.
              sthead-zpno = pczpnoi.
            ENDIF.
            IF pczdesc IS NOT INITIAL.
              sthead-zdesc = pczdesc.
            ENDIF.
            MODIFY ithead FROM sthead TRANSPORTING zpno zdesc zup zup_per.
          ENDLOOP.
          IF sy-subrc <> 0.
            MESSAGE s007.
          ENDIF.
        ENDIF.
      ENDIF.
    WHEN 'SALL' OR 'DALL'.
      IF prdtyp3 = ''. "20200430 yinglung V002
        PERFORM select_alv USING gcsavok.
      ENDIF.
    WHEN OTHERS.

  ENDCASE.
ENDMODULE.                 " USER_COMMAND_6000  INPUT

*&---------------------------------------------------------------------*
*&      Form  GODETAIL
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_E_ROW  text
*      -->P_E_COLUMN  text
*----------------------------------------------------------------------*
FORM godetail  USING    psrow STRUCTURE lvc_s_row
                        pscolumn STRUCTURE  lvc_s_col
                        psrowno  STRUCTURE  lvc_s_roid.
  IF pscolumn-fieldname NE 'VBELN'.
    EXIT.
  ENDIF.
  READ TABLE ithead INTO sthead INDEX psrowno-row_id.
  IF sy-subrc = 0.

  ENDIF.
ENDFORM.


*&---------------------------------------------------------------------*
*&      Form  SAVE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM save .


  DATA: itcond  TYPE bapicond OCCURS 0 WITH HEADER LINE,
        itconx  TYPE bapicondx OCCURS 0 WITH HEADER LINE,
        stheax  LIKE bapisdh1x,
        ststyl  TYPE lvc_s_styl,
        ititem  LIKE ztsd0099 OCCURS 0 WITH HEADER LINE,
        sts104  LIKE zssd0104,
        lcperid TYPE ztunym,
        lnverno TYPE zverno,
        BEGIN OF itkeyy OCCURS 0,
          vtweg LIKE ztsd0099-vtweg,
          werks LIKE ztsd0099-werks,
          zxqno LIKE ztsd0099-zxqno,
        END OF itkeyy,
        itou99 LIKE ztsd0099_out OCCURS 0 WITH HEADER LINE,
        ito100 LIKE ztsd0100_out OCCURS 0 WITH HEADER LINE,
        ito10a LIKE ztsd0100a_out OCCURS 0 WITH HEADER LINE,
        ito101 LIKE ztsd0101_out OCCURS 0 WITH HEADER LINE,
        stcr98 TYPE ztsd0098_crt,
        itcr98 TYPE ztsd0098_crt OCCURS 0 WITH HEADER LINE,
        stou98 TYPE ztsd0098_out,
        ituomp LIKE ztmm_uom_map OCCURS 0 WITH HEADER LINE,
        itsd23 LIKE ztsd0023 OCCURS 0 WITH HEADER LINE,
        itsd15 LIKE ztsd0015 OCCURS 0 WITH HEADER LINE,
        stlogi LIKE bapisdls.

  cls itmess.
  IF itmess[] IS NOT INITIAL.
    post_popup_display.
    EXIT.
  ENDIF.
  SELECT * INTO TABLE ituomp FROM ztmm_uom_map.
  SELECT * INTO TABLE itsd23 FROM ztsd0023.
  SELECT * INTO TABLE itsd15 FROM ztsd0015.
  LOOP AT ithead INTO sthead WHERE ckbox = 'X'.
    itkeyy-vtweg = sthead-vtweg.
    itkeyy-zxqno = sthead-zxqno.
    COLLECT itkeyy.
  ENDLOOP.

  LOOP AT itkeyy.
    READ TABLE itsd98 WITH KEY vtweg = itkeyy-vtweg zxqno = itkeyy-zxqno.
    CLEAR lnverno.
    SELECT MAX( zverno ) INTO lnverno FROM ztsd0098_crt WHERE zxqno = itkeyy-zxqno.  " vtweg = itkeyy-vtweg AND
    lnverno = lnverno + 1.
    MOVE-CORRESPONDING itsd98 TO stou98.
*    stou98-zopr = sy-uname.
*    stou98-zopd = sy-datum.
*    stou98-zopt = sy-uzeit.
    MOVE-CORRESPONDING itsd98 TO stcr98.
    stcr98-uuid = /bobf/cl_frw_factory=>get_new_key( ).
    stcr98-zout_proc_status = 'N'.
    stcr98-zout_trans_num = stcr98-uuid.
    stcr98-zout_trans_date = sy-datum.
    stcr98-zout_trans_time = sy-uzeit.
    stcr98-zout_trans_name = sy-uname.
    stcr98-zverno = lnverno.
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
    stou98-zaction = 'I'.
    MODIFY ztsd0098_crt FROM stcr98.
    MODIFY ztsd0098_out FROM stou98.
    cls: itou99, ito100, ito101, ito10a.
    LOOP AT ithead INTO sthead WHERE ckbox = 'X' AND vtweg = itkeyy-vtweg AND zxqno = itkeyy-zxqno.
      UPDATE ztsd0099 SET zpno = sthead-zpno zdesc = sthead-zdesc zup = sthead-zup zup_per = sthead-zup_per
                          zopr = sy-uname zopd = sy-datum zopt = sy-uzeit
       WHERE vtweg = sthead-vtweg AND zxqno = sthead-zxqno AND zxqseq = sthead-zxqseq.
      LOOP AT itsd99 WHERE vtweg = itkeyy-vtweg AND zxqno = itkeyy-zxqno AND zxqseq = sthead-zxqseq.
        itsd99-zpno = sthead-zpno .
        itsd99-zdesc = sthead-zdesc .
        itsd99-zup = sthead-zup .
        itsd99-zup_per = sthead-zup_per.
*        itsd99-zopr = sy-uname .
*        itsd99-zopd = sy-datum .
*        itsd99-zopt = sy-uzeit.
        MODIFY itsd99 TRANSPORTING zpno zdesc zup zup_per zopr zopd zopt.
      ENDLOOP.
    ENDLOOP.
*    LOOP AT itsd99 WHERE vtweg = itkeyy-vtweg AND zxqno = itkeyy-zxqno.
    SELECT * INTO itsd99 FROM ztsd0099 WHERE vtweg = itkeyy-vtweg AND zxqno = itkeyy-zxqno.
      MOVE-CORRESPONDING itsd99 TO itou99.
      itou99-uuid = stcr98-uuid.
      itou99-zout_proc_status = 'N'.
      itou99-zverno           = stcr98-zverno.
      itou99-zout_trans_num   = stcr98-uuid.
      itou99-zout_trans_date  = sy-datum.
      itou99-zout_trans_time  = sy-uzeit.
      itou99-zout_trans_name  = sy-uname.
      itou99-zaction = 'U'.
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
      IF itsd99-zaction = ''.
        itou99-zaction = 'U'.
      ENDIF.
      CALL FUNCTION 'Z_SD_CONVERT_KUNNR_TO_WLPNO'
        EXPORTING
          i_kunnr                    = itou99-zbcust
        IMPORTING
          e_altkn                    = itou99-zbcust
        EXCEPTIONS
          customer_mapping_not_found = 1
          OTHERS                     = 2.
      APPEND itou99.
    ENDSELECT.
    SELECT * INTO CORRESPONDING FIELDS OF TABLE ito100 FROM ztsd0100
     WHERE vtweg = itsd99-vtweg AND zxqno = itsd99-zxqno.  " AND zxqseq = itsd99-zxqseq.
    SELECT * INTO CORRESPONDING FIELDS OF TABLE ito10a FROM ztsd0100a
     WHERE  zxqno = itsd99-zxqno.  " AND zxqseq = itsd99-zxqseq.  vtweg = itsd99-vtweg AND
    SELECT * INTO CORRESPONDING FIELDS OF TABLE ito101 FROM ztsd0101
     WHERE vtweg = itsd99-vtweg AND zxqno = itsd99-zxqno.  " AND zxqseq = itsd99-zxqseq.
    ito100-uuid = stcr98-uuid.
    ito100-zout_proc_status = 'N'.
    ito100-zverno           = stcr98-zverno.
    ito100-zout_trans_num   = stcr98-uuid.
    ito100-zout_trans_date  = sy-datum.
    ito100-zout_trans_time  = sy-uzeit.
    ito100-zout_trans_name  = sy-uname.
    ito100-zaction = 'U'.
    MODIFY ito100 FROM ito100 TRANSPORTING uuid zout_proc_status zverno zout_trans_num zout_trans_date zout_trans_time zout_trans_name zaction
     WHERE zxqno = stcr98-zxqno.  "  AND zxqseq = itsd99-zxqseq.  vtweg = stcr98-vtweg AND
    ito10a-uuid = stcr98-uuid.
    ito10a-zout_proc_status = 'N'.
    ito10a-zverno           = stcr98-zverno.
    ito10a-zout_trans_num   = stcr98-uuid.
    ito10a-zout_trans_date  = sy-datum.
    ito10a-zout_trans_time  = sy-uzeit.
    ito10a-zout_trans_name  = sy-uname.
    ito10a-zaction = 'U'.
    MODIFY ito10a FROM ito10a TRANSPORTING uuid zout_proc_status zverno zout_trans_num zout_trans_date zout_trans_time zout_trans_name zaction
     WHERE  zxqno = stcr98-zxqno.  "  AND zxqseq = itsd99-zxqseq.  vtweg = stcr98-vtweg AND
    ito101-uuid = stcr98-uuid.
    ito101-zout_proc_status = 'N'.
    ito101-zverno           = stcr98-zverno.
    ito101-zout_trans_num   = stcr98-uuid.
    ito101-zout_trans_date  = sy-datum.
    ito101-zout_trans_time  = sy-uzeit.
    ito101-zout_trans_name  = sy-uname.
    ito101-zaction = 'U'.
    MODIFY ito101 FROM ito101 TRANSPORTING uuid zout_proc_status zverno zout_trans_num zout_trans_date
                                           zout_trans_time zout_trans_name zaction
*                                           kunrg zbcust zuq zcur zdcvkorg zdnvkorg
     WHERE  zxqno = stcr98-zxqno.  "  AND zxqseq = itsd99-zxqseq.  vtweg = stcr98-vtweg AND
    LOOP AT ito101 WHERE  zxqno = itsd99-zxqno.  " vtweg = itsd99-vtweg AND
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
      MODIFY ito101.
    ENDLOOP.
    MODIFY ztsd0099_out FROM TABLE itou99.
    MODIFY ztsd0100_out FROM TABLE ito100.
    MODIFY ztsd0101_out FROM TABLE ito101.
    MODIFY ztsd0100a_out FROM TABLE ito10a.
    COMMIT WORK.
*    SUBMIT ztwbsd0025 WITH pcvtweg = itkeyy-zauthorg WITH sczxqno = itkeyy-zxqno WITH scverno = lnverno WITH pxcalrp = 'X' AND RETURN.
    APPEND stcr98 TO itcr98.
  ENDLOOP.
  IF sy-subrc = 0.
    CALL FUNCTION 'Z_SD_ODM_DNCN_XQ_INTERFACE'
      EXPORTING
*       I_UUID          =
        I_ZAUTHORG      = itkeyy-werks "vtweg
      TABLES
        it_ztsd0098_crt = itcr98.
    MESSAGE i022.
    cls ithead.
    CALL FUNCTION 'DEQUEUE_ALL'.
*    PERFORM lesen.
*    PERFORM proces.
    LEAVE TO SCREEN 0.
  ELSE.
    MESSAGE s007.
  ENDIF.

ENDFORM.

*Text elements
*----------------------------------------------------------
* 002 Input
* 003 Sales Organization
* 004 Download data OK
* 005 Input sales org. is not correct.
* 006 No record selected
* 017 File path is wrong
* F01 Customer Material No
* F02 Model Number
* F03 Quantity
* F04 Line type
* F05 Major category
* F06 UNPAY sort
* I03 Caution
* I06 Will exit program!
* I07 Are you sure to exit program?
* I08 Exit current screen, data not saved will be dismissed.
* I09 Are you sure to exit?
* L01 Price From
* L02 Price From Currency
* L03 Price From Per
* L04 Price From UOM
* L05 Price To
* L06 Price To Currency
* L07 Price To Per
* L08 Price To UOM
* L09 Update Message
* L10 Sales Unit Price
* L11 Original Pur Unit Price
* L12 TWD Pur Unit Price
* L13 CNY Pur Unit Price


*Selection texts
*----------------------------------------------------------
* PCKUNNR         Customer
* PCVTWEG         Distribution Channel
* PCZDESC         English Description
* PCZPNOI         Preget material number
* PPUPPER         Sales price unit
* PPZUPII         Sales price
* PRDTYP1         Modify part no.
* PRDTYP2         Modify group price
* PRDTYP3         Query Price
* SCITSTS         Item status
* SCPERID         Period
* SCPNOCN         Model Number
* SCWERKS         Plant
* SCXQLIN         Line
* SCXQSTA         Status
* SCYYYMM         Month
* SCZCPNO         Customer Material No
* SCZPNOI         Preget material number
* SCZXQNO         XQ number
* SNXQSEQ         Item serial

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
