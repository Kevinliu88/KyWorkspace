*&---------------------------------------------------------------------*
*&  Include           ZTWRBC0003_TOP
*&---------------------------------------------------------------------*
TABLES: tstc, usobx.
*
FIELD-SYMBOLS: <ls_t_obj>.
*
DATA: it_usobx      LIKE usobx     OCCURS 0  WITH HEADER LINE.
DATA: it_usobt      LIKE usobt     OCCURS 0  WITH HEADER LINE.
DATA: it_tstc       LIKE tstct     OCCURS 0  WITH HEADER LINE.

DATA: BEGIN OF is_t_obj,
        tcode       LIKE tstc-tcode,
        tctxt       LIKE tstct-ttext.
        INCLUDE     STRUCTURE is_object.
DATA: END OF is_t_obj.
DATA: it_t_obj      LIKE is_t_obj  OCCURS 0  WITH HEADER LINE.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
