FUNCTION z_sd_convert_kunnr_to_wlpno.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(I_KUNNR) TYPE  KUNNR
*"  EXPORTING
*"     REFERENCE(E_ALTKN) TYPE  ALTKN
*"  EXCEPTIONS
*"      CUSTOMER_MAPPING_NOT_FOUND
*"----------------------------------------------------------------------

  CLEAR e_altkn.
  CHECK i_kunnr IS NOT INITIAL.
  READ TABLE gt_custmap ASSIGNING FIELD-SYMBOL(<gt_custmap>) WITH TABLE KEY kunnr = i_kunnr.
  IF sy-subrc <> 0.
    INSERT VALUE #( kunnr = i_kunnr ) INTO TABLE gt_custmap ASSIGNING <gt_custmap>.
    SELECT altkn
           FROM knb1 INTO TABLE @DATA(lt_altkn)
           WHERE kunnr = @i_kunnr.
    LOOP AT lt_altkn ASSIGNING FIELD-SYMBOL(<altkn>)
                     WHERE table_line IS NOT INITIAL.
      EXIT.
    ENDLOOP.
    IF sy-subrc = 0.
      <gt_custmap>-altkn = <altkn>.
    ENDIF.
  ENDIF.

  e_altkn = <gt_custmap>-altkn.

  IF e_altkn IS INITIAL.
    MESSAGE s398(00) RAISING customer_mapping_not_found
                     WITH 'Customer'(002) i_kunnr
                          'has no mapping maintained'(001) space.
  ENDIF.
ENDFUNCTION.


*Messages
*----------------------------------------------------------
*
* Message class: 00
*398   & & & &

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
