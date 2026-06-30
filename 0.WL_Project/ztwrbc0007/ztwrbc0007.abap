REPORT ztwrbc0007a.
TABLES: usr02,tstc,tobj,agr_define,agr_1251,t001,t001w,
        tgsb,t024e,t024,t014,tvko,tvtw,tvst.

DATA : ls_zdd03m LIKE zdd03m,
       lt_zdd03m LIKE zdd03m OCCURS 0 WITH HEADER LINE.

TYPES :BEGIN OF  t_user ,
         bname      TYPE xubname,
         name_text  TYPE ad_namtext,
         department TYPE ad_dprtmnt,
         agr_name   TYPE agr_name,
         role_desc  TYPE agr_title,
       END OF t_user.

TYPES : BEGIN OF t_auth,
          bname      TYPE xubname,
          name_text  TYPE ad_namtext, "ADRP
          department TYPE ad_dprtmnt, "ADRC
          agr_name   TYPE agr_name,
          role_desc  TYPE agr_title,
          auth       TYPE agauth,
          object     TYPE agobject,
          obj_name   TYPE  xutext,  "OBJECT說明
          field      TYPE agrfield,
          field_name TYPE as4text, "FIELD說明
          varbl      TYPE agrorgvar,
          org_name   TYPE as4text,  "組織權限說明
          low        TYPE agval,
          high       TYPE agval,
          tcode_name TYPE ttext_stct, "TCODE說明
        END OF t_auth.

DATA : lv_rollname TYPE rollname.

TYPES : BEGIN OF t_org,
          varbl     TYPE agrorgvar,
          fieldname TYPE fieldname,
          rollname  TYPE  rollname,
          ddtext    TYPE  as4text,
        END OF t_org.

TYPES : BEGIN OF t_obj,
          object TYPE xuobject,
          ttext  TYPE xutext,
        END OF t_obj.

TYPES : BEGIN OF t_field,
          field    TYPE fieldname,
          rollname TYPE rollname,
          ddtext   TYPE as4text,
        END OF t_field.

DATA: ls_user  TYPE   t_user,
      lt_user  LIKE ls_user OCCURS 0 WITH HEADER LINE,
      ls_auth  TYPE   t_auth,
      lt_auth  LIKE ls_auth OCCURS 0 WITH HEADER LINE,
      ls_org   TYPE t_org,
      lt_org   LIKE ls_org OCCURS 0 WITH HEADER LINE,
      ls_obj   TYPE t_obj,
      lt_obj   LIKE ls_obj OCCURS 0 WITH HEADER LINE,
      ls_field TYPE t_field,
      lt_field LIKE ls_field OCCURS 0 WITH HEADER LINE.


*ALV
TYPE-POOLS slis.
DATA: gt_fieldcat TYPE slis_t_fieldcat_alv,
      wa_fieldcat TYPE slis_fieldcat_alv.
DATA: gs_layout    TYPE slis_layout_alv.
DATA: gt_sortinfo       TYPE slis_t_sortinfo_alv.
FIELD-SYMBOLS: <itab>         LIKE lt_auth.


SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.

  SELECT-OPTIONS: s_user FOR usr02-bname MODIF ID ex0.
  SELECT-OPTIONS: s_agr  FOR agr_define-agr_name.
  SELECT-OPTIONS: s_tcode FOR tstc-tcode MODIF ID ex1,
                  s_oclss FOR tobj-oclss MODIF ID ex2,
                  s_obj  FOR tobj-objct MODIF ID ex2,
                  s_bukrs FOR t001-bukrs MODIF ID ex3,
                  s_gsber FOR tgsb-gsber MODIF ID ex3,
                  s_vkorg FOR tvko-vkorg MODIF ID ex3,
                  s_vtweg FOR tvtw-vtweg MODIF ID ex3,
                  s_vstel FOR tvst-vstel MODIF ID ex3,
                  s_ekorg FOR t024e-ekorg MODIF ID ex3,
                  s_ekgrp FOR t024-ekgrp MODIF ID ex3,
                  s_werks FOR t001w-werks MODIF ID ex3,
                  s_kkber FOR t014-kkber MODIF ID ex3.

  PARAMETERS: r_tcode  RADIOBUTTON GROUP g3 DEFAULT 'X' USER-COMMAND uc1,      "看TCODE權限
              r_org    RADIOBUTTON GROUP g3,                             "看組織權限
              r_auth   RADIOBUTTON GROUP g3,                             "看權限物件
              r_des    RADIOBUTTON GROUP g3,                              "更新欄位資料
* VXXX Added by Tristan 2025/03/24 *
              r_roltco RADIOBUTTON GROUP g3.  " 給ROLE找T-Code
* VXXX End off *
SELECTION-SCREEN END OF BLOCK b01.


AT SELECTION-SCREEN OUTPUT.

  LOOP AT SCREEN.

    IF screen-name = 'R_DES'.

      screen-active = 0.

      MODIFY SCREEN.

    ENDIF.
    IF screen-group1 = 'EX1'.
      IF r_tcode = 'X'.
        screen-active = 1.
      ELSE.
        screen-active = 0.
      ENDIF.
      MODIFY SCREEN.
    ENDIF.
    IF screen-group1 = 'EX2'.
      IF r_auth = 'X'
      OR r_tcode = 'X'.
        screen-active = 1.
      ELSE.
        screen-active = 0.
      ENDIF.
      MODIFY SCREEN.
    ENDIF.
    IF screen-group1 = 'EX3'.
      IF r_org = 'X'.
        screen-active = 1.
      ELSE.
        screen-active = 0.
      ENDIF.
      MODIFY SCREEN.
    ENDIF.
* VXXX Added by Tristan 2025/03/25 *
    IF screen-group1 = 'EX0'.
      IF r_roltco = 'X'.
        screen-active = 0.
      ENDIF.
      MODIFY SCREEN.
    ENDIF.
* VXXX End off *
  ENDLOOP.


* ------------------------------------------------------------- *
* START-OF-SELECTION
* ------------------------------------------------------------- *
START-OF-SELECTION.

*請注意如果選了更新外掛表格，就不會執行查詢權限動作
  IF r_des = 'X'.
    " IF  ( sy-binpt = 'X' or sy-batch = 'X' ).
    "先把所有權限物件會抓的欄位抓起來
    DATA: lv_field TYPE agrfield.
    RANGES : s_field FOR agr_1251-field.
    SELECT  field INTO lv_field  FROM agr_1251  WHERE  deleted <> 'X'.
      READ TABLE s_field WITH KEY low = lv_field.
      IF sy-subrc <> 0.
        s_field-sign = 'I'.
        s_field-option = 'EQ'.
        s_field-low = lv_field.
        APPEND s_field.
      ENDIF.
    ENDSELECT.

    "然後去dd03m讀取，放到zdd03m
    SELECT fieldname rollname ddlanguage ddtext
      INTO CORRESPONDING FIELDS OF ls_zdd03m
      FROM dd03m
     WHERE fieldname IN s_field.
      READ TABLE lt_zdd03m WITH KEY rollname = lt_zdd03m-rollname
                                    fieldname = lt_zdd03m-fieldname
                                    ddlanguage = lt_zdd03m-ddlanguage.
      IF sy-subrc <> 0.
        APPEND ls_zdd03m TO  lt_zdd03m.
      ENDIF.
    ENDSELECT.

    DELETE FROM zdd03m.

    INSERT zdd03m FROM TABLE  lt_zdd03m.

    " ELSE.
    "   MESSAGE e002(zsd01) WITH 'It is only allowed in background mode!'.
    "ENDIF.

  ELSE.

*首先讀取目前有效的USERID, 並且找到對應的ROLE(一個ID不會只有一個)
    REFRESH : lt_user.
* VXXX Changed by Tristan 2025/03/24 *
*    PERFORM get_userdata TABLES  lt_user.
    IF r_roltco = ''.
      PERFORM get_userdata TABLES  lt_user.
    ENDIF.
* VXXX End off *

*然後根據每個ROLE去讀取AUTH.OBJ

    REFRESH : lt_auth.

    IF r_tcode = 'X'.  "如果是抓TCODE : 直接讀取S_TCODE即可

      PERFORM get_authdata TABLES lt_user
                                  lt_auth
                            USING  'S_TCODE'.

    ELSEIF r_org = 'X'.

      PERFORM get_authdata TABLES lt_user
                                  lt_auth
                           USING  'ORG'.

    ELSEIF r_auth = 'X'.

      PERFORM get_authdata TABLES lt_user
                                  lt_auth
                           USING  'ALL'.

* VXXX Added by Tristan 2025/03/24 *
    ELSEIF r_roltco = 'X'.
      PERFORM get_authdata TABLES lt_user
                                  lt_auth
                           USING  'ROLE'.

* VXXX End off *
    ENDIF.

    PERFORM display_data.
  ENDIF.

END-OF-SELECTION.
*&---------------------------------------------------------------------*
*&      Form  GET_USERDATA
*&---------------------------------------------------------------------*
*       從TABLE USR02讀取USERID資料,
*      再串TABLE AGR_USERS找到對應的ROLE
*----------------------------------------------------------------------*
FORM get_userdata  TABLES   pt_user  STRUCTURE  lt_user.

  DATA: l_persnumber LIKE usr21-persnumber.

  SELECT a~agr_name b~uname AS bname
    INTO CORRESPONDING FIELDS OF TABLE pt_user
    FROM agr_define AS a LEFT OUTER JOIN agr_users AS b
                           ON b~agr_name = a~agr_name
                          AND b~to_dat >= sy-datum
   WHERE a~agr_name IN s_agr.
  IF s_user[] IS NOT INITIAL.
    DELETE pt_user WHERE NOT bname IN s_user.
  ENDIF.
  SORT pt_user BY bname agr_name.
  DELETE ADJACENT DUPLICATES FROM pt_user COMPARING bname agr_name.
* VXXX Added by Tristan 2024/12/06 *
  IF pt_user[] IS NOT INITIAL.
    SELECT * FROM agr_texts INTO TABLE @DATA(lt_agr_texts)
       FOR ALL ENTRIES IN @pt_user
     WHERE agr_name = @pt_user-agr_name
       AND ( spras = @sy-langu OR spras = 'E' ).
    SORT lt_agr_texts BY agr_name spras line.
    DELETE ADJACENT DUPLICATES FROM lt_agr_texts COMPARING agr_name.
    SELECT * FROM usr21
       FOR ALL ENTRIES IN @pt_user
     WHERE bname = @pt_user-bname
      INTO TABLE @DATA(lt_usr21).
    IF sy-subrc = 0.
      SELECT * FROM adrp INTO TABLE @DATA(lt_adrp)
         FOR ALL ENTRIES IN @lt_usr21
       WHERE persnumber = @lt_usr21-persnumber.

      SELECT * FROM adcp INTO TABLE @DATA(lt_adcp)
         FOR ALL ENTRIES IN @lt_usr21
       WHERE persnumber = @lt_usr21-persnumber.
    ENDIF.
  ENDIF.

  SORT: lt_usr21 BY bname, lt_adrp BY persnumber, lt_adcp BY persnumber,
        lt_agr_texts BY agr_name.
* VXXX End off *

*  LOOP AT pt_user INTO ls_user.
*    "因為發現DEV環境好像不是每個語言的role都有建，所以先以原始語言抓，抓不到再去英文版
*    SELECT SINGLE a~text
*      INTO ls_user-role_desc
*      FROM agr_texts AS a
*     WHERE a~agr_name = ls_user-agr_name
*       AND a~spras = sy-langu.
*    IF sy-subrc <> 0 AND sy-langu <> 'EN'.
*      SELECT SINGLE a~text
*        INTO ls_user-role_desc
*        FROM agr_texts AS a
*       WHERE a~agr_name = ls_user-agr_name
*         AND a~spras = 'EN'.
*    ENDIF.
*
*    CLEAR l_persnumber.
*    SELECT SINGLE persnumber INTO l_persnumber
*      FROM usr21
*     WHERE bname = ls_user-bname.
*
*    SELECT SINGLE name_text INTO ls_user-name_text
*      FROM adrp
*     WHERE persnumber = l_persnumber.
*
*    SELECT SINGLE department INTO ls_user-department
*      FROM adcp
*     WHERE persnumber = l_persnumber.
*
*    MODIFY pt_user FROM ls_user.
*  ENDLOOP.
  LOOP AT pt_user ASSIGNING FIELD-SYMBOL(<fs_user>).
    READ TABLE lt_agr_texts INTO DATA(ls_agr_texts) WITH KEY agr_name = <fs_user>-agr_name BINARY SEARCH.
    IF sy-subrc = 0.
      <fs_user>-role_desc = ls_agr_texts-text.
    ENDIF.
    READ TABLE lt_usr21 INTO DATA(ls_usr21) WITH KEY bname = <fs_user>-bname BINARY SEARCH.
    IF sy-subrc = 0.
      READ TABLE lt_adrp INTO DATA(ls_adrp) WITH KEY persnumber = ls_usr21-persnumber BINARY SEARCH.
      IF sy-subrc = 0.
        <fs_user>-name_text = ls_adrp-name_text.
      ENDIF.
      READ TABLE lt_adcp INTO DATA(ls_adcp) WITH KEY persnumber = ls_usr21-persnumber BINARY SEARCH.
      IF sy-subrc = 0.
        <fs_user>-department = ls_adcp-department.
      ENDIF.
    ENDIF.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_AUTHDATA
*&---------------------------------------------------------------------*
*  1. 雖然有FUNCTION SUSR_USER_AUTH_FOR_OBJ_GET可以一次抓到ID底下所有AUTH.OBJ,
*     但是不能BY ROLE,查，先不使用
* 2. 抓出權限物件，並且依物件的欄位抓出說明
*    如果是抓TCODE, 就連TCODE名稱一起抓
*    如果是組織權限 就抓出組織欄位名稱
*----------------------------------------------------------------------*
FORM get_authdata  TABLES   pt_user STRUCTURE  lt_user
                            pt_auth STRUCTURE lt_auth
                   USING    pp_obj.

  DATA: pt_auth2 LIKE pt_auth OCCURS 0 WITH HEADER LINE,
        lt_tactt LIKE tactt  OCCURS 0 WITH HEADER LINE,
        l_langu  LIKE sy-langu.
  DATA: rg_tcode LIKE zsrange OCCURS 0 WITH HEADER LINE,
        rg_bukrs LIKE zsrange OCCURS 0 WITH HEADER LINE,
        rg_gsber LIKE zsrange OCCURS 0 WITH HEADER LINE,
        rg_vkorg LIKE zsrange OCCURS 0 WITH HEADER LINE,
        rg_vtweg LIKE zsrange OCCURS 0 WITH HEADER LINE,
        rg_vstel LIKE zsrange OCCURS 0 WITH HEADER LINE,
        rg_ekorg LIKE zsrange OCCURS 0 WITH HEADER LINE,
        rg_ekgrp LIKE zsrange OCCURS 0 WITH HEADER LINE,
        rg_werks LIKE zsrange OCCURS 0 WITH HEADER LINE,
        rg_kkber LIKE zsrange OCCURS 0 WITH HEADER LINE.
  DATA l_tabix LIKE sy-tabix.

  CLEAR lv_rollname.
  REFRESH:  pt_auth2, lt_tactt.

  CASE  pp_obj.
    WHEN 'ALL'.
      LOOP AT pt_user.
        SELECT  a~object a~auth a~field a~low a~high
          FROM agr_1251 AS a INNER JOIN tobj AS b
                                ON b~objct = a~object
          INTO CORRESPONDING FIELDS OF pt_auth
         WHERE a~agr_name = pt_user-agr_name
           AND a~deleted <> 'X'
           AND a~object IN s_obj
           AND b~oclss  IN s_oclss.
          pt_auth-bname = pt_user-bname.
* VXXX Added by Tristan 2024/12/09 *
          pt_auth-name_text = pt_user-name_text.
          pt_auth-department = pt_user-department.
* VXXX End off *
          pt_auth-agr_name = pt_user-agr_name.
          pt_auth-role_desc = pt_user-role_desc.
          APPEND pt_auth.
        ENDSELECT.
      ENDLOOP.

*1. 因為權限物件裡會直接使用組織權限的變數，要多抓一下組織權限的東西
      LOOP AT pt_user.
        SELECT   varbl low high
          FROM agr_1252
          INTO CORRESPONDING FIELDS OF pt_auth2
         WHERE agr_name = pt_user-agr_name.
          pt_auth2-bname = pt_user-bname.
          pt_auth2-name_text = pt_user-name_text.
          pt_auth2-department = pt_user-department.
          pt_auth2-agr_name = pt_user-agr_name.
          pt_auth2-role_desc = pt_user-role_desc.
          APPEND pt_auth2.
        ENDSELECT.
      ENDLOOP.

*2.因為可執行活動特別重要，需將各別值做說明
      SELECT *  FROM tactt APPENDING TABLE lt_tactt WHERE spras = 'E'.

      "3. 因為權限物件中重複的OBJ/FIELD說明過多，為增加效率需先整理後再抓說明
      "20220815 因為頻繁讀取資料庫反而變慢，不如直接抓全部資料
      LOOP AT pt_auth INTO ls_auth.
        PERFORM get_obj_field TABLES lt_obj lt_field
                                                  USING ls_auth.
      ENDLOOP.

      PERFORM process_obj_field.


      LOOP AT pt_auth INTO ls_auth.

        CLEAR : ls_auth-obj_name, ls_auth-field_name.

        READ TABLE lt_obj INTO ls_obj WITH KEY object = ls_auth-object.  "權限物件說明
        IF sy-subrc = 0.
          ls_auth-obj_name = ls_obj-ttext.
        ENDIF.
        READ TABLE lt_field INTO ls_field WITH KEY field = ls_auth-field.   "欄位說明
        IF sy-subrc = 0.
          ls_auth-field_name = ls_field-ddtext.
        ENDIF.

        IF ls_auth-field = 'ACTVT'.    "因為可執行活動特別重要，需將各別值做說明
          READ TABLE lt_tactt WITH KEY actvt = ls_auth-low.
          IF sy-subrc = 0.
            ls_auth-low = lt_tactt-ltext.
          ENDIF.

        ENDIF.

        MODIFY pt_auth FROM ls_auth.

      ENDLOOP.

**因為有部分角色的欄位是套用組織欄位，所以一併解譯
      LOOP AT pt_auth INTO ls_auth.
        l_tabix = sy-tabix.
        IF ls_auth-low(1) = '$'.
*          BREAK-POINT.
          LOOP AT pt_auth2 WHERE agr_name = ls_auth-agr_name
                             AND varbl    = ls_auth-low.
            ls_auth-low = pt_auth2-low.
            APPEND  ls_auth TO pt_auth.
          ENDLOOP.
          DELETE pt_auth INDEX l_tabix.
        ENDIF.
      ENDLOOP.

    WHEN 'S_TCODE'.
*
      RANGES: r_tcode FOR tstc-tcode.
      SELECT * FROM agr_1251 INTO TABLE @DATA(lt_1251)
         FOR ALL ENTRIES IN @pt_user
       WHERE agr_name = @pt_user-agr_name
         AND object = 'S_TCODE'.

      SELECT * FROM tstc INTO TABLE @DATA(lt_tstc)
       WHERE tcode IN @s_tcode.

      SELECT * FROM tstct INTO TABLE @DATA(lt_tstct)
       WHERE tcode IN @s_tcode
         AND sprsl = @sy-langu.

      SORT: lt_1251 BY agr_name,
            lt_tstc BY tcode,
            lt_tstct BY tcode.
      LOOP AT pt_user.
        READ TABLE lt_1251 INTO DATA(wa_1251) WITH KEY agr_name = pt_user-agr_name BINARY SEARCH.
        CHECK sy-subrc = 0.
        DATA(p_tabix) = sy-tabix.
        LOOP AT lt_1251 INTO DATA(ls_1251) FROM p_tabix WHERE agr_name = pt_user-agr_name.
          pt_auth-bname = pt_user-bname.
          pt_auth-name_text = pt_user-name_text.
          pt_auth-department = pt_user-department.
          pt_auth-agr_name = pt_user-agr_name.
          pt_auth-role_desc = pt_user-role_desc.

          REFRESH r_tcode.
          r_tcode-sign = 'I'.
          r_tcode-option = COND #( WHEN ls_1251-high = '' THEN 'CP'
                                   ELSE 'BT' ).
          r_tcode-low = pt_auth-low = ls_1251-low.
          r_tcode-high = pt_auth-high = ls_1251-high.
          APPEND r_tcode. CLEAR r_tcode.
          LOOP AT lt_tstc INTO DATA(ls_tstc) WHERE tcode IN r_tcode.
            READ TABLE lt_tstct INTO DATA(ls_tstct) WITH KEY tcode = pt_auth-low BINARY SEARCH.
            IF sy-subrc = 0.
              pt_auth-tcode_name = ls_tstct-ttext.
            ELSE.
              pt_auth-tcode_name = ''.
            ENDIF.
            APPEND pt_auth.
            EXIT.
          ENDLOOP.
        ENDLOOP.
      ENDLOOP.

*      LOOP AT pt_user.
*        SELECT  object  field low high
*          FROM agr_1251
*          INTO CORRESPONDING FIELDS OF pt_auth
*         WHERE  agr_name = pt_user-agr_name
*           AND object = 'S_TCODE'.
*          pt_auth-bname = pt_user-bname.
*          pt_auth-name_text = pt_user-name_text.
*          pt_auth-department = pt_user-department.
*          pt_auth-agr_name = pt_user-agr_name.
*          pt_auth-role_desc = pt_user-role_desc.
*
*          REFRESH: rg_tcode.
**查詢特定TCODE所屬的ROLE
*          IF s_tcode[] IS NOT INITIAL.
*            PERFORM crt_org TABLES rg_tcode
*                            USING pt_auth-low pt_auth-high.
*            SELECT *
*              FROM tstc
*             WHERE tcode IN s_tcode.
*              IF tstc-tcode IN rg_tcode.
*                APPEND pt_auth.
*                EXIT.
*              ENDIF.
*            ENDSELECT.
*          ELSE.
*            APPEND pt_auth.
*          ENDIF.
*        ENDSELECT.
*      ENDLOOP.

*      LOOP AT pt_auth INTO ls_auth.
*        SELECT SINGLE ttext INTO ls_auth-tcode_name
*          FROM tstct
*         WHERE sprsl = sy-langu
*           AND tcode =   ls_auth-low.    "請注意只抓LOW不抓HIGH的
*        IF sy-subrc <> 0.
*          CASE sy-langu.
*            WHEN 'E'.
*              l_langu = 'M'.
*            WHEN 'M'.
*              l_langu = 'E'.
*          ENDCASE.
*          SELECT SINGLE ttext
*            INTO ls_auth-tcode_name
*            FROM tstct
*           WHERE sprsl = l_langu
*             AND tcode =   ls_auth-low.    "請注意只抓LOW不抓HIGH的
*        ENDIF.
*        IF sy-subrc = 0.
*          MODIFY pt_auth FROM ls_auth.
*        ENDIF.
*      ENDLOOP.

      SORT pt_auth BY bname agr_name low.


    WHEN 'ORG'.
      LOOP AT pt_user.
        SELECT varbl low high
          FROM agr_1252
          INTO CORRESPONDING FIELDS OF pt_auth
         WHERE agr_name = pt_user-agr_name .
          pt_auth-bname = pt_user-bname.
          pt_auth-name_text = pt_user-name_text.
          pt_auth-department = pt_user-department.
          pt_auth-agr_name = pt_user-agr_name.
          pt_auth-role_desc = pt_user-role_desc.

          REFRESH: rg_bukrs,rg_gsber,rg_vkorg,rg_vtweg,rg_vstel,
                   rg_ekorg,rg_ekgrp,rg_werks,rg_kkber.
          CASE pt_auth-varbl.
            WHEN '$BUKRS'.  "company code
*查詢特定Company code所屬的ROLE
              IF s_bukrs[] IS NOT INITIAL.
                PERFORM crt_org TABLES rg_bukrs
                                USING pt_auth-low pt_auth-high.
                SELECT *
                  FROM t001
                 WHERE bukrs IN s_bukrs.
                  IF t001-bukrs IN rg_bukrs.
                    APPEND pt_auth.
                    EXIT.
                  ENDIF.
                ENDSELECT.
              ENDIF.
            WHEN '$GSBER'.  "BA
*查詢特定Business Area所屬的ROLE
              IF s_gsber[] IS NOT INITIAL.
                PERFORM crt_org TABLES rg_gsber
                                USING pt_auth-low pt_auth-high.
                SELECT *
                  FROM tgsb
                 WHERE gsber IN s_gsber.
                  IF tgsb-gsber IN rg_gsber.
                    APPEND pt_auth.
                    EXIT.
                  ENDIF.
                ENDSELECT.
              ENDIF.
            WHEN '$VKORG'.  "Sales Org.
*查詢特定Sales org所屬的ROLE
              IF s_vkorg[] IS NOT INITIAL.
                PERFORM crt_org TABLES rg_vkorg
                                USING pt_auth-low pt_auth-high.
                SELECT *
                  FROM tvko
                 WHERE vkorg IN s_vkorg.
                  IF tvko-vkorg IN rg_vkorg.
                    APPEND pt_auth.
                    EXIT.
                  ENDIF.
                ENDSELECT.
              ENDIF.
            WHEN '$VTWEG'.  "distribution channel
*查詢特定Distribution channel所屬的ROLE
              IF s_vtweg[] IS NOT INITIAL.
                PERFORM crt_org TABLES rg_vtweg
                                USING pt_auth-low pt_auth-high.
                SELECT *
                  FROM tvtw
                 WHERE vtweg IN s_vtweg.
                  IF tvtw-vtweg IN rg_vtweg.
                    APPEND pt_auth.
                    EXIT.
                  ENDIF.
                ENDSELECT.
              ENDIF.
            WHEN '$VSTEL'.  "Shipping point
*查詢特定Shipping point所屬的ROLE
              IF s_vstel[] IS NOT INITIAL.
                PERFORM crt_org TABLES rg_vstel
                                USING pt_auth-low pt_auth-high.
                SELECT *
                  FROM tvst
                 WHERE vstel IN s_vstel.
                  IF tvst-vstel IN rg_vstel.
                    APPEND pt_auth.
                    EXIT.
                  ENDIF.
                ENDSELECT.
              ENDIF.
            WHEN '$EKORG'.  "Purchase org.
*查詢特定Purchase org所屬的ROLE
              IF s_ekorg[] IS NOT INITIAL.
                PERFORM crt_org TABLES rg_ekorg
                                USING pt_auth-low pt_auth-high.
                SELECT *
                  FROM t024e
                 WHERE ekorg IN s_ekorg.
                  IF t024e-ekorg IN rg_ekorg.
                    APPEND pt_auth.
                    EXIT.
                  ENDIF.
                ENDSELECT.
              ENDIF.
            WHEN '$EKGRP'.  "Purchase group.
*查詢特定Purchase group所屬的ROLE
              IF s_ekgrp[] IS NOT INITIAL.
                PERFORM crt_org TABLES rg_ekgrp
                                USING pt_auth-low pt_auth-high.
                SELECT *
                  FROM t024
                 WHERE ekgrp IN s_ekgrp.
                  IF t024-ekgrp IN rg_ekgrp.
                    APPEND pt_auth.
                    EXIT.
                  ENDIF.
                ENDSELECT.
              ENDIF.
            WHEN '$WERKS'.  "Plant
*查詢特定Plant所屬的ROLE
              IF s_werks[] IS NOT INITIAL.
                PERFORM crt_org TABLES rg_werks
                                USING pt_auth-low pt_auth-high.
                SELECT *
                  FROM t001w
                 WHERE werks IN s_werks.
                  IF t001w-werks IN rg_werks.
                    APPEND pt_auth.
                    EXIT.
                  ENDIF.
                ENDSELECT.
              ENDIF.
            WHEN '$KKBER'.  "Credit control area
*查詢特定Credit Control Area所屬的ROLE
              IF s_kkber[] IS NOT INITIAL.
                PERFORM crt_org TABLES rg_kkber
                                USING pt_auth-low pt_auth-high.
                SELECT *
                  FROM t014
                 WHERE kkber IN s_kkber.
                  IF t014-kkber IN rg_kkber.
                    APPEND pt_auth.
                    EXIT.
                  ENDIF.
                ENDSELECT.
              ENDIF.
          ENDCASE.
          IF s_bukrs[] IS INITIAL
          AND s_gsber[] IS INITIAL
          AND s_vkorg[] IS INITIAL
          AND s_vtweg[] IS INITIAL
          AND s_vstel[] IS INITIAL
          AND s_ekorg[] IS INITIAL
          AND s_ekgrp[] IS INITIAL
          AND s_werks[] IS INITIAL
          AND s_kkber[] IS INITIAL.
            APPEND pt_auth.
          ENDIF.
        ENDSELECT.
      ENDLOOP.

      "為了避免查詢多人導致組織參數說明重複讀取，先整理沒重複的變數
      LOOP AT pt_auth INTO ls_auth.
        PERFORM get_org TABLES lt_org  USING ls_auth.
      ENDLOOP.


      LOOP AT pt_auth INTO ls_auth.
        READ TABLE lt_org INTO ls_org WITH KEY varbl = ls_auth-varbl.
        IF sy-subrc = 0.
          ls_auth-org_name = ls_org-ddtext.
          MODIFY pt_auth FROM ls_auth.
        ENDIF.
      ENDLOOP.

      SORT pt_auth BY bname agr_name varbl low.
* VXXX Added by Tristan 2025/03/24 *
    WHEN 'ROLE'.
      IF s_agr[] IS INITIAL.
        MESSAGE 'Role不可為空' TYPE 'I' DISPLAY LIKE 'E'.
        LEAVE LIST-PROCESSING.
      ENDIF.
      SELECT agr_1251~agr_name, agr_1251~low, agr_1251~high, agr_texts~text
        FROM agr_1251 INNER JOIN agr_texts
          ON agr_1251~agr_name = agr_texts~agr_name
       WHERE agr_1251~agr_name IN @s_agr
         AND agr_1251~object = 'S_TCODE'
         AND ( agr_texts~spras = 'M' OR agr_texts~spras = 'E' )
        INTO TABLE @DATA(lt_agr).
      CHECK sy-subrc = 0.
*      SELECT * FROM agr_1251 INTO TABLE @lt_1251
*       WHERE agr_name IN @s_agr
*         AND object = 'S_TCODE'.
      DATA: q_tcode TYPE RANGE OF tstct-tcode,
            l_tcode LIKE LINE OF q_tcode.
      q_tcode = VALUE #( FOR qs_1251 IN lt_1251
                       ( sign = 'I'
                         option = 'BT'
                         low = qs_1251-low
                         high = qs_1251-high )
                       ).
      l_tcode-option = 'CP'.
      MODIFY q_tcode FROM l_tcode TRANSPORTING option WHERE high = ''.

      SELECT tstc~tcode, tstct~ttext
        FROM tstc INNER JOIN tstct
          ON tstc~tcode = tstct~tcode
       WHERE tstc~tcode IN @q_tcode
         AND tstct~sprsl = @sy-langu
        INTO TABLE @DATA(it_tstc).

*      SELECT * FROM tstct INTO TABLE @lt_tstct
*       WHERE tcode IN @q_tcode
*         AND sprsl = @sy-langu.

      SORT: lt_agr BY agr_name,
            it_tstc BY tcode.
      LOOP AT lt_agr INTO DATA(ls_agr).
        DATA(lv_tabix) = sy-tabix.
        AT NEW agr_name.
          DATA(wa_agr) = lt_agr[ lv_tabix ].
          REFRESH r_tcode.
          pt_auth-agr_name = wa_agr-agr_name.
          pt_auth-role_desc = wa_agr-text.
        ENDAT.
        r_tcode-sign = 'I'.
        r_tcode-option = COND #( WHEN ls_agr-high = '' THEN 'CP'
                                 ELSE 'BT' ).
        r_tcode-low = ls_agr-low.
        r_tcode-high = ls_agr-high.
        APPEND r_tcode. CLEAR r_tcode.
        AT END OF agr_name.
*          LOOP AT it_tstc INTO DATA(wa_tstc) WHERE tcode IN r_tcode.
*            pt_auth-low = wa_tstc-tcode.
*            pt_auth-tcode_name = wa_tstc-ttext.
*            APPEND pt_auth.
*          ENDLOOP.
          DATA(tmp_tstc) = it_tstc. DELETE tmp_tstc WHERE tcode NOT IN r_tcode.
          LOOP AT tmp_tstc INTO DATA(wa_tstc).
            pt_auth-low = wa_tstc-tcode.
            pt_auth-tcode_name = wa_tstc-ttext.
            APPEND pt_auth.
          ENDLOOP.
        ENDAT.
      ENDLOOP.
      SORT pt_auth. DELETE ADJACENT DUPLICATES FROM pt_auth.
* VXXX End off *
  ENDCASE.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  DISPLAY_DATA
*&---------------------------------------------------------------------*
*       創建ALV報表
*----------------------------------------------------------------------*
FORM display_data .


  CLEAR: gt_fieldcat, gs_layout.
  REFRESH:gt_sortinfo,  gt_fieldcat .

  IF r_tcode = 'X'.
    PERFORM build_fcatalog USING:
               'BNAME' 'LT_AUTH' TEXT-l01 12,
               'NAME_TEXT' 'LT_AUTH' TEXT-l18 80,
               'DEPARTMENT' 'LT_AUTH' TEXT-l19 40,
               'AGR_NAME ' 'LT_AUTH' TEXT-l02 30,
               'ROLE_DESC ' 'LT_AUTH' TEXT-l06 80,
               'LOW' 'LT_AUTH' TEXT-l03 50,
               'HIGH' 'LT_AUTH' TEXT-l05 50,
               'TCODE_NAME' 'LT_AUTH' TEXT-l04 100.

    PERFORM sortinfo_init USING 'ORG' .

  ELSEIF r_org = 'X'.
    PERFORM build_fcatalog USING:
             'BNAME' 'LT_AUTH' TEXT-l01 12,
             'NAME_TEXT' 'LT_AUTH' TEXT-l18 80,
             'DEPARTMENT' 'LT_AUTH' TEXT-l19 40,
             'AGR_NAME ' 'LT_AUTH' TEXT-l02 30,
             'ROLE_DESC ' 'LT_AUTH' TEXT-l06 80,
             'VARBL' 'LT_AUTH' TEXT-l07 50,
             'ORG_NAME' 'LT_AUTH' TEXT-l08 50,
             'LOW' 'LT_AUTH' TEXT-l09 50,
             'HIGH' 'LT_AUTH' TEXT-l10 50.

    PERFORM sortinfo_init USING 'ORG' .
* VXXX Added by Tristan 2025/03/25 *
  ELSEIF r_roltco = 'X'.
    PERFORM build_fcatalog USING:
               'AGR_NAME ' 'LT_AUTH' TEXT-l02 30,
               'ROLE_DESC ' 'LT_AUTH' TEXT-l06 80,
               'LOW' 'LT_AUTH' TEXT-l03 50,
               'TCODE_NAME' 'LT_AUTH' TEXT-l04 100.
    PERFORM sortinfo_init USING 'ROLE' .
* VXXX End off *
  ELSE.
    PERFORM build_fcatalog USING:
         'BNAME' 'LT_AUTH' TEXT-l01 12,
         'NAME_TEXT' 'LT_AUTH' TEXT-l18 80,
         'DEPARTMENT' 'LT_AUTH' TEXT-l19 40,
         'AGR_NAME ' 'LT_AUTH' TEXT-l02 30,
         'ROLE_DESC ' 'LT_AUTH' TEXT-l06 80,
         'AUTH' 'LT_AUTH' TEXT-l17 12,
         'OBJECT' 'LT_AUTH' TEXT-l11 10,
         'OBJ_NAME' 'LT_AUTH' TEXT-l12 60,
         'FIELD' 'LT_AUTH' TEXT-l13 30,
         'FIELD_NAME' 'LT_AUTH' TEXT-l14 50,
         'LOW' 'LT_AUTH'  TEXT-l15 50,
         'HIGH' 'LT_AUTH'  TEXT-l16 50.

    PERFORM sortinfo_init USING 'ALL' .

  ENDIF.

  gs_layout-zebra = 'X'.
  gs_layout-colwidth_optimize = 'X'.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program      = sy-repid
      i_bypassing_buffer      = 'X'
      is_layout               = gs_layout
      i_callback_user_command = 'USER_COMMAND'
      it_sort                 = gt_sortinfo[]
      it_fieldcat             = gt_fieldcat[]
      i_save                  = 'A'
    TABLES
      t_outtab                = lt_auth
    EXCEPTIONS
      program_error           = 1
      OTHERS                  = 2.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  BUILD_FCATALOG
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_0492   text
*      -->P_0493   text
*      -->P_0494   text
*----------------------------------------------------------------------*
FORM build_fcatalog  USING  l_field l_tab l_text l_len.

  wa_fieldcat-fieldname      = l_field.
  wa_fieldcat-tabname        = l_tab.
  wa_fieldcat-seltext_m      = l_text.
  wa_fieldcat-outputlen      = l_len.

  APPEND wa_fieldcat TO gt_fieldcat.
  CLEAR wa_fieldcat.


ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_ORG_DSCR
*&---------------------------------------------------------------------*
*       抓組織參數
*----------------------------------------------------------------------*
FORM get_org  TABLES   p_lt_org STRUCTURE ls_org
                            USING    p_ls_auth TYPE t_auth.

  DATA: lv_fname TYPE fieldname.

  lv_fname =  p_ls_auth-varbl+1(39).   "因為VARBL有$號，要跳過
  READ TABLE lt_org INTO ls_org WITH KEY fieldname = lv_fname.
  IF sy-subrc <> 0.
    ls_org-varbl = p_ls_auth-varbl.
    ls_org-fieldname = lv_fname.

*    IF  lv_fname = 'CONGR'.
*      BREAK-POINT.
*    ENDIF.

    CLEAR lv_rollname.
    SELECT SINGLE rollname
      INTO lv_rollname
      FROM dd03l
     WHERE  fieldname = ls_org-fieldname
       AND rollname NOT LIKE 'CHAR%'                "僅顯示字元用的欄位沒有意義，剔除之
       AND rollname IS NOT NULL
       AND domname IS NOT NULL.
    IF sy-subrc = 0.
      SELECT SINGLE ddtext
        INTO ls_org-ddtext
        FROM dd04t
       WHERE rollname = lv_rollname
         AND ddlanguage = sy-langu.
    ENDIF.

    APPEND ls_org TO p_lt_org.

  ENDIF.


ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  GET_OBJ_FIELD
*&---------------------------------------------------------------------*
*  整理權限物件參數和欄位
*----------------------------------------------------------------------*
FORM get_obj_field  TABLES   p_lt_obj STRUCTURE ls_obj
                                           p_lt_field STRUCTURE ls_field
                         USING    p_ls_auth TYPE t_auth.

  READ TABLE lt_obj INTO ls_obj WITH KEY object = p_ls_auth-object.
  IF sy-subrc <> 0.

    ls_obj-object = p_ls_auth-object.

    CLEAR ls_obj-ttext.

    APPEND ls_obj TO p_lt_obj.

  ENDIF.

  READ TABLE lt_field INTO ls_field WITH KEY field  = p_ls_auth-field.
  IF sy-subrc <> 0.

    ls_field-field = p_ls_auth-field.

    CLEAR : ls_field-ddtext, lv_rollname.

    APPEND ls_field TO p_lt_field.

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  PROCESS_OBJ_FIELD
*&---------------------------------------------------------------------*
*       為避免頻繁讀取說明資料，直接一次讀取所有的OBJ/FIELD資料
*----------------------------------------------------------------------*
FORM process_obj_field .
  DATA: lt_tobjt LIKE tobjt OCCURS 0 WITH HEADER LINE.
  DATA: BEGIN OF lt_dd03t OCCURS 0,
          rollname   TYPE rollname,
          fieldname  TYPE fieldname,
          ddlanguage TYPE ddlanguage,
          ddtext     TYPE as4text,
        END OF lt_dd03t.


  SELECT * FROM tobjt APPENDING TABLE lt_tobjt.
  LOOP AT lt_obj INTO ls_obj.
    READ TABLE lt_tobjt WITH KEY object = ls_obj-object
                                            langu = 'E'.
    IF sy-subrc = 0.
      ls_obj-ttext = lt_tobjt-ttext.
      MODIFY lt_obj FROM ls_obj.
    ELSE.
      READ TABLE lt_tobjt WITH KEY object = ls_obj-object   "如果連英文都找不到，只能找德文了
                                         langu = 'D'.
      IF sy-subrc = 0.
        ls_obj-ttext = lt_tobjt-ttext.
        MODIFY lt_obj FROM ls_obj.
      ENDIF.
    ENDIF.
  ENDLOOP.

  LOOP AT lt_field INTO ls_field.
    SELECT SINGLE rollname
      INTO ls_field-rollname FROM dd03l
     WHERE fieldname = ls_field-field
       AND rollname <> ''
       AND domname <> ''.
    IF sy-subrc = 0.
      SELECT SINGLE ddtext
        INTO ls_field-ddtext FROM dd04t
       WHERE rollname =   ls_field-rollname
         AND ddlanguage = 'E'.

*奇怪的是有些欄位抓不到相關資料，先hardcode寫上
      CASE ls_field-field.
        WHEN 'ACTVT'.
          ls_field-ddtext = 'Activities'.

      ENDCASE.

      MODIFY lt_field FROM ls_field.

    ENDIF.

  ENDLOOP.


ENDFORM.

FORM sortinfo_init USING p_values .
  DATA: st_sort   TYPE  slis_sortinfo_alv,
        group     LIKE st_sort-group,
        spos      LIKE st_sort-spos,
        fieldname LIKE st_sort-fieldname,
        up        LIKE st_sort-up,
        subtot    LIKE st_sort-subtot.
  DEFINE st_sort.
    MOVE: &1 TO spos, &2 TO fieldname, &3 TO up,
          &4 TO subtot, &5 TO group.
    st_sort-spos = spos.
    st_sort-fieldname = fieldname.
    st_sort-up = up.
    st_sort-group = group.
    st_sort-subtot = subtot.
    APPEND st_sort TO gt_sortinfo.
    CLEAR st_sort.
  END-OF-DEFINITION.

  IF p_values = 'ALL'.
    st_sort: 1 'BNAME' 'X'     ' '     ' ',
                2 'NAME_TEXT' 'X' ' '  ' ',
                3 'DEPARTMENT' 'X' ' ' ' ',
                4 'AGR_NAME' 'X'  ' '      ' ',
                5 'AUTH' 'X'  ' '      ' ',
                6 'OBJECT' 'X'    ' '    ' ',
                7 'OBJ_NAME' 'X'    ' '    ' '.

  ELSEIF p_values = 'ORG'.
    st_sort: 1 'BNAME' 'X'     ' '     ' ',
                2 'NAME_TEXT' 'X' ' '  ' ',
                3 'DEPARTMENT' 'X' 'X' ' ',
                4 'AGR_NAME' 'X'  ' '      ' ',
                5 'ROLE_DESC' 'X'  ' '      ' '.
* VXXX Added by Tristan 2025/03/25 *
  ELSEIF p_values = 'ROLE'.
    st_sort: 1 'AGR_NAME'  'X' ' ' ' ',
             2 'ROLE_DESC' 'X' ' ' ' '.
* VXXX End off *
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  CRT_ORG
*&---------------------------------------------------------------------*
FORM crt_org  TABLES rg_org STRUCTURE zsrange
              USING    i_low
                       i_high.
  rg_org-low = i_low.
  rg_org-high = i_high.
  rg_org-sign = 'I'.
  IF rg_org-high = ''.
    rg_org-option = 'CP'.
  ELSE.
    rg_org-option = 'BT'.
  ENDIF.
  APPEND rg_org.
ENDFORM.
*---------------------------------------------------------------------*
*       FORM USER_COMMAND                                             *
*---------------------------------------------------------------------*
FORM user_command USING r_ucomm     LIKE sy-ucomm
                        rs_selfield TYPE slis_selfield.
  DATA: l_tcode LIKE sy-tcode.
  CASE r_ucomm.
    WHEN '&IC1'.
      READ TABLE lt_auth ASSIGNING <itab> INDEX rs_selfield-tabindex.
      IF sy-subrc = 0.
        CASE rs_selfield-fieldname.
          WHEN 'LOW'.
*點選t-code欄位值時,顯示對應所有相關的 object list
            IF r_tcode = 'X'.
              l_tcode = <itab>-low.
              PERFORM get_object_list USING <itab> l_tcode.
            ENDIF.
          WHEN 'AGR_NAME'.
*點選role 欄位值時執行t-code :PFCG
            SET PARAMETER ID 'PROFILE_GENERATOR' FIELD <itab>-agr_name.
            CALL TRANSACTION 'PFCG'.
*          WHEN 'BNAME'.
*            SET PARAMETER ID 'XUS' FIELD <itab>-bname.
*            CALL TRANSACTION 'SU01D' AND SKIP FIRST SCREEN.
        ENDCASE.
      ENDIF.
  ENDCASE.
  rs_selfield-refresh = 'X'.

ENDFORM.                    "USER_COMMAND
*&---------------------------------------------------------------------*
*&      Form  GET_OBJECT_LIST
*&---------------------------------------------------------------------*
FORM get_object_list  USING i_itab LIKE lt_auth
                            i_tcode.
  DATA: wt_user LIKE ls_user OCCURS 0 WITH HEADER LINE,
        wt_auth LIKE ls_auth OCCURS 0 WITH HEADER LINE.
  RANGES: rg_obj FOR tobj-objct.
*Get 該tcode用到的object
  REFRESH: rg_obj.
  SELECT object
    INTO rg_obj-low
    FROM usobx_c
   WHERE name = i_tcode
     AND type = 'TR'  "transaction
     AND okflag = 'Y'.
    rg_obj-sign = 'I'.
    rg_obj-option = 'EQ'.
    APPEND rg_obj.
  ENDSELECT.
*顯示該role中與該TCODE相關的object list
  REFRESH: wt_user,wt_auth.
  MOVE-CORRESPONDING i_itab TO wt_user.
  APPEND wt_user.

  PERFORM get_authdata TABLES wt_user
                              wt_auth
                       USING  'ALL'.
  IF rg_obj[] IS INITIAL.
    DELETE wt_auth WHERE object IN rg_obj.  "delete all data
  ELSE.
    DELETE wt_auth WHERE NOT object IN rg_obj.
  ENDIF.
  PERFORM display_data_detail TABLES wt_auth.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  DISPLAY_DATA_DETAIL
*&---------------------------------------------------------------------*
FORM display_data_detail TABLES t_itab STRUCTURE lt_auth.


  CLEAR: gt_fieldcat, gs_layout.
  REFRESH:gt_sortinfo,  gt_fieldcat .
  PERFORM build_fcatalog USING:
       'BNAME' 'T_ITAB' TEXT-l01 12,
       'NAME_TEXT' 'T_ITAB' TEXT-l18 80,
       'DEPARTMENT' 'T_ITAB' TEXT-l19 40,
       'AGR_NAME ' 'T_ITAB' TEXT-l02 30,
       'ROLE_DESC ' 'LT_AUTH' TEXT-l06 80,
       'AUTH' 'T_ITAB' TEXT-l17 12,
       'OBJECT' 'T_ITAB' TEXT-l11 10,
       'OBJ_NAME' 'T_ITAB' TEXT-l12 60,
       'FIELD' 'T_ITAB' TEXT-l13 30,
       'FIELD_NAME' 'T_ITAB' TEXT-l14 50,
       'LOW' 'T_ITAB'  TEXT-l15 50,
       'HIGH' 'T_ITAB'  TEXT-l16 50.

  PERFORM sortinfo_init USING 'ALL' .


  gs_layout-zebra = 'X'.
  gs_layout-colwidth_optimize = 'X'.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program = sy-repid
      i_bypassing_buffer = 'X'
      is_layout          = gs_layout
      it_sort            = gt_sortinfo[]
      it_fieldcat        = gt_fieldcat[]
      i_save             = 'A'
    TABLES
      t_outtab           = t_itab
    EXCEPTIONS
      program_error      = 1
      OTHERS             = 2.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

ENDFORM.

*Text elements
*----------------------------------------------------------
* B01 Options
* L01 USERID
* L02 Role
* L03 TCODE(From)
* L04 Desc.
* L05 TCODE(To)
* L06 Role name.
* L07 Org. variant
* L08 Org.Variant name
* L09 From
* L10 To
* L11 Object
* L12 Object name
* L13 Field
* L14 Field name
* L15 From
* L16 To
* L17 Object group
* L18 User Name
* L19 User Department


*Selection texts
*----------------------------------------------------------
* R_AUTH         Authorization Object list
* R_DES         update table zdd03m
* R_ORG         Organization list
* R_ROLTCO         角色對應交易代碼清單
* R_TCODE         Tcode list
* S_AGR D       .
* S_BUKRS D       .
* S_EKGRP D       .
* S_EKORG D       .
* S_GSBER D       .
* S_KKBER D       .
* S_OBJ D       .
* S_OCLSS D       .
* S_TCODE D       .
* S_USER D       .
* S_VKORG D       .
* S_VSTEL D       .
* S_VTWEG D       .
* S_WERKS D       .


*Messages
*----------------------------------------------------------
*
* Message class: Hard coded
*   Role不可為空

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
