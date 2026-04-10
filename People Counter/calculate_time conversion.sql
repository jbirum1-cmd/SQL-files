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

select
l.LocationName,
sum(t.Incount) as incount,
sum(t.OutCount) as outcount
from #time t
join integration.peoplecounter.sensorsite ss
on t.sensorid = ss.sensorid
join integration.peoplecounter.sitelocation sl
on ss.VeaSiteId = sl.VeaSiteId
join integration.peoplecounter.location l
on sl.VeaLocationId = l.VeaLocationId
where t.est_time like '%2025-02%' --and locationname = 'temporary space'
group by locationname
