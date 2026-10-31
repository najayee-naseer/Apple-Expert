import { code128Modules, code128Widths } from './code128'
import type { UnitView } from './units'

/**
 * Barcode labels for received units — one sticker per physical item.
 *
 * Each label carries:
 *   - the product name and variant (what the item is)
 *   - a QR code holding the unit barcode (phone cameras read it)
 *   - a Code 128 barcode of the same value (USB / Bluetooth counter scanners
 *     read it) with the value printed underneath
 *   - the IMEI / serial number when the unit has one
 *
 * Everything is drawn as vectors except the QR, so the bars stay sharp on any
 * printer. jsPDF and qrcode are loaded only when a label is actually printed.
 */

export type LabelLayout = 'sticker' | 'a4'

export const LABEL_LAYOUTS: { value: LabelLayout; label: string; hint: string }[] = [
  { value: 'sticker', label: 'Sticker printer · 50 × 30 mm', hint: 'One label per page, for a thermal label printer.' },
  { value: 'a4', label: 'A4 sheet · 3 × 8 labels', hint: '24 labels per A4 page, for an office printer and sticker sheets.' },
]

export interface LabelItem {
  barcode: string
  serial: string | null
  title: string
  subtitle: string | null
}

export function unitToLabel(unit: UnitView): LabelItem {
  return {
    barcode: unit.barcode,
    serial: unit.serial_number,
    title: unit.productName,
    subtitle: unit.variantName,
  }
}

const LABEL_W = 50
const LABEL_H = 30

type PdfDoc = import('jspdf').jsPDF

async function qrDataUrl(text: string): Promise<string> {
  const QRCode = (await import('qrcode')).default
  return QRCode.toDataURL(text, { margin: 0, errorCorrectionLevel: 'M', width: 240 })
}

/** Draws a Code 128 barcode filling `width` mm, with the quiet zone inside it. */
function drawCode128(doc: PdfDoc, text: string, x: number, y: number, width: number, height: number) {
  const quiet = 10
  const modules = code128Modules(text) + quiet * 2
  const moduleMm = width / modules
  let cursor = x + quiet * moduleMm
  let bar = true
  doc.setFillColor(0, 0, 0)
  for (const w of code128Widths(text)) {
    if (bar) doc.rect(cursor, y, w * moduleMm, height, 'F')
    cursor += w * moduleMm
    bar = !bar
  }
}

/** Cuts text to fit `maxWidth` mm at the current font size. */
function fit(doc: PdfDoc, text: string, maxWidth: number): string {
  if (doc.getTextWidth(text) <= maxWidth) return text
  let cut = text
  while (cut.length > 1 && doc.getTextWidth(cut + '…') > maxWidth) cut = cut.slice(0, -1)
  return cut.trimEnd() + '…'
}

/** One 50 × 30 mm label with its top-left corner at (x, y). */
async function drawLabel(doc: PdfDoc, item: LabelItem, x: number, y: number) {
  const pad = 2
  const qrSize = 13

  // QR, top-left.
  doc.addImage(await qrDataUrl(item.barcode), 'PNG', x + pad, y + pad, qrSize, qrSize)

  // Name, variant, IMEI to the right of the QR.
  const textX = x + pad + qrSize + 2
  const textW = LABEL_W - (textX - x) - pad
  doc.setTextColor(0, 0, 0)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(7.5)
  doc.text(fit(doc, item.title, textW), textX, y + pad + 3)
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(6.5)
  if (item.subtitle) doc.text(fit(doc, item.subtitle, textW), textX, y + pad + 6.2)
  if (item.serial) {
    doc.setFontSize(6)
    doc.text(fit(doc, `IMEI/SN ${item.serial}`, textW), textX, y + pad + 9.4)
  }
  doc.setFontSize(5.5)
  doc.text('Apple Expert', textX, y + pad + 12.6)

  // Code 128 across the bottom, value underneath.
  const barTop = y + pad + qrSize + 1.5
  drawCode128(doc, item.barcode, x + pad, barTop, LABEL_W - pad * 2, 7.5)
  doc.setFont('courier', 'bold')
  doc.setFontSize(7)
  doc.text(item.barcode, x + LABEL_W / 2, barTop + 10, { align: 'center' })
}

/**
 * A label for a quantity-tracked item, which has no barcode in the database. It
 * deliberately carries no code of any kind: nothing could resolve it at the counter.
 */
export interface ShelfLabelItem {
  title: string
  subtitle: string | null
  reference: string
}

function drawShelfLabel(doc: PdfDoc, item: ShelfLabelItem, x: number, y: number) {
  const pad = 3
  const width = LABEL_W - pad * 2
  doc.setTextColor(0, 0, 0)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(10)
  const titleLines = (doc.splitTextToSize(item.title, width) as string[]).slice(0, 2)
  doc.text(titleLines, x + pad, y + pad + 3.5)
  let cursor = y + pad + 3.5 + titleLines.length * 4.2
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(8)
  if (item.subtitle) {
    doc.text(fit(doc, item.subtitle, width), x + pad, cursor)
    cursor += 3.6
  }
  doc.setFontSize(6.5)
  doc.text(fit(doc, item.reference, width), x + pad, y + LABEL_H - pad - 2.8)
  doc.setFontSize(5.5)
  doc.text('Apple Expert', x + pad, y + LABEL_H - pad)
}

/** Builds the shelf label PDF and returns it as a Blob. */
export async function buildShelfLabelPdf(items: ShelfLabelItem[], layout: LabelLayout): Promise<Blob> {
  return renderLabels(items, layout, drawShelfLabel)
}

/** Builds the barcode label PDF and returns it as a Blob. */
export async function buildLabelPdf(items: LabelItem[], layout: LabelLayout): Promise<Blob> {
  return renderLabels(items, layout, drawLabel)
}

/** Places one label per sticker page, or 24 per A4 sheet with light cut marks. */
async function renderLabels<T>(
  items: T[],
  layout: LabelLayout,
  draw: (doc: PdfDoc, item: T, x: number, y: number) => void | Promise<void>,
): Promise<Blob> {
  if (items.length === 0) throw new Error('There are no labels to print.')
  const { jsPDF } = await import('jspdf')

  if (layout === 'sticker') {
    const doc = new jsPDF({ unit: 'mm', format: [LABEL_W, LABEL_H], orientation: 'landscape' })
    for (let i = 0; i < items.length; i++) {
      if (i > 0) doc.addPage([LABEL_W, LABEL_H], 'landscape')
      await draw(doc, items[i], 0, 0)
    }
    return doc.output('blob')
  }

  // A4: 3 columns x 8 rows of 50 x 30 mm, centred, with light cut marks.
  const doc = new jsPDF({ unit: 'mm', format: 'a4', orientation: 'portrait' })
  const cols = 3
  const rows = 8
  const gapX = 15
  const gapY = 4
  const left = (210 - (cols * LABEL_W + (cols - 1) * gapX)) / 2
  const top = (297 - (rows * LABEL_H + (rows - 1) * gapY)) / 2
  const perPage = cols * rows

  for (let i = 0; i < items.length; i++) {
    const slot = i % perPage
    if (i > 0 && slot === 0) doc.addPage('a4', 'portrait')
    const x = left + (slot % cols) * (LABEL_W + gapX)
    const y = top + Math.floor(slot / cols) * (LABEL_H + gapY)
    doc.setDrawColor(200, 200, 200)
    doc.setLineWidth(0.1)
    doc.rect(x, y, LABEL_W, LABEL_H)
    await draw(doc, items[i], x, y)
  }
  return doc.output('blob')
}

/**
 * Hands a generated PDF to something that can print it.
 *
 * In the APK neither browser route works: Capacitor's WebView has no multi-window
 * support and no download listener, so window.open() just navigates the app away
 * to a blob it cannot render, and an <a download> does nothing. There the file is
 * written to the app's cache and offered through the system share sheet, from
 * which a PDF viewer, a print service or a label printer's app can take it. Plugins
 * load only on the device, so the web bundle does not carry them.
 *
 * Throws if the native route fails, so the screen can say so.
 */
export async function openPdf(blob: Blob, fileName: string): Promise<void> {
  const { Capacitor } = await import('@capacitor/core')
  if (Capacitor.isNativePlatform()) {
    const [{ Filesystem, Directory }, { Share }] = await Promise.all([
      import('@capacitor/filesystem'),
      import('@capacitor/share'),
    ])
    const { uri } = await Filesystem.writeFile({
      path: fileName.replace(/[^A-Za-z0-9._-]/g, '_'),
      data: await blobToBase64(blob),
      directory: Directory.Cache,
    })
    try {
      await Share.share({ title: fileName, files: [uri], dialogTitle: 'Print or save' })
    } catch (err) {
      // Closing the share sheet without choosing anything is not a failure.
      if (!(err instanceof Error && /cancel/i.test(err.message))) throw err
    }
    return
  }

  const url = URL.createObjectURL(blob)
  const tab = window.open(url, '_blank')
  if (!tab) {
    const a = document.createElement('a')
    a.href = url
    a.download = fileName
    document.body.appendChild(a)
    a.click()
    a.remove()
  }
  // Give the viewer time to load before the URL is released.
  window.setTimeout(() => URL.revokeObjectURL(url), 60_000)
}

function blobToBase64(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onerror = () => reject(reader.error ?? new Error('The PDF could not be read.'))
    reader.onload = () => resolve(String(reader.result).split(',')[1] ?? '')
    reader.readAsDataURL(blob)
  })
}
