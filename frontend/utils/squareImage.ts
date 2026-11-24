// Crop the middle square of a picture and shrink it to size×size JPEG, in the browser.
// A 5MB phone photo becomes ~20KB, so Rails needs no image library (libvips) to make thumbnails.
export async function squareImage(file: File, size = 256): Promise<Blob> {
  const bitmap = await createImageBitmap(file) // throws when the browser cannot read the file (e.g. not an image)
  const side = Math.min(bitmap.width, bitmap.height)
  const canvas = document.createElement('canvas')
  canvas.width = canvas.height = size
  const ctx = canvas.getContext('2d')!
  ctx.fillStyle = '#fff' // JPEG has no transparency: transparent PNG parts become white, not black
  ctx.fillRect(0, 0, size, size)
  // drawImage(source, sx, sy, sw, sh, dx, dy, dw, dh): take the centred side×side square, draw it at size×size
  ctx.drawImage(bitmap, (bitmap.width - side) / 2, (bitmap.height - side) / 2, side, side, 0, 0, size, size)
  bitmap.close()
  return new Promise((resolve, reject) =>
    canvas.toBlob(blob => (blob ? resolve(blob) : reject(new Error('toBlob failed'))), 'image/jpeg', 0.9)
  )
}
