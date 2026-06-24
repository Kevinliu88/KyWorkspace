*&-----------------------------------------------------------------------------*
*& Report  QQ單狀態更新                                                 *
*------------------------------------------------------------------------------*
* Author      : Ron Chang                                                      *
* Purpose     : QQ單狀態更新
********************************************************************************
* MODIFICATIONS HISTORY :                                                      *
********************************************************************************
* CHANGE DATE VERSION MODIFIER DESCRIPTION
* =========== ======= ======== =================================================
* 2024/09/26  V001    Ron Chang Creation
* 2026/04/27  V002    Tristan   增加欄位ZAPROPD抓ZTSD0028-ZAPROPD(限定ZTSD0028-ZVSNMR_V = '0')
* 2026/05/27  V003    Tristan   同步訂單時XQ的客戶別需與訂單一致
* 2026/05/29  V004     JosephLo  縮窄 get_qq_data 掃描範圍:原 ~960K(僅待轉XQ的A/D已配SD單);
*                              排除 INITIAL/刪除/已轉XQ(zxqno+zxqseq)/ISMOQ歷史回填
* 2026/06/02  V005     JosephLo  移除「qq 不在 ztsd0098_xqlog」條件:一張 QQ 會轉多張 XQ,
*                              該條為 QQ 層級過濾,會誤殺「同 QQ 尚有未轉 XQ 子件」的有效列;
*                              row 層級去重已由 zxqno=''/zxqseq='' 負責,足夠且正確
* 2026/06/03  V006     JosephLo  漸進式修正(基於PRD舊版,非整支重構):
*                              ①WHERE加vbeln=''/qq<>''/moq_qty>0(只抓待補SD的待轉正列)
*                              ②拿掉「qq IS INITIAL」守門→A/D成功配SD即轉B
*                              ③砍時間窗IF/ELSEIF→不分erdat,找到訂單就轉(舊單不再卡死)
*                              ④ztsd0029只用現行zportalno(不回溯old);迴圈內用補上的vbeln
*                                查ztsd0028(0版)校驗vtweg+簽核(zapropd非空;ZDSTAT 06/04停用)並取zapropd ⑤失效C不處理
* 2026/06/05  V007    JosephLo  【目的:本批 vbeln 回填是給 ZTGCX0026 的 liability(預採帳負債)餘額計算用】
*                              ZTGCX0026 以「XQ 餘額 ⇄ IQ 需求」FIFO 沖銷算 liability 餘額;IQ 需求取自
*                              ZTCX0001(qq_status<>'C' 且 vbeln 對到 ztsd0028 0版簽核單)。vbeln 是
*                              ZTGCX0026/ZTGCX0019 的唯一鑰匙、且唯一由本 SYNC 回填。V004 把「qq_status
*                              IS INITIAL」移出掃描範圍後,「無 QQ 號直接需求」(qq_status=''+qq='' 但已有
*                              0版簽核 SO)拿不到 vbeln → 被 ZTGCX0026 漏算(liability 餘額少算)。本版新增
*                              FORM sync_blank_demand:set-based(INNER JOIN ztsd0029+ztsd0028 0版)回填
*                              vbeln/posnr/zapropd 並標 'B',讓這批需求能進 0026 正常 consume(沖銷)XQ 餘額。
*                              不濾 ismoq/moq_qty(不報MOQ子件亦有效,由 0026 menge>0 把關);不做失效'C'
*                              ('C'⟺無vbeln,下游本就要vbeln,冗餘);多SO先到先處理(假設一詢單一SO)。
* 2026/06/05  V008    JosephLo  放寬 sync_blank_demand:移除 qq='' 限制(原僅收無QQ號直接需求)。
*                              「有QQ號但qq_status空白」的破口列也會被 ZTGCX0026 漏算——成因:confirm_get_qq
*                              /calc_7day_qq 的 SWITCH 缺 WHEN'D'/OTHERS(角色D產QQ得空白)、P_FIX
*                              (frm_fix_missing_materials)根本不寫 qq_status。下游 liability/轉XQ 只認 vbeln、
*                              不認 QQ 號有無,故一併納入(實測加入後仍約5萬筆)。根因(SWITCH/P_FIX)另案修
*                              (需先定『角色D→哪個 qq_status』)。
* 2026/06/15  V009    JosephLo  放寬 sync_blank_demand 的 qq_status 守門:原僅收 ''(空白狀態),改為
*                              「<>'B' AND <>'C'」=連 A/D 也收。成因:報MOQ淨額重算(V026+)/舊 calc_7day_qq
*                              會在「不報列(moq_qty=0)」蓋 qq_status='D'/'A'(沿用前批QQ);這些列 get_qq_data
*                              因 moq_qty>0 擋掉、sync_blank_demand 因 =''擋掉 → 兩支都漏,vbeln 永不回填 →
*                              ZTGCX0026 漏算該需求(liability)。放寬後「有詢單、非B/C、有0版簽核SO」全收;
*                              get_qq_data 先轉B並COMMIT,本 SELECT 以 <>'B' 自動排除已轉列,無重複處理。
*                              PRD 佐證:此類待補列約1千筆(集中5-6月),相對現行空白批~5萬為零頭,set-based無感。
********************************************************************************
* ★ 待評估(TODO) 2026/06/03:
*   - 選擇畫面 p_date / p_days:V006 已【完全不判斷日期】(程式不讀取,填什麼都不影響結果),
*     但畫面仍顯示恐誤導使用者。後續評估:隱藏 / 改選擇文字加註「本版未使用」/ 移除。
*   - SELECT 的 ORDER BY erdat 為「排序用」(非判斷,僅讓舊單先處理),保留與否一併評估。
********************************************************************************
REPORT ztgcx0001_sync NO STANDARD PAGE HEADING.
TABLES:ztcx0001.
SELECT-OPTIONS: s_iq FOR ztcx0001-zportalno.
PARAMETERS:p_date    TYPE sy-datum DEFAULT sy-datum,
           p_days(3) TYPE p DECIMALS 0 DEFAULT 7.

* V006 2026/06/03:成功+失敗合併顯示;失敗列以紅色行 + 原因欄標註(line_color/reason)
TYPES BEGIN OF ty_show.
INCLUDE TYPE ztcx0001.
TYPES   reason     TYPE c LENGTH 60.
TYPES   line_color TYPE c LENGTH 4.
TYPES END OF ty_show.
DATA gt_show TYPE TABLE OF ty_show.

INITIALIZATION.

START-OF-SELECTION.
* V007 2026/06/05 JosephLo:get_qq_data 收集 A/D、sync_blank_demand 收集待轉正需求,
*   兩批共用 gt_show(只收集、不各自顯示);最後 show_result 統一顯示「合併」ALV(失敗以紅色行 line_color 計)。
* V009 2026/06/15:sync_blank_demand 放寬到「非 B/C」後與 get_qq_data(A/D)範圍重疊;靠 get_qq_data 先轉B並
*   COMMIT、sync_blank_demand 的 SELECT 以 <>'B' 自動排除已轉列,保證不重複處理(順序:先 get_qq_data 不可調換)。
  PERFORM get_qq_data.
  PERFORM sync_blank_demand.
  PERFORM show_result.
*&---------------------------------------------------------------------*
*& Form get_qq_data
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM get_qq_data .
* V006 2026/06/03:不再用時間窗(p_date/p_days/lv_7day),改為「不分時間,
*   只要 ztsd0029 找到訂單就轉正」。p_date/p_days 參數保留於選擇畫面(向後相容),程式不再使用。
* V004 Modified by JosephLo 2026/05/29 *
* ┌─ qq_status 狀態機(V006 2026/06/03 更新)──────────────────────────────┐
* │ INITIAL = 新詢單未 CONFIRM(上傳 SAVE)。本 SYNC 不掃(WHERE 排除)。
* │ 'A'     = 生管已確認(角色 A CONFIRM 取 QQ)。寫入:ZTGCX0001 confirm_get_qq
* │ 'D'     = 採購已確認(角色 C CONFIRM 取 QQ)。寫入:ZTGCX0001 confirm_get_qq
* │ 'B'     = 詢單已轉正。寫入:本 SYNC 迴圈。
* │           條件(V006):A/D + ztsd0029 找到 vbeln + ztsd0028 0版已簽核(zapropd;ZDSTAT 06/04停用)
* │                      + 通路(vtweg)一致;【不分 erdat 時間窗】。
* │ 'C'     = 失效。本 SYNC【V006 起不處理】:找不到訂單僅 CONTINUE 跳過,不標 C
* │           (舊版時間窗 ELSEIF 標 C 邏輯已移除)。
* │
* │ 流轉:  A/D ──(配到 SD + 0版簽核 + 通路一致,本 SYNC)──► B(終態)
* │        A/D ──(找不到訂單/未簽核/通路不符)─────────────► 維持 A/D(下次再試)
* │
* │ SYNC 服務對象 = A/D 且 vbeln='' 且 qq<>'' 且 moq_qty>0(待補 SD 的待轉正列)
* └─────────────────────────────────────────────────────────────────────┘
*
* 原 WHERE 含 qq_status IS INITIAL 會撈 ~960K 筆,經 ZSQL 分析:
*  -  95 萬筆是上傳 SAVE 但未 CONFIRM 的 INITIAL; 原 ELSEIF 標 'C' 路徑因 V003 CONTINUE 已失效,本版直接排除留待獨立流程
*  - 真正待 SYNC = A/D + 已配 SD 單但尚未轉 XQ
* 同步排除已刪除(loekz)/已轉 XQ(zxqno+zxqseq)/歷史回填(ismoq='X')。
* V005(2026/06/02): 移除原「qq NOT IN ztsd0098_xqlog」條件。
*   一張 QQ 會轉多張 XQ(每子件 1 張),該條為 QQ 層級過濾,只要同 QQ 任一子件已轉 XQ,
*   會把同 QQ 尚未轉的有效子件一併誤殺。改靠 row 層級 zxqno=''/zxqseq='' 去重即可。
  SELECT * FROM ztcx0001
    WHERE zportalno IN @s_iq
      AND ( qq_status = 'A' OR qq_status = 'D' )
      AND loekz  = ''
      AND zxqno  = ''
      AND zxqseq = ''
      AND ismoq  = ''
      AND vbeln  = '' "V006 JosephLo:只抓尚未配 SD 單的(待補 vbeln)
      AND qq    <> '' "V006 JosephLo
      AND moq_qty > 0 "V006 JosephLo
* V005 Removed by JosephLo 2026/06/02 *
*       AND qq NOT IN ( SELECT z_ori_num FROM ztsd0098_xqlog WHERE ftype = 'QQ' )
  ORDER BY erdat
  INTO TABLE @DATA(lt_qq).
* V004 End off *
* V006 2026/06/03:原 V002 it_0028 迴圈外預載(用舊 vbeln)已無意義,
*   改為迴圈內用「本次補上的 vbeln」查 ztsd0028,故整段預載刪除。
*  DATA lt_done TYPE TABLE OF ztcx0001.   "V006:成功改走 gt_show,lt_done 已不用
  DATA lv_ok   TYPE i.
  DATA lv_skip TYPE i.
  LOOP AT lt_qq ASSIGNING FIELD-SYMBOL(<ls_qq>).

* V006 2026/06/03 整合:不分時間窗,只要 ztsd0029 找到訂單,且 ztsd0028(0版)
*   通過 approved + vtweg 校驗,即轉正 B。失效 C 不處理(找不到就 CONTINUE)。
* 用現行 zportalno 找 ztsd0029 訂單(不回溯 oldzportalno)
    SELECT SINGLE vbeln, posnr FROM ztsd0029
      WHERE zportalno = @<ls_qq>-zportalno
*        AND zvsnmr_v = '000'   "V006 先註解:ztsd0029 不取版本,與舊版一致(0版僅 ztsd0028 用)
      INTO @DATA(ls_sd029).
    IF sy-subrc <> 0 OR ls_sd029-vbeln IS INITIAL.
      PERFORM add_show USING <ls_qq> 'ztsd0029 查無對應訂單' 'C610'.
      CONTINUE.                                   "找不到訂單 → 跳過(失效C不處理)
    ENDIF.

* 用該 vbeln 查 ztsd0028(0版):校驗 vtweg + 簽核(zapropd 非空 且 ZDSTAT='1'),取 zapropd
    SELECT SINGLE vtweg, zapropd, zdstat FROM ztsd0028
      WHERE vbeln    = @ls_sd029-vbeln
        AND zvsnmr_v = '000'
      INTO @DATA(ls_sd028).
    DATA lv_rsn TYPE c LENGTH 60.   "失敗原因(含訂單號,便於排查)
    IF sy-subrc <> 0.
      lv_rsn = |ztsd0028 無0版訂單 訂單={ ls_sd029-vbeln }|.
      PERFORM add_show USING <ls_qq> lv_rsn 'C610'.
      CONTINUE.                                   "該 vbeln 無0版 → 跳過
    ENDIF.
    IF ls_sd028-zapropd IS INITIAL.
      lv_rsn = |ztsd0028 未簽核(zapropd 空) 訂單={ ls_sd029-vbeln }|.
      PERFORM add_show USING <ls_qq> lv_rsn 'C610'.
      CONTINUE.                                   "未簽核(zapropd 為空)→ 跳過
    ENDIF.
* 2026/06/04 與顧問 Oliver、KY 討論,決定先將此訂單狀態(ZDSTAT)的判斷拿掉。
*   若業務端因各種原因決定取消,則由他們人為判斷是否將已轉(報MOQ)的 XQ 取消(做轉出),
*   或是走 XJ 訂單取消流程(假設已經有需求單據)。
*    IF ls_sd028-zdstat <> '1'.
*      lv_rsn = |ztsd0028 簽核ZDSTAT≠1 訂單={ ls_sd029-vbeln }|.
*      PERFORM add_show USING <ls_qq> lv_rsn 'C610'.
*      CONTINUE.                                   "簽核狀態 ZDSTAT 必須=1 → 跳過(2026/06/03 加,06/04 停用)
*    ENDIF.
    IF ls_sd028-vtweg <> <ls_qq>-vtweg.
      lv_rsn = |通路不一致 訂單={ ls_sd029-vbeln } SD通路={ ls_sd028-vtweg } CX通路={ <ls_qq>-vtweg }|.
      PERFORM add_show USING <ls_qq> lv_rsn 'C610'.
      CONTINUE.                                   "通路不一致 → 跳過(remove)
    ENDIF.

* 全過 → 回填 + 轉正B
*   ※ztsd0029 不取版本(與舊版一致);多SO時 SELECT SINGLE 取任意一筆,配合 WHERE vbeln=''
*     為先到先得首次定案(多SO規則待PRD量化,見 ZTGCX0001_SYNC_PRD驗證SQL_一詢單多SO.md)
    <ls_qq>-vbeln     = ls_sd029-vbeln.
    <ls_qq>-posnr     = ls_sd029-posnr.
    <ls_qq>-zapropd   = ls_sd028-zapropd.
    <ls_qq>-qq_status = 'B'.            "詢單已轉正
    <ls_qq>-chdat     = sy-datum.
    <ls_qq>-chtim     = sy-uzeit.
    <ls_qq>-chnam     = sy-uname.


    UPDATE ztcx0001
      SET vbeln = @<ls_qq>-vbeln,
          posnr = @<ls_qq>-posnr,
          qq_status = @<ls_qq>-qq_status,
          chdat = @<ls_qq>-chdat,
          chtim = @<ls_qq>-chtim,
          chnam = @<ls_qq>-chnam,
* V002 Added by Tristan 2026/04/27 *
          zapropd = @<ls_qq>-zapropd
* V002 End off *
    WHERE werks = @<ls_qq>-werks
      AND vtweg = @<ls_qq>-vtweg
      AND zseq = @<ls_qq>-zseq
      AND zportalno = @<ls_qq>-zportalno
      AND idnrk = @<ls_qq>-idnrk
*     V006 safety:選取到回寫有時間差,重驗來源條件避免誤轉
      AND ( qq_status = 'A' OR qq_status = 'D' )
      AND vbeln  = ''
      AND qq    <> ''
      AND moq_qty > 0
      AND zxqno  = ''
      AND zxqseq = ''
      AND loekz  = ''
      AND ismoq  = ''.
    IF sy-subrc = 0.
      lv_ok = lv_ok + 1.
      PERFORM add_show USING <ls_qq> '轉正成功' space.             "成功:不上色
    ELSE.
      lv_skip = lv_skip + 1.
      PERFORM add_show USING <ls_qq> '回寫時重驗未過(選取後狀態已變)' 'C610'.
    ENDIF.
  ENDLOOP.
  IF lv_ok > 0.
    COMMIT WORK AND WAIT.
  ENDIF.
*  LOOP AT lt_qq INTO DATA(ls_d) GROUP BY ( zportalno = ls_d-zportalno size = GROUP SIZE ) INTO DATA(lg_qq).
*    LOOP AT GROUP lg_qq ASSIGNING FIELD-SYMBOL(<ls_qq>).
*      IF <ls_qq>-erdat BETWEEN  lv_7day AND p_date.
*        SELECT SINGLE vbeln,posnr FROM ztsd0029
*          WHERE zportalno = @<ls_qq>-zportalno
*        INTO @DATA(ls_sd029).
*        IF sy-subrc = 0 AND ls_sd029-vbeln IS NOT INITIAL.
*          <ls_qq>-vbeln = ls_sd029-vbeln.
*          <ls_qq>-posnr = ls_sd029-posnr.
*          IF <ls_qq>-qq IS INITIAL.
*            <ls_qq>-qq_status = 'B'. "詢單已轉正
*          ENDIF.
*          <ls_qq>-chdat = sy-datum.
*          <ls_qq>-chtim = sy-uzeit.
*          <ls_qq>-chnam = sy-uname.
*        ENDIF.
*      ELSEIF <ls_qq>-erdat < lv_7day.
*        SELECT SINGLE vbeln,posnr FROM ztsd0029
*          WHERE zportalno = @<ls_qq>-zportalno
*        INTO @ls_sd029.
*        IF sy-subrc NE 0 OR ( sy-subrc = 0 AND ls_sd029-vbeln IS INITIAL ).
*          <ls_qq>-vbeln = ls_sd029-vbeln.
*          <ls_qq>-posnr = ls_sd029-posnr.
*          IF <ls_qq>-qq IS INITIAL.
*            <ls_qq>-qq_status = 'C'. "失效
*          ENDIF.
*          <ls_qq>-chdat = sy-datum.
*          <ls_qq>-chtim = sy-uzeit.
*          <ls_qq>-chnam = sy-uname.
*        ENDIF.
*      ENDIF.
*    ENDLOOP.
  "重新計算其它詢單同子件的需求數和MOQ數
*    LOOP AT GROUP lg_qq INTO DATA(ls_d1) WHERE qq_status = 'B' OR qq_status = 'C'
*                  GROUP BY ( werks = ls_d1-werks
*                             vtweg = ls_d1-vtweg
*                             zseq = ls_d1-zseq
*                             idnrk = ls_d1-idnrk ) INTO DATA(lg_recalc).
*
*      SELECT * FROM ztcx0001
*        WHERE werks = @lg_recalc-werks
*          AND vtweg = @lg_recalc-vtweg
*          AND zseq = @lg_recalc-zseq
*          AND idnrk  = @lg_recalc-idnrk
*          AND qq IS INITIAL
*          AND erdat BETWEEN @lv_7day AND @sy-datum
*      INTO TABLE @DATA(lt_recalc).
*
*      LOOP AT lt_recalc INTO DATA(ls_re).
*
*      ENDLOOP.
*
*
*    ENDLOOP.
*ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form show_result — V007 2026/06/05 JosephLo
*&   統一顯示 gt_show:get_qq_data 的 A/D + sync_blank_demand 的「待補SD需求(非B/C)」,
*&   合併於同一張 ALV。失敗紅色行(line_color='C610')+ 原因欄(reason);成功/失敗數以紅色行計。
*&---------------------------------------------------------------------*
FORM show_result.
* V006 顯示:成功+失敗合併(gt_show),失敗紅色行(line_color='C610')+原因欄(reason);
*   因多了 reason 欄,改用 fieldcat(REUSE_ALV_FIELDCATALOG_MERGE 自動產生再 append)。
  IF gt_show IS NOT INITIAL.
    DATA lt_fcat   TYPE slis_t_fieldcat_alv.
    DATA ls_fc     TYPE slis_fieldcat_alv.
    DATA ls_layout TYPE slis_layout_alv.
    CALL FUNCTION 'REUSE_ALV_FIELDCATALOG_MERGE'
      EXPORTING
        i_program_name   = sy-repid
        i_structure_name = 'ZTCX0001'
      CHANGING
        ct_fieldcat      = lt_fcat
      EXCEPTIONS
        OTHERS           = 0.
    CLEAR ls_fc.
    ls_fc-fieldname    = 'REASON'.
    ls_fc-seltext_l    = '狀態/失敗原因'.
    ls_fc-seltext_m    = '狀態/失敗原因'.
    ls_fc-seltext_s    = '原因'.
    ls_fc-reptext_ddic = '狀態/失敗原因'.
    APPEND ls_fc TO lt_fcat.
    ls_layout-colwidth_optimize = 'X'.
    ls_layout-info_fieldname    = 'LINE_COLOR'.   "失敗='C610'紅,成功=空
* V001 Added by Tristan 2026/02/12 *
    IF sy-batch = ''.
* V001 End off *
      CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
        EXPORTING
          it_fieldcat = lt_fcat
          is_layout   = ls_layout
        TABLES
          t_outtab    = gt_show
        EXCEPTIONS
          OTHERS      = 0.
* V001 Added by Tristan 2026/02/12 *
    ENDIF.
* V001 End off *

    DATA lv_total TYPE i.
    DATA lv_fail  TYPE i.
    lv_total = lines( gt_show ).
* V007 2026/06/05 JosephLo:gt_show 現含「A/D」+「待補SD需求(非B/C)」兩批;失敗數改以紅色行(line_color
*   ='C610')計、成功=總-失敗,避免沿用 lv_ok(只計 A/D)把直接需求的成功列誤算成失敗。
    lv_fail = 0.
    LOOP AT gt_show TRANSPORTING NO FIELDS WHERE line_color = 'C610'.
      lv_fail = lv_fail + 1.
    ENDLOOP.
    DATA(lv_msg) = |本次同步抓出 { lv_total } 筆:轉正成功 { lv_total - lv_fail } 筆,失敗 { lv_fail } 筆(紅色行)|.
    MESSAGE lv_msg TYPE 'S'.
  ELSE.
    MESSAGE '查無待處理資料' TYPE 'S'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form add_show — 收集顯示列(成功/失敗)+ 原因 + 行顏色
*&   pv_color: 'C610'=紅(失敗) / space=不上色(成功)
*&---------------------------------------------------------------------*
FORM add_show USING ps_data  TYPE ztcx0001
                    pv_reason TYPE c
                    pv_color  TYPE c.
  APPEND INITIAL LINE TO gt_show ASSIGNING FIELD-SYMBOL(<s>).
  MOVE-CORRESPONDING ps_data TO <s>.
  <s>-reason     = pv_reason.
  <s>-line_color = pv_color.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form sync_blank_demand — V007/V008 2026/06/05、V009 2026/06/15 JosephLo
*&   V009 起守門放寬為「qq_status <> 'B' AND <> 'C'」(原僅 ''):涵蓋 ①無 QQ 號直接需求 ②有 QQ 號但
*&   qq_status 空白的破口列(角色 D 的 SWITCH 缺 WHEN'D' / P_FIX 不寫 qq_status) ③A/D 不報列(moq_qty=0,
*&   沿用前批QQ得'D'/'A',get_qq_data 因 moq_qty>0 漏收)。zportalno 對到 0版簽核 SO、但
*&   ZTCX0001-vbeln 未回填者。vbeln 是 ZTGCX0019(轉XQ)/ZTGCX0026(liability)
*&   的唯一鑰匙(兩者都 INNER JOIN ztsd0028 ON vbeln);本 FORM 把 ztsd0029 的
*&   vbeln 搬進 ZTCX0001 並標 'B',讓這批直接需求能進 ZTGCX0026 的 liability(預採帳負債)餘額
*&   計算、正常 consume(沖銷)XQ 餘額(這正是本 FORM 存在的目的)。
*&   ※不做失效'C':'C'⟺無vbeln,而下游本就要vbeln,'C'冗餘(訂單取消走人工)。
*&   ※不濾 ismoq/moq_qty:不報MOQ(子件)亦為有效需求,由 ZTGCX0026 的 menge>0 把關。
*&---------------------------------------------------------------------*
FORM sync_blank_demand.
* Step1 set-based 撈「非B/C(qq_status<>'B' AND <>'C')待轉正需求 + 0版簽核SO」(取代逐筆 SELECT SINGLE,避免百萬 N+1)
  SELECT a~werks, a~vtweg, a~zseq, a~zportalno, a~idnrk,
         d~vbeln, d~posnr, b~zapropd
    FROM ztcx0001 AS a
    INNER JOIN ztsd0029 AS d ON d~zportalno = a~zportalno
    INNER JOIN ztsd0028 AS b ON b~vbeln    = d~vbeln
                            AND b~zvsnmr_v = '000'
                            AND b~vtweg    = a~vtweg          "通路一致(V006 三關之一)
    WHERE a~zportalno IN @s_iq
*     V009 2026/06/15:放寬「= ''」→「<>'B' AND <>'C'」,把 A/D 不報列(moq_qty=0,沿用前批QQ得'D'/'A')也納入;
*       get_qq_data 先轉B並COMMIT,<>'B' 自動排除已轉列,兩支不重複(順序:先 get_qq_data)
      AND a~qq_status <> 'B' AND a~qq_status <> 'C'   "V008→V009:'' → 非B/C(空白+A/D不報+破口列全收)
      AND a~loekz     = ''
      AND a~zxqno     = ''        "尚未轉XQ
      AND a~zxqseq    = ''
      AND a~vbeln     = ''        "vbeln 待補(唯一鑰匙;有值的已能被 0019/0026 看到)
      AND b~zapropd  <> '00000000'   "已簽核(zapropd 是 DATS,空=00000000)
    INTO TABLE @DATA(lt_blank).
  IF lt_blank IS INITIAL.
    RETURN.
  ENDIF.

* Step2 一詢單多SO → 先到先處理(假設業務一詢單一SO):同一 ZTCX0001 列只留首筆
*   排序後取 zapropd 最早→vbeln 最小(確定性);此即先到先得首次定案。
  SORT lt_blank BY werks vtweg zseq zportalno idnrk zapropd vbeln.
  DELETE ADJACENT DUPLICATES FROM lt_blank
         COMPARING werks vtweg zseq zportalno idnrk.

* Step3 check-and-set 回填 vbeln/posnr/zapropd + 標'B';WHERE 主鍵外重驗來源條件
*   (選取到回寫有時間差/並發時,狀態已變的列 sy-subrc<>0 自動跳過)。成功/跳過列收進 gt_show,
*   與 get_qq_data 的 A/D 結果「合併」於同一張 ALV 顯示(統一由 FORM show_result 顯示)。
  DATA lv_ok   TYPE i.
  DATA ls_disp TYPE ztcx0001.        "顯示用工作區(MOVE-CORRESPONDING 自 ls_b)
  LOOP AT lt_blank INTO DATA(ls_b).
    UPDATE ztcx0001
       SET vbeln     = @ls_b-vbeln,
           posnr     = @ls_b-posnr,
           zapropd   = @ls_b-zapropd,
           qq_status = 'B',
           chdat     = @sy-datum,
           chtim     = @sy-uzeit,
           chnam     = @sy-uname
     WHERE werks     = @ls_b-werks
       AND vtweg     = @ls_b-vtweg
       AND zseq      = @ls_b-zseq
       AND zportalno = @ls_b-zportalno
       AND idnrk     = @ls_b-idnrk
       AND qq_status <> 'B' AND qq_status <> 'C'   "V009 2026/06/15:對齊放寬後的選取條件(原 ='')
       AND vbeln     = ''
       AND zxqno     = ''
       AND zxqseq    = ''
       AND loekz     = ''.
    DATA(lv_subrc) = sy-subrc.   "先固定 UPDATE 回傳碼(後續 CLEAR/MOVE 不動 sy-subrc,仍以此判定)
    CLEAR ls_disp.
    MOVE-CORRESPONDING ls_b TO ls_disp.
    ls_disp-qq_status = 'B'.
    IF lv_subrc = 0.
      lv_ok = lv_ok + 1.
      PERFORM add_show USING ls_disp '待補SD轉正成功(→B)' space.
    ELSE.
      PERFORM add_show USING ls_disp '待補SD跳過(選取後狀態已變/並發)' 'C610'.
    ENDIF.
  ENDLOOP.
  IF lv_ok > 0.
    COMMIT WORK AND WAIT.
  ENDIF.
* 顯示交給 FORM show_result 統一(本批成功/跳過列已 add_show 進 gt_show);此處不另發訊息。
ENDFORM.