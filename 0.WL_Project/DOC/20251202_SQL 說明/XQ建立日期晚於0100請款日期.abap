select a.zxqno, a.zxqseq, b.ZDCNO, a.ZOPD_NEW CREATION_V003, b.ZOPD_NEW CREATION_0100, a.*, b.* from zvsd0003 a
inner join ztsd0101 b on a.mandt = b.mandt and a.zxqno = b.zxqno and a.zxqseq = b.zxqseq
where a.zym > '202506' 
--and (a.ZXQSTA <> '8' or a.ZXQWRKTYP <> '8')
and a.ZOPD_NEW > b.ZOPD_NEW
order by a.ZOPD_NEW DESC,1,2,3