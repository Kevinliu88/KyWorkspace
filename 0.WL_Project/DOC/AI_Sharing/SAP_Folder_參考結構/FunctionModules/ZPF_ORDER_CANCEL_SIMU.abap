FUNCTION zpf_order_cancel_simu.
*"----------------------------------------------------------------------
*"*"區域介面：
*"  IMPORTING
*"     VALUE(I_INPUT) TYPE  ZPSRP0001
*"  EXPORTING
*"     VALUE(E_RETURN) TYPE  BAPIRET2
*"  TABLES
*"      IT_RESULT STRUCTURE  ZPSRP0002
*"----------------------------------------------------------------------
  TYPES:BEGIN OF ty_index,
          index TYPE mdmldelay-index,
          menge TYPE zpsrp0002-menge,
        END OF ty_index.
  DATA:ls_input           TYPE zpsrp0001,
       lv_delkz           TYPE mdps-delkz,
       lv_del12           TYPE mdps-del12,
       lv_delps           TYPE mdps-delps,
       lt_mldelay         TYPE md_t_mldelay,
       lt_result          TYPE TABLE OF zpsrp0002,
       lv_flag            TYPE c,
       lv_index           TYPE mdmldelay-index,
       lv_times           TYPE i,
       lv_count           TYPE i,
       lv_count_do        TYPE i,
       lv_zex_hier        TYPE zpsrp0002-zex_hier,
       lt_index           TYPE TABLE OF ty_index,
       lt_index_do        LIKE lt_index,
       lt_stpox           TYPE TABLE OF stpox,
       ls_mldelay_index_1 TYPE mdmldelay.

  CLEAR: ls_input, lv_delkz, lv_del12, lv_delps, lt_result[], lv_flag,
         lv_index, lv_times, lv_count, lv_zex_hier, lt_index[],
         lt_stpox[], ls_mldelay_index_1.

  ls_input = i_input.

**SO+SO Item
  IF ls_input-kdauf IS NOT INITIAL AND ls_input-kdpos IS NOT INITIAL.
    lv_delkz = 'VC'.
    lv_del12 = ls_input-kdauf.
    lv_delps = ls_input-kdpos.
**Order
  ELSEIF ls_input-aufnr IS NOT INITIAL.
    lv_delkz = 'FE'.
    lv_del12 = ls_input-aufnr.
**Planned Order
  ELSEIF ls_input-plnum IS NOT INITIAL.
    lv_delkz = 'PA'.
    lv_del12 = ls_input-plnum.
  ENDIF.


  "找不到就展BOM

  CALL FUNCTION 'MD_SALES_ORDER_STATUS_REPORT'
    EXPORTING
      edelkz     = lv_delkz
      edelnr     = lv_del12
      edelps     = lv_delps
      memory_id  = 'PLHS'
      nodisp     = 'X'
      i_profid   = 'SAP000000001'
    IMPORTING
      et_mldelay = lt_mldelay
    EXCEPTIONS
      error      = 1
      OTHERS     = 2.
  IF sy-subrc <> 0.
    "Message Error
    e_return-id = sy-msgid.
    e_return-type = 'E'.
    e_return-number = sy-msgno.
    e_return-message_v1 = sy-msgv1.
    e_return-message_v2 = sy-msgv2.
    e_return-message_v3 = sy-msgv3.
    e_return-message_v4 = sy-msgv4.
  ELSE.
    SELECT DISTINCT a~rsnum, a~rspos, a~aufnr, a~plnum, a~banfn, a~bnfpo,
                    a~ebeln, a~ebelp, a~sobkz, a~werks, a~matnr, a~bdmng,
                    b~delkz, a~baugr
      FROM resb AS a INNER JOIN @lt_mldelay AS b
                             ON a~rsnum = substring( b~delnr, 1, 10 )
                            AND a~rspos = substring( b~delps, 3, 4 )
      INTO TABLE @DATA(lt_resb) ##ITAB_KEY_IN_SELECT.
    IF sy-subrc = 0.
      SORT lt_resb BY rsnum rspos.
    ENDIF.

    SELECT matnr, werks, beskz, sobsl
      FROM marc
     WHERE EXISTS ( SELECT DISTINCT a~matnr, werks FROM @lt_mldelay AS a
                     WHERE a~matnr = marc~matnr
                       AND a~werks = marc~werks )
     ORDER BY matnr, werks
      INTO TABLE @DATA(lt_marc) ##ITAB_KEY_IN_SELECT.

    "保留Father為1的資料
    DATA(lt_father) = lt_mldelay[].
    DELETE lt_father WHERE father <> 1.

    "讀取Index為1、Father為0的資料
    READ TABLE lt_mldelay WITH KEY index = '1'
                                   father = '0'
                          ASSIGNING FIELD-SYMBOL(<lfs_mldelay_index_1>).
    IF sy-subrc = 0.
      ls_mldelay_index_1 = <lfs_mldelay_index_1>.
    ENDIF.
    UNASSIGN <lfs_mldelay_index_1>.

    "撈取工單表頭數量
    SELECT aufnr, gamng FROM afko
     WHERE EXISTS ( SELECT a~aufnr FROM @lt_resb AS a
                     WHERE a~aufnr = afko~aufnr
                       AND a~delkz = 'AR' ) "工單
     ORDER BY aufnr
      INTO TABLE @DATA(lt_afko).

    "撈取計畫單數量
    SELECT plnum, gsmng FROM plaf
     WHERE EXISTS ( SELECT a~plnum FROM @lt_resb AS a
                     WHERE a~plnum = plaf~plnum
                       AND a~delkz IN ('SB','BB') ) "計畫單
     ORDER BY plnum
      INTO TABLE @DATA(lt_plaf).

    "撈取請購單數量
    SELECT banfn, bnfpo, menge FROM eban
     WHERE EXISTS ( SELECT a~banfn, a~bnfpo FROM @lt_resb AS a
                     WHERE a~banfn = eban~banfn
                       AND a~bnfpo = eban~bnfpo
                       AND a~delkz = 'BB' ) "請購單
     ORDER BY banfn, bnfpo
      INTO TABLE @DATA(lt_eban).

    "撈取採購單數量
    SELECT ebeln, ebelp, menge FROM ekpo
     WHERE EXISTS ( SELECT a~ebeln, a~ebelp FROM @lt_resb AS a
                     WHERE a~ebeln = ekpo~ebeln
                       AND a~ebelp = ekpo~ebelp
                       AND a~delkz = 'BB' ) "採購單
     ORDER BY ebeln, ebelp
      INTO TABLE @DATA(lt_ekpo).

    "新增Group 情境
    TYPES: BEGIN OF ty_mldelay_index,
             index TYPE mdmldelay-index,
             z_ff  TYPE mdmldelay-index,
           END OF ty_mldelay_index.
    DATA: lv_z_ff          TYPE mdmldelay-index,
          lv_count_gp      TYPE i,
          lv_menge_sum     TYPE zpsrp0002-menge,
          lv_menge_gp      TYPE zpsrp0002-menge,
          lv_flag_gp       TYPE c,
          lt_mldelay_index TYPE TABLE OF ty_mldelay_index.
    DATA(lt_mldelay_sort) = lt_mldelay[].
    SORT lt_mldelay_sort BY matnr index.

    LOOP AT lt_father ASSIGNING FIELD-SYMBOL(<lfs_father>).
      CLEAR: lv_zex_hier, lv_times, lv_flag.
      "讀取預留單
      READ TABLE lt_resb WITH KEY rsnum = <lfs_father>-delnr
                                  rspos = <lfs_father>-delps
                         ASSIGNING FIELD-SYMBOL(<lfs_resb>)
                         BINARY SEARCH.
      IF sy-subrc = 0.
        "第一階
        lv_zex_hier = 1.
        APPEND INITIAL LINE TO lt_result ASSIGNING FIELD-SYMBOL(<lfs_result>).
        <lfs_result>-zex_hier  = lv_zex_hier. "展開階層
        "若MRP element為VC帶入SO+SO Item
        IF lv_delkz = 'VC'.
          <lfs_result>-kdauf = lv_del12.
          <lfs_result>-kdpos = lv_delps.
*        ELSE.
*          <lfs_result>-del12 = lv_del12. "工單/預留單
        ENDIF.
        <lfs_result>-del12  = ls_mldelay_index_1-rcenr. "原始工單/計畫單
        <lfs_result>-werks = <lfs_resb>-werks. "工廠
        <lfs_result>-rsnum = <lfs_resb>-rsnum. "預留單
        <lfs_result>-rspos = <lfs_resb>-rspos. "預留單項目
        <lfs_result>-matnr = <lfs_resb>-matnr. "物料
        <lfs_result>-delkz = ls_mldelay_index_1-rcekz.  "原始MRP元素
        <lfs_result>-index = <lfs_father>-index.
        "判斷是否有相同物料的資料且得出每筆的Z_FF
        CLEAR: lv_menge_gp, lv_menge_sum, lv_count_gp, lv_flag_gp, lt_mldelay_index[].
        LOOP AT lt_mldelay_sort ASSIGNING FIELD-SYMBOL(<lfs_mldelay_chk>)
                                WHERE matnr = <lfs_father>-matnr.
          CLEAR lv_z_ff.
          "讀取預留單
          READ TABLE lt_resb WITH KEY rsnum = <lfs_mldelay_chk>-delnr
                                      rspos = <lfs_mldelay_chk>-delps
                             ASSIGNING FIELD-SYMBOL(<lfs_resb_chk>)
                             BINARY SEARCH.
          IF sy-subrc = 0.
            "取得Z_FF=>讀取符合需求溯源的INDEX且INDEX比該筆小
            LOOP AT lt_mldelay_sort ASSIGNING FIELD-SYMBOL(<lfs_mldelay_sort>)
                                    WHERE matnr = <lfs_resb_chk>-baugr
                                      AND index < <lfs_mldelay_chk>-index.
              "若為空紀錄INDEX
              IF lv_z_ff IS INITIAL.
                lv_z_ff = <lfs_mldelay_sort>-index.
              ELSE.
                "判斷當前讀到的INDEX是否大於上一筆, 優先取用最大的INDEX
                IF <lfs_mldelay_sort>-index > lv_z_ff.
                  lv_z_ff = <lfs_mldelay_sort>-index.
                ENDIF.
              ENDIF.
            ENDLOOP.
            UNASSIGN <lfs_mldelay_sort>.
            "若為空Z_FF帶入1
            IF lv_z_ff IS INITIAL.
              lv_z_ff = <lfs_mldelay_chk>-father.
            ENDIF.
            "若需求溯源料號相同才紀錄
            IF <lfs_resb>-baugr = <lfs_resb_chk>-baugr.
              "紀錄INDEX及Z_FF
              lt_mldelay_index = VALUE #( BASE lt_mldelay_index ( index = <lfs_mldelay_chk>-index
                                                                  z_ff = lv_z_ff  ) ).
            ENDIF.
          ENDIF.
          UNASSIGN <lfs_resb_chk>.
        ENDLOOP.
        UNASSIGN <lfs_mldelay_chk>.
        "若不為空
        IF lt_mldelay_index[] IS NOT INITIAL.
          "取得當前循環INDEX的Z_FF
          READ TABLE lt_mldelay_index WITH KEY index =  <lfs_father>-index
                                      ASSIGNING FIELD-SYMBOL(<lfs_mldelay_index>).
          IF sy-subrc = 0.
            "將相同Z_FF的INDEX對應的表頭數量合併計算
            LOOP AT lt_mldelay_index ASSIGNING FIELD-SYMBOL(<lfs_mldelay_index_sum>)
                                     WHERE z_ff = <lfs_mldelay_index>-z_ff.
              "計算筆數
              lv_count_gp = lv_count_gp + 1.
              "取得表頭數量
              READ TABLE lt_mldelay WITH KEY index = <lfs_mldelay_index_sum>-index
                                    ASSIGNING FIELD-SYMBOL(<lfs_mldelay_sum>).
              IF sy-subrc = 0.
                "讀取預留單
                READ TABLE lt_resb WITH KEY rsnum = <lfs_mldelay_sum>-delnr
                                            rspos = <lfs_mldelay_sum>-delps
                                   ASSIGNING FIELD-SYMBOL(<lfs_resb_sum>)
                                   BINARY SEARCH.
                IF sy-subrc = 0.
                  CASE <lfs_mldelay_sum>-delkz.
                    WHEN 'AR'. "工單
                      READ TABLE lt_afko WITH KEY aufnr = <lfs_resb_sum>-aufnr
                                         ASSIGNING FIELD-SYMBOL(<lfs_afko_sum>)
                                         BINARY SEARCH.
                      IF sy-subrc = 0.
                        "累加表頭數量
                        lv_menge_sum = <lfs_afko_sum>-gamng + lv_menge_sum.
                      ENDIF.
                      UNASSIGN <lfs_afko_sum>.
                    WHEN 'SB'. "計畫單
                      READ TABLE lt_plaf WITH KEY plnum = <lfs_resb_sum>-plnum
                                         ASSIGNING FIELD-SYMBOL(<lfs_plaf_sum>)
                                         BINARY SEARCH.
                      IF sy-subrc = 0.
                        "累加表頭數量
                        lv_menge_sum = <lfs_plaf_sum>-gsmng + lv_menge_sum.
                      ENDIF.
                      UNASSIGN <lfs_plaf_sum>.
                    WHEN 'BB'. "請購/採購單/計畫單
                      READ TABLE lt_ekpo WITH KEY ebeln = <lfs_resb_sum>-ebeln
                                                  ebelp = <lfs_resb_sum>-ebelp
                                         ASSIGNING FIELD-SYMBOL(<lfs_ekpo_sum>)
                                         BINARY SEARCH.
                      IF sy-subrc = 0.
                        "累加表頭數量
                        lv_menge_sum = <lfs_ekpo_sum>-menge + lv_menge_sum.
                      ELSE.
                        READ TABLE lt_eban WITH KEY banfn = <lfs_resb_sum>-banfn
                                                    bnfpo = <lfs_resb_sum>-bnfpo
                                           ASSIGNING FIELD-SYMBOL(<lfs_eban_sum>)
                                           BINARY SEARCH.
                        IF sy-subrc = 0.
                          "累加表頭數量
                          lv_menge_sum = <lfs_eban_sum>-menge + lv_menge_sum.
                        ELSE.
                          READ TABLE lt_plaf WITH KEY plnum = <lfs_resb_sum>-plnum
                                             ASSIGNING <lfs_plaf_sum>
                                             BINARY SEARCH.
                          IF sy-subrc = 0.
                            "累加表頭數量
                            lv_menge_sum = <lfs_plaf_sum>-gsmng + lv_menge_sum.
                          ENDIF.
                          UNASSIGN <lfs_plaf_sum>.
                        ENDIF.
                      ENDIF.
                      UNASSIGN <lfs_eban_sum>.
                  ENDCASE.
                ENDIF.
                UNASSIGN <lfs_resb_sum>.
              ENDIF.
              UNASSIGN <lfs_mldelay_sum>.
            ENDLOOP.
            UNASSIGN <lfs_mldelay_index_sum>.
            "若Z_FF的資料大於1筆
            IF lv_count_gp > 1.
              lv_menge_gp = ls_input-menge.
              "百分比計算旗標
              lv_flag_gp = 'X'.
            ENDIF.
          ENDIF.
          UNASSIGN <lfs_mldelay_index>.
        ENDIF.
        "計算展開數量=>傳入展開數量 除 單據數量 乘 預留單數量 乘 表頭數量除總表頭數量
        CASE <lfs_father>-delkz.
          WHEN 'AR'. "工單
            READ TABLE lt_afko WITH KEY aufnr = <lfs_resb>-aufnr
                               ASSIGNING FIELD-SYMBOL(<lfs_afko>)
                               BINARY SEARCH.
            IF sy-subrc = 0.
              IF ls_input-menge <> 0 AND <lfs_afko>-gamng <> 0 AND <lfs_resb>-bdmng <> 0.
                IF lv_flag_gp = 'X'.
                  <lfs_result>-menge = ( lv_menge_gp / <lfs_afko>-gamng ) *  <lfs_resb>-bdmng * ( <lfs_afko>-gamng / lv_menge_sum ).
                ELSE.
                  <lfs_result>-menge = ( ls_input-menge / <lfs_afko>-gamng ) *  <lfs_resb>-bdmng.
                ENDIF.
              ENDIF.
            ENDIF.
            UNASSIGN <lfs_afko>.
          WHEN 'SB'. "計畫單
            READ TABLE lt_plaf WITH KEY plnum = <lfs_resb>-plnum
                               ASSIGNING FIELD-SYMBOL(<lfs_plaf>)
                               BINARY SEARCH.
            IF sy-subrc = 0.
              IF ls_input-menge <> 0 AND <lfs_plaf>-gsmng <> 0 AND <lfs_resb>-bdmng <> 0.
                IF lv_flag_gp = 'X'.
                  <lfs_result>-menge = ( lv_menge_gp / <lfs_plaf>-gsmng ) *  <lfs_resb>-bdmng * ( <lfs_plaf>-gsmng / lv_menge_sum ).
                ELSE.
                  <lfs_result>-menge = ( ls_input-menge / <lfs_plaf>-gsmng ) *  <lfs_resb>-bdmng.
                ENDIF.
              ENDIF.
            ENDIF.
            UNASSIGN <lfs_plaf>.
          WHEN 'BB'. "請購/採購單/計畫單
            READ TABLE lt_ekpo WITH KEY ebeln = <lfs_resb>-ebeln
                                        ebelp = <lfs_resb>-ebelp
                               ASSIGNING FIELD-SYMBOL(<lfs_ekpo>)
                               BINARY SEARCH.
            IF sy-subrc = 0.
              IF ls_input-menge <> 0 AND <lfs_ekpo>-menge <> 0 AND <lfs_resb>-bdmng <> 0.
                IF lv_flag_gp = 'X'.
                  <lfs_result>-menge = ( lv_menge_gp / <lfs_ekpo>-menge ) *  <lfs_resb>-bdmng * ( <lfs_ekpo>-menge / lv_menge_sum ).
                ELSE.
                  <lfs_result>-menge = ( ls_input-menge / <lfs_ekpo>-menge ) *  <lfs_resb>-bdmng.
                ENDIF.
              ENDIF.
            ELSE.
              READ TABLE lt_eban WITH KEY banfn = <lfs_resb>-banfn
                                          bnfpo = <lfs_resb>-bnfpo
                                 ASSIGNING FIELD-SYMBOL(<lfs_eban>)
                                 BINARY SEARCH.
              IF sy-subrc = 0.
                IF ls_input-menge <> 0 AND <lfs_eban>-menge <> 0 AND <lfs_resb>-bdmng <> 0.
                  IF lv_flag_gp = 'X'.
                    <lfs_result>-menge = ( lv_menge_gp / <lfs_eban>-menge ) *  <lfs_resb>-bdmng * ( <lfs_eban>-menge / lv_menge_sum ).
                  ELSE.
                    <lfs_result>-menge = ( ls_input-menge / <lfs_eban>-menge ) *  <lfs_resb>-bdmng.
                  ENDIF.
                ENDIF.
              ELSE.
                READ TABLE lt_plaf WITH KEY plnum = <lfs_resb>-plnum
                                   ASSIGNING <lfs_plaf>
                                   BINARY SEARCH.
                IF sy-subrc = 0.
                  IF ls_input-menge <> 0 AND <lfs_plaf>-gsmng <> 0 AND <lfs_resb>-bdmng <> 0.
                    IF lv_flag_gp = 'X'.
                      <lfs_result>-menge = ( lv_menge_gp / <lfs_plaf>-gsmng ) *  <lfs_resb>-bdmng * ( <lfs_plaf>-gsmng / lv_menge_sum ).
                    ELSE.
                      <lfs_result>-menge = ( ls_input-menge / <lfs_plaf>-gsmng ) *  <lfs_resb>-bdmng.
                    ENDIF.
                  ENDIF.
                ENDIF.
                UNASSIGN <lfs_plaf>.
              ENDIF.
            ENDIF.
            UNASSIGN <lfs_eban>.
        ENDCASE.

        DATA(lv_menge) = <lfs_result>-menge.
        DATA(lv_flag_45d) = <lfs_result>-flag.

        IF <lfs_resb>-sobkz = 'E'.
          "若預留/相關需求號碼為空, 此筆資料僅為第一階不往下執行
          IF <lfs_father>-nxtrs IS INITIAL.
            CONTINUE.
          ENDIF.
          "將預留/相關需求號碼不為空的資料, 展開完整階層
          WHILE lv_flag = space.
            CLEAR: lv_count_do, lt_index_do[].
            "階層加1
            lv_zex_hier = lv_zex_hier + 1.
            IF lv_times = space. "第二階
              lv_count = 1.
              lt_index = VALUE #( ( index = <lfs_father>-index menge = <lfs_result>-menge  ) ).
              lv_times = lv_times + 1.
            ENDIF.
            "紀錄此次迴圈的階層筆數及INDEX
            lv_count_do = lv_count.
            lt_index_do[] = lt_index[].
            IF lt_index[] IS NOT INITIAL.
              "清空此次迴圈的階層筆數及INDEX, 紀錄下階層的筆數及INDEX
              CLEAR: lv_count, lt_index[].
              "此階層共有幾筆
              DO lv_count_do TIMES.
                "讀取INDEX
                READ TABLE lt_index_do INDEX sy-index
                                       ASSIGNING FIELD-SYMBOL(<lfs_index_do>).
                IF sy-subrc = 0.
                  LOOP AT lt_mldelay ASSIGNING FIELD-SYMBOL(<lfs_mldelay>)
                                     WHERE father = <lfs_index_do>-index.
                    "讀取預留單
                    READ TABLE lt_resb WITH KEY rsnum = <lfs_mldelay>-delnr
                                                rspos = <lfs_mldelay>-delps
                                       ASSIGNING FIELD-SYMBOL(<lfs_resb_1>)
                                       BINARY SEARCH.
                    IF sy-subrc = 0.
                      APPEND INITIAL LINE TO lt_result ASSIGNING <lfs_result>.
                      <lfs_result>-zex_hier  = lv_zex_hier. "展開階層
                      "若MRP element為VC帶入SO+SO Item
                      IF lv_delkz = 'VC'.
                        <lfs_result>-kdauf = lv_del12.
                        <lfs_result>-kdpos = lv_delps.
*                      ELSE.
*                        <lfs_result>-del12 = lv_del12. "工單/預留單
                      ENDIF.
                      <lfs_result>-del12  = ls_mldelay_index_1-rcenr. "原始工單/計畫單
                      <lfs_result>-werks = <lfs_resb_1>-werks. "工廠
                      <lfs_result>-rsnum = <lfs_resb_1>-rsnum. "預留單
                      <lfs_result>-rspos = <lfs_resb_1>-rspos. "預留單項目
                      <lfs_result>-matnr = <lfs_resb_1>-matnr. "物料
                      <lfs_result>-delkz = ls_mldelay_index_1-rcekz.  "原始MRP元素
                      <lfs_result>-index = <lfs_mldelay>-index.
                      "若MRP element為SB標記為轉用LL/45D
                      IF <lfs_mldelay>-rcekz = 'SB'.
                        <lfs_result>-flag      = 'X'.
                      ENDIF.
                      "判斷是否有相同物料的資料且得出每筆的Z_FF
                      CLEAR: lv_menge_gp, lv_menge_sum, lv_count_gp, lv_flag_gp, lt_mldelay_index[].
                      LOOP AT lt_mldelay_sort ASSIGNING <lfs_mldelay_chk>
                                              WHERE matnr = <lfs_mldelay>-matnr.
                        CLEAR lv_z_ff.
                        "讀取預留單
                        READ TABLE lt_resb WITH KEY rsnum = <lfs_mldelay_chk>-delnr
                                                    rspos = <lfs_mldelay_chk>-delps
                                           ASSIGNING <lfs_resb_chk>
                                           BINARY SEARCH.
                        IF sy-subrc = 0.
                          "取得Z_FF=>讀取符合需求溯源的INDEX且INDEX比該筆小
                          LOOP AT lt_mldelay_sort ASSIGNING <lfs_mldelay_sort>
                                                  WHERE matnr = <lfs_resb_chk>-baugr
                                                    AND index < <lfs_mldelay_chk>-index.
                            "若為空紀錄INDEX
                            IF lv_z_ff IS INITIAL.
                              lv_z_ff = <lfs_mldelay_sort>-index.
                            ELSE.
                              "判斷當前讀到的INDEX是否大於上一筆, 優先取用最大的INDEX
                              IF <lfs_mldelay_sort>-index > lv_z_ff.
                                lv_z_ff = <lfs_mldelay_sort>-index.
                              ENDIF.
                            ENDIF.
                          ENDLOOP.
                          UNASSIGN <lfs_mldelay_sort>.
                          IF lv_z_ff IS NOT INITIAL.
                            "紀錄INDEX及Z_FF
                            lt_mldelay_index = VALUE #( BASE lt_mldelay_index ( index = <lfs_mldelay_chk>-index
                                                                                z_ff = lv_z_ff  ) ).
                          ENDIF.
                        ENDIF.
                        UNASSIGN <lfs_resb_chk>.
                      ENDLOOP.
                      UNASSIGN <lfs_mldelay_chk>.
                      "若不為空
                      IF lt_mldelay_index[] IS NOT INITIAL.
                        "取得當前循環INDEX的Z_FF
                        READ TABLE lt_mldelay_index WITH KEY index =  <lfs_mldelay>-index
                                                    ASSIGNING <lfs_mldelay_index>.
                        IF sy-subrc = 0.
                          "將相同Z_FF的INDEX對應的表頭數量合併計算
                          LOOP AT lt_mldelay_index ASSIGNING <lfs_mldelay_index_sum>
                                                   WHERE z_ff = <lfs_mldelay_index>-z_ff.
                            "計算筆數
                            lv_count_gp = lv_count_gp + 1.
                            "取得表頭數量
                            READ TABLE lt_mldelay WITH KEY index = <lfs_mldelay_index_sum>-index
                                                  ASSIGNING <lfs_mldelay_sum>.
                            IF sy-subrc = 0.
                              "讀取預留單
                              READ TABLE lt_resb WITH KEY rsnum = <lfs_mldelay_sum>-delnr
                                                          rspos = <lfs_mldelay_sum>-delps
                                                 ASSIGNING <lfs_resb_sum>
                                                 BINARY SEARCH.
                              IF sy-subrc = 0.
                                CASE <lfs_mldelay_sum>-delkz.
                                  WHEN 'AR'. "工單
                                    READ TABLE lt_afko WITH KEY aufnr = <lfs_resb_sum>-aufnr
                                                       ASSIGNING <lfs_afko_sum>
                                                       BINARY SEARCH.
                                    IF sy-subrc = 0.
                                      "累加表頭數量
                                      lv_menge_sum = <lfs_afko_sum>-gamng + lv_menge_sum.
                                    ENDIF.
                                    UNASSIGN <lfs_afko_sum>.
                                  WHEN 'SB'. "計畫單
                                    READ TABLE lt_plaf WITH KEY plnum = <lfs_resb_sum>-plnum
                                                       ASSIGNING <lfs_plaf_sum>
                                                       BINARY SEARCH.
                                    IF sy-subrc = 0.
                                      "累加表頭數量
                                      lv_menge_sum = <lfs_plaf_sum>-gsmng + lv_menge_sum.
                                    ENDIF.
                                    UNASSIGN <lfs_plaf_sum>.
                                  WHEN 'BB'. "請購/採購單/計畫單
                                    READ TABLE lt_ekpo WITH KEY ebeln = <lfs_resb_sum>-ebeln
                                                                ebelp = <lfs_resb_sum>-ebelp
                                                       ASSIGNING <lfs_ekpo_sum>
                                                       BINARY SEARCH.
                                    IF sy-subrc = 0.
                                      "累加表頭數量
                                      lv_menge_sum = <lfs_ekpo_sum>-menge + lv_menge_sum.
                                    ELSE.
                                      READ TABLE lt_eban WITH KEY banfn = <lfs_resb_sum>-banfn
                                                                  bnfpo = <lfs_resb_sum>-bnfpo
                                                         ASSIGNING <lfs_eban_sum>
                                                         BINARY SEARCH.
                                      IF sy-subrc = 0.
                                        "累加表頭數量
                                        lv_menge_sum = <lfs_eban_sum>-menge + lv_menge_sum.
                                      ELSE.
                                        READ TABLE lt_plaf WITH KEY plnum = <lfs_resb_sum>-plnum
                                                           ASSIGNING <lfs_plaf_sum>
                                                           BINARY SEARCH.
                                        IF sy-subrc = 0.
                                          "累加表頭數量
                                          lv_menge_sum = <lfs_plaf_sum>-gsmng + lv_menge_sum.
                                        ENDIF.
                                        UNASSIGN <lfs_plaf_sum>.
                                      ENDIF.
                                    ENDIF.
                                    UNASSIGN <lfs_eban_sum>.
                                ENDCASE.
                              ENDIF.
                              UNASSIGN <lfs_resb_sum>.
                            ENDIF.
                            UNASSIGN <lfs_mldelay_sum>.
                          ENDLOOP.
                          UNASSIGN <lfs_mldelay_index_sum>.
                          "若Z_FF的資料大於1筆
                          IF lv_count_gp > 1.
                            "取得Z_FF的展開數量
                            READ TABLE lt_result WITH KEY index = <lfs_mldelay_index>-z_ff
                                                 ASSIGNING FIELD-SYMBOL(<lfs_result_gp>).
                            IF sy-subrc = 0.
                              lv_menge_gp = <lfs_result_gp>-menge.
                            ENDIF.
                            UNASSIGN <lfs_result_gp>.
                            "百分比計算旗標
                            lv_flag_gp = 'X'.
                          ENDIF.
                        ENDIF.
                        UNASSIGN <lfs_mldelay_index>.
                      ENDIF.
                      "計算展開數量=>傳入展開數量 除 單據數量 乘 預留單數量 乘 表頭數量除總表頭數量
                      CASE <lfs_mldelay>-delkz.
                        WHEN 'AR'. "工單
                          READ TABLE lt_afko WITH KEY aufnr = <lfs_resb_1>-aufnr
                                             ASSIGNING <lfs_afko>
                                             BINARY SEARCH.
                          IF sy-subrc = 0.
                            IF <lfs_index_do>-menge <> 0 AND <lfs_afko>-gamng <> 0 AND <lfs_resb_1>-bdmng <> 0.
                              IF lv_flag_gp = 'X'.
                                <lfs_result>-menge = ( lv_menge_gp / <lfs_afko>-gamng ) *  <lfs_resb_1>-bdmng * ( <lfs_afko>-gamng / lv_menge_sum ).
                              ELSE.
                                <lfs_result>-menge = ( <lfs_index_do>-menge / <lfs_afko>-gamng ) *  <lfs_resb_1>-bdmng.
                              ENDIF.
                            ENDIF.
                          ENDIF.
                          UNASSIGN <lfs_afko>.
                        WHEN 'SB'. "計畫單
                          READ TABLE lt_plaf WITH KEY plnum = <lfs_resb_1>-plnum
                                             ASSIGNING <lfs_plaf>
                                             BINARY SEARCH.
                          IF sy-subrc = 0.
                            IF <lfs_index_do>-menge <> 0 AND <lfs_plaf>-gsmng <> 0 AND <lfs_resb_1>-bdmng <> 0.
                              IF lv_flag_gp = 'X'.
                                <lfs_result>-menge = ( lv_menge_gp / <lfs_plaf>-gsmng ) *  <lfs_resb_1>-bdmng * ( <lfs_plaf>-gsmng / lv_menge_sum ).
                              ELSE.
                                <lfs_result>-menge = ( <lfs_index_do>-menge / <lfs_plaf>-gsmng ) *  <lfs_resb_1>-bdmng.
                              ENDIF.
                            ENDIF.
                          ENDIF.
                          UNASSIGN <lfs_plaf>.
                        WHEN 'BB'. "請購/採購單/計畫單
                          READ TABLE lt_ekpo WITH KEY ebeln = <lfs_resb_1>-ebeln
                                                      ebelp = <lfs_resb_1>-ebelp
                                             ASSIGNING <lfs_ekpo>
                                             BINARY SEARCH.
                          IF sy-subrc = 0.
                            IF <lfs_index_do>-menge <> 0 AND <lfs_ekpo>-menge <> 0 AND <lfs_resb_1>-bdmng <> 0.
                              IF lv_flag_gp = 'X'.
                                <lfs_result>-menge = ( lv_menge_gp / <lfs_ekpo>-menge ) *  <lfs_resb_1>-bdmng * ( <lfs_ekpo>-menge / lv_menge_sum ).
                              ELSE.
                                <lfs_result>-menge = ( <lfs_index_do>-menge / <lfs_ekpo>-menge ) *  <lfs_resb_1>-bdmng.
                              ENDIF.
                            ENDIF.
                          ELSE.
                            READ TABLE lt_eban WITH KEY banfn = <lfs_resb_1>-banfn
                                                        bnfpo = <lfs_resb_1>-bnfpo
                                               ASSIGNING <lfs_eban>
                                               BINARY SEARCH.
                            IF sy-subrc = 0.
                              IF <lfs_index_do>-menge <> 0 AND <lfs_eban>-menge <> 0 AND <lfs_resb_1>-bdmng <> 0.
                                IF lv_flag_gp = 'X'.
                                  <lfs_result>-menge = ( lv_menge_gp / <lfs_eban>-menge ) *  <lfs_resb_1>-bdmng * ( <lfs_eban>-menge / lv_menge_sum ).
                                ELSE.
                                  <lfs_result>-menge = ( <lfs_index_do>-menge / <lfs_eban>-menge ) *  <lfs_resb_1>-bdmng.
                                ENDIF.
                              ENDIF.
                            ELSE.
                              READ TABLE lt_plaf WITH KEY plnum = <lfs_resb_1>-plnum
                                                 ASSIGNING <lfs_plaf>
                                                 BINARY SEARCH.
                              IF sy-subrc = 0.
                                IF <lfs_index_do>-menge <> 0 AND <lfs_plaf>-gsmng <> 0 AND <lfs_resb_1>-bdmng <> 0.
                                  IF lv_flag_gp = 'X'.
                                    <lfs_result>-menge = ( lv_menge_gp / <lfs_plaf>-gsmng ) *  <lfs_resb_1>-bdmng * ( <lfs_plaf>-gsmng / lv_menge_sum ).
                                  ELSE.
                                    <lfs_result>-menge = ( <lfs_index_do>-menge / <lfs_plaf>-gsmng ) *  <lfs_resb_1>-bdmng.
                                  ENDIF.
                                ENDIF.
                              ENDIF.
                              UNASSIGN <lfs_plaf>.
                            ENDIF.
                          ENDIF.
                          UNASSIGN <lfs_eban>.
                      ENDCASE.
                      "紀錄讀到的Index
                      lt_index = VALUE #( BASE lt_index ( index = <lfs_mldelay>-index
                                                           menge = <lfs_result>-menge ) ).
                      lv_count = lv_count + 1.
                    ENDIF.
                  ENDLOOP.
                  "若找不到Father展BOM
                  IF sy-subrc <> 0.
                    "讀取此INDEX對應的料號及工廠
                    READ TABLE lt_mldelay WITH KEY index = <lfs_index_do>-index
                                          ASSIGNING FIELD-SYMBOL(<lfs_mldelay_bom>).
                    IF sy-subrc = 0                                          .
                      READ TABLE lt_marc WITH KEY matnr = <lfs_mldelay_bom>-matnr
                                                  werks = <lfs_mldelay_bom>-werks
                                          ASSIGNING FIELD-SYMBOL(<lfs_marc>)
                                          BINARY SEARCH.
                      IF sy-subrc = 0.
                        "若採購類型為E或F且特殊採購類型為30
                        IF ( <lfs_marc>-beskz = 'E' ) OR ( <lfs_marc>-beskz = 'F' AND <lfs_marc>-sobsl = '30' ).
                          CLEAR lt_stpox[].
                          CALL FUNCTION 'CS_BOM_EXPL_MAT_V2'
                            EXPORTING
                              capid                 = 'PP01'
                              datuv                 = sy-datlo
                              mehrs                 = 'X'
                              emeng                 = <lfs_index_do>-menge
                              mtnrv                 = <lfs_mldelay_bom>-matnr
                              werks                 = <lfs_mldelay_bom>-werks
                            TABLES
                              stb                   = lt_stpox
                            EXCEPTIONS
                              alt_not_found         = 1
                              call_invalid          = 2
                              material_not_found    = 3
                              missing_authorization = 4
                              no_bom_found          = 5
                              no_plant_data         = 6
                              no_suitable_bom_found = 7
                              conversion_error      = 8
                              OTHERS                = 9.
                          IF sy-subrc = 0.
                            LOOP AT lt_stpox ASSIGNING FIELD-SYMBOL(<lfs_stpox>).
                              IF <lfs_stpox>-sobsl = '50' OR <lfs_stpox>-schgt = 'X'.
                                CONTINUE.
                              ENDIF.
                              APPEND INITIAL LINE TO lt_result ASSIGNING <lfs_result>.
                              <lfs_result>-zex_hier  = lv_zex_hier + <lfs_stpox>-stufe. "展開階層
                              "若MRP element為VC帶入SO+SO Item
                              IF lv_delkz = 'VC'.
                                <lfs_result>-kdauf = lv_del12.
                                <lfs_result>-kdpos = lv_delps.
                              ENDIF.
                              <lfs_result>-del12  = ls_mldelay_index_1-rcenr. "原始工單/計畫單
                              <lfs_result>-werks = <lfs_stpox>-werks. "工廠
                              <lfs_result>-matnr = <lfs_stpox>-idnrk. "物料
                              <lfs_result>-menge = <lfs_stpox>-mnglg. "展開數量
                              <lfs_result>-delkz = ls_mldelay_index_1-rcekz.  "原始MRP元素
                            ENDLOOP.
                            UNASSIGN <lfs_stpox>.
                          ENDIF.
                        ENDIF.
                      ENDIF.
                      UNASSIGN <lfs_marc>.
                    ENDIF.
                    UNASSIGN <lfs_mldelay_bom>.
                  ENDIF.
                  UNASSIGN <lfs_mldelay>.
                ENDIF.
                UNASSIGN <lfs_index_do>.
              ENDDO.
            ELSE.
              lv_flag = 'X'.
              EXIT.
            ENDIF.
          ENDWHILE.
        ELSE.
          "若上階有旗標則不需往下展BOM
          IF lv_flag_45d = space.
            READ TABLE lt_marc WITH KEY matnr = <lfs_father>-matnr
                                        werks = <lfs_father>-werks
                               ASSIGNING <lfs_marc>
                               BINARY SEARCH.
            IF sy-subrc = 0.
              "若採購類型為E或F且特殊採購類型為30且MRP element不等於WB或KB
              IF ( <lfs_marc>-beskz = 'E' ) OR
                 ( <lfs_marc>-beskz = 'F' AND <lfs_marc>-sobsl = '30' ). "AND
*                  ( <lfs_father>-rcekz <> 'WB' AND <lfs_father>-rcekz <> 'KB' ) ).
                CALL FUNCTION 'CS_BOM_EXPL_MAT_V2'
                  EXPORTING
                    capid                 = 'PP01'
                    datuv                 = sy-datlo
                    mehrs                 = 'X'
                    emeng                 = lv_menge
                    mtnrv                 = <lfs_father>-matnr
                    werks                 = <lfs_father>-werks
                  TABLES
                    stb                   = lt_stpox
                  EXCEPTIONS
                    alt_not_found         = 1
                    call_invalid          = 2
                    material_not_found    = 3
                    missing_authorization = 4
                    no_bom_found          = 5
                    no_plant_data         = 6
                    no_suitable_bom_found = 7
                    conversion_error      = 8
                    OTHERS                = 9.
                IF sy-subrc = 0.
                  LOOP AT lt_stpox ASSIGNING <lfs_stpox>.
                    IF <lfs_stpox>-sobsl = '50' OR <lfs_stpox>-schgt = 'X'.
                      CONTINUE.
                    ENDIF.
                    APPEND INITIAL LINE TO lt_result ASSIGNING <lfs_result>.
                    <lfs_result>-zex_hier  = lv_zex_hier + <lfs_stpox>-stufe. "展開階層
                    "若MRP element為VC帶入SO+SO Item
                    IF lv_delkz = 'VC'.
                      <lfs_result>-kdauf = lv_del12.
                      <lfs_result>-kdpos = lv_delps.
                    ENDIF.
                    <lfs_result>-del12  = ls_mldelay_index_1-rcenr. "原始工單/計畫單
                    <lfs_result>-werks = <lfs_stpox>-werks. "工廠
                    <lfs_result>-matnr = <lfs_stpox>-idnrk. "物料
                    <lfs_result>-menge = <lfs_stpox>-mnglg. "展開數量
                    <lfs_result>-delkz = ls_mldelay_index_1-rcekz.  "原始MRP元素
                  ENDLOOP.
                  UNASSIGN <lfs_stpox>.
                ENDIF.
              ENDIF.
            ENDIF.
            UNASSIGN <lfs_marc>.
          ENDIF.
        ENDIF.
      ENDIF.
      UNASSIGN <lfs_resb>.
    ENDLOOP.

    "新增工單/計畫單情境
    DATA(lt_result_apd) = lt_result[].
    CLEAR lt_result_apd[].
    READ TABLE lt_result INDEX 1
                         ASSIGNING <lfs_result>.
    IF sy-subrc = 0.
      CASE <lfs_result>-delkz.
        WHEN 'FE'. "工單
          SELECT aufnr, rsnum, rspos, matnr, enmng,
                 CASE WHEN enmng = bdmng THEN 'X' END AS flag
            FROM resb
           WHERE aufnr = @<lfs_result>-del12
            INTO TABLE @DATA(lt_resb_fe).
          IF sy-subrc = 0.
            SORT lt_resb_fe BY aufnr.
            DELETE lt_resb_fe WHERE flag <> 'X'.
            SORT lt_resb_fe BY aufnr.
            LOOP AT lt_resb_fe ASSIGNING FIELD-SYMBOL(<lfs_resb_fe>).
              APPEND INITIAL LINE TO lt_result_apd ASSIGNING FIELD-SYMBOL(<lfs_result_apd>).
              <lfs_result_apd>-zex_hier = '9999'.           "填寫為9999
              <lfs_result_apd>-kdauf    = <lfs_result>-kdauf.  "同訂單號
              <lfs_result_apd>-kdpos    = <lfs_result>-kdpos.  "同訂單項次
              <lfs_result_apd>-del12    = <lfs_result>-del12.  "同源頭單據號碼
              <lfs_result_apd>-werks    = <lfs_result>-werks.  "同展開工廠
              <lfs_result_apd>-rsnum    = <lfs_resb_fe>-rsnum.
              <lfs_result_apd>-rspos    = <lfs_resb_fe>-rspos.
              <lfs_result_apd>-matnr    = <lfs_resb_fe>-matnr.
              <lfs_result_apd>-menge    = <lfs_resb_fe>-enmng.
            ENDLOOP.
            UNASSIGN <lfs_resb_fe>.
          ENDIF.
        WHEN 'PA'. "計畫單
          SELECT a~aufnr, b~rsnum, b~rspos, b~matnr, b~bdmng
            FROM ztppmo0037 AS a INNER JOIN resb AS b
                                         ON a~zdplnum = b~plnum
           WHERE a~aufnr = @<lfs_result>-del12+0(10)
             AND a~zplvoid = @space "固定為空
            INTO TABLE @DATA(lt_resb_pa).
          IF sy-subrc = 0.
            SORT lt_resb_pa BY aufnr.
            LOOP AT lt_resb_pa ASSIGNING FIELD-SYMBOL(<lfs_resb_pa>).
              APPEND INITIAL LINE TO lt_result_apd ASSIGNING <lfs_result_apd>.
              <lfs_result_apd>-zex_hier = '8888'.           "填寫為8888
              <lfs_result_apd>-kdauf    = <lfs_result>-kdauf.  "同訂單號
              <lfs_result_apd>-kdpos    = <lfs_result>-kdpos.  "同訂單項次
              <lfs_result_apd>-del12    = <lfs_result>-del12.  "同源頭單據號碼
              <lfs_result_apd>-werks    = <lfs_result>-werks.  "同展開工廠
              <lfs_result_apd>-rsnum    = <lfs_resb_pa>-rsnum.
              <lfs_result_apd>-rspos    = <lfs_resb_pa>-rspos.
              <lfs_result_apd>-matnr    = <lfs_resb_pa>-matnr.
              <lfs_result_apd>-menge    = <lfs_resb_pa>-bdmng.
            ENDLOOP.
            UNASSIGN <lfs_resb_pa>.
          ENDIF.
      ENDCASE.
    ENDIF.
    "若不為空
    IF lt_result_apd[] IS NOT INITIAL.
      lt_result[] = CORRESPONDING #( BASE ( lt_result[] ) lt_result_apd[] ).
    ENDIF.
    "Result
    it_result[] = lt_result[].
    "Message Success
    e_return-type = 'S'.
    e_return-message = 'Success'.
  ENDIF.
ENDFUNCTION.