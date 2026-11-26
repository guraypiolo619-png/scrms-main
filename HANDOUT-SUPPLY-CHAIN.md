# Integration Handout: Supply Chain Management System (SCRMS)

> **Audience**: AI Agent / Developers of `https://github.com/guraypiolo619-png/scrms-main.git`  
> **Core ERP Gateway**: InvenTree Production System (`Azyte12/SIA-LBM-GUERRA`)  
> **Date**: 2026-11-25

---

## 1. System Role & Integration Boundary

You are the **Supply Chain System of Record (SCRMS)**.
* **You Own**: Suppliers, Purchase Requisitions, Purchase Orders, Shipment Notices, Physical Receipt Notifications.
* **Core ERP (InvenTree) Owns**: Physical Inventory, Part SKUs, Warehouse Locations, Stock Counts, Build Orders, and QC inspection records.
* **Security & Access Rule**: You **never** connect directly to the Core PostgreSQL database. All interactions happen through the authenticated, idempotent Integration Gateway API.

---

## 2. API Gateway Connection Specification

### Base Endpoints
* **Health Check**: `GET http://<core-erp-host>:8088/api/v1/integration/health/` (Public)
* **Event Submission**: `POST http://<core-erp-host>:8088/api/v1/integration/events/` (Authenticated)
* **Event Status**: `GET http://<core-erp-host>:8088/api/v1/integration/events/<event_id>/` (Authenticated)

### Required Headers
Every event submission must include these exact headers:
```http
Authorization: Bearer <your-integration-token>
Idempotency-Key: <unique-uuid4-matching-event_id>
X-Limbus-System: supply-chain
Content-Type: application/json
```

---

## 3. Allowed Events for Supply Chain

Your system is authorized to submit the following event types:
1. `purchase.received`: When goods or raw materials arrive at a receiving location.
2. `supplier.upsert`: When a supplier is created or updated.
3. `purchase_order.upsert`: When a purchase order is created or updated.

---

## 4. Event Envelope & Payload Specifications

### A. Event: `purchase.received` (Primary Physical Flow)
Triggered when physical items are received at a designated warehouse location against a purchase order line.

```json
{
  "event_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "source_system": "supply-chain",
  "event_type": "purchase.received",
  "occurred_at": "2026-11-25T12:00:00Z",
  "correlation_id": "PO-2026-0048",
  "external_id": "PO-2026-0048",
  "payload": {
    "purchase_order_external_id": "PO-2026-0048",
    "line_item_external_id": "PO-2026-0048-L1",
    "location_external_id": "BATANGAS-WH",
    "quantity": "25",
    "batch_code": "HEAT-2026-A1",
    "supplier_lot": "SUP-LOT-9981"
  }
}
```

#### Payload Fields:
* `purchase_order_external_id` (string, required): Your external PO reference. Must be mapped in `IntegrationMapping`.
* `line_item_external_id` (string, required): Your line item reference. Must be mapped in `IntegrationMapping`.
* `location_external_id` (string, required): Receiving location code (e.g. `BATANGAS-WH`). Must be mapped in `IntegrationMapping`.
* `quantity` (string, required): Positive decimal quantity received.
* `batch_code` (string, optional): Heat number / steel batch code.
* `supplier_lot` (string, optional): Supplier lot number for traceability.

---

### B. Event: `supplier.upsert`
Triggered when a supplier is registered or profile updated in SCRMS.

```json
{
  "event_id": "a55c2f81-54de-4d33-bcbe-01efb5402123",
  "source_system": "supply-chain",
  "event_type": "supplier.upsert",
  "occurred_at": "2026-11-25T12:00:00Z",
  "correlation_id": "SUP-001",
  "external_id": "SUP-001",
  "payload": {
    "supplier_external_id": "SUP-001",
    "name": "SteelCorp International",
    "description": "Primary steel coil and rebar supplier",
    "email": "sales@steelcorp.example.com",
    "phone": "+63-2-8123-4567"
  }
}
```

---

## 5. Drop-in Python Integration Client

Add this module to your SCRMS project (e.g. `integration/gateway_client.py`):

```python
import uuid
from datetime import datetime, timezone
import requests

class CoreERPGatewayClient:
    def __init__(self, base_url: str, token: str):
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.system_id = "supply-chain"

    def _send_event(self, event_type: str, correlation_id: str, external_id: str, payload: dict) -> dict:
        event_id = str(uuid.uuid4())
        occurred_at = datetime.now(timezone.utc).isoformat()

        envelope = {
            "event_id": event_id,
            "source_system": self.system_id,
            "event_type": event_type,
            "occurred_at": occurred_at,
            "correlation_id": str(correlation_id),
            "external_id": str(external_id),
            "payload": payload,
        }

        headers = {
            "Authorization": f"Bearer {self.token}",
            "Idempotency-Key": event_id,
            "X-Limbus-System": self.system_id,
            "Content-Type": "application/json",
        }

        endpoint = f"{self.base_url}/api/v1/integration/events/"
        response = requests.post(endpoint, json=envelope, headers=headers, timeout=10)
        response.raise_for_status()
        return response.json()

    def record_receipt(self, po_id: str, line_item_id: str, location_id: str, quantity: float, batch_code: str = None, supplier_lot: str = None):
        """Notify Core ERP of a physical stock receipt."""
        payload = {
            "purchase_order_external_id": str(po_id),
            "line_item_external_id": str(line_item_id),
            "location_external_id": str(location_id),
            "quantity": str(quantity),
        }
        if batch_code:
            payload["batch_code"] = batch_code
        if supplier_lot:
            payload["supplier_lot"] = supplier_lot

        return self._send_event(
            event_type="purchase.received",
            correlation_id=po_id,
            external_id=po_id,
            payload=payload,
        )

    def upsert_supplier(self, supplier_id: str, name: str, email: str = None, phone: str = None, description: str = None):
        """Sync supplier master data to Core ERP."""
        payload = {
            "supplier_external_id": str(supplier_id),
            "name": name,
            "email": email or "",
            "phone": phone or "",
            "description": description or "",
        }
        return self._send_event(
            event_type="supplier.upsert",
            correlation_id=supplier_id,
            external_id=supplier_id,
            payload=payload,
        )
```

---

## 6. Verification with cURL

Run this command to test event submission:

```bash
curl -X POST http://<core-erp-host>:8088/api/v1/integration/events/ \
  -H "Authorization: Bearer <your-token>" \
  -H "Idempotency-Key: 11111111-2222-3333-4444-555555555555" \
  -H "X-Limbus-System: supply-chain" \
  -H "Content-Type: application/json" \
  -d '{
    "event_id": "11111111-2222-3333-4444-555555555555",
    "source_system": "supply-chain",
    "event_type": "supplier.upsert",
    "occurred_at": "2026-11-25T12:00:00Z",
    "correlation_id": "SUP-TEST-01",
    "external_id": "SUP-TEST-01",
    "payload": {
      "supplier_external_id": "SUP-TEST-01",
      "name": "Acme Steel Supply Inc."
    }
  }'
```

**Expected Response**:
```json
{
  "event_id": "11111111-2222-3333-4444-555555555555",
  "status": "succeeded"
}
```
Re-sending the exact same request will return `status: duplicate` without creating duplicate suppliers or stock entries.
