"use client"

import { useId } from 'react'
import { COUNTRIES, findCountry } from '@/lib/auth/phone'

/**
 * Country + national number, the way every SMS sign-in worth using asks for it.
 *
 * The two parts stay separate all the way to `parsePhone`, so the customer can
 * type their number exactly as they write it locally (071 234 5678) while the
 * provider still receives strict E.164.
 */
export function PhoneField({
  iso, onIsoChange, national, onNationalChange, disabled = false, autoFocus = false,
  label = 'Phone number', hint, invalid = false, describedBy,
}: {
  iso: string
  onIsoChange: (iso: string) => void
  national: string
  onNationalChange: (national: string) => void
  disabled?: boolean
  autoFocus?: boolean
  label?: string
  /** Replaces the line about the sign-in code, for numbers that receive no code. */
  hint?: string
  invalid?: boolean
  /** The id of an error message shown below the field, so it is read with it. */
  describedBy?: string
}) {
  const id = useId()
  const country = findCountry(iso)

  return (
    <div>
      <label htmlFor={id} className="mb-1.5 block text-[13px] font-semibold text-foreground">
        {label}
      </label>

      <div className="flex gap-2">
        <select
          value={iso}
          onChange={(e) => onIsoChange(e.target.value)}
          disabled={disabled}
          aria-label="Country"
          className="focus-ring h-12 w-[104px] shrink-0 rounded-2xl border border-mint-deep dark:border-border bg-card px-2.5 text-sm font-semibold text-foreground transition-colors focus:border-primary/45 focus:outline-none disabled:opacity-60"
        >
          {COUNTRIES.map((c) => (
            <option key={c.iso} value={c.iso}>
              {c.iso} +{c.dial}
            </option>
          ))}
        </select>

        <div className="relative flex-1">
          <span
            aria-hidden="true"
            className="pointer-events-none absolute inset-y-0 left-0 flex w-12 items-center justify-center text-sm font-semibold text-muted-foreground"
          >
            +{country.dial}
          </span>
          <input
            id={id}
            type="tel"
            inputMode="tel"
            autoComplete="tel-national"
            autoFocus={autoFocus}
            aria-invalid={invalid}
            aria-describedby={describedBy}
            value={national}
            onChange={(e) => onNationalChange(e.target.value)}
            disabled={disabled}
            placeholder={country.example}
            className="focus-ring h-12 w-full rounded-2xl border border-mint-deep dark:border-border bg-card pl-12 pr-4 text-sm tabular-nums text-foreground transition-colors placeholder:text-muted-foreground focus:border-primary/45 focus:outline-none disabled:opacity-60"
          />
        </div>
      </div>

      <p className="mt-1.5 text-[12px] text-muted-foreground">
        {hint ?? <>{country.name} · we will text you a {'6'}-digit code.</>}
      </p>
    </div>
  )
}
