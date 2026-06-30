*&---------------------------------------------------------------------*
*&  Include           ZTWRMMI016
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&  Include           ZSI00051
*&---------------------------------------------------------------------*
** T A B L E   W O R K   A R E A   D E C L A R A T I O N ***************
TABLES: t001l, vbak, mara, t001w, tvko, kna1, vbap, tvtw, tvak, ztsd0098, ztsd0099, zssd0077,
        likp, lips, vbuv, ztsd0150.

** S E L E C T I O N   S C R E E N *************************************
SELECTION-SCREEN SKIP.
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-002.

*PARAMETERS: pcwerks LIKE t001w-werks AS LISTBOX VISIBLE LENGTH 16 OBLIGATORY USER-COMMAND on_changeobject.
*PARAMETERS: pcvkorg LIKE tvko-vkorg OBLIGATORY.
  SELECT-OPTIONS: scwerks for ztsd0098-werks.
  PARAMETERS: pcvtweg LIKE ztsd0098-vtweg MEMORY ID zau OBLIGATORY.
*PARAMETERS: pcentit LIKE ztsd0015-zp_entity MEMORY ID zent OBLIGATORY.
  PARAMETERS: pckunnr LIKE kna1-kunnr MEMORY ID kun OBLIGATORY.
  SELECT-OPTIONS: scxqlin FOR ztsd0098-zxqline,
                  scyyymm FOR ztsd0098-zym,
                  scperid FOR ztsd0098-zperiod,
                  sczxqno FOR ztsd0098-zxqno MEMORY ID zxqno,
                  scxqsta FOR ztsd0098-zxqsta,
                  sczcpno FOR ztsd0098-zcpno,
                  scpnocn FOR ztsd0098-zcpnocn,
                  snxqseq FOR ztsd0099-zxqseq,
                  sczpnoi FOR ztsd0099-zpno,
                  scitsts FOR ztsd0099-zxqwrktyp.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN SKIP.
PARAMETERS: prdtyp1 RADIOBUTTON GROUP gr1 MODIF ID abc,
            prdtyp2 RADIOBUTTON GROUP gr1 MODIF ID abc,
            prdtyp3 RADIOBUTTON GROUP gr1 MODIF ID abc. "2020/04/30 yinglung V002
*PARAMETERS: pcfpath TYPE rlgrap-filename MEMORY ID pfu12.
SELECTION-SCREEN BEGIN OF SCREEN 1100 AS WINDOW.
  SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE TEXT-s01.
    PARAMETERS: pczpnoi LIKE ztsd0099-zpno.
    PARAMETERS: pczdesc LIKE ztsd0099-zdesc.
  SELECTION-SCREEN END OF BLOCK b4.
SELECTION-SCREEN END OF SCREEN 1100.

SELECTION-SCREEN BEGIN OF SCREEN 1200 AS WINDOW.
  SELECTION-SCREEN BEGIN OF BLOCK b5 WITH FRAME TITLE TEXT-s01.
    PARAMETERS: ppzupii LIKE ztsd0099-zup.
    PARAMETERS: ppupper LIKE ztsd0099-zup_per DEFAULT 1.
  SELECTION-SCREEN END OF BLOCK b5.
SELECTION-SCREEN END OF SCREEN 1200.

** I N T E R N A L   T A B L E  &  G L O B A L  V A R ******************
CONSTANTS: cilenth TYPE i VALUE 132.



TYPES: BEGIN OF tthead.
         INCLUDE STRUCTURE zssd0079.
TYPES:   style TYPE lvc_t_styl.
TYPES: END OF tthead.

DATA: sthead TYPE tthead,
      ithead TYPE TABLE OF tthead, "20200430 yinglung V002
      stchos TYPE tthead,
      itchos TYPE TABLE OF tthead,
      itlist LIKE zssd0076 OCCURS 0 WITH HEADER LINE.
TYPES: BEGIN OF ttdata.
         INCLUDE STRUCTURE zssd0075.
TYPES:   style TYPE lvc_t_styl.
TYPES: END OF ttdata.
DATA: stdata TYPE ttdata,
      ititmp TYPE ttdata,
      itdata TYPE TABLE OF ttdata,
      sttemp TYPE ttdata.
TYPES: BEGIN OF tt0100.
         INCLUDE STRUCTURE zssd0077.
TYPES:   style TYPE lvc_t_styl.
TYPES: END OF tt0100.
DATA: st0100 TYPE tt0100,
      it0100 TYPE TABLE OF tt0100.
TYPES: BEGIN OF tt0101.
         INCLUDE STRUCTURE zssd0078.
TYPES:   style TYPE lvc_t_styl.
TYPES: END OF tt0101.
DATA: st0101 TYPE tt0101,
      it0101 TYPE TABLE OF tt0101,
      itlis2 LIKE zssd0075 OCCURS 0 WITH HEADER LINE.
DATA: itsd99       LIKE ztsd0099 OCCURS 0 WITH HEADER LINE,
      it001w       LIKE t001w    OCCURS 0 WITH HEADER LINE,
      itmara       LIKE mara     OCCURS 0 WITH HEADER LINE,
      itvbuv       LIKE vbuv     OCCURS 0 WITH HEADER LINE,
      itsv03       LIKE zvsd0003 OCCURS 0 WITH HEADER LINE,
      itsd98       LIKE ztsd0098 OCCURS 0 WITH HEADER LINE,
*      sts130       LIKE ztsd0130,
      gczxqno      TYPE zxqno,
      gixqind      TYPE i,
      gnxqseq      TYPE zxqseq,
      gixqseq      TYPE i,
      gicount      TYPE i,
      gcxqlin      TYPE zmoqline,
      gcpotyp(2),
      gcfpath      TYPE string,
      gitabix      TYPE i,
      gnyearn(4)   TYPE n,
      gnperid(2)   TYPE n,
      gnyear1(4)   TYPE n,
      gnperi1(2)   TYPE n,
      gnyear2(4)   TYPE n,
      gnperi2(2)   TYPE n,
      gnyear3(4)   TYPE n,
      gnperi3(2)   TYPE n,
      gddatfr      TYPE d,
      gddatto      TYPE d,
      gclgort      TYPE lgort_d,
      lcmessg(255),
      gcmblnr      LIKE mkpf-mblnr,
      gcmjahr      LIKE mkpf-mjahr,
      gctitle(50),
      gncount(6),
      gxifext,
      gcdynnr      TYPE sy-dynnr,
      sts117       TYPE ztsd0117,
      stsd98       TYPE ztsd0098,
      stsd99       TYPE ztsd0099,
      stsd28       TYPE ztsd0028,
      stsd29       TYPE ztsd0029,
      stsd20       TYPE ztsd0020,
      sts107       TYPE ztsd0107,
      stss01       TYPE ztsd0100,
      stss02       TYPE ztsd0101,
      itss01       TYPE ztsd0100 OCCURS 0 WITH HEADER LINE,
      itss02       TYPE ztsd0101 OCCURS 0 WITH HEADER LINE,
      gcwaers      TYPE waers,
      gcfortp      TYPE zformulatype,
      stkna1       TYPE kna1,
      gckunam(40),
      gcbukrs      TYPE bukrs,
      itsd28       TYPE zssd0096 OCCURS 0 WITH HEADER LINE,
      itsd93       TYPE ztsd0093 OCCURS 0 WITH HEADER LINE,
      itsd29       TYPE zssd0097 OCCURS 0 WITH HEADER LINE,
      itsd30       TYPE zssd0098 OCCURS 0 WITH HEADER LINE,
      its107       TYPE zssd0099 OCCURS 0 WITH HEADER LINE,
      its100       TYPE zssd0100 OCCURS 0 WITH HEADER LINE,
      its101       TYPE zssd0101 OCCURS 0 WITH HEADER LINE,
      its102       TYPE zssd0102 OCCURS 0 WITH HEADER LINE,
      its103       TYPE zssd0103 OCCURS 0 WITH HEADER LINE,
      itsuom       TYPE ztmm_uom_map OCCURS 0 WITH HEADER LINE,
      itfloc       TYPE slis_t_fieldcat_alv,
      stfloc       TYPE slis_fieldcat_alv,
      stoptn       TYPE ctu_params,
      ititem       TYPE bapi2017_gm_item_create OCCURS 0 WITH HEADER LINE,
      itretn       TYPE bapiret2 OCCURS 0 WITH HEADER LINE,
      stcode       LIKE bapi2017_gm_code.
DATA: gcvname TYPE vrm_id VALUE 'PCWERKS',
      itvlis  TYPE vrm_values,
      stvalu  TYPE vrm_value.

RANGES: rcvbeln FOR likp-vbeln,
        rdbudat FOR mkpf-budat.
CONSTANTS: BEGIN OF cstabs,
             tab1 LIKE sy-ucomm VALUE 'CCTABS_FC1',
             tab2 LIKE sy-ucomm VALUE 'CCTABS_FC2',
             tab3 LIKE sy-ucomm VALUE 'CCTABS_FC3',
           END OF cstabs.
CONTROLS:  cctabs TYPE TABSTRIP.

DATA: cst0100 TYPE scrfname VALUE 'CT0100',
      cst0101 TYPE scrfname VALUE 'CT0101',
      ora0100 TYPE REF TO cl_gui_alv_grid,
      ora0101 TYPE REF TO cl_gui_alv_grid,
      orc0100 TYPE REF TO cl_gui_custom_container,
      orc0101 TYPE REF TO cl_gui_custom_container.

DATA: BEGIN OF gstabs,
        subscreen   LIKE sy-dynnr,
        prog        LIKE sy-repid VALUE 'ZTWBSD0021',
        pressed_tab LIKE sy-ucomm VALUE cstabs-tab1,
      END OF gstabs.

** M A C R O   D E F I N I T I O N *************************************

** C L A S S   D E F I N I T I O N *************************************
CLASS glhandl    DEFINITION DEFERRED.
CLASS cl_gui_cfw DEFINITION LOAD.
*---------------------------------------------------------------------*
*       CLASS glmethd DEFINITION
*---------------------------------------------------------------------*
*       ........                                                      *
*---------------------------------------------------------------------*
CLASS glhandl DEFINITION.

  PUBLIC SECTION.
    METHODS:
      godetail FOR EVENT double_click OF cl_gui_alv_grid
        IMPORTING e_row e_column es_row_no.

ENDCLASS.                    "lcl_application DEFINITION

** C L A S S  I M P L E M E N T A T I O N -----------------------------
*---------------------------------------------------------------------*
*       CLASS glmethd IMPLEMENTATION
*---------------------------------------------------------------------*
*       ........                                                      *
*---------------------------------------------------------------------*
CLASS glhandl IMPLEMENTATION.
  METHOD godetail.

    PERFORM godetail USING e_row e_column es_row_no.

  ENDMETHOD.                    "handle_alv_drop

ENDCLASS.                    "lcl_application IMPLEMENTATION

** A T - S E L E C T I O N - S C R E E N  ******************************
AT SELECTION-SCREEN OUTPUT.

  IF pczdesc = '' AND pczpnoi <> ''.
    SELECT SINGLE zdesc INTO pczdesc FROM ztsd0093
     WHERE vtweg = pcvtweg AND zbcust = pckunnr AND zpno = pczpnoi.
    IF sy-subrc <> 0.
      ""SELECT SINGLE * INTO sts130 FROM ztsd0130 WHERE vtweg = pcvtweg AND zpno = pczpnoi.
      SELECT SINGLE matnr, wl2_thenameoftheerp, wl2_englishspecifications, wl2_erpspecification
        INTO ( @DATA(tmp_matnr), @DATA(tmp_cdesc), @DATA(tmp_espec), @DATA(tmp_cspec) )
         FROM ztmara WHERE matnr = @pczpnoi.
      IF sy-subrc = 0.
        "" pczdesc = sts130-zpno_edesc && ` ` && sts130-zpno_desc.
        pczdesc = tmp_espec && ` ` && tmp_cdesc.
      ENDIF.
    ENDIF.
  ENDIF.
*V004 added by Fangchyi
  IF sy-tcode = 'ZXQ04_2'.
    prdtyp3 = 'X'.
    CLEAR: prdtyp1, prdtyp2.
    LOOP AT SCREEN.
      IF screen-group1 = 'ABC'.
        screen-input = '0'.
        MODIFY SCREEN.
      ENDIF.
    ENDLOOP.
  ENDIF.
*V004 end off
*  LOOP AT SCREEN.
*    IF screen-name = 'PPUPPER'.
*      screen-input = 0.
*      MODIFY SCREEN.
*    ENDIF.
*  ENDLOOP.
*AT SELECTION-SCREEN ON ppupper.
*  IF ppupper <> 1 AND ppupper <> 7.
*    MESSAGE e000 WITH '定價單位僅能為1或7'.
*  ENDIF.

*AT SELECTION-SCREEN ON VALUE-REQUEST FOR pcfpath.
*  PERFORM f4_pcfolder.
*
*AT SELECTION-SCREEN ON pcfpath.
*  IF prdtyp2 = 'X'.
*    IF pcfpath = ''.
*      MESSAGE e000 WITH text-017.
*    ELSE.
*      gcfpath = pcfpath.
*      IF cl_gui_frontend_services=>directory_exist( EXPORTING directory = gcfpath ).
*        IF NOT pcfpath CP '*\'.
*          pcfpath = pcfpath && '\'.
*        ENDIF.
*      ELSE.
*        MESSAGE e000 WITH text-017.
*      ENDIF.
*    ENDIF.
*  ENDIF.
*AT SELECTION-SCREEN ON VALUE-REQUEST FOR pcfname.
*  PERFORM f4_file_path USING    sy-repid
*                                sy-dynnr
*                                'PCFNAME'.

*AT SELECTION-SCREEN ON VALUE-REQUEST FOR pcfname.
*
*  CALL FUNCTION 'KD_GET_FILENAME_ON_F4'
*    EXPORTING
*      mask      = ',All Files,.'                          "#EC NOTEXT
*      static    = 'X'
*    CHANGING
*      file_name = pcfname.

*AT SELECTION-SCREEN ON pcvkorg.
*  SELECT SINGLE vkorg INTO pcvkorg FROM tvko
*   WHERE vkorg = pcvkorg.
*  IF sy-subrc <> 0.
*    MESSAGE e000 WITH text-005.
*  ELSE.
*    AUTHORITY-CHECK OBJECT 'V_VBAK_VKO'
*             ID 'VKORG' FIELD pcvkorg
*             ID 'ACTVT' FIELD '03'.
*    IF sy-subrc <> 0 .
*      MESSAGE e002 WITH pcvkorg.
*    ENDIF.
*  ENDIF.

*AT SELECTION-SCREEN ON pcfnam2.
*  IF prtype2 = 'X'.
*    gcfpath = pcfnam2.
*    CALL METHOD cl_gui_frontend_services=>directory_exist
*      EXPORTING
*        directory            = gcfpath
*      RECEIVING
*        result               = gxifext
*      EXCEPTIONS
*        cntl_error           = 1
*        error_no_gui         = 2
*        wrong_parameter      = 3
*        not_supported_by_gui = 4
*        OTHERS               = 5.
*    IF gxifext <> 'X'.
*      MESSAGE e000 WITH '請輸入正確路徑'.
*    ENDIF.
*  ENDIF.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
