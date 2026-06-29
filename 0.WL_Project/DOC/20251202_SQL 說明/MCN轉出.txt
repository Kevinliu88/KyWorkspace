SELECT 'MCN轉XQ' TYPE,
	  a.VTWEG,
        a.ZPNO,
        a.VTWEG || '-' || a.ZPNO VTWEG_ZPNO,
        a.zxqdat,
	a.ZXQWRKTYP XQ_STATUS,
        a.zunptyp,
	  a.zqty,
        a.zqtybalace,
	  a.zup,
	  a.ZUP_PER,
        a.zxqno,
        a.zxqseq

from ZVSD0003 a
where a.mandt = '301' 
and a.ZUNPTYP = '3'
and a.ZQTYBALACE > 0

	
