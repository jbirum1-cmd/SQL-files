--select * from [PeopleCounter].[SMSS_Traffic_XML]
--select * from [PeopleCounter].[SmsStoreTrafficHistory]

--daily
select
sum(TrafficValue) as TrafficDailyTotal,
cast(TrafficDate as date) as TrafficDate
from [PeopleCounter].[SmsStoreTrafficHistory]
where DATENAME(WEEKDAY, TrafficDate) <> 'Sunday' and cast(TrafficDate as date) >= '4/1/2026'
group by cast(TrafficDate as date)
order by TrafficDate

--monthly
select
sum(TrafficValue) as TrafficDailyTotal,
format(cast(TrafficDate as date), 'yyyy-MM') as TrafficYearMonth
from [PeopleCounter].[SmsStoreTrafficHistory]
where DATENAME(WEEKDAY, TrafficDate) <> 'Sunday' and format(cast(TrafficDate as date), 'yyyy-MM') >= '2026-01'
group by format(cast(TrafficDate as date), 'yyyy-MM')
order by format(cast(TrafficDate as date), 'yyyy-MM')
