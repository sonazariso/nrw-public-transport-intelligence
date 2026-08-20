USE NRWTransportDW;
GO

/*
Purpose
-------
Create analytical indexes on the final Phase 1 fact table.

Why these indexes are needed
----------------------------
dw.FactTripStop contains more than 8 million rows.

The clustered primary key is FactTripStopKey, which is useful for row identity,
but most analytical queries do not filter by that column.

The implemented nonclustered indexes support the two main query patterns:

1. Date / Route / Stop analysis
2. Following one TripInstance in StopSequence order

These indexes were created after the fact table load.

Why after the load?
-------------------
Creating nonclustered indexes before inserting millions of rows would increase
the cost of the initial load because SQL Server would have to maintain each
index while every row was inserted.

The fact data was therefore loaded and validated first, and the reporting
indexes were added afterward.
*/


/*
Index 1
-------
Supports analytical queries grouped or filtered by:

- Date
- Route
- Stop

This is particularly useful for warehouse reporting and future Power BI
queries such as scheduled service volume by date, route, or station.
*/

CREATE INDEX IX_FactTripStop_DateRouteStop
ON dw.FactTripStop
(
    DateKey,
    RouteKey,
    StopKey
);
GO


/*
Index 2
-------
Supports retrieval of all stops belonging to one TripInstance in their
scheduled sequence.

Typical usage:

WHERE TripInstanceKey = ...
ORDER BY StopSequence
*/

CREATE INDEX IX_FactTripStop_TripInstance
ON dw.FactTripStop
(
    TripInstanceKey,
    StopSequence
);
GO


/*
Implementation status
---------------------
Both indexes were successfully created during implementation.

No additional fact-table indexes are documented here as Implemented unless
they have actually been created and verified in SQL Server.

Physical foreign key constraints are also not included in this file because
they had not yet been implemented at this stage.
*/
