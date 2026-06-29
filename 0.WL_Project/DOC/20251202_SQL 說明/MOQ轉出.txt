SELECT 'MOQ轉XQ' TYPE,
	  a.VTWEG,
        a.ZPNO,
        a.VTWEG || '-' || a.ZPNO VTWEG_ZPNO,
        a.zxqdat,
        a.zunptyp,
	  a.zqty,
        a.zqtybalace,
	  a.zup,
	  a.ZUP_PER,
        a.zxqno,
        a.zxqseq

from ZVSD0003 a
where a.mandt = '301' 
and a.ZUNPTYP = '2'
and a.zxqdat >= '20250601'

	
