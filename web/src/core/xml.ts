/**
 * Leitor mínimo de tags XML, sem DOM (funciona em qualquer ambiente e aguenta os .model de milhões de
 * triângulos, que o DOMParser carregaria inteiros na memória).
 */
const TAG = /<(\/?)([A-Za-z_][\w:.-]*)([^>]*?)(\/?)>/g
const ATTR = /([\w:.-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/g

const ENTITIES: Record<string, string> = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" }
const decode = (v: string) => (v.includes('&') ? v.replace(/&(amp|lt|gt|quot|apos);/g, (_, n: string) => ENTITIES[n]) : v)

export function parseAttrs(text: string): Record<string, string> {
  const attrs: Record<string, string> = {}
  ATTR.lastIndex = 0
  let m: RegExpExecArray | null
  while ((m = ATTR.exec(text))) attrs[m[1]] = decode(m[2] ?? m[3] ?? '')
  return attrs
}

/** Percorre as tags em ordem. `name` vem sem prefixo de namespace e em minúsculas. */
export function forEachTag(
  xml: string,
  visit: (name: string, attrsText: string, kind: 'open' | 'close' | 'self') => void,
) {
  TAG.lastIndex = 0
  let m: RegExpExecArray | null
  while ((m = TAG.exec(xml))) {
    const name = m[2].slice(m[2].lastIndexOf(':') + 1).toLowerCase()
    visit(name, m[3], m[1] ? 'close' : m[4] ? 'self' : 'open')
  }
}
