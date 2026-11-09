const CARD_W = 264.64
const CARD_H = 387.945
const LETTERS = [ "A", "B", "C", "D", "E" ]

export function readPrintedCard(canvas, options = {}) {
  const questionCount = Number(options.questionCount) || 0
  const letterCount = Math.min(5, Math.max(2, Number(options.letterCount) || 5))
  if (!canvas || questionCount < 1) return null

  const image = sampleCanvas(canvas)
  if (!image) return null

  const qr = locateQr(image, options.jsQR)
  const corners = findCorners(image)
  const fromQr = qr && sampleGrid(
    image,
    homography(qrCardCorners(qr.version), qr.corners),
    Math.hypot(qr.corners[1][0] - qr.corners[0][0], qr.corners[1][1] - qr.corners[0][1]) * 0.05,
    questionCount,
    letterCount
  )
  const fromCorners = corners && sampleGrid(
    image,
    homography(fiducials(), corners),
    Math.hypot(corners[1][0] - corners[0][0], corners[1][1] - corners[0][1]) * 0.012,
    questionCount,
    letterCount
  )
  return richer(fromQr, fromCorners)
}

function sampleGrid(image, warp, spanRadius, questionCount, letterCount) {
  if (!warp) return null

  const answers = {}
  let covered = 0
  const radius = Math.max(3, Math.round(spanRadius))
  Object.entries(bubblePoints(questionCount, letterCount)).forEach(([ number, letters ]) => {
    const samples = Object.entries(letters).map(([ letter, point ]) => {
      const [ x, y ] = warp(point[0], point[1])
      return { letter, lum: luminanceAt(image, x, y, radius) }
    })
    const decision = chosen(samples)
    if (!decision) return

    covered += 1
    if (decision.letter) answers[number] = decision.letter
  })
  if (covered < 1) return null
  return { answers, covered }
}

function richer(first, second) {
  if (!first) return second
  if (!second) return first
  const firstLetters = Object.keys(first.answers).length
  const secondLetters = Object.keys(second.answers).length
  if (secondLetters > firstLetters) return second
  if (firstLetters > secondLetters) return first
  return (second.covered || 0) > (first.covered || 0) ? second : first
}

function bubblePoints(count, letterCount) {
  const letters = LETTERS.slice(0, letterCount)
  const perColumn = Math.ceil(count / 2)
  const rowH = Math.min(Math.max((CARD_H - 168) / Math.max(perColumn + 1, 1), 9), 13)
  const columnWidth = (CARD_W - 36) / 2
  const step = (columnWidth - 8 - 18) / Math.max(letters.length, 1)
  const mapped = {}

  for (let index = 0; index < count; index += 1) {
    const column = Math.floor(index / perColumn)
    const row = index % perColumn
    const left = 18 + (column * columnWidth)
    const points = {}
    letters.forEach((letter, letterIndex) => {
      points[letter] = [
        (left + 18 + (letterIndex * step) + (step / 2)) / CARD_W,
        (104 + (row * rowH)) / CARD_H
      ]
    })
    mapped[String(index + 1)] = points
  }
  return mapped
}

function fiducials() {
  const x = 10 / CARD_W
  const y = 10 / CARD_H
  return [ [ x, y ], [ 1 - x, y ], [ x, 1 - y ], [ 1 - x, 1 - y ] ]
}

function qrCardCorners(version) {
  const modules = 21 + ((Number(version) || 2) - 1) * 4
  const inset = 4 / (modules + 8)
  const width = 58 / CARD_W
  const height = 58 / CARD_H
  const left = ((CARD_W - 58) / 2) / CARD_W
  const top = (CARD_H - 60) / CARD_H
  return [
    [ left + (width * inset), top + (height * inset) ],
    [ left + (width * (1 - inset)), top + (height * inset) ],
    [ left + (width * inset), top + (height * (1 - inset)) ],
    [ left + (width * (1 - inset)), top + (height * (1 - inset)) ]
  ]
}

function locateQr(image, jsQR) {
  if (!jsQR) return null

  const regions = [
    { x: 0, y: 0, width: image.width, height: image.height },
    { x: 0, y: Math.floor(image.height * 0.5), width: image.width, height: Math.ceil(image.height * 0.5) },
    {
      x: Math.floor(image.width * 0.15),
      y: Math.floor(image.height * 0.55),
      width: Math.ceil(image.width * 0.7),
      height: Math.ceil(image.height * 0.42)
    }
  ]
  for (const region of regions) {
    const found = decodeRegion(image, jsQR, region)
    if (found) return found
  }
  return null
}

function decodeRegion(image, jsQR, region) {
  const width = Math.max(1, Math.min(region.width, image.width - region.x))
  const height = Math.max(1, Math.min(region.height, image.height - region.y))
  const data = new Uint8ClampedArray(width * height * 4)
  for (let y = 0; y < height; y += 1) {
    const source = (((region.y + y) * image.width) + region.x) * 4
    data.set(image.data.subarray(source, source + (width * 4)), y * width * 4)
  }

  let found = null
  try {
    found = jsQR(data, width, height, { inversionAttempts: "attemptBoth" })
  } catch (_error) {
    return null
  }
  const location = found?.location
  if (!location?.topLeftCorner || !location.topRightCorner || !location.bottomLeftCorner || !location.bottomRightCorner) {
    return null
  }
  const shift = (point) => [ point.x + region.x, point.y + region.y ]
  return {
    version: found.version,
    corners: [
      shift(location.topLeftCorner),
      shift(location.topRightCorner),
      shift(location.bottomLeftCorner),
      shift(location.bottomRightCorner)
    ]
  }
}

function sampleCanvas(canvas) {
  const scale = Math.min(1, 1200 / Math.max(canvas.width, canvas.height))
  const width = Math.max(1, Math.round(canvas.width * scale))
  const height = Math.max(1, Math.round(canvas.height * scale))
  const copy = document.createElement("canvas")
  copy.width = width
  copy.height = height
  const context = copy.getContext("2d", { willReadFrequently: true })
  context.drawImage(canvas, 0, 0, width, height)
  const data = context.getImageData(0, 0, width, height)
  return { width, height, data: data.data }
}

function findCorners(image) {
  const blobs = darkSquares(image)
  if (blobs.length < 4) return null

  const picks = [
    [ 0, 0 ],
    [ image.width - 1, 0 ],
    [ 0, image.height - 1 ],
    [ image.width - 1, image.height - 1 ]
  ].map(([ x, y ], index) => {
    const quadrant = blobs.filter((blob) => inQuadrant(blob, index, image.width, image.height))
    const pool = quadrant.length ? quadrant : blobs
    return pool.reduce((best, blob) => {
      const distance = ((blob.x - x) ** 2) + ((blob.y - y) ** 2)
      return !best || distance < best.distance ? { blob, distance } : best
    }, null)?.blob
  })

  if (picks.filter(Boolean).length < 4) return null
  const unique = new Set(picks.map((blob) => `${Math.round(blob.x)}:${Math.round(blob.y)}`))
  if (unique.size < 4) return null

  const left = Math.min(...picks.map((blob) => blob.x))
  const right = Math.max(...picks.map((blob) => blob.x))
  const top = Math.min(...picks.map((blob) => blob.y))
  const bottom = Math.max(...picks.map((blob) => blob.y))
  if ((right - left) < image.width * 0.18 || (bottom - top) < image.height * 0.18) return null
  return picks.map((blob) => [ blob.x, blob.y ])
}

function inQuadrant(blob, index, width, height) {
  if (index === 0) return blob.x < width * 0.55 && blob.y < height * 0.55
  if (index === 1) return blob.x > width * 0.45 && blob.y < height * 0.55
  if (index === 2) return blob.x < width * 0.55 && blob.y > height * 0.45
  return blob.x > width * 0.45 && blob.y > height * 0.45
}

function darkSquares(image) {
  const { width, height, data } = image
  const seen = new Uint8Array(width * height)
  const blobs = []

  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const start = (y * width) + x
      if (seen[start] || !darkAt(data, start)) continue

      const queue = [ start ]
      seen[start] = 1
      let count = 0
      let sumX = 0
      let sumY = 0
      let minX = x
      let maxX = x
      let minY = y
      let maxY = y
      for (let cursor = 0; cursor < queue.length; cursor += 1) {
        const index = queue[cursor]
        const px = index % width
        const py = Math.floor(index / width)
        count += 1
        sumX += px
        sumY += py
        if (px < minX) minX = px
        if (px > maxX) maxX = px
        if (py < minY) minY = py
        if (py > maxY) maxY = py
        ;[ index - 1, index + 1, index - width, index + width ].forEach((neighbor) => {
          if (neighbor < 0 || neighbor >= seen.length || seen[neighbor]) return
          const nx = neighbor % width
          if (Math.abs(nx - px) > 1) return
          if (!darkAt(data, neighbor)) return
          seen[neighbor] = 1
          queue.push(neighbor)
        })
      }

      const boxW = maxX - minX + 1
      const boxH = maxY - minY + 1
      const ratio = boxW / boxH
      if (count < 24 || count > 12000 || boxW < 5 || boxH < 5) continue
      if (ratio < 0.65 || ratio > 1.45) continue
      if (count < boxW * boxH * 0.45) continue
      blobs.push({ x: sumX / count, y: sumY / count, area: count })
    }
  }
  return blobs
}

function chosen(samples) {
  const ordered = samples.slice().sort((a, b) => a.lum - b.lum)
  const best = ordered[0]
  const rest = ordered.slice(1)
  if (!best) return null
  const restAverage = rest.reduce((sum, sample) => sum + sample.lum, 0) / Math.max(rest.length, 1)
  if (best.lum <= 170 && restAverage - best.lum >= 18) return { letter: best.letter }
  if (ordered.every((sample) => sample.lum >= 185)) return { letter: null }
  return null
}

function luminanceAt(image, x, y, radius) {
  let total = 0
  let count = 0
  const cx = Math.round(x)
  const cy = Math.round(y)
  for (let dy = -radius; dy <= radius; dy += 1) {
    for (let dx = -radius; dx <= radius; dx += 1) {
      const px = cx + dx
      const py = cy + dy
      if (px < 0 || py < 0 || px >= image.width || py >= image.height) continue
      const index = ((py * image.width) + px) * 4
      total += (image.data[index] + image.data[index + 1] + image.data[index + 2]) / 3
      count += 1
    }
  }
  return count ? total / count : 255
}

function darkAt(data, pixelIndex) {
  const index = pixelIndex * 4
  return ((data[index] + data[index + 1] + data[index + 2]) / 3) <= 120
}

function homography(sources, destinations) {
  const matrix = []
  const vector = []
  sources.forEach(([ x, y ], index) => {
    const [ u, v ] = destinations[index]
    matrix.push([ x, y, 1, 0, 0, 0, -x * u, -y * u, u ])
    matrix.push([ 0, 0, 0, x, y, 1, -x * v, -y * v, v ])
    vector.push(u, v)
  })
  const solved = solve(matrix)
  if (!solved) return null
  return (x, y) => {
    const denom = (solved[6] * x) + (solved[7] * y) + 1
    if (Math.abs(denom) < 1e-8) return [ 0, 0 ]
    return [
      ((solved[0] * x) + (solved[1] * y) + solved[2]) / denom,
      ((solved[3] * x) + (solved[4] * y) + solved[5]) / denom
    ]
  }
}

function solve(rows) {
  const size = rows.length
  const matrix = rows.map((row) => row.slice())
  for (let col = 0; col < size; col += 1) {
    let pivot = col
    for (let row = col + 1; row < size; row += 1) {
      if (Math.abs(matrix[row][col]) > Math.abs(matrix[pivot][col])) pivot = row
    }
    if (Math.abs(matrix[pivot][col]) < 1e-8) return null
    ;[ matrix[col], matrix[pivot] ] = [ matrix[pivot], matrix[col] ]
    const factor = matrix[col][col]
    matrix[col] = matrix[col].map((value) => value / factor)
    for (let row = 0; row < size; row += 1) {
      if (row === col) continue
      const scale = matrix[row][col]
      if (Math.abs(scale) < 1e-12) continue
      matrix[row] = matrix[row].map((value, index) => value - (scale * matrix[col][index]))
    }
  }
  return matrix.map((row) => row[size])
}
