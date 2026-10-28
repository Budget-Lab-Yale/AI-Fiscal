// Chart-engine toolchain for AI-Fiscal's published figures
// (docs/v1_2_figure_pipeline_plan.md, step F2). Runs the pinned engine's
// `tbl-chart` CLI over every figure in a collection folder, as written by
// code/16_chart_data.R (<run dir>/charts/<collection>/).
//
//   node tools/charts.mjs validate  <collection dir>
//   node tools/charts.mjs render    <collection dir> [out dir]
//   node tools/charts.mjs png       <collection dir> [out dir]
//   node tools/charts.mjs pin-check <budget-lab-charts checkout>
//
// render writes one interactive page per figure linking a shared copy of the
// engine runtime (out/_assets); png writes the engine's headless-Chromium
// render. Default out dir: <collection dir>/../<collection>_html or _png.
// Exits 1 if any figure fails.

import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repo = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const cli = join(repo, "node_modules", "budget-lab-chart-engine", "dist", "cli", "index.js");
const ENGINE_DEP = "budget-lab-chart-engine";

function tblChart(args) {
  const r = spawnSync(process.execPath, [cli, ...args], { encoding: "utf8" });
  return { ok: r.status === 0, out: `${r.stdout ?? ""}${r.stderr ?? ""}`.trim() };
}

// [{ name, spec }] for every figure folder holding a chart.yaml or table.yaml.
function figures(collectionDir) {
  return readdirSync(collectionDir, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => {
      const spec = ["chart.yaml", "table.yaml"]
        .map((f) => join(collectionDir, d.name, f))
        .find((f) => existsSync(f));
      return spec && { name: d.name, spec };
    })
    .filter(Boolean)
    .sort((a, b) => a.name.localeCompare(b.name));
}

function report(results) {
  for (const r of results) console.log(`${r.ok ? "ok  " : "FAIL"} ${r.name}${r.ok ? "" : `\n     ${r.out}`}`);
  const failed = results.filter((r) => !r.ok).length;
  console.log(`${results.length - failed} of ${results.length} figures ok`);
  if (failed) process.exit(1);
}

function defaultOut(collectionDir, suffix) {
  const dir = resolve(collectionDir);
  return join(dirname(dir), `${basename(dir)}_${suffix}`);
}

const commands = {
  validate(collectionDir) {
    report(figures(collectionDir).map((f) => ({ name: f.name, ...tblChart(["validate", f.spec]) })));
  },

  render(collectionDir, outDir = defaultOut(collectionDir, "html")) {
    mkdirSync(outDir, { recursive: true });
    const assets = tblChart(["assets", "-o", join(outDir, "_assets")]);
    if (!assets.ok) report([{ name: "_assets", ...assets }]);
    report(figures(collectionDir).map((f) => ({
      name: f.name,
      ...tblChart(["render", f.spec, "-o", join(outDir, `${f.name}.html`), "--assets-base", "_assets"]),
    })));
  },

  // `tbl-chart snapshot` exits 0 even when the render fails, so success is
  // judged by the PNG existing afterwards.
  png(collectionDir, outDir = defaultOut(collectionDir, "png")) {
    mkdirSync(outDir, { recursive: true });
    report(figures(collectionDir).map((f) => {
      const png = join(outDir, `${f.name}.png`);
      rmSync(png, { force: true });
      const r = tblChart(["snapshot", f.spec, "--baseline", png, "--update"]);
      return { name: f.name, ok: existsSync(png), out: r.out };
    }));
  },

  // The engine tag pinned here must equal budget-lab-charts', so a figure
  // previewed here renders identically on the site.
  "pin-check"(chartsRepo) {
    const pin = (dir) => JSON.parse(readFileSync(join(dir, "package.json"), "utf8")).dependencies[ENGINE_DEP];
    const ours = pin(repo);
    const theirs = pin(chartsRepo);
    console.log(`AI-Fiscal:          ${ours}\nbudget-lab-charts:  ${theirs}`);
    if (ours !== theirs) {
      console.log("Engine pins differ: bump package.json here (and re-render) before previewing for the site.");
      process.exit(1);
    }
  },
};

const [command, ...args] = process.argv.slice(2);
if (!commands[command] || !args[0]) {
  console.error("Usage: node tools/charts.mjs <validate|render|png> <collection dir> [out dir]\n" +
                "       node tools/charts.mjs pin-check <budget-lab-charts checkout>");
  process.exit(2);
}
commands[command](...args);
