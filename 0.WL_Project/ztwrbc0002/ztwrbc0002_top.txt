*&---------------------------------------------------------------------*
*&  Include           ZTWRBC0002_TOP
*&---------------------------------------------------------------------*
FIELD-SYMBOLS: <ls_a_obj>.
*
DATA: it_1252       LIKE agr_1252        OCCURS 0  WITH HEADER LINE.
*
DATA: BEGIN OF is_agr_object.
        INCLUDE      STRUCTURE it_agr.
DATA:   auth         LIKE agr_1251-auth,
        check(20)    type c.
        INCLUDE      STRUCTURE is_object.
DATA: END OF is_agr_object.

DATA: it_agr_object  LIKE is_agr_object  OCCURS 0  WITH HEADER LINE.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
