/*ZXQ07-單顆長交期預採_202602 - 全欄位優先取 EBAN 版*/
WITH 
-- 1. 預處理客戶對照表
CTE_Customer AS (
    SELECT vtweg, MAX(kunnr) as kunnr
    FROM ZTCX0008A
    GROUP BY vtweg
),
 
-- 2. 預處理物料主檔對照表 (原本的 ZBQTY 來源)
CTE_SKU AS (
    SELECT vtweg, idnrk, MAX(SKUITEM) as SKUITEM, MAX(MNGLG) as MNGLG
    FROM ztcx0001
    GROUP BY vtweg, idnrk
),
 
-- 3. 處理 ZVSD0003 設定檔 (原本的 ZUNPTYP, ZCPNO 等來源)
CTE_ZVSD AS (
    SELECT a.*
    FROM zvsd0003 a
    INNER JOIN (
        SELECT vtweg, zpno, MAX(zxqno) as zxqno 
        FROM zvsd0003 
        WHERE ZUNPTYP BETWEEN '6' AND 'W' 
        GROUP BY vtweg, zpno
    ) b ON a.zxqno = b.zxqno AND a.vtweg = b.vtweg AND a.zpno = b.zpno
)
 
-- 4. 主查詢
SELECT 
    a.werks,
    b.vtweg,
    cust.kunnr AS customer_1,
    cust.kunnr AS customer_2,
    a.CREATIONDATE,
    /* ZXQLINE 優先取 EBAN.ZZMOQLINE */
    CASE 
        WHEN a.ZZMOQLINE IS NOT NULL AND a.ZZMOQLINE <> '' THEN a.ZZMOQLINE
        WHEN b.vtweg = 'G1' THEN 'USA' 
        ELSE 'GLOBAL' 
    END AS ZXQLINE,
    1 AS Class_1,
    /* ZUNPTYP 優先取 EBAN.ZZUNPTYP */
    CASE 
        WHEN a.ZZUNPTYP IS NOT NULL AND a.ZZUNPTYP <> '' THEN a.ZZUNPTYP 
        ELSE e.ZUNPTYP 
    END AS ZUNPTYP,
 
    /* zcpno / ZCPNOCN 優先取 EBAN.ZZSKUITEM */
    CASE 
        WHEN a.ZZSKUITEM IS NOT NULL AND a.ZZSKUITEM <> '' THEN a.ZZSKUITEM
        WHEN e.zcpno IS NOT NULL AND e.zcpno <> '' THEN e.zcpno
        ELSE sku.SKUITEM 
    END AS zcpno,
    CASE 
        WHEN a.ZZSKUITEM IS NOT NULL AND a.ZZSKUITEM <> '' THEN a.ZZSKUITEM
        WHEN e.ZCPNOCN IS NOT NULL AND e.ZCPNOCN <> '' THEN e.ZCPNOCN
        ELSE sku.SKUITEM 
    END AS ZCPNOCN,
    e.ZDESC_H,
    a.BANFN || '-' || a.BNFPO AS PR_SEQ,
    a.matnr,
    '' AS matnr_like,
    'X' AS ZTUNYN,
    /* class_2 同步 ZUNPTYP 邏輯 */
    CASE 
        WHEN a.ZZUNPTYP IS NOT NULL AND a.ZZUNPTYP <> '' THEN a.ZZUNPTYP 
        ELSE e.ZUNPTYP 
    END AS class_2,
    a.menge,
    /* ZBQTY 優先取 EBAN.ZZMNGLG */
    CASE 
        WHEN a.ZZMNGLG IS NOT NULL AND a.ZZMNGLG > 0 THEN a.ZZMNGLG
        WHEN e.ZBQTY IS NOT NULL THEN e.ZBQTY 
        ELSE sku.MNGLG 
    END AS ZBQTY,
    COALESCE(d.WAERS, a.WAERS) AS WAERS,
    CASE 
        WHEN c.NETPR IS NOT NULL THEN c.NETPR / NULLIF(c.PEINH, 0) 
        ELSE a.PREIS / NULLIF(a.PEINH, 0) 
    END AS unit_price,
    a.ZZBPMNUMBER || '-' || a.ZZBPMNUMITEM AS BPM_SEQ,
    c.EBELN || '-' || c.EBELP AS PO_SEQ
FROM eban a
INNER JOIN tvtwt b
    ON a.mandt = b.mandt
   AND b.spras = 'M'
   AND UPPER(b.vtext) LIKE RTRIM(UPPER(a.zzcustomer)) || '%'
LEFT JOIN CTE_Customer cust
    ON b.vtweg = cust.vtweg
LEFT JOIN EKPO c
    ON a.EBELN = c.EBELN AND a.EBELP = c.EBELP
LEFT JOIN EKKO d
    ON a.EBELN = d.EBELN
LEFT JOIN CTE_ZVSD e
    ON a.matnr = e.ZPNO AND b.vtweg = e.VTWEG
LEFT JOIN CTE_SKU sku
    ON a.matnr = sku.idnrk AND b.vtweg = sku.vtweg
WHERE a.BSART = 'ZR07' 
  AND a.CREATIONDATE BETWEEN '20260401' AND '20260428' 
  AND a.LOEKZ = ''
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8;