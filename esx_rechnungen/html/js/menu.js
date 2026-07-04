/**
 * ESX Rechnungssystem – Custom Menü Logik
 */

var state = {
    mode: null,
    navStack: [],
    adminTab: 'invoices',
    filter: 'all',
    createData: null,
    invoices: [],
    adminInvoices: [],
    jobs: [],
    jobSettings: {},
    societies: [],
    societyInfo: {},
    globalSettings: {},
    hubData: null
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
    document.getElementById('menu-root').classList.remove('open');
    setTimeout(function() {
        document.getElementById('menu-root').classList.add('hidden');
    }, 280);
    nuiFetch('close');
}

function formatMoney(n) {
    var v = parseFloat(n) || 0;
    var s = v.toFixed(2).replace('.', ',');
    return s.replace(/\B(?=(\d{3})+(?!\d))/g, '.') + ' €';
}

function formatDate(d) {
    if (!d) return '-';
    var m = String(d).match(/(\d+)-(\d+)-(\d+)/);
    return m ? m[3] + '.' + m[2] + '.' + m[1] : d;
}

function statusLabel(s) {
    return { open: 'Offen', paid: 'Bezahlt', overdue: 'Überfällig', cancelled: 'Storniert' }[s] || s;
}

function statusIcon(s) {
    return { open: 'clock', paid: 'check-circle', overdue: 'alert-circle', cancelled: 'x' }[s] || 'file-text';
}

function statusClass(s) {
    return { open: 'warning', paid: 'success', overdue: 'danger', cancelled: '' }[s] || '';
}

// ============================================================
// Navigation
// ============================================================

function setHeader(title, subtitle, showBack) {
    document.getElementById('menu-title').textContent = title;
    document.getElementById('menu-subtitle').textContent = subtitle || '';
    document.getElementById('btn-back').classList.toggle('hidden', !showBack);
}

function pushView(renderFn, title, subtitle) {
    state.navStack.push({ render: renderFn, title: title, subtitle: subtitle });
    setHeader(title, subtitle, state.navStack.length > 1);
    renderFn();
}

function goBack() {
    if (state.navStack.length <= 1) return;
    state.navStack.pop();
    var v = state.navStack[state.navStack.length - 1];
    setHeader(v.title, v.subtitle, state.navStack.length > 1);
    v.render();
}

function resetNav() {
    state.navStack = [];
}

function renderList(items) {
    var html = '<div class="menu-list">';
    items.forEach(function(item) {
        if (item.section) {
            html += '<div class="menu-section">' + item.section + '</div>';
            return;
        }
        var cls = 'menu-item' + (item.readonly ? ' readonly' : '');
        html += '<button class="' + cls + '" data-action="' + (item.action || '') + '">';
        html += '<div class="menu-item-icon ' + (item.iconClass || '') + '">' + icon(item.icon || 'file-text', 16) + '</div>';
        html += '<div class="menu-item-content"><div class="menu-item-title">' + item.title + '</div>';
        if (item.desc) html += '<div class="menu-item-desc">' + item.desc + '</div>';
        html += '</div>';
        if (item.badge) html += '<span class="badge badge-' + item.badge + '">' + statusLabel(item.badge) + '</span>';
        if (item.value) html += '<span class="menu-item-value">' + item.value + '</span>';
        if (item.arrow) html += '<span class="menu-item-arrow">' + icon('chevron-right', 16) + '</span>';
        html += '</button>';
    });
    html += '</div>';
    document.getElementById('menu-body').innerHTML = html;

    document.querySelectorAll('.menu-item[data-action]').forEach(function(el) {
        var action = el.getAttribute('data-action');
        if (!action) return;
        el.addEventListener('click', function() {
            var fn = window['_action_' + action];
            if (fn) fn();
        });
    });
}

// ============================================================
// HAUPTMENÜ (F7)
// ============================================================

function renderHubMenu() {
    var d = state.hubData || {};
    var items = [
        {
            icon: 'list',
            title: 'Rechnungen einsehen',
            desc: 'Offene, bezahlte und überfällige Rechnungen',
            arrow: true,
            action: 'hub_player'
        }
    ];

    if (d.canCreate) {
        items.push({
            icon: 'plus',
            title: 'Rechnung ausstellen',
            desc: 'Neue Rechnung an Spieler oder Firma',
            arrow: true,
            action: 'hub_create'
        });
    } else {
        items.push({
            icon: 'plus',
            title: 'Rechnung ausstellen',
            desc: 'Mit deinem Job nicht verfügbar',
            readonly: true
        });
    }

    if (d.isAdmin) {
        items.push({
            icon: 'shield',
            title: 'Adminpanel',
            desc: 'Rechnungen, Jobs, Firmen & System',
            arrow: true,
            action: 'hub_admin'
        });
    }

    items.push({ section: 'Schnellzugriff' });
    items.push({
        icon: 'clock',
        title: 'Offene Rechnungen',
        desc: 'Direkt zu unbezahlten Rechnungen',
        arrow: true,
        action: 'hub_open'
    });

    renderList(items);
}

function openHubHome(data) {
    state.hubData = data || {};
    state.mode = 'hub';
    resetNav();
    document.getElementById('admin-tabs').classList.add('hidden');
    pushView(renderHubMenu, 'Rechnungssystem', 'F7 · Hauptmenü');
}

window._action_hub_player = function() { openPlayerHome(true); };
window._action_hub_create = function() {
    if (!state.hubData.canCreate || !state.hubData.createData) {
        showToast('Du darfst keine Rechnungen ausstellen.', 'warning');
        return;
    }
    openCreateHome(state.hubData.createData, true);
};
window._action_hub_admin = function() {
    state.mode = 'admin';
    state.adminTab = 'invoices';
    document.getElementById('admin-tabs').classList.remove('hidden');
    document.querySelectorAll('.tab').forEach(function(t) {
        t.classList.toggle('active', t.dataset.tab === 'invoices');
    });
    pushView(function() { renderAdminTab(); }, 'Adminpanel', 'Verwaltung');
};
window._action_hub_open = function() {
    state.filter = 'open';
    openPlayerList(true);
};

// ============================================================
// SPIELER
// ============================================================

function openPlayerHome(fromHub) {
    var renderCats = function() {
        renderList([
            { icon: 'list', title: 'Alle Rechnungen', desc: 'Komplette Übersicht', arrow: true, action: 'p_all' },
            { icon: 'clock', title: 'Offene Rechnungen', iconClass: 'warning', arrow: true, action: 'p_open' },
            { icon: 'check-circle', title: 'Bezahlte Rechnungen', iconClass: 'success', arrow: true, action: 'p_paid' },
            { icon: 'alert-circle', title: 'Überfällige Rechnungen', iconClass: 'danger', arrow: true, action: 'p_overdue' }
        ]);
    };

    if (fromHub) {
        pushView(renderCats, 'Meine Rechnungen', 'Übersicht & Bezahlung');
    } else {
        resetNav();
        state.mode = 'player';
        pushView(renderCats, 'Meine Rechnungen', 'Übersicht & Bezahlung');
    }
}

window._action_p_all = function() { state.filter = 'all'; openPlayerList(); };
window._action_p_open = function() { state.filter = 'open'; openPlayerList(); };
window._action_p_paid = function() { state.filter = 'paid'; openPlayerList(); };
window._action_p_overdue = function() { state.filter = 'overdue'; openPlayerList(); };

function openPlayerList(fromHub) {
    nuiFetch('getMyInvoices').then(function(invoices) {
        state.invoices = invoices || [];
        var filtered = state.invoices.filter(function(inv) {
            return state.filter === 'all' || inv.payment_status === state.filter;
        });

        var renderListView = function() {
            var items = [];
            if (filtered.length === 0) {
                items.push({ icon: 'inbox', title: 'Keine Rechnungen', desc: 'In dieser Kategorie leer', readonly: true });
            } else {
                filtered.forEach(function(inv, idx) {
                    var gross = parseFloat(inv.gross_amount) || 0;
                    var rem = inv.payment_status === 'overdue' ? (parseFloat(inv.reminder_fee) || 0) : 0;
                    items.push({
                        icon: statusIcon(inv.payment_status),
                        iconClass: statusClass(inv.payment_status),
                        title: inv.invoice_number,
                        desc: inv.reason,
                        value: formatMoney(gross + rem),
                        badge: inv.payment_status,
                        arrow: true,
                        action: 'p_detail_' + idx
                    });
                    window['_action_p_detail_' + idx] = (function(i) { return function() { openPlayerDetail(i); }; })(inv);
                });
            }
            renderList(items);
        };

        if (fromHub) {
            pushView(renderListView, 'Rechnungsliste', filtered.length + ' Einträge');
        } else {
            pushView(renderListView, 'Rechnungsliste', filtered.length + ' Einträge');
        }
    });
}

function openPlayerDetail(inv) {
    var gross = parseFloat(inv.gross_amount) || 0;
    var rem = inv.payment_status === 'overdue' ? (parseFloat(inv.reminder_fee) || 0) : 0;
    var total = gross + rem;

    pushView(function() {
        var html = '<div class="detail-block">';
        html += row('Aussteller', inv.issuer_name || '-');
        html += row('Grund', inv.reason);
        html += row('Datum', formatDate(inv.created_at));
        html += row('Fällig', formatDate(inv.due_date));
        html += row('Netto', formatMoney(inv.net_amount));
        html += row('Steuer', inv.tax_rate + '% (' + formatMoney(inv.tax_amount) + ')');
        if (rem > 0) html += row('Mahngebühr', formatMoney(rem));
        html += row('Brutto', formatMoney(total), true);
        html += '</div>';

        if (inv.payment_status === 'open' || inv.payment_status === 'overdue') {
            html += '<div class="btn-row"><button class="btn btn-success" id="pay-bank">' + icon('credit-card', 14) + ' Bank</button>';
            html += '<button class="btn btn-success" id="pay-cash">' + icon('banknote', 14) + ' Bar</button></div>';
        }

        document.getElementById('menu-body').innerHTML = html;
        var pb = document.getElementById('pay-bank');
        var pc = document.getElementById('pay-cash');
        if (pb) pb.onclick = function() { nuiFetch('payInvoice', { invoiceId: inv.id, paymentMethod: 'bank' }); showToast('Zahlung wird verarbeitet...', 'info'); setTimeout(goBack, 600); };
        if (pc) pc.onclick = function() { nuiFetch('payInvoice', { invoiceId: inv.id, paymentMethod: 'cash' }); showToast('Zahlung wird verarbeitet...', 'info'); setTimeout(goBack, 600); };
    }, inv.invoice_number, statusLabel(inv.payment_status));
}

function row(label, val, total) {
    return '<div class="detail-row' + (total ? ' total' : '') + '"><span>' + label + '</span><span>' + val + '</span></div>';
}

// ============================================================
// RECHNUNG ERSTELLEN
// ============================================================

function openCreateHome(data, fromHub) {
    state.createData = data;

    var renderRecipient = function() {
        var items = [];
        var s = data.settings || {};
        if (s.can_issue_player !== 0) items.push({ icon: 'user', title: 'An Spieler', desc: 'Rechnung an nahen Spieler', arrow: true, action: 'c_player' });
        if (s.can_issue_society === 1) items.push({ icon: 'building', title: 'An Firma', desc: 'Rechnung an Society', arrow: true, action: 'c_society' });
        if (items.length === 0) items.push({ icon: 'x', title: 'Keine Berechtigung', readonly: true });
        renderList(items);
    };

    if (fromHub) {
        pushView(renderRecipient, 'Rechnung ausstellen', data.job ? data.job.label : '');
    } else {
        resetNav();
        state.mode = 'create';
        pushView(renderRecipient, 'Rechnung ausstellen', data.job ? data.job.label : '');
    }
}

window._action_c_player = function() {
    nuiFetch('getNearbyPlayers').then(function(players) {
        pushView(function() {
            var items = [];
            (players || []).forEach(function(p, i) {
                items.push({ icon: 'user', title: p.name, desc: p.distance + 'm entfernt', arrow: true, action: 'cp_' + i });
                window['_action_cp_' + i] = (function(pl) { return function() { openCreateForm('player', { target_id: pl.source }); }; })(p);
            });
            if (items.length === 0) items.push({ icon: 'user', title: 'Keine Spieler in der Nähe', readonly: true });
            renderList(items);
        }, 'Spieler wählen', '');
    });
};

window._action_c_society = function() {
    nuiFetch('getSocieties').then(function(societies) {
        pushView(function() {
            var items = [];
            (societies || []).forEach(function(s, i) {
                items.push({ icon: 'building', title: s.label, desc: s.name, arrow: true, action: 'cs_' + i });
                window['_action_cs_' + i] = (function(soc) { return function() { openCreateForm('society', { society_name: soc.name }); }; })(s);
            });
            if (items.length === 0) items.push({ icon: 'building', title: 'Keine Firmen', readonly: true });
            renderList(items);
        }, 'Firma wählen', '');
    });
};

function openCreateForm(type, extra) {
    var tax = state.createData.settings ? state.createData.settings.tax_rate : 19;
    pushView(function() {
        document.getElementById('menu-body').innerHTML =
            '<form class="form" id="create-form">' +
            '<div class="form-group"><label>Rechnungsgrund</label><input id="f-reason" required maxlength="500" placeholder="z.B. Reparatur"></div>' +
            '<div class="form-row"><div class="form-group"><label>Netto (€)</label><input type="number" id="f-net" min="1" step="0.01" value="100" required></div>' +
            '<div class="form-group"><label>Steuer (%)</label><input type="number" id="f-tax" min="0" max="100" step="0.1" value="' + tax + '"></div></div>' +
            '<div id="tax-preview" class="detail-block" style="margin:0"></div>' +
            '<button type="submit" class="btn btn-primary">' + icon('plus', 14) + ' Rechnung ausstellen</button></form>';

        function updatePreview() {
            var net = parseFloat(document.getElementById('f-net').value) || 0;
            var rate = parseFloat(document.getElementById('f-tax').value) || 0;
            var taxAmt = Math.round(net * rate / 100 * 100) / 100;
            document.getElementById('tax-preview').innerHTML =
                row('Netto', formatMoney(net)) + row('MwSt.', formatMoney(taxAmt)) + row('Brutto', formatMoney(net + taxAmt), true);
        }

        document.getElementById('f-net').oninput = updatePreview;
        document.getElementById('f-tax').oninput = updatePreview;
        updatePreview();

        document.getElementById('create-form').onsubmit = function(e) {
            e.preventDefault();
            var data = {
                recipient_type: type,
                reason: document.getElementById('f-reason').value,
                net_amount: parseFloat(document.getElementById('f-net').value),
                tax_rate: parseFloat(document.getElementById('f-tax').value)
            };
            if (type === 'player') data.target_id = extra.target_id;
            else data.society_name = extra.society_name;
            nuiFetch('createInvoice', data);
            showToast('Rechnung wird erstellt...', 'success');
            closeMenu();
        };
    }, 'Rechnungsdaten', '');
}

// ============================================================
// ADMIN
// ============================================================

function openAdminHome() {
    resetNav();
    document.getElementById('admin-tabs').classList.remove('hidden');
    state.adminTab = 'invoices';
    document.querySelectorAll('.tab').forEach(function(t) { t.classList.toggle('active', t.dataset.tab === 'invoices'); });
    renderAdminTab();
}

function renderAdminTab() {
    if (state.adminTab === 'invoices') renderAdminInvoices();
    else if (state.adminTab === 'jobs') renderAdminJobs();
    else if (state.adminTab === 'societies') renderAdminSocieties();
    else if (state.adminTab === 'settings') renderAdminSettings();
    setHeader('Adminpanel', { invoices: 'Rechnungen', jobs: 'Jobs', societies: 'Firmen', settings: 'System' }[state.adminTab], false);
}

function renderAdminInvoices() {
    nuiFetch('getAllInvoices').then(function(invoices) {
        state.adminInvoices = invoices || [];
        var open = 0, paid = 0, overdue = 0;
        state.adminInvoices.forEach(function(i) {
            if (i.payment_status === 'open') open++;
            if (i.payment_status === 'paid') paid++;
            if (i.payment_status === 'overdue') overdue++;
        });

        var html = '<div class="stats-row">' +
            '<div class="stat-box"><div class="val">' + state.adminInvoices.length + '</div><div class="lbl">Gesamt</div></div>' +
            '<div class="stat-box"><div class="val">' + open + '</div><div class="lbl">Offen</div></div>' +
            '<div class="stat-box"><div class="val">' + paid + '</div><div class="lbl">Bezahlt</div></div>' +
            '<div class="stat-box"><div class="val">' + overdue + '</div><div class="lbl">Überfällig</div></div></div>';

        document.getElementById('menu-body').innerHTML = html + '<div id="admin-list"></div>';

        var items = [{ icon: 'refresh', title: 'Aktualisieren', action: 'adm_refresh' }];
        window._action_adm_refresh = renderAdminInvoices;

        state.adminInvoices.forEach(function(inv, idx) {
            items.push({
                icon: statusIcon(inv.payment_status),
                iconClass: statusClass(inv.payment_status),
                title: inv.invoice_number,
                desc: (inv.issuer_name || '-') + ' → ' + (inv.recipient_name || '-'),
                value: formatMoney(inv.gross_amount),
                arrow: true,
                action: 'adm_inv_' + idx
            });
            window['_action_adm_inv_' + idx] = (function(i) { return function() { openAdminInvoiceDetail(i); }; })(inv);
        });

        if (state.adminInvoices.length === 0) items.push({ icon: 'inbox', title: 'Keine Rechnungen', readonly: true });

        var list = document.getElementById('admin-list');
        list.innerHTML = '<div class="menu-list"></div>';
        var temp = document.createElement('div');
        temp.innerHTML = '<div class="menu-list">' + items.map(function(item) {
            if (item.readonly) return '<div class="menu-item readonly"><div class="menu-item-icon">' + icon(item.icon, 16) + '</div><div class="menu-item-content"><div class="menu-item-title">' + item.title + '</div></div></div>';
            return '<button class="menu-item" data-action="' + item.action + '"><div class="menu-item-icon ' + (item.iconClass || '') + '">' + icon(item.icon, 16) + '</div><div class="menu-item-content"><div class="menu-item-title">' + item.title + '</div>' + (item.desc ? '<div class="menu-item-desc">' + item.desc + '</div>' : '') + '</div>' + (item.value ? '<span class="menu-item-value">' + item.value + '</span>' : '') + '<span class="menu-item-arrow">' + icon('chevron-right', 16) + '</span></button>';
        }).join('') + '</div>';
        list.innerHTML = temp.innerHTML;
        list.querySelectorAll('[data-action]').forEach(function(el) {
            el.addEventListener('click', function() { var fn = window['_action_' + el.getAttribute('data-action')]; if (fn) fn(); });
        });
    });
}

function openAdminInvoiceDetail(inv) {
    document.getElementById('admin-tabs').classList.add('hidden');
    pushView(function() {
        var html = '<div class="detail-block">';
        html += row('Aussteller', inv.issuer_name || '-');
        html += row('Empfänger', inv.recipient_name || '-');
        html += row('Grund', inv.reason);
        html += row('Brutto', formatMoney(inv.gross_amount), true);
        html += row('Status', statusLabel(inv.payment_status));
        html += '</div><div class="btn-row" style="margin-bottom:6px"><button class="btn btn-ghost" id="adm-edit">' + icon('edit', 14) + ' Bearbeiten</button></div>';
        html += '<div class="btn-row"><button class="btn btn-danger" id="adm-cancel">' + icon('x', 14) + ' Stornieren</button>';
        html += '<button class="btn btn-danger" id="adm-delete">' + icon('trash', 14) + ' Löschen</button></div>';
        document.getElementById('menu-body').innerHTML = html;

        document.getElementById('adm-edit').onclick = function() { openAdminEditInvoice(inv); };
        document.getElementById('adm-cancel').onclick = function() {
            showPrompt('Stornierungsgrund (optional):', '', { title: 'Stornieren' }).then(function(r) {
                if (r === null) return;
                nuiFetch('cancelInvoice', { invoiceId: inv.id, reason: r });
                showToast('Storniert', 'success');
                document.getElementById('admin-tabs').classList.remove('hidden');
                goBack(); renderAdminInvoices();
            });
        };
        document.getElementById('adm-delete').onclick = function() {
            showConfirm('Rechnung unwiderruflich löschen?', { title: 'Löschen', danger: true, confirmText: 'Löschen' }).then(function(ok) {
                if (!ok) return;
                nuiFetch('deleteInvoice', { invoiceId: inv.id });
                showToast('Gelöscht', 'success');
                document.getElementById('admin-tabs').classList.remove('hidden');
                goBack(); renderAdminInvoices();
            });
        };
    }, inv.invoice_number, statusLabel(inv.payment_status));
}

function openAdminEditInvoice(inv) {
    pushView(function() {
        document.getElementById('menu-body').innerHTML =
            '<form class="form" id="edit-form">' +
            '<div class="form-group"><label>Grund</label><input id="e-reason" value="' + esc(inv.reason) + '" required></div>' +
            '<div class="form-row"><div class="form-group"><label>Netto (€)</label><input type="number" id="e-net" value="' + inv.net_amount + '" step="0.01"></div>' +
            '<div class="form-group"><label>Steuer (%)</label><input type="number" id="e-tax" value="' + inv.tax_rate + '"></div></div>' +
            '<div class="form-group"><label>Status</label><select id="e-status"><option value="open">Offen</option><option value="paid">Bezahlt</option><option value="overdue">Überfällig</option><option value="cancelled">Storniert</option></select></div>' +
            '<button type="submit" class="btn btn-primary">' + icon('save', 14) + ' Speichern</button></form>';
        document.getElementById('e-status').value = inv.payment_status;
        document.getElementById('edit-form').onsubmit = function(e) {
            e.preventDefault();
            nuiFetch('editInvoice', { invoiceId: inv.id, reason: document.getElementById('e-reason').value, net_amount: parseFloat(document.getElementById('e-net').value), tax_rate: parseFloat(document.getElementById('e-tax').value), payment_status: document.getElementById('e-status').value });
            showToast('Gespeichert', 'success');
            goBack(); goBack(); renderAdminInvoices();
        };
    }, 'Bearbeiten', inv.invoice_number);
}

function esc(s) { return String(s || '').replace(/"/g, '&quot;').replace(/</g, '&lt;'); }

function renderAdminJobs() {
    nuiFetch('getJobSettings').then(function(r) {
        state.jobs = r.jobs || [];
        state.jobSettings = r.settings || {};
        var items = state.jobs.map(function(job, i) {
            var cfg = state.jobSettings[job.name];
            return { icon: cfg ? 'check-circle' : 'briefcase', iconClass: cfg ? 'success' : '', title: job.label, desc: cfg ? 'Konfiguriert' : 'Nicht eingerichtet', arrow: true, action: 'job_' + i };
        });
        items.forEach(function(_, i) {
            window['_action_job_' + i] = (function(job) { return function() { openAdminJobForm(job); }; })(state.jobs[i]);
        });
        renderList(items);
    });
}

function openAdminJobForm(job) {
    document.getElementById('admin-tabs').classList.add('hidden');
    var s = state.jobSettings[job.name] || {};
    pushView(function() {
        document.getElementById('menu-body').innerHTML =
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
            '<button type="submit" class="btn btn-primary">' + icon('save', 14) + ' Speichern</button>' +
            '<button type="button" class="btn btn-danger" id="j-del">' + icon('trash', 14) + ' Löschen</button></form>';
        document.getElementById('j-dest').value = s.money_destination || 'society';
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
            document.getElementById('admin-tabs').classList.remove('hidden');
            goBack(); renderAdminJobs();
        };
        document.getElementById('j-del').onclick = function() {
            showConfirm('Job-Einstellungen löschen?', { danger: true }).then(function(ok) {
                if (!ok) return;
                nuiFetch('deleteJobSettings', { jobName: job.name });
                document.getElementById('admin-tabs').classList.remove('hidden');
                goBack(); renderAdminJobs();
            });
        };
    }, job.label, 'Job-Einstellungen');
}

function chk(id, label, checked) {
    return '<label class="check-row"><input type="checkbox" id="' + id + '"' + (checked ? ' checked' : '') + '>' + label + '</label>';
}

function renderAdminSocieties() {
    nuiFetch('getAllSocieties').then(function(societies) {
        nuiFetch('getSocietyInfo').then(function(info) {
            state.societies = societies || [];
            state.societyInfo = info || {};
            var items = state.societies.map(function(soc, i) {
                var cfg = state.societyInfo[soc.name];
                return { icon: cfg ? 'check-circle' : 'building', iconClass: cfg ? 'success' : '', title: soc.label, desc: cfg ? 'Daten hinterlegt' : 'Nicht eingerichtet', arrow: true, action: 'soc_' + i };
            });
            items.forEach(function(_, i) {
                window['_action_soc_' + i] = (function(s) { return function() { openAdminSocietyForm(s); }; })(state.societies[i]);
            });
            renderList(items);
        });
    });
}

function openAdminSocietyForm(soc) {
    document.getElementById('admin-tabs').classList.add('hidden');
    var info = state.societyInfo[soc.name] || {};
    pushView(function() {
        document.getElementById('menu-body').innerHTML =
            '<form class="form" id="soc-form">' +
            '<div class="form-group"><label>Firmenname</label><input id="sf-name" value="' + esc(info.company_name) + '"></div>' +
            '<div class="form-group"><label>Adresse</label><textarea id="sf-addr">' + esc(info.company_address) + '</textarea></div>' +
            '<div class="form-row"><div class="form-group"><label>Steuernr.</label><input id="sf-tax" value="' + esc(info.tax_id) + '"></div>' +
            '<div class="form-group"><label>USt-IdNr.</label><input id="sf-vat" value="' + esc(info.vat_id) + '"></div></div>' +
            '<div class="form-group"><label>Präfix</label><input id="sf-pre" value="' + esc(info.invoice_prefix || 'RE') + '" maxlength="10"></div>' +
            '<button type="submit" class="btn btn-primary">' + icon('save', 14) + ' Speichern</button>' +
            '<button type="button" class="btn btn-danger" id="sf-del">' + icon('trash', 14) + ' Löschen</button></form>';
        document.getElementById('soc-form').onsubmit = function(e) {
            e.preventDefault();
            nuiFetch('saveSocietyInfo', { society_name: soc.name, company_name: document.getElementById('sf-name').value, company_address: document.getElementById('sf-addr').value, tax_id: document.getElementById('sf-tax').value, vat_id: document.getElementById('sf-vat').value, invoice_prefix: document.getElementById('sf-pre').value || 'RE' });
            showToast('Firma gespeichert', 'success');
            document.getElementById('admin-tabs').classList.remove('hidden');
            goBack(); renderAdminSocieties();
        };
        document.getElementById('sf-del').onclick = function() {
            showConfirm('Firmendaten löschen?', { danger: true }).then(function(ok) {
                if (!ok) return;
                nuiFetch('deleteSocietyInfo', { societyName: soc.name });
                document.getElementById('admin-tabs').classList.remove('hidden');
                goBack(); renderAdminSocieties();
            });
        };
    }, soc.label, 'Firmendaten');
}

function boolVal(v) { return v === 'true' || v === true; }

function renderAdminSettings() {
    nuiFetch('getGlobalSettings').then(function(s) {
        state.globalSettings = s || {};
        renderList([
            { section: 'Bereiche' },
            { icon: 'bell', title: 'Discord & Logging', arrow: true, action: 'set_discord' },
            { icon: 'percent', title: 'Steuersystem', arrow: true, action: 'set_tax' },
            { icon: 'receipt', title: 'Rechnungen & Fristen', arrow: true, action: 'set_inv' },
            { icon: 'shield', title: 'Admin-Rechte', arrow: true, action: 'set_perm' }
        ]);
    });
}

window._action_set_discord = function() {
    var s = state.globalSettings;
    document.getElementById('admin-tabs').classList.add('hidden');
    pushView(function() {
        document.getElementById('menu-body').innerHTML = '<form class="form" id="f-discord">' + chk('d-en', 'Discord aktiv', boolVal(s.discord_enabled)) + '<div class="form-group"><label>Webhook URL</label><input id="d-url" value="' + esc(s.discord_webhook) + '"></div><button class="btn btn-primary" type="submit">' + icon('save', 14) + ' Speichern</button></form>';
        document.getElementById('f-discord').onsubmit = function(e) { e.preventDefault(); nuiFetch('saveGlobalSettings', { discord_enabled: document.getElementById('d-en').checked, discord_webhook: document.getElementById('d-url').value }); showToast('Gespeichert', 'success'); document.getElementById('admin-tabs').classList.remove('hidden'); goBack(); };
    }, 'Discord', '');
};

window._action_set_tax = function() {
    var s = state.globalSettings;
    document.getElementById('admin-tabs').classList.add('hidden');
    pushView(function() {
        document.getElementById('menu-body').innerHTML = '<form class="form" id="f-tax">' + chk('t-en', 'Steuern aktiv', boolVal(s.tax_enabled)) + '<div class="form-group"><label>Standard-Steuersatz %</label><input type="number" id="t-rate" value="' + (s.default_tax_rate || 19) + '"></div><button class="btn btn-primary" type="submit">' + icon('save', 14) + ' Speichern</button></form>';
        document.getElementById('f-tax').onsubmit = function(e) { e.preventDefault(); nuiFetch('saveGlobalSettings', { tax_enabled: document.getElementById('t-en').checked, default_tax_rate: document.getElementById('t-rate').value }); showToast('Gespeichert', 'success'); document.getElementById('admin-tabs').classList.remove('hidden'); goBack(); };
    }, 'Steuern', '');
};

window._action_set_inv = function() {
    var s = state.globalSettings;
    document.getElementById('admin-tabs').classList.add('hidden');
    pushView(function() {
        document.getElementById('menu-body').innerHTML = '<form class="form" id="f-inv">' + chk('i-auto', 'Auto-Nummern', boolVal(s.auto_invoice_numbers)) + '<div class="form-group"><label>Präfix</label><input id="i-pre" value="' + esc(s.invoice_prefix || 'RE') + '"></div><div class="form-row"><div class="form-group"><label>Frist (Tage)</label><input type="number" id="i-days" value="' + (s.payment_deadline_days || 14) + '"></div><div class="form-group"><label>Mahngebühr €</label><input type="number" id="i-fee" value="' + (s.reminder_fee || 25) + '"></div></div>' + chk('i-login', 'Login-Hinweis', boolVal(s.show_unpaid_on_login)) + '<button class="btn btn-primary" type="submit">' + icon('save', 14) + ' Speichern</button></form>';
        document.getElementById('f-inv').onsubmit = function(e) { e.preventDefault(); nuiFetch('saveGlobalSettings', { auto_invoice_numbers: document.getElementById('i-auto').checked, invoice_prefix: document.getElementById('i-pre').value, payment_deadline_days: document.getElementById('i-days').value, reminder_fee: document.getElementById('i-fee').value, show_unpaid_on_login: document.getElementById('i-login').checked }); showToast('Gespeichert', 'success'); document.getElementById('admin-tabs').classList.remove('hidden'); goBack(); };
    }, 'Rechnungen', '');
};

window._action_set_perm = function() {
    var s = state.globalSettings;
    document.getElementById('admin-tabs').classList.add('hidden');
    pushView(function() {
        document.getElementById('menu-body').innerHTML = '<form class="form" id="f-perm">' + chk('p-view', 'Einsehen', boolVal(s.admin_can_view)) + chk('p-edit', 'Bearbeiten', boolVal(s.admin_can_edit)) + chk('p-cancel', 'Stornieren', boolVal(s.admin_can_cancel)) + chk('p-del', 'Löschen', boolVal(s.admin_can_delete)) + '<button class="btn btn-primary" type="submit">' + icon('save', 14) + ' Speichern</button></form>';
        document.getElementById('f-perm').onsubmit = function(e) { e.preventDefault(); nuiFetch('saveGlobalSettings', { admin_can_view: document.getElementById('p-view').checked, admin_can_edit: document.getElementById('p-edit').checked, admin_can_cancel: document.getElementById('p-cancel').checked, admin_can_delete: document.getElementById('p-del').checked }); showToast('Gespeichert', 'success'); document.getElementById('admin-tabs').classList.remove('hidden'); goBack(); };
    }, 'Admin-Rechte', '');
};

// ============================================================
// Events
// ============================================================

window.addEventListener('message', function(e) {
    var d = e.data;
    if (d.action === 'open') {
        var root = document.getElementById('menu-root');
        root.classList.remove('hidden');
        if (d.config && d.config.width) {
            document.documentElement.style.setProperty('--menu-width', d.config.width + 'px');
        }
        document.getElementById('admin-tabs').classList.add('hidden');
        setIcon(document.getElementById('btn-close'), 'x', 16);
        setIcon(document.getElementById('btn-back'), 'chevron-left', 16);
        requestAnimationFrame(function() { root.classList.add('open'); });

        if (d.mode === 'player') { state.mode = 'player'; openPlayerHome(); }
        else if (d.mode === 'create') { state.mode = 'create'; openCreateHome(d.data); }
        else if (d.mode === 'admin') { state.mode = 'admin'; openAdminHome(); }
        else if (d.mode === 'hub') { openHubHome(d.data); }
    } else if (d.action === 'close') {
        document.getElementById('menu-root').classList.remove('open');
        setTimeout(function() { document.getElementById('menu-root').classList.add('hidden'); }, 280);
    } else if (d.action === 'toast') {
        showToast(d.message, d.type);
    }
});

document.getElementById('btn-close').onclick = closeMenu;
document.getElementById('btn-back').onclick = function() {
    if (state.navStack.length <= 1) {
        closeMenu();
        return;
    }

    if (state.mode === 'admin' && state.navStack.length === 2 && state.hubData) {
        document.getElementById('admin-tabs').classList.add('hidden');
        state.mode = 'hub';
    }

    goBack();
};

document.querySelectorAll('.tab').forEach(function(tab) {
    tab.addEventListener('click', function() {
        state.adminTab = tab.dataset.tab;
        document.querySelectorAll('.tab').forEach(function(t) { t.classList.toggle('active', t === tab); });

        if (state.hubData && state.navStack.length > 1) {
            state.navStack = state.navStack.slice(0, 2);
            setHeader('Adminpanel', { invoices: 'Rechnungen', jobs: 'Jobs', societies: 'Firmen', settings: 'System' }[state.adminTab], true);
            renderAdminTab();
        } else {
            resetNav();
            state.mode = 'admin';
            document.getElementById('admin-tabs').classList.remove('hidden');
            renderAdminTab();
        }
    });
});

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        if (isDialogOpen()) { closeDialog(null); return; }
        if (state.navStack.length > 1) { goBack(); return; }
        closeMenu();
    }
});

setIcon(document.getElementById('btn-close'), 'x', 16);
setIcon(document.getElementById('btn-back'), 'chevron-left', 16);
