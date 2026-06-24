*&---------------------------------------------------------------------*
*&  Include           ZTWRBC0005_TOP
*&---------------------------------------------------------------------*
tables: agr_users.

DATA: it_a_user       LIKE agr_users      OCCURS 0  WITH HEADER LINE.

DATA: BEGIN OF it_user  OCCURS 0,
        bname       LIKE user_addr-bname,
        name_textc  LIKE user_addr-name_textc,
        department  LIKE user_addr-department,
      END OF it_user.
*
DATA: BEGIN OF is_agr_user.
        INCLUDE     STRUCTURE it_agr.
        INCLUDE     STRUCTURE it_user.
DATA:   uname       LIKE agr_users-uname,
      END OF is_agr_user.
DATA: it_agr_user     LIKE is_agr_user    OCCURS 0  WITH HEADER LINE.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
