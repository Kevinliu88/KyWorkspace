# 專案資料夾結構

`JLOSAPSpace/` 底下每一個子資料夾代表一個獨立的 ABAP 程式專案（可能對應一支主程式、一組相關程式、或一段功能改修案）。本文件定義每個專案資料夾內部該有什麼。

---

## 命名規則

```
<Domain>_<MainProg>[_<RelatedProg|Version>][_<中文簡述>]
```

| 段 | 說明 | 範例 |
| --- | --- | --- |
| `<Domain>` | 業務情境標籤，不一定等於 SAP 模組 | `Ship` / `SO` / `WO` / `PO` / `MM` / `FI` |
| `<MainProg>` | 主程式名稱（原始 Z/Y 物件名） | `ZSD012` / `ZPPB015` / `ZMMB007` |
| `<RelatedProg|Version>` | 關聯程式或版本標記，選用 | `ZSDR0017V2` / `ZSD_PACKING_02` |
| `<中文簡述>` | 給人類辨識用 | `客戶開發單` / `線材打工單` |

範例（取自實際工作區）：

```
Ship_ZSD012_ZSD_PACKING_02_...
SO_ZSD002_ZSDS0003_客戶開發...
SO_ZSD040_ZSDR0017V2_預計出口櫃數抓...
WO_ZPPB015_線材打工單與銷售...
Z_56_DDIC_TXT_印出ddic文字格式
```

> Windows 檔名上限 = 路徑總長 260 字元（除非開長路徑），中文簡述請精簡，必要時擷取關鍵字即可。

---

## 標準資料夾骨架

```
<ProjectFolder>/
├── <MainProg>.abap                    # 主程式（必有）
├── <MainProg>_Analysis_Report.md      # 分析報告 / 文件（建議有）
├── include/                           # 主程式相依的 includes
│   ├── <MainProg>_TOP.abap            #   全域宣告 (TABLES, DATA, TYPES)
│   ├── <MainProg>_F01.abap            #   FORM 子程式
│   ├── <MainProg>_O01.abap            #   PBO modules (Dynpro)
│   ├── <MainProg>_I01.abap            #   PAI modules (Dynpro)
│   └── <MainProg>_S01.abap            #   Selection screen
├── prompt/                            # 給 Claude/LLM 用的 prompt 草稿、設計討論
│   └── *.md
├── screen/                            # (選用) Dynpro 截圖、layout 草圖
├── data/                              # (選用) 測試資料 CSV/Excel、debug 樣本
└── notes/                             # (選用) 會議紀錄、SAP Note、客戶來信
```

**必要**：`<MainProg>.abap`、`include/` (如該程式有 include)。
**強烈建議**：`<MainProg>_Analysis_Report.md`、`prompt/`。
**選用**：其餘依該專案需求加。

---

## 各檔案/資料夾用途

### `<MainProg>.abap`

主程式原始碼。命名沿用 SAP 物件名（不加 Z 前綴去掉的版本，保持完整）。

### `<MainProg>_Analysis_Report.md`

該專案的核心分析文件，建議涵蓋：

1. **程式用途**：解決什麼業務問題、誰使用、執行時機。
2. **輸入 / 輸出**：Selection screen 參數、Output 樣式 (ALV / spool / 寫入哪張表)。
3. **資料來源**：用到哪些 table / CDS / FM / BAPI。
4. **流程概述**：高層次的流程圖或 step list。
5. **修改紀錄**：本次改了什麼、為什麼、影響範圍（給人類看，比 git log 更業務面）。
6. **待辦 / 風險 / 疑問**。

### `include/`

主程式相依的 Z include。命名沿用 SAP 慣例 (`_TOP` / `_F01` / `_O01` / `_I01` / `_S01` ...)。

### `prompt/`

放給 Claude 或其他 LLM 用的 prompt 草稿、設計討論摘錄、refactor 計畫等。讓重複性的提問（例如「請依 Clean ABAP 重構 FORM xxx」）可以版本化。

### `screen/` (選用)

Dynpro 編號、layout 截圖、欄位對照表。對純 report 程式不需要。

### `data/` (選用)

僅放**該專案**用到的測試資料、樣本檔；非通用資料。**敏感欄位需先去識別化**。

### `notes/` (選用)

會議紀錄、相關 SAP Note 摘錄、Email 整理、Issue tracker 連結等雜項。

---

## 建立新專案的快速流程

1. 在 `JLOSAPSpace/` 下依命名規則建資料夾。
2. 把 SAP 上抓下來的主程式存成 `<MainProg>.abap`。
3. 把 include 全部抓下來放進 `include/`，檔名沿用 SAP 上的名字。
4. 建一份 `<MainProg>_Analysis_Report.md`，至少寫上「程式用途」與「本次要改什麼」。
5. 開始與 Claude 對話前，把背景丟給它：「請先讀 `<MainProg>.abap` 和 `<MainProg>_Analysis_Report.md`」。

---

## 與全域 guidelines 的關係

- `naming-conventions.md` 與 `clean-abap.md` 適用於**所有**專案，撰寫/review code 時預設遵循。
- 若某專案有特例（例如維護舊系統、需保留 `TABLES` 寫法），在該專案的 `Analysis_Report.md` 中明確記下「本程式不套用 XX 規則，原因：...」。
