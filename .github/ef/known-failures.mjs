// Compare vitest JSON reports with .github/ef/known-failures.txt (see its header).
//   node .github/ef/known-failures.mjs <package>=<report.json> [...]
// Exit 1 on a failure not in the list, or on a report that is missing (a suite that crashed before reporting).
import { readFileSync, existsSync } from 'node:fs'
import { relative } from 'node:path'

const known = new Set(
  readFileSync(new URL('./known-failures.txt', import.meta.url), 'utf8')
    .split('\n')
    .filter((l) => l.trim() && !l.startsWith('#'))
)
const failed = new Set()
let bad = false
for (const arg of process.argv.slice(2)) {
  const [pkg, file] = arg.split('=')
  if (!existsSync(file)) {
    console.log(`::error::${pkg}: no report at ${file}`)
    bad = true
    continue
  }
  const report = JSON.parse(readFileSync(file, 'utf8'))
  for (const suite of report.testResults ?? []) {
    const path = relative(`${process.cwd()}/packages/${pkg}`, suite.name)
    const tests = suite.assertionResults ?? []
    for (const t of tests) {
      if (t.status === 'failed') failed.add(`${pkg}|${path} > ${[...t.ancestorTitles, t.title].join(' > ')}`)
    }
    // A file that failed outside any test (beforeAll, import) carries its message on the suite.
    if (suite.status === 'failed' && !tests.some((t) => t.status === 'failed')) {
      const first = tests[0]?.ancestorTitles?.[0]
      failed.add(`${pkg}|${path}${first ? ` > ${first}` : ''}`)
    }
  }
}
const unknown = [...failed].filter((f) => !known.has(f))
const fixed = [...known].filter((k) => !failed.has(k))
for (const f of unknown) console.log(`::error::new failure: ${f}`)
for (const f of fixed) console.log(`::notice::now passes — remove from known-failures.txt: ${f}`)
console.log(`${failed.size} failed, ${failed.size - unknown.length} of them known; ${unknown.length} new; ${fixed.length} known now pass`)
process.exit(bad || unknown.length ? 1 : 0)
