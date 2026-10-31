import { centsToRupees } from './pricing'
import { formatPrice } from '@/utils/formatPrice'
import { paymentLabel, formatDateTime, type PosSaleDetail } from './units'

/**
 * The counter bill as an 80 mm receipt PDF (the common thermal receipt
 * width). The page grows with the number of items, so it prints as one strip.
 * Every figure comes from the saved sale — never from the screen — so a
 * reprint is always identical to the bill the customer received.
 */

export interface BillShop {
  name: string
  phone: string | null
  address: string | null
}

const WIDTH = 80
const MARGIN = 5

function money(cents: number): string {
  return formatPrice(centsToRupees(cents))
}

export async function buildBillPdf(detail: PosSaleDetail, shop: BillShop): Promise<Blob> {
  const { jsPDF } = await import('jspdf')
  const { sale, items, cashierName, refundedCents } = detail

  // Height: header + one block per item + totals + footer.
  const itemBlock = (i: (typeof items)[number]) => 9 + (i.serial_snapshot ? 3.4 : 0) + (i.returned_quantity > 0 ? 3.4 : 0)
  const height = 62 + items.reduce((h, i) => h + itemBlock(i), 0)
    + (sale.customer_name || sale.customer_phone ? 8 : 0) + (sale.discount_cents > 0 ? 5 : 0)
    + (refundedCents > 0 ? 10 : 0)

  const doc = new jsPDF({ unit: 'mm', format: [WIDTH, Math.max(height, 90)], orientation: 'portrait' })
  const right = WIDTH - MARGIN
  const inner = WIDTH - MARGIN * 2
  let y = 8

  const line = () => {
    doc.setDrawColor(0, 0, 0)
    doc.setLineDashPattern([0.8, 0.8], 0)
    doc.line(MARGIN, y, right, y)
    doc.setLineDashPattern([], 0)
    y += 4
  }

  doc.setTextColor(0, 0, 0)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(13)
  doc.text(shop.name, WIDTH / 2, y, { align: 'center' })
  y += 5
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(8)
  if (shop.address) {
    for (const part of doc.splitTextToSize(shop.address, inner) as string[]) {
      doc.text(part, WIDTH / 2, y, { align: 'center' })
      y += 3.6
    }
  }
  if (shop.phone) { doc.text(`Tel: ${shop.phone}`, WIDTH / 2, y, { align: 'center' }); y += 3.6 }
  y += 1.5
  line()

  doc.setFontSize(8.5)
  doc.setFont('helvetica', 'bold')
  doc.text(`Bill ${sale.bill_number}`, MARGIN, y)
  doc.setFont('helvetica', 'normal')
  doc.text(formatDateTime(sale.created_at), right, y, { align: 'right' })
  y += 4
  if (cashierName) { doc.text(`Cashier: ${cashierName}`, MARGIN, y); y += 4 }
  if (sale.customer_name || sale.customer_phone) {
    doc.text(`Customer: ${[sale.customer_name, sale.customer_phone].filter(Boolean).join(' · ')}`, MARGIN, y)
    y += 4
  }
  y += 0.5
  line()

  for (const item of items) {
    const name = item.variant_label_snapshot
      ? `${item.product_name_snapshot} · ${item.variant_label_snapshot}`
      : item.product_name_snapshot
    doc.setFont('helvetica', 'bold')
    doc.setFontSize(8.5)
    const nameLines = (doc.splitTextToSize(name, inner - 24) as string[]).slice(0, 2)
    doc.text(nameLines, MARGIN, y)
    doc.text(money(item.line_total_cents), right, y, { align: 'right' })
    y += 3.6 * nameLines.length
    doc.setFont('courier', 'normal')
    doc.setFontSize(7.5)
    doc.text(item.barcode_snapshot ?? `${item.quantity} x ${money(item.unit_price_cents)}`, MARGIN, y)
    y += 3.4
    if (item.serial_snapshot) { doc.text(`IMEI/SN ${item.serial_snapshot}`, MARGIN, y); y += 3.4 }
    if (item.returned_quantity > 0) {
      doc.setFont('helvetica', 'italic')
      doc.text(`${item.returned_quantity} returned${item.returned_at ? ` ${formatDateTime(item.returned_at)}` : ''}`, MARGIN, y)
      y += 3.4
    }
    y += 1.6
  }
  line()

  doc.setFont('helvetica', 'normal')
  doc.setFontSize(9)
  const itemCount = items.reduce((n, i) => n + i.quantity, 0)
  doc.text(`Subtotal (${itemCount} item${itemCount === 1 ? '' : 's'})`, MARGIN, y)
  doc.text(money(sale.subtotal_cents), right, y, { align: 'right' })
  y += 5
  if (sale.discount_cents > 0) {
    doc.text('Discount', MARGIN, y)
    doc.text(`- ${money(sale.discount_cents)}`, right, y, { align: 'right' })
    y += 5
  }
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(11.5)
  doc.text('TOTAL', MARGIN, y)
  doc.text(money(sale.total_cents), right, y, { align: 'right' })
  y += 5.5
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(8.5)
  doc.text(`Paid by ${paymentLabel(sale.payment_method)}`, MARGIN, y)
  y += 6
  // Goods coming back and money going back are separate facts: only a recorded
  // refund appears here.
  if (refundedCents > 0) {
    doc.text('Refunded', MARGIN, y)
    doc.text(`- ${money(refundedCents)}`, right, y, { align: 'right' })
    y += 5
    doc.setFont('helvetica', 'bold')
    doc.text('Net paid', MARGIN, y)
    doc.text(money(sale.total_cents - refundedCents), right, y, { align: 'right' })
    doc.setFont('helvetica', 'normal')
    y += 5
  }

  doc.setFontSize(8)
  doc.text('Thank you for shopping with us!', WIDTH / 2, y, { align: 'center' })
  y += 3.6
  doc.text('Keep this bill for warranty claims.', WIDTH / 2, y, { align: 'center' })

  return doc.output('blob')
}
