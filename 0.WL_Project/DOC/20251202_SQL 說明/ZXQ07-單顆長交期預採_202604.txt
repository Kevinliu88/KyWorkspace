/*ZXQ07-單顆長交期預採_202602 改進版*/
WITH 
-- 1. 預處理客戶對照表，解決可能的多筆資料導致報錯問題
CTE_Customer AS (
    SELECT vtweg, MAX(kunnr) as kunnr
    FROM ZTCX0008A
    GROUP BY vtweg
),
 
-- 2. 預處理物料主檔對照表
CTE_SKU AS (
    SELECT vtweg, idnrk, MAX(SKUITEM) as SKUITEM, MAX(MNGLG) as MNGLG
    FROM ztcx0001
    GROUP BY vtweg, idnrk
),
 
-- 3. 處理 ZVSD0003 的複雜過濾邏輯
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
    CASE WHEN b.vtweg = 'G1' THEN 'USA' ELSE 'GLOBAL' END AS ZXQLINE,
    1 AS Class_1,
    e.ZUNPTYP,
    CASE 
        WHEN e.zcpno IS NOT NULL AND e.zcpno <> '' THEN e.zcpno
        ELSE sku.SKUITEM 
    END AS zcpno,
    CASE 
        WHEN e.ZCPNOCN IS NOT NULL AND e.ZCPNOCN <> '' THEN e.ZCPNOCN
        ELSE sku.SKUITEM 
    END AS ZCPNOCN,
    e.ZDESC_H,
    a.BANFN || '-' || a.BNFPO AS PR_SEQ,
    a.matnr,
    '' AS matnr_like,
    'X' AS ZTUNYN,
    e.ZUNPTYP AS class_2,
    a.menge,
    CASE WHEN e.ZBQTY IS NOT NULL THEN e.ZBQTY ELSE sku.MNGLG END AS ZBQTY,
    COALESCE(d.WAERS, a.WAERS) AS WAERS,
    CASE 
        WHEN c.NETPR IS NOT NULL THEN c.NETPR / NULLIF(c.PEINH, 0) 
        ELSE a.PREIS / NULLIF(a.PEINH, 0) 
    END AS unit_price,
    a.ZZBPMNUMBER || '-' || a.ZZBPMNUMITEM AS BPM_SEQ,
    c.EBELN || '-' || c.EBELP AS PO_SEQ
FROM eban a
-- 建議：若懷疑這裡過濾掉資料，可先改為 LEFT JOIN 觀察
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
  -- 若要指定特定 PR 測試，取消下行註解
  -- AND a.BANFN = '1003881324'
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8;