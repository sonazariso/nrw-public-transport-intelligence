NRW Public Transport Intelligence – Business Case

Project Objective

The goal of this project is to build a data warehouse and Power BI analytics solution for evaluating the performance and reliability of public transport services in North Rhine-Westphalia (NRW), Germany.

The primary users of the solution are transport management teams and performance management teams responsible for monitoring service quality and identifying operational problems.

Business Problem

Passengers in NRW regularly experience delays, cancellations, and reliability problems across regional and urban public transport.

The project aims to answer questions such as:

Which routes have the highest delays?

Which routes have the highest cancellation rates?

Which stations experience the most operational problems?

How does performance differ between RE, RB, and S-Bahn services?

At what times of day or days of the week are delays more frequent?

Is service reliability improving or deteriorating over time?

Current Scope

Phase 1 focuses on regional rail services:

RE – Regional-Express

RB – Regionalbahn

S-Bahn

Long-distance services such as ICE and IC are currently excluded because the project focuses on everyday regional and local public transport within NRW.

Future phases may include:

U-Bahn / Stadtbahn

Tram

Bus

Analytical Goal

The final solution will provide a Power BI dashboard that enables transport management teams to monitor:

Punctuality

Delays

Cancellations

Station performance

Route performance

Operator performance

Peak-hour reliability

Performance trends over time

Initial Fact Grain

The current analytical grain is:

One scheduled trip at one stop on one service date.

This grain allows detailed analysis at trip, route, station, date, and time level and can later support delay propagation analysis along a route.
