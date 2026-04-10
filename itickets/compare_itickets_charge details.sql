select
e.EventId,
e.Eventname,
e.eventdate,
o.orderid,
c.paymethod,
c.card_type,
c.check_number,
c.firstname,
c.lastname
from Tickets.ITickets_Event e
left join Tickets.ITickets_Order o
on o.eventid = e.EventId
left join Tickets.ITickets_OrderCharge c
on o.OrderId = c.orderid
where e.eventid = '484880'
order by o.orderid

