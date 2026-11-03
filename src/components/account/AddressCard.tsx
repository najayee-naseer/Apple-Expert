"use client"

import { AlertCircle, Check, MapPin } from 'lucide-react'
import { formatE164 } from '@/lib/auth/phone'
import {
  deliveryPlace, isAddressComplete, type DeliverySnapshot, type SavedAddress,
} from '@/lib/customer/addresses'

/** The address lines, used for saved addresses before an order and for its copy after. */
function AddressLines({ recipient, line1, line2, landmark, place, province, postalCode, country, phone, instructions }: {
  recipient: string
  line1: string
  line2: string
  landmark: string
  place: string
  province: string
  postalCode: string
  country: string
  phone: string
  instructions: string
}) {
  return (
    <div className="min-w-0 break-words text-[13.5px] leading-relaxed text-foreground">
      {recipient && <p className="font-semibold">{recipient}</p>}
      <p>{line1}</p>
      {line2 && <p>{line2}</p>}
      <p>{place}{postalCode && ` ${postalCode}`}</p>
      {province && <p>{province}</p>}
      <p>{country}</p>
      {landmark && <p className="mt-1 text-[12.5px] text-muted-foreground">Landmark: {landmark}</p>}
      {phone && <p className="mt-1 text-[12.5px] text-muted-foreground">Contact: {formatE164(phone)}</p>}
      {instructions && <p className="text-[12.5px] text-muted-foreground">Instructions: {instructions}</p>}
    </div>
  )
}

export function SavedAddressLines({ address }: { address: SavedAddress }) {
  return (
    <AddressLines
      recipient={address.recipientName} line1={address.line1} line2={address.line2} landmark={address.landmark}
      place={deliveryPlace(address)} province={address.province} postalCode={address.postalCode}
      country={address.countryCode === 'LK' ? 'Sri Lanka' : address.countryCode}
      phone={address.phone} instructions={address.deliveryInstructions}
    />
  )
}

export function DeliverySnapshotLines({ snapshot }: { snapshot: DeliverySnapshot }) {
  return (
    <AddressLines
      recipient={snapshot.recipientName} line1={snapshot.addressLine1} line2={snapshot.addressLine2} landmark={snapshot.landmark}
      place={deliveryPlace(snapshot)} province={snapshot.province} postalCode={snapshot.postalCode}
      country={snapshot.country} phone={snapshot.contactNumber} instructions={snapshot.deliveryInstructions}
    />
  )
}

export function AddressHeading({ address }: { address: SavedAddress }) {
  return (
    <div className="mb-1.5 flex flex-wrap items-center gap-2">
      <span className="inline-flex items-center gap-1.5 text-[11px] font-bold uppercase tracking-[0.12em] text-muted-foreground">
        <MapPin size={13} className="text-primary" /> {address.label || 'Address'}
      </span>
      {address.isDefault && (
        <span className="inline-flex items-center gap-1 rounded-full border border-mint-deep bg-primary-soft px-2 py-0.5 text-[11px] font-semibold text-primary">
          <Check size={11} strokeWidth={3} /> Default address
        </span>
      )}
    </div>
  )
}

/** Shown for a row saved before these fields existed. */
export function IncompleteNote({ address }: { address: SavedAddress }) {
  if (isAddressComplete(address)) return null
  return (
    <p className="mt-2 flex items-start gap-1.5 text-[12.5px] text-amber-700 dark:text-amber-400">
      <AlertCircle size={14} className="mt-0.5 shrink-0" />
      Some details are missing. Edit this address to deliver to it.
    </p>
  )
}
