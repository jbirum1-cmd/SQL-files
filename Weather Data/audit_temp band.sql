drop table if exists #maxavgtemp
select
CAST(observationdate as date) as observationdate,
datatype,
[value]
into #maxavgtemp
from [Integration].[Weather].[HistoricalHistory]
where datatype = 'tmax'  and value >= '266.6' and observationdate like '%2025%' and StoreLocationId = '1'
order by value desc

select * from [Integration].[Weather].[HistoricalHistory]
where observationdate like '%2025-04-02%'

select * from #maxavgtemp

drop table if exists #traffic
select
l.LocationName,
sum(st.incount) as incount,
cast(timestampest as date) as trafficdate
into #traffic
from Fact.Sensor_Traffic st
join Dim.PeopleCounter_Location l
on l.PeopleCounterLocationKey = st.PeopleCounterLocationKey
where timestampest like '%2025%'
group by l.locationname, cast(timestampest as date)
--select * from #traffic

drop table if exists #distinct
select distinct
t.locationname,
t.incount,
t.trafficdate
into #distinct
from #traffic t
join #maxavgtemp a
on t.trafficdate = a.observationdate


select
locationname,
sum(incount) as incount
from #distinct
group by locationname