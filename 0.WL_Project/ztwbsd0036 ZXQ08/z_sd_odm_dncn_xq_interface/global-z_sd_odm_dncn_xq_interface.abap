FUNCTION-POOL ZSD_ODM_DNCN  MESSAGE-ID ZODMSD01.

* INCLUDE LZSD_ODM_DNCND...                  " Local class definition
TABLES: ZTSD_PR_YY_CODE, ZTSD0099.

DATA: GW_ZTSD0119    LIKE ZTSD0119.        "DN/CN單據類型
DATA: G_NR_RANGE_NR LIKE  INRI-NRRANGENR,  "號碼範圍編號
      G_OBJECT      LIKE  INRI-OBJECT,     "號碼範圍物件的名稱
      G_SUBOBJECT   TYPE  ZPR_YY.
DATA: GW_ZTSD0119CUS LIKE ZTSD0119CUS.     "付款方DN/CN 取號設定檔


DATA: G_ERROR(50).

----------------------------------------------------------------------------------
Extracted by Mass Download version 1.5.5 - E.G.Mellodew. 1998-2026. Sap Release 757
