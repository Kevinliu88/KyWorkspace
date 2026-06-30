/* search IQ in ZTCX0001 in last period */
select distinct ZPORTALNO 
  from ztcx0001 
  where erdat between '20260101' and '20260131'
   	and vtweg in ('C1','G1')
        