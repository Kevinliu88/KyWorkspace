*&---------------------------------------------------------------------*
*&  Include           ZTWRMMI001
*&---------------------------------------------------------------------*
DATA: gilines  TYPE i,
      gcsign   LIKE raldb-sign,
      gcoption LIKE raldb-option.

CONSTANTS: twd    LIKE tcurc-waers VALUE 'TWD',
           yes    VALUE 'J',
           no     VALUE 'N',
           cancel VALUE 'A'.

DATA: stmarm LIKE marm,
      itcurc LIKE tcurc   OCCURS 0 WITH HEADER LINE,
      BEGIN OF itbdct OCCURS 0.
        INCLUDE STRUCTURE bdcdata.
DATA: END OF itbdct,
BEGIN OF itmsgt OCCURS 10.
  INCLUDE STRUCTURE bdcmsgcoll.
DATA: ltext(80) TYPE c,
END OF itmsgt,
itinrv  LIKE inriv OCCURS 0 WITH HEADER LINE,
      stmcha  LIKE mcha,
      itclba  LIKE clbatch  OCCURS 0 WITH HEADER LINE,
      stclba  LIKE clbatch,
      gccname LIKE klah-class,
      gierrct TYPE i,
      gitotct TYPE i,
      gispell TYPE i,
      gisucct TYPE i,
      gcvalid,
      gxtestf,
      stspel  LIKE spell,
      gcumode LIKE bdc_struc-bdcmode VALUE 'N',
      stpara  LIKE pri_params,
      stssfc  TYPE ssfcrescl,
      stcntl  TYPE ssfctrlop,                  "PRINT CONTROL
      stoupp  TYPE ssfcompop,                  "OUPPUT CONTROL
      gcformn TYPE tdsfname,
      stfcre  TYPE ssfcresop,
      gcfmnam TYPE rs38l_fnam,
      gxdebug,
      BEGIN OF itexrt OCCURS 0,
        waers LIKE csks-kostl,
        ukurs LIKE tcurr-ukurs,
        ffact LIKE tcurr-ffact,
        tfact LIKE tcurr-tfact,
      END   OF itexrt,
      gfexrat LIKE tcurr-ukurs,
      gflocfr LIKE tcurr-tfact,
      gfforfr LIKE tcurr-ffact,
      BEGIN OF itmesb OCCURS 0,
        kostl      LIKE csks-kostl,
        error(100),
        belnr      LIKE bkpf-belnr,
        gjahr      LIKE bkpf-gjahr,
        stats(10),
      END   OF itmesb,
      BEGIN OF itsyst OCCURS 0,
        msgid LIKE sy-msgid,
        msgty LIKE sy-msgty,
        msgno LIKE sy-msgno,
        msgv1 LIKE sy-msgv1,
        msgv2 LIKE sy-msgv2,
        msgv3 LIKE sy-msgv3,
        msgv4 LIKE sy-msgv4,
        subrc LIKE sy-subrc,
      END   OF itsyst,
      BEGIN OF gssepa,
        001(220),002(220),003(220),004(220),005(220),006(220),007(220),008(220),009(220),010(220),
        011(220),012(220),013(220),014(220),015(220),016(220),017(220),018(220),019(220),020(220),
        021(220),022(220),023(220),024(220),025(220),026(220),027(220),028(220),029(220),030(220),
        031(220),032(220),033(220),034(220),035(220),036(220),037(220),038(220),039(220),040(220),
        041(220),042(220),043(220),044(220),045(220),046(220),047(220),048(220),049(220),050(220),
        051(220),052(220),053(220),054(220),055(220),056(220),057(220),058(220),059(220),060(220),
        061(220),062(220),063(220),064(220),065(220),066(220),067(220),068(220),069(220),070(220),
        071(220),072(220),073(220),074(220),075(220),076(220),077(220),078(220),079(220),080(220),
        081(220),082(220),083(220),084(220),085(220),086(220),087(220),088(220),089(220),090(220),
        091(220),092(220),093(220),094(220),095(220),096(220),097(220),098(220),099(220),100(220),
        101(220),102(220),103(220),104(220),105(220),106(220),107(220),108(220),109(220),110(220),
        111(220),112(220),113(220),114(220),115(220),116(220),117(220),118(220),119(220),120(220),
        121(220),122(220),123(220),124(220),125(220),126(220),127(220),128(220),129(220),130(220),
        131(220),132(220),133(220),134(220),135(220),136(220),137(220),138(220),139(220),140(220),
        141(220),142(220),143(220),144(220),145(220),146(220),147(220),148(220),149(220),150(220),
        151(220),152(220),153(220),154(220),155(220),156(220),157(220),158(220),159(220),160(220),
        161(220),162(220),163(220),164(220),165(220),166(220),167(220),168(220),169(220),170(220),
        171(220),172(220),173(220),174(220),175(220),176(220),177(220),178(220),179(220),180(220),
        181(220),182(220),183(220),184(220),185(220),186(220),187(220),188(220),189(220),190(220),
        191(220),192(220),193(220),194(220),195(220),196(220),197(220),198(220),199(220),200(220),
        201(220),202(220),203(220),204(220),205(220),206(220),207(220),208(220),209(220),210(220),
        211(220),212(220),213(220),214(220),215(220),216(220),217(220),218(220),219(220),220(220),
        221(220),222(220),223(220),224(220),225(220),226(220),227(220),228(220),229(220),230(220),
        231(220),232(220),233(220),234(220),235(220),236(220),237(220),238(220),239(220),240(220),
        241(220),242(220),243(220),244(220),245(220),246(220),247(220),248(220),249(220),250(220),
        251(220),252(220),253(220),254(220),255(220),256(220),257(220),258(220),259(220),260(220),
        261(220),262(220),263(220),264(220),265(220),266(220),267(220),268(220),269(220),270(220),
        271(220),272(220),273(220),274(220),275(220),276(220),277(220),278(220),279(220),280(220),
      END OF gssepa.

DATA: stoutp       LIKE bapiache09,
      stachd       LIKE bapiache09,
      itscit       LIKE TABLE OF bapiacgl09 WITH HEADER LINE,  "
      itcrat       LIKE TABLE OF bapiaccr09 WITH HEADER LINE,  "currency amount
      itacap       LIKE TABLE OF bapiacap09 WITH HEADER LINE,  "AP
      itaccp       LIKE TABLE OF bapiackec9 WITH HEADER LINE,  "COPA
      ittext       LIKE STANDARD TABLE OF tline WITH HEADER LINE,
      gcobjct      LIKE thead-tdobject,
      gcttdid      LIKE thead-tdid,
      stt001       LIKE t001,
      itt001       LIKE t001 OCCURS 0 WITH HEADER LINE,
      gcatinn      LIKE cabn-atinn,
      gcokcod(20),                     " Temp OK Code
      gcmessg(220),
      gdbudat      TYPE d,
      gngjahr      LIKE ccss-gjahr,    "øÈ§J¶~
      gngermn      LIKE coep-perio,    "øÈ§J§Î
      gncuryr      LIKE ccss-gjahr,    "≤{¶b¶~
      gncurmn      LIKE coep-perio,    "≤{¶b§Î
      gnpjahr      LIKE ccss-gjahr,    "§W§@¶~
      gnpermn      LIKE coep-perio,    "§W§@§Î
      gnzjahr      LIKE ccss-gjahr,    "µ≤ßÙ¶~
      gnzermn      LIKE coep-perio.    "µ≤ßÙ§Î
DATA: gcvkorg LIKE tvko-vkorg,
      gcwerks LIKE t001w-werks,
      gcvtweg LIKE tvtw-vtweg,
      gcspart LIKE tspa-spart,
      gckunnr LIKE kna1-kunnr.

RANGES: rcgjahr FOR bkpf-gjahr,
        rcaufnr FOR aufk-aufnr,
        rcobjnr FOR coss-objnr,
        rcwerks FOR t001l-werks,
        rcvkorg FOR tvko-vkorg,
        rcsetnm FOR setnode-subsetname,
        rcauart FOR aufk-auart,
        rcktsch FOR afvc-ktsch,
        rcmatnr FOR mara-matnr,
        rcvornr FOR afvc-vornr,
        rckostl FOR csks-kostl,
        rdfkdat FOR vbrk-fkdat,
        rdpedat FOR vbrk-fkdat,
        rdperio FOR coep-perio,
        rchkont FOR bseg-hkont,
        rcbelnr FOR bkpf-belnr.

DATA: gs_disvariant TYPE disvariant,
      itstrn        TYPE TABLE OF string WITH HEADER LINE,
      gstitl        LIKE gssepa,
      gnyerno(4)    TYPE n,
      gnyyyno(3)    TYPE n,
      gnmmmno(2)    TYPE n,
      gndddno(2)    TYPE n,
      itftab        TYPE TABLE OF string WITH HEADER LINE,
      gcrepid       LIKE sy-repid.

FIELD-SYMBOLS <fsitstrn> LIKE itstrn.

* Messages display
DATA: itmeok TYPE bapirettab WITH HEADER LINE.
DATA: itmess TYPE bapirettab WITH HEADER LINE.
DATA: gxifprt,
      ok_code(20),
      gxvalid,
      gcsavok(20),
      gxerror,
      gcanswr.

TYPE-POOLS: slis.
DATA: itfild  TYPE slis_t_fieldcat_alv,
      itfil2  TYPE slis_t_fieldcat_alv,
      itsort  TYPE slis_t_sortinfo_alv,
      itsorg  TYPE lvc_t_sort,
      stsorg  TYPE lvc_s_sort,
      itsorv  TYPE lvc_t_sort  WITH HEADER LINE,        "Sort information
      stsort  TYPE slis_sortinfo_alv,
      stlayo  TYPE slis_layout_alv,
      stglay  TYPE lvc_s_glay,
      stkeyi  TYPE slis_keyinfo_alv,
      itgrrp  TYPE slis_t_sp_group_alv,
      itevnt  TYPE slis_t_event,
      itlish  TYPE slis_t_listheader,
      stprnt  TYPE slis_print_alv,
      gcpfsts TYPE slis_formname,
      gcuscom TYPE slis_formname,
      gcvarit LIKE disvariant-variant,
      gcobjky TYPE objnum,
      itlsco  TYPE lvc_t_scol WITH HEADER LINE,
      gxstopx,
      stvari  LIKE disvariant,
      itcolr  TYPE slis_t_specialcol_alv.

DATA: itdect TYPE TABLE OF sy-ucomm,
      itbmss LIKE bapiret2 OCCURS 0 WITH HEADER LINE,
      italls LIKE bapi1003_alloc_values_num OCCURS 0 WITH HEADER LINE,
      italch LIKE bapi1003_alloc_values_char OCCURS 0 WITH HEADER LINE,
      italur LIKE bapi1003_alloc_values_curr OCCURS 0 WITH HEADER LINE,
      itfcct TYPE slis_t_fieldcat_alv,
      stfcct TYPE slis_fieldcat_alv.

*  S C R E E N  C O N T R O L  D E C L A R A T I O N  ******************
DATA: oredit1 TYPE REF TO c_textedit_control,
      oredit2 TYPE REF TO c_textedit_control,
      ordokcn TYPE REF TO cl_gui_docking_container,
      orctgrp TYPE REF TO cl_gui_custom_container,
      cstanrr TYPE scrfname VALUE 'CTTANR',
      orctdtl TYPE REF TO cl_gui_custom_container,
      csdetll TYPE scrfname VALUE 'CTDETL',
      oralvgd TYPE REF TO cl_gui_alv_grid,
      oralvgg TYPE REF TO cl_gui_alv_grid,
      oralvrs TYPE REF TO cl_gui_alv_grid,
      itsrow  TYPE lvc_t_row,
      stsrow  TYPE lvc_s_row,
      itrown  TYPE lvc_t_roid,
      strown  TYPE lvc_s_roid,
      itfcat  TYPE lvc_t_fcat,
      stfcat  TYPE lvc_s_fcat,
      stlaya  TYPE lvc_s_layo,
      stcell  TYPE lvc_s_cell,
      itcell  TYPE lvc_t_cell,
      itexfc  TYPE TABLE OF sy-ucomm,
      itexcl  TYPE slis_t_extab,
      stexfu  TYPE ui_functions,
      stexlu  TYPE ui_func,
      iteent  TYPE slis_t_event WITH HEADER LINE.

DATA: stindx      LIKE indx,
      gcuname     LIKE sy-uname,
      gcmemid(22),
      gcmemix(50).

FIELD-SYMBOLS <fcat> TYPE lvc_s_fcat.

DATA: cstlist   TYPE scrfname VALUE 'CTLIST',
      cstdetl   TYPE scrfname VALUE 'CTDETL',
      cstvarvc  TYPE scrfname VALUE 'CTVARVC',
      oralist   TYPE REF TO cl_gui_alv_grid,
      oradetl   TYPE REF TO cl_gui_alv_grid,
      oratvarvc TYPE REF TO cl_gui_alv_grid,
      orclist   TYPE REF TO cl_gui_custom_container,
      orcdetl   TYPE REF TO cl_gui_custom_container,
      orctvarvc TYPE REF TO cl_gui_custom_container.

* BDC variables
DATA: itbdcd  LIKE bdcdata OCCURS 0 WITH HEADER LINE,
      itbdcm  LIKE bdcmsgcoll OCCURS 0 WITH HEADER LINE,
      gcbdcmo LIKE ctu_params-dismode VALUE 'N'.

** C L A S S   D E F I N I T I O N *************************************
CLASS glmethd    DEFINITION DEFERRED.
CLASS cl_gui_cfw DEFINITION LOAD.
*---------------------------------------------------------------------*
*       CLASS glmethd DEFINITION
*---------------------------------------------------------------------*
*       ........                                                      *
*---------------------------------------------------------------------*
CLASS glmethd DEFINITION.

  PUBLIC SECTION.
    METHODS:
      godetail FOR EVENT double_click OF cl_gui_alv_grid
        IMPORTING e_row e_column es_row_no,
      on_after_user_command FOR EVENT after_user_command OF cl_gui_alv_grid
        IMPORTING e_ucomm e_saved e_not_processed,
      on_after_refresh FOR EVENT after_refresh OF cl_gui_alv_grid,
      on_data_changed FOR EVENT data_changed OF cl_gui_alv_grid
        IMPORTING er_data_changed e_onf4 e_onf4_before e_onf4_after e_ucomm,
      on_chg_finished FOR EVENT data_changed_finished OF cl_gui_alv_grid
        IMPORTING et_good_cells.

ENDCLASS.                    "lcl_application DEFINITION

** C L A S S  I M P L E M E N T A T I O N -----------------------------
*---------------------------------------------------------------------*
*       CLASS glmethd IMPLEMENTATION
*---------------------------------------------------------------------*
*       ........                                                      *
*---------------------------------------------------------------------*
CLASS glmethd IMPLEMENTATION.
  METHOD godetail.
    RETURN. "ATC
  ENDMETHOD.                    "handle_alv_drop
  METHOD on_after_user_command.
*    IF e_ucomm = '&SORT_ASC' OR
*       e_ucomm = '&SORT_DSC'.
*    PERFORM alv_refresh_action.
*    ENDIF.
    RETURN. "ATC
  ENDMETHOD.                   "on_AFTER_USER_COMMAND
  METHOD on_after_refresh.
*    PERFORM alv_refresh_action.
    RETURN. "ATC
  ENDMETHOD.                    "on_AFTER_REFRESH
  METHOD on_data_changed.
*    PERFORM data_chg USING er_data_changed.
    RETURN. "ATC
  ENDMETHOD.                    "on_DATA_CHANGED
  METHOD on_chg_finished.
*    PERFORM chg_finish USING et_good_cells.
    RETURN. "ATC
  ENDMETHOD.                    "on_DATA_CHANGED

ENDCLASS.                    "lcl_application IMPLEMENTATION
DATA: orappli TYPE REF TO glmethd.

DEFINE string_length.
  CALL FUNCTION 'STRING_LENGTH'
    EXPORTING
      string        = &1
   IMPORTING
     length        = &2.
END-OF-DEFINITION.

DEFINE read_exchange_rate.
  CALL FUNCTION 'READ_EXCHANGE_RATE'
    EXPORTING
      date             = &1
      foreign_currency = &2
      local_currency   = &3
      type_of_rate     = &4
*     EXACT_DATE       = ' '
    IMPORTING
      exchange_rate    = &5
      foreign_factor   = &6
      local_factor     = &7
    EXCEPTIONS
      no_rate_found    = 1
      no_factors_found = 2
      no_spread_found  = 3
      derived_2_times  = 4
      overflow         = 5
      zero_rate        = 6
      OTHERS           = 7.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.
END-OF-DEFINITION.

DEFINE spell_qty.
  CALL FUNCTION 'HR_IN_CHG_INR_WRDS'
    EXPORTING
      amt_in_num              = &1
   IMPORTING
     amt_in_words             = &2
   EXCEPTIONS
     data_type_mismatch       = 1
     OTHERS                   = 2.
  REPLACE ALL OCCURRENCES OF 'CRORE' IN &2 WITH 'TEN MILLION'.
  REPLACE ALL OCCURRENCES OF 'LAKH' IN &2 WITH 'HUNDRED THOUSAND'.
  REPLACE ALL OCCURRENCES OF 'NIL' IN &2 WITH 'ZERO'.

END-OF-DEFINITION.

DEFINE get_material_char.
  gcobjky = &1.
  CALL FUNCTION 'BAPI_OBJCL_GETDETAIL'
    EXPORTING
      objectkey              = gcobjky
      objecttable            = 'MARA'
      classnum               = 'ZC'
      classtype              = '001'
    TABLES
      allocvaluesnum         = italls
      allocvalueschar        = italch
      allocvaluescurr        = italur
      return                 = itbmss.

END-OF-DEFINITION.

DEFINE get_material_char_za.
  gcobjky = &1.
  CALL FUNCTION 'BAPI_OBJCL_GETDETAIL'
    EXPORTING
      objectkey              = gcobjky
      objecttable            = 'MARA'
      classnum               = 'ZA'
      classtype              = '001'
    TABLES
      allocvaluesnum         = italls
      allocvalueschar        = italch
      allocvaluescurr        = italur
      return                 = itbmss.

END-OF-DEFINITION.

DEFINE char_key.
  CALL FUNCTION 'CONVERSION_EXIT_ATINN_INPUT'
    EXPORTING
      input        = &1
   IMPORTING
     output        = &2.
END-OF-DEFINITION.

DEFINE vb_get_char.
  CALL FUNCTION 'VB_BATCH_GET_DETAIL'
    EXPORTING
      matnr              = &1
      charg              = &2
      werks              = &3
      get_classification = 'X'
      read_from_buffer   = ' '
    IMPORTING
      ymcha              = &4
      classname          = &5
    TABLES
      char_of_batch      = &6
    EXCEPTIONS
      no_material        = 1
      no_batch           = 2
      no_plant           = 3
      material_not_found = 4
      plant_not_found    = 5
      no_authority       = 6
      batch_not_exist    = 7
      lock_on_batch      = 8
      OTHERS             = 9.
END-OF-DEFINITION.

DEFINE app_to.
  APPEND &1 TO &2.
  CLEAR  &1.
END-OF-DEFINITION.

DEFINE vb_set_char.
  CALL FUNCTION 'VB_CHANGE_BATCH'
    EXPORTING
      ymcha          = &1
      kzcla          = '1'
      xkcfc          = 'X'
      buffer_refresh = 'X'
    IMPORTING
      ymcha          = &1
    TABLES
      char_of_batch  = &2
      return         = &3
    EXCEPTIONS
      OTHERS         = 1.
END-OF-DEFINITION.
DEFINE mm_log_initialize.
  CLEAR: itmess[], itmess.
END-OF-DEFINITION.

DEFINE mm_log_add_message.
  itmess-type = &1.
  itmess-id = &2.
  itmess-number = &3.
  itmess-message_v1 = &4.
  itmess-message_v2 = &5.
  itmess-message_v3 = &6.
  itmess-message_v4 = &7.
  MESSAGE ID itmess-id TYPE 'S' NUMBER itmess-number
          INTO itmess-message
          WITH itmess-message_v1 itmess-message_v2
               itmess-message_v3 itmess-message_v4.
  APPEND itmess.
*  CLEAR itmess.
END-OF-DEFINITION.

DEFINE post_popup_display.
  IF itmess[] IS NOT INITIAL AND
     sy-batch = space AND
     sy-binpt = space.
    CALL FUNCTION 'OXT_MESSAGE_TO_POPUP'
      EXPORTING
        it_message = itmess[]
      EXCEPTIONS
        OTHERS     = 1.
    REFRESH itmess.
  ENDIF.
END-OF-DEFINITION.

DEFINE mm_ok_add_message.
  itmeok-type = &1.
  itmeok-id = &2.
  itmeok-number = &3.
  itmeok-message_v1 = &4.
  itmeok-message_v2 = &5.
  itmeok-message_v3 = &6.
  itmeok-message_v4 = &7.
  MESSAGE ID itmeok-id TYPE 'S' NUMBER itmeok-number
          INTO itmeok-message
          WITH itmeok-message_v1 itmeok-message_v2
               itmeok-message_v3 itmeok-message_v4.

  MESSAGE ID itmeok-id TYPE 'S' NUMBER itmeok-number
          WITH itmeok-message_v1 itmeok-message_v2
               itmeok-message_v3 itmeok-message_v4.
  APPEND itmeok.
  CLEAR itmeok.
END-OF-DEFINITION.

DEFINE post_ok_popup_display.
  IF itmeok[] IS NOT INITIAL AND
     sy-batch = space AND
     sy-binpt = space.
    CALL FUNCTION 'OXT_MESSAGE_TO_POPUP'
      EXPORTING
        it_message = itmeok[]
      EXCEPTIONS
        OTHERS     = 1.
    REFRESH itmeok.
  ENDIF.
END-OF-DEFINITION.

DEFINE mm_log_popup_display.
  IF itmess[] IS NOT INITIAL AND
     sy-batch = space AND
     sy-binpt = space.
    CLEAR gcanswr.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        text_question = 'ERROR Information'
      IMPORTING
        answer        = gcanswr
      EXCEPTIONS
        OTHERS        = 1.
    IF gcanswr = '1'. "Yes
      CALL FUNCTION 'OXT_MESSAGE_TO_POPUP'
        EXPORTING
          it_message = itmess[]
        EXCEPTIONS
          OTHERS     = 1.
    ENDIF.
  ENDIF.
END-OF-DEFINITION.
DATA: limod TYPE i.
DEFINE change_intensify.    "DATA: limod TYPE i. should be declared
  limod = sy-tabix MOD 2.
  IF limod = 0.
    FORMAT INTENSIFIED OFF.
  ELSE.
    FORMAT INTENSIFIED ON.
  ENDIF.
END-OF-DEFINITION.

DEFINE first_day_of_months.
  &2 = &1.
  &2+6(2) = '01'.
END-OF-DEFINITION.

DEFINE last_day_of_months.
  CALL FUNCTION 'LAST_DAY_OF_MONTHS'
    EXPORTING
      day_in            = &1
    IMPORTING
      last_day_of_month = &2
    EXCEPTIONS
      day_in_no_date    = 1
      OTHERS            = 2.
END-OF-DEFINITION.

DEFINE week_get_first_day.
  CALL FUNCTION 'WEEK_GET_FIRST_DAY'
    EXPORTING
      week         = &1
    IMPORTING
      date         = &2
    EXCEPTIONS
      week_invalid = 1
      OTHERS       = 2.
END-OF-DEFINITION.

DEFINE date_get_week.
  CALL FUNCTION 'DATE_GET_WEEK'
    EXPORTING
      date         = &1
    IMPORTING
      week         = &2
    EXCEPTIONS
      date_invalid = 01.
END-OF-DEFINITION.

DEFINE insert_range.
  &1-sign   = 'I'.
  &1-option = 'EQ'.
  &1-low    = &2.
  APPEND &1. CLEAR &1.
END-OF-DEFINITION.

DEFINE exclude_range.
  &1-sign   = 'E'.
  &1-option = 'EQ'.
  &1-low    = &2.
  APPEND &1. CLEAR &1.
END-OF-DEFINITION.


DEFINE pattrn_range.
  &1-sign   = 'I'.
  &1-option = 'CP'.
  &1-low    = &2.
  APPEND &1. CLEAR &1.
END-OF-DEFINITION.

DEFINE between_range.
  &1-sign   = 'I'.
  &1-option = 'BT'.
  &1-low    = &2.
  &1-high   = &3.
  APPEND &1. CLEAR &1.
END-OF-DEFINITION.

DEFINE select_all.
  &1-sel = 'X'.
  MODIFY &1 TRANSPORTING sel WHERE sel = space.
END-OF-DEFINITION.

DEFINE deselect_all.
  &1-sel = ' '.
  MODIFY &1 TRANSPORTING sel WHERE sel = 'X'.
END-OF-DEFINITION.

DEFINE delete_flag.
  &1-del = 'X'.
  MODIFY &1 TRANSPORTING del WHERE sel = 'X'.
END-OF-DEFINITION.

DEFINE undelete.
  &1-del = ' '.
  MODIFY &1 TRANSPORTING del WHERE sel = 'X'.
END-OF-DEFINITION.

DEFINE delete_entry.
  DELETE &1 WHERE sel = 'X'.
END-OF-DEFINITION.

DEFINE message_build.
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

DEFINE unlock_all.
  CALL FUNCTION 'DEQUEUE_ALL'.
*     EXPORTING
*          _SYNCHRON = ' '.
END-OF-DEFINITION.

DEFINE cls.
  REFRESH &1. CLEAR &1.
END-OF-DEFINITION.

DEFINE leave_back.
  IF r_fa = 'X'.
    LEAVE TO SCREEN 1100.
  ELSE.
    LEAVE TO SCREEN 1200.
  ENDIF.
END-OF-DEFINITION.

DEFINE select_one_item.
  IF sy-subrc <> 0 .
    MESSAGE w000 WITH 'Ë´##Â∞ëÈ#Êì#∏ÄÂàó'.
    leave_back.
  ENDIF.
END-OF-DEFINITION.

DEFINE error_message.
  MESSAGE e000 WITH &1.
END-OF-DEFINITION.

DEFINE append_pf.
  &1-&2 = '&3'.
  APPEND &1.
END-OF-DEFINITION.

DEFINE append_itab.
  &1-&2 = &3.  APPEND &1.
END-OF-DEFINITION.

DEFINE define_table.
  DATA: &1 LIKE &2 OCCURS &3 WITH HEADER LINE.
END-OF-DEFINITION.

DEFINE get_icon.
  DESCRIBE TABLE &1 LINES gilines.
  IF gilines > 0.
    READ TABLE &1 INDEX 1.
*   if &1-low <> space.
    &2 = 'ICON_DISPLAY_MORE'.
*   else.
*     &2 = 'ICON_ENTER_MORE'.
*   endif.
  ELSE.
    &2 = 'ICON_ENTER_MORE'.
    CLEAR &1.
  ENDIF.

  CALL FUNCTION 'ICON_CREATE'
    EXPORTING
      name                  = &2
      text                  = space
    IMPORTING
      result                = &3
    EXCEPTIONS
      icon_not_found        = 01
      outputfield_too_short = 02.

END-OF-DEFINITION.

DEFINE icon_create.
  CALL FUNCTION 'ICON_CREATE'
    EXPORTING
      name                  = &1
      text                  = space
    IMPORTING
      result                = &2
    EXCEPTIONS
      icon_not_found        = 01
      outputfield_too_short = 02.

END-OF-DEFINITION.

DEFINE multi_selections.
  CALL FUNCTION 'COMPLEX_SELECTIONS_DIALOG'
    EXPORTING
      title             = &1
*     signed            = 'X'
*     no_interval_check = ' '
    TABLES
      range             = &2
    EXCEPTIONS
      no_range_tab      = 1
      cancelled         = 2
      internal_error    = 3
      OTHERS            = 4.
  DESCRIBE TABLE &2 LINES gilines.
  IF gilines = 0.
    CLEAR &2.
  ENDIF.
END-OF-DEFINITION.

DEFINE get_option.

  READ TABLE &1 INDEX 1.
  gcoption = &1-option.
  gcsign   = &1-sign.
  CALL FUNCTION 'RS_SET_SELECT_OPTIONS_OPTIONS'
       EXPORTING
           high                = space
           low                 = space
           option              = gcoption
           option_set          = 'INI'
           selcname            = space
           selctext            = space
           sign                = gcsign
*          COMPLEX_SELECTIONS  = ' '
       IMPORTING
           option              = gcoption
           sign                = gcsign
       EXCEPTIONS
           delete_line         = 1
           not_executed        = 2
           OTHERS              = 3.

  CASE sy-subrc.
    WHEN 0.
      &1-option = gcoption.
      &1-sign   = gcsign.
      MODIFY &1 INDEX 1.
    WHEN 1.
      DELETE &1 INDEX 1.
      CLEAR &1.
  ENDCASE.
END-OF-DEFINITION.

DEFINE get_range.
  CALL FUNCTION 'SELOPTS_INPUT_ADJUST'
    CHANGING
      sign   = &1
      option = &2
      low    = &3
      high   = &4
    EXCEPTIONS
      OTHERS = 4.
  IF sy-subrc <> 0.
    SET CURSOR FIELD &5.
    MESSAGE e650(db).
  ENDIF.
  IF &3  IS INITIAL AND &4 IS INITIAL.
*   delete &6   index 1.          "if existing, delete old value
  ELSE.
    MODIFY &6   INDEX 1.
    IF sy-subrc <> 0.
      APPEND &6.
    ENDIF.
  ENDIF.
  IF &1 EQ 'I' AND 'EQ/BT' CS &2 OR &1 EQ 'E' AND 'NE/NB' CS &2.
    CLEAR: &1, &2.
  ENDIF.
END-OF-DEFINITION.

DEFINE alpha_input.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = &1
    IMPORTING
      output = &1.

END-OF-DEFINITION.

DEFINE zalpha_input.

* added by Marie 2025/01/15 *
*- In S4, the alphabetic material is extended to 40 digits;
*- but the numeric material is still restricted to 18 digits.
  IF &1 NE ''.
  CALL FUNCTION 'ZCONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = &1
    IMPORTING
      output = &1.
  ENDIF.
* end off 2025/01/15 *

END-OF-DEFINITION.

DEFINE matn1_output.

  CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
    EXPORTING
      input  = &1
    IMPORTING
      output = &1.

END-OF-DEFINITION.

DEFINE idoc_to_sap.

  CALL FUNCTION 'CURRENCY_AMOUNT_IDOC_TO_SAP'
    EXPORTING
      currency    = &1
      idoc_amount = &2
    IMPORTING
      sap_amount  = &2.

END-OF-DEFINITION.

DEFINE sap_to_idoc.

  CALL FUNCTION 'CURRENCY_AMOUNT_SAP_TO_IDOC'
    EXPORTING
      currency    = &1
      sap_amount  = &2
    IMPORTING
      idoc_amount = &2.

END-OF-DEFINITION.

DEFINE date_check.

  CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
    EXPORTING
      date                      = &1
    EXCEPTIONS
      plausibility_check_failed = 1
      OTHERS                    = 2.

END-OF-DEFINITION.

DEFINE time_check.
  CALL FUNCTION 'TIME_CHECK_PLAUSIBILITY'
    EXPORTING
      time                      = &1
    EXCEPTIONS
      plausibility_check_failed = 1
      OTHERS                    = 2.

END-OF-DEFINITION.
* &1: date in, &2: month count, &3: '+'Âä#úà, '-'Ê∏#úà
DEFINE change_month.

  CALL FUNCTION 'HR_PT_ADD_MONTH_TO_DATE'
    EXPORTING
      dmm_datin = &1
      dmm_count = &2
      dmm_oper  = &3
      dmm_pos   = ' '
    IMPORTING
      dmm_daout = &4
    EXCEPTIONS
      unknown   = 1
      OTHERS    = 2.

END-OF-DEFINITION.

DEFINE ftpost_field.

  &1-fnam = &2.
  &1-fval = &3.
  APPEND &1.

END-OF-DEFINITION.

DEFINE conv_unit.
  CALL FUNCTION 'MATERIAL_UNIT_CONVERSION'
    EXPORTING
      input  = &1
      matnr  = &2
      meinh  = &3
    IMPORTING
      output = &1
    EXCEPTIONS
      OTHERS = 9.
  IF sy-subrc <> 0.
*     MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
*        WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
  ENDIF.

END-OF-DEFINITION.

DEFINE curr_factor_get.

  CALL FUNCTION 'CURRENCY_FACTOR_GET'
    EXPORTING
      i_from_currency = &1
      i_to_currency   = &2
    IMPORTING
      e_factor        = &3.

END-OF-DEFINITION.

DEFINE popup_confirm.
  CLEAR &4.
  CALL FUNCTION 'POPUP_TO_CONFIRM_WITH_MESSAGE'
    EXPORTING
      defaultoption        = 'N'
      diagnosetext1        = &1
*       DIAGNOSETEXT2        = &2
*       DIAGNOSETEXT3        = ' '
      textline1            = &2
*       TEXTLINE2            = ' '
      titel                = &3
      start_column         = 25
      start_row            = 6
*       CANCEL_DISPLAY       = 'X'
    IMPORTING
      answer               = &4.

END-OF-DEFINITION.

DEFINE setit.
  &1 = 'X'.
END-OF-DEFINITION.

DEFINE added.
  &1 = &1 + 1.
END-OF-DEFINITION.

DEFINE cntl_system_method.
  CALL METHOD &1
    EXCEPTIONS
      cntl_system_error = 1
      cntl_error        = 2.
  IF sy-subrc <> 0.
*      message a000.
  ENDIF.

END-OF-DEFINITION.

DEFINE get_rows.

  IF &1 IS NOT INITIAL.
    CALL METHOD &1->get_selected_rows
      IMPORTING
        et_index_rows = &2.
  ENDIF.

END-OF-DEFINITION.

DEFINE set_rows.

  IF &1 IS NOT INITIAL.
    CALL METHOD &1->set_selected_rows
      EXPORTING
        it_index_rows            = &2
        is_keep_other_selections = &3.
  ENDIF.

END-OF-DEFINITION.

DEFINE lvc_field_merge.

  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name   = &1
      i_bypassing_buffer = 'X'
    CHANGING
      ct_fieldcat        = &2.

END-OF-DEFINITION.

DEFINE get_work_days.
  CALL FUNCTION 'DURATION_DETERMINE'
   EXPORTING
     factory_calendar                 = &1
   IMPORTING
     duration                         = &4
   CHANGING
     start_date                       = &2
     end_date                         = &3
   EXCEPTIONS
     factory_calendar_not_found       = 1
     date_out_of_calendar_range       = 2
     date_not_valid                   = 3
     unit_conversion_error            = 4
     si_unit_missing                  = 5
     parameters_not_valid             = 6
     OTHERS                           = 7.
END-OF-DEFINITION.

DEFINE reuse_alv_field_merge.
  CALL FUNCTION 'REUSE_ALV_FIELDCATALOG_MERGE'
    EXPORTING
*     I_PROGRAM_NAME         =
*     I_INTERNAL_TABNAME     =
      i_structure_name       = &1
*     I_CLIENT_NEVER_DISPLAY = 'X'
*     I_INCLNAME             =
      i_bypassing_buffer     = 'X'
*     I_BUFFER_ACTIVE        =
    CHANGING
      ct_fieldcat            = &2
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.
  IF sy-subrc <> 0.
* MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
*         WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
  ENDIF.

END-OF-DEFINITION.

DEFINE reuse_hierseq_alv_field_merge.
  CALL FUNCTION 'REUSE_ALV_FIELDCATALOG_MERGE'
    EXPORTING
*     I_PROGRAM_NAME         =
      i_internal_tabname     = &3
      i_structure_name       = &1
*     I_CLIENT_NEVER_DISPLAY = 'X'
*     I_INCLNAME             =
      i_bypassing_buffer     = 'X'
*     I_BUFFER_ACTIVE        =
    CHANGING
      ct_fieldcat            = &2
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.
  IF sy-subrc <> 0.
* MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
*         WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
  ENDIF.

END-OF-DEFINITION.

DEFINE create_container_object.

  CREATE OBJECT &1
    EXPORTING
      container_name              = &2
    EXCEPTIONS
      cntl_error                  = 1
      cntl_system_error           = 2
      create_error                = 3
      lifetime_error              = 4
      lifetime_dynpro_dynpro_link = 5
      OTHERS                      = 6.

END-OF-DEFINITION.

DEFINE create_alv_object.

  CREATE OBJECT &1
    EXPORTING
      i_parent          = &2
    EXCEPTIONS
      error_cntl_create = 1
      error_cntl_init   = 2
      error_cntl_link   = 3
      error_dp_create   = 4
      OTHERS            = 5.

END-OF-DEFINITION.
DEFINE check_domain.
  CALL FUNCTION 'CHECK_DOMAIN_VALUES'
    EXPORTING
      domname       = &1
      value         = &2
    EXCEPTIONS
      no_domname    = 1
      wrong_value   = 2
      dom_not_found = 3
      OTHERS        = 4.
END-OF-DEFINITION.

DEFINE get_domain.
  CALL FUNCTION 'GET_DOMAIN_VALUES'
    EXPORTING
      domname         = &1
    TABLES
      values_tab      = &2
    EXCEPTIONS
      no_values_found = 1
      OTHERS          = 2.
END-OF-DEFINITION.

DEFINE bfill.
  PERFORM dynpro USING &1 &2 &3.
END-OF-DEFINITION.

DEFINE read_text.
  CLEAR: &4[] ,&4.
  CALL FUNCTION 'READ_TEXT'
    EXPORTING
     client                        = sy-mandt
      id                           = &1
      language                     = &5
      name                         = &2
      object                       = &3
*     importing
*       header                        =
    TABLES
      lines                        = &4
   EXCEPTIONS
     id                            = 1
     language                      = 2
     name                          = 3
     not_found                     = 4
     object                        = 5
     reference_check               = 6
     wrong_access_to_archive       = 7
     OTHERS                        = 8.
  CLEAR: &4 .

END-OF-DEFINITION.

DEFINE read_text_with_header.
  CLEAR: &4[] ,&4, &6.
  CALL FUNCTION 'READ_TEXT'
    EXPORTING
     client                        = sy-mandt
      id                           = &1
      language                     = &5
      name                         = &2
      object                       = &3
     IMPORTING
       header                      = &6
    TABLES
      lines                        = &4
   EXCEPTIONS
     id                            = 1
     language                      = 2
     name                          = 3
     not_found                     = 4
     object                        = 5
     reference_check               = 6
     wrong_access_to_archive       = 7
     OTHERS                        = 8.
  CLEAR: &4 .

END-OF-DEFINITION.

DEFINE werks_get_bukrs.
  CALL FUNCTION 'HRCA_PLANT_GET_COMPANYCODE'
    EXPORTING
      plant                 = &1
    IMPORTING
      companycode           = &2
    EXCEPTIONS
      no_company_code_found = 1
      plant_not_found       = 2
      OTHERS                = 3.

END-OF-DEFINITION.

DEFINE front_sign.
  IF &1 CA '-'.
    TRANSLATE &1 USING '- '.
    CONDENSE &1  NO-GAPS.
    SHIFT &1 LEFT DELETING LEADING space.
    CONCATENATE '-'  &1 INTO &1.
    CONDENSE &1  NO-GAPS.
    SHIFT &1 RIGHT DELETING TRAILING space.
  ENDIF.
END-OF-DEFINITION.

DEFINE plant_get_company.
  CALL FUNCTION 'HRCA_PLANT_GET_COMPANYCODE'
    EXPORTING
      plant                 = &1
    IMPORTING
      companycode           = &2
    EXCEPTIONS
      no_company_code_found = 1
      plant_not_found       = 2
      OTHERS                = 3.
END-OF-DEFINITION.

DEFINE get_number.
  cls itinrv.
  CALL FUNCTION 'NUMBER_RANGE_INTERVAL_LIST'
    EXPORTING
      object                 = &1
      subobject              = &2     "BUKRS
      clear_local_memory     = 'X'
    TABLES
      interval               = itinrv
    EXCEPTIONS
      nr_range_nr1_not_found = 1.
  IF sy-subrc <> 0.
    mm_log_add_message 'E' 'ZMCO01' '000' 'Á#Ê≥ïÂèñÂæ#ñÆÊì#µ#∞¥Ëôü' '' '' ''. "
  ELSE.
    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr = '01'
        object      = &1
        subobject   = &2
      IMPORTING
        number      = &3.
  ENDIF.


END-OF-DEFINITION.

DEFINE get_number_no.
  cls itinrv.
  CALL FUNCTION 'NUMBER_RANGE_INTERVAL_LIST'
    EXPORTING
      object                 = &1
*       subobject              = &2     "BUKRS
      clear_local_memory     = 'X'
    TABLES
      interval               = itinrv
    EXCEPTIONS
      nr_range_nr1_not_found = 1.
  IF sy-subrc <> 0.
    mm_log_add_message 'E' 'ZMIM01' '000' 'Á#Ê≥ïÂèñÂæ#ñÆÊì#µ#∞¥Ëôü' '' '' ''. "
  ELSE.
    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr = '01'
        object      = &1
*         subobject   = &2
      IMPORTING
        number      = &2.
  ENDIF.


END-OF-DEFINITION.

DEFINE unit_input.
  CALL FUNCTION 'CONVERSION_EXIT_CUNIT_INPUT'
    EXPORTING
      input          = &1
*     LANGUAGE       = SY-LANGU
    IMPORTING
      output         = &2
    EXCEPTIONS
      unit_not_found = 1
      OTHERS         = 2.
  IF sy-subrc <> 0.
* MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
*         WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
  ENDIF.
END-OF-DEFINITION.

DEFINE unit_output.
  CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
    EXPORTING
      input          = &1
*     LANGUAGE       = SY-LANGU
    IMPORTING
*     LONG_TEXT      =
      output         = &2
*     SHORT_TEXT     =
    EXCEPTIONS
      unit_not_found = 1
      OTHERS         = 2.
  IF sy-subrc <> 0.
* MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
*         WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
  ENDIF.

END-OF-DEFINITION.

DEFINE chinese_date.
  gnyerno = &1+0(4).
  gnyerno = gnyerno - 1911.
  gnyyyno = gnyerno.
  gnmmmno = &1+4(2).
  gndddno = &1+6(2).
*   concatenate 'Ê∞ëÂúã' gnyyyno 'Âπ¥' gnmmmno 'Êúà' gndddno 'Ê#' into &2 separated by space.
*   concatenate gnyyyno 'Âπ¥' gnmmmno 'Êúà' gndddno 'Ê#' into &2 separated by space.
  CONCATENATE gnyyyno 'Âπ¥' gnmmmno 'Êúà' gndddno 'Ê#' INTO &2.
END-OF-DEFINITION.

DEFINE cost_unit_qty.
  SELECT SINGLE * INTO stmarm FROM marm
   WHERE matnr = &1 AND numtp = 'Z2'.
  IF sy-subrc = 0 AND stmarm-meinh <> &2.
    &3 = &3 * stmarm-umren / stmarm-umrez.
  ELSE.
  ENDIF.

END-OF-DEFINITION.

DEFINE conv_unit_qty.
  SELECT SINGLE * INTO stmarm FROM marm
   WHERE matnr = &1 AND meinh = &2.
  IF sy-subrc = 0.
    &3 = &3 * stmarm-umren / stmarm-umrez.
  ELSE.
  ENDIF.

END-OF-DEFINITION.

DEFINE get_ck11n.
  CALL FUNCTION 'Z_CO_0001'
    EXPORTING
      fcmatnr = &1
      fcwerks = &2
      fcperid = &3
    TABLES
      itckis  = &4.

END-OF-DEFINITION.

DEFINE get_cost_comp.
  CALL FUNCTION 'Z_CO_0003'
    EXPORTING
      fcmatnr = &1
      fcwerks = &2
      fcperid = &3
      fcifyan = &6
    IMPORTING
      sthead  = &5
    TABLES
      itcost  = &4.

END-OF-DEFINITION.

DEFINE spell_amount.
  CALL FUNCTION 'SPELL_AMOUNT'
    EXPORTING
      amount    = &1
      currency  = &2
      language  = sy-langu
    IMPORTING
      in_words  = stspel
    EXCEPTIONS
      not_found = 1
      too_large = 2
      OTHERS    = 3.
  IF sy-subrc <> 0.
    CLEAR: &3.
  ELSE.
    CLEAR: &3.
    IF stspel-decword <> '' AND stspel-decword <> 'È#'.
*       condense stspel-decword.
      IF stspel-decimal IS NOT INITIAL.
*         stspel-decimal = stspel-decimal+0(stspel-currdec).
        CLEAR stspel-decword.
        stspel-dig15   = stspel-decimal+0(stspel-currdec).
        DO stspel-currdec TIMES.
          gispell = sy-index - 1.
          SELECT SINGLE wort INTO stspel-decword+gispell(1) FROM t015z
           WHERE spras = sy-langu AND einh = '0' AND ziff = stspel-dig15+gispell(1).
        ENDDO.
      ENDIF.
      CONCATENATE stspel-word 'Èªû' stspel-decword INTO &3 SEPARATED BY space.
      CONDENSE &3 NO-GAPS.
    ELSE.
      &3 = stspel-word.
      CONDENSE &3 NO-GAPS.
    ENDIF.
  ENDIF.

END-OF-DEFINITION.


DEFINE date_get_weekday.

  CALL FUNCTION 'DATE_COMPUTE_DAY'
    EXPORTING
      date = &1
    IMPORTING
      day  = &2.

END-OF-DEFINITION.

DEFINE set_create_date.
  IF &1-crdat IS INITIAL.
    &1-crdat = sy-datum.
    &1-crnam = sy-uname.
    &1-crtim = sy-uzeit.
    CALL FUNCTION 'TERMINAL_ID_GET'
      EXPORTING
        username             = sy-uname
      IMPORTING
        terminal             = &1-crtem
      EXCEPTIONS
        multiple_terminal_id = 1
        no_terminal_found    = 2
        OTHERS               = 3.
  ELSE.
    &1-lcdat = sy-datum.
    &1-lcnam = sy-uname.
    &1-lctim = sy-uzeit.
    CALL FUNCTION 'TERMINAL_ID_GET'
      EXPORTING
        username             = sy-uname
      IMPORTING
        terminal             = &1-lctem
      EXCEPTIONS
        multiple_terminal_id = 1
        no_terminal_found    = 2
        OTHERS               = 3.
  ENDIF.
END-OF-DEFINITION.

DEFINE set_change_date.
  &1-lcdat = sy-datum.
  &1-lcnam = sy-uname.
  &1-lctim = sy-uzeit.
  CALL FUNCTION 'TERMINAL_ID_GET'
    EXPORTING
      username             = sy-uname
    IMPORTING
      terminal             = &1-lctem
    EXCEPTIONS
      multiple_terminal_id = 1
      no_terminal_found    = 2
      OTHERS               = 3.

END-OF-DEFINITION.

DEFINE convert_local_cur.
  CALL FUNCTION 'CONVERT_TO_LOCAL_CURRENCY'
    EXPORTING
*     CLIENT            = SY-MANDT
      date              = gddatub
      foreign_amount    = &1
      foreign_currency  = &2
      local_currency    = &4
      rate              = gfkurst
      type_of_rate      = 'M'
*     READ_TCURR        = 'X'
    IMPORTING
      exchange_rate     = gfkursf
*     FOREIGN_FACTOR    =
      local_amount      = &3
*     LOCAL_FACTOR      =
*     EXCHANGE_RATEX    =
*     FIXED_RATE        =
*     DERIVED_RATE_TYPE =
    EXCEPTIONS
      no_rate_found     = 1
      overflow          = 2
      no_factors_found  = 3
      no_spread_found   = 4
      derived_2_times   = 5
      OTHERS            = 6.

END-OF-DEFINITION.

DEFINE popup_to_select_month.
  &1 = sy-datum.
  CALL FUNCTION 'POPUP_TO_SELECT_MONTH'
    EXPORTING
      actual_month               = &1
      start_column               = 8
      start_row                  = 5
    IMPORTING
      selected_month             = &1
    EXCEPTIONS
      factory_calendar_not_found = 1
      holiday_calendar_not_found = 2
      month_not_found            = 3
      OTHERS                     = 4.

END-OF-DEFINITION.

DEFINE concatenate_resut.
  IF &1 = ''.
    CONCATENATE &2 &3 &4 INTO &1 SEPARATED BY space.
  ELSE.
    CONCATENATE &1 '/' &2 &3 &4 INTO &1 SEPARATED BY space.
  ENDIF.
END-OF-DEFINITION.

DEFINE string_cutoff_pos.
* also try CL_DOCUMENT_BCS=>STRING_TO_SOLI( ). or
* concatenate cl_abap_char_utilities=>newline <body content> into <body>

  CALL METHOD cl_scp_linebreak_util=>string_split_at_position
    EXPORTING
      im_string                 = &1
      im_pos_vis                = &2
      im_pos_tech               = &2
      im_boundary_kind          = cl_scp_linebreak_util=>c_boundary_word
    IMPORTING
      ex_pos_tech               = &3
    EXCEPTIONS
      pos_not_valid             = 1
      unsupported_boundary_kind = 2
      invalid_text_enviroment   = 3
      OTHERS                    = 4.

  IF sy-subrc <> 0.

  ENDIF.

END-OF-DEFINITION.

DEFINE set_alv_sort.
  stsort-spos = &1.
  stsort-tabname   = &2.
  stsort-fieldname = &3.
  stsort-up = 'X'.
  stsort-group = '*'.
  stsort-subtot = ' '.
* stsort-comp = 'X'.
* stsort-expa = 'X'.
* stsort-obligatory = 'X'.
  APPEND stsort TO itsort.
END-OF-DEFINITION.

DEFINE set_grid_sort.
  stsorg-spos = &1.
  stsorg-fieldname = &2.
  stsorg-up = 'X'.
  stsorg-level = &1.
*  stsorg-group = '* '.
  stsorg-subtot = ' '.
* stsorg-comp = 'X'.
* stsorg-expa = 'X'.
* stsorg-obligatory = 'X'.
  APPEND stsorg TO itsorg.
END-OF-DEFINITION.

DEFINE sel_all.

  PERFORM suanzer USING 'S'.

END-OF-DEFINITION.

DEFINE desel_all.

  PERFORM suanzer USING 'D'.

END-OF-DEFINITION.

DEFINE alv_check_changed_data.
  CALL METHOD oralist->check_changed_data
    IMPORTING
      e_valid = gxvalid.
  IF gxvalid = ''.
*    CALL METHOD oralvgd->activate_display_protocol.
    EXIT.
  ENDIF.
END-OF-DEFINITION.

DEFINE setup_bapi_update_flag.

*FORM setup_bapi_update_flag USING u_wa  TYPE any
*                            CHANGING u_wax TYPE any.
  DATA: lostrc TYPE REF TO cl_abap_structdescr,
        loelem TYPE REF TO cl_abap_elemdescr.
  FIELD-SYMBOLS: <comp> LIKE LINE OF cl_abap_structdescr=>components,
                 <x>    TYPE any.
  FIELD-SYMBOLS: <inputed> TYPE any.
  lostrc ?= cl_abap_typedescr=>describe_by_data( u_wax ).
  CHECK lostrc IS BOUND.
  LOOP AT lostrc->components ASSIGNING <comp>.
    UNASSIGN <x>.
    CHECK <comp>-type_kind EQ lostrc->typekind_char.
    ASSIGN COMPONENT <comp>-name OF STRUCTURE u_wax TO <x>.
    ASSIGN COMPONENT <comp>-name OF STRUCTURE u_wa  TO <inputed>.
*-> if cluase of englkish
    IF <inputed> IS ASSIGNED AND <inputed> IS NOT INITIAL.
      CHECK <x> IS ASSIGNED.
      loelem ?= cl_abap_typedescr=>describe_by_data( <x> ).
      CHECK loelem->absolute_name EQ '\TYPE=BAPIUPDATE'.
      <x> = cl_mmpur_constants=>yes.
    ENDIF.
  ENDLOOP.

END-OF-DEFINITION.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
