FUNCTION zconversion_exit_alpha_input.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(INPUT) TYPE  CLIKE
*"  EXPORTING
*"     VALUE(OUTPUT) TYPE  CLIKE
*"----------------------------------------------------------------------
* MODIFICATION LOG
************************************************************************
* CHANGE DATE VERSION MODIFIER DESCRIPTION
* =========== ======= ======== =========================================
* 2025/01/15  V000    Marie    Created
************************************************************************

  DATA: l_string      TYPE string,
        l_htype       LIKE dd01v-datatype,
        l_matnr18(18) TYPE c.

  CALL 'CONVERSION_EXIT_ALPHA_INPUT'  ID 'INPUT'  FIELD input
                                      ID 'OUTPUT' FIELD output.

* Numeric Material?
  CALL FUNCTION 'NUMERIC_CHECK'
    EXPORTING
      string_in  = input
    IMPORTING
      string_out = l_matnr18
      htype      = l_htype.

  CASE l_htype.
    WHEN 'NUMC'.
      output = l_matnr18.
    WHEN OTHERS.
      output = input.
  ENDCASE.

ENDFUNCTION.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
