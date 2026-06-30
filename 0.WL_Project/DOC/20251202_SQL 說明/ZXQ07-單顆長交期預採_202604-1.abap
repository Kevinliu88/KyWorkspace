/*ZXQ07-單顆長交期預採_202602*/
SELECT
    a.werks,
    b.vtweg,
    (SELECT kunnr FROM ZTCX0008A x WHERE b.vtweg = x.vtweg) AS customer_1,
    (SELECT kunnr FROM ZTCX0008A x WHERE b.vtweg = x.vtweg) AS customer_2,
    a.CREATIONDATE,
    CASE WHEN b.vtweg = 'G1' THEN 'USA' ELSE 'GLOBAL' END AS ZXQLINE,
    1                                                        AS Class_1,
    e.ZUNPTYP,
    CASE
        WHEN e.zcpno IS NOT NULL AND e.zcpno <> ' '
        THEN e.zcpno
        ELSE (SELECT MAX(x.SKUITEM) FROM ztcx0001 x WHERE a.matnr = x.idnrk AND b.vtweg = x.vtweg)
    END AS zcpno,
    CASE
        WHEN e.ZCPNOCN IS NOT NULL AND e.ZCPNOCN <> ' '
        THEN e.ZCPNOCN
        ELSE (SELECT MAX(x.SKUITEM) FROM ztcx0001 x WHERE a.matnr = x.idnrk AND b.vtweg = x.vtweg)
    END AS ZCPNOCN,
    e.ZDESC_H,
    CONCAT(CONCAT(a.BANFN, '-'), a.BNFPO)                   AS PR_SEQ,
    a.matnr,
    ''                                                        AS matnr_like,
    'X'                                                       AS ZTUNYN,
    e.ZUNPTYP                                                 AS class_2,
    a.menge,
    CASE
        WHEN e.ZBQTY IS NOT NULL
        THEN e.ZBQTY
        ELSE (SELECT MAX(x.MNGLG) FROM ztcx0001 x WHERE a.matnr = x.idnrk AND b.vtweg = x.vtweg)
    END AS ZBQTY,
    CASE WHEN d.WAERS IS NOT NULL THEN d.WAERS ELSE a.WAERS END AS WAERS,
    CASE WHEN c.NETPR IS NOT NULL THEN c.NETPR / c.PEINH ELSE a.PREIS / a.PEINH END AS unit_price,
    CONCAT(CONCAT(a.ZZBPMNUMBER, '-'), a.ZZBPMNUMITEM)       AS BPM_SEQ,
    CONCAT(CONCAT(c.EBELN, '-'), c.EBELP)                    AS PO_SEQ

FROM eban a

INNER JOIN tvtwt b
    ON  a.mandt          = b.mandt
    AND b.spras          = 'M'
    AND UPPER(b.vtext)   LIKE CONCAT(a.zzcustomer, '%')

LEFT OUTER JOIN EKPO c
    ON  a.EBELN = c.EBELN
    AND a.EBELP = c.EBELP

LEFT OUTER JOIN EKKO d
    ON  a.EBELN = d.EBELN

LEFT OUTER JOIN (
    SELECT
        a.zxqno,
        a.zxqseq,
        a.vtweg,
        a.zpno,
        a.ZXQLINE,
        a.ZBCUST,
        a.zcpno,
        a.ZCPNOCN,
        a.ZUNPTYP,
        a.ZDESC,
        a.ZTUNYN,
        a.ZBQTY,
        a.ZSCUST,
        a.ZDESC_H
    FROM zvsd0003 a
    INNER JOIN (
        SELECT vtweg, zpno, MAX(zxqno) AS zxqno
        FROM zvsd0003
        WHERE ZUNPTYP BETWEEN '6' AND 'W'
        GROUP BY vtweg, zpno
    ) b
        ON  a.zxqno = b.zxqno
        AND a.vtweg = b.vtweg
        AND a.zpno  = b.zpno
) e
    ON  a.matnr  = e.ZPNO
    AND b.vtweg  = e.VTWEG

WHERE
    a.BSART        = 'ZR07'
    AND a.CREATIONDATE BETWEEN '20260401' AND '20260428'
    AND (a.LOEKZ IS NULL OR a.LOEKZ = ' ')
    -- ===================================================
    -- [DEBUG] 指定 PR 號碼篩選，正式上線前請註解此區塊
    -- 單筆：AND a.BANFN = '0010001234'
    -- 多筆：AND a.BANFN IN ('0010001234', '0010001235', '0010001236')
    -- 含項次：AND CONCAT(CONCAT(a.BANFN,'-'),a.BNFPO) = '0010001234-00010'
    AND a.BANFN IN ('0010001234', '0010001235')   -- << 改這裡
    -- ===================================================

ORDER BY 1, 2, 3, 4, 5, 6, 7, 8