SELECT 'XQ 轉出' TYPE,
a.vtweg,
b.zym ZYM_100,
a.zxqno,
a.zxqseq,
a.ZUNPTYP,
a.zpno,
b.ZPTYP,
a.vtweg||'-'||a.zpno C_PART,
b.zqty ZQTY_100,
	 b.ZSEQ，
A.SALES_PRICE_6
FROM zvsd0003 a
inner join ZTSD0100 b on a.mandt = b.mandt and a.zxqno = b.zxqno and a.zxqseq = b.zxqseq
where b.zym > '202506' and a.mandt = '301'
 
union all
 
SELECT 'IQ 轉正' AS TYPE,
a.vtweg,
LEFT(COALESCE(b.ZAPROPD, a.ERDAT), 6) AS ZYM_100,
a.ZPORTALNO AS zxqno,
a.VBELN AS zxqseq,
'CX001' AS ZUNPTYP,
a.idnrk AS zpno,
'CX001' ZPTYP,
a.vtweg||'-'||a.idnrk C_PART,
a.MENGE AS ZQTY_100,
	 '' ZSEQ,
A.SALES_PRICE_6
FROM ztcx0001 a
LEFT OUTER JOIN ztsd0028 b
ON a.mandt = b.mandt
AND a.vtweg = b.vtweg
AND a.VBELN = b.VBELN
AND b.ZVSNMR_V = '0'
WHERE 1=1
AND a.VBELN <> ''
AND a.SOBSL = ''
AND a.MENGE > 0