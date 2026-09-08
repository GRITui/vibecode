import Foundation

/// Pure, dependency-free renderer for the service-health dashboard page served at `GET /dashboard`.
public enum DashboardHTML {
    public static func render() -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>VibeCode Dashboard</title>
        <style>
          :root { color-scheme: dark light; }
          body {
            margin: 0; padding: 24px;
            background: #0f1115; color: #e6e6e6;
            font: 14px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          }
          h1 { font-size: 20px; margin: 0 0 4px; }
          h2 { font-size: 15px; margin: 24px 0 8px; color: #9aa0a6; text-transform: uppercase; letter-spacing: 0.05em; }
          .subtitle { color: #9aa0a6; margin-bottom: 16px; }
          .cards { display: flex; flex-wrap: wrap; gap: 12px; }
          .card {
            background: #1b1e26; border: 1px solid #2a2e37; border-radius: 8px;
            padding: 12px 16px; min-width: 180px;
          }
          .card .label { color: #9aa0a6; font-size: 12px; }
          .card .value { font-size: 18px; font-weight: 600; margin-top: 4px; }
          .ok { color: #4caf50; }
          .bad { color: #f44336; }
          .empty { color: #9aa0a6; font-style: italic; }
          .board { display: flex; gap: 12px; align-items: flex-start; }
          .column { flex: 1; min-width: 0; background: #1b1e26; border-radius: 8px; padding: 10px; }
          .column h3 { margin: 0 0 8px; font-size: 13px; color: #9aa0a6; }
          .item {
            background: #262a33; border-radius: 6px; padding: 8px 10px; margin-bottom: 8px;
            font-size: 13px; word-wrap: break-word;
          }
          .item .section { color: #9aa0a6; font-size: 11px; }
          .item .notes { color: #9aa0a6; font-size: 12px; margin-top: 4px; }
          .actions { display: flex; gap: 8px; margin-top: 8px; flex-wrap: wrap; }
          button {
            background: #2a6df4; color: white; border: none; border-radius: 6px;
            padding: 8px 14px; font-size: 13px; cursor: pointer;
          }
          button:hover { background: #1f5adb; }
          #actionResult {
            margin-top: 10px; padding: 10px; background: #1b1e26; border-radius: 6px;
            font-family: ui-monospace, monospace; font-size: 12px; white-space: pre-wrap; display: none;
          }
        </style>
        </head>
        <body>
          <h1>VibeCode Dashboard</h1>
          <div class="subtitle">Service health, roadmap, and health-delegation actions</div>

          <h2>Service Health</h2>
          <div class="cards" id="healthCards"><div class="empty">Loading…</div></div>

          <h2>Roadmap</h2>
          <div class="board" id="board">
            <div class="column"><h3>Todo</h3><div id="col-todo"></div></div>
            <div class="column"><h3>In Progress</h3><div id="col-in_progress"></div></div>
            <div class="column"><h3>Done</h3><div id="col-done"></div></div>
          </div>

          <h2>Health Actions</h2>
          <div class="actions">
            <button id="delegateBtn">Delegate to small model</button>
            <button id="notifyBtn">Notify via n8n</button>
          </div>
          <div id="actionResult"></div>

          <script>
          function el(tag, cls, text) {
            var e = document.createElement(tag);
            if (cls) e.className = cls;
            if (text !== undefined) e.textContent = text;
            return e;
          }

          function renderHealth(status, health) {
            var container = document.getElementById('healthCards');
            container.innerHTML = '';

            var summary = el('div', 'card');
            summary.appendChild(el('div', 'label', 'Bot'));
            summary.appendChild(el('div', 'value ' + (status && status.botRunning ? 'ok' : 'bad'),
              status ? (status.botRunning ? 'Running' : 'Stopped') : 'Unknown'));
            container.appendChild(summary);

            var orb = el('div', 'card');
            orb.appendChild(el('div', 'label', 'OrbStack'));
            orb.appendChild(el('div', 'value ' + (status && status.orbStackConnected ? 'ok' : 'bad'),
              status ? (status.orbStackConnected ? 'Connected' : 'Disconnected') : 'Unknown'));
            container.appendChild(orb);

            var containers = el('div', 'card');
            containers.appendChild(el('div', 'label', 'Active Containers'));
            containers.appendChild(el('div', 'value', status ? String(status.activeContainers) : '—'));
            container.appendChild(containers);

            if (!health) {
              container.appendChild(el('div', 'card empty', 'No health check has run yet'));
              return;
            }

            (health.checks || []).forEach(function (check) {
              var card = el('div', 'card');
              card.appendChild(el('div', 'label', check.component));
              card.appendChild(el('div', 'value ' + (check.healthy ? 'ok' : 'bad'),
                check.healthy ? '✓ ' + check.status : '✗ ' + (check.errorMessage || check.status)));
              container.appendChild(card);
            });
          }

          function renderBoard(sections) {
            var cols = { todo: document.getElementById('col-todo'),
                         in_progress: document.getElementById('col-in_progress'),
                         done: document.getElementById('col-done') };
            cols.todo.innerHTML = ''; cols.in_progress.innerHTML = ''; cols.done.innerHTML = '';

            sections.forEach(function (section) {
              section.items.forEach(function (item) {
                var col = cols[item.status] || cols.todo;
                var card = el('div', 'item');
                card.appendChild(el('div', 'section', section.name));
                card.appendChild(el('div', '', item.title));
                if (item.notes) card.appendChild(el('div', 'notes', item.notes));
                col.appendChild(card);
              });
            });
          }

          function refreshHealth() {
            Promise.all([
              fetch('/status').then(function (r) { return r.ok ? r.json() : null; }).catch(function () { return null; }),
              fetch('/health').then(function (r) { return r.status === 204 ? null : r.json(); }).catch(function () { return null; })
            ]).then(function (results) {
              renderHealth(results[0], results[1]);
            });
          }

          function refreshRoadmap() {
            fetch('/roadmap.json').then(function (r) { return r.json(); }).then(renderBoard).catch(function () {});
          }

          function showResult(obj) {
            var box = document.getElementById('actionResult');
            box.style.display = 'block';
            box.textContent = JSON.stringify(obj, null, 2);
          }

          document.getElementById('delegateBtn').addEventListener('click', function () {
            fetch('/health/delegate', { method: 'POST' })
              .then(function (r) { return r.status === 204 ? { message: 'No health prompt available yet' } : r.json(); })
              .then(showResult)
              .catch(function (e) { showResult({ error: String(e) }); });
          });

          document.getElementById('notifyBtn').addEventListener('click', function () {
            fetch('/webhook/n8n', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ source: 'dashboard', action: 'manual-trigger' })
            })
              .then(function (r) { return r.json(); })
              .then(showResult)
              .catch(function (e) { showResult({ error: String(e) }); });
          });

          refreshHealth();
          refreshRoadmap();
          setInterval(refreshHealth, 5000);
          </script>
        </body>
        </html>
        """
    }
}
