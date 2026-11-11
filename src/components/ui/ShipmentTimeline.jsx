import React from "react";
import { ExternalLink, Trash2 } from "lucide-react";
import StatusBadge from "./StatusBadge";

// Delhivery collapses each shipment into one stable stage (see
// server/services/delhiveryService.js stageOf). The API returns the raw
// machine value, so the wording is mapped here for display.
const STAGE_LABELS = {
  pending: "Awaiting pickup",
  manifested: "Picked up",
  in_transit: "In transit",
  out_for_delivery: "Out for delivery",
  delivered: "Delivered",
  returned: "Returned",
  cancelled: "Cancelled",
};

export function stageLabel(stage) {
  return STAGE_LABELS[stage] || String(stage || "").replaceAll("_", " ");
}

export function formatScanTime(value) {
  if (!value) return "—";
  const date = new Date(value);
  return Number.isNaN(date.getTime())
    ? String(value)
    : date.toLocaleString("en-IN", { timeZone: "Asia/Kolkata" });
}

export function ShipmentScans({ scans = [] }) {
  if (!scans.length)
    return <p className="empty-copy">No scans recorded for this shipment yet.</p>;
  return (
    <ol className="shipment-scans">
      {scans.map((scan, index) => (
        <li key={`${scan.at || "scan"}-${index}`} className={index === 0 ? "current" : ""}>
          <div>
            <b>{String(scan.status || "Update").replaceAll("_", " ")}</b>
            <span>{formatScanTime(scan.at)}</span>
          </div>
          {scan.location && <small>{scan.location}</small>}
          {scan.instructions && <p>{scan.instructions}</p>}
        </li>
      ))}
    </ol>
  );
}

export default function ShipmentTimeline({ shipments = [], onRemove, busy = false }) {
  if (!shipments.length)
    return <p className="empty-copy">No shipment linked to this order yet.</p>;
  return (
    <div className="shipment-list">
      {shipments.map((shipment) => (
        <div className="shipment-card" key={shipment.waybill}>
          <div className="shipment-card-head">
            <div>
              <b>{shipment.waybill}</b>
              <StatusBadge>{stageLabel(shipment.stage)}</StatusBadge>
            </div>
            <span className="table-actions">
              <a
                className="outline"
                href={shipment.trackingUrl}
                target="_blank"
                rel="noopener noreferrer"
              >
                <ExternalLink size={14} />
                Delhivery
              </a>
              {onRemove && (
                <button
                  className="danger"
                  disabled={busy}
                  onClick={() => onRemove(shipment.waybill)}
                >
                  <Trash2 size={14} />
                  Unlink
                </button>
              )}
            </span>
          </div>
          <div className="shipment-facts">
            <span>
              <small>Current status</small>
              {shipment.status || "—"}
            </span>
            <span>
              <small>Location</small>
              {shipment.statusLocation || "—"}
            </span>
            <span>
              <small>Expected delivery</small>
              {shipment.expectedDelivery || "—"}
            </span>
            <span>
              <small>Route</small>
              {[shipment.origin, shipment.destination].filter(Boolean).join(" → ") || "—"}
            </span>
            <span>
              <small>Last synced</small>
              {formatScanTime(shipment.lastSyncedAt)}
            </span>
          </div>
          {shipment.lastError && <p className="shipment-warning">{shipment.lastError}</p>}
          <ShipmentScans scans={shipment.scans} />
        </div>
      ))}
    </div>
  );
}
