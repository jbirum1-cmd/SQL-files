drop table if exists #time
select
traffichistoryid,
sensorid,
sensorname,
incount,
outcount,
timestamputc,
timestamputc AT TIME ZONE 'UTC' 
    AT TIME ZONE 'Eastern Standard Time' AS est_time
into #time
from integration.peoplecounter.traffichistory

drop table if exists #integration25
select
l.LocationName,
sum(t.Incount) as incount,
sum(t.OutCount) as outcount
into #integration25
from #time t
join integration.peoplecounter.sensorsite ss
on t.sensorid = ss.sensorid
join integration.peoplecounter.sitelocation sl
on ss.VeaSiteId = sl.VeaSiteId
join integration.peoplecounter.location l
on sl.VeaLocationId = l.VeaLocationId
where t.est_time like '%2025%' --and locationname = 'temporary space'
group by locationname

drop table if exists #integration26
select
l.LocationName,
sum(t.Incount) as incount,
sum(t.OutCount) as outcount
into #integration26
from #time t
join integration.peoplecounter.sensorsite ss
on t.sensorid = ss.sensorid
join integration.peoplecounter.sitelocation sl
on ss.VeaSiteId = sl.VeaSiteId
join integration.peoplecounter.location l
on sl.VeaLocationId = l.VeaLocationId
where t.est_time like '%2026%' --and locationname = 'temporary space'
group by locationname

drop table if exists #dw25
select
l.LocationName,
sum(st.Incount) as incount,
sum(st.OutCount) as outcount
into #dw25
from Fact.Sensor_Traffic st
join Dim.PeopleCounter_Location l
on l.PeopleCounterLocationKey = st.PeopleCounterLocationKey
where timestampest like '%2025%'
group by l.locationname

drop table if exists #dw26
select
l.LocationName,
sum(st.Incount) as incount,
sum(st.OutCount) as outcount
into #dw26
from Fact.Sensor_Traffic st
join Dim.PeopleCounter_Location l
on l.PeopleCounterLocationKey = st.PeopleCounterLocationKey
where timestampest like '%2026%'
group by l.locationname

select
i5.locationname,
i5.incount as [2025_integration_incount],
d5.incount as [2025_DW_incount],
i5.outcount as [2025_integration_outcount],
d5.outcount as [2025_DW_outcount],
i6.incount as [2026_integration_incount],
d6.incount as [2026_DW_incount],
i6.outcount as [2026_integration_outcount],
d6.outcount as [2026_DW_outcount]
from #integration25 i5
join #integration26 i6
on i5.locationname = i6.locationname
join #dw25 d5
on d5.locationname = i6.locationname
join #dw26 d6
on d6.locationname = i6.locationname