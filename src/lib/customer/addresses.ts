import { getSupabaseClient } from '@/lib/supabase/client'
import { COUNTRIES, DEFAULT_COUNTRY_ISO, parsePhone } from '@/lib/auth/phone'
import type { Database } from '@/lib/supabase/database.types'

/**
 * Saved delivery addresses and the delivery details recorded on an order.
 *
 * These are two separate things. A saved address (public.addresses) can change at
 * any time. orders.shipping_address is a copy place_order_v3() took when the order
 * was placed: it is the only source for an order's delivery details, so nothing
 * here ever joins an order to a saved address.
 *
 * Saving goes through RPCs, which take the customer from the session and keep one
 * default per customer. The database repeats every rule below; these checks exist
 * so the customer hears about a mistake beside the field.
 */

type AddressRow = Database['public']['Tables']['addresses']['Row']

export interface SavedAddress {
  id: string
  label: string
  recipientName: string
  phone: string
  countryCode: string
  province: string
  district: string
  city: string
  line1: string
  line2: string
  landmark: string
  postalCode: string
  deliveryInstructions: string
  isDefault: boolean
}

export const ADDRESS_LABELS = ['Home', 'Work', 'Other'] as const

function fromRow(row: AddressRow): SavedAddress {
  return {
    id: row.id,
    label: row.label ?? '',
    recipientName: row.recipient_name ?? '',
    phone: row.phone ?? '',
    countryCode: row.country_code,
    province: row.province ?? '',
    district: row.district ?? '',
    city: row.city,
    line1: row.line1,
    line2: row.line2 ?? '',
    landmark: row.landmark ?? '',
    postalCode: row.postal_code ?? '',
    deliveryInstructions: row.delivery_instructions ?? '',
    isDefault: row.is_default,
  }
}

/** Rows older than this feature may lack these, and cannot be delivered to until completed. */
export function isAddressComplete(address: SavedAddress): boolean {
  return Boolean(address.recipientName && address.phone && address.province && address.district)
}

/** The signed-in customer's addresses, default first. "addresses own all" scopes the read. */
export async function listMyAddresses(): Promise<SavedAddress[]> {
  const { data, error } = await getSupabaseClient()
    .from('addresses')
    .select('*')
    .order('is_default', { ascending: false })
    .order('updated_at', { ascending: false })
  if (error) throw error
  return (data ?? []).map(fromRow)
}

export interface DeliveryProvince {
  name: string
  districts: string[]
}

let regionsRequest: Promise<DeliveryProvince[]> | null = null

/**
 * Provinces and districts from public.delivery_regions, so the form and the
 * database's check share one list. Fetched once per app session.
 */
export function loadDeliveryRegions(): Promise<DeliveryProvince[]> {
  if (regionsRequest) return regionsRequest
  regionsRequest = (async () => {
    const { data, error } = await getSupabaseClient()
      .from('delivery_regions')
      .select('province, district')
      .eq('country_code', DEFAULT_COUNTRY_ISO)
      .order('province')
      .order('district')
    if (error) throw error
    const provinces = new Map<string, string[]>()
    for (const row of data ?? []) {
      provinces.set(row.province, [...(provinces.get(row.province) ?? []), row.district])
    }
    return Array.from(provinces, ([name, districts]) => ({ name, districts }))
  })()
  // A failed read is not kept, so reopening the form tries again.
  regionsRequest.catch(() => { regionsRequest = null })
  return regionsRequest
}

export interface AddressInput {
  label: string
  recipientName: string
  phoneIso: string
  phoneNational: string
  province: string
  district: string
  city: string
  line1: string
  line2: string
  landmark: string
  postalCode: string
  deliveryInstructions: string
  makeDefault: boolean
}

export type AddressErrors = Partial<Record<keyof AddressInput, string>>

export function validateAddress(input: AddressInput): AddressErrors {
  const errors: AddressErrors = {}
  if (!input.recipientName.trim()) errors.recipientName = 'Enter the name of the person receiving the delivery.'
  else if (input.recipientName.trim().length > 100) errors.recipientName = 'The name is limited to 100 characters.'

  const phone = parsePhone(input.phoneIso, input.phoneNational)
  if (!phone.ok) errors.phoneNational = phone.reason
  else if (phone.e164.startsWith('+94') && phone.e164.length !== 12) {
    errors.phoneNational = 'A Sri Lankan number has nine digits after the leading 0.'
  }

  if (!input.province) errors.province = 'Choose a province.'
  if (!input.district) errors.district = 'Choose a district.'
  if (!input.city.trim()) errors.city = 'Enter your city or town.'
  else if (input.city.trim().length > 100) errors.city = 'The city or town is limited to 100 characters.'
  if (!input.line1.trim()) errors.line1 = 'Enter your house number and street.'
  else if (input.line1.trim().length > 200) errors.line1 = 'The street address is limited to 200 characters.'
  if (input.line2.trim().length > 200) errors.line2 = 'This line is limited to 200 characters.'
  if (input.landmark.trim().length > 200) errors.landmark = 'The landmark is limited to 200 characters.'
  if (input.postalCode.trim() && !/^\d{5}$/.test(input.postalCode.trim())) {
    errors.postalCode = 'A Sri Lankan postal code has five digits.'
  }
  if (input.deliveryInstructions.trim().length > 500) {
    errors.deliveryInstructions = 'Delivery instructions are limited to 500 characters.'
  }
  return errors
}

/** Saves a new address (id null) or an edit, returning its id. Validate first. */
export async function saveAddress(id: string | null, input: AddressInput): Promise<string> {
  const phone = parsePhone(input.phoneIso, input.phoneNational)
  const { data, error } = await getSupabaseClient().rpc('save_address', {
    p_id: id,
    p_label: input.label,
    p_recipient_name: input.recipientName,
    p_phone: phone.ok ? phone.e164 : input.phoneNational,
    p_province: input.province,
    p_district: input.district,
    p_city: input.city,
    p_line1: input.line1,
    p_line2: input.line2,
    p_landmark: input.landmark,
    p_postal_code: input.postalCode,
    p_delivery_instructions: input.deliveryInstructions,
    p_make_default: input.makeDefault,
  })
  if (error) throw new Error(describeAddressError(error.message))
  return data
}

export async function setDefaultAddress(id: string): Promise<void> {
  const { error } = await getSupabaseClient().rpc('set_default_address', { p_id: id })
  if (error) throw new Error(describeAddressError(error.message))
}

export async function deleteAddress(id: string): Promise<void> {
  const { error } = await getSupabaseClient().rpc('delete_address', { p_id: id })
  if (error) throw new Error(describeAddressError(error.message))
}

/** The database raises '<code>: <detail>'. Validation details are already plain sentences. */
export function describeAddressError(message: string): string {
  if (message.includes('Could not find the function')) {
    return 'Saved addresses are not available yet. Please contact us to place your order.'
  }
  const separator = message.indexOf(':')
  const code = separator === -1 ? message : message.slice(0, separator).trim()
  const detail = separator === -1 ? '' : message.slice(separator + 1).trim()
  switch (code) {
    case 'not_authenticated': return 'Please sign in again to manage your addresses.'
    case 'address_duplicate': return 'You have already saved this address. Choose it from your list instead.'
    case 'address_not_found': return 'That address is no longer in your account. Please refresh and try again.'
    case 'address_limit_reached':
    case 'invalid_address':
    case 'invalid_phone':
    case 'invalid_region':
    case 'invalid_postal_code': return detail.charAt(0).toUpperCase() + detail.slice(1) + '.'
    default: return 'Your address could not be saved. Please try again.'
  }
}

/** The delivery details recorded on an order: exactly the keys place_order_v3() writes. */
export interface DeliverySnapshot {
  label: string
  recipientName: string
  contactNumber: string
  country: string
  province: string
  district: string
  city: string
  addressLine1: string
  addressLine2: string
  landmark: string
  postalCode: string
  deliveryInstructions: string
}

/** Null for an order placed before addresses were recorded. */
export function parseDeliverySnapshot(value: unknown): DeliverySnapshot | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null
  const raw = value as Record<string, unknown>
  const text = (key: string) => (typeof raw[key] === 'string' ? raw[key] as string : '')
  if (!text('address_line_1')) return null
  return {
    label: text('label'),
    recipientName: text('recipient_name'),
    contactNumber: text('contact_number'),
    country: text('country'),
    province: text('province'),
    district: text('district'),
    city: text('city'),
    addressLine1: text('address_line_1'),
    addressLine2: text('address_line_2'),
    landmark: text('landmark'),
    postalCode: text('postal_code'),
    deliveryInstructions: text('delivery_instructions'),
  }
}

/** The place, in the form an address is written here: "Kinniya, Trincomalee". */
export function deliveryPlace(address: { city: string; district: string }): string {
  return [address.city, address.district].filter(Boolean).join(', ')
}

/** Plain text for staff to paste into a courier booking or a message. */
export function formatDeliveryForCopy(snapshot: DeliverySnapshot): string {
  return [
    snapshot.recipientName,
    snapshot.contactNumber,
    snapshot.addressLine1,
    snapshot.addressLine2,
    snapshot.landmark && `Landmark: ${snapshot.landmark}`,
    [deliveryPlace(snapshot), snapshot.postalCode].filter(Boolean).join(' '),
    snapshot.province,
    snapshot.country,
    snapshot.deliveryInstructions && `Instructions: ${snapshot.deliveryInstructions}`,
  ].filter(Boolean).join('\n')
}

/** Splits a stored E.164 number back into the form's country and national number. */
export function splitPhone(e164: string): { iso: string; national: string } {
  const digits = e164.replace(/^\+/, '')
  const match = COUNTRIES
    .filter((c) => digits.startsWith(c.dial))
    .sort((a, b) => b.dial.length - a.dial.length)[0]
  if (!match) return { iso: DEFAULT_COUNTRY_ISO, national: '' }
  const national = digits.slice(match.dial.length)
  return { iso: match.iso, national: match.iso === 'LK' ? `0${national}` : national }
}
