# 命名規範 (Naming Conventions)

適用範圍：S/4HANA 2022 on-premise，自開發 (custom development) 物件。

## 命名空間

| 命名空間 | 用途 |
| --- | --- |
| `Z*` | 預設客戶自開發物件 (SAP-reserved customer namespace) |
| `Y*` | 保留給臨時/實驗性物件、POC，正式上線前應改名為 `Z*` |
| `/XXX/` | 註冊命名空間，本專案目前**未使用**，如有需要再申請 |

> 嚴禁直接以 `Z`/`Y` 之外的字元起頭建立物件（會擋在 development class check）。

## 物件命名通則

格式：`Z{物件類型縮寫}_{模組}_{描述}`

- 全大寫、用底線分隔。
- **模組縮寫**：MM / SD / FI / CO / PP / WM / HR / BC（Basis） 等。跨模組或共用工具用 `COM`。
- **描述**：英文縮寫，避免中文拼音；以名詞為主，動詞用於程式/方法名。
- 物件名稱**最長 30 字元**（DDIC 物件多半限制如此），命名前先預留版本後綴空間。

## 各類物件命名

### Repository 物件

| 物件類型 | 前綴 | 範例 |
| --- | --- | --- |
| Executable Program (Report) | `Z_R_` 或 `ZR_` | `ZR_MM_PO_OVERDUE` |
| Module Pool / Dynpro 程式 | `ZM_` / `SAPMZ` | `SAPMZSD_QUOTE` |
| Include | `ZI_` (跟著主程式) | `ZR_MM_PO_OVERDUE_F01` (Form 子程式 include 沿 SAP 慣例) |
| Function Group | `ZFG_` | `ZFG_MM_PO` |
| Function Module | `Z_` (依 FG) | `Z_MM_PO_HEADER_GET` |
| Global Class | `ZCL_` | `ZCL_MM_PO_OVERDUE_REPORT` |
| Global Interface | `ZIF_` | `ZIF_MM_PRICING_STRATEGY` |
| Exception Class | `ZCX_` | `ZCX_MM_PO_NOT_FOUND` |
| Type Pool | `ZTY_` | `ZTY_COM_RANGES` |
| Message Class | `ZMC_` | `ZMC_MM` |

### DDIC 物件

| 物件類型 | 前綴 | 範例 |
| --- | --- | --- |
| Domain | `ZD_` | `ZD_MM_PO_STATUS` |
| Data Element | `ZE_` | `ZE_MM_PO_STATUS` |
| Table (透通表) | `ZT_` | `ZT_MM_PO_LOG` |
| Structure | `ZS_` | `ZS_MM_PO_HEADER` |
| Table Type | `ZTT_` | `ZTT_MM_PO_HEADER` |
| View (CDS) | `ZC_*` (Consumption) / `ZI_*` (Interface) / `ZR_*` (Raw/基底) | `ZI_PurchaseOrderItem` |
| Search Help | `ZSH_` | `ZSH_MM_VENDOR` |
| Lock Object | `EZ_` (SAP 規定 lock obj 以 `E` 開頭) | `EZ_MM_PO_LOG` |

### CDS / RAP 命名

S/4 2022 已全面支援 RAP，CDS View Entity 命名採 CamelCase（SAP 官方寫法）：

- Interface View: `ZI_<業務實體>`（例：`ZI_SalesOrderItem`）
- Consumption View: `ZC_<業務實體>`（例：`ZC_SalesOrderItemTP`）
- Behavior Definition / Implementation 用相同主體名字。

### 開發類別 (Package)

- `Z_MM_PO` / `Z_SD_QUOTE`，依模組劃分。
- 開發類別應指定軟體元件 (`HOME` 或對應 component)、傳輸層 (transport layer)。

### 變數與內部命名（程式內部）

| 類型 | 規則 | 範例 |
| --- | --- | --- |
| 區域變數 | `lv_` / `ls_` / `lt_` / `lr_` / `lo_` | `lv_count` / `ls_po_header` / `lt_po_item` / `lr_matnr` / `lo_logger` |
| Importing 參數 | `iv_` / `is_` / `it_` / `ir_` / `io_` | `iv_belnr` |
| Exporting 參數 | `ev_` / `es_` / `et_` / `er_` / `eo_` | `et_messages` |
| Changing 參數 | `cv_` / `cs_` / `ct_` / `cr_` / `co_` | `cs_header` |
| Returning 參數 | `rv_` / `rs_` / `rt_` / `rr_` / `ro_` | `rv_result` |
| 全域變數（盡量避免） | `gv_` / `gs_` / `gt_` | `gt_po_log` |
| 常數 | `gc_` / `lc_` | `gc_status_open` |
| 類別屬性 | 無前綴，直接用語意名 | `messages`, `is_dirty` |
| 類別方法 | 動詞開頭 | `get_overdue_pos`, `calculate_total` |

> **Clean ABAP 立場**：類別屬性、方法、區域變數**不再使用匈牙利前綴**。前綴規則上方仍保留以相容團隊習慣，新寫的 OO code 建議向 Clean ABAP 看齊（見 `clean-abap.md`）。在同一份程式中保持一致即可，**忌混用**。

## Transport Request 命名

`{系統}K9{流水號}` 為 SAP 自動產生，無須命名。但 TR **描述**請依以下格式：

```
[模組] [單號或工單] 簡短描述
```

範例：`[MM] CR-2024-117 採購單逾期報表新增廠商過濾`

## 訊息類別 (Message Class)

- 訊息類別本身 `ZMC_<模組>`。
- 訊息編號 001–999，按功能分區段（例：001–099 = PO，100–199 = GR ...），並在 long text 維護中文說明。
