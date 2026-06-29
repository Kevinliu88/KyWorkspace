[EKKN]
MANDT | MANDT | CLNT | 000003 | 000000 | Client
EBELN | EBELN | CHAR | 000010 | 000000 | Purchasing Document Number
EBELP | EBELP | NUMC | 000005 | 000000 | Item Number of Purchasing Document
ZEKKN | DZEKKN | NUMC | 000002 | 000000 | Sequential Number of Account Assignment
LOEKZ | KLOEK | CHAR | 000001 | 000000 | Deletion Indicator: Purchasing Document Account Assignment
AEDAT | ERDAT | DATS | 000008 | 000000 | Record Created On
KFLAG | EFLAG | CHAR | 000001 | 000000 | Change flag: Purchasing (currently not used)
MENGE | MENGE_D | QUAN | 000013 | 000003 | Quantity
VPROZ | VPROZ | DEC | 000003 | 000001 | Distribution percentage in the case of multiple acct assgt
NETWR | BWERT | CURR | 000013 | 000002 | Net Order Value in PO Currency
SAKTO | SAKNR | CHAR | 000010 | 000000 | G/L Account Number
GSBER | GSBER | CHAR | 000004 | 000000 | Business Area
KOSTL | KOSTL | CHAR | 000010 | 000000 | Cost Center
PROJN | PROJN | CHAR | 000016 | 000000 | Old: Project number : No longer used --> PS_POSNR
VBELN | VBELN_CO | CHAR | 000010 | 000000 | Sales and Distribution Document Number
VBELP | POSNR_CO | NUMC | 000006 | 000000 | Sales Document Item
VETEN | ETENR | NUMC | 000004 | 000000 | Schedule Line Number
KZBRB | KZBRB | CHAR | 000001 | 000000 | Gross requirements indicator
ANLN1 | ANLN1 | CHAR | 000012 | 000000 | Main Asset Number
ANLN2 | ANLN2 | CHAR | 000004 | 000000 | Asset Subnumber
AUFNR | AUFNR | CHAR | 000012 | 000000 | Order Number
WEMPF | WEMPF | CHAR | 000012 | 000000 | Goods Recipient
ABLAD | ABLAD | CHAR | 000025 | 000000 | Unloading Point
KOKRS | KOKRS | CHAR | 000004 | 000000 | Controlling Area
XBKST | XBKST | CHAR | 000001 | 000000 | Posting to cost center?
XBAUF | XBAUF | CHAR | 000001 | 000000 | Post To Order
XBPRO | XBPRO | CHAR | 000001 | 000000 | Post to project
EREKZ | EREKZ | CHAR | 000001 | 000000 | Final Invoice Indicator
KSTRG | KSTRG | CHAR | 000012 | 000000 | Cost Object
PAOBJNR | RKEOBJNR | NUMC | 000010 | 000000 | Profitability Segment Number (CO-PA)
PRCTR | PRCTR | CHAR | 000010 | 000000 | Profit Center
PS_PSP_PNR | PS_PSP_PNR | NUMC | 000008 | 000000 | Work Breakdown Structure Element (WBS Element)
NPLNR | NPLNR | CHAR | 000012 | 000000 | Network Number for Account Assignment
AUFPL | CO_AUFPL | NUMC | 000010 | 000000 | Routing number of operations in the order
IMKEY | IMKEY | CHAR | 000008 | 000000 | Internal Key for Real Estate Object
APLZL | CIM_COUNT | NUMC | 000008 | 000000 | Internal counter
VPTNR | JV_PART | CHAR | 000010 | 000000 | Partner account number
FIPOS | FIPOS | CHAR | 000014 | 000000 | Commitment Item
RECID | JV_RECIND | CHAR | 000002 | 000000 | Recovery Indicator
SERVICE_DOC_TYPE | FCO_SRVDOC_TYPE | CHAR | 000004 | 000000 | Service Document Type
SERVICE_DOC_ID | FCO_SRVDOC_ID | CHAR | 000010 | 000000 | Service Document ID
SERVICE_DOC_ITEM_ID | FCO_SRVDOC_ITEM_ID | NUMC | 000006 | 000000 | Service Document Item ID
DUMMY_INCL_EEW_COBL | CFD_DUMMY | CHAR | 000001 | 000000 | Custom Fields: Dummy for Use in Extension Includes
FISTL | FISTL | CHAR | 000016 | 000000 | Funds Center
GEBER | BP_GEBER | CHAR | 000010 | 000000 | Fund
FKBER | FKBER | CHAR | 000016 | 000000 | Functional Area
DABRZ | DABRBEZ | DATS | 000008 | 000000 | Reference date for settlement
AUFPL_ORD | CO_AUFPL | NUMC | 000010 | 000000 | Routing number of operations in the order
APLZL_ORD | CO_APLZL | NUMC | 000008 | 000000 | General counter for order
MWSKZ | MWSKZ | CHAR | 000002 | 000000 | Tax on sales/purchases code
TXJCD | TXJCD | CHAR | 000015 | 000000 | Tax Jurisdiction
NAVNW | NAVNW | CURR | 000013 | 000002 | Non-deductible input tax
KBLNR | KBLNR | CHAR | 000010 | 000000 | Document Number for Earmarked Funds
KBLPOS | KBLPOS | NUMC | 000003 | 000000 | Earmarked Funds: Document Item
LSTAR | LSTAR | CHAR | 000006 | 000000 | Activity Type
PRZNR | CO_PRZNR | CHAR | 000012 | 000000 | Business Process
GRANT_NBR | GM_GRANT_NBR | CHAR | 000020 | 000000 | Grant
BUDGET_PD | FM_BUDGET_PERIOD | CHAR | 000010 | 000000 | Budget Period
FM_SPLIT_BATCH | FMSP_SPLIT_BATCH | NUMC | 000003 | 000000 | Batch to group results from an PSM assignment distribution
FM_SPLIT_BEGRU | FMSP_SPLIT_AUTG | CHAR | 000004 | 000000 | Authorization Group for PSM Account Assignment Distribution
AA_FINAL_IND | AA_FINAL_IND | CHAR | 000001 | 000000 | Final Account Assignment Indicator
AA_FINAL_REASON | AA_FINAL_REASON | CHAR | 000002 | 000000 | Final Account Assignment Reason Code
AA_FINAL_QTY | AA_FINAL_QTY | QUAN | 000013 | 000003 | Final Account Assignment Quantity
AA_FINAL_QTY_F | AA_FINAL_QTY_F | FLTP | 000016 | 000016 | Final Account Assignment Quantity (Floating Point Number)
MENGE_F | MENGE_F | FLTP | 000016 | 000016 | Quantity (Floating Point Number - Internal Field)
FMFGUS_KEY | FMFG_US_KEY | CHAR | 000022 | 000000 | United States Federal Government Fields
_DATAAGING | DATA_TEMPERATURE | DATS | 000008 | 000000 | Data Filter Value for Data Aging
EGRUP | JV_EGROUP | CHAR | 000003 | 000000 | Equity group
VNAME | JV_NAME | CHAR | 000006 | 000000 | Joint venture
KBLNR_CAB | REFPRECOM | CHAR | 000010 | 000000 | Referenced Funds Precommitment
KBLPOS_CAB | REFPREPOS | NUMC | 000003 | 000000 | Item in Referenced Funds Precommitment
TCOBJNR | J_OBJNR | CHAR | 000022 | 000000 | Object number
DATEOFSERVICE | VVBEACTDATE | DATS | 000008 | 000000 | Date of Service
NOTAXCORR | VVREITNOTAXCORR | CHAR | 000001 | 000000 | Do Not Consider Item in Input Tax Correction
DIFFOPTRATE | POPTSATZ | DEC | 000009 | 000006 | Real Estate Option Rate
HASDIFFOPTRATE | VVREITUSEDIFFOPTRATE | CHAR | 000001 | 000000 | Use Different Option Rate
