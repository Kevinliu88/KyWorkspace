SELECT '系統轉出否' AS TYPE,
    a.VTWEG,
    a.WERKS, 
    a.ZPNO, 
    a.ZXQWRKTYP as Status,
    a.ZDAT ,
    a.ZXQDTYP as Class,
--  a.ZXQWRKTYP,
    a.ZXQNO,
    a.ZXQSEQ,
    a.ZTUNYN,
    c.STRGR
FROM ZTSD0099 a
INNER JOIN marc c ON a.werks = c.werks AND a.ZPNO = c.matnr and a.MANDT = c.MANDT
WHERE a.zdat BETWEEN '20250101' AND '20260518'
  AND a.ZTUNYN = 'X'
  -- 加上物料開頭篩選條件
  AND (a.ZPNO LIKE 'A0501%' OR a.ZPNO LIKE 'A0502%' OR ZPNO LIKE 'A0606%' OR ZPNO LIKE 'A0613%')
  AND c.STRGR =  '20'
  AND a.MANDT = '301'
  AND a.ZXQWRKTYP <> '8'
Order by a.WERKS,a.VTWEG,a.ZXQNO,a.ZXQSEQ