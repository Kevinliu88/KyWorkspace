*&---------------------------------------------------------------------*
*&  Include           ZTWRBC0004_TOP
*&---------------------------------------------------------------------*
TABLES: tstc, agr_tcodes, zttcode_log.
*
RANGES: ir_tcode    FOR tstc-tcode.
*
DATA: it_tstc       LIKE tstc           OCCURS 0  WITH HEADER LINE.
DATA: it_tstct      LIKE tstct          OCCURS 0  WITH HEADER LINE.
DATA: it_tcode      LIKE agr_tcodes     OCCURS 0  WITH HEADER LINE.
DATA: it_zlog       LIKE zttcode_log    OCCURS 0  WITH HEADER LINE.
DATA: BEGIN OF it_tlog    OCCURS 0.
        INCLUDE     STRUCTURE tstct.
DATA:   erdat       LIKE zttcode_log-erdat,
        ernam       LIKE zttcode_log-ernam,
      END OF it_tlog.
*
DATA: BEGIN OF is_agr_tc.
        INCLUDE     STRUCTURE it_agr.
DATA:   tcode       LIKE tstc-tcode,
        tctxt       LIKE tstct-ttext,
        erdat       LIKE zttcode_log-erdat,
        ernam       LIKE zttcode_log-ernam,
        modified    LIKE agr_1251-modified,
        menu(1)     TYPE c,
        check(2)    TYPE c,
        color_r(4)  TYPE c,     "row color attributes
      END OF is_agr_tc.
DATA: it_agr_tc     LIKE is_agr_tc      OCCURS 0  WITH HEADER LINE.
DATA: g_erdat       LIKE zttcode_log-erdat.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
