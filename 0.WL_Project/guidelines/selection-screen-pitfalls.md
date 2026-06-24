# Selection Screen 陷阱（COMMENT / TITLE / 命名）

S/4HANA 2022 / ABAP 7.57。記錄選擇畫面動態中文標題/說明常踩、**編譯期才報錯**的雷。首次落地：`ZTGCX0032`。

---

## 1. ⚠️ COMMENT 與 FRAME TITLE 的變數是「自動宣告」— 不可再 `DATA`

`SELECTION-SCREEN COMMENT ... name` 與 `SELECTION-SCREEN BEGIN OF BLOCK ... WITH FRAME TITLE name`
的 `name`，若不是 text symbol，**系統會自動宣告**這個變數。你**不可**再用 `DATA` 宣告，否則：

```
"NAME" was already declared.
```

**正確寫法**：直接在 TOP 用 `SELECTION-SCREEN`，在 `INITIALIZATION`（或 `AT SELECTION-SCREEN OUTPUT`）賦值：

```abap
* TOP：不要 DATA 宣告 gv_tit1 / ss_c01 ！由下列敘述自動宣告
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE gv_tit1.
SELECTION-SCREEN COMMENT /1(79) ss_c01.
SELECTION-SCREEN END OF BLOCK b1.

* 主程式
INITIALIZATION.
  gv_tit1 = '一、Email 發送'.        " 自動宣告的變數，這裡直接賦值
  ss_c01  = 'QQ：報MOQ>0、未刪除…'.
```

- 自動宣告的 COMMENT 變數長度＝COMMENT 的 `(len)`；賦值過長會截斷（不報錯）。
- 參考：`ZTGCX0003` 的 `WITH FRAME TITLE title01`（`title01` 從未 `DATA` 宣告，於 `INITIALIZATION` 才 `title01 = TEXT-t01.`）。

> 用變數而非 `TEXT-xxx` 的好處：中文標題自帶在程式碼，不必另外維護 text element（也不會因未維護而顯示空白）。

---

## 2. ⚠️ COMMENT / TITLE / 參數 / 選項的「名稱」≤ 8 字元

```
The name of the comment can be up to eight characters long.
```

- `gv_title1`（9 字）→ 報錯；改 `gv_tit1`（7 字）。
- 同理 `PARAMETERS` / `SELECT-OPTIONS` 名稱上限 8 字（如 `p_mail`、`s_dli`）。
- 命名請預留：`gv_tit1~3`、`ss_c01~99`、`ss_mail`、`ss_dli` 皆 ≤ 8。

---

## 3. 小結 checklist（寫選擇畫面前）
- [ ] COMMENT / TITLE 變數**不要** `DATA` 宣告（自動宣告），改在 `INITIALIZATION` 賦值。
- [ ] 所有畫面元素名稱 ≤ 8 字元。
- [ ] 動態文字用變數（免維護 text element）；於 `INITIALIZATION` 填值。
- [ ] 背景排程：說明文字純顯示即可；勿在畫面事件放會彈窗的邏輯。
```
