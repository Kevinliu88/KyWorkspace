FUNCTION zsd_odm_xq_formula.
*"----------------------------------------------------------------------
*"*"區域介面：
*"  IMPORTING
*"     REFERENCE(E_ZTSD0107) TYPE  ZTSD0107 OPTIONAL
*"  EXPORTING
*"     VALUE(E_ZUPFORMULA) TYPE  ZUPFORMULA
*"  TABLES
*"      TKOMV STRUCTURE  KOMV
*"----------------------------------------------------------------------
  DATA:ls_a993     TYPE a993,
       lv_brand    TYPE ztqt0018-brand,
       lv_brandgrp TYPE ztqt0018-brandgrp.
  DATA: z_factor    TYPE p DECIMALS 3,
        z_kbetr     TYPE p DECIMALS 6,
        zz03        TYPE p DECIMALS 6,
        c_kbetr(15) TYPE c,
        n_kbetr(15) TYPE n.
  CHECK tkomv[] IS NOT INITIAL.
  LOOP AT tkomv.
    CHECK tkomv-kbetr <> 0.
    CLEAR : c_kbetr,n_kbetr,z_kbetr,z_factor.
    CALL FUNCTION 'CURRENCY_CONVERTING_FACTOR'
      EXPORTING
        currency = tkomv-waers
      IMPORTING
        factor   = z_factor.

    CASE tkomv-kschl.
      WHEN 'ZZ02' OR 'ZZ05'. " +
        IF tkomv-kpein NE 0.
          z_kbetr = tkomv-kbetr * z_factor / tkomv-kpein.
        ELSE.
          z_kbetr = 0.
        ENDIF.
        WRITE z_kbetr TO c_kbetr LEFT-JUSTIFIED NO-ZERO.
        SHIFT c_kbetr RIGHT DELETING TRAILING space.
        SHIFT c_kbetr RIGHT DELETING TRAILING '0'.
        SHIFT c_kbetr RIGHT DELETING TRAILING '.'.
        SHIFT c_kbetr LEFT DELETING LEADING space.
        CONCATENATE e_zupformula '+' c_kbetr INTO e_zupformula.
      WHEN 'ZZ03'. "匯率
*        zz03 = tkomv-kbetr * z_factor.
        CLEAR:ls_a993.
        SELECT SINGLE *
          FROM a993 INTO ls_a993
          WHERE kschl = 'ZZ03' AND knumh = tkomv-knumh.
        CLEAR:lv_brand,lv_brandgrp.
        IF ls_a993-vtweg = 'B1'.
          lv_brand = 'GRACO'.
          lv_brandgrp = 'WB'.
        ELSEIF ls_a993-vtweg = 'G1'.
          lv_brand = 'GRACO'.
        ELSEIF ls_a993-vtweg = 'C1'.
          lv_brand = 'CHICCO'.
          lv_brandgrp = 'CHICCO'.
        ELSEIF ls_a993-vtweg = 'J1'.
          lv_brand = 'JOIE'.
        ELSEIF ls_a993-vtweg = 'N1'.
          lv_brand = 'NUNA'.
        ELSEIF ls_a993-vtweg = 'T1'.
          lv_brand = 'TAVO'.
        ELSEIF ls_a993-vtweg = 'Z1'.
          lv_brand = 'OTHER'.
        ENDIF.
        SELECT SINGLE kursp
          FROM ztqt0018 INTO zz03
          WHERE brand = lv_brand
          AND brandgrp = lv_brandgrp
          AND fcurr = 'USD'
          AND tcurr = e_ztsd0107-zcalcur.
      WHEN 'ZZ08'. "匯率base
        IF zz03 <> 0.
          IF tkomv-kbetr NE 0
          AND z_factor NE 0.
            z_kbetr = zz03 / ( tkomv-kbetr * z_factor ).
          ELSE.
            z_kbetr = 0.
          ENDIF.
          WRITE z_kbetr TO c_kbetr LEFT-JUSTIFIED NO-ZERO.
          SHIFT c_kbetr RIGHT DELETING TRAILING space.
          SHIFT c_kbetr RIGHT DELETING TRAILING '0'.
          SHIFT c_kbetr RIGHT DELETING TRAILING '.'.
          SHIFT c_kbetr LEFT DELETING LEADING space.
          CONCATENATE e_zupformula '/' c_kbetr INTO e_zupformula.
          CLEAR: zz03.
        ENDIF.
      WHEN 'ZZ04'.  "* 權重
        WRITE tkomv-kbetr CURRENCY '3'  TO n_kbetr .
        z_kbetr = n_kbetr / 100.
        WRITE z_kbetr TO c_kbetr LEFT-JUSTIFIED NO-ZERO.
        SHIFT c_kbetr RIGHT DELETING TRAILING space.
        SHIFT c_kbetr RIGHT DELETING TRAILING '0'.
        SHIFT c_kbetr RIGHT DELETING TRAILING '.'.
        SHIFT c_kbetr LEFT DELETING LEADING space.
        CONCATENATE e_zupformula '*' c_kbetr INTO e_zupformula.
    ENDCASE.
  ENDLOOP.




ENDFUNCTION.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
