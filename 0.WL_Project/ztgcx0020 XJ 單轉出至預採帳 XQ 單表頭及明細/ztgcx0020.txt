*&---------------------------------------------------------------------*
*& Report  ZTGCX0020  XJ 單轉出至預採帳 XQ 單表頭及明細
*& 目的  : 將 ZTCX0004 資料轉入 ZTSD0098 / ZTSD0099（覆蓋模式）
*&---------------------------------------------------------------------*
REPORT ztgcx0020.

TABLES: ztcx0004.

CONSTANTS: c_str_98 TYPE dd02l-tabname VALUE 'ZTSD0098',
           c_str_99 TYPE dd02l-tabname VALUE 'ZTSD0099'.

TYPE-POOLS: slis.

SELECTION-SCREEN BEGIN OF BLOCK blk1 WITH FRAME TITLE TEXT-t01.
  SELECT-OPTIONS:
    s_vtweg  FOR ztcx0004-vtweg OBLIGATORY,
    s_xj     FOR ztcx0004-xj OBLIGATORY,
    s_idnrk  FOR ztcx0004-idnrk,
"    s_erdat  FOR ztcx0004-xj_erdat OBLIGATORY,
    s_erdat  FOR ztcx0004-sa_chg_date OBLIGATORY,
    s_ernam  FOR ztcx0004-xj_ernam,
    s_xjsts  FOR ztcx0004-xj_status.

*  PARAMETERS: p_zym     TYPE ztunym  OBLIGATORY.
*  PARAMETERS: p_period  TYPE zperiod OBLIGATORY DEFAULT 1.

  PARAMETERS: p_prev AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK blk1.

DATA: lt_src      TYPE STANDARD TABLE OF ztcx0004,
      ls_src      TYPE ztcx0004,
      lt_98       TYPE STANDARD TABLE OF ztsd0098,
      lt_99       TYPE STANDARD TABLE OF ztsd0099,
      ls_98       TYPE ztsd0098,
      ls_99       TYPE ztsd0099,
      gt_err_log  TYPE STANDARD TABLE OF string,
      gt_exec_log TYPE STANDARD TABLE OF string.

DATA: lv_old_xj   TYPE ztcx0004-xj,
      lv_new_xqno TYPE ztsd0098-zxqno.

DATA lv_perid TYPE zivdch_ym.   "CHAR6 (YYYYMM)

DATA:lv_wl2_englishspecifications TYPE ztmara-wl2_englishspecifications,
     lv_string                    TYPE string.

*TYPES:BEGIN OF ty_xj,
*        xj TYPE ztcx0004-xj,
*      END OF ty_xj.
*DATA:lt_xj TYPE TABLE OF ty_xj.

INITIALIZATION.
*  p_zym = sy-datum(6).  " 自動填入今天的年月 (YYYYMM)


START-OF-SELECTION.

  SELECT * INTO TABLE @lt_src FROM ztcx0004
    WHERE vtweg     IN @s_vtweg
      AND xj        IN @s_xj
      AND idnrk     IN @s_idnrk
"      AND xj_erdat  IN @s_erdat
      AND sa_chg_date  IN @s_erdat "改抓SA_CHG_DATE 20251023
      AND xj_ernam  IN @s_ernam
      AND xj        <> ''
      AND xj_status <> 'F'  "除了 F，其他狀態都可以
*      AND xj_status = 'E' "只抓狀態=E 20251005
      AND xj_status IN @s_xjsts
      AND sales_netpr > 0
      AND ( zind01 = '' OR zind01 = 'C' )
      AND zxqno = ''   "只抓取未產生XQ單的數據
      AND stock_qty > 0
    ORDER BY xj, xj_item ASCENDING
    .

  IF lt_src IS INITIAL.
    MESSAGE TEXT-001 TYPE 'I'.
    RETURN.
  ENDIF.

  SORT lt_src BY xj xj_item.

*  CLEAR:lt_xj.
  LOOP AT lt_src INTO ls_src.
*    "已經生成XQ單的不允許再生成
*    READ TABLE lt_xj INTO DATA(ls_xj) WITH KEY xj = ls_src-xj.
*    IF sy-subrc = 0.
*      CLEAR:ls_xj.
*    ELSE.
*      SELECT SINGLE * INTO @DATA(ls_ztsd0098_xqlog)
*        FROM ztsd0098_xqlog
*        WHERE ftype = 'XJ' AND z_ori_num = @ls_src-xj.
*      IF ls_ztsd0098_xqlog IS NOT INITIAL.
*        CLEAR:ls_ztsd0098_xqlog,ls_src.
*        CONTINUE.
*      ELSE.
*        CLEAR:ls_xj.
*        ls_xj-xj = ls_src-xj.
*        APPEND ls_xj TO lt_xj.
*      ENDIF.
*    ENDIF.

    IF p_prev <> 'X'. " 僅在非預覽模式執行換號邏輯
      IF ls_src-xj <> lv_old_xj.
        lv_old_xj = ls_src-xj.

        SELECT SINGLE z_new_num INTO lv_new_xqno
          FROM ztsd0098_xqlog
          WHERE ftype = 'XJ'
            AND z_ori_num = ls_src-xj.

        lv_perid = sy-datum(6).         "等同 sy-datum+0(6)
        IF sy-subrc <> 0.  " 如果查不到，取新號
          CALL FUNCTION 'ZSD_ODM_XQ_NO_GET'
            EXPORTING
              iv_perid = lv_perid        "改成今天的 YYYYMM
              "iv_perid = ls_src-xj
              iv_werks = ls_src-werks
            IMPORTING
              ev_zxqno = lv_new_xqno
            EXCEPTIONS
              OTHERS   = 1.

          IF sy-subrc <> 0 OR lv_new_xqno IS INITIAL.
            APPEND |XQ單號產生失敗，XJ={ ls_src-xj } 工廠={ ls_src-werks }| TO gt_err_log.
*            APPEND TEXT-002 TO gt_err_log.
            CONTINUE.
          ELSE.
            DATA: ls_log LIKE ztsd0098_xqlog.

            ls_log-ftype     = 'XJ'.          " 這支程式固定 QQ
            ls_log-z_ori_num = ls_src-xj.
            ls_log-z_new_num = lv_new_xqno.
            ls_log-ernam     = sy-uname.
            ls_log-erdat     = sy-datum.
            ls_log-erzet     = sy-uzeit.
            ls_log-tcode     = sy-tcode.

            MODIFY ztsd0098_xqlog FROM ls_log.
*            IF sy-subrc <> 0 AND sy-subrc <> 4. "4=duplicate key (已有人插入)
*              "APPEND |⚠️ 寫入 XQLOG 失敗 XJ={ ls_src-xj }| TO gt_err_log.
*              APPEND TEXT-003 TO gt_err_log.
*            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ELSE.
      lv_new_xqno = ls_src-xj.
    ENDIF.

    CLEAR ls_98.

    SELECT SINGLE zp_entity INTO @DATA(tmp_zp_enty)
      FROM ztsd0015
     WHERE bukrs = @ls_src-werks.

    IF sy-subrc = 0.
      ls_98-zp_entity = tmp_zp_enty.
    ENDIF.

    ls_98-mandt     = sy-mandt.
    ls_98-werks     = ls_src-werks.
    ls_98-zxqno     = lv_new_xqno.
    ls_98-zverno    = '1'.
    ls_98-zbcust    = ls_src-kunnr.
    ls_98-zxqsta    = ''.
    ls_98-zcpnocn   = ls_src-skuitem.
*    ls_98-zxqdat    = sy-datum.
*
*    " XJ 單 / QQ 單轉 XQ 單時，XQ 單的建立日期要抓 SO 的確認日
**    SELECT SINGLE audat FROM ztsd0028 INTO @DATA(tmp_lv_audat)
**      WHERE vbeln = @ls_src-vbeln AND zvsnmr_v = '000'.
*
*    " changed by Lauren 20251002  改抓ztcx0004-sa_chg_date
*    SELECT SINGLE sa_chg_date FROM ztcx0004 INTO @DATA(tmp_lv_audat)
*      WHERE vbeln = @ls_src-vbeln
*      AND   xj    = @ls_src-xj.
*
*    IF sy-subrc = 0 AND tmp_lv_audat IS NOT INITIAL.
*      ls_98-zxqdat = tmp_lv_audat.
*    ENDIF.
    ls_98-zxqdat = ls_src-sa_chg_date.

*    ls_98-zpno      = ls_src-idnrk.
    ls_98-zpno      = ls_src-matnr.
*    ls_98-zscust    = ls_src-kunnr.
    ls_98-zpnouq    = ls_src-meins.
    ls_98-zxqqty    = ls_src-stock_qty.
    ls_98-zsono     = ls_src-vbeln.
    ls_98-zsoseq    = ls_src-posnr.
    ls_98-vtweg     = ls_src-vtweg.
    ls_98-zxjno     = ls_src-xj. "IQ單號（詢單單號）

    " 這 2 個欄位由取得的 ZSONO，對應 ZTSD0028-VBELN 最新版本的資料
    "ls_98-bstnk     = ztsd0028-bstnk.    ""
    "ls_98-zsappo    = ztsd0098-zsappo.   ""

    IF ls_src-vbeln IS NOT INITIAL.
      SELECT SINGLE bstnk, zsappo
        INTO (@ls_98-zcord, @ls_98-zsappo)
        FROM ztsd0028
        WHERE vbeln    = @ls_src-vbeln
          AND zvsnmr_v = ( SELECT MAX( zvsnmr_v )
                             FROM ztsd0028
                             WHERE vbeln = @ls_src-vbeln ).
      IF ls_98-zsappo IS INITIAL.
        SELECT SINGLE zssppo
          INTO @ls_98-zsappo
          FROM ztsd0029
          WHERE vbeln = @ls_src-vbeln
          AND posnr = @ls_src-posnr
          AND zvsnmr_v = ( SELECT MAX( zvsnmr_v )
                             FROM ztsd0029
                             WHERE vbeln = @ls_src-vbeln
                             AND posnr = @ls_src-posnr ).
      ENDIF.
    ENDIF.

    ls_98-zopr_new  = sy-uname.
    ls_98-zopd_new  = sy-datum.
    ls_98-zopt_new  = sy-uzeit.
    ls_98-zaction   = 'I'.

*    ls_98-zym       = p_zym.          " 預採帳年月
    ls_98-zym       = ls_98-zxqdat(6).          " 預採帳年月
*    ls_98-zperiod   = p_period.       " 期別 (預設1)
*    IF ls_98-zperiod IS INITIAL.
    ls_98-zperiod = '1'.     " 期別
*    ENDIF.

    ls_98-zxqtyp    = '1'.             " 大分類, 預設帶入 1，代表 RAW-MATERIAL
    ls_98-zunptyp   = '1'.             " UNPAY 排序, 代表 (1)MOQ & (2)ORDER CANCEL
    ls_98-zdesc     = 'ORDER CANCEL'. "敘述，固定寫入ORDER CANCEL 20251021

    "===== 帶入 ZTSD0098-ZCPNO（兩段式查找） =====
    " (1) 以 (VTWEG, KUNNR, MATNR) 比對 ZTSD0020（DEL <> 'X'）
    "     多筆 → 先取 ZDEFAULT = 'X'，否則取第一筆
    " (2) 若(1)無資料 → 以 (VTWEG, MATNR) 再查一次，同樣規則

    " 若來源一定用 MATNR，就直接用 ls_src-matnr；若偶爾只有 IDNRK，可視情況 fallback
    DATA(lv_matnr_for_match) = COND matnr(
      WHEN ls_src-matnr IS NOT INITIAL THEN ls_src-matnr
      ELSE ls_src-idnrk ).

    CLEAR ls_98-zcpno.

    " --- (1) VTWEG + KUNNR + MATNR ---
    SELECT zcpno, zdefault
      FROM ztsd0020
      WHERE vtweg = @ls_src-vtweg
        AND kunnr = @ls_src-kunnr
        AND matnr = @lv_matnr_for_match
        AND del   <> 'X'
      INTO TABLE @DATA(lt_0020_1).

    IF lt_0020_1 IS NOT INITIAL.
      SORT lt_0020_1 BY zdefault DESCENDING.
      READ TABLE lt_0020_1 INDEX 1 INTO DATA(ls_0020_best1).
      IF sy-subrc = 0.
        ls_98-zcpno = ls_0020_best1-zcpno.
      ENDIF.
    ENDIF.

    " --- (2) VTWEG + MATNR （只有在(1)沒找到時做）---
    IF ls_98-zcpno IS INITIAL.
      SELECT zcpno, zdefault
        FROM ztsd0020
        WHERE vtweg = @ls_src-vtweg
          AND matnr = @lv_matnr_for_match
          AND del   <> 'X'
        INTO TABLE @DATA(lt_0020_2).

      IF lt_0020_2 IS NOT INITIAL.
        SORT lt_0020_2 BY zdefault DESCENDING.
        READ TABLE lt_0020_2 INDEX 1 INTO DATA(ls_0020_best2).
        IF sy-subrc = 0.
          ls_98-zcpno = ls_0020_best2-zcpno.
        ENDIF.
      ENDIF.
    ENDIF.

    "===== 帶入 ZTSD0098-ZXQLINE =====
    " 規則：以 (KUNNR, VTWEG) 查 KNVV，取第一個「不為空」的 ZZMOQLINE（多筆時）
    CLEAR ls_98-zxqline.

    "調整線別邏輯 ZTCX0001-VBELN → ZTSD0028 取 KUNNR_WE, VTWEG by Lauren 20251004
    IF ls_src-vbeln IS NOT INITIAL.

      DATA: lv_kunnr TYPE ztsd0028-kunnr_we,
            lv_vtweg TYPE ztsd0028-vtweg.
      CLEAR:lv_kunnr,lv_vtweg.
      SELECT SINGLE kunnr_we, vtweg
        INTO (@lv_kunnr, @lv_vtweg)
        FROM ztsd0028
        WHERE vbeln = @ls_src-vbeln AND zvsnmr_v = '000'.
      ls_98-zscust = lv_kunnr. "收貨方
      IF sy-subrc = 0 AND lv_kunnr IS NOT INITIAL AND lv_vtweg IS NOT INITIAL.

        SELECT zzmoqline
          FROM knvv
          WHERE kunnr = @lv_kunnr
            AND vtweg = @lv_vtweg
          INTO TABLE @DATA(lt_knvv_line).

        IF lt_knvv_line IS NOT INITIAL.
          LOOP AT lt_knvv_line ASSIGNING FIELD-SYMBOL(<fs_kv>)
               WHERE zzmoqline IS NOT INITIAL.
            ls_98-zxqline = <fs_kv>-zzmoqline.
            EXIT. " 只要第一個非空值
          ENDLOOP.
          " 若全為空則維持初始值（不強填）
        ENDIF.
      ENDIF.
    ENDIF.


    APPEND ls_98 TO lt_98.

    CLEAR ls_99.

    ls_99-zp_entity  = tmp_zp_enty.

    ls_99-mandt      = sy-mandt.
    ls_99-werks      = ls_src-werks.
    ls_99-zxqno      = lv_new_xqno.
    ls_99-zxqseq     = ls_src-xj_item.
    ls_99-zverno     = '1'.
    ls_99-zxqwrktyp  = '1'.
    ls_99-zbcust     = ls_src-kunnr.
*    ls_99-zdat       = sy-datum.
*
*    " XJ 單 / QQ 單轉 XQ 單時，XQ 單的建立日期要抓 SO 的確認日
**    SELECT SINGLE audat FROM ztsd0028 INTO @tmp_lv_audat
**      WHERE vbeln = @ls_src-vbeln AND zvsnmr_v = '000'.
*
*    " changed by Lauren 20251002  改抓ztcx0004-sa_chg_date
*    SELECT SINGLE sa_chg_date FROM ztcx0004 INTO @tmp_lv_audat
*      WHERE vbeln = @ls_src-vbeln
*      AND   xj    = @ls_src-xj.
*
*    IF sy-subrc = 0 AND tmp_lv_audat IS NOT INITIAL.
*      ls_99-zdat = tmp_lv_audat.
*    ENDIF.
    ls_99-zdat = ls_src-sa_chg_date.

    ls_99-zpno       = ls_src-idnrk.
*    ls_99-zdesc      = ls_src-wl2_erpspecification.

    " 這個欄位由取得的 ZPNO，對應 ZTMARA-WL2_ENGLISHSPECIFICATIONS
*    IF ls_99-zpno IS NOT INITIAL.
*      SELECT SINGLE wl2_englishspecifications
*        INTO @ls_99-zdesc
*        FROM ztmara
*       WHERE matnr = @ls_99-zpno.
*    ENDIF.
    IF ls_99-zpno IS NOT INITIAL.
      CLEAR:lv_wl2_englishspecifications,lv_string.
      SELECT SINGLE wl2_englishspecifications
        INTO @lv_wl2_englishspecifications
        FROM ztmara
       WHERE matnr = @ls_99-zpno.
      lv_string = lv_wl2_englishspecifications.
      REPLACE ALL OCCURRENCES OF REGEX '[一-龥]' IN lv_string WITH ''.
      ls_99-zdesc = lv_string.
    ENDIF.

*    ls_99-zqty       = ls_src-ztrans_qty.
    ls_99-zqty       = ls_src-stock_qty.
    ls_99-zuq        = ls_src-meins.
    ls_99-zunit      = ls_src-canc_qty.
    ls_99-zpcur      = ls_src-waers.
    ls_99-zpup       = ls_src-netpr * 100.
    ls_99-zusdcur    = ls_src-sales_waers.
    "    ls_99-zup        = ls_src-sales_netpr * 100.
    ls_99-zup        = ls_src-sales_netpr * 10000.
    ls_99-zopr_new   = sy-uname.
    ls_99-zopd_new   = sy-datum.
    ls_99-zopt_new   = sy-uzeit.
    ls_99-zaction    = 'I'.
    ls_99-vtweg      = ls_src-vtweg.
    ls_99-zxqdtyp    = '1'.             " 表 ORDER Cancel

*    IF ls_98-zunptyp = '1' OR ls_98-zunptyp = '2' OR ls_98-zunptyp = '3'. " 系統轉出否 ZTSD0098-ZUNPTYP IN ('1','2','3') -> X
*      ls_99-ztunyn     = 'X'.
*    ENDIF.
    " 系統轉出否
    IF ls_src-zind01 = 'C'.
      ls_99-ztunyn     = 'C'.
    ELSE.
      ls_99-ztunyn     = 'X'.
    ENDIF.

    ls_99-zptwdcur   = ls_src-waers_twd.
    ls_99-zptwdup    = ls_src-netpr_twd * 100.
    ls_99-zpcnycur   = ls_src-waers_cny.
    ls_99-zpcnyup    = ls_src-netpr_cny * 100.

    IF ls_src-canc_qty > 0.
      ls_99-zbqty      = ls_src-bdmng / ls_src-canc_qty.
    ELSE.
      ls_99-zbqty      = ls_src-bdmng / 1.
    ENDIF.

    ls_99-zpup_per   = '100'. " '1'.
    ls_99-zptwd_per  = '100'. " '1'.
    ls_99-zpcny_per  = '100'. " '1'.
    "    ls_99-zup_per    = '100'. " '1'.
    ls_99-zup_per    = '10000'. " '1'.

    ls_99-zqtybalace = ls_src-stock_qty.

    APPEND ls_99 TO lt_99.

    IF p_prev <> 'X'.          "正式模式
      UPDATE ztcx0004 SET zxqno = ls_99-zxqno zxqseq = ls_99-zxqseq
         WHERE xj = ls_src-xj AND xj_item = ls_src-xj_item.
      IF sy-subrc = 0.
        COMMIT WORK AND WAIT.
      ENDIF.
    ENDIF.

    CLEAR:ls_src.
  ENDLOOP.

  SORT lt_98 BY werks zxqno.
  DELETE ADJACENT DUPLICATES FROM lt_98 COMPARING werks zxqno.
  SORT lt_99 BY werks zxqno zxqseq.
  DELETE ADJACENT DUPLICATES FROM lt_99 COMPARING werks zxqno zxqseq.
  IF p_prev = 'X'.
    PERFORM show_alv_zt98.
    PERFORM show_alv_zt99.
    "MESSAGE |預覽模式：未寫入資料庫，共 { lines( lt_98 ) + lines( lt_99 ) } 筆資料。| TYPE 'S'.
    MESSAGE TEXT-004 TYPE 'S'.
  ELSE.
    PERFORM write_db.
    PERFORM show_log.
  ENDIF.

FORM show_alv_zt98.
  DATA: lt_fieldcat TYPE slis_t_fieldcat_alv,
        ls_layout   TYPE slis_layout_alv.
  CALL FUNCTION 'REUSE_ALV_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'ZTSD0098'
    CHANGING
      ct_fieldcat      = lt_fieldcat.
  ls_layout-colwidth_optimize = 'X'.
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program = sy-repid
      is_layout          = ls_layout
      it_fieldcat        = lt_fieldcat
    TABLES
      t_outtab           = lt_98.
ENDFORM.

FORM show_alv_zt99.
  DATA: lt_fieldcat TYPE slis_t_fieldcat_alv,
        ls_layout   TYPE slis_layout_alv.
  CALL FUNCTION 'REUSE_ALV_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'ZTSD0099'
    CHANGING
      ct_fieldcat      = lt_fieldcat.
  ls_layout-colwidth_optimize = 'X'.
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program = sy-repid
      is_layout          = ls_layout
      it_fieldcat        = lt_fieldcat
    TABLES
      t_outtab           = lt_99.
ENDFORM.

FORM write_db.
  TRY.
      IF lt_98 IS NOT INITIAL.
        MODIFY ztsd0098 FROM TABLE lt_98.
        APPEND |ZTSD0098 更新成功，筆數：{ lines( lt_98 ) }| TO gt_exec_log.
*        APPEND TEXT-005 TO gt_exec_log.
      ENDIF.
      IF lt_99 IS NOT INITIAL.
        MODIFY ztsd0099 FROM TABLE lt_99.
        APPEND |ZTSD0099 更新成功，筆數：{ lines( lt_99 ) }| TO gt_exec_log.
*        APPEND TEXT-006 TO gt_exec_log.
      ENDIF.
      COMMIT WORK.
    CATCH cx_sy_open_sql_db INTO DATA(lx_db).
      ROLLBACK WORK.
      APPEND |❌ DB Error：{ lx_db->get_text( ) }| TO gt_err_log.
  ENDTRY.
ENDFORM.

FORM show_log.
  SKIP.
  ULINE.
  IF gt_err_log IS NOT INITIAL.
    WRITE: / '=== Error Log ==='.
    LOOP AT gt_err_log INTO DATA(l_err).
      WRITE: / l_err COLOR COL_NEGATIVE.
    ENDLOOP.
  ELSE.
    WRITE: / '=== Execution Log ==='.
    LOOP AT gt_exec_log INTO DATA(l_msg).
      WRITE: / l_msg COLOR COL_POSITIVE.
    ENDLOOP.
  ENDIF.
ENDFORM.

* TEXT-t01 篩選條件

*Text elements
*----------------------------------------------------------
* 001 查無符合條件的資料
* 002 單號產生失敗，XJ=，工廠=
* 003 寫入 XQLOG 失敗 XJ=
* 004 預覽模式：未寫入資料庫
* 005 ZTSD0098 更新成功
* 006 ZTSD0099 更新成功


*Selection texts
*----------------------------------------------------------
* P_PERIOD         期別
* P_PREV         資料預覽
* P_ZYM         預採帳年月
* S_ERDAT         業務維護日期
* S_ERNAM         建立人員
* S_IDNRK         件號
* S_VTWEG         預採帳客戶別
* S_XJ         XJ 單號
* S_XJSTS         XJ 單狀態

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
