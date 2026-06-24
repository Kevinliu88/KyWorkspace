REPORT zab135_ddic_export.

*---------------------------------------------------------------------*
* Export DDIC object definitions to text files.
*
* S/4HANA-ready rewrite of legacy report Z_56_DDIC_TXT.
* Supported object types:
*   - Transparent tables, pooled/cluster tables where still available,
*     views and structures handled by DDIF_FIELDINFO_GET
*   - Data elements handled by DDIF_DTEL_GET
*   - Domains handled by DDIF_DOMA_GET
*
* Output format is intentionally close to the legacy tool:
*   [OBJECT_NAME]
*   fieldname | rollname | datatype | length | decimals | description
*---------------------------------------------------------------------*

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-t01.
  PARAMETERS p_ddic TYPE char255 OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-t02.
  PARAMETERS p_path TYPE char255 LOWER CASE.
SELECTION-SCREEN END OF BLOCK b2.

CLASS lcl_ddic_export DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES tt_name   TYPE STANDARD TABLE OF ddobjname WITH EMPTY KEY.
    TYPES tt_dfies  TYPE STANDARD TABLE OF dfies     WITH DEFAULT KEY.
    TYPES tt_string TYPE STANDARD TABLE OF string    WITH EMPTY KEY.
    TYPES tt_dd07v  TYPE STANDARD TABLE OF dd07v     WITH DEFAULT KEY.

    " Component list read straight from DD03L. Used as a fallback for deep
    " structures (those containing table-type / reference components) that
    " DDIF_FIELDINFO_GET cannot flatten and therefore returns empty for.
    TYPES: BEGIN OF ty_dd03l,
             position  TYPE dd03l-position,
             fieldname TYPE dd03l-fieldname,
             rollname  TYPE dd03l-rollname,
             datatype  TYPE dd03l-datatype,
             leng      TYPE dd03l-leng,
             decimals  TYPE dd03l-decimals,
             comptype  TYPE dd03l-comptype,
             inttype   TYPE dd03l-inttype,
             precfield TYPE dd03l-precfield,
           END OF ty_dd03l.
    TYPES tt_dd03l TYPE STANDARD TABLE OF ty_dd03l WITH DEFAULT KEY.

    CONSTANTS:
      c_true          TYPE abap_bool VALUE abap_true,
      c_false         TYPE abap_bool VALUE abap_false,
      c_codepage_utf8 TYPE abap_encoding VALUE '4110'.

    CLASS-METHODS run
      IMPORTING
        iv_ddic TYPE char255
        iv_path TYPE char255.

  PRIVATE SECTION.
    CLASS-METHODS parse_names
      IMPORTING
        iv_input        TYPE char255
      RETURNING
        VALUE(rt_names) TYPE tt_name.

    CLASS-METHODS build_path
      IMPORTING
        iv_path            TYPE char255
        iv_object_name     TYPE ddobjname
      RETURNING
        VALUE(rv_fullpath) TYPE string.

    CLASS-METHODS build_object_output
      IMPORTING
        iv_name        TYPE ddobjname
      EXPORTING
        et_lines       TYPE tt_string
        ev_found       TYPE abap_bool
        ev_object_type TYPE string
        ev_error_text  TYPE string.

    CLASS-METHODS build_fieldinfo_output
      IMPORTING
        iv_name  TYPE ddobjname
        it_dfies TYPE tt_dfies
      EXPORTING
        et_lines TYPE tt_string.

    CLASS-METHODS build_dtel_output
      IMPORTING
        iv_name  TYPE ddobjname
        is_dd04v TYPE dd04v
      EXPORTING
        et_lines TYPE tt_string.

    CLASS-METHODS build_doma_output
      IMPORTING
        iv_name  TYPE ddobjname
        is_dd01v TYPE dd01v
        it_dd07v TYPE tt_dd07v
      EXPORTING
        et_lines TYPE tt_string.

    CLASS-METHODS try_get_fieldinfo
      IMPORTING
        iv_name       TYPE ddobjname
      EXPORTING
        et_dfies      TYPE tt_dfies
        ev_found      TYPE abap_bool
        ev_error_text TYPE string.

    CLASS-METHODS try_get_dtel
      IMPORTING
        iv_name       TYPE ddobjname
      EXPORTING
        es_dd04v      TYPE dd04v
        ev_found      TYPE abap_bool
        ev_error_text TYPE string.

    CLASS-METHODS try_get_doma
      IMPORTING
        iv_name       TYPE ddobjname
      EXPORTING
        es_dd01v      TYPE dd01v
        et_dd07v      TYPE tt_dd07v
        ev_found      TYPE abap_bool
        ev_error_text TYPE string.

    CLASS-METHODS try_get_dd03l
      IMPORTING
        iv_name       TYPE ddobjname
      EXPORTING
        et_fields     TYPE tt_dd03l
        ev_found      TYPE abap_bool
        ev_error_text TYPE string.

    CLASS-METHODS build_dd03l_output
      IMPORTING
        iv_name   TYPE ddobjname
        it_fields TYPE tt_dd03l
      EXPORTING
        et_lines  TYPE tt_string.

    CLASS-METHODS try_get_ttyp
      IMPORTING
        iv_name       TYPE ddobjname
      EXPORTING
        es_dd40v      TYPE dd40v
        ev_found      TYPE abap_bool
        ev_error_text TYPE string.

    CLASS-METHODS build_ttyp_output
      IMPORTING
        iv_name  TYPE ddobjname
        is_dd40v TYPE dd40v
      EXPORTING
        et_lines TYPE tt_string.

    CLASS-METHODS get_dtel_text
      IMPORTING
        iv_name        TYPE rollname
      RETURNING
        VALUE(rv_text) TYPE dd04t-ddtext.

    CLASS-METHODS get_doma_text
      IMPORTING
        iv_name        TYPE domname
      RETURNING
        VALUE(rv_text) TYPE dd01t-ddtext.

    CLASS-METHODS get_field_text
      IMPORTING
        iv_object_name TYPE tabname
        iv_tabname     TYPE tabname
        iv_fieldname   TYPE fieldname
        iv_rollname    TYPE rollname
        iv_dfies_text  TYPE csequence
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS read_dd03t_text
      IMPORTING
        iv_tabname     TYPE tabname
        iv_fieldname   TYPE fieldname
        iv_langu       TYPE sylangu
      RETURNING
        VALUE(rv_text) TYPE dd03t-ddtext.

    CLASS-METHODS append_field_line
      IMPORTING
        iv_fieldname       TYPE csequence
        iv_rollname        TYPE csequence
        iv_datatype        TYPE csequence
        VALUE(iv_length)   TYPE string
        VALUE(iv_decimals) TYPE string
        iv_text            TYPE csequence
      CHANGING
        ct_lines           TYPE tt_string.

    CLASS-METHODS download_file
      IMPORTING
        iv_fullpath TYPE string
      CHANGING
        ct_lines    TYPE tt_string.
ENDCLASS.

CLASS lcl_ddic_export IMPLEMENTATION.
  METHOD run.
    DATA lt_names       TYPE tt_name.
    DATA lt_lines       TYPE tt_string.
    DATA lv_fullpath    TYPE string.
    DATA lv_found       TYPE abap_bool.
    DATA lv_object_type TYPE string.
    DATA lv_error_text  TYPE string.
    DATA lv_count       TYPE i.

    lt_names = parse_names( iv_ddic ).

    IF lt_names IS INITIAL.
      MESSAGE 'No DDIC object was entered.' TYPE 'E'.
      RETURN.
    ENDIF.

    LOOP AT lt_names INTO DATA(lv_name).
      CLEAR: lt_lines, lv_fullpath, lv_found, lv_object_type, lv_error_text.

      build_object_output(
        EXPORTING
          iv_name        = lv_name
        IMPORTING
          et_lines       = lt_lines
          ev_found       = lv_found
          ev_object_type = lv_object_type
          ev_error_text  = lv_error_text ).

      IF lv_found <> c_true.
        IF lv_error_text IS INITIAL.
          lv_error_text = |DDIC object { lv_name } was not found.|.
        ENDIF.
        MESSAGE lv_error_text TYPE 'E'.
        CONTINUE.
      ENDIF.

      lv_fullpath = build_path(
        iv_path        = iv_path
        iv_object_name = lv_name ).

      download_file(
        EXPORTING
          iv_fullpath = lv_fullpath
        CHANGING
          ct_lines    = lt_lines ).

      lv_count = lv_count + 1.
      WRITE: / |Exported { lv_name } ({ lv_object_type }) -> { lv_fullpath }|.
    ENDLOOP.

    MESSAGE |DDIC export completed. Objects exported: { lv_count }.| TYPE 'S'.
  ENDMETHOD.

  METHOD parse_names.
    DATA lt_parts TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    SPLIT iv_input AT ',' INTO TABLE lt_parts.

    LOOP AT lt_parts INTO DATA(lv_part).
      DATA(lv_clean) = lv_part.
      CONDENSE lv_clean.
      TRANSLATE lv_clean TO UPPER CASE.

      IF lv_clean IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_name) = CONV ddobjname( lv_clean ).

      READ TABLE rt_names WITH KEY table_line = lv_name TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        APPEND lv_name TO rt_names.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_path.
    DATA lv_path        TYPE string.
    DATA lv_filename    TYPE string.
    DATA lv_last_char   TYPE c LENGTH 1.
    DATA lv_last_offset TYPE i.

    lv_filename = |{ iv_object_name }.txt|.

    IF iv_path IS INITIAL.
      rv_fullpath = lv_filename.
      RETURN.
    ENDIF.

    lv_path = iv_path.
    SHIFT lv_path LEFT  DELETING LEADING space.
    SHIFT lv_path RIGHT DELETING TRAILING space.

    IF strlen( lv_path ) > 0.
      lv_last_offset = strlen( lv_path ) - 1.
      lv_last_char = lv_path+lv_last_offset(1).

      IF lv_last_char <> '\' AND lv_last_char <> '/'.
        CONCATENATE lv_path '\' INTO lv_path.
      ENDIF.
    ENDIF.

    rv_fullpath = |{ lv_path }{ lv_filename }|.
  ENDMETHOD.

  METHOD build_object_output.
    DATA lt_dfies TYPE tt_dfies.
    DATA ls_dd04v TYPE dd04v.
    DATA ls_dd01v TYPE dd01v.
    DATA lt_dd07v TYPE tt_dd07v.
    DATA lt_dd03l TYPE tt_dd03l.
    DATA ls_dd40v TYPE dd40v.

    CLEAR: et_lines, ev_found, ev_object_type, ev_error_text.

    try_get_fieldinfo(
      EXPORTING
        iv_name       = iv_name
      IMPORTING
        et_dfies      = lt_dfies
        ev_found      = ev_found
        ev_error_text = ev_error_text ).

    IF ev_found = c_true.
      ev_object_type = 'TABLE/STRUCTURE/VIEW'.
      build_fieldinfo_output(
        EXPORTING
          iv_name  = iv_name
          it_dfies = lt_dfies
        IMPORTING
          et_lines = et_lines ).
      RETURN.
    ENDIF.

    " DDIF_FIELDINFO_GET only flattens flat tables/structures/views. Deep
    " structures (with table-type/reference components) come back empty, so read
    " the component list straight from DD03L.
    try_get_dd03l(
      EXPORTING
        iv_name       = iv_name
      IMPORTING
        et_fields     = lt_dd03l
        ev_found      = ev_found
        ev_error_text = ev_error_text ).

    IF ev_found = c_true.
      ev_object_type = 'STRUCTURE (DEEP)'.
      build_dd03l_output(
        EXPORTING
          iv_name   = iv_name
          it_fields = lt_dd03l
        IMPORTING
          et_lines  = et_lines ).
      RETURN.
    ENDIF.

    try_get_ttyp(
      EXPORTING
        iv_name       = iv_name
      IMPORTING
        es_dd40v      = ls_dd40v
        ev_found      = ev_found
        ev_error_text = ev_error_text ).

    IF ev_found = c_true.
      ev_object_type = 'TABLE TYPE'.
      build_ttyp_output(
        EXPORTING
          iv_name  = iv_name
          is_dd40v = ls_dd40v
        IMPORTING
          et_lines = et_lines ).
      RETURN.
    ENDIF.

    try_get_dtel(
      EXPORTING
        iv_name       = iv_name
      IMPORTING
        es_dd04v      = ls_dd04v
        ev_found      = ev_found
        ev_error_text = ev_error_text ).

    IF ev_found = c_true.
      ev_object_type = 'DATA ELEMENT'.
      build_dtel_output(
        EXPORTING
          iv_name  = iv_name
          is_dd04v = ls_dd04v
        IMPORTING
          et_lines = et_lines ).
      RETURN.
    ENDIF.

    try_get_doma(
      EXPORTING
        iv_name       = iv_name
      IMPORTING
        es_dd01v      = ls_dd01v
        et_dd07v      = lt_dd07v
        ev_found      = ev_found
        ev_error_text = ev_error_text ).

    IF ev_found = c_true.
      ev_object_type = 'DOMAIN'.
      build_doma_output(
        EXPORTING
          iv_name  = iv_name
          is_dd01v = ls_dd01v
          it_dd07v = lt_dd07v
        IMPORTING
          et_lines = et_lines ).
      RETURN.
    ENDIF.

    ev_found = c_false.
    ev_error_text = |DDIC object { iv_name } was not found as table/structure/view, deep structure, table type, data element, or domain.|.
  ENDMETHOD.

  METHOD build_fieldinfo_output.
    DATA lv_fieldname TYPE string.
    DATA lv_rollname  TYPE string.
    DATA lv_datatype  TYPE string.
    DATA lv_length    TYPE string.
    DATA lv_decimals  TYPE string.
    DATA lv_text      TYPE string.

    CLEAR et_lines.
    APPEND |[{ iv_name }]| TO et_lines.

    LOOP AT it_dfies INTO DATA(ls_dfies).
      CLEAR: lv_fieldname, lv_rollname, lv_datatype, lv_length, lv_decimals.

      IF ls_dfies-fieldname(1) = '.'
         OR ls_dfies-fieldname = 'INCLUDE'
         OR ls_dfies-inttype = 'h'.
        lv_fieldname = '.INCLUDE'.
        lv_rollname  = ls_dfies-rollname.

        IF lv_rollname IS INITIAL.
          lv_rollname = ls_dfies-tabname.
        ENDIF.

        IF lv_rollname IS INITIAL.
          lv_rollname = ls_dfies-fieldname.
        ENDIF.

        lv_datatype = 'STRU'.
        lv_length   = '0'.
        lv_decimals = '0'.
      ELSE.
        lv_fieldname = ls_dfies-fieldname.
        lv_rollname  = ls_dfies-rollname.

        IF lv_rollname IS INITIAL.
          lv_rollname = ls_dfies-fieldname.
        ENDIF.

        lv_datatype = ls_dfies-datatype.
        lv_length   = |{ ls_dfies-leng }|.
        lv_decimals = |{ ls_dfies-decimals }|.
        CONDENSE: lv_length, lv_decimals.
      ENDIF.

      lv_text = get_field_text(
        iv_object_name = iv_name
        iv_tabname    = ls_dfies-tabname
        iv_fieldname  = ls_dfies-fieldname
        iv_rollname   = ls_dfies-rollname
        iv_dfies_text = ls_dfies-fieldtext ).

      append_field_line(
        EXPORTING
          iv_fieldname = lv_fieldname
          iv_rollname  = lv_rollname
          iv_datatype  = lv_datatype
          iv_length    = lv_length
          iv_decimals  = lv_decimals
          iv_text      = lv_text
        CHANGING
          ct_lines     = et_lines ).
    ENDLOOP.
  ENDMETHOD.

  METHOD build_dtel_output.
    DATA lv_length   TYPE string.
    DATA lv_decimals TYPE string.

    CLEAR et_lines.
    APPEND |[{ iv_name }]| TO et_lines.

    lv_length = |{ is_dd04v-leng }|.
    lv_decimals = |{ is_dd04v-decimals }|.
    CONDENSE: lv_length, lv_decimals.

    append_field_line(
      EXPORTING
        iv_fieldname = '(ELEMENT)'
        iv_rollname  = iv_name
        iv_datatype  = is_dd04v-datatype
        iv_length    = lv_length
        iv_decimals  = lv_decimals
        iv_text      = get_dtel_text( is_dd04v-rollname )
      CHANGING
        ct_lines     = et_lines ).
  ENDMETHOD.

  METHOD build_doma_output.
    DATA lv_value    TYPE string.
    DATA lv_text     TYPE string.
    DATA lv_length   TYPE string.
    DATA lv_decimals TYPE string.

    CLEAR et_lines.
    APPEND |[{ iv_name }]| TO et_lines.

    lv_length = |{ is_dd01v-leng }|.
    lv_decimals = |{ is_dd01v-decimals }|.
    CONDENSE: lv_length, lv_decimals.

    lv_text = get_doma_text( is_dd01v-domname ).
    IF lv_text IS INITIAL.
      lv_text = is_dd01v-ddtext.
    ENDIF.

    append_field_line(
      EXPORTING
        iv_fieldname = '(DOMAIN)'
        iv_rollname  = iv_name
        iv_datatype  = is_dd01v-datatype
        iv_length    = lv_length
        iv_decimals  = lv_decimals
        iv_text      = lv_text
      CHANGING
        ct_lines     = et_lines ).

    LOOP AT it_dd07v INTO DATA(ls_dd07v).
      IF ls_dd07v-domvalue_h IS INITIAL.
        lv_value = |={ ls_dd07v-domvalue_l }|.
      ELSE.
        lv_value = |={ ls_dd07v-domvalue_l }..{ ls_dd07v-domvalue_h }|.
      ENDIF.

      append_field_line(
        EXPORTING
          iv_fieldname = lv_value
          iv_rollname  = iv_name
          iv_datatype  = 'VALUE'
          iv_length    = '0'
          iv_decimals  = '0'
          iv_text      = ls_dd07v-ddtext
        CHANGING
          ct_lines     = et_lines ).
    ENDLOOP.
  ENDMETHOD.

  METHOD build_dd03l_output.
    DATA lv_fieldname TYPE string.
    DATA lv_rollname  TYPE string.
    DATA lv_datatype  TYPE string.
    DATA lv_text      TYPE string.

    CLEAR et_lines.
    APPEND |[{ iv_name }]| TO et_lines.

    LOOP AT it_fields INTO DATA(ls_field).
      CLEAR: lv_fieldname, lv_rollname, lv_datatype, lv_text.

      IF ls_field-fieldname(1) = '.' OR ls_field-fieldname = 'INCLUDE'.
        lv_fieldname = '.INCLUDE'.
        lv_rollname  = ls_field-rollname.
        IF lv_rollname IS INITIAL.
          lv_rollname = ls_field-precfield.
        ENDIF.
        IF lv_rollname IS INITIAL.
          lv_rollname = ls_field-fieldname.
        ENDIF.

        append_field_line(
          EXPORTING
            iv_fieldname = lv_fieldname
            iv_rollname  = lv_rollname
            iv_datatype  = 'STRU'
            iv_length    = '0'
            iv_decimals  = '0'
            iv_text      = ''
          CHANGING
            ct_lines     = et_lines ).
        CONTINUE.
      ENDIF.

      lv_fieldname = ls_field-fieldname.
      lv_rollname  = ls_field-rollname.
      IF lv_rollname IS INITIAL.
        lv_rollname = ls_field-fieldname.
      ENDIF.

      " COMPTYPE classifies the component: E = elementary, S = structure,
      " L = table type (the deep part), R = data reference.
      CASE ls_field-comptype.
        WHEN 'L'.
          lv_datatype = 'TTYP'.
        WHEN 'S'.
          lv_datatype = 'STRU'.
        WHEN 'R'.
          lv_datatype = 'REF'.
        WHEN OTHERS.
          lv_datatype = ls_field-datatype.
          IF lv_datatype IS INITIAL.
            lv_datatype = ls_field-inttype.
          ENDIF.
      ENDCASE.

      lv_text = get_field_text(
        iv_object_name = iv_name
        iv_tabname     = iv_name
        iv_fieldname   = ls_field-fieldname
        iv_rollname    = ls_field-rollname
        iv_dfies_text  = '' ).

      append_field_line(
        EXPORTING
          iv_fieldname = lv_fieldname
          iv_rollname  = lv_rollname
          iv_datatype  = lv_datatype
          iv_length    = |{ ls_field-leng }|
          iv_decimals  = |{ ls_field-decimals }|
          iv_text      = lv_text
        CHANGING
          ct_lines     = et_lines ).
    ENDLOOP.
  ENDMETHOD.

  METHOD build_ttyp_output.
    DATA lv_rowtype  TYPE string.
    DATA lv_datatype TYPE string.
    DATA lv_length   TYPE string.
    DATA lt_sub      TYPE tt_string.
    DATA lv_found    TYPE abap_bool.
    DATA lv_objtype  TYPE string.
    DATA lv_error    TYPE string.

    CLEAR et_lines.
    APPEND |[{ iv_name }]| TO et_lines.

    lv_rowtype = is_dd40v-rowtype.

    IF is_dd40v-datatype IS NOT INITIAL.
      " Table of an elementary type (CHAR, INT4, ...).
      lv_datatype = is_dd40v-datatype.
      lv_length   = |{ is_dd40v-leng }|.
    ELSE.
      " Table of a structure / table / reference.
      lv_datatype = 'STRU'.
      lv_length   = '0'.
    ENDIF.

    append_field_line(
      EXPORTING
        iv_fieldname = '(TABLE TYPE)'
        iv_rollname  = COND #( WHEN lv_rowtype IS NOT INITIAL THEN lv_rowtype ELSE |{ iv_name }| )
        iv_datatype  = lv_datatype
        iv_length    = lv_length
        iv_decimals  = |{ is_dd40v-decimals }|
        iv_text      = is_dd40v-ddtext
      CHANGING
        ct_lines     = et_lines ).

    " When the row type is itself a DDIC object, expand its definition so the
    " file shows the table's full row layout, not just the row type name.
    IF lv_rowtype IS NOT INITIAL.
      build_object_output(
        EXPORTING
          iv_name        = CONV ddobjname( lv_rowtype )
        IMPORTING
          et_lines       = lt_sub
          ev_found       = lv_found
          ev_object_type = lv_objtype
          ev_error_text  = lv_error ).

      IF lv_found = c_true.
        " Skip the row type's own [header] line; keep its field lines.
        LOOP AT lt_sub INTO DATA(lv_line) FROM 2.
          APPEND lv_line TO et_lines.
        ENDLOOP.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD try_get_fieldinfo.
    CLEAR: et_dfies, ev_found, ev_error_text.

    CALL FUNCTION 'DDIF_FIELDINFO_GET'
      EXPORTING
        tabname        = iv_name
        langu          = sy-langu
      TABLES
        dfies_tab      = et_dfies
      EXCEPTIONS
        not_found      = 1
        internal_error = 2
        OTHERS         = 3.

    IF sy-subrc = 0 AND et_dfies IS NOT INITIAL.
      ev_found = c_true.
      RETURN.
    ENDIF.

    ev_found = c_false.

    IF sy-subrc > 1.
      ev_error_text = |Error reading field information for { iv_name }. SY-SUBRC={ sy-subrc }.|.
    ENDIF.
  ENDMETHOD.

  METHOD try_get_dtel.
    CLEAR: es_dd04v, ev_found, ev_error_text.

    CALL FUNCTION 'DDIF_DTEL_GET'
      EXPORTING
        name          = iv_name
        state         = 'A'
        langu         = sy-langu
      IMPORTING
        dd04v_wa      = es_dd04v
      EXCEPTIONS
        illegal_input = 1
        not_found     = 2
        OTHERS        = 3.

    " DDIF_DTEL_GET may return SY-SUBRC = 0 with an empty work area when the
    " name is not actually a data element (e.g. a table type or deep structure).
    " Require a populated work area so such objects are not silently written out
    " as bogus "(ELEMENT) | ... |  | 000000 | 000000 |" lines.
    IF sy-subrc = 0 AND es_dd04v-datatype IS NOT INITIAL.
      ev_found = c_true.
      RETURN.
    ENDIF.

    ev_found = c_false.

    IF sy-subrc <> 2 AND sy-subrc <> 0.
      ev_error_text = |Error reading data element { iv_name }. SY-SUBRC={ sy-subrc }.|.
    ENDIF.
  ENDMETHOD.

  METHOD try_get_doma.
    CLEAR: es_dd01v, et_dd07v, ev_found, ev_error_text.

    CALL FUNCTION 'DDIF_DOMA_GET'
      EXPORTING
        name          = iv_name
        state         = 'A'
        langu         = sy-langu
      IMPORTING
        dd01v_wa      = es_dd01v
      TABLES
        dd07v_tab     = et_dd07v
      EXCEPTIONS
        illegal_input = 1
        not_found     = 2
        OTHERS        = 3.

    " Same defensive check as for data elements: only treat as a domain when the
    " work area actually came back populated.
    IF sy-subrc = 0 AND es_dd01v-datatype IS NOT INITIAL.
      ev_found = c_true.
      RETURN.
    ENDIF.

    ev_found = c_false.

    IF sy-subrc <> 2 AND sy-subrc <> 0.
      ev_error_text = |Error reading domain { iv_name }. SY-SUBRC={ sy-subrc }.|.
    ENDIF.
  ENDMETHOD.

  METHOD try_get_dd03l.
    CLEAR: et_fields, ev_found, ev_error_text.

    SELECT position, fieldname, rollname, datatype, leng, decimals,
           comptype, inttype, precfield
      FROM dd03l
      WHERE tabname  = @iv_name
        AND as4local = 'A'
      ORDER BY position
      INTO CORRESPONDING FIELDS OF TABLE @et_fields.

    IF sy-subrc = 0 AND et_fields IS NOT INITIAL.
      ev_found = c_true.
    ELSE.
      ev_found = c_false.
    ENDIF.
  ENDMETHOD.

  METHOD try_get_ttyp.
    CLEAR: es_dd40v, ev_found, ev_error_text.

    CALL FUNCTION 'DDIF_TTYP_GET'
      EXPORTING
        name          = iv_name
        state         = 'A'
        langu         = sy-langu
      IMPORTING
        dd40v_wa      = es_dd40v
      EXCEPTIONS
        illegal_input = 1
        not_found     = 2
        OTHERS        = 3.

    IF sy-subrc = 0 AND es_dd40v-typename IS NOT INITIAL.
      ev_found = c_true.
      RETURN.
    ENDIF.

    ev_found = c_false.

    IF sy-subrc <> 2 AND sy-subrc <> 0.
      ev_error_text = |Error reading table type { iv_name }. SY-SUBRC={ sy-subrc }.|.
    ENDIF.
  ENDMETHOD.

  METHOD get_dtel_text.
    DATA lv_ddtext TYPE dd04t-ddtext.

    SELECT SINGLE ddtext
      FROM dd04t
      WHERE rollname   = @iv_name
        AND ddlanguage = @sy-langu
        AND as4local   = 'A'
        AND as4vers    = '0000'
      INTO @lv_ddtext.

    IF sy-subrc = 0.
      rv_text = lv_ddtext.
      RETURN.
    ENDIF.

    IF sy-langu <> 'E'.
      CLEAR lv_ddtext.
      SELECT SINGLE ddtext
        FROM dd04t
        WHERE rollname   = @iv_name
          AND ddlanguage = 'E'
          AND as4local   = 'A'
          AND as4vers    = '0000'
        INTO @lv_ddtext.

      IF sy-subrc = 0.
        rv_text = lv_ddtext.
        RETURN.
      ENDIF.
    ENDIF.

    IF sy-langu <> 'M'.
      CLEAR lv_ddtext.
      SELECT SINGLE ddtext
        FROM dd04t
        WHERE rollname   = @iv_name
          AND ddlanguage = 'M'
          AND as4local   = 'A'
          AND as4vers    = '0000'
        INTO @lv_ddtext.

      IF sy-subrc = 0.
        rv_text = lv_ddtext.
        RETURN.
      ENDIF.
    ENDIF.

    IF sy-langu <> '1'.
      CLEAR lv_ddtext.
      SELECT SINGLE ddtext
        FROM dd04t
        WHERE rollname   = @iv_name
          AND ddlanguage = '1'
          AND as4local   = 'A'
          AND as4vers    = '0000'
        INTO @lv_ddtext.

      IF sy-subrc = 0.
        rv_text = lv_ddtext.
        RETURN.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD get_doma_text.
    SELECT SINGLE ddtext
      FROM dd01t
      WHERE domname    = @iv_name
        AND ddlanguage = @sy-langu
        AND as4local   = 'A'
        AND as4vers    = '0000'
      INTO @rv_text.

    IF sy-subrc <> 0 AND sy-langu <> 'E'.
      SELECT SINGLE ddtext
        FROM dd01t
        WHERE domname    = @iv_name
          AND ddlanguage = 'E'
          AND as4local   = 'A'
          AND as4vers    = '0000'
        INTO @rv_text.
    ENDIF.
  ENDMETHOD.

  METHOD get_field_text.
    rv_text = iv_dfies_text.

    IF rv_text IS NOT INITIAL.
      RETURN.
    ENDIF.

    rv_text = read_dd03t_text(
      iv_tabname   = iv_object_name
      iv_fieldname = iv_fieldname
      iv_langu     = sy-langu ).

    IF rv_text IS NOT INITIAL.
      RETURN.
    ENDIF.

    IF iv_tabname <> iv_object_name.
      rv_text = read_dd03t_text(
        iv_tabname   = iv_tabname
        iv_fieldname = iv_fieldname
        iv_langu     = sy-langu ).

      IF rv_text IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    IF sy-langu <> 'E'.
      rv_text = read_dd03t_text(
        iv_tabname   = iv_object_name
        iv_fieldname = iv_fieldname
        iv_langu     = 'E' ).

      IF rv_text IS NOT INITIAL.
        RETURN.
      ENDIF.

      IF iv_tabname <> iv_object_name.
        rv_text = read_dd03t_text(
          iv_tabname   = iv_tabname
          iv_fieldname = iv_fieldname
          iv_langu     = 'E' ).

        IF rv_text IS NOT INITIAL.
          RETURN.
        ENDIF.
      ENDIF.
    ENDIF.

    " Common SAP language keys for Chinese texts. This helps when the
    " GUI language is English but custom field texts were maintained in Chinese.
    IF sy-langu <> 'M'.
      rv_text = read_dd03t_text(
        iv_tabname   = iv_object_name
        iv_fieldname = iv_fieldname
        iv_langu     = 'M' ).

      IF rv_text IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    IF sy-langu <> '1'.
      rv_text = read_dd03t_text(
        iv_tabname   = iv_object_name
        iv_fieldname = iv_fieldname
        iv_langu     = '1' ).

      IF rv_text IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    IF iv_rollname IS NOT INITIAL.
      rv_text = get_dtel_text( iv_rollname ).
    ENDIF.
  ENDMETHOD.

  METHOD read_dd03t_text.
    SELECT SINGLE ddtext
      FROM dd03t
      WHERE tabname    = @iv_tabname
        AND fieldname  = @iv_fieldname
        AND ddlanguage = @iv_langu
        AND as4local   = 'A'
      INTO @rv_text.
  ENDMETHOD.

  METHOD append_field_line.
    DATA lv_length   TYPE string.
    DATA lv_decimals TYPE string.
    DATA lv_line     TYPE string.

    lv_length = |{ iv_length }|.
    lv_decimals = |{ iv_decimals }|.
    CONDENSE: lv_length, lv_decimals.

    CONCATENATE iv_fieldname iv_rollname iv_datatype
                lv_length lv_decimals iv_text
           INTO lv_line SEPARATED BY ' | '.
    APPEND lv_line TO ct_lines.
  ENDMETHOD.

  METHOD download_file.
    CALL METHOD cl_gui_frontend_services=>gui_download
      EXPORTING
        filename                = iv_fullpath
        filetype                = 'ASC'
        codepage                = c_codepage_utf8
      CHANGING
        data_tab                = ct_lines
      EXCEPTIONS
        file_write_error        = 1
        no_batch                = 2
        gui_refuse_filetransfer = 3
        invalid_type            = 4
        no_authority            = 5
        unknown_error           = 6
        header_not_allowed      = 7
        separator_not_allowed   = 8
        filesize_not_allowed    = 9
        header_too_long         = 10
        dp_error_create         = 11
        dp_error_send           = 12
        dp_error_write          = 13
        unknown_dp_error        = 14
        access_denied           = 15
        dp_out_of_memory        = 16
        disk_full               = 17
        dp_timeout              = 18
        file_not_found          = 19
        dataprovider_exception  = 20
        control_flush_error     = 21
        not_supported_by_gui    = 22
        error_no_gui            = 23
        OTHERS                  = 24.

    IF sy-subrc <> 0.
      MESSAGE |Unable to download { iv_fullpath }. SY-SUBRC={ sy-subrc }.| TYPE 'E'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  lcl_ddic_export=>run(
    iv_ddic = p_ddic
    iv_path = p_path ).

*---------------------------------------------------------------------*
* Text symbols to maintain in the text pool:
*   T01 DDIC Objects (comma-separated)
*   T02 Frontend Download Path (optional)
*---------------------------------------------------------------------*


*Messages
*----------------------------------------------------------
*
* Message class: Hard coded
*   No DDIC object was entered.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
