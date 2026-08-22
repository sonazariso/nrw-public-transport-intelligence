# 9. Production Realtime Collector, DW Load, and Operations

## 9.1 Scope of This Checkpoint

This chapter continues directly from the validated interactive collector described in Chapter 8. It records only the work completed after that point, through **2026-08-22**.

The implementation is currently production-like for one pilot station, Köln Hbf. It is not yet a multi-station NRW service.

## 9.2 Final Collector Flow

The reusable `DbRealtimeCollector.ps1` performs the complete pipeline:

```text
DB Timetables API
  -> current-hour /plan + next-hour /plan + /fchg
  -> deduplicate DbEventId values
  -> match planned and changed events
  -> append full snapshots to stg.DbRealtimeStopObservation
  -> select the latest observation per event
  -> strong-match DB events to GTFS trip stops
  -> materialize wrk.vDbRealtimeStopPerformanceLoadSource
  -> update existing facts and insert new facts
  -> dw.FactRealtimeStopPerformance
```

Reading both the current and next hours avoids the coverage gap around an hour boundary. Deduplication is required because the two plan windows can overlap.

Staging remains append-only during normal collection. Repeated observations are intentional: they preserve how delay, cancellation, and platform information changes over time.

## 9.3 Strong DB-to-GTFS Match and Fact Grain

Only technically reliable matches are loaded into the realtime fact. The validated load source has a one-to-one relationship between `DbEventId` and `FactTripStopKey`.

`dw.FactRealtimeStopPerformance` keeps one current row per strongly matched DB event/trip-stop pair. It includes the latest observation, first and last capture times, observation count, delays, cancellation flags, platforms, and match metadata.

The loader protects both directions of the relationship:

- an existing `DbEventId` cannot move to a different `FactTripStopKey`;
- an existing `FactTripStopKey` cannot move to a different `DbEventId`.

Any such conflict fails the load instead of silently corrupting the fact grain.

## 9.4 Idempotent DW Upsert

`dw.usp_LoadFactRealtimeStopPerformance` updates an existing event only when its latest observation state has advanced and inserts events that do not yet exist. Re-running the loader without new source data produces zero updates and zero inserts.

The final synchronization validation returned:

```text
SourceRows    = 133
FactRows      = 133
MatchedRows   = 133
OutOfSyncRows = 0
```

This confirms that the load source and realtime fact were fully synchronized at the checkpoint.

## 9.5 Loader Performance Optimization

The original procedure evaluated the complex source view more than once and took about 59.7 seconds. The final procedure materializes the view once into `#Source`, adds unique indexes for `DbEventId` and `FactTripStopKey`, and then performs the safety checks and upsert inside a short transaction.

Validated benchmark:

```text
Before: approximately 59.7 seconds elapsed
After:  approximately 1.1 seconds elapsed
```

Materialization occurs before the DW transaction so the relatively expensive matching work does not extend fact-table locks.

## 9.6 Operational Wrapper and Logging

`RunDbRealtimeCollector.ps1` runs the collector with stop-on-error behavior and writes a timestamped log under:

```text
C:\NRWTransport\Collector\Logs
```

The wrapper records start time, collector output, successful completion, or the error that caused failure. It was validated from a clean PowerShell process using `-NoProfile`, confirming that scheduled execution does not depend on an interactive session.

API credentials must remain outside source control. They must not be committed to this repository or written into documentation or logs.

## 9.7 Windows Task Scheduler

The Windows task `NRW DB Realtime Collector` runs the wrapper every 15 minutes. The validated operational settings are:

- repeat every 15 minutes indefinitely;
- run whether the user is logged on or not;
- start in `C:\NRWTransport\Collector`;
- start missed runs as soon as possible;
- do not start a new instance when a prior run is still active;
- stop an abnormally long run after the minimum available one-hour limit.

An automatic run on 2026-08-22 completed with Task Scheduler result `0x0`, created a new log, inserted 71 snapshots, updated 30 fact rows, and left 133 total fact rows.

## 9.8 Observed Volume and Retention Decision

The first validated history sample contained:

```text
Observations     = 1,097
Distinct events = 313
Capture period  = 2026-08-22 13:42:44 through 21:50:18
Table size      = 0.52 MB reserved / 0.41 MB used
```

At roughly 71 rows per run and 96 runs per day, Köln Hbf produces about 6,800 observation rows per day. No cleanup is currently enabled because raw history is still required to validate analytical requirements.

Retention targets for later implementation are:

```text
stg.DbRealtimeStopObservation   180 days
Collector logs                  30 days
dw.FactRealtimeStopPerformance no scheduled deletion
```

Raw cleanup must not be enabled until all history required by Power BI is preserved in an appropriate analytical structure.

## 9.9 Project State as of 2026-08-22

Completed and validated:

- Köln Hbf collection for the current and next hours;
- overlapping-event deduplication;
- append-only realtime observation history;
- delay, cancellation, and platform capture;
- strong DB-to-GTFS matching;
- idempotent, conflict-protected DW upsert;
- loader optimization from about one minute to about one second;
- independent wrapper execution and timestamped logs;
- automatic 15-minute execution in Windows Task Scheduler.

Not yet implemented:

- database-driven configuration for multiple NRW stations;
- automatic staging and log cleanup;
- a historical analytical model beyond the latest-state realtime fact;
- Power BI performance dashboards.

## 9.10 Next Starting Point

The next development step is to create a station configuration object such as `cfg.DbRealtimeStation` and remove station EVA/GTFS mapping from PowerShell. Köln Hbf should first be migrated to that configuration without changing collector results; additional NRW stations can then be introduced incrementally.

After multi-station collection is stable, implement retention jobs and the Power BI-facing historical model.
