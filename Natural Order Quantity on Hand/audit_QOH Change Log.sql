SELECT 
    sku,
    warehouse,
    previouslocation,
    newlocation,
    programid,
    executionid,
    istestrun,
    COUNT(*) AS duplicate_count
FROM inv.locationchangelog
WHERE changedat > '2026-04-21 15:12:36.2530158'
GROUP BY 
    sku,
    warehouse,
    previouslocation,
    newlocation,
    programid,
    executionid,
    istestrun
HAVING COUNT(*) > 1;

select * from inv.LocationChangeLog order by changedat desc