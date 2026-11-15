import { ImagePlus, Image as ImageIcon, Trash2 } from 'lucide-react'
import { useRef, useState } from 'react'
import { importImage, useImage, type ImageKind } from '../images'
import { useApp } from '../store'

/**
 * Quadro de imagem: mostra a imagem ou um marcador padrão.
 * Clique para escolher, arraste um arquivo para soltar, botão para remover.
 */
export function ImageSlot({
  imageId,
  kind,
  onChange,
  width = 76,
  height = 76,
  label = 'Adicionar foto',
  fit = 'cover',
}: {
  imageId: string | null
  kind: ImageKind
  onChange: (id: string | null) => void
  width?: number
  height?: number
  label?: string
  fit?: 'cover' | 'contain'
}) {
  const url = useImage(imageId)
  const input = useRef<HTMLInputElement>(null)
  const [dragging, setDragging] = useState(false)
  const [busy, setBusy] = useState(false)
  const showToast = useApp((s) => s.showToast)

  const handle = async (file: File | undefined) => {
    if (!file) return
    if (!file.type.startsWith('image/')) return showToast('Escolha um arquivo de imagem.', 'error')
    setBusy(true)
    try {
      onChange(await importImage(file, kind))
    } catch (e) {
      showToast((e as Error).message, 'error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="image-slot-wrap" style={{ width }}>
      <button
        type="button"
        className={`image-slot ${dragging ? 'dragging' : ''}`}
        style={{ width, height }}
        title={url ? 'Clique para trocar a imagem' : 'Clique ou arraste uma imagem'}
        onClick={() => input.current?.click()}
        onDragOver={(e) => {
          e.preventDefault()
          setDragging(true)
        }}
        onDragLeave={() => setDragging(false)}
        onDrop={(e) => {
          e.preventDefault()
          setDragging(false)
          handle(e.dataTransfer.files[0])
        }}
      >
        {url ? (
          <img src={url} alt="" style={{ objectFit: fit, padding: fit === 'contain' ? 6 : 0 }} />
        ) : (
          <span className="image-placeholder">
            {busy ? <span className="spinner" /> : kind === 'logo' ? <ImagePlus size={Math.min(width, height) * 0.3} /> : <ImageIcon size={Math.min(width, height) * 0.3} />}
            {!busy && <small>{label}</small>}
          </span>
        )}
      </button>
      {url && (
        <button type="button" className="image-remove" onClick={() => onChange(null)} title="Remover imagem" aria-label="Remover imagem">
          <Trash2 size={12} />
        </button>
      )}
      <input
        ref={input}
        type="file"
        accept="image/*"
        hidden
        onChange={(e) => {
          handle(e.target.files?.[0])
          e.target.value = ''
        }}
      />
    </div>
  )
}
