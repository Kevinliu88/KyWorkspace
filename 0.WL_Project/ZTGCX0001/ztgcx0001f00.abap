*&---------------------------------------------------------------------*
*& Include          ZTGCX0001F00
*&---------------------------------------------------------------------*
*& V025 JosephLo 2026/06/01 本次新增的「全域 / 畫面調整」邏輯集中於此 include。
*&   緣由:ZTGCX0001_SUB 過於龐大,先把這次新增、偏全域性質的 FORM 抽出來放這;
*&         舊有的全域 / 畫面邏輯(init_param 主體、status 設定等)日後再逐步搬入。
*&   內容:
*&     - init_mode           mode profile 解析(t-code → 能力旗標 gs_mode)
*&     - adjust_screen_filt  P_FILT 過濾勾選框的畫面顯示控制
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Form init_mode
*&---------------------------------------------------------------------*
*& mode profile：把散落的 sy-tcode 判斷收斂成一處能力旗標。
*&   呼叫時機:START-OF-SELECTION(get_global_data 後)一次,gs_mode 全域 persist 到 ALV 互動。
*&   旗標讀取點:do_filter→explode_bom/assign_rem_data/check_nomoq_rule;
*&             allow_write→frm_status_set 擋按鈕 + frm_user_command 寫入守門(雙保險);
*&             pick_basis→choose_moq_basis;relax_check→is_check_bypassed。
*&   安全原則:寫DB能力綁不可變 t-code;ZTGCX0001A 永遠 allow_write='';WHEN OTHERS 預設不可寫。
*&---------------------------------------------------------------------*
FORM init_mode .
  CLEAR gs_mode.
  gs_mode-tcode = sy-tcode.
  CASE sy-tcode.
    WHEN 'ZTGCX0001'.                  "正式交易:過濾 + 可寫DB
      gs_mode-do_filter   = 'X'.
      gs_mode-allow_write = 'X'.
    WHEN 'ZTGCX0001A'.                 "模擬/預覽:預設不過濾(勾 P_FILT 才過濾);永不寫DB;可挑基準;放寬檢查
      gs_mode-allow_write = ''.
      gs_mode-pick_basis  = 'X'.
      gs_mode-relax_check = 'X'.
*     預設不勾 = 不過濾(顯示全部);勾選 P_FILT 才過濾(只顯示本角色關注件 / 報MOQ件)
      gs_mode-do_filter   = p_filt.
    WHEN 'ZTGCX0001B'.                 "IT 返補不報MOQ子件(維持現有:不過濾、可寫DB)
      gs_mode-do_filter   = ''.
      gs_mode-allow_write = 'X'.
    WHEN OTHERS.                        "含 SE38:安全預設＝過濾、不可寫DB
      gs_mode-do_filter   = 'X'.
      gs_mode-allow_write = ''.
  ENDCASE.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form adjust_screen_filt
*&---------------------------------------------------------------------*
*& P_FILT 過濾勾選框畫面顯示控制(勾=只顯示本角色關注件、濾掉非所屬角色 / 不報MOQ;不勾=顯示全部):
*&   只在 ZTGCX0001A 模擬 + 上傳(p_imp)模式露出,其餘模式隱藏。
*&   由 init_param 呼叫(INITIALIZATION / AT SELECTION-SCREEN OUTPUT 時點)。
*&---------------------------------------------------------------------*
FORM adjust_screen_filt .
  LOOP AT SCREEN.
    IF screen-name = 'P_FILT'.
      IF sy-tcode = 'ZTGCX0001A' AND p_imp = 'X'.
        screen-active = 1.
      ELSE.
        screen-active = 0.
      ENDIF.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.
ENDFORM.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
