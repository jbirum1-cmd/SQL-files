--gets kit skus for exclusion
drop table if exists #kits
select
sku
into #kits
from titan.live.dbo.kitting

--gets all Eagle skus that meet file criteria
drop table if exists #eagleskus
select
replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','') as sku
into #eagleskus
from sqleagle.hh.view_in_clone v
where v.in_privatefromecommercefg in ('C','O','N') and v.in_store IN ('1','2','4','7','8','12','18')
and not exists (
    select 1
	from #kits k
	where k.sku = trim(v.in_item_number))

--gets all existing Akeneo skus with a source of Eagle
drop table if exists #akeneoskus
select
trim(sku) as sku
into #akeneoskus
from integration.pim.allproductstable 
where core_product_data_source in ('eagle')

--unions both sources together and drops dups
drop table if exists #allskus
select *
into #allskus
from #eagleskus

union

select *
from #akeneoskus

--joins final sku list back to eagle to pull discontinued and close out data. This way, if products exist in Akeneo and not Eagle, we can still flag them
drop table if exists #eagledata
select
a.sku,
v.in_store,
v.in_discontinued,
v.inx_store_closeout_flag
into #eagledata
from #allskus a
left join sqleagle.hh.view_in_clone v
on a.sku = replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','')
where in_privatefromecommercefg in ('C','O','N') and in_store IN ('1','2','4','7','8','12','18')

--store locations with discontinued items
drop table if exists #discont
select
sku,
in_store,
in_discontinued
into #discont
from #eagledata
where in_discontinued = 'Y'

--store locations with closeouts
drop table if exists #closeout
select
sku,
in_store,
inx_store_closeout_flag
into #closeout
from #eagledata
where inx_store_closeout_flag = 'Y'

--creates string
drop table if exists #discontstr
select 
sku,
STRING_AGG(CAST(in_store AS varchar(10)), ',') 
        WITHIN GROUP (ORDER BY in_store) AS discontinued
into #discontstr
from #discont
group by sku

drop table if exists #closeoutstr
select 
sku,
STRING_AGG(CAST(in_store AS varchar(10)), ',') 
        WITHIN GROUP (ORDER BY in_store) AS closeout
into #closeoutstr
from #closeout
group by sku

--combines discontinued and closeout data
drop table if exists #combined
select
e.sku,
d.discontinued,
c.closeout
into #combined
from #eagledata e
left join #discontstr d
on e.sku = d.sku
left join #closeoutstr c
on e.sku = c.sku

--pulls in comparison fields
drop table if exists #compare
select
c.sku as eagle_sku,
p.sku as akeneo_sku,
isnull(c.discontinued,0) as eagle_discontinued,
isnull(c.closeout, 0) as eagle_closeout,
isnull(replace(replace(replace(p.discontinued, '[',''),']',''),'"',''),0) as akeneo_discontinued,
isnull(replace(replace(replace(p.store_closeout, '[',''),']',''),'"',''),0) as akeneo_closeout
into #compare
from #combined c
left join pim.allproductstable p
on c.sku = p.sku

--displays discrepancies
select distinct
eagle_sku,
akeneo_sku,
eagle_discontinued,
akeneo_discontinued,
case when
    eagle_discontinued = akeneo_discontinued
    then 'true'
    else 'false'
    end as discont_compare,
eagle_closeout,
akeneo_closeout,
case when
    eagle_closeout = akeneo_closeout
    then 'true'
    else 'false'
    end as closeout_compare
from #compare
where 
(case when
    eagle_discontinued = akeneo_discontinued
    then 'true'
    else 'false'
    end = 'false') 
    or
(case when
    eagle_closeout = akeneo_closeout
    then 'true'
    else 'false'
    end = 'false')
