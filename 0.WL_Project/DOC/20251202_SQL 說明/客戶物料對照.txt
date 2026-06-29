select a.vtweg, 
    a.kunnr,
    a.zcpno SKU,
    a.zcn model,
    m.mtart
from ztsd0020 a
inner join mara m on a.matnr = m.matnr
where a.mandt = '301' and a.vtweg = 'G1'