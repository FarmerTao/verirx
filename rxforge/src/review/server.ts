import http from "node:http";
import type { StagingDatabase } from "../db.js";

/**
 * Minimalist 10-second Human Sign-off Review Console (http://localhost:4321).
 * Displays pending RxForge questions side-by-side with FDA SPL citations & Blind Critic logs.
 */
export function startReviewServer(staging: StagingDatabase, port = 4321): void {
  const server = http.createServer((req, res) => {
    const url = new URL(req.url ?? "/", `http://localhost:${port}`);

    if (req.method === "GET" && url.pathname === "/api/pending") {
      const rows = staging.db
        .prepare(
          `SELECT q.*, d.generic_name, d.raw_label_excerpt
           FROM questions q
           LEFT JOIN drugs d ON q.drug_id = d.id
           WHERE q.review_status = 'pending'
           ORDER BY q.created_at DESC`
        )
        .all();
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ items: rows, stats: staging.getStats() }));
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/decision") {
      let body = "";
      req.on("data", (chunk) => (body += chunk));
      req.on("end", () => {
        const { id, status } = JSON.parse(body) as {
          id: string;
          status: "approved" | "rejected";
        };
        staging.db
          .prepare("UPDATE questions SET review_status = ? WHERE id = ?")
          .run(status, id);
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ok: true, stats: staging.getStats() }));
      });
      return;
    }

    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(REVIEW_HTML);
  });

  server.listen(port, () => {
    console.log(`[RxForge Review Console] Running at http://localhost:${port}`);
    console.log("  Shortcuts: [A] Approve  |  [R] Reject");
  });
}

const REVIEW_HTML = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<title>RxForge — Founder Final Review Console</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 0; background: #0f172a; color: #f8fafc; }
  header { padding: 16px 24px; background: #1e293b; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #334155; }
  main { display: grid; grid-template-columns: 1.2fr 1fr; gap: 20px; padding: 24px; max-width: 1360px; margin: 0 auto; }
  .card { background: #1e293b; border: 1px solid #334155; border-radius: 12px; padding: 20px; }
  .choice { padding: 10px 12px; border-radius: 8px; margin: 8px 0; background: #0f172a; border: 1px solid #334155; }
  .choice.correct { border-color: #10b981; background: rgba(16,185,129,0.12); }
  .rationale { font-size: 13px; color: #94a3b8; margin-top: 4px; }
  .actions { display: flex; gap: 12px; margin-top: 20px; }
  button { padding: 10px 20px; border-radius: 8px; border: none; font-weight: 600; cursor: pointer; font-size: 15px; }
  .approve { background: #10b981; color: #052e16; }
  .reject { background: #ef4444; color: #fff; }
  pre { white-space: pre-wrap; font-size: 13px; color: #cbd5e1; background: #0f172a; padding: 12px; border-radius: 8px; }
  a { color: #38bdf8; }
</style>
</head>
<body>
<header>
  <strong>RxForge · Founder Sign-Off Queue</strong>
  <span id="stats">Loading…</span>
</header>
<main id="app"></main>
<script>
let queue = [];
async function load() {
  const res = await fetch('/api/pending').then(r => r.json());
  queue = res.items;
  document.getElementById('stats').textContent =
    \`Pending: \${res.stats.pendingQuestions} | Approved: \${res.stats.approvedQuestions} | Drugs: \${res.stats.drugs}\`;
  render();
}
function render() {
  const el = document.getElementById('app');
  if (!queue.length) {
    el.innerHTML = '<div class="card"><h3>All caught up! Zero pending questions.</h3><p>Run <code>npm run export:pack</code> to compile the iOS SQLite bundle.</p></div>';
    return;
  }
  const q = queue[0];
  const choices = JSON.parse(q.choices_json);
  el.innerHTML = \`
    <div class="card">
      <div style="font-size:13px;color:#38bdf8;margin-bottom:8px;">\${q.exam_code} · \${q.domain_code} · Difficulty \${q.difficulty}/5</div>
      <h3 style="line-height:1.45;">\${q.stem}</h3>
      \${choices.map(c => \`
        <div class="choice \${c.id === q.correct_choice_id ? 'correct' : ''}">
          <strong>\${c.id}. \${c.text}</strong>
          <div class="rationale">\${c.rationale}</div>
        </div>
      \`).join('')}
      <p style="font-size:14px;color:#e2e8f0;"><strong>Explanation:</strong> \${q.explanation}</p>
      <div class="actions">
        <button class="approve" onclick="decide('approved')">Approve [A]</button>
        <button class="reject" onclick="decide('rejected')">Reject [R]</button>
      </div>
    </div>
    <div class="card">
      <h4>FDA SPL Source & Blind Critic Audit</h4>
      <p><strong>Quote:</strong> \${q.citation_quote}</p>
      <p><a href="\${q.citation_url}" target="_blank">Open Official DailyMed Label ↗</a></p>
      <pre>\${q.raw_label_excerpt || 'N/A'}</pre>
      <h4>Blind Critic Audit</h4>
      <pre>\${q.blind_critic_json || '{}'}</pre>
    </div>
  \`;
}
async function decide(status) {
  if (!queue.length) return;
  const id = queue[0].id;
  await fetch('/api/decision', { method: 'POST', body: JSON.stringify({ id, status }) });
  await load();
}
window.addEventListener('keydown', e => {
  if (e.key === 'a' || e.key === 'A') decide('approved');
  if (e.key === 'r' || e.key === 'R') decide('rejected');
});
load();
</script>
</body>
</html>`;
