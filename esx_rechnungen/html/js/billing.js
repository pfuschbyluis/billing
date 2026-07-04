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
    createStep: 1,
    createType: null,
    createTarget: null,
    adminInvoices: [],
    jobs: [],
    jobSettings: {},
    societies: [],
    societyInfo: {},
    globalSettings: {},
    selectedInvoice: null
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
    return { open: 'OFFEN', paid: 'BEZAHLT', overdue: 'ÜBERFÄLLIG', cancelled: 'STORNIERT' }[s] || s;
}

function statusClass(s) {
    return { open: 'status-open', paid: 'status-paid', overdue: 'status-overdue', cancelled: 'status-cancelled' }[s] || '';
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
    var adminTab = document.getElementById('tab-admin');
    var createTab = document.querySelector('.billing-tab[data-tab="create"]');
    if (adminTab) adminTab.classList.toggle('hidden', !d.isAdmin);
    if (createTab) {
        createTab.classList.toggle('disabled', !d.canCreate);
        if (!d.canCreate) createTab.title = 'Mit deinem Job nicht verfügbar';
    }
}

function setActiveTab(tab) {
    state.tab = tab;
    document.querySelectorAll('.billing-tab').forEach(function(t) {
        t.classList.toggle('active', t.dataset.tab === tab);
    });
    renderCurrentTab();
}

function renderCurrentTab() {
    if (state.tab === 'overview') renderOverview();
    else if (state.tab === 'statistics') renderStatistics();
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
        statCard('OFFENER BETRAG', formatMoney(stats.open_amount || 0)) +
        statCard('HEUTE', (stats.today_count || 0) + ' (' + formatMoney(stats.today_amount || 0) + ')') +
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
            '<span class="invoice-date">' + formatDate(inv.created_at) + '</span>' +
            '</div>' +
            '<div class="invoice-row-meta">' +
            '<span>Ersteller: <strong>' + esc(inv.issuer_name || '-') + '</strong></span>' +
            '<span>Empfänger: <strong>' + esc(inv.recipient_name || '-') + '</strong></span>' +
            '<span>Betrag: <strong>' + formatMoney(total) + '</strong></span>' +
            '</div></div>' +
            '<div class="invoice-row-actions">' +
            '<button class="btn btn-view" type="button" data-view="' + inv.id + '">ANSEHEN</button>' +
            (canDelete ? '<button class="btn btn-icon btn-danger btn-del" type="button" data-del="' + inv.id + '" title="Löschen">' + iconHtml('trash', 14) + '</button>' : '') +
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
            '<button class="btn btn-success" id="pay-cash" type="button">' + iconHtml('banknote', 14) + ' Bar</button></div>';
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
    var total = stats.total || 0;
    var max = Math.max(stats.open || 0, stats.paid || 0, stats.overdue || 0, 1);

    var html = '<div class="stats-detail-grid">' +
        '<div class="stat-block"><div class="big">' + (stats.total || 0) + '</div><div class="lbl">Gesamt</div></div>' +
        '<div class="stat-block"><div class="big">' + formatMoney(stats.open_amount || 0) + '</div><div class="lbl">Offener Betrag</div></div>' +
        '<div class="stat-block"><div class="big">' + (stats.today_count || 0) + '</div><div class="lbl">Heute erstellt</div></div>' +
        '</div>';

    html += '<div class="section-title">STATUS-VERTEILUNG</div>';
    html += '<div class="bar-chart">' +
        barRow('Offen', stats.open || 0, max, 'open') +
        barRow('Bezahlt', stats.paid || 0, max, 'paid') +
        barRow('Überfällig', stats.overdue || 0, max, 'overdue') +
        '</div>';

    html += '<div class="section-title">HEUTE</div>';
    html += '<div class="preview-box">' +
        detailRow('Anzahl', stats.today_count || 0) +
        detailRow('Volumen', formatMoney(stats.today_amount || 0), true) +
        '</div>';

    if (total === 0) {
        html += '<div class="empty-state" style="padding:24px">Noch keine Rechnungsdaten vorhanden.</div>';
    }

    document.getElementById('billing-body').innerHTML = html;
}

function barRow(label, val, max, cls) {
    var pct = Math.round((val / max) * 100);
    return '<div class="bar-row"><span>' + label + '</span>' +
        '<div class="bar-track"><div class="bar-fill ' + cls + '" style="width:' + pct + '%"></div></div>' +
        '<span>' + val + '</span></div>';
}

// ============================================================
// RECHNUNG ERSTELLEN
// ============================================================

function renderCreate() {
    var d = state.data || {};
    if (!d.canCreate || !d.createData) {
        document.getElementById('billing-body').innerHTML =
            '<div class="empty-state"><div class="icon-wrap">' + iconHtml('x', 40) + '</div>' +
            'Du darfst mit deinem aktuellen Job keine Rechnungen ausstellen.<br>Bitte wende dich an einen Administrator.</div>';
        return;
    }

    if (state.createStep === 1) renderCreateRecipient();
    else if (state.createStep === 2) renderCreateTargetList();
    else if (state.createStep === 3) renderCreateForm();
}

function renderCreateRecipient() {
    var data = state.data.createData;
    var s = data.settings || {};
    var jobLabel = data.job ? data.job.label : '';

    document.getElementById('billing-body').innerHTML =
        '<div class="create-steps">' +
        '<div class="create-step active">1 · Empfängerart</div>' +
        '<div class="create-step">2 · Auswahl</div>' +
        '<div class="create-step">3 · Details</div></div>' +
        '<div class="section-title">RECHNUNG AUSSTELLEN · ' + esc(jobLabel) + '</div>' +
        '<div class="admin-grid" id="create-recipient-grid"></div>';

    var items = [];
    if (s.can_issue_player !== 0) items.push({ icon: 'user', title: 'An Spieler', desc: 'Rechnung an nahen Spieler', type: 'player' });
    if (s.can_issue_society === 1) items.push({ icon: 'building', title: 'An Firma', desc: 'Rechnung an Society', type: 'society' });

    var grid = document.getElementById('create-recipient-grid');
    if (items.length === 0) {
        grid.innerHTML = '<div class="empty-state">Keine Berechtigung zum Ausstellen.</div>';
        return;
    }

    grid.innerHTML = items.map(function(item) {
        return '<div class="admin-card" data-type="' + item.type + '">' +
            '<h4>' + iconHtml(item.icon, 14) + ' ' + item.title + '</h4>' +
            '<p>' + item.desc + '</p></div>';
    }).join('');

    grid.querySelectorAll('.admin-card').forEach(function(card) {
        card.onclick = function() {
            state.createType = card.dataset.type;
            state.createStep = 2;
            renderCreate();
        };
    });
}

function renderCreateTargetList() {
    var fetchFn = state.createType === 'player' ? 'getNearbyPlayers' : 'getSocieties';
    var title = state.createType === 'player' ? 'Spieler wählen' : 'Firma wählen';

    document.getElementById('billing-body').innerHTML =
        '<div class="create-steps">' +
        '<div class="create-step done">1 · Empfängerart</div>' +
        '<div class="create-step active">2 · Auswahl</div>' +
        '<div class="create-step">3 · Details</div></div>' +
        '<div class="section-title">' + title + '</div>' +
        '<div class="player-pick-list" id="pick-list"><div class="empty-state">Lade...</div></div>' +
        '<div class="btn-row" style="margin-top:12px"><button class="btn btn-ghost" id="create-back" type="button">' + iconHtml('chevron-left', 14) + ' Zurück</button></div>';

    document.getElementById('create-back').onclick = function() {
        state.createStep = 1;
        state.createType = null;
        renderCreate();
    };

    nuiFetch(fetchFn).then(function(items) {
        var list = document.getElementById('pick-list');
        if (!items || items.length === 0) {
            list.innerHTML = '<div class="empty-state">Keine Einträge gefunden.</div>';
            return;
        }

        list.innerHTML = items.map(function(item, i) {
            var label = item.name || item.label;
            var sub = state.createType === 'player' ? (item.distance + 'm entfernt') : item.name;
            return '<div class="pick-item" data-idx="' + i + '"><div><strong>' + esc(label) + '</strong><br><span style="font-size:11px;color:var(--text-muted)">' + esc(sub) + '</span></div>' +
                iconHtml('chevron-right', 16) + '</div>';
        }).join('');

        list.querySelectorAll('.pick-item').forEach(function(el) {
            el.onclick = function() {
                var idx = parseInt(el.dataset.idx);
                if (state.createType === 'player') {
                    state.createTarget = { target_id: items[idx].source };
                } else {
                    state.createTarget = { society_name: items[idx].name };
                }
                state.createStep = 3;
                renderCreate();
            };
        });
    });
}

function renderCreateForm() {
    var data = state.data.createData;
    var tax = data.settings ? data.settings.tax_rate : 19;

    document.getElementById('billing-body').innerHTML =
        '<div class="create-steps">' +
        '<div class="create-step done">1 · Empfängerart</div>' +
        '<div class="create-step done">2 · Auswahl</div>' +
        '<div class="create-step active">3 · Details</div></div>' +
        '<form class="form" id="create-form">' +
        '<div class="form-group"><label>Rechnungsgrund</label><input id="f-reason" required maxlength="500" placeholder="z.B. Reparatur, Behandlung"></div>' +
        '<div class="form-row">' +
        '<div class="form-group"><label>Netto (€)</label><input type="number" id="f-net" min="1" step="0.01" value="100" required></div>' +
        '<div class="form-group"><label>Steuer (%)</label><input type="number" id="f-tax" min="0" max="100" step="0.1" value="' + tax + '"></div></div>' +
        '<div class="preview-box" id="tax-preview"></div>' +
        '<div class="btn-row">' +
        '<button type="button" class="btn btn-ghost" id="create-back2">' + iconHtml('chevron-left', 14) + ' Zurück</button>' +
        '<button type="submit" class="btn btn-primary">' + iconHtml('plus', 14) + ' Rechnung ausstellen</button></div></form>';

    document.getElementById('create-back2').onclick = function() {
        state.createStep = 2;
        renderCreate();
    };

    function updatePreview() {
        var net = parseFloat(document.getElementById('f-net').value) || 0;
        var rate = parseFloat(document.getElementById('f-tax').value) || 0;
        var taxAmt = Math.round(net * rate / 100 * 100) / 100;
        document.getElementById('tax-preview').innerHTML =
            detailRow('Netto', formatMoney(net)) +
            detailRow('MwSt.', formatMoney(taxAmt)) +
            detailRow('Brutto', formatMoney(net + taxAmt), true);
    }

    document.getElementById('f-net').oninput = updatePreview;
    document.getElementById('f-tax').oninput = updatePreview;
    updatePreview();

    document.getElementById('create-form').onsubmit = function(e) {
        e.preventDefault();
        var payload = {
            recipient_type: state.createType,
            reason: document.getElementById('f-reason').value,
            net_amount: parseFloat(document.getElementById('f-net').value),
            tax_rate: parseFloat(document.getElementById('f-tax').value)
        };
        if (state.createType === 'player') payload.target_id = state.createTarget.target_id;
        else payload.society_name = state.createTarget.society_name;

        nuiFetch('createInvoice', payload);
        showToast('Rechnung wird erstellt...', 'success');
        state.createStep = 1;
        state.createType = null;
        state.createTarget = null;
        refreshDashboard(function() {
            setActiveTab('overview');
            state.subTab = 'created';
        });
    };
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
    state.createStep = 1;
    state.createType = null;
    state.createTarget = null;
    state.adminTab = 'invoices';

    document.getElementById('billing-player-name').textContent = state.data.playerName || 'Spieler';
    updateTabsVisibility();

    var root = document.getElementById('billing-root');
    root.classList.remove('hidden');
    requestAnimationFrame(function() { root.classList.add('open'); });

    setActiveTab(state.tab);
}

window.addEventListener('message', function(e) {
    var d = e.data;
    if (d.action === 'open') {
        if (d.mode === 'dashboard') {
            openDashboard(d.data || {});
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

document.querySelectorAll('.billing-tab').forEach(function(tab) {
    tab.addEventListener('click', function() {
        if (tab.classList.contains('disabled')) {
            showToast('Du darfst keine Rechnungen ausstellen.', 'warning');
            return;
        }
        if (tab.dataset.tab === 'admin' && !(state.data && state.data.isAdmin)) return;
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
