/* ZXQ08 -1 XQ 與 IQ 詢單轉正計算 Liability.txt */
select  a.VTWEG,
        a.ZPNO,
        a.VTWEG || '_' || a.ZPNO VTWEG_ZPNO,
        a.zxqdat,
        a.zunptyp,
        a.zqtybalace,
        a.ZMOQty,
        (select sum(c.MENGE) from ZTCX0001 c
         where a.VTWEG = c.VTWEG and a.zpno = c.idnrk
           and (c.ERDAT between '20260201' and '20260228')
           and c.VBELN <> ''
         group by c.VTWEG, c.idnrk) sum_MENGE
from ZVSD0003 a
where a.zqtybalace >0
  and (a.zym < '202602' or (a.zunptyp <> '2' and a.zym in ('202602')))
  and a.VTWEG in ('C1','J1','B1','N1','T1')
  and a.ZTUNYN = 'X'
  and a.ZXQWRKTYP <> 8 and a.ZXQSTA <>'8'

union ALL

select  a.VTWEG,
        a.idnrk,
        a.VTWEG || '_' || a.IDNRK VTWEG_ZPNO,
        a.ERDAT,
        'IQ 轉正' zunptyp,
        -MOQ_CONFIRM,
        a.zmoq,
        (select sum(MOQ_CONFIRM) from ZTCX0001 c
         where a.VTWEG = c.VTWEG and a.idnrk = c.idnrk
           and c.ERDAT between '20260201' and '20260228'
           and c.VBELN <> ''
         group by c.VTWEG, c.idnrk) sum_MENGE
from ztcx0001 a
inner join (select distinct a.VTWEG, a.zpno from ZVSD0003 a
            where a.zqtybalace >0  ) b
            on a.VTWEG = b.VTWEG and a.idnrk = b.ZPNO
where a.ERDAT between '20260201' and '20260228'
  and a.VBELN <> ''
  and a.VTWEG in ('C1','J1','B1','N1','T1')

order by 1,2,3,4,5
