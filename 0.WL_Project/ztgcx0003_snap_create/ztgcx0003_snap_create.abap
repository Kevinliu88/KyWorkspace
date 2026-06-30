*&---------------------------------------------------------------------*
*& Report  ZTGCX0003_SNAP_CREATE
*&---------------------------------------------------------------------*
*& 用途:背景批次建立「XJ 計算快照」(與 ZTGCX0003 存檔解耦,避免拖慢前景)
*&   ZTGCX0003 存檔時只寫 SNAPH stub(STATUS='P');本程式週期跑:
*&     0) reclaim_stale  : 認領逾時(>p_stale 分)仍卡 'R' 的 → 退回 'P'(防 run 中途掛掉)
*&     1) process_pending: 撈 STATUS='P' 上限 p_num,逐筆「條件 UPDATE 認領」(P→R,看 sy-dbcnt 防重複)
*&     2) build_one      : 每筆 SUBMIT 018 r_mode2 攔明細→SNAP018;MD_SALES_ORDER_STATUS_REPORT→SNAPMD4
*&     3) 收尾 SNAPH(STATUS='D' + 時戳/耗時/落差);任何失敗→STATUS='E' + ERRTX(錯誤看得到)
*&   排程:SM36 週期(建議每 3 分、p_num=50;用批次 user,前景使用者免 S_BTCH_JOB)
*&   ※ 認領 commit 在前、慢工在後 → 兩 run 重疊也不會重複處理(集合互斥)
*& MODIFICATIONS HISTORY
*&   2026/06/19  V001  JosephLo  Creation(快照背景建立;與 ZTGCX0003 解耦)
*&   2026/06/20  V002  JosephLo  018改呼叫ztgpprp0019_v1(配合ZTGCX0003 V007);ty_pp029加werks_yc/werks_so,
*&                               攔截後還原werks=子件廠、werks_so=訂單表頭廠;SNAP018加WERKS_SO欄
*&   2026/06/23  V003  JosephLo  SNAP018加追溯欄index/rsnum/rspos(對應018_v1 ty_alv新增,heshaoliang已做);
*&                               ty_pp029加3欄+build_one存ls_d-md_index=ls_p-index(rsnum/rspos同名自動帶);
*&                               SNAP018↔SNAPMD4可用md_index 1:1精準對位
*&   2026/06/23  V004  JosephLo  018_v1還原(werks=子件廠、移除werks_yc)→build_one拆掉V007換位迴圈(werks直接用)
*&---------------------------------------------------------------------*
REPORT ztgcx0003_snap_create NO STANDARD PAGE HEADING.

" 018 輸出子集(= ZTGCX0003 的 ty_pp029;攔截用)
TYPES: BEGIN OF ty_pp029,
         kdauf    TYPE co_kdauf,
         kdpos    TYPE co_kdpos,
         matnr    TYPE vbap-matnr,
         werks    TYPE marc-werks,
         werks_yc TYPE marc-werks,
         werks_so TYPE marc-werks,
         menge    TYPE mseg-menge,
         beskz    TYPE marc-beskz,
         sobsl    TYPE marc-sobsl,
         zex_hier TYPE zpsrp0002-zex_hier,
         del12    TYPE zpsrp0002-del12,
         delnr    TYPE ioel-delnr,
         meins    TYPE mara-meins,
         labst    TYPE ztpprp0010-labst,
         insme    TYPE ztpprp0010-insme,
         bebst    TYPE ztpprp0010-bebst,
         banfb    TYPE ztpprp0010-banfb,
         menge_g  TYPE ztpprp0010-sum04,
         feaub    TYPE ztpprp0010-feaub,
         plafb    TYPE ztpprp0010-plafb,
         menge_t  TYPE ztpprp0019-quantity,
         index    TYPE zpsrp0002-index,   "V003 MD4節點序(追溯,對 SNAPMD4.md_index)
         rsnum    TYPE zpsrp0002-rsnum,   "V003 預留單號
         rspos    TYPE zpsrp0002-rspos,   "V003 預留項次
       END OF ty_pp029.

PARAMETERS: p_num   TYPE i DEFAULT 5,   "每次最多處理筆數
            p_stale TYPE i DEFAULT 15.   "認領逾時(分)→ 回收 R→P

DATA: gt_pp029 TYPE TABLE OF ty_pp029,
      gv_done  TYPE i,
      gv_err   TYPE i.

*----------------------------------------------------------------------*
START-OF-SELECTION.
*  PERFORM reclaim_stale. "Joseph 決定先不做reclaim
  PERFORM process_pending.
  WRITE: / 'XJ 快照批次完成:成功', gv_done, '筆 / 失敗', gv_err, '筆'.

*&---------------------------------------------------------------------*
*& 0) 回收逾時卡死的 'R'(run 中途掛掉,否則永遠不被處理)
*&---------------------------------------------------------------------*
FORM reclaim_stale.
  DATA: lv_now   TYPE timestamp,
        lv_claim TYPE timestamp,
        lv_age   TYPE p LENGTH 8 DECIMALS 0.
  GET TIME STAMP FIELD lv_now.
  SELECT xj, claim_ts FROM ztcx0004_snaph
    WHERE status = 'R'
    INTO TABLE @DATA(lt_r).
  LOOP AT lt_r INTO DATA(ls_r).
    CLEAR lv_claim.
    lv_claim = ls_r-claim_ts.                 "TIMESTAMPL→TIMESTAMP(去小數秒)
    IF lv_claim IS INITIAL.
      CONTINUE.
    ENDIF.
    lv_age = cl_abap_tstmp=>subtract( tstmp1 = lv_now tstmp2 = lv_claim ).
    IF lv_age > p_stale * 60.
      UPDATE ztcx0004_snaph SET status = 'P'
        WHERE xj = @ls_r-xj AND status = 'R'.
    ENDIF.
  ENDLOOP.
  COMMIT WORK.
ENDFORM.

*&---------------------------------------------------------------------*
*& 1) 撈 + 認領(P→R),只收自己搶到的(sy-dbcnt=1)
*&---------------------------------------------------------------------*
FORM process_pending.
  DATA lv_now TYPE timestamp.
  SELECT xj FROM ztcx0004_snaph
    WHERE status = 'P'
    ORDER BY save_tstamp DESCENDING, xj DESCENDING   "由最近(新)的先做
    INTO TABLE @DATA(lt_cand) UP TO @p_num ROWS.
  CHECK lt_cand IS NOT INITIAL.
  DATA lt_mine LIKE lt_cand.
  LOOP AT lt_cand INTO DATA(ls_c).
    GET TIME STAMP FIELD lv_now.
    UPDATE ztcx0004_snaph SET status = 'R', claim_ts = @lv_now
      WHERE xj = @ls_c-xj AND status = 'P'.
    IF sy-dbcnt = 1.
      APPEND ls_c TO lt_mine.            "搶到才處理;dbcnt=0=別人先搶,跳過
    ENDIF.
  ENDLOOP.
  COMMIT WORK.                            "認領先落地,再開始慢工
  LOOP AT lt_mine INTO DATA(ls_m2).
    PERFORM build_one USING ls_m2-xj.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& 2) 建單筆快照:018 r_mode2 + MD4C → SNAP018/SNAPMD4 → 收尾 SNAPH
*&---------------------------------------------------------------------*
FORM build_one USING p_xj TYPE ztcx0004_snaph-xj.
  DATA: ls_hdr    TYPE ztcx0004_snaph,
        lt_d      TYPE TABLE OF ztcx0004_snap018,
        ls_d      TYPE ztcx0004_snap018,
        lt_m      TYPE TABLE OF ztcx0004_snapmd4,
        ls_m      TYPE ztcx0004_snapmd4,
        lt_mld    TYPE md_t_mldelay,
        lv_seq    TYPE n LENGTH 6,
        lv_018beg TYPE timestamp,
        lv_018end TYPE timestamp,
        lv_md4beg TYPE timestamp,
        lv_md4end TYPE timestamp,
        lv_now    TYPE timestamp,
        lv_calc   TYPE timestamp,
        lv_sec    TYPE p LENGTH 8 DECIMALS 0,
        lv_r18ms  TYPE int4,
        lv_md4ms  TYPE int4,
        lv_gap    TYPE int4,
        lv_thr    TYPE i,
        lv_stale  TYPE flag,
        lv_meins  TYPE meins.
  "MD4C 介面型別中介變數(否則 CALL_FUNCTION_CONFLICT_TYPE)
  DATA: lv_md_delkz TYPE mdps-delkz,
        lv_md_delnr TYPE mdps-del12,
        lv_md_delps TYPE mdps-delps.

  SELECT SINGLE * FROM ztcx0004_snaph WHERE xj = @p_xj INTO @ls_hdr.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  TRY.
      "① 018 明細(r_mode2)
      CLEAR gt_pp029.
      GET TIME STAMP FIELD lv_018beg.
      cl_salv_bs_runtime_info=>set( display  = abap_false
                                    metadata = abap_false
                                    data     = abap_true ).
      "V007 改呼叫 ZPRP018_V1(ztgpprp0019_v1)取代 ztgpprp0019
      SUBMIT ztgpprp0019_v1 WITH r_bt1   = 'X'
                         WITH p_vbeln = ls_hdr-vbeln
                         WITH p_posnr = ls_hdr-posnr
                         WITH p_menge = ls_hdr-menge
                         WITH r_mode1 = space
                         WITH r_mode2 = 'X'
        AND RETURN.
      TRY.
          cl_salv_bs_runtime_info=>get_data_ref( IMPORTING r_data = DATA(lo_ref) ).
          ASSIGN lo_ref->* TO FIELD-SYMBOL(<lt>).
          IF <lt> IS ASSIGNED.
            gt_pp029 = CORRESPONDING #( <lt> ).
            "V004 018_v1 已還原(werks=子件廠、移除 werks_yc)→ 拆掉 V007 換位;werks 直接用
          ENDIF.
        CATCH cx_salv_bs_sc_runtime_info.
      ENDTRY.
      cl_salv_bs_runtime_info=>clear_all( ).
      GET TIME STAMP FIELD lv_018end.
      lv_sec   = cl_abap_tstmp=>subtract( tstmp1 = lv_018end tstmp2 = lv_018beg ).
      lv_r18ms = lv_sec * 1000.

      "明細列(MOVE-CORRESPONDING:同名欄含 delnr/menge_g/meins 自動對應)
      CLEAR lv_seq.
      LOOP AT gt_pp029 INTO DATA(ls_p).
        lv_seq = lv_seq + 1.
        CLEAR ls_d.
        MOVE-CORRESPONDING ls_p TO ls_d.
        ls_d-md_index = ls_p-index.   "V003 index→md_index(對 SNAPMD4);rsnum/rspos 同名已自動帶
        ls_d-xj    = p_xj.
        ls_d-seqno = lv_seq.
        APPEND ls_d TO lt_d.
      ENDLOOP.
      READ TABLE gt_pp029 INTO DATA(ls_p1) INDEX 1.
      IF sy-subrc = 0.
        lv_meins = ls_p1-meins.
      ENDIF.

      "② MD4C 供需樹
      lv_md_delkz = 'VC'.
      lv_md_delnr = ls_hdr-vbeln.
      lv_md_delps = ls_hdr-posnr.
      GET TIME STAMP FIELD lv_md4beg.
      CALL FUNCTION 'MD_SALES_ORDER_STATUS_REPORT'
        EXPORTING
          edelkz     = lv_md_delkz
          edelnr     = lv_md_delnr
          edelps     = lv_md_delps
          memory_id  = 'PLHS'
          nodisp     = 'X'
          i_profid   = 'SAP000000001'
        IMPORTING
          et_mldelay = lt_mld
        EXCEPTIONS
          error      = 1
          OTHERS     = 2.
      GET TIME STAMP FIELD lv_md4end.
      lv_sec   = cl_abap_tstmp=>subtract( tstmp1 = lv_md4end tstmp2 = lv_md4beg ).
      lv_md4ms = lv_sec * 1000.
      IF sy-subrc = 0.
        CLEAR lv_seq.
        LOOP AT lt_mld INTO DATA(ls_mld).
          lv_seq = lv_seq + 1.
          CLEAR ls_m.
          MOVE-CORRESPONDING ls_mld TO ls_m.   "father/nxtrs/matnr/werks/delkz/delnr/delps/rcekz/rcenr/rceps/bddat 同名
          ls_m-md_index = ls_mld-index.        "INDEX→MD_INDEX 名稱不同,手搬
          ls_m-xj       = p_xj.
          ls_m-seqno    = lv_seq.
          APPEND ls_m TO lt_m.
        ENDLOOP.
      ENDIF.

      "③ 寫入(清舊+寫新+收尾,SUBMIT 之後一個工作單元)
      DELETE FROM ztcx0004_snap018 WHERE xj = @p_xj.
      DELETE FROM ztcx0004_snapmd4 WHERE xj = @p_xj.
      IF lt_d IS NOT INITIAL.
        INSERT ztcx0004_snap018 FROM TABLE lt_d ACCEPTING DUPLICATE KEYS.
      ENDIF.
      IF lt_m IS NOT INITIAL.
        INSERT ztcx0004_snapmd4 FROM TABLE lt_m ACCEPTING DUPLICATE KEYS.
      ENDIF.

      "落差 = 建立計算(T0=calc_tstamp) → 快照建立(now)
      GET TIME STAMP FIELD lv_now.
      CLEAR lv_calc.
      lv_calc = ls_hdr-calc_tstamp.
      IF lv_calc IS NOT INITIAL.
        lv_gap = cl_abap_tstmp=>subtract( tstmp1 = lv_now tstmp2 = lv_calc ).
      ENDIF.
      lv_thr = ls_hdr-threshold_min.
      IF lv_thr = 0.
        lv_thr = 15.
      ENDIF.
      CLEAR lv_stale.
      IF lv_gap > lv_thr * 60.
        lv_stale = 'X'.
      ENDIF.

      UPDATE ztcx0004_snaph
        SET status      = 'D',
            meins       = @lv_meins,
            run018_ts   = @lv_018end,
            run018_ms   = @lv_r18ms,
            runmd4_ts   = @lv_md4end,
            runmd4_ms   = @lv_md4ms,
            gap_seconds = @lv_gap,
            stale_flg   = @lv_stale,
            errtx       = @space
        WHERE xj = @p_xj.
      COMMIT WORK.
      gv_done = gv_done + 1.

    CATCH cx_root INTO DATA(lx).
      ROLLBACK WORK.
      DATA lv_etx TYPE ztcx0004_snaph-errtx.
      lv_etx = lx->get_text( ).
      UPDATE ztcx0004_snaph SET status = 'E', errtx = @lv_etx
        WHERE xj = @p_xj.
      COMMIT WORK.
      gv_err = gv_err + 1.
  ENDTRY.
ENDFORM.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
