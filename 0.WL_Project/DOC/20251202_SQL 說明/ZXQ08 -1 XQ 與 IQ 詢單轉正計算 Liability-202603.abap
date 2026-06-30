WITH CTE_ZTCX AS (
    -- 先將複雜的聚合與邏輯預處理出來
    SELECT 
        c.VTWEG,
        c.IDNRK,
        sum(c.menge) SUM_MENGE
    FROM ZTCX0001 c
    JOIN ztsd0028 s2 ON c.VBELN = s2.VBELN AND s2.ZVSNMR_V = 0
    WHERE c.VBELN <> '' 
      AND c.LOEKZ = ''
      -- 這裡將您的日期邏輯過濾條件放入
      AND CASE WHEN c.ERDAT > s2.ZAPROPD THEN c.ERDAT ELSE s2.ZAPROPD END BETWEEN '20260301' AND '20260331'
    GROUP BY c.VTWEG, c.IDNRK
)
/* 上半段查詢 */
SELECT a.VTWEG,
       a.ZPNO,
       a.VTWEG || '_' || a.ZPNO AS VTWEG_ZPNO,
       a.zxqdat,
       a.zunptyp,
       a.zqtybalace,
       a.ZMOQty,
       (SELECT SUM_MENGE FROM CTE_ZTCX t WHERE t.VTWEG = a.VTWEG AND t.IDNRK = a.ZPNO) AS sum_MENGE
FROM ZVSD0003 a
WHERE a.zqtybalace > 0
  AND (a.zym < '202603' OR (a.zunptyp <> '2' AND a.zym = '202603'))
  AND a.VTWEG IN ('G1')
  AND a.ZTUNYN = 'X'
  AND a.ZXQWRKTYP <> 8 
  AND a.ZXQSTA <> '8'
 
UNION ALL
 
/* 下半段查詢：直接關聯 CTE */
SELECT a.VTWEG,
       a.IDNRK,
       a.VTWEG || '_' || a.IDNRK AS VTWEG_ZPNO,
       (CASE WHEN a.ERDAT > s.ZAPROPD THEN a.ERDAT ELSE s.ZAPROPD END) AS ERDAT,
       'IQ 轉正' AS zunptyp,
       -a.MENGE MENGE,
       a.zmoq,
       t.SUM_MENGE
FROM ZTCX0001 a
INNER JOIN ztsd0028 s ON a.VBELN = s.VBELN AND s.ZVSNMR_V = 0
LEFT JOIN CTE_ZTCX t ON a.VTWEG = t.VTWEG AND a.IDNRK = t.IDNRK
WHERE 
      (CASE WHEN a.ERDAT > s.ZAPROPD THEN a.ERDAT ELSE s.ZAPROPD END) BETWEEN '20260301' AND '20260331'
  AND a.VBELN <> '' 
  AND a.LOEKZ = ''
  AND a.VTWEG IN ('G1')
  AND EXISTS (
      SELECT 1 FROM ZVSD0003 b 
      WHERE b.VTWEG = a.VTWEG AND b.ZPNO = a.IDNRK AND b.zqtybalace > 0 
  )
ORDER BY 1, 2, 3, 4, 5;