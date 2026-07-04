/**
 * ESX Rechnungssystem – Billing Dashboard
 */

var state = {
    tab: 'overview',
    subTab: 'created',
    filter: 'all',
    search: '',
    data: null,
    adminTab: 'invoices',
    createRecipients: { players: [], societies: [] },
    signatureDirty: false,
    adminInvoices: [],
    jobs: [],
    jobSettings: {},
    societies: [],
    societyInfo: {},
    globalSettings: {},
    selectedInvoice: null,
    pendingTemplate: null,
    chartScope: 'created',
    chartRange: 14
};

function getResourceName() {
    return (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'esx_rechnungen';
}

function nuiFetch(event, data) {
    return fetch('https://' + getResourceName() + '/' + event, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    }).then(function(r) { return r.json(); }).catch(function() { return {}; });
}

function closeMenu() {
    document.getElementById('billing-root').classList.remove('open');
    setTimeout(function() {
        document.getElementById('billing-root').classList.add('hidden');
    }, 280);
    closeDetailModal();
    nuiFetch('close');
}

function formatMoney(n) {
    var v = parseFloat(n) || 0;
    return v.toFixed(2).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, '.') + ' €';
}

function formatMoneyShort(n) {
    var v = parseFloat(n) || 0;
    if (v === Math.floor(v)) {
        return Math.floor(v).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.') + ' €';
    }
    return formatMoney(v);
}

function formatDate(d) {
    if (!d) return '-';
    var s = String(d);
    var m = s.match(/(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?/);
    if (!m) return d;
    var out = m[3] + '.' + m[2] + '.' + m[1];
    if (m[4]) out += ' ' + m[4] + ':' + m[5];
    return out;
}

function statusLabel(s) {
    var loc = (state.data && state.data.locale) || {};
    return {
        open: loc.status_open || 'OFFEN',
        paid: loc.status_paid || 'BEZAHLT',
        overdue: loc.status_overdue || 'ÜBERFÄLLIG',
        cancelled: loc.status_cancelled || 'STORNIERT',
        rejected: loc.status_rejected || 'ABGELEHNT'
    }[s] || s;
}

function statusClass(s) {
    return { open: 'status-open', paid: 'status-paid', overdue: 'status-overdue', cancelled: 'status-cancelled', rejected: 'status-cancelled' }[s] || '';
}

function applyTheme(ui) {
    if (!ui || !ui.colors) return;
    var c = ui.colors;
    var root = document.documentElement;
    root.style.setProperty('--accent', c.accent || '#7d52ff');
    root.style.setProperty('--accent-glow', c.accent_glow || 'rgba(125, 82, 255, 0.45)');
    root.style.setProperty('--bg-panel', c.background || 'rgba(15, 15, 19, 0.94)');
    root.style.setProperty('--bg-card', c.card || 'rgba(20, 20, 28, 0.85)');
    root.style.setProperty('--text', c.text || '#ffffff');
    root.style.setProperty('--text-dim', c.text_dim || '#9b95b0');
    root.style.setProperty('--success', c.success || '#3dd68c');
    root.style.setProperty('--warning', c.warning || '#f5a623');
    root.style.setProperty('--danger', c.danger || '#f06565');
    root.style.setProperty('--info', c.info || '#5b9cf5');
    if (ui.logo) {
        var logo = document.querySelector('.billing-logo');
        if (logo) logo.textContent = ui.logo;
    }
}

function esc(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
}

function boolVal(v) { return v === 'true' || v === true; }

function chk(id, label, checked) {
    return '<label class="check-row"><input type="checkbox" id="' + id + '"' + (checked ? ' checked' : '') + '>' + label + '</label>';
}

function refreshDashboard(cb) {
    nuiFetch('getDashboardData').then(function(data) {
        if (data && data.playerName) {
            state.data = data;
            document.getElementById('billing-player-name').textContent = data.playerName;
            updateTabsVisibility();
            if (cb) cb();
        }
    });
}

function updateTabsVisibility() {
    var d = state.data || {};
    var adminBtn = document.getElementById('btn-admin');
    var createTab = document.querySelector('.billing-tab[data-tab="create"]');
    if (adminBtn) {
        adminBtn.classList.toggle('hidden', !d.isAdmin);
        setIcon(adminBtn, 'shield', 16);
    }
    if (createTab) {
        createTab.classList.toggle('disabled', !d.canCreate);
        createTab.title = d.canCreate ? '' : 'Mit deinem Job nicht verfügbar';
    }
}

function setActiveTab(tab) {
    state.tab = tab;
    var panel = document.getElementById('billing-panel');
    var header = document.querySelector('.billing-header');
    var tabs = document.getElementById('billing-tabs');
    var isCreate = tab === 'create' && state.data && state.data.canCreate;

    if (panel) panel.classList.toggle('invoice-create-mode', isCreate);
    if (header) header.classList.toggle('hidden', isCreate);
    if (tabs) tabs.classList.toggle('hidden', isCreate);

    document.querySelectorAll('.billing-tab').forEach(function(t) {
        t.classList.toggle('active', t.dataset.tab === tab);
    });
    renderCurrentTab();
}

function openAdminPanel() {
    if (!(state.data && state.data.isAdmin)) return;
    state.tab = 'admin';
    var panel = document.getElementById('billing-panel');
    var header = document.querySelector('.billing-header');
    var tabs = document.getElementById('billing-tabs');
    if (panel) panel.classList.remove('invoice-create-mode');
    if (header) header.classList.remove('hidden');
    if (tabs) tabs.classList.remove('hidden');
    document.querySelectorAll('.billing-tab').forEach(function(t) { t.classList.remove('active'); });
    renderAdmin();
}

function renderCurrentTab() {
    if (state.tab === 'overview') renderOverview();
    else if (state.tab === 'statistics') renderStatistics();
    else if (state.tab === 'templates') renderTemplates();
    else if (state.tab === 'create') renderCreate();
    else if (state.tab === 'admin') renderAdmin();
}

// ============================================================
// ÜBERSICHT
// ============================================================

function renderOverview() {
    var d = state.data || {};
    var stats = d.stats || {};
    var html = '<div class="stats-grid">' +
        statCard('GESAMT RECHNUNGEN', stats.total || 0) +
        statCard('OFFENE RECHNUNGEN', stats.open || 0) +
        statCard('OFFENER BETRAG', formatMoneyShort(stats.open_amount || 0)) +
        statCard('HEUTE', (stats.today_count || 0) + ' (' + formatMoneyShort(stats.today_amount || 0) + ')') +
        '</div>';

    html += '<div class="list-toolbar">' +
        '<div class="sub-tabs">' +
        '<button class="sub-tab' + (state.subTab === 'created' ? ' active' : '') + '" data-sub="created" type="button">ERSTELLT</button>' +
        '<button class="sub-tab' + (state.subTab === 'received' ? ' active' : '') + '" data-sub="received" type="button">EMPFANGEN</button>' +
        '</div>' +
        '<div class="list-filters">' +
        '<select class="filter-select" id="invoice-filter">' +
        '<option value="all">Alle</option>' +
        '<option value="open">Offen</option>' +
        '<option value="paid">Bezahlt</option>' +
        '<option value="overdue">Überfällig</option>' +
        '<option value="cancelled">Storniert</option>' +
        '<option value="rejected">Abgelehnt</option>' +
        '</select>' +
        '<div class="search-wrap">' +
        iconHtml('search', 14) +
        '<input class="search-input" id="invoice-search" type="text" placeholder="Suchen..." value="' + esc(state.search) + '">' +
        '</div></div></div>';

    html += '<div class="invoice-list" id="invoice-list"></div>';

    document.getElementById('billing-body').innerHTML = html;

    document.getElementById('invoice-filter').value = state.filter;
    document.getElementById('invoice-filter').onchange = function() {
        state.filter = this.value;
        renderInvoiceList();
    };
    document.getElementById('invoice-search').oninput = function() {
        state.search = this.value.toLowerCase();
        renderInvoiceList();
    };

    document.querySelectorAll('.sub-tab').forEach(function(btn) {
        btn.onclick = function() {
            state.subTab = btn.dataset.sub;
            document.querySelectorAll('.sub-tab').forEach(function(b) {
                b.classList.toggle('active', b === btn);
            });
            renderInvoiceList();
        };
    });

    renderInvoiceList();
}

function statCard(label, value) {
    return '<div class="stat-card"><div class="stat-label">' + label + '</div><div class="stat-value">' + value + '</div></div>';
}

function getInvoiceList() {
    var d = state.data || {};
    return state.subTab === 'created' ? (d.created || []) : (d.received || []);
}

function renderInvoiceList() {
    var list = getInvoiceList();
    var filtered = list.filter(function(inv) {
        if (state.filter !== 'all' && inv.payment_status !== state.filter) return false;
        if (state.search) {
            var hay = [
                inv.invoice_number, inv.reason, inv.issuer_name, inv.recipient_name,
                inv.payment_status, statusLabel(inv.payment_status)
            ].join(' ').toLowerCase();
            if (hay.indexOf(state.search) === -1) return false;
        }
        return true;
    });

    var el = document.getElementById('invoice-list');
    if (!el) return;

    if (filtered.length === 0) {
        el.innerHTML = '<div class="empty-state"><div class="icon-wrap">' + iconHtml('inbox', 40) + '</div>Keine Rechnungen in dieser Ansicht</div>';
        return;
    }

    el.innerHTML = filtered.map(function(inv) {
        var gross = parseFloat(inv.gross_amount) || 0;
        var rem = inv.payment_status === 'overdue' ? (parseFloat(inv.reminder_fee) || 0) : 0;
        var total = gross + rem;
        var canDelete = state.data && state.data.isAdmin;

        return '<div class="invoice-row" data-id="' + inv.id + '">' +
            '<div class="invoice-row-main">' +
            '<div class="invoice-row-top">' +
            '<span class="invoice-number">' + esc(inv.invoice_number) + '</span>' +
            '<span class="status-badge ' + statusClass(inv.payment_status) + '">' + statusLabel(inv.payment_status) + '</span>' +
            '<span class="date-pill">' + formatDate(inv.created_at) + '</span>' +
            '</div>' +
            '<div class="invoice-row-meta">' +
            '<span>Ersteller: <strong>' + esc(inv.issuer_name || '-') + '</strong></span>' +
            '<span>Empfänger: <strong>' + esc(inv.recipient_name || '-') + '</strong></span>' +
            '<span>Betrag: <strong>' + formatMoneyShort(total) + '</strong></span>' +
            '</div></div>' +
            '<div class="invoice-row-actions">' +
            '<button class="btn btn-view" type="button" data-view="' + inv.id + '">ANSEHEN</button>' +
            (canDelete ? '<button class="btn btn-icon btn-del" type="button" data-del="' + inv.id + '" title="Löschen">' + iconHtml('trash', 14) + '</button>' : '') +
            '</div></div>';
    }).join('');

    el.querySelectorAll('[data-view]').forEach(function(btn) {
        btn.onclick = function() {
            var id = parseInt(btn.getAttribute('data-view'));
            var inv = filtered.find(function(i) { return i.id === id; });
            if (inv) openDetailModal(inv, state.subTab === 'received');
        };
    });

    el.querySelectorAll('[data-del]').forEach(function(btn) {
        btn.onclick = function() {
            var id = parseInt(btn.getAttribute('data-del'));
            showConfirm('Rechnung unwiderruflich löschen?', { title: 'Löschen', danger: true, confirmText: 'Löschen' }).then(function(ok) {
                if (!ok) return;
                nuiFetch('deleteInvoice', { invoiceId: id });
                showToast('Gelöscht', 'success');
                refreshDashboard(renderOverview);
            });
        };
    });
}

function iconHtml(name, size) {
    var el = createIconElement(name, size);
    if (!el) return '';
    var wrap = document.createElement('div');
    wrap.appendChild(el);
    return wrap.innerHTML;
}

// ============================================================
// DETAIL MODAL
// ============================================================

function closeDetailModal() {
    document.getElementById('detail-modal').classList.add('hidden');
    state.selectedInvoice = null;
}

function openDetailModal(inv, canPay) {
    state.selectedInvoice = inv;
    var gross = parseFloat(inv.gross_amount) || 0;
    var rem = inv.payment_status === 'overdue' ? (parseFloat(inv.reminder_fee) || 0) : 0;
    var total = gross + rem;

    document.getElementById('detail-title').textContent = inv.invoice_number;
    var badge = document.getElementById('detail-badge');
    badge.textContent = statusLabel(inv.payment_status);
    badge.className = 'status-badge ' + statusClass(inv.payment_status);

    setIcon(document.getElementById('detail-close'), 'x', 16);

    var body = '';
    body += detailRow('Aussteller', inv.issuer_name || '-');
    body += detailRow('Empfänger', inv.recipient_name || '-');
    body += detailRow('Grund', inv.reason || '-');
    if (inv.notes) body += detailRow('Notizen', inv.notes);
    if (inv.line_items) {
        try {
            var items = typeof inv.line_items === 'string' ? JSON.parse(inv.line_items) : inv.line_items;
            if (items && items.length) {
                body += '<div class="section-title" style="margin-top:12px">POSITIONEN</div>';
                items.forEach(function(item) {
                    body += detailRow(esc(item.description || '-'), (item.units || 1) + ' × ' + formatMoney(item.price || 0));
                });
            }
        } catch (e) { /* ignore */ }
    }
    body += detailRow('Erstellt', formatDate(inv.created_at));
    body += detailRow('Fällig', formatDate(inv.due_date));
    body += detailRow('Netto', formatMoney(inv.net_amount));
    body += detailRow('Steuer', (inv.tax_rate || 0) + '% (' + formatMoney(inv.tax_amount) + ')');
    if (rem > 0) body += detailRow('Mahngebühr', formatMoney(rem));
    body += detailRow('Brutto', formatMoney(total), true);

    document.getElementById('detail-body').innerHTML = body;

    var footer = document.getElementById('detail-footer');
    footer.innerHTML = '';

    if (canPay && (inv.payment_status === 'open' || inv.payment_status === 'overdue')) {
        footer.innerHTML = '<div class="btn-row">' +
            '<button class="btn btn-success" id="pay-bank" type="button">' + iconHtml('credit-card', 14) + ' Bank</button>' +
            '<button class="btn btn-success" id="pay-cash" type="button">' + iconHtml('banknote', 14) + ' Bar</button>';
        if (state.data && state.data.rejection_enabled) {
            footer.innerHTML += '<button class="btn btn-danger" id="pay-reject" type="button">' + ((state.data.locale && state.data.locale.ui_reject) || 'ABLEHNEN') + '</button>';
        }
        footer.innerHTML += '</div>';
        document.getElementById('pay-bank').onclick = function() {
            nuiFetch('payInvoice', { invoiceId: inv.id, paymentMethod: 'bank' });
            showToast('Zahlung wird verarbeitet...', 'info');
            closeDetailModal();
            setTimeout(function() { refreshDashboard(renderOverview); }, 800);
        };
        document.getElementById('pay-cash').onclick = function() {
            nuiFetch('payInvoice', { invoiceId: inv.id, paymentMethod: 'cash' });
            showToast('Zahlung wird verarbeitet...', 'info');
            closeDetailModal();
            setTimeout(function() { refreshDashboard(renderOverview); }, 800);
        };
        var rejectBtn = document.getElementById('pay-reject');
        if (rejectBtn) rejectBtn.onclick = function() {
            showPrompt('Ablehnungsgrund (Pflicht):', '', { title: 'Rechnung ablehnen' }).then(function(reason) {
                if (!reason || reason.trim() === '') return;
                nuiFetch('rejectInvoice', { invoiceId: inv.id, reason: reason.trim() });
                showToast('Rechnung abgelehnt', 'success');
                closeDetailModal();
                setTimeout(function() { refreshDashboard(renderOverview); }, 600);
            });
        };
    }

    document.getElementById('detail-modal').classList.remove('hidden');
}

function detailRow(label, val, total) {
    return '<div class="detail-row' + (total ? ' total' : '') + '"><span>' + label + '</span><span>' + esc(val) + '</span></div>';
}

// ============================================================
// STATISTIK
// ============================================================

function renderStatistics() {
    var d = state.data || {};
    var stats = d.stats || {};
    var chart = stats.chart || { labels: [], values: [] };

    var html = '<div class="stats-page-top">' +
        '<div class="stat-block"><div class="big">' + (stats.total || 0) + '</div><div class="lbl">RECHNUNGEN</div></div>' +
        '<div class="stat-block"><div class="big">' + formatMoneyShort(stats.total_amount || 0) + '</div><div class="lbl">GESAMTBETRAG</div></div>' +
        '<div class="stat-block"><div class="big">' + formatMoneyShort(stats.avg_invoice || 0) + '</div><div class="lbl">Ø / RECHNUNG</div></div>' +
        '<div class="stat-block"><div class="big">' + formatMoneyShort(stats.avg_day || 0) + '</div><div class="lbl">Ø / TAG</div></div>' +
        '</div>';

    html += '<div class="chart-card">' +
        '<div class="chart-card-header"><h3>DIAGRAMM</h3>' +
        '<div class="chart-filters">' +
        '<select id="chart-scope"><option value="created">Erstellt</option><option value="received">Empfangen</option></select>' +
        '<select id="chart-range"><option value="7">1 Woche</option><option value="14" selected>2 Wochen</option></select>' +
        '</div></div>' +
        '<svg class="chart-svg" id="line-chart" viewBox="0 0 800 180" preserveAspectRatio="none"></svg></div>';

    html += '<div class="stats-bottom">' +
        '<div class="donut-card"><h3>STATUS</h3><div class="donut-wrap">' +
        '<svg class="donut-svg" id="donut-chart" viewBox="0 0 120 120"></svg>' +
        '<div class="donut-legend">' +
        '<div class="legend-item"><span class="legend-dot open"></span>Offen<strong>' + (stats.open || 0) + '</strong></div>' +
        '<div class="legend-item"><span class="legend-dot overdue"></span>Überfällig<strong>' + (stats.overdue || 0) + '</strong></div>' +
        '<div class="legend-item"><span class="legend-dot paid"></span>Bezahlt<strong>' + (stats.paid || 0) + '</strong></div>' +
        '</div></div></div>' +
        '<div class="recent-card"><h3>LETZTE ZAHLUNGEN</h3><div class="recent-list" id="recent-payments"></div></div>' +
        '</div>';

    document.getElementById('billing-body').innerHTML = html;

    document.getElementById('chart-scope').value = state.chartScope;
    document.getElementById('chart-range').value = String(state.chartRange);
    document.getElementById('chart-scope').onchange = function() {
        state.chartScope = this.value;
        drawLineChart(getChartData());
    };
    document.getElementById('chart-range').onchange = function() {
        state.chartRange = parseInt(this.value) || 14;
        drawLineChart(getChartData());
    };

    drawLineChart(getChartData());
    drawDonutChart(stats.open || 0, stats.overdue || 0, stats.paid || 0);
    renderRecentPayments(stats.recent_payments || []);
}

function getChartData() {
    var stats = (state.data && state.data.stats) || {};
    var key = state.chartScope === 'received' ? 'chart_received' : 'chart_created';
    var chart = stats[key] || stats.chart || { labels: [], values: [] };
    var range = state.chartRange || 14;
    var labels = (chart.labels || []).slice(-range);
    var values = (chart.values || []).slice(-range);
    return { labels: labels, values: values };
}

function drawLineChart(data) {
    var svg = document.getElementById('line-chart');
    if (!svg) return;

    var labels = data.labels || [];
    var values = data.values || [];
    var w = 800, h = 180, pad = { t: 20, r: 20, b: 30, l: 50 };
    var max = Math.max.apply(null, values.concat([1]));

    var points = [];
    var step = labels.length > 1 ? (w - pad.l - pad.r) / (labels.length - 1) : 0;

    for (var i = 0; i < values.length; i++) {
        var x = pad.l + step * i;
        var y = pad.t + (h - pad.t - pad.b) * (1 - values[i] / max);
        points.push(x + ',' + y);
    }

    var linePath = points.length ? 'M' + points.join(' L') : '';
    var areaPath = linePath;
    if (points.length) {
        areaPath += ' L' + (pad.l + step * (values.length - 1)) + ',' + (h - pad.b);
        areaPath += ' L' + pad.l + ',' + (h - pad.b) + ' Z';
    }

    var grid = '';
    for (var g = 0; g <= 4; g++) {
        var gy = pad.t + (h - pad.t - pad.b) * (g / 4);
        grid += '<line x1="' + pad.l + '" y1="' + gy + '" x2="' + (w - pad.r) + '" y2="' + gy + '" stroke="rgba(125,82,255,0.1)" stroke-width="1"/>';
    }

    var xLabels = '';
    labels.forEach(function(lbl, i) {
        if (labels.length > 8 && i % 2 !== 0 && i !== labels.length - 1) return;
        var x = pad.l + step * i;
        xLabels += '<text x="' + x + '" y="' + (h - 8) + '" fill="#6b6578" font-size="11" text-anchor="middle">' + esc(lbl) + '</text>';
    });

    svg.innerHTML = grid +
        '<defs><linearGradient id="chartGrad" x1="0" y1="0" x2="0" y2="1">' +
        '<stop offset="0%" stop-color="#7d52ff" stop-opacity="0.35"/>' +
        '<stop offset="100%" stop-color="#7d52ff" stop-opacity="0"/></linearGradient></defs>' +
        (areaPath ? '<path d="' + areaPath + '" fill="url(#chartGrad)"/>' : '') +
        (linePath ? '<path d="' + linePath + '" fill="none" stroke="#7d52ff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>' : '') +
        xLabels;
}

function drawDonutChart(open, overdue, paid) {
    var svg = document.getElementById('donut-chart');
    if (!svg) return;

    var total = open + overdue + paid;
    if (total === 0) {
        svg.innerHTML = '<circle cx="60" cy="60" r="42" fill="none" stroke="rgba(125,82,255,0.15)" stroke-width="14"/>' +
            '<text x="60" y="58" text-anchor="middle" fill="#9b95b0" font-size="11" font-weight="700">Total</text>' +
            '<text x="60" y="74" text-anchor="middle" fill="#7d52ff" font-size="16" font-weight="800">0</text>';
        return;
    }

    var segments = [
        { val: open, color: '#5b9cf5' },
        { val: overdue, color: '#f5a623' },
        { val: paid, color: '#3dd68c' }
    ];

    var r = 42, cx = 60, cy = 60, circ = 2 * Math.PI * r;
    var offset = 0;
    var arcs = '';

    segments.forEach(function(seg) {
        if (seg.val <= 0) return;
        var len = (seg.val / total) * circ;
        arcs += '<circle cx="' + cx + '" cy="' + cy + '" r="' + r + '" fill="none" stroke="' + seg.color + '" stroke-width="14" ' +
            'stroke-dasharray="' + len + ' ' + (circ - len) + '" stroke-dashoffset="' + (-offset) + '" transform="rotate(-90 ' + cx + ' ' + cy + ')"/>';
        offset += len;
    });

    svg.innerHTML = arcs +
        '<text x="60" y="56" text-anchor="middle" fill="#9b95b0" font-size="10" font-weight="700">Total</text>' +
        '<text x="60" y="74" text-anchor="middle" fill="#7d52ff" font-size="18" font-weight="800">' + total + '</text>';
}

function renderRecentPayments(payments) {
    var el = document.getElementById('recent-payments');
    if (!el) return;

    if (!payments.length) {
        el.innerHTML = '<div class="empty-state" style="padding:20px">Keine Zahlungen</div>';
        return;
    }

    el.innerHTML = payments.map(function(p) {
        var st = p.status === 'cancelled' ? 'cancelled' : (p.status === 'rejected' ? 'rejected' : 'paid');
        var lbl = p.status === 'cancelled' ? 'STORNIERT' : (p.status === 'rejected' ? 'ABGELEHNT' : 'BEZAHLT');
        var desc = p.status === 'cancelled'
            ? ('Storniert – ' + esc(p.invoice_number))
            : (p.status === 'rejected'
                ? ('Abgelehnt – ' + esc(p.invoice_number))
                : (esc(p.payer_name || 'Unbekannt') + ' bezahlte ' + formatMoneyShort(p.amount)));
        return '<div class="recent-item">' +
            '<div class="recent-item-top">' +
            '<span class="status-badge status-' + (st === 'paid' ? 'paid' : 'cancelled') + '">' + lbl + '</span>' +
            '<span class="recent-id">' + esc(p.invoice_number) + '</span>' +
            '<span class="recent-time">' + formatDate(p.paid_at || p.created_at) + '</span>' +
            '</div><div class="recent-desc">' + desc + '</div></div>';
    }).join('');
}

// ============================================================
// VORLAGEN
// ============================================================

function renderTemplates() {
    var d = state.data || {};
    var templates = (d.createData && d.createData.templates) || DEFAULT_TEMPLATES;

    if (!d.canCreate) {
        document.getElementById('billing-body').innerHTML =
            '<div class="empty-state">Vorlagen sind nur für berechtigte Jobs verfügbar.</div>';
        return;
    }

    document.getElementById('billing-body').innerHTML =
        '<div class="section-title">RECHNUNGS-VORLAGEN</div>' +
        '<div class="template-grid" id="template-grid"></div>';

    var grid = document.getElementById('template-grid');
    grid.innerHTML = templates.map(function(tpl, i) {
        var preview = (tpl.items || []).map(function(it) {
            return it.description + ' (' + formatMoneyShort((it.units || 1) * (it.price || 0)) + ')';
        }).join(', ');
        return '<div class="template-card" data-idx="' + i + '">' +
            '<h4>' + esc(tpl.name) + '</h4>' +
            '<p>' + esc(tpl.notes || 'Schnellvorlage für häufige Rechnungen') + '</p>' +
            '<div class="template-preview">' + esc(preview) + '</div></div>';
    }).join('');

    grid.querySelectorAll('.template-card').forEach(function(card) {
        card.onclick = function() {
            state.pendingTemplate = parseInt(card.dataset.idx);
            setActiveTab('create');
        };
    });
}

function barRow(label, val, max, cls) {
    var pct = Math.round((val / max) * 100);
    return '<div class="bar-row"><span>' + label + '</span>' +
        '<div class="bar-track"><div class="bar-fill ' + cls + '" style="width:' + pct + '%"></div></div>' +
        '<span>' + val + '</span></div>';
}

// ============================================================
// RECHNUNG ERSTELLEN (Papier-Layout)
// ============================================================

var DEFAULT_TEMPLATES = [
    { name: 'Reparatur', items: [{ description: 'Reparatur', units: 1, price: 100 }], notes: '' },
    { name: 'Dienstleistung', items: [{ description: 'Dienstleistung', units: 1, price: 250 }], notes: '' },
    { name: 'Material', items: [{ description: 'Material', units: 1, price: 50 }], notes: '' }
];

function renderCreate() {
    var d = state.data || {};
    if (!d.canCreate || !d.createData) {
        document.getElementById('billing-panel').classList.remove('invoice-create-mode');
        document.querySelector('.billing-header').classList.remove('hidden');
        document.getElementById('billing-tabs').classList.remove('hidden');
        document.getElementById('billing-body').innerHTML =
            '<div class="empty-state"><div class="icon-wrap">' + iconHtml('x', 40) + '</div>' +
            'Du darfst mit deinem aktuellen Job keine Rechnungen ausstellen.<br>Bitte wende dich an einen Administrator.</div>';
        return;
    }

    var data = d.createData;
    var s = data.settings || {};
    var job = data.job || {};
    var society = data.societyInfo || {};
    var playerName = d.playerName || 'Spieler';
    var companyName = society.company_name || job.label || 'Firma';
    var taxRate = parseFloat(s.tax_rate) || 19;
    var templates = data.templates || DEFAULT_TEMPLATES;
    var durations = (state.data && state.data.durations) || [
        { label: '3 Tage', days: 3 }, { label: '1 Woche', days: 7 },
        { label: '2 Wochen', days: 14 }, { label: '1 Monat', days: 30 }
    ];
    var durationHtml = durations.map(function(d, i) {
        return '<option value="' + d.days + '"' + (d.days === 7 ? ' selected' : '') + '>' + esc(d.label) + '</option>';
    }).join('');

    document.getElementById('billing-body').innerHTML =
        '<div class="invoice-stack">' +
        '<div class="invoice-sheet-back"></div>' +
        '<div class="invoice-sheet-mid"></div>' +
        '<div class="invoice-sheet">' +
        '<header class="invoice-sheet-header">' +
        '<div class="invoice-sheet-title"><h2>RECHNUNG</h2><p>RECHNUNG ERSTELLEN</p></div>' +
        '<button class="invoice-sheet-esc" id="invoice-esc" type="button">ESC</button>' +
        '</header>' +
        '<div class="invoice-meta-grid">' +
        '<div class="invoice-field"><label>AUSSTELLER</label>' +
        '<select id="inv-issuer"><option value="personal">Persönlich</option><option value="company">Firma</option></select>' +
        '<div class="invoice-field-hint" id="issuer-hint">* ' + esc(playerName) + '</div></div>' +
        '<div class="invoice-field"><label>EMPFÄNGER</label><select id="inv-recipient"><option value="">Lädt...</option></select></div>' +
        '<div class="invoice-field"><label>FRIST</label>' +
        '<select id="inv-duration">' + durationHtml + '</select></div>' +
        '<div class="invoice-field"><label>VORLAGE</label>' +
        '<select id="inv-template"><option value="">Vorlage wählen</option>' +
        templates.map(function(t, i) { return '<option value="' + i + '">' + esc(t.name) + '</option>'; }).join('') +
        '</select></div></div>' +
        '<table class="invoice-items-table"><thead><tr>' +
        '<th class="col-num">#</th><th>Beschreibung</th><th class="col-units">Menge</th><th class="col-price">Preis</th>' +
        '</tr></thead><tbody id="invoice-items-body"></tbody></table>' +
        '<button class="btn-add-row" id="btn-add-item" type="button">+ Position hinzufügen</button>' +
        '<div class="invoice-totals"><div class="invoice-totals-box">' +
        '<div class="invoice-total-row"><span>Zwischensumme</span><span id="inv-subtotal">0,00 €</span></div>' +
        '<div class="invoice-total-row"><span>Steuer (' + taxRate + '%)</span><span id="inv-tax">0,00 €</span></div>' +
        '<div class="invoice-total-row grand"><span>Gesamt</span><span id="inv-total">0,00 €</span></div>' +
        '</div></div>' +
        '<div class="invoice-notes"><label>NOTIZEN</label>' +
        '<textarea id="inv-notes" placeholder="z.B. Privatkauf ohne Gewährleistung"></textarea></div>' +
        '<div class="invoice-footer-row">' +
        '<div class="invoice-signature"><label>UNTERSCHRIFT</label>' +
        '<div class="signature-wrap"><canvas class="signature-canvas" id="sig-canvas" width="280" height="90"></canvas>' +
        '<button class="btn-sig-clear" id="sig-clear" type="button">×</button></div></div>' +
        '<div class="invoice-actions">' +
        '<button class="btn-invoice btn-invoice-cancel" id="inv-cancel" type="button">ABBRECHEN</button>' +
        '<button class="btn-invoice btn-invoice-create" id="inv-submit" type="button">ERSTELLEN</button>' +
        '</div></div></div></div>';

    document.getElementById('invoice-esc').onclick = closeMenu;
    document.getElementById('inv-cancel').onclick = function() {
        setActiveTab('overview');
    };

    document.getElementById('inv-issuer').onchange = function() {
        var hint = document.getElementById('issuer-hint');
        hint.textContent = this.value === 'company' ? ('* ' + companyName) : ('* ' + playerName);
    };

    document.getElementById('inv-template').onchange = function() {
        var idx = this.value;
        if (idx === '') return;
        var tpl = templates[parseInt(idx)];
        if (!tpl) return;
        document.getElementById('inv-notes').value = tpl.notes || '';
        renderLineItems(tpl.items || [{ description: '', units: 1, price: 0 }]);
        updateInvoiceTotals(taxRate);
    };

    document.getElementById('btn-add-item').onclick = function() {
        addLineItemRow('', 1, 0);
        updateInvoiceTotals(taxRate);
    };

    document.getElementById('inv-submit').onclick = function() {
        submitInvoiceForm(data, s, taxRate);
    };

    renderLineItems([{ description: '', units: 1, price: 0 }]);
    initSignaturePad();
    loadCreateRecipients(s);
    updateInvoiceTotals(taxRate);

    if (state.pendingTemplate !== null && state.pendingTemplate !== undefined) {
        var tplIdx = state.pendingTemplate;
        state.pendingTemplate = null;
        setTimeout(function() {
            var sel = document.getElementById('inv-template');
            if (sel) {
                sel.value = String(tplIdx);
                sel.onchange();
            }
        }, 50);
    }
}

function loadCreateRecipients(settings) {
    var select = document.getElementById('inv-recipient');
    var promises = [];

    if (settings.can_issue_player !== 0) {
        promises.push(nuiFetch('getNearbyPlayers').then(function(p) { return { type: 'players', data: p || [] }; }));
    }
    if (settings.can_issue_society === 1) {
        promises.push(nuiFetch('getSocieties').then(function(s) { return { type: 'societies', data: s || [] }; }));
    }

    if (promises.length === 0) {
        select.innerHTML = '<option value="">Keine Berechtigung</option>';
        return;
    }

    Promise.all(promises).then(function(results) {
        state.createRecipients = { players: [], societies: [] };
        var html = '<option value="">Empfänger wählen...</option>';

        results.forEach(function(r) {
            if (r.type === 'players') {
                state.createRecipients.players = r.data;
                if (r.data.length) {
                    html += '<optgroup label="Spieler">';
                    r.data.forEach(function(p) {
                        html += '<option value="player:' + p.source + '">' + esc(p.name) + ' (' + p.distance + 'm)</option>';
                    });
                    html += '</optgroup>';
                }
            } else {
                state.createRecipients.societies = r.data;
                if (r.data.length) {
                    html += '<optgroup label="Firmen">';
                    r.data.forEach(function(s) {
                        html += '<option value="society:' + s.name + '">' + esc(s.label) + '</option>';
                    });
                    html += '</optgroup>';
                }
            }
        });

        if (html === '<option value="">Empfänger wählen...</option>') {
            html += '<option value="" disabled>Keine Empfänger verfügbar</option>';
        }
        select.innerHTML = html;
    });
}

function renderLineItems(items) {
    var tbody = document.getElementById('invoice-items-body');
    if (!tbody) return;
    tbody.innerHTML = '';
    items.forEach(function(item) {
        addLineItemRow(item.description || '', item.units || 1, item.price || 0);
    });
    if (items.length === 0) addLineItemRow('', 1, 0);
}

function addLineItemRow(desc, units, price) {
    var tbody = document.getElementById('invoice-items-body');
    if (!tbody) return;
    var tr = document.createElement('tr');
    tr.innerHTML =
        '<td class="col-num"><button class="btn-row-remove" type="button" title="Entfernen">×</button></td>' +
        '<td><input type="text" class="item-desc" value="' + esc(desc) + '" placeholder="Beschreibung" maxlength="200"></td>' +
        '<td class="col-units"><input type="number" class="item-units" value="' + units + '" min="1" step="1"></td>' +
        '<td class="col-price"><input type="number" class="item-price" value="' + price + '" min="0" step="0.01"></td>';

    tr.querySelector('.btn-row-remove').onclick = function() {
        if (tbody.children.length <= 1) {
            tr.querySelector('.item-desc').value = '';
            tr.querySelector('.item-units').value = 1;
            tr.querySelector('.item-price').value = 0;
        } else {
            tr.remove();
        }
        var taxRate = parseFloat((state.data.createData.settings || {}).tax_rate) || 19;
        updateInvoiceTotals(taxRate);
    };

    tr.querySelectorAll('input').forEach(function(inp) {
        inp.oninput = function() {
            var taxRate = parseFloat((state.data.createData.settings || {}).tax_rate) || 19;
            updateInvoiceTotals(taxRate);
        };
    });

    tbody.appendChild(tr);
}

function collectLineItems() {
    var items = [];
    document.querySelectorAll('#invoice-items-body tr').forEach(function(tr) {
        var desc = tr.querySelector('.item-desc').value.trim();
        var units = parseInt(tr.querySelector('.item-units').value) || 1;
        var price = parseFloat(tr.querySelector('.item-price').value) || 0;
        if (desc || price > 0) {
            items.push({ description: desc || 'Position', units: units, price: price });
        }
    });
    return items;
}

function updateInvoiceTotals(taxRate) {
    var items = collectLineItems();
    var subtotal = 0;
    items.forEach(function(i) { subtotal += i.units * i.price; });
    var tax = Math.round(subtotal * taxRate / 100 * 100) / 100;
    var total = subtotal + tax;

    var subEl = document.getElementById('inv-subtotal');
    var taxEl = document.getElementById('inv-tax');
    var totEl = document.getElementById('inv-total');
    if (subEl) subEl.textContent = formatMoney(subtotal);
    if (taxEl) taxEl.textContent = formatMoney(tax);
    if (totEl) totEl.textContent = formatMoney(total);
}

function initSignaturePad() {
    var canvas = document.getElementById('sig-canvas');
    if (!canvas) return;
    var ctx = canvas.getContext('2d');
    var drawing = false;
    state.signatureDirty = false;

    ctx.strokeStyle = '#1a1a24';
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';

    function getPos(e) {
        var rect = canvas.getBoundingClientRect();
        var scaleX = canvas.width / rect.width;
        var scaleY = canvas.height / rect.height;
        var clientX = e.touches ? e.touches[0].clientX : e.clientX;
        var clientY = e.touches ? e.touches[0].clientY : e.clientY;
        return { x: (clientX - rect.left) * scaleX, y: (clientY - rect.top) * scaleY };
    }

    function startDraw(e) {
        e.preventDefault();
        drawing = true;
        var p = getPos(e);
        ctx.beginPath();
        ctx.moveTo(p.x, p.y);
    }

    function draw(e) {
        if (!drawing) return;
        e.preventDefault();
        var p = getPos(e);
        ctx.lineTo(p.x, p.y);
        ctx.stroke();
        state.signatureDirty = true;
    }

    function endDraw() { drawing = false; }

    canvas.onmousedown = startDraw;
    canvas.onmousemove = draw;
    canvas.onmouseup = endDraw;
    canvas.onmouseleave = endDraw;
    canvas.ontouchstart = startDraw;
    canvas.ontouchmove = draw;
    canvas.ontouchend = endDraw;

    document.getElementById('sig-clear').onclick = function() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        state.signatureDirty = false;
    };
}

function getSignatureData() {
    var canvas = document.getElementById('sig-canvas');
    if (!canvas || !state.signatureDirty) return null;
    try { return canvas.toDataURL('image/png'); } catch (e) { return null; }
}

function submitInvoiceForm(createData, settings, taxRate) {
    var recipientVal = document.getElementById('inv-recipient').value;
    if (!recipientVal) {
        showToast('Bitte wähle einen Empfänger.', 'warning');
        return;
    }

    var items = collectLineItems();
    if (items.length === 0) {
        showToast('Bitte füge mindestens eine Position hinzu.', 'warning');
        return;
    }

    var subtotal = 0;
    items.forEach(function(i) { subtotal += i.units * i.price; });
    if (subtotal <= 0) {
        showToast('Der Rechnungsbetrag muss größer als 0 sein.', 'warning');
        return;
    }

    if ((state.data && state.data.signature_required !== false) && !state.signatureDirty) {
        showToast((state.data && state.data.locale && state.data.locale.signature_required) || 'Bitte unterschreibe die Rechnung.', 'warning');
        return;
    }

    var parts = recipientVal.split(':');
    var payload = {
        recipient_type: parts[0],
        line_items: items,
        net_amount: subtotal,
        tax_rate: taxRate,
        notes: document.getElementById('inv-notes').value.trim(),
        duration_days: parseInt(document.getElementById('inv-duration').value) || 7,
        issuer_mode: document.getElementById('inv-issuer').value,
        signature: getSignatureData()
    };

    if (parts[0] === 'player') payload.target_id = parseInt(parts[1]);
    else payload.society_name = parts[1];

    var reasons = items.map(function(i) {
        return i.description + (i.units > 1 ? ' (' + i.units + 'x)' : '');
    });
    payload.reason = reasons.join(', ');

    document.getElementById('inv-submit').disabled = true;
    nuiFetch('createInvoice', payload);
    showToast('Rechnung wird erstellt...', 'success');

    setTimeout(function() {
        state.signatureDirty = false;
        refreshDashboard(function() {
            setActiveTab('overview');
            state.subTab = 'created';
        });
    }, 600);
}

// ============================================================
// ADMIN
// ============================================================

function renderAdmin() {
    var tabs = [
        { id: 'invoices', label: 'Rechnungen' },
        { id: 'jobs', label: 'Jobs' },
        { id: 'societies', label: 'Firmen' },
        { id: 'settings', label: 'System' }
    ];

    var html = '<div class="admin-subtabs">';
    tabs.forEach(function(t) {
        html += '<button class="admin-subtab' + (state.adminTab === t.id ? ' active' : '') + '" data-admin="' + t.id + '" type="button">' + t.label + '</button>';
    });
    html += '</div><div id="admin-content"></div>';

    document.getElementById('billing-body').innerHTML = html;

    document.querySelectorAll('.admin-subtab').forEach(function(btn) {
        btn.onclick = function() {
            state.adminTab = btn.dataset.admin;
            renderAdmin();
        };
    });

    if (state.adminTab === 'invoices') renderAdminInvoices();
    else if (state.adminTab === 'jobs') renderAdminJobs();
    else if (state.adminTab === 'societies') renderAdminSocieties();
    else if (state.adminTab === 'settings') renderAdminSettings();
}

function renderAdminInvoices() {
    var el = document.getElementById('admin-content');
    el.innerHTML = '<div class="empty-state">Lade Rechnungen...</div>';

    nuiFetch('getAllInvoices').then(function(invoices) {
        state.adminInvoices = invoices || [];
        if (state.adminInvoices.length === 0) {
            el.innerHTML = '<div class="empty-state">Keine Rechnungen vorhanden.</div>';
            return;
        }

        el.innerHTML = '<div class="btn-row" style="margin-bottom:12px"><button class="btn btn-ghost" id="adm-refresh" type="button">' + iconHtml('refresh', 14) + ' Aktualisieren</button></div>' +
            '<div class="invoice-list" id="admin-invoice-list"></div>';

        document.getElementById('adm-refresh').onclick = renderAdminInvoices;

        var listEl = document.getElementById('admin-invoice-list');
        listEl.innerHTML = state.adminInvoices.map(function(inv) {
            return '<div class="invoice-row">' +
                '<div class="invoice-row-main">' +
                '<div class="invoice-row-top">' +
                '<span class="invoice-number">' + esc(inv.invoice_number) + '</span>' +
                '<span class="status-badge ' + statusClass(inv.payment_status) + '">' + statusLabel(inv.payment_status) + '</span>' +
                '</div>' +
                '<div class="invoice-row-meta">' +
                '<span>' + esc(inv.issuer_name || '-') + ' → ' + esc(inv.recipient_name || '-') + '</span>' +
                '<span><strong>' + formatMoney(inv.gross_amount) + '</strong></span>' +
                '</div></div>' +
                '<div class="invoice-row-actions">' +
                '<button class="btn btn-view adm-view" type="button" data-id="' + inv.id + '">ANSEHEN</button>' +
                '</div></div>';
        }).join('');

        listEl.querySelectorAll('.adm-view').forEach(function(btn) {
            btn.onclick = function() {
                var id = parseInt(btn.dataset.id);
                var inv = state.adminInvoices.find(function(i) { return i.id === id; });
                if (inv) openAdminInvoiceDetail(inv);
            };
        });
    });
}

function openAdminInvoiceDetail(inv) {
    document.getElementById('detail-title').textContent = inv.invoice_number;
    var badge = document.getElementById('detail-badge');
    badge.textContent = statusLabel(inv.payment_status);
    badge.className = 'status-badge ' + statusClass(inv.payment_status);
    setIcon(document.getElementById('detail-close'), 'x', 16);

    document.getElementById('detail-body').innerHTML =
        detailRow('Aussteller', inv.issuer_name || '-') +
        detailRow('Empfänger', inv.recipient_name || '-') +
        detailRow('Grund', inv.reason) +
        detailRow('Brutto', formatMoney(inv.gross_amount), true) +
        detailRow('Status', statusLabel(inv.payment_status));

    document.getElementById('detail-footer').innerHTML =
        '<div class="btn-row">' +
        '<button class="btn btn-ghost" id="adm-edit" type="button">' + iconHtml('edit', 14) + ' Bearbeiten</button>' +
        '<button class="btn btn-danger" id="adm-cancel" type="button">' + iconHtml('x', 14) + ' Stornieren</button>' +
        '<button class="btn btn-danger" id="adm-delete" type="button">' + iconHtml('trash', 14) + ' Löschen</button></div>';

    document.getElementById('detail-modal').classList.remove('hidden');

    document.getElementById('adm-edit').onclick = function() {
        closeDetailModal();
        openAdminEditInvoice(inv);
    };
    document.getElementById('adm-cancel').onclick = function() {
        showPrompt('Stornierungsgrund (optional):', '', { title: 'Stornieren' }).then(function(r) {
            if (r === null) return;
            nuiFetch('cancelInvoice', { invoiceId: inv.id, reason: r });
            showToast('Storniert', 'success');
            closeDetailModal();
            renderAdminInvoices();
        });
    };
    document.getElementById('adm-delete').onclick = function() {
        showConfirm('Rechnung unwiderruflich löschen?', { title: 'Löschen', danger: true, confirmText: 'Löschen' }).then(function(ok) {
            if (!ok) return;
            nuiFetch('deleteInvoice', { invoiceId: inv.id });
            showToast('Gelöscht', 'success');
            closeDetailModal();
            renderAdminInvoices();
        });
    };
}

function openAdminEditInvoice(inv) {
    document.getElementById('billing-body').innerHTML =
        '<div class="section-title">RECHNUNG BEARBEITEN · ' + esc(inv.invoice_number) + '</div>' +
        '<form class="form" id="edit-form">' +
        '<div class="form-group"><label>Grund</label><input id="e-reason" value="' + esc(inv.reason) + '" required></div>' +
        '<div class="form-row"><div class="form-group"><label>Netto (€)</label><input type="number" id="e-net" value="' + inv.net_amount + '" step="0.01"></div>' +
        '<div class="form-group"><label>Steuer (%)</label><input type="number" id="e-tax" value="' + inv.tax_rate + '"></div></div>' +
        '<div class="form-group"><label>Status</label><select id="e-status">' +
        '<option value="open">Offen</option><option value="paid">Bezahlt</option>' +
        '<option value="overdue">Überfällig</option><option value="cancelled">Storniert</option></select></div>' +
        '<div class="btn-row">' +
        '<button type="button" class="btn btn-ghost" id="edit-back">Zurück</button>' +
        '<button type="submit" class="btn btn-primary">' + iconHtml('save', 14) + ' Speichern</button></div></form>';

    document.getElementById('e-status').value = inv.payment_status;
    document.getElementById('edit-back').onclick = function() { renderAdmin(); };
    document.getElementById('edit-form').onsubmit = function(e) {
        e.preventDefault();
        nuiFetch('editInvoice', {
            invoiceId: inv.id,
            reason: document.getElementById('e-reason').value,
            net_amount: parseFloat(document.getElementById('e-net').value),
            tax_rate: parseFloat(document.getElementById('e-tax').value),
            payment_status: document.getElementById('e-status').value
        });
        showToast('Gespeichert', 'success');
        renderAdmin();
    };
}

function renderAdminJobs() {
    var el = document.getElementById('admin-content');
    el.innerHTML = '<div class="empty-state">Lade Jobs...</div>';

    nuiFetch('getJobSettings').then(function(r) {
        state.jobs = r.jobs || [];
        state.jobSettings = r.settings || {};

        if (state.jobs.length === 0) {
            el.innerHTML = '<div class="empty-state">Keine Jobs gefunden.</div>';
            return;
        }

        el.innerHTML = '<div class="admin-grid">' + state.jobs.map(function(job) {
            var cfg = state.jobSettings[job.name];
            return '<div class="admin-card' + (cfg ? ' configured' : '') + '" data-job="' + esc(job.name) + '">' +
                '<h4>' + esc(job.label) + '</h4>' +
                '<p>' + (cfg ? 'Konfiguriert' : 'Nicht eingerichtet') + '</p></div>';
        }).join('') + '</div>';

        el.querySelectorAll('.admin-card').forEach(function(card) {
            card.onclick = function() {
                var job = state.jobs.find(function(j) { return j.name === card.dataset.job; });
                if (job) openAdminJobForm(job);
            };
        });
    });
}

function openAdminJobForm(job) {
    var s = state.jobSettings[job.name] || {};
    document.getElementById('billing-body').innerHTML =
        '<div class="section-title">JOB · ' + esc(job.label) + '</div>' +
        '<form class="form" id="job-form">' +
        chk('j-issue', 'Rechnungen schreiben', s.can_issue == 1) +
        chk('j-player', 'An Spieler', s.can_issue_player !== 0) +
        chk('j-society', 'An Firmen', s.can_issue_society == 1) +
        '<div class="form-row"><div class="form-group"><label>Max. Betrag (€)</label><input type="number" id="j-max" value="' + (s.max_amount || 10000) + '"></div>' +
        '<div class="form-group"><label>Max. Distanz (m)</label><input type="number" id="j-dist" value="' + (s.max_distance || 5) + '"></div></div>' +
        chk('j-prox', 'Nähe erforderlich', s.require_proximity !== 0) +
        chk('j-bank', 'Bankzahlung', s.payment_bank !== 0) +
        chk('j-cash', 'Barzahlung', s.payment_cash !== 0) +
        '<div class="form-group"><label>Geldziel</label><select id="j-dest"><option value="society">Society</option><option value="employee">Mitarbeiter</option><option value="split">Aufteilen</option></select></div>' +
        '<div class="form-row"><div class="form-group"><label>Society %</label><input type="number" id="j-soc" value="' + (s.society_percent || 70) + '"></div>' +
        '<div class="form-group"><label>Mitarbeiter %</label><input type="number" id="j-emp" value="' + (s.employee_percent || 30) + '"></div></div>' +
        '<div class="form-group"><label>Steuersatz %</label><input type="number" id="j-tax" value="' + (s.tax_rate || 19) + '"></div>' +
        '<div class="btn-row">' +
        '<button type="button" class="btn btn-ghost" id="job-back">Zurück</button>' +
        '<button type="submit" class="btn btn-primary">' + iconHtml('save', 14) + ' Speichern</button>' +
        '<button type="button" class="btn btn-danger" id="j-del">' + iconHtml('trash', 14) + ' Löschen</button></div></form>';

    document.getElementById('j-dest').value = s.money_destination || 'society';
    document.getElementById('job-back').onclick = function() { renderAdmin(); };
    document.getElementById('job-form').onsubmit = function(e) {
        e.preventDefault();
        nuiFetch('saveJobSettings', {
            job_name: job.name,
            can_issue: document.getElementById('j-issue').checked,
            can_issue_player: document.getElementById('j-player').checked,
            can_issue_society: document.getElementById('j-society').checked,
            max_amount: parseInt(document.getElementById('j-max').value),
            require_proximity: document.getElementById('j-prox').checked,
            max_distance: parseFloat(document.getElementById('j-dist').value),
            payment_bank: document.getElementById('j-bank').checked,
            payment_cash: document.getElementById('j-cash').checked,
            money_destination: document.getElementById('j-dest').value,
            society_percent: parseInt(document.getElementById('j-soc').value),
            employee_percent: parseInt(document.getElementById('j-emp').value),
            tax_rate: parseFloat(document.getElementById('j-tax').value)
        });
        showToast('Job gespeichert', 'success');
        renderAdmin();
    };
    document.getElementById('j-del').onclick = function() {
        showConfirm('Job-Einstellungen löschen?', { danger: true }).then(function(ok) {
            if (!ok) return;
            nuiFetch('deleteJobSettings', { jobName: job.name });
            renderAdmin();
        });
    };
}

function renderAdminSocieties() {
    var el = document.getElementById('admin-content');
    el.innerHTML = '<div class="empty-state">Lade Firmen...</div>';

    nuiFetch('getAllSocieties').then(function(societies) {
        nuiFetch('getSocietyInfo').then(function(info) {
            state.societies = societies || [];
            state.societyInfo = info || {};

            if (state.societies.length === 0) {
                el.innerHTML = '<div class="empty-state">Keine Firmen gefunden.</div>';
                return;
            }

            el.innerHTML = '<div class="admin-grid">' + state.societies.map(function(soc) {
                var cfg = state.societyInfo[soc.name];
                return '<div class="admin-card' + (cfg ? ' configured' : '') + '" data-soc="' + esc(soc.name) + '">' +
                    '<h4>' + esc(soc.label) + '</h4>' +
                    '<p>' + (cfg ? 'Daten hinterlegt' : 'Nicht eingerichtet') + '</p></div>';
            }).join('') + '</div>';

            el.querySelectorAll('.admin-card').forEach(function(card) {
                card.onclick = function() {
                    var soc = state.societies.find(function(s) { return s.name === card.dataset.soc; });
                    if (soc) openAdminSocietyForm(soc);
                };
            });
        });
    });
}

function openAdminSocietyForm(soc) {
    var info = state.societyInfo[soc.name] || {};
    document.getElementById('billing-body').innerHTML =
        '<div class="section-title">FIRMA · ' + esc(soc.label) + '</div>' +
        '<form class="form" id="soc-form">' +
        '<div class="form-group"><label>Firmenname</label><input id="sf-name" value="' + esc(info.company_name) + '"></div>' +
        '<div class="form-group"><label>Adresse</label><textarea id="sf-addr">' + esc(info.company_address) + '</textarea></div>' +
        '<div class="form-row"><div class="form-group"><label>Steuernr.</label><input id="sf-tax" value="' + esc(info.tax_id) + '"></div>' +
        '<div class="form-group"><label>USt-IdNr.</label><input id="sf-vat" value="' + esc(info.vat_id) + '"></div></div>' +
        '<div class="form-group"><label>Präfix</label><input id="sf-pre" value="' + esc(info.invoice_prefix || 'RE') + '" maxlength="10"></div>' +
        '<div class="btn-row">' +
        '<button type="button" class="btn btn-ghost" id="soc-back">Zurück</button>' +
        '<button type="submit" class="btn btn-primary">' + iconHtml('save', 14) + ' Speichern</button>' +
        '<button type="button" class="btn btn-danger" id="sf-del">' + iconHtml('trash', 14) + ' Löschen</button></div></form>';

    document.getElementById('soc-back').onclick = function() { renderAdmin(); };
    document.getElementById('soc-form').onsubmit = function(e) {
        e.preventDefault();
        nuiFetch('saveSocietyInfo', {
            society_name: soc.name,
            company_name: document.getElementById('sf-name').value,
            company_address: document.getElementById('sf-addr').value,
            tax_id: document.getElementById('sf-tax').value,
            vat_id: document.getElementById('sf-vat').value,
            invoice_prefix: document.getElementById('sf-pre').value || 'RE'
        });
        showToast('Firma gespeichert', 'success');
        renderAdmin();
    };
    document.getElementById('sf-del').onclick = function() {
        showConfirm('Firmendaten löschen?', { danger: true }).then(function(ok) {
            if (!ok) return;
            nuiFetch('deleteSocietyInfo', { societyName: soc.name });
            renderAdmin();
        });
    };
}

function renderAdminSettings() {
    nuiFetch('getGlobalSettings').then(function(s) {
        state.globalSettings = s || {};
        document.getElementById('admin-content').innerHTML =
            '<div class="admin-grid">' +
            '<div class="admin-card" id="set-discord"><h4>' + iconHtml('bell', 14) + ' Discord & Logging</h4><p>Webhook & Benachrichtigungen</p></div>' +
            '<div class="admin-card" id="set-tax"><h4>' + iconHtml('percent', 14) + ' Steuersystem</h4><p>Steuersätze & Aktivierung</p></div>' +
            '<div class="admin-card" id="set-inv"><h4>' + iconHtml('receipt', 14) + ' Rechnungen</h4><p>Nummern, Fristen, Mahngebühr</p></div>' +
            '<div class="admin-card" id="set-perm"><h4>' + iconHtml('shield', 14) + ' Admin-Rechte</h4><p>Berechtigungen verwalten</p></div>' +
            '</div>';

        document.getElementById('set-discord').onclick = function() { openSettingsForm('discord'); };
        document.getElementById('set-tax').onclick = function() { openSettingsForm('tax'); };
        document.getElementById('set-inv').onclick = function() { openSettingsForm('inv'); };
        document.getElementById('set-perm').onclick = function() { openSettingsForm('perm'); };
    });
}

function openSettingsForm(type) {
    var s = state.globalSettings;
    var html = '<div class="section-title">SYSTEM-EINSTELLUNGEN</div><form class="form" id="settings-form">';

    if (type === 'discord') {
        html += chk('d-en', 'Discord aktiv', boolVal(s.discord_enabled));
        html += '<div class="form-group"><label>Webhook URL</label><input id="d-url" value="' + esc(s.discord_webhook) + '"></div>';
    } else if (type === 'tax') {
        html += chk('t-en', 'Steuern aktiv', boolVal(s.tax_enabled));
        html += '<div class="form-group"><label>Standard-Steuersatz %</label><input type="number" id="t-rate" value="' + (s.default_tax_rate || 19) + '"></div>';
    } else if (type === 'inv') {
        html += chk('i-auto', 'Auto-Nummern', boolVal(s.auto_invoice_numbers));
        html += '<div class="form-group"><label>Präfix</label><input id="i-pre" value="' + esc(s.invoice_prefix || 'RE') + '"></div>';
        html += '<div class="form-row"><div class="form-group"><label>Frist (Tage)</label><input type="number" id="i-days" value="' + (s.payment_deadline_days || 14) + '"></div>';
        html += '<div class="form-group"><label>Mahngebühr €</label><input type="number" id="i-fee" value="' + (s.reminder_fee || 25) + '"></div></div>';
        html += chk('i-login', 'Login-Hinweis', boolVal(s.show_unpaid_on_login));
    } else if (type === 'perm') {
        html += chk('p-view', 'Einsehen', boolVal(s.admin_can_view));
        html += chk('p-edit', 'Bearbeiten', boolVal(s.admin_can_edit));
        html += chk('p-cancel', 'Stornieren', boolVal(s.admin_can_cancel));
        html += chk('p-del', 'Löschen', boolVal(s.admin_can_delete));
    }

    html += '<div class="btn-row"><button type="button" class="btn btn-ghost" id="settings-back">Zurück</button>';
    html += '<button type="submit" class="btn btn-primary">' + iconHtml('save', 14) + ' Speichern</button></div></form>';

    document.getElementById('billing-body').innerHTML = html;
    document.getElementById('settings-back').onclick = function() { renderAdmin(); };

    document.getElementById('settings-form').onsubmit = function(e) {
        e.preventDefault();
        var payload = {};
        if (type === 'discord') {
            payload = { discord_enabled: document.getElementById('d-en').checked, discord_webhook: document.getElementById('d-url').value };
        } else if (type === 'tax') {
            payload = { tax_enabled: document.getElementById('t-en').checked, default_tax_rate: document.getElementById('t-rate').value };
        } else if (type === 'inv') {
            payload = {
                auto_invoice_numbers: document.getElementById('i-auto').checked,
                invoice_prefix: document.getElementById('i-pre').value,
                payment_deadline_days: document.getElementById('i-days').value,
                reminder_fee: document.getElementById('i-fee').value,
                show_unpaid_on_login: document.getElementById('i-login').checked
            };
        } else if (type === 'perm') {
            payload = {
                admin_can_view: document.getElementById('p-view').checked,
                admin_can_edit: document.getElementById('p-edit').checked,
                admin_can_cancel: document.getElementById('p-cancel').checked,
                admin_can_delete: document.getElementById('p-del').checked
            };
        }
        nuiFetch('saveGlobalSettings', payload);
        showToast('Gespeichert', 'success');
        renderAdmin();
    };
}

// ============================================================
// OPEN / EVENTS
// ============================================================

function openDashboard(data) {
    state.data = data || {};
    state.tab = data.tab || 'overview';
    state.subTab = data.subTab || 'created';
    state.filter = 'all';
    state.search = '';
    state.signatureDirty = false;
    state.adminTab = 'invoices';

    document.getElementById('billing-player-name').textContent = state.data.playerName || 'Spieler';
    setIcon(document.getElementById('swap-icon'), 'repeat', 14);
    applyTheme(state.data.ui || (state.data.config && state.data.config.ui));
    updateTabsVisibility();

    var root = document.getElementById('billing-root');
    root.classList.remove('hidden');
    requestAnimationFrame(function() { root.classList.add('open'); });

    if (state.data.tab === 'admin') openAdminPanel();
    else setActiveTab(state.tab);
}

window.addEventListener('message', function(e) {
    var d = e.data;
    if (d.action === 'open') {
        if (d.mode === 'dashboard') {
            openDashboard(d.data || {});
            if (d.config) applyTheme(d.config.ui);
        }
    } else if (d.action === 'close') {
        document.getElementById('billing-root').classList.remove('open');
        setTimeout(function() { document.getElementById('billing-root').classList.add('hidden'); }, 280);
        closeDetailModal();
    } else if (d.action === 'toast') {
        showToast(d.message, d.type);
    }
});

document.getElementById('btn-close').onclick = closeMenu;
document.getElementById('detail-close').onclick = closeDetailModal;
document.getElementById('btn-admin').onclick = openAdminPanel;

document.querySelectorAll('.billing-tab').forEach(function(tab) {
    tab.addEventListener('click', function() {
        if (tab.classList.contains('disabled')) {
            showToast('Du darfst keine Rechnungen ausstellen.', 'warning');
            return;
        }
        setActiveTab(tab.dataset.tab);
    });
});

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        if (isDialogOpen && isDialogOpen()) { closeDialog(null); return; }
        if (!document.getElementById('detail-modal').classList.contains('hidden')) {
            closeDetailModal();
            return;
        }
        closeMenu();
    }
});

if (typeof initProtection === 'function') initProtection();
