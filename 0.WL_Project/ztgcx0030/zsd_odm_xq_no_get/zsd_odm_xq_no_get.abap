FUNCTION zsd_odm_xq_no_get.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(IV_PERID) TYPE  ZIVDCH_YM
*"     REFERENCE(IV_WERKS) TYPE  WERKS_D
*"  EXPORTING
*"     REFERENCE(EV_ZXQNO) TYPE  ZXQNO
*"  EXCEPTIONS
*"      CX_NO_AUTHORITY
*"      CX_ENQ_LOCK
*"----------------------------------------------------------------------

  TYPES: BEGIN OF ty_range,
           werks  TYPE werks_d,
           zstart TYPE numc5,
         END OF ty_range.

  DATA: lt_range TYPE STANDARD TABLE OF ty_range WITH EMPTY KEY,
        ls_range TYPE ty_range.

  CLEAR lt_range.

  SELECT werks, zstart
    FROM ZTSD0117_RANGE
    INTO TABLE @lt_range.

*  ls_range-werks = '1120'.
*  ls_range-start = '60001'.
*  APPEND ls_range TO lt_range.
*
*  ls_range-werks = '2120'.
*  ls_range-start = '80001'.
*  APPEND ls_range TO lt_range.

  "# 權限 / 工廠檢查
  READ TABLE lt_range INTO ls_range WITH KEY werks = iv_werks.
  IF sy-subrc <> 0.
    MESSAGE TEXT-001 TYPE 'E'. "你沒有權限產生該廠別的 XQ 號碼
  ENDIF.

  "# 解析年月 → 前五碼
  DATA(lv_mon2) = iv_perid+2(2).          " YY .
  DATA(lv_code1) = iv_perid+5(1).         "
  CASE iv_perid+4(2).                     "10‧11‧12 轉 A/B/C
    WHEN '10'. lv_code1 = 'A'.
    WHEN '11'. lv_code1 = 'B'.
    WHEN '12'. lv_code1 = 'C'.
  ENDCASE.

  "# 取 / 建流水號（Z d/b 表：Z T S D 0 1 1 7）
  "   此處直接 SELECT ... FOR UPDATE 避免自建 ENQUEUE object
  DATA lv_serial TYPE numc5.

  SELECT SINGLE seril
         INTO @lv_serial
         FROM ztsd0117
         WHERE perid = @iv_perid
           AND werks = @iv_werks.

  IF sy-subrc = 0.
    lv_serial = lv_serial + 1.
    UPDATE ztsd0117
       SET seril = @lv_serial
     WHERE perid = @iv_perid
       AND werks = @iv_werks.
  ELSE.
    lv_serial = ls_range-zstart.

    DATA: ls_ztsd0117 TYPE ztsd0117.

    ls_ztsd0117-perid    = iv_perid.
    ls_ztsd0117-werks    = iv_werks.
    ls_ztsd0117-seril    = lv_serial.

    INSERT ztsd0117 FROM ls_ztsd0117.

  ENDIF.

  IF sy-subrc <> 0.
    ROLLBACK WORK.
  ENDIF.

  COMMIT WORK AND WAIT.

  "# 組 ZXQNO：  XQ + MM + Y/A/B/C + 5 碼流水
  ev_zxqno = |XQ{ lv_mon2 }{ lv_code1 }{ lv_serial ALPHA = OUT }|.

ENDFUNCTION.

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
