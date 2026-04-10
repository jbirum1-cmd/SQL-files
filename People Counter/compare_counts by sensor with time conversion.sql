drop table if exists #timeconversion
select
traffichistoryid,
sensorid,
sensorname,
incount,
outcount,
timestamputc,
timestamputc AT TIME ZONE 'UTC' 
    AT TIME ZONE 'Eastern Standard Time' AS timestampest
into #timeconversion
from integration.peoplecounter.traffichistory

drop table if exists #timejoin
select
th.sensorid,
th.sensorname,
th.timestamputc,
t.timestampest,
th.incount,
th.outcount
into #timejoin 
from integration.peoplecounter.traffichistory th
join #timeconversion t
on t.traffichistoryid = th.traffichistoryid

select * from #timejoin 


select
s.sensorname,
sum(t.Incount) as incount,
sum(t.OutCount) as outcount
from #timejoin t
join integration.peoplecounter.sensorsite ss
on t.sensorid = ss.sensorid
join integration.peoplecounter.sensor s
on s.SensorId = ss.sensorid
join integration.peoplecounter.sitelocation sl
on ss.VeaSiteId = sl.VeaSiteId
join integration.peoplecounter.location l
on sl.VeaLocationId = l.VeaLocationId
where t.timestampest like '%2025-12%' and l.locationname = 'hartville collectibles'
group by s.sensorname
