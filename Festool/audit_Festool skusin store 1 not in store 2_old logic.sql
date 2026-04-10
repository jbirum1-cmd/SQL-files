drop table if exists #st2
select
trim(in_item_number) as sku,
in_store,
in_manufacturer,
in_quantity_on_hand,
in_discontinued,
inx_store_closeout_flag
into #st2
from hh.view_in_clone
where in_manufacturer = 'fest' and in_store = '2' and trim(in_item_number) not like '%zz%' and ((in_discontinued not in ('Y') and inx_store_closeout_flag not in ('Y')) or in_quantity_on_hand > 0)

drop table if exists #st1
select
trim(in_item_number) as sku,
in_store,
in_manufacturer,
in_quantity_on_hand,
in_discontinued,
inx_store_closeout_flag
into #st1
from hh.view_in_clone
where in_manufacturer = 'fest' and in_store = '1' and trim(in_item_number) not like '%zz%' and (in_discontinued <> 'Y' OR inx_store_closeout_flag <> 'Y') 

select
st1.sku,
st1.in_store,
st1.in_manufacturer,
st1.in_quantity_on_hand,
st1.in_discontinued,
st1.inx_store_closeout_flag
from #st1 st1
left join #st2 st2
on st1.sku = st2.sku
where st2.sku is null

