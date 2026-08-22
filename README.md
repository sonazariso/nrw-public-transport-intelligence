# nrw-public-transport-intelligence

Data warehouse and Power BI analytics project for public transport performance and reliability in North Rhine-Westphalia, Germany.

Current implementation includes an SQL Server-based GTFS pipeline from raw NRW timetable data through staging, transformation, and a Phase 1 Star Schema for RE, RB, and S-Bahn scheduled-service analytics.

The project now also includes a validated Deutsche Bahn realtime pipeline for Köln Hbf. A PowerShell collector polls the current and next timetable hours every 15 minutes, preserves observation history, performs strong DB-to-GTFS matching, and upserts the latest matched state into the realtime performance fact table.

For the implementation checkpoint as of **2026-08-22**, see:

- [English: Production Collector, DW Load, and Operations](docs/en/09-production-realtime-collector-and-operations.md)
- [فارسی: Collector نهایی، بارگذاری DW و عملیات](docs/fa/09-production-realtime-collector-and-operations.md)

Power BI reporting and multi-station NRW collection are planned next.
