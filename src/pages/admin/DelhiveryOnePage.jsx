import React, { useEffect, useState } from "react";
import { Calculator, RefreshCw, Wallet } from "lucide-react";
import { get, post } from "../../api/client";

function money(value) {
  const amount = Number(value || 0);
  return Number.isFinite(amount) ? `₹${amount.toFixed(2)}` : "—";
}

export default function DelhiveryOnePage() {
  const [wallet, setWallet] = useState(null),
    [walletError, setWalletError] = useState(""),
    [loadingWallet, setLoadingWallet] = useState(false),
    [rates, setRates] = useState([]),
    [ratesError, setRatesError] = useState(""),
    [checking, setChecking] = useState(false),
    [compare, setCompare] = useState(true);
  async function loadWallet() {
    setLoadingWallet(true);
    try {
      setWallet(await get("/api/delhivery-one/wallet"));
      setWalletError("");
    } catch (e) {
      setWallet(null);
      setWalletError(e.message);
    } finally {
      setLoadingWallet(false);
    }
  }
  useEffect(() => {
    loadWallet();
  }, []);
  async function checkRates(e) {
    e.preventDefault();
    const f = new FormData(e.currentTarget),
      base = {
        origin_pin: String(f.get("originPin")).trim(),
        destination_pin: String(f.get("destinationPin")).trim(),
        weight: Number(f.get("weight")),
        weight_unit: f.get("weightUnit"),
        payment_mode: f.get("paymentMode"),
        length: Number(f.get("length")) || undefined,
        breadth: Number(f.get("breadth")) || undefined,
        height: Number(f.get("height")) || undefined,
        packaging_type: f.get("packagingType") || undefined,
      },
      modes = compare ? ["SURFACE", "EXPRESS"] : [f.get("shippingMode")],
      requests = modes.map((shipping_mode) => ({ ...base, shipping_mode }));
    setChecking(true);
    try {
      const result = await post("/api/delhivery-one/rates", { requests });
      setRates(result.responses || []);
      setRatesError("");
    } catch (err) {
      setRates([]);
      setRatesError(err.message);
    } finally {
      setChecking(false);
    }
  }
  return (
    <section className="content">
      <div className="headline">
        <div>
          <p>LOGISTICS</p>
          <h1>Delhivery One</h1>
          <small>
            Prepaid wallet balance and B2C rate estimates for the connected
            Delhivery One account.
          </small>
        </div>
        <button className="outline" disabled={loadingWallet} onClick={loadWallet}>
          <RefreshCw size={15} />
          Refresh wallet
        </button>
      </div>
      <article className="card profile-section">
        <div className="panel-heading">
          <div>
            <h2>
              <Wallet size={16} /> Wallet
            </h2>
            <p>Live prepaid balance used for Delhivery shipments.</p>
          </div>
        </div>
        {walletError && <div className="auth-error">{walletError}</div>}
        {wallet ? (
          <div className="shipment-facts">
            <span>
              <small>Current balance</small>
              {money(wallet.current_balance)}
            </span>
            <span>
              <small>Status</small>
              {wallet.is_active ? "Active" : "Inactive"}
            </span>
            <span>
              <small>Payment gateway</small>
              {wallet.payment_gateway || "—"}
            </span>
          </div>
        ) : (
          !walletError && <p className="empty-copy">Loading wallet…</p>
        )}
      </article>
      <article className="card profile-section">
        <div className="panel-heading">
          <div>
            <h2>
              <Calculator size={16} /> Rate checker
            </h2>
            <p>Estimate SURFACE / EXPRESS charges before creating a shipment.</p>
          </div>
        </div>
        <form className="order-editor" onSubmit={checkRates}>
          <div className="order-form-grid">
            <label>
              Origin PIN
              <input name="originPin" inputMode="numeric" maxLength={6} required defaultValue="411014" />
            </label>
            <label>
              Destination PIN
              <input name="destinationPin" inputMode="numeric" maxLength={6} required placeholder="e.g. 600017" />
            </label>
            <label>
              Weight
              <input name="weight" type="number" step="any" min="1" required defaultValue={500} />
            </label>
            <label>
              Weight unit
              <select name="weightUnit" defaultValue="GM">
                <option value="GM">Grams</option>
                <option value="KG">Kilograms</option>
              </select>
            </label>
            <label>
              Mode
              <select name="shippingMode" defaultValue="SURFACE" disabled={compare}>
                <option value="SURFACE">Surface</option>
                <option value="EXPRESS">Express</option>
              </select>
            </label>
            <label>
              Payment
              <select name="paymentMode" defaultValue="PREPAID">
                <option value="PREPAID">Prepaid</option>
                <option value="COD">COD</option>
              </select>
            </label>
            <label>
              Length (cm)
              <input name="length" type="number" step="any" min="1" required defaultValue={10} />
            </label>
            <label>
              Breadth (cm)
              <input name="breadth" type="number" step="any" min="1" required defaultValue={10} />
            </label>
            <label>
              Height (cm)
              <input name="height" type="number" step="any" min="1" required defaultValue={10} />
            </label>
            <label>
              Packaging
              <select name="packagingType" defaultValue="">
                <option value="">Default</option>
                <option value="FLYER">Flyer</option>
                <option value="BOX">Box</option>
                <option value="CUSTOM">Custom</option>
              </select>
            </label>
            <label className="check-field">
              <input type="checkbox" checked={compare} onChange={(e) => setCompare(e.target.checked)} />
              Compare SURFACE vs EXPRESS
            </label>
          </div>
          <button className="primary" disabled={checking}>
            <Calculator size={16} />
            {checking ? "Checking…" : "Check rates"}
          </button>
        </form>
        {ratesError && <div className="auth-error">{ratesError}</div>}
        {rates.length > 0 && (
          <div className="customer-table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Mode</th>
                  <th>Zone</th>
                  <th>Charged wt (g)</th>
                  <th>Freight</th>
                  <th>Fuel</th>
                  <th>Total (incl. GST)</th>
                </tr>
              </thead>
              <tbody>
                {rates.map((rate) => (
                  <tr key={rate.id}>
                    <td>
                      <b>{String(rate.id).split("_")[0]}</b>
                    </td>
                    <td>{rate.zone || "—"}</td>
                    <td>{rate.charged_weight ?? "—"}</td>
                    <td>{money(rate.freight_cost)}</td>
                    <td>{money(rate.fuel_surcharge)}</td>
                    <td>
                      <b>{money(rate.total_amount)}</b>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </article>
    </section>
  );
}
