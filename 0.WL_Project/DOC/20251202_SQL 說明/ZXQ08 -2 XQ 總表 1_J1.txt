/* XQ 單總表  */

select  
        a.VTWEG,
        a.ZYM,
        a.ZXQno,
        b.ZXQSEQ,
        a.ZBCUST,
        a.Zunptyp,
        b.ZPNO,
        a.VTWEG ||'_' || b.ZPNO VTWEG_ZPNO,
        b.ZDAT,
        b.ZQTY,
        b.ZQTYBALACE,
        a.werks
from ZTSD0098 a
inner join ZTSD0099 b    on a.mandt = b.mandt 
                        and a.ZXQNO = b.ZXQNO 
                        and b.ZQTYBALACE > 0 
                        and a.vtweg = b.vtweg
                        and b.ZTUNYN = 'X'
                        and b.ZXQWRKTYP <> 8 and a.ZXQSTA <>'8'
where a.vtweg in ('C1','J1')
order by a.VTWEG, b.ZPNO, b.ZDAT desc, a.ZXQno DESC, b.ZXQSEQ DESC
