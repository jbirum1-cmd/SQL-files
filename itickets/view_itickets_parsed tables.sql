select * from Tickets.vw_ITickets_Event_Parsed order by eid desc, cdate desc
select * from Tickets.vw_ITickets_Order_Parsed order by oid desc, pulledatutc desc
select * from Tickets.vw_ITickets_OrderCharge_Parsed order by oid desc, pulledatutc desc
select * from Tickets.vw_ITickets_OrderTicket_Parsed order by oid desc, pulledatutc desc
