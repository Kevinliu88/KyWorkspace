SELECT a~werks a~vtweg a~zseq a~zportalno a~idnrk a~loekz a~qq a~qq_seq a~matnr a~req_date

a~zportalno_qty a~mnglg a~menge a~meins a~beskz a~sobsl a~mstae a~stock_qty a~extra_sup

a~bmeng a~zmoq a~moq_qty a~moq_remain a~moq_7day_req a~moq_confirm

a~netpr a~waers a~sales_waers a~sales_netpr a~sales_netpr_6 a~sales_amt

a~out_qty a~prod a~ebeln a~qq_ori

a~wl2_thenameoftheerp a~wl2_erpspecification a~zdefault_vendor a~vendor_name1 a~plifz

a~wl2_englishspecifications a~skuitem a~fevor a~txt_fevor

a~erdat AS erdat_a b~zapropd AS zapropd_b

a~ertim a~ernam a~qq_status a~chdat a~chtim a~chnam a~moq_period

a~vbeln a~posnr a~remark_pur a~remark_pp a~remark_del

a~netpr_cny a~waers_cny a~netpr_twd a~waers_twd a~zind01

FROM ztcx0001 AS a

INNER JOIN ztsd0028 AS b

ON a~vbeln    = b~vbeln

AND b~zvsnmr_v = '000'

WHERE a~erdat         BETWEEN '20260408' AND '20260430'

AND a~qq            <> ''

AND a~qq_status     <> 'C'

AND a~loekz         = ''

AND a~moq_qty       > 0

AND a~vbeln         <> ''

AND ( a~zind01      = '' OR a~zind01 = 'C' )

AND a~zxqno         = ''

AND a~sales_netpr_6 = 0

AND a~qq NOT IN ( SELECT DISTINCT qq FROM ztcx0001

WHERE erdat <  '20250501'

AND qq    <> ''

AND loekz <> 'X'

)

ORDER BY a~vtweg a~qq a~idnrk
 