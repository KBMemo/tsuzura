import Cropper from 'cropperjs'
import 'cropperjs/dist/cropper.css'

function initCropperEditor() {
  const root = document.querySelector('[data-cropper-editor]')
  const image = document.getElementById('cropper-image')
  const rotate = document.getElementById('edit-stack-rotate')
  const resetBtn = document.getElementById('reset-crop')
  const status = document.getElementById('crop-status')
  const fields = {
    x: document.getElementById('edit_stack_crop_x'),
    y: document.getElementById('edit_stack_crop_y'),
    w: document.getElementById('edit_stack_crop_w'),
    h: document.getElementById('edit_stack_crop_h'),
  }
  if (!root || !image || !fields.x || !fields.y || !fields.w || !fields.h) return

  let cropper
  const initialCrop = JSON.parse(root.dataset.initialCrop || '{}')
  const number = (value, fallback) => {
    const parsed = Number.parseFloat(value)
    return Number.isFinite(parsed) ? parsed : fallback
  }
  const clamp = (value, min, max) => Math.min(max, Math.max(min, value))
  const round = (value) => String(Math.round(value * 10000) / 10000)
  const currentRotate = () => Number.parseInt(rotate?.value || '0', 10) || 0
  const rotated = () => Math.abs(currentRotate()) % 180 === 90
  const dimensions = () => {
    const data = cropper.getImageData()
    const width = data.naturalWidth || image.naturalWidth || 1
    const height = data.naturalHeight || image.naturalHeight || 1
    return rotated() ? { width: height, height: width } : { width, height }
  }
  const setFields = (crop) => {
    fields.x.value = round(clamp(crop.x, 0, 1))
    fields.y.value = round(clamp(crop.y, 0, 1))
    fields.w.value = round(clamp(crop.w, 0.0001, 1))
    fields.h.value = round(clamp(crop.h, 0.0001, 1))
    if (status) {
      status.textContent = `x=${fields.x.value} y=${fields.y.value} w=${fields.w.value} h=${fields.h.value}`
    }
  }
  const cropFromData = () => {
    const data = cropper.getData(true)
    const size = dimensions()
    return {
      x: data.x / size.width,
      y: data.y / size.height,
      w: data.width / size.width,
      h: data.height / size.height,
    }
  }
  const applyCrop = (crop) => {
    const size = dimensions()
    cropper.setData({
      x: number(crop.x, 0) * size.width,
      y: number(crop.y, 0) * size.height,
      width: number(crop.w, 1) * size.width,
      height: number(crop.h, 1) * size.height,
    })
    setFields(cropFromData())
  }
  const selectAll = () => applyCrop({ x: 0, y: 0, w: 1, h: 1 })

  cropper = new Cropper(image, {
    viewMode: 1,
    autoCrop: true,
    background: false,
    responsive: true,
    checkOrientation: false,
    ready() {
      cropper.rotateTo(currentRotate())
      window.requestAnimationFrame(() => applyCrop(initialCrop))
    },
    crop() {
      setFields(cropFromData())
    },
  })

  rotate?.addEventListener('change', () => {
    cropper.rotateTo(currentRotate())
    window.requestAnimationFrame(selectAll)
  })
  resetBtn?.addEventListener('click', selectAll)
  document.getElementById('edit-stack-form')?.addEventListener('submit', () => {
    setFields(cropFromData())
  })
}

function initBlurRegions() {
  const container = document.getElementById('blur-regions')
  const template = document.getElementById('blur-region-template')
  const addBtn = document.getElementById('add-blur-region')
  if (!container || !template || !addBtn) return

  const nextIndex = () => container.querySelectorAll('[data-blur-region]').length

  addBtn.addEventListener('click', () => {
    const html = template.innerHTML.replaceAll('__INDEX__', String(nextIndex()))
    container.insertAdjacentHTML('beforeend', html)
  })

  container.addEventListener('click', (event) => {
    const btn = event.target.closest('[data-remove-blur-region]')
    if (!btn) return
    const row = btn.closest('[data-blur-region]')
    if (row) row.remove()
  })
}

document.addEventListener('DOMContentLoaded', () => {
  initCropperEditor()
  initBlurRegions()
})
