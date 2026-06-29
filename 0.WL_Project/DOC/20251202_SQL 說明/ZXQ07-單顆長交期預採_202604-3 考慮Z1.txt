/*ZXQ07-單顆長交期預採_202602 改進版*/
WITH 
-- 1. 預處理客戶對照表，解決可能的多筆資料導致報錯問題
CTE_Customer AS (
    SELECT vtweg, MAX(kunnr) AS kunnr
    FROM ZTCX0008A
    GROUP BY vtweg
),

-- 2. 預處理物料主檔對照表
CTE_SKU AS (
    SELECT vtweg, idnrk, MAX(SKUITEM) AS SKUITEM, MAX(MNGLG) AS MNGLG
    FROM ztcx0001
    GROUP BY vtweg, idnrk
),

-- 3. 處理 ZVSD0003 的複雜過濾邏輯
CTE_ZVSD AS (
    SELECT a.*
    FROM zvsd0003 a
    INNER JOIN (
        SELECT vtweg, zpno, MAX(zxqno) AS zxqno 
        FROM zvsd0003 
        WHERE ZUNPTYP BETWEEN '6' AND 'W' 
        GROUP BY vtweg, zpno
    ) b ON a.zxqno = b.zxqno AND a.vtweg = b.vtweg AND a.zpno = b.zpno
)

-- 4. 主查詢
SELECT 
    a.werks,
    -- [NEW] 找不到對應通路時，預設為 'Z1'
    COALESCE(b.vtweg, 'Z1')                                          AS vtweg,
    cust.kunnr                                                        AS customer_1,
    cust.kunnr                                                        AS customer_2,
    a.CREATIONDATE,
    -- [NEW] vtweg 預設 Z1 後，ZXQLINE 也能正確對應
    CASE WHEN COALESCE(b.vtweg, 'Z1') = 'G1' THEN 'USA' ELSE 'GLOBAL' END AS ZXQLINE,
    1                                                                 AS Class_1,
    e.ZUNPTYP,
    CASE 
        WHEN e.zcpno IS NOT NULL AND e.zcpno <> ' ' THEN e.zcpno
        ELSE sku.SKUITEM 
    END AS zcpno,
    CASE 
        WHEN e.ZCPNOCN IS NOT NULL AND e.ZCPNOCN <> ' ' THEN e.ZCPNOCN
        ELSE sku.SKUITEM 
    END AS ZCPNOCN,
    e.ZDESC_H,
    CONCAT(CONCAT(a.BANFN, '-'), a.BNFPO)                            AS PR_SEQ,
    a.matnr,
    ''                                                                AS matnr_like,
    'X'                                                               AS ZTUNYN,
    e.ZUNPTYP                                                         AS class_2,
    a.menge,
    CASE WHEN e.ZBQTY IS NOT NULL THEN e.ZBQTY ELSE sku.MNGLG END    AS ZBQTY,
    COALESCE(d.WAERS, a.WAERS)                                        AS WAERS,
    CASE 
        WHEN c.NETPR IS NOT NULL THEN c.NETPR / NULLIF(c.PEINH, 0) 
        ELSE a.PREIS / NULLIF(a.PEINH, 0) 
    END AS unit_price,
    CONCAT(CONCAT(a.ZZBPMNUMBER, '-'), a.ZZBPMNUMITEM)               AS BPM_SEQ,
    CONCAT(CONCAT(c.EBELN, '-'), c.EBELP)                            AS PO_SEQ

FROM eban a

-- [NEW] 改為 LEFT JOIN：ZZCUSTOMER 在 TVTWT 找不到對應時，
--       該 PR 仍保留，vtweg 會是 NULL，後續由 COALESCE 補 'Z1'
LEFT JOIN tvtwt b
    ON  a.mandt        = b.mandt
    AND b.spras        = 'M'
    AND UPPER(b.vtext) LIKE CONCAT(RTRIM(UPPER(a.zzcustomer)), '%')

LEFT JOIN CTE_Customer cust
    -- [NEW] vtweg 為 NULL 時用 'Z1' 去查客戶對照表
    ON COALESCE(b.vtweg, 'Z1') = cust.vtweg

LEFT JOIN EKPO c
    ON  a.EBELN = c.EBELN 
    AND a.EBELP = c.EBELP

LEFT JOIN EKKO d
    ON  a.EBELN = d.EBELN

LEFT JOIN CTE_ZVSD e
    -- [NEW] 同上，vtweg 為 NULL 時用 'Z1'
    ON  a.matnr                  = e.ZPNO 
    AND COALESCE(b.vtweg, 'Z1')  = e.VTWEG

LEFT JOIN CTE_SKU sku
    -- [NEW] 同上
    ON  a.matnr                  = sku.idnrk 
    AND COALESCE(b.vtweg, 'Z1')  = sku.vtweg

WHERE a.BSART = 'ZR07' 
  AND a.CREATIONDATE BETWEEN '20260401' AND '20260428' 
  AND (a.LOEKZ IS NULL OR a.LOEKZ = ' ')
  -- 若要指定特定 PR 測試，取消下行註解
  --AND a.BANFN = '1003881324'

ORDER BY 1, 2, 3, 4, 5, 6, 7, 8;