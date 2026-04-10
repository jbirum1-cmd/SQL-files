--gets event total sales
drop table if exists #sales
SELECT
e.EventId,
e.Eventname,
sum(o.totalcharge) as event_total,
e.eventdate
into #sales
FROM Tickets.ITickets_Event e
left join Tickets.ITickets_Order o
on o.eventid = e.EventId
where o.markedrefundedat is null --and e.eid = '484882'
group by e.EventId, e.Eventname, e.eventdate
order by e.eventdate desc

--gets event non-meal tickets
drop table if exists #nonmeal
select
o.eventid,
count(*) as event_ticket_count
into #nonmeal
from Tickets.ITickets_Order o
join Tickets.ITickets_OrderTicket ot
on o.orderid = ot.orderid
where ot.type <> 'meal'
group by o.eventid

--gets meal tickets
drop table if exists #meal
select
o.eventid,
count(*) as meal_ticket_count
into #meal
from Tickets.ITickets_Order o
join Tickets.ITickets_OrderTicket ot
on o.orderid = ot.orderid
where ot.type = 'meal'
group by o.eventid

--joins together
select
s.EventId,
s.EventName,
s.Eventdate,
isnull(s.Event_total,0) as Event_total,
isnull(n.event_ticket_count,0) as event_ticket_count,
isnull(m.meal_ticket_count,0) as meal_ticket_count,
isnull(n.event_ticket_count,0) + isnull(m.meal_ticket_count,0) as total_ticket_count
from #sales s
left join #nonmeal n
on s.eventid = n.eventid
left join #meal m
on s.eventid = m.eventid
order by eventdate desc


/* investigate discrepancies
SELECT
e.EID,
e.cname,
o.fname,
o.lname,
o.totalcharge,
e.cdate
FROM Tickets.ITickets_Event e
left join Tickets.ITickets_Order o
on o.eid = e.eid
where e.eid = '484882'
order by e.cdate desc

select * from Tickets.vw_ITickets_Event_Parsed order by eid desc, cdate desc
select * from Tickets.ITickets_OrderTicket order by lastsyncedat desc
*/

