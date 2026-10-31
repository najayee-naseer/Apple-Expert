import { code128Modules, code128Widths } from './code128'
import type { UnitView } from './units'

/**
 * Barcode labels for received units — one sticker per physical item.
 *
 * Each label identifies one physical unit and carries:
 *   - the product name and variant (what the item is)
 *   - a QR code holding the unit barcode (phone cameras read it)
 *   - a Code 128 barcode of the same value (USB / Bluetooth counter scanners
 *     read it) with the value printed underneath
 *   - the IMEI / serial number when the unit has one
 *
 * Quantity-tracked items get a plain shelf label instead (below), never a code.
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

/** Shrinks the font until an identifier fits: cutting one short would make it wrong. */
function shrinkToFit(doc: PdfDoc, text: string, maxWidth: number, size: number, minSize: number) {
  let current = size
  doc.setFontSize(current)
  while (current > minSize && doc.getTextWidth(text) > maxWidth) {
    current -= 0.25
    doc.setFontSize(current)
  }
}

/** At most two lines of name; anything longer ends with an ellipsis on the second. */
function nameLines(doc: PdfDoc, text: string, maxWidth: number): string[] {
  const lines = doc.splitTextToSize(text, maxWidth) as string[]
  return lines.length <= 2 ? lines : [lines[0], fit(doc, lines.slice(1).join(' '), maxWidth)]
}

/** A 15-digit serial is an IMEI; anything else is a serial number. */
function serialLine(serial: string): string {
  return /^\d{15}$/.test(serial) ? `IMEI ${serial}` : `S/N ${serial}`
}

/**
 * One 50 × 30 mm label for one physical unit, top-left corner at (x, y).
 *
 * Black on white with no filled areas, so a thermal printer can print it. The QR
 * and the barcode keep clear space around them (a scanner needs it), which is why
 * the left and bottom margins are not smaller.
 */
async function drawLabel(doc: PdfDoc, item: LabelItem, x: number, y: number) {
  const margin = 2.5
  const qrSize = 12
  const qrTop = 2.5

  doc.addImage(await qrDataUrl(item.barcode), 'PNG', x + margin, y + qrTop, qrSize, qrSize)

  const textX = x + margin + qrSize + 2.5
  const textW = LABEL_W - (textX - x) - margin
  doc.setTextColor(0, 0, 0)

  doc.setFont('helvetica', 'bold')
  doc.setFontSize(5.5)
  doc.text('APPLE EXPERT', textX, y + 3.8)

  let cursor = y + 6.8
  doc.setFontSize(7.5)
  for (const line of nameLines(doc, item.title, textW)) {
    doc.text(line, textX, cursor)
    cursor += 2.8
  }

  doc.setFont('helvetica', 'normal')
  if (item.subtitle) {
    doc.setFontSize(6.5)
    doc.text(fit(doc, item.subtitle, textW), textX, cursor)
    cursor += 2.5
  }
  if (item.serial) {
    const line = serialLine(item.serial)
    shrinkToFit(doc, line, textW, 6, 4.5)
    doc.text(line, textX, cursor)
  }

  // Code 128 across the bottom, its value underneath for reading by eye.
  const barTop = y + 16.8
  drawCode128(doc, item.barcode, x + margin - 0.5, barTop, LABEL_W - (margin - 0.5) * 2, 7.2)
  doc.setFont('courier', 'bold')
  doc.setFontSize(8)
  doc.text(item.barcode, x + LABEL_W / 2, barTop + 10, { align: 'center' })
}

/**
 * A label for a quantity-tracked item, which has no barcode in the database. It
 * deliberately carries no code of any kind: nothing could resolve it at the counter.
 * Every copy is the same, and the label says so, so a sticker is never mistaken for
 * the identity of one physical item.
 */
export interface ShelfLabelItem {
  title: string
  subtitle: string | null
  reference: string
}

function drawShelfLabel(doc: PdfDoc, item: ShelfLabelItem, x: number, y: number) {
  const margin = 3
  const width = LABEL_W - margin * 2
  const right = x + LABEL_W - margin
  doc.setTextColor(0, 0, 0)
  doc.setDrawColor(0, 0, 0)

  doc.setFont('helvetica', 'bold')
  doc.setFontSize(6)
  doc.text('APPLE EXPERT', x + margin, y + 5.2)

  // Outlined, not filled: thermal print heads handle it better.
  const tag = 'SHELF LABEL'
  const tagW = doc.getTextWidth(tag) + 2.4
  doc.setLineWidth(0.25)
  doc.rect(right - tagW, y + 2.8, tagW, 3.4)
  doc.text(tag, right - 1.2, y + 5.2, { align: 'right' })

  let cursor = y + 10.6
  doc.setFontSize(10)
  for (const line of nameLines(doc, item.title, width)) {
    doc.text(line, x + margin, cursor)
    cursor += 3.9
  }

  doc.setFont('helvetica', 'normal')
  if (item.subtitle) {
    doc.setFontSize(8)
    doc.text(fit(doc, item.subtitle, width), x + margin, cursor)
  }

  doc.setLineWidth(0.15)
  doc.line(x + margin, y + 22.6, right, y + 22.6)
  doc.setFontSize(5.5)
  doc.text('Same product on every copy.', x + margin, y + 24.8)
  doc.text('Not an individual item label.', x + margin, y + 26.9)
  // A reference number is never cut short: it shrinks to fit instead.
  shrinkToFit(doc, item.reference, 19, 5.5, 4.5)
  doc.text(item.reference, right, y + 26.9, { align: 'right' })
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
