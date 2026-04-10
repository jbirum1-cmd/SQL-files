select
l.LocationName,
sum(t.Incount) as InCount,
sum(t.OutCount) as OutCount
from integration.peoplecounter.traffichistory t
join integration.peoplecounter.sensorsite ss
on t.sensorid = ss.sensorid
join integration.peoplecounter.sitelocation sl
on ss.VeaSiteId = sl.VeaSiteId
join integration.peoplecounter.location l
on sl.VeaLocationId = l.VeaLocationId
where t.TimestampUtc like '%2025-01%'
group by l.locationname

select
l.LocationName,
sum(t.Incount) as InCount,
sum(t.OutCount) as OutCount
from integration.peoplecounter.traffichistory t
join integration.peoplecounter.sensorsite ss
on t.sensorid = ss.sensorid
join integration.peoplecounter.sitelocation sl
on ss.VeaSiteId = sl.VeaSiteId
join integration.peoplecounter.location l
on sl.VeaLocationId = l.VeaLocationId
where t.TimestampUtc like '%2025-02%'
group by l.locationname

select
l.LocationName,
sum(t.Incount) as InCount,
sum(t.OutCount) as OutCount
from integration.peoplecounter.traffichistory t
join integration.peoplecounter.sensorsite ss
on t.sensorid = ss.sensorid
join integration.peoplecounter.sitelocation sl
on ss.VeaSiteId = sl.VeaSiteId
join integration.peoplecounter.location l
on sl.VeaLocationId = l.VeaLocationId
where t.TimestampUtc like '%2025-03%'
group by l.locationname

select
l.LocationName,
sum(t.Incount) as InCount,
sum(t.OutCount) as OutCount
from integration.peoplecounter.traffichistory t
join integration.peoplecounter.sensorsite ss
on t.sensorid = ss.sensorid
join integration.peoplecounter.sitelocation sl
on ss.VeaSiteId = sl.VeaSiteId
join integration.peoplecounter.location l
on sl.VeaLocationId = l.VeaLocationId
where t.TimestampUtc like '%2025-04%'
group by l.locationname