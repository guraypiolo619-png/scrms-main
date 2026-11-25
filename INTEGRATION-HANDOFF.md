# Limbus Manufacturing Cross-System Integration Handoff

## 1. Purpose

This document defines the integration boundary for five AI-owned systems:

| System | Owned data | Production dependency |
| --- | --- | --- |
| Finance | Invoices, payments, ledgers, cost centers, financial periods | Build cost, stock valuation, purchase and sales totals |
| Human Resources | Employees, departments, roles, employment status | Manufacturing operators, approvers and accountable users |
| Supply Chain | Suppliers, purchase requests, purchase orders, receipts, suppliers | Parts, supplier parts, stock receipts and purchase orders |
| Sales and Marketing | Customers, quotations, promotions, sales demand | Sales orders, allocations, shipments and finished stock |
| Production | Parts, BOMs, builds, stock, locations, QC and traceability | Receives demand and supply, publishes finished goods and consumption |

No agent should write directly to PostgreSQL. Every agent sends authenticated
API requests to the integration gateway. The gateway validates payloads,
records an idempotency key and event audit, maps external IDs, applies changes
to the Production system, and publishes a result or retry event.

## 2. Centralized topology

```text
Finance AI --------\
HR AI ------------\
Supply Chain AI ----> Integration Gateway -> InvenTree Production API
Sales and Marketing AI/                             |
                                                    +-> PostgreSQL
                                                          centralized
                                                          audit/mapping
                                                          data
```

The existing PostgreSQL database is the centralized data store. The existing
InvenTree data remains authoritative for:

- parts and BOMs
- stock locations and quantities
- build orders
- purchase orders and receipts
- sales orders and shipments
- users and permissions

External systems remain authoritative for their source records. The gateway
stores only the authoritative external ID, the local entity ID and the last
successfully processed event.

## 3. API conventions

Base URL:

```text
https://<production-host>:8088/api/v1/integration
```

Until HTTPS is configured, use the private/trusted network URL only. Never put
an API token in source code or a Git repository.

All requests use:

```http
Authorization: Bearer <system-specific-token>
Content-Type: application/json
Idempotency-Key: <uuid>
X-Limbus-System: finance|hr|supply-chain|sales-marketing|production
```

All response bodies use JSON. Timestamps use UTC ISO-8601:

```text
2026-11-20T10:30:00Z
```

IDs and units must be strings. Never infer units at the receiver.

## 4. Common event envelope

```json
{
  "event_id": "8cb64af2-2a3c-4cd1-b1cb-a98b0fe6c5d2",
  "source_system": "supply-chain",
  "event_type": "purchase.received",
  "occurred_at": "2026-11-20T10:30:00Z",
  "correlation_id": "po-2026-0048",
  "external_id": "PO-2026-0048",
  "payload": {}
}
```

Rules:

- `event_id` is unique for the event.
- `Idempotency-Key` and `event_id` must be identical across retries.
- Replaying an event must return the original result, not create duplicates.
- `source_system` and `event_type` must match an allowlist.
- Unknown fields must be rejected or explicitly documented.
- A 4xx response identifies an invalid request and must not be retried unchanged.
- A 5xx or timeout response may be retried with exponential backoff.

## 5. Finance AI instructions

### Sends to Production

- approved supplier invoice totals
- payment status
- cost-center allocations
- invoice references
- posted/cancelled financial-period transactions

### Receives from Production

- purchase-order committed cost
- received stock value
- build material consumption
- finished-stock valuation
- sales shipment and invoice-relevant totals

### Required endpoints

- `POST /api/v1/integration/events/purchase-cost`
- `POST /api/v1/integration/events/build-cost`
- `POST /api/v1/integration/events/sales-cost`

Finance must not create or alter inventory quantities.

## 6. Human Resources AI instructions

### Sends to Production

- employee ID and status
- department
- role/job title
- manager or approver
- start/end employment dates

### Receives from Production

- build, QC or approval actions requiring an accountable operator
- rejected-time or missing-identity events

### Required endpoints

- `POST /api/v1/integration/events/employee-upsert`
- `POST /api/v1/integration/events/employee-deactivate`

Before a user is created in InvenTree, normalize the external employee ID and
map it to the local account. HR is authoritative for active status.

## 7. Supply Chain AI instructions

### Sends to Production

- supplier record updates
- purchase requisitions
- purchase orders
- shipment notice
- quantity received
- rejected or returned quantity

### Receives from Production

- low-stock notifications
- reorder demand
- open purchase orders
- QC hold/release results
- receipt discrepancies

### Required endpoints

- `POST /api/v1/integration/events/supplier-upsert`
- `POST /api/v1/integration/events/purchase-order-upsert`
- `POST /api/v1/integration/events/purchase-received`
- `POST /api/v1/integration/events/purchase-returned`

For receipts, include part external ID, quantity, unit, location, batch/heat
number, supplier lot number, received timestamp and operator external ID.

## 8. Sales and Marketing AI instructions

### Sends to Production

- customer updates
- forecast or demand
- quotation
- sales order
- order cancellation

### Receives from Production

- available-to-promise quantities
- build completion
- allocated stock
- shipment status
- delivery completion

### Required endpoints

- `POST /api/v1/integration/events/customer-upsert`
- `POST /api/v1/integration/events/demand-upsert`
- `POST /api/v1/integration/events/sales-order-upsert`
- `POST /api/v1/integration/events/sales-order-cancel`

Sales and Marketing must not change physical stock. Only Production may execute
allocation, shipment and stock adjustments.

## 9. Production AI instructions

The Production system is the primary manufacturing API owner.

### Must publish

- stock received
- stock consumed
- stock transferred
- QC approved/rejected
- build started/completed/cancelled
- shipment ready/dispatched/delivered
- low-stock alerts

### InvenTree endpoints

The current production API base is `http://<host>:8088/api/`. Relevant existing
API areas include:

- `/api/part/`
- `/api/build/`
- `/api/stock/`
- `/api/order/`
- `/api/company/`
- `/api/users/`
- `/api/system/health/`

Use the exported schema at `api-459.yaml` as the endpoint authority. Validate
field names and permission requirements against the running instance before
implementation.

Production must:

- map external IDs through the integration mapping table
- serialize each state transition
- publish one event for each committed transition
- reject consumption where stock, BOM or QC rules do not pass
- keep an audit trail for quantity, unit and operator

## 10. Central integration data model

The gateway or database migration must provide these tables:

### `integration_event`

| Column | Type | Purpose |
| --- | --- | --- |
| event_id | UUID | immutable external event ID |
| source_system | text | sender |
| event_type | text | typed event name |
| correlation_id | text | business process ID |
| external_id | text | source record ID |
| payload | JSONB | original normalized payload |
| status | text | received, processing, succeeded, failed, duplicate |
| attempt_count | integer | retry count |
| last_error | text | safe error detail |
| occurred_at | timestamptz | source event time |
| received_at | timestamptz | gateway receive time |
| processed_at | timestamptz | successful process time |

### `integration_mapping`

| Column | Type | Purpose |
| --- | --- | --- |
| source_system | text | external system |
| entity_type | text | supplier, part, employee, order |
| external_id | text | ID in source system |
| inventree_model | text | target InvenTree model |
| inventree_id | bigint/text | target record ID |
| metadata | JSONB | optional mapping details |

Constraints:

- unique `(source_system, entity_type, external_id)`
- unique `(source_system, event_id)`
- mapping changes require an audit event

## 11. Security requirements

Each system receives a separate token with least privilege.

- Finance: financial event write; production cost read
- HR: employee lifecycle write
- Supply Chain: supplier, purchasing and receipt write
- Sales and Marketing: customer, forecast and sales demand write
- Production: inventory, build and sales fulfillment write

Required controls:

- HTTPS for public traffic
- token rotation
- short-lived integration sessions where supported
- IP or network allowlists where practical
- per-source rate limits
- secret storage outside source control
- audit log for authorization and state changes
- no direct PostgreSQL credentials for AI agents

## 12. Delivery and retry policy

1. Sender performs the request once with an Idempotency-Key.
2. Gateway validates authentication, allowlist and payload.
3. Gateway stores `received` before processing.
4. Gateway maps IDs and executes the Production transition.
5. Gateway stores the result and publishes a response event.
6. Failures are retried after 1, 5, 15, 60 and 300 seconds.
7. After five attempts, move the event to `failed` and alert an operator.

## 13. Acceptance tests

Every external AI must pass these tests before production use:

1. Duplicate event replay returns the original success and creates no duplicate.
2. Missing required fields return 400 with a field-level error.
3. Invalid token returns 401.
4. Unauthorized event type returns 403.
5. Gateway outage preserves the sender queue and retries safely.
6. A purchase receipt with partial quantity updates the correct location and batch.
7. An employee deactivation prevents new local authorization assignments.
8. A cancelled sales order does not cancel physical stock already shipped.
9. A build completion cannot exceed the accepted finished quantity policy.
10. Every successful external event has an external-ID/local-ID mapping.

## 14. Agent implementation order

1. Centralize and review the canonical event schema.
2. Implement the Integration Gateway and database migration.
3. Implement Health and event reception endpoints.
4. Implement idempotency, audit and retry.
5. Implement one production pilot flow.
6. Implement Supply Chain purchase receipts.
7. Implement Sales demand and order flows.
8. Implement HR identity lifecycle.
9. Implement Finance costing and reconciliation.
10. Run replay, failure, permission and reconciliation tests.
