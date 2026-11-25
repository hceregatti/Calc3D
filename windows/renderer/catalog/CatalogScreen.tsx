import { ArrowUpRight, Box, Calculator, Download, FolderOpen, Library, RefreshCw, Save, Search, Trash2, Upload } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { CATEGORIES, PRICING_ERROR, calculate, canPrice, money, unitCost } from '@web/core/calculator'
import { weight } from '@web/core/format'
import { jobPatchFromImport } from '@web/core/importer'
import { Empty, PageHeader, Row, Section } from '@web/components/ui'
import { useApp } from '@web/store'
import type { CatalogEntry } from '../bridge'
import { useCatalog, visibleFiles } from './catalogStore'

export function CatalogScreen() {
  const folder = useCatalog((s) => s.folder)
  const refresh = useCatalog((s) => s.refresh)
  useEffect(() => { void refresh() }, [refresh, folder])
  // Relê a pasta ao voltar para o app, como no macOS.
  useEffect(() => {
    const onFocus = () => void useCatalog.getState().refresh()
    window.addEventListener('focus', onFocus)
    return () => window.removeEventListener('focus', onFocus)
  }, [])
  return folder ? <Browser /> : <Setup />
}

/** Primeiro uso: escolher a pasta compartilhada. */
function Setup() {
  const chooseFolder = useCatalog((s) => s.chooseFolder)
  const message = useCatalog((s) => s.message)
  return (
    <div className="page">
      <PageHeader title="Catálogo" />
      <Empty
        icon={Library}
        title="Catálogo de modelos"
        text="Escolha a pasta compartilhada (OneDrive, Google Drive, Dropbox, rede…) onde ficam os arquivos 3MF/STL já configurados. O app lê o peso e o tempo gravados em cada arquivo e calcula o custo com os seus parâmetros."
      >
        <button className="btn primary" onClick={() => void chooseFolder()}>
          <FolderOpen size={16} /> Escolher pasta…
        </button>
        {message && <p className="feedback warn">{message}</p>}
      </Empty>
    </div>
  )
}

function Browser() {
  const { files, search, setSearch, selected, message, refreshing, folder } = useCatalog()
  const { refresh, upload, chooseFolder, disconnect } = useCatalog.getState()
  const visible = useMemo(() => visibleFiles(files, search), [files, search])
  const file = files.find((f) => f.path === selected) ?? null
  const [menu, setMenu] = useState(false)

  return (
    <div className="page">
      <PageHeader title="Catálogo">
        <button className="btn" onClick={() => void upload()} title="Envia arquivos 3MF/STL do seu computador para a pasta do catálogo">
          <Upload size={16} /> Enviar arquivo
        </button>
        <button className="btn" disabled={refreshing} onClick={() => void refresh()} title="Relê a pasta compartilhada">
          <RefreshCw size={16} /> Atualizar
        </button>
        <div className="menu-wrap">
          <button className="btn" onClick={() => setMenu(!menu)} title="Pasta do catálogo">
            <FolderOpen size={16} /> Pasta
          </button>
          {menu && (
            <div className="menu" onMouseLeave={() => setMenu(false)}>
              <div className="menu-label" style={{ maxWidth: 280, wordBreak: 'break-all' }}>{folder}</div>
              <button onClick={() => { setMenu(false); void chooseFolder() }}>Trocar pasta…</button>
              <button onClick={() => { setMenu(false); disconnect() }}>Desconectar do catálogo</button>
            </div>
          )}
        </div>
      </PageHeader>
      <div className="master-detail">
        <div className="master">
          <div style={{ padding: 12, position: 'relative' }}>
            <Search size={14} style={{ position: 'absolute', left: 22, top: 22, opacity: 0.5 }} />
            <input className="input" style={{ width: '100%', paddingLeft: 30 }} placeholder="Buscar modelo ou pasta" value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
          {visible.length === 0 ? (
            <Empty
              icon={Library}
              title={files.length === 0 ? 'Nenhum modelo na pasta' : 'Nada encontrado'}
              text={files.length === 0 ? 'Coloque arquivos 3MF ou STL na pasta do catálogo e atualize.' : 'Ajuste a busca.'}
            />
          ) : (
            <div className="list">
              {visible.map((f) => <FileRow key={f.path} file={f} />)}
            </div>
          )}
          {message && <p className="feedback warn" style={{ padding: 10, margin: 0 }}>{message}</p>}
        </div>
        <div className="detail">
          {file ? <Detail key={file.path} file={file} /> : (
            <Empty icon={Library} title="Selecione um modelo" text="Veja o que o arquivo traz e o custo com os seus parâmetros." />
          )}
        </div>
      </div>
    </div>
  )
}

function Thumb({ file, size }: { file: CatalogEntry; size: number }) {
  const url = useCatalog((s) => s.thumbs[file.path])
  const loadThumb = useCatalog((s) => s.loadThumb)
  useEffect(() => { loadThumb(file) }, [file, loadThumb])
  return url ? (
    <img src={url} alt="" width={size} height={size} style={{ borderRadius: 8, objectFit: 'cover', flex: 'none' }} />
  ) : (
    <span style={{ width: size, height: size, borderRadius: 8, background: 'var(--fill)', display: 'grid', placeItems: 'center', flex: 'none', color: 'var(--muted)' }}>
      <Box size={size * 0.45} />
    </span>
  )
}

function FileRow({ file }: { file: CatalogEntry }) {
  const selected = useCatalog((s) => s.selected === file.path)
  const select = useCatalog((s) => s.select)
  return (
    <div className={`list-row ${selected ? 'selected' : ''}`} onClick={() => select(file.path)}>
      <Thumb file={file} size={44} />
      <div className="grow text" style={{ minWidth: 0 }}>
        <strong className="ellipsis">{file.name}</strong>
        <small className="muted ellipsis">
          {file.extension.toUpperCase()}{file.folder ? ` · ${file.folder}` : ''} · {new Date(file.modifiedAt).toLocaleDateString('pt-BR', { dateStyle: 'medium' })}
        </small>
      </div>
    </div>
  )
}

const duration = (seconds: number) => {
  const minutes = Math.round(seconds / 60)
  return `${Math.floor(minutes / 60)} h ${minutes % 60} min`
}
const mm = (v: string) => v.replace('.', ',') + ' mm'

function Detail({ file }: { file: CatalogEntry }) {
  const { loadInfo, loadSlicers, data: dataOf, setPlate, plateChoice, download, reveal, trash, openInSlicer, slicers } = useCatalog()
  const info = useCatalog((s) => s.info[file.path])
  const thumb = useCatalog((s) => s.thumbs[file.path])
  const settings = useApp((s) => s.settings)
  const baseJob = useApp((s) => s.job)
  const { setJob, go, saveQuote, showToast, askConfirm } = useApp.getState()
  useEffect(() => { loadInfo(file) }, [file, loadInfo])
  useEffect(() => { void loadSlicers() }, [loadSlicers])

  const raw = info?.state === 'ready' ? info.data : null
  const data = dataOf(file)
  const job = useMemo(() => {
    if (!data || !data.weightGrams || !data.durationSeconds || data.durationSeconds <= 0) return null
    return { ...baseJob, ...jobPatchFromImport(data) }
  }, [data, baseJob])
  const result = useMemo(() => (job ? calculate(settings, job) : null), [job, settings])
  const chosen = raw && raw.plates.length > 1 ? (plateChoice[file.path] ?? raw.plates[0].index) : null
  const usedPlate = raw ? (chosen !== null ? raw.plates.find((p) => p.index === chosen) : raw.plates[0]) : undefined

  return (
    <div className="detail-inner">
      <h2>{file.name}</h2>
      {thumb && <img src={thumb} alt="" style={{ width: '100%', maxHeight: 260, objectFit: 'contain', borderRadius: 12 }} />}

      <Section title="Arquivo" icon={Box} color="#30b0c7">
        <Row label="Formato">{file.extension.toUpperCase()}</Row>
        {file.folder && <Row label="Pasta">{file.folder}</Row>}
        <Row label="Modificado em">{new Date(file.modifiedAt).toLocaleString('pt-BR', { dateStyle: 'long', timeStyle: 'short' })}</Row>
      </Section>

      <Section
        title="Informações do arquivo"
        icon={Search}
        color="#ff9f0a"
        footer={
          raw && data && (data.weightGrams === null || data.durationSeconds === null)
            ? raw.plates.length > 1 ? 'Escolha uma mesa para ver o peso e o tempo.' : 'O arquivo não traz peso e/ou tempo (precisa estar fatiado). Abra em “Calcular peça” para preencher à mão.'
            : undefined
        }
      >
        {!info && <p className="muted">Lendo o arquivo…</p>}
        {info?.state === 'error' && <p className="warn">{info.message}</p>}
        {raw && data && (
          <>
            {raw.plates.length > 1 && (
              <Row label="Mesa">
                <select className="input" value={chosen ?? undefined} onChange={(e) => setPlate(file.path, Number(e.target.value))}>
                  {raw.plates.map((p) => <option key={p.index} value={p.index}>Mesa {p.index}</option>)}
                </select>
              </Row>
            )}
            {raw.printer && (
              <>
                {(raw.printer.model ?? raw.printer.profile) && <Row label="Impressora">{raw.printer.model ?? raw.printer.profile}</Row>}
                {raw.printer.nozzleDiameter && <Row label="Bico">{mm(raw.printer.nozzleDiameter)}</Row>}
                {raw.printer.layerHeight && <Row label="Altura de camada">{mm(raw.printer.layerHeight)}</Row>}
                {raw.printer.printProfile && <Row label="Perfil de impressão">{raw.printer.printProfile}</Row>}
              </>
            )}
            <Row label="Peso">{data.weightGrams !== null ? weight(data.weightGrams) : 'Não informado no arquivo'}</Row>
            <Row label="Tempo de impressão">{data.durationSeconds && data.durationSeconds > 0 ? duration(data.durationSeconds) : 'Não informado no arquivo'}</Row>
            {data.weightGrams === null && raw.estimatedWeight && (
              <>
                <Row label="Peso estimado"><span className="warn">≈ {weight(raw.estimatedWeight.grams)}</span></Row>
                <p className="muted" style={{ fontSize: 12 }}>
                  Calculado pelo volume do modelo ({raw.estimatedWeight.pieces === 1 ? '1 peça' : `${raw.estimatedWeight.pieces} peças`}), com a densidade e o preenchimento do projeto, ou PLA a 15% se não constarem. É uma aproximação; o tempo não pode ser estimado.
                </p>
              </>
            )}
            {raw.plates.length > 1 && <p className="muted" style={{ fontSize: 12 }}>Arquivo com {raw.plates.length} mesas fatiadas; escolha qual calcular.</p>}
            {(usedPlate?.filaments ?? []).map((f, i) => (
              <Row key={i} label={`Filamento ${i + 1}`}>{[f.type, f.colorHex, weight(f.grams)].filter(Boolean).join(' · ')}</Row>
            ))}
          </>
        )}
      </Section>

      {result && (
        <Section title="Com os seus parâmetros" icon={Calculator} color="#30d158"
          footer="Usa os parâmetros fixos, o filamento e a margem da peça que está em “Calcular peça”.">
          <Row label="Custo por peça">{money(unitCost(result))}</Row>
          <Row label={<strong>Preço sugerido</strong>}>
            <strong>{canPrice(result) && result.suggestedPrice !== null ? money(result.suggestedPrice) : 'Indisponível'}</strong>
          </Row>
          {!canPrice(result) && <p className="error-text">{PRICING_ERROR}</p>}
          {result.items.map((i) => <Row key={i.category} label={CATEGORIES.find((c) => c.id === i.category)!.title}>{money(i.amount)}</Row>)}
        </Section>
      )}

      <Section title="Abrir no fatiador" icon={ArrowUpRight} color="#ff9f0a"
        footer="Abre uma cópia do modelo: salvar no fatiador não altera o arquivo do catálogo.">
        <div style={{ display: 'flex', gap: 12 }}>
          {slicers.map((s) => (
            <button key={s.id} className="btn" disabled={!s.installed} onClick={() => void openInSlicer(file, s.id)}
              title={s.installed ? `Abrir uma cópia do modelo no ${s.title}` : `${s.title} não foi encontrado nos programas instalados`}
              style={{ flex: 1, justifyContent: 'flex-start', gap: 12, padding: 12, height: 'auto', opacity: s.installed ? 1 : 0.55 }}>
              {s.icon ? <img src={s.icon} alt="" width={36} height={36} /> : <Box size={36} />}
              <span style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start', flex: 1 }}>
                <strong>{s.title}</strong>
                <small className="muted">{s.installed ? 'Abrir cópia do modelo' : 'Não instalado'}</small>
              </span>
              <ArrowUpRight size={18} />
            </button>
          ))}
        </div>
      </Section>

      <div className="btn-row">
        <button className="btn" disabled={!data} onClick={() => {
          if (!data) return
          setJob(jobPatchFromImport(data))
          go('printJob')
        }}>
          <Calculator size={16} /> Calcular
        </button>
        <button className="btn" disabled={!job} onClick={() => {
          if (!job) return
          saveQuote(job)
          showToast('Peça salva no seu histórico ✔')
        }}>
          <Save size={16} /> Salvar
        </button>
        <button className="btn" onClick={() => void download(file)}><Download size={16} /> Baixar</button>
        <button className="btn" onClick={() => reveal(file)}><FolderOpen size={16} /> Mostrar no Explorer</button>
        <span className="grow" />
        <button className="btn danger-text" onClick={() => askConfirm({
          title: 'Excluir este modelo do catálogo?',
          message: 'O arquivo vai para a Lixeira e some do catálogo para todas as pessoas que usam esta pasta.',
          confirmLabel: `Excluir "${file.name}"`,
          destructive: true,
          onConfirm: () => void trash(file),
        })}>
          <Trash2 size={16} /> Excluir
        </button>
      </div>
    </div>
  )
}

