drop table if exists #tmpShopfiySkus
drop table if exists #tmpNoAlias
drop table if exists #tmpNoSkus
select top 1000 sku into #tmpShopfiySkus from Integration.inv.Shopifyvariants
select trim(sku) as sku into #tmpNoAlias from NaturalOrder.syn_CATALOG_ALIAS n where n.CATALOG_ID IN ('MASTER13', 'LEHMASTER', 'HHMASTER','MFMASTER')
select trim(sku) as sku into #tmpNoSkus from NaturalOrder.syn_CATALOG_ITEMS i where i.CATALOG_ID IN ('MASTER13', 'LEHMASTER', 'HHMASTER','MFMASTER')

select sku from #tmpShopfiySkus s
where not exists (select 1 from #tmpNoAlias a where s.sku = a.sku) and not exists (select 1 from #tmpNoSkus i where s.sku = i.sku)

Declare @IsSkuExist INT = 0
Declare @Sku varchar(14) = '1737677'
IF(EXISTS(select sku from NaturalOrder.syn_CATALOG_ALIAS Where CATALOG_ID IN ('MASTER13', 'LEHMASTER', 'HHMASTER','MFMASTER') and CATALOG_ALIAS = @Sku)) 
BEGIN 
SET @IsSkuExist = 1
END
IF(EXISTS(select sku from NaturalOrder.syn_CATALOG_ITEMS Where CATALOG_ID IN ('MASTER13', 'LEHMASTER', 'HHMASTER','MFMASTER') and sku= @Sku) AND @IsSkuExist=0) 
BEGIN 
SET @IsSkuExist = 1
END
SELECT @IsSkuExist as IsSkuExist