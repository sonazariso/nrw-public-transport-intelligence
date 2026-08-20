# 03-classify-phase1-routes.sql

```sql id="3v7nkd"
USE NRWTransportDW;
GO

/*
Purpose
-------
Classify NRW rail routes into the Phase 1 business scope:

- RE
- RB
- S-Bahn

and explicitly retain excluded rail-like routes as Other Rail.

Why this transformation is needed
---------------------------------
The project focuses on NRW regional rail performance.

The source GTFS feed contains multiple transport modes and uses
extended GTFS route_type values.

Initial profiling showed that the feed does not use route_type = 2
for the relevant rail services.

Observed route_type distribution included:

0   = 586 routes
1   = 511 routes
3   = 4,647 routes
4   = 2 routes
106 = 52 routes
109 = 123 routes
405 = 28 routes

Further profiling showed:

RouteType 106:
- 32 RE routes
- 20 RB routes

RouteType 109:
- 13 routes with an S-Bahn-style RouteShortName
- 110 additional routes that did not match the Phase 1 S-Bahn naming rule

Therefore, Phase 1 classification is based on both RouteType
and RouteShortName.

Phase 1 rules
-------------
RouteType 106 + RE prefix -> RE
RouteType 106 + RB prefix -> RB
RouteType 109 + S prefix  -> S-Bahn

All remaining routes within 106/109 are explicitly classified
as Other Rail and excluded from Phase 1.

This preserves auditability: excluded routes remain visible instead
of disappearing silently from the transformation.
*/


IF OBJECT_ID('wrk.RouteClassification', 'U') IS NOT NULL
    DROP TABLE wrk.RouteClassification;
GO

CREATE TABLE wrk.RouteClassification
(
    RouteId              NVARCHAR(255) NOT NULL,
    RouteShortName       NVARCHAR(100) NULL,
    RouteType            INT NOT NULL,
    TransportMode        NVARCHAR(50) NOT NULL,
    IsPhase1             BIT NOT NULL,
    ClassificationRule   NVARCHAR(255) NOT NULL,

    CONSTRAINT PK_wrk_RouteClassification
        PRIMARY KEY CLUSTERED (RouteId)
);
GO


INSERT INTO wrk.RouteClassification
(
    RouteId,
    RouteShortName,
    RouteType,
    TransportMode,
    IsPhase1,
    ClassificationRule
)
SELECT
    RouteId,
    RouteShortName,
    RouteType,

    CASE
        WHEN RouteType = 106
             AND RouteShortName LIKE 'RE%'
            THEN 'RE'

        WHEN RouteType = 106
             AND RouteShortName LIKE 'RB%'
            THEN 'RB'

        WHEN RouteType = 109
             AND RouteShortName LIKE 'S%'
            THEN 'S-Bahn'

        ELSE 'Other Rail'
    END AS TransportMode,

    CASE
        WHEN RouteType = 106
             AND
             (
                 RouteShortName LIKE 'RE%'
                 OR RouteShortName LIKE 'RB%'
             )
            THEN 1

        WHEN RouteType = 109
             AND RouteShortName LIKE 'S%'
            THEN 1

        ELSE 0
    END AS IsPhase1,

    CASE
        WHEN RouteType = 106
             AND RouteShortName LIKE 'RE%'
            THEN 'RouteType 106 + RE prefix'

        WHEN RouteType = 106
             AND RouteShortName LIKE 'RB%'
            THEN 'RouteType 106 + RB prefix'

        WHEN RouteType = 109
             AND RouteShortName LIKE 'S%'
            THEN 'RouteType 109 + S prefix'

        ELSE 'Excluded from Phase 1 after profiling'
    END AS ClassificationRule

FROM stg.Routes
WHERE RouteType IN (106, 109);
GO


/*
Validation performed during implementation
------------------------------------------

Observed results:

RB          | IsPhase1 = 1 | 20 routes
RE          | IsPhase1 = 1 | 32 routes
S-Bahn      | IsPhase1 = 1 | 13 routes
Other Rail  | IsPhase1 = 0 | 110 routes

Total classified routes = 175
Phase 1 routes          = 65

The 110 excluded RouteType 109 routes were profiled separately.
They belonged to AgencyName = VRR and primarily used numeric
RouteShortName values rather than S-Bahn identifiers.
*/


SELECT
    TransportMode,
    IsPhase1,
    COUNT(*) AS RouteCount
FROM wrk.RouteClassification
GROUP BY
    TransportMode,
    IsPhase1
ORDER BY
    IsPhase1 DESC,
    TransportMode;


SELECT
    COUNT(*) AS Phase1RouteCount
FROM wrk.RouteClassification
WHERE IsPhase1 = 1;
```
