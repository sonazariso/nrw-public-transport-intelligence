USE NRWTransportDW;
GO

/*
Purpose
-------
Create the Route dimension for the Phase 1 data warehouse.

Grain
-----
One row = one Phase 1 RouteId.

Why this dimension is needed
----------------------------
The fact table should use compact surrogate keys instead of repeatedly
storing descriptive route attributes.

DimRoute centralizes:

- Route identifier
- Short and long route names
- Transport mode
- Operator / agency
- Original GTFS RouteType

Only routes explicitly classified as Phase 1 are loaded:

- RE
- RB
- S-Bahn

This keeps the warehouse aligned with the validated business scope while
the full source data remains preserved in the staging layer.
*/


IF OBJECT_ID('dw.DimRoute', 'U') IS NOT NULL
    DROP TABLE dw.DimRoute;
GO


CREATE TABLE dw.DimRoute
(
    RouteKey          INT IDENTITY(1,1) NOT NULL,

    RouteId           NVARCHAR(255) NOT NULL,
    RouteShortName    NVARCHAR(100) NULL,
    RouteLongName     NVARCHAR(500) NULL,

    TransportMode     NVARCHAR(50) NOT NULL,

    AgencyId          NVARCHAR(100) NULL,
    OperatorName      NVARCHAR(255) NULL,

    SourceRouteType   INT NOT NULL,

    CONSTRAINT PK_dw_DimRoute
        PRIMARY KEY CLUSTERED (RouteKey),

    CONSTRAINT UQ_dw_DimRoute_RouteId
        UNIQUE (RouteId)
);
GO


/*
Load Phase 1 routes
-------------------
wrk.RouteClassification contains the validated business classification.

stg.Routes provides descriptive GTFS route attributes.

stg.Agency provides the operator name.
*/

INSERT INTO dw.DimRoute
(
    RouteId,
    RouteShortName,
    RouteLongName,
    TransportMode,
    AgencyId,
    OperatorName,
    SourceRouteType
)
SELECT
    r.RouteId,
    r.RouteShortName,
    r.RouteLongName,
    rc.TransportMode,
    r.AgencyId,
    a.AgencyName,
    r.RouteType
FROM stg.Routes r

INNER JOIN wrk.RouteClassification rc
    ON r.RouteId = rc.RouteId
   AND rc.IsPhase1 = 1

LEFT JOIN stg.Agency a
    ON r.AgencyId = a.AgencyId;
GO


/*
Validation performed during implementation
------------------------------------------

Observed results:

Total Phase 1 routes = 65

Breakdown:
RB      = 20
RE      = 32
S-Bahn  = 13

MissingOperatorCount = 0

This confirms that all selected Phase 1 routes were loaded and every
route could be associated with an operator name.
*/


SELECT
    COUNT(*) AS RouteCount
FROM dw.DimRoute;


SELECT
    TransportMode,
    COUNT(*) AS RouteCount
FROM dw.DimRoute
GROUP BY TransportMode
ORDER BY TransportMode;


SELECT
    COUNT(*) AS MissingOperatorCount
FROM dw.DimRoute
WHERE OperatorName IS NULL;


SELECT TOP (30)
    RouteKey,
    RouteId,
    RouteShortName,
    RouteLongName,
    TransportMode,
    OperatorName,
    SourceRouteType
FROM dw.DimRoute
ORDER BY
    TransportMode,
    RouteShortName;
