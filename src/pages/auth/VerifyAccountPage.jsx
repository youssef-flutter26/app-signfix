import React, { useEffect, useMemo, useState } from 'react';
import { ArrowLeft, CheckCircle2, Mail } from 'lucide-react';
import { post } from '../../api/client';

function maskIdentifier(value) {
  const raw = String(value || '').trim();
  const digits = raw.replace(/\D/g, '');
  if (digits.length >= 10) {
    const normalized = digits.length === 10 ? `91${digits}` : digits;
    return `+${normalized.slice(0, 2)} ${'X'.repeat(Math.max(0, normalized.length - 6))}${normalized.slice(-4)}`;
  }
  if (raw.includes('@')) {
    const [name, domain] = raw.split('@');
    return `${name.slice(0, 2)}${'*'.repeat(Math.max(1, name.length - 2))}@${domain}`;
  }
  return raw;
}

export default function VerifyAccountPage({ navigate }) {
  const params = useMemo(() => new URLSearchParams(window.location.search), []);
  const [identifier, setIdentifier] = useState(params.get('identifier') || '');
  const [purpose, setPurpose] = useState(params.get('purpose') || 'verify_registration');
  const [otp, setOtp] = useState('');
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  const [resending, setResending] = useState(false);
  const [seconds, setSeconds] = useState(0);

  useEffect(() => {
    if (!seconds) return undefined;
    const timer = window.setInterval(() => setSeconds((value) => Math.max(0, value - 1)), 1000);
    return () => window.clearInterval(timer);
  }, [seconds]);

  function updateUrl(nextIdentifier = identifier, nextPurpose = purpose) {
    const query = new URLSearchParams({ identifier: nextIdentifier, purpose: nextPurpose });
    window.history.replaceState({}, '', `/verify-account?${query.toString()}`);
  }

  async function verify(event) {
    event.preventDefault();
    setError('');
    setMessage('');
    if (!identifier.trim()) return setError('Email address is required.');
    if (!/^\d{6}$/.test(otp)) return setError('Enter the 6-digit OTP.');
    setBusy(true);
    try {
      const result = await post('/api/auth/verify-otp', { identifier: identifier.trim(), otp, purpose });
      setMessage(purpose === 'reset_password' ? 'OTP verified successfully. You can now continue with password reset.' : 'Account verified successfully.');
      setOtp('');
      window.setTimeout(() => navigate('/login'), 700);
    } catch (requestError) {
      setError(requestError.message || 'Invalid or expired OTP.');
    } finally {
      setBusy(false);
    }
  }

  async function resend() {
    if (seconds > 0 || resending || !identifier.trim()) return;
    setError('');
    setMessage('');
    setResending(true);
    try {
      const result = await post('/api/auth/resend-registration-otp', { identifier: identifier.trim(), purpose });
      if (result.identifier) setIdentifier(result.identifier);
      setMessage('A new OTP has been sent to your email address.');
      setSeconds(30);
      updateUrl(result.identifier || identifier, purpose);
    } catch (requestError) {
      setError(requestError.message || 'Unable to resend OTP.');
    } finally {
      setResending(false);
    }
  }

  return (
    <div className="verify-page">
      <header className="verify-header">
        <button className="verify-back" type="button" onClick={() => navigate('/login')} aria-label="Go back">
          <ArrowLeft size={34} strokeWidth={2.2} />
        </button>
        <h1>Verify Account</h1>
      </header>

      <main className="verify-main">
        <section className="verify-card">
          <div className="verify-icon"><Mail size={34} strokeWidth={2.1} /></div>
          <h2>Enter verification code</h2>
          <p className="verify-description">
            We sent a 6-digit OTP to<br />
            <strong>{maskIdentifier(identifier) || 'your email address'}</strong> via email.
          </p>

          {!params.get('identifier') && (
            <label className="verify-field verify-mobile-field">
              Email address
              <input value={identifier} onChange={(event) => setIdentifier(event.target.value)} placeholder="you@example.com" inputMode="email" autoComplete="email" />
            </label>
          )}

          <form onSubmit={verify}>
            <label className="verify-field">
              <span className="sr-only">OTP</span>
              <input
                value={otp}
                onChange={(event) => setOtp(event.target.value.replace(/\D/g, '').slice(0, 6))}
                placeholder="OTP"
                inputMode="numeric"
                autoComplete="one-time-code"
                maxLength={6}
                autoFocus
                aria-label="6-digit OTP"
              />
            </label>

            {error && <div className="verify-error" role="alert">{error}</div>}
            {message && <div className="verify-success"><CheckCircle2 size={18} />{message}</div>}

            <button className="verify-submit" type="submit" disabled={busy}>
              <CheckCircle2 size={24} fill="currentColor" />
              {busy ? 'Verifying…' : 'Verify & Continue'}
            </button>
          </form>

          <button className="verify-resend" type="button" onClick={resend} disabled={seconds > 0 || resending || !identifier.trim()}>
            {resending ? 'Sending OTP…' : seconds > 0 ? `Resend OTP in ${seconds}s` : 'Resend OTP'}
          </button>
        </section>
      </main>
    </div>
  );
}
