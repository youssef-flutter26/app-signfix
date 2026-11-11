import React from "react";
import { storeIcons } from "./BrandIcons";
import { appLinks } from "../../lib/site-config";

/**
 * The Apple mark is square (24x24) while the Google Play mark is slightly
 * taller than it is wide (256x283), so both are sized from a shared height
 * and each keeps its own aspect ratio.
 */
function iconSize(isPlay, size) {
  if (isPlay) {
    return { width: Math.round(((size * 256) / 283) * 10) / 10, height: size };
  }
  return { width: size, height: size };
}

/**
 * App download buttons.
 *
 * Both stores are always rendered — there is no device, platform or
 * user-agent detection, so an Android user also sees the App Store button
 * and vice versa.
 *
 * `compact` (navbar): icon + label from `xl` up, icon-only below, with the
 *   accessible name carried by `aria-label` (plus `title` for a tooltip).
 * `full` (mobile drawer): always shows the label, stacked full width.
 *
 * Surface, shadow, hover and press states live in `styles.css`
 * (`.app-store-btn`). There is no looping animation — the buttons stay
 * still until the user hovers, presses or tabs to them.
 */
export function AppStoreButtons({ className = "", full = false }) {
  const size = full ? 19 : 16;

  return (
    <div
      className={
        full
          ? `flex flex-col gap-2.5 ${className}`
          : `flex items-center gap-1.5 sm:gap-2 ${className}`
      }
    >
      {appLinks.map((app) => {
        const Icon = storeIcons[app.id];
        if (!Icon) return null;
        return (
          <a
            key={app.id}
            href={app.url}
            target="_blank"
            rel="noopener noreferrer"
            aria-label={app.ariaLabel}
            title={app.ariaLabel}
            className={
              full
                ? `app-store-btn app-store-btn--full flex items-center justify-center gap-2.5 px-4 py-3.5 font-display font-semibold text-sm text-ink`
                : `app-store-btn inline-flex h-9 sm:h-10 items-center gap-1.5 px-2 text-ink`
            }
          >
            <Icon className="app-store-icon" {...iconSize(app.id === "google-play", size)} />
            {full ? (
              <span>{app.label}</span>
            ) : (
              <span className="hidden xl:inline font-display font-bold text-[10px] tracking-wide uppercase whitespace-nowrap">
                {app.label}
              </span>
            )}
          </a>
        );
      })}
    </div>
  );
}
