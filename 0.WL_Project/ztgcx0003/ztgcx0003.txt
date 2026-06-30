*&-----------------------------------------------------------------------------*
*& Report  預採帳-訂單異動與取消報庫存                                         *
*------------------------------------------------------------------------------*
* Author      : Ron Chang                                                      *
* Purpose     : 預採帳-訂單異動與取消報庫存
********************************************************************************
* MODIFICATIONS HISTORY :                                                      *
********************************************************************************
* CHANGE DATE VERSION MODIFIER DESCRIPTION
* =========== ======= ======== =================================================
* 2024/10/20  V001    Ron Chang Creation
* 2026/06/11  V002    JosephLo  修 collect_upd_data 採購(C)幣別無空白保護:p_upd重匯入幣別欄空白時保留DB既有幣別(不再洗掉採購已維護幣別)
* 2026/06/14  V003    JosephLo  p_imp(上傳建立)ALV加RECALC「重新計算」鈕:重跑018重建gt_data(畫面重算不存檔),保留手填stock_qty/pp_remark
* 2026/06/16  V004    JosephLo  修上傳更新(p_upd):新增項次的採購屬性(beskz/sobsl)一律取物料主檔、忽略Excel;既有項次完全不更動採購屬性
* 2026/06/17  V005    JosephLo  新增可轉/適用型號重算 FORM calc_rep(同通路by vtweg,讀ZTCX0003_PROD+ZTSD0020):
*                              P_IMP在END-OF-SELECTION自動算全表;P_MOD新增CALC_REP按鈕只算勾選且rep空/N列(保護Y);
*                              純記憶體不寫DB,隨save_data一起寫。GUI status STATUS_ALV需於SE41新增CALC_REP功能碼+ICON
* 2026/06/18  V006    JosephLo  新增「XJ計算快照」(供後續深度分析/回溯):p_imp建立XJ→存檔只寫
*                              SNAPH stub(STATUS='P')秒回;018明細(r_mode2)+MD4C(MD_SALES_ORDER_STATUS_REPORT)改由背景程式
*                              ZTGCX0003_SNAP_CREATE(SM36週期、認領P→R)建 ZTCX0004_SNAPH/_SNAP018/_SNAPMD4;
*                              隱藏開關p_snap(預設'X')控制是否建立;計算↔存檔超過gc_stale_min(15)分提醒但不卡。
*                              TOP加p_snap/gc_stale_min/gv_calc_tstamp;SUB加FORM snap_stale_check/create_calc_snapshot(只寫stub);
*                              SNAPH含STATUS/ERRTX/CLAIM_TS佇列(P待辦/R處理中/D完成/E失敗)
*                              [併入]移除 prepare_data「最高版本料號去重」(lv_base/lv_best+IF NE lv_best CONTINUE):
*                              018加總模式(r_mode1='X')每(matnr,werks)僅一列無真重複,該去重只會誤砍同基礎碼版本變體
*                              (如...618 vs ...618A)、把有實體庫存要取消的舊版料靜默丟掉→整段移除,018回傳料全建入gt_data
*                              (詳 ZTGCX0003_018展開料未進XJ清單_根因分析.md §6)
* 2026/06/20  V007    JosephLo  展BOM改呼叫ZPRP018_V1(ztgpprp0019_v1)取代ztgpprp0019:V1工廠欄換位
*                              (V1 werks=訂單表頭廠、werks_yc=子件需求廠=原版werks),攔截後LOOP還原
*                              werks=werks_yc(子件廠語意不變、下游不動)、werks_so另存訂單表頭廠;
*                              submit_pp029與快照SNAP_CREATE/build_one兩處SUBMIT都切V1;ty_pp029加
*                              werks_yc/werks_so;prepare_data填werks_so;3表ZTCX0004/ZSCX0003_ALV/
*                              ZTCX0004_SNAP018加WERKS_SO欄。⚠V1鏈僅DEV/QA,0003進PROD前須先傳V1整鏈
* 2026/06/23  V008    JosephLo  018_v1由heshaoliang還原為原始版(werks=子件需求廠、移除werks_yc/友廠邏輯,已傳PROD)
*                              →拆掉V007的werks欄位換位:submit_pp029/build_one移除還原迴圈(werks直接用018子件廠);
*                              werks_so改由VBAP(訂單/項次)補;index/rsnum/rspos追溯欄不受影響(018保留)
* 2026/06/24  V008    JosephLo  [併入]放開「報庫存量≤018需求量」限制:018需求常與生管認知不符,改不擋→條列ALV彈窗軟提醒
*                              (show_exceed_popup)列出超量XJ/項次/超出量/超出%;觸發點=生管確認數量(CONFIRM按鈕)
*                              與p_upd上傳更新(END-OF-SELECTION主ALV顯示前)兩處,有超量才跳、不中斷;
*                              confirm_qty WHEN'A'拿掉寫msg(改PERFORM collect_exceed收集),超量列仍正常推進狀態B+存檔;
*                              TOP加ty_exceed/gt_exceed;SUB加collect_exceed/show_exceed_popup。無DDIC/無標色(純彈窗即時算)
REPORT ztgcx0003 NO STANDARD PAGE HEADING MESSAGE-ID zcx01.
INCLUDE ztgcx0003_top.
INCLUDE ztgcx0003_sub.

INITIALIZATION.
  CLEAR:gt_role,gt_upload,gt_data.
  title01 = TEXT-t01.

  sscrfields-functxt_01 = icon_export && TEXT-t02.
  sscrfields-ucomm      = 'FC01'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM file_open_dialog.

AT SELECTION-SCREEN.
  IF sy-ucomm = 'FC01'.
*  下載模版
    PERFORM frm_download_template.
  ENDIF.

AT SELECTION-SCREEN ON p_file.
  IF p_imp IS NOT INITIAL AND p_file IS INITIAL AND sy-ucomm NE 'FC01'.
    MESSAGE e001(00) WITH '請選擇上傳檔案路徑'(t03).
  ENDIF.

START-OF-SELECTION.
  "PERFORM check_auth.
  "取得人員ROLE
  SELECT * FROM ztcx0003 WHERE uname = @sy-uname INTO TABLE @gt_role.
  SELECT * FROM ztcx0008 INTO TABLE @gt_custmap.
  IF gt_role IS INITIAL AND ( p_imp IS NOT INITIAL OR p_mod IS NOT INITIAL ).
    MESSAGE e005.
  ELSE.
    IF line_exists( gt_role[ role = 'B' ] ) AND ( p_imp IS NOT INITIAL OR p_upd IS NOT INITIAL ).
      MESSAGE e006. "非生管/採購人員不能上傳，請確認
    ENDIF.
  ENDIF.
  IF p_imp IS NOT INITIAL.
    "上傳檔案
    PERFORM excel_upload.
    IF gt_upload IS NOT INITIAL.
      "檢查EXCEL內容
      PERFORM check_upload_data.
      cl_salv_bs_runtime_info=>set( display  = abap_true
                                metadata = abap_false
                                data     = abap_true ).
      LOOP AT gt_upload INTO DATA(ls_u) WHERE zmsg IS NOT INITIAL.ENDLOOP.
      IF sy-subrc = 0.
        "Show error ALV and download to local
        PERFORM show_error_alv.
      ELSE.
        "將上傳檔案內容整理到ALV上
        PERFORM prepare_data.

      ENDIF.
    ELSE.
      MESSAGE s001(00) WITH 'No data upload'.
      RETURN.
    ENDIF.
  ELSEIF p_mod IS NOT INITIAL OR p_dis IS NOT INITIAL.
    PERFORM get_data.
  ELSEIF p_upd IS NOT INITIAL.
    "上傳檔案
    PERFORM excel_upload.
    PERFORM collect_upd_data.
    PERFORM confirm_qty.
    "V008 超量提醒移至 END-OF-SELECTION 主ALV顯示前彈窗(此處只收集 gt_exceed,不在START階段跳)
  ENDIF.

END-OF-SELECTION.


 "=== 統一補值 (不管走哪個分支，最後都補一次) ===
  LOOP AT gt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
    DATA(ls_key1) = VALUE ty_key(
                      matnr = <ls_data>-idnrk
                      werks = <ls_data>-werks ).
    PERFORM update_alv_fields USING ls_key1 CHANGING <ls_data>.
  ENDLOOP.

  DATA ls_tmp TYPE zscx0003_alv.
  LOOP AT gt_report ASSIGNING FIELD-SYMBOL(<ls_rpt>).
    CLEAR ls_tmp.
    MOVE-CORRESPONDING <ls_rpt> TO ls_tmp.

    DATA(ls_key2) = VALUE ty_key(
                      matnr = ls_tmp-idnrk
                      werks = ls_tmp-werks ).
    PERFORM update_alv_fields USING ls_key2 CHANGING ls_tmp.

    MOVE-CORRESPONDING ls_tmp TO <ls_rpt>.
  ENDLOOP.

  "=== V005 P_IMP 上傳建立:自動重算可轉/適用型號(記憶體,隨後 &DATA_SAVE 一起寫)===
  IF p_imp IS NOT INITIAL.
    PERFORM calc_rep USING abap_false.
  ENDIF.

  "=== V008 p_upd上傳更新:報庫存量超過018需求量→條列彈窗軟提醒(主ALV顯示前跳,時序自然;不中斷、不影響存檔)===
  IF gt_exceed IS NOT INITIAL.
    PERFORM show_exceed_popup.
  ENDIF.

  "=== 顯示 ALV ===
  IF gt_data IS NOT INITIAL AND gt_report IS INITIAL.
    PERFORM display_alv USING gt_data.
    PERFORM unlock_table.
  ELSEIF gt_data IS INITIAL AND gt_report IS NOT INITIAL.
    PERFORM display_alv USING gt_report.
  ELSE.
    MESSAGE s001(00) WITH 'No data exist.'.
  ENDIF.


*Messages
*----------------------------------------------------------
*
* Message class: 00
*001   &1&2&3&4&5&6&7&8
*
* Message class: Hard coded
*   Excel data format is wrong,please check
*
* Message class: ZCX01
*002   Update table: & successful.
*006   Non-production management personnel cannot upload, please confirm

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
