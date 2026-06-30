/*ZXQ07-單顆長交期預採_202602*/
select      a.werks,
            b.vtweg,
            (select kunnr from ZTCX0008A x where b.vtweg = x.vtweg) customer_1,
            (select kunnr from ZTCX0008A x where b.vtweg = x.vtweg) customer_2,
            a.CREATIONDATE,
            case when b.vtweg = 'G1' then 'USA' else 'GLOBAL' end ZXQLINE,
            1 Class_1,
            e.ZUNPTYP,
            case when e.zcpno <> '' then e.zcpno
                 else (select max(x.SKUITEM) from ztcx0001 x where a.matnr = x.idnrk and b.vtweg = x.vtweg) end as zcpno,
            case when e.ZCPNOCN <> '' then e.ZCPNOCN
                 else (select max(x.SKUITEM) from ztcx0001 x where a.matnr = x.idnrk and b.vtweg = x.vtweg) end as ZCPNOCN,
            e.ZDESC_H,
            a.BANFN||'-'||a.BNFPO PR_SEQ,
            a.matnr,
            '' matnr_like,
            'X' ZTUNYN,
            e.ZUNPTYP class_2,
            a.menge,
            case when e.ZBQTY is not null then e.ZBQTY
                 else (select max(x.MNGLG) from ztcx0001 x where a.matnr = x.idnrk and b.vtweg = x.vtweg) end as ZBQTY,
            case when d.WAERS is not null then d.WAERS else a.WAERS end WAERS,
            case when c.NETPR is not null then c.NETPR /c.PEINH else a.PREIS/a.PEINH end unit_price,
            a.ZZBPMNUMBER||'-'||a.ZZBPMNUMITEM BPM_SEQ,
            c.EBELN||'-'||c.EBELP PO_SEQ
from eban a
inner join tvtwt b
                 on a.mandt = b.mandt
                and b.spras = 'M'
                and upper(b.vtext) like a.zzcustomer||'%' /**/
left outer join EKPO c
                on a.EBELN = c.EBELN
                and a.EBELP = c.EBELP
left outer JOIN EKKO d
                ON a.EBELN = d.EBELN
left outer join (select a.zxqno,
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
                 from zvsd0003 a
                 inner join (select vtweg, zpno, max(zxqno) zxqno from zvsd0003 where ZUNPTYP between '6' and 'W' group by vtweg, zpno
                                ) b
                         on a.zxqno = b.zxqno
                        and a.vtweg = b.vtweg
                        and a.zpno = b.zpno
                  ) e
                on a.matnr = e.ZPNO
                and b.vtweg = e.VTWEG
where a.BSART = 'ZR07' and a.CREATIONDATE between '20260201' and '20260228' and a.LOEKZ = ''
order by 1,2,3,4,5,6,7,8