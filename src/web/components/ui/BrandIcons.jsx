import React from "react";

/**
 * Store brand marks.
 *
 * These are the official brand glyphs (Apple logo + the four-colour Google
 * Play mark), inlined as local SVG so there is no network dependency and no
 * new icon-library dependency. The accessible name always comes from the
 * surrounding link's `aria-label`, so every glyph here is decorative.
 */

const glyphBase = {
  xmlns: "http://www.w3.org/2000/svg",
  focusable: "false",
  "aria-hidden": "true",
};

/** Apple logo — single colour, inherits the surrounding text colour. */
export function AppleLogo({ className = "", ...rest }) {
  return (
    <svg
      {...glyphBase}
      viewBox="0 0 24 24"
      className={className}
      {...rest}
    >
      <path
        fill="currentColor"
        d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04c-2.04.027-3.91 1.183-4.961 3.014c-2.117 3.675-.546 9.103 1.519 12.09c1.013 1.454 2.208 3.09 3.792 3.039c1.52-.065 2.09-.987 3.935-.987c1.831 0 2.35.987 3.96.948c1.637-.026 2.676-1.48 3.676-2.948c1.156-1.688 1.636-3.325 1.662-3.415c-.039-.013-3.182-1.221-3.22-4.857c-.026-3.04 2.48-4.494 2.597-4.559c-1.429-2.09-3.623-2.324-4.39-2.376c-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83c-1.207.052-2.662.805-3.532 1.818c-.78.896-1.454 2.338-1.273 3.714c1.338.104 2.715-.688 3.559-1.701"
      />
    </svg>
  );
}

/** Google Play mark — official four-colour mark, always kept multi-colour. */
export function GooglePlayLogo({ className = "", ...rest }) {
  return (
    <svg
      {...glyphBase}
      viewBox="0 0 256 283"
      className={className}
      {...rest}
    >
      <path
        fill="#ea4335"
        d="M119.553 134.916L1.06 259.061a32.14 32.14 0 0 0 47.062 19.071l133.327-75.934z"
      />
      <path
        fill="#fbbc04"
        d="M239.37 113.814L181.715 80.79l-64.898 56.95l65.162 64.28l57.216-32.67a31.345 31.345 0 0 0 0-55.537z"
      />
      <path
        fill="#4285f4"
        d="M1.06 23.487A30.6 30.6 0 0 0 0 31.61v219.327a32.3 32.3 0 0 0 1.06 8.124l122.555-120.966z"
      />
      <path
        fill="#34a853"
        d="m120.436 141.274l61.278-60.483L48.564 4.503A32.85 32.85 0 0 0 32.051 0C17.644-.028 4.978 9.534 1.06 23.399z"
      />
    </svg>
  );
}

export const storeIcons = {
  "app-store": AppleLogo,
  "google-play": GooglePlayLogo,
};
