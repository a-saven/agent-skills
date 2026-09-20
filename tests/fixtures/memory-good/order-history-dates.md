---
name: order-history-dates
description: order history renders UTC instead of local time — known-broken, ticket #150
metadata:
  type: project
---
The date column in order history shows the raw UTC timestamp from the API, one day off for evening orders in UTC-5.
**Why:** it is a real defect with an open ticket, so a run that reports it as new noise costs the reader time.
**How to apply:** still run the check, then report it as KNOWN with the lesson's date and the ticket number.
