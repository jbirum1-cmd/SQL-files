drop table if exists #st4
select 
trim(in_item_number) as sku,
in_store,
in_quantity_on_hand,
in_discontinued,
in_privatefromecommercefg
into #st4
from hh.view_in_clone
where in_store = '4' 

select 
trim(v.in_item_number) as sku,
v.in_store,
v.in_quantity_on_hand,
v.in_discontinued,
v.in_privatefromecommercefg
from hh.view_in_clone v
where v.in_store = '1' and v.in_quantity_on_hand > 0 and v.in_discontinued = 'N' and v.in_privatefromecommercefg in ('C','O','N') and
not exists (
	select 1
	from #st4 s
	where s.sku = trim(in_item_number)
	)

