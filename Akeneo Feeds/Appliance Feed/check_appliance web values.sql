--get max update date record
drop table if exists #maxupdate
select
sku,
max(isnull(updatedate,insertdate)) as max_update_date
into #maxupdate
from titan.integration.dbo.centerspecappliances
group by sku

--create string
drop table if exists #string
select distinct
t.sku,
t.obsoletedate,
STRING_AGG(CAST(v.in_privatefromecommercefg AS varchar(10)), ',') 
        WITHIN GROUP (ORDER BY v.in_privatefromecommercefg) AS string_in_privatefromecommercefg
into #string
from titan.integration.dbo.centerspecappliances t
join #maxupdate m
on m.sku = t.sku and m.max_update_date = coalesce(t.updatedate,t.insertdate)
left join sqleagle.hh.view_in_clone v
on t.sku = trim(v.in_item_number) and in_store in ('1','2','4')
group by t.sku, t.obsoletedate


--determine web value
drop table if exists #webvalue
select
s.sku,
s.obsoletedate,
s.string_in_privatefromecommercefg,
case when 
	s.obsoletedate is not null
	then 'false'
	else
		case when
		s.string_in_privatefromecommercefg like '%C%' or s.string_in_privatefromecommercefg like '%N%' or s.string_in_privatefromecommercefg like '%O%'
		then 'true'
		when s.string_in_privatefromecommercefg is null
		then 'true'
		else 'false'
		end
	end as web_calculated
into #webvalue
from #string s

--compare
select
a.identifier,
w.obsoletedate,
w.string_in_privatefromecommercefg,
w.web_calculated,
a.web_website_hartville,
case when
	w.web_calculated = a.web_website_hartville
	then 'true'
	else 'false'
	end as web_check
from integration.pim.allproductstable a
join #webvalue w
on a.identifier = w.sku
where
case when
	w.web_calculated = a.web_website_hartville
	then 'true'
	else 'false'
	end = 'false'


