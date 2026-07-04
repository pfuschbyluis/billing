/**
 * ESX Rechnungssystem - NUI JavaScript
 * Deutsches UI für Spieler, Admin und Rechnungserstellung
 */

// ============================================================
// Zustand
// ============================================================

let currentMode = null;
let playerInvoices = [];
let adminInvoices = [];
let currentFilter = 'all';
let createData = null;
let jobSettingsCache = {};
let societyInfoCache = {};
let allJobs = [];
let allSocieties = [];
let selectedInvoice = null;

// ============================================================
// Icon-Rendering
// ============================================================

/**
 * Rendert alle data-icon Elemente im DOM
 */
function refreshIcons(root) {
    if (typeof injectIcons === 'function') {
        injectIcons(root || document);
    }
}

// ============================================================
// NUI-Kommunikation
// ============================================================

/**
 * Sendet eine Nachricht an den FiveM-Client
 */
function nuiFetch(event, data = {}) {
    const resourceName = (typeof GetParentResourceName === 'function')
        ? GetParentResourceName()
        : 'esx_rechnungen';

    return fetch('https://' + resourceName + '/' + event, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).then(r => r.json()).catch(() => ({}));
}

/**
 * Schließt die UI
 */
function closeUI() {
    document.getElementById('app').classList.add('hidden');
    nuiFetch('close');
}

// ============================================================
// Nachrichten vom Client empfangen
// ============================================================

window.addEventListener('message', (event) => {
    const { action, mode, data } = event.data;

    if (action === 'open') {
        openApp(mode, data);
    } else if (action === 'close') {
        document.getElementById('app').classList.add('hidden');
    } else if (action === 'escape') {
        if (isDialogOpen()) {
            closeDialog(null);
        } else if (!document.getElementById('modal-invoice').classList.contains('hidden')) {
            closeModal();
        } else if (!document.getElementById('modal-edit').classList.contains('hidden')) {
            closeEditModal();
        } else {
            closeUI();
        }
    }
});

/**
 * Öffnet die App im angegebenen Modus
 */
function openApp(mode, data = {}) {
    currentMode = mode;
    const app = document.getElementById('app');
    app.classList.remove('hidden');
    app.classList.toggle('admin-mode', mode === 'admin');

    document.querySelectorAll('.view').forEach(v => v.classList.add('hidden'));
    document.getElementById('admin-sidebar').classList.add('hidden');

    if (mode === 'player') {
        document.getElementById('header-title').textContent = 'Meine Rechnungen';
        document.getElementById('header-subtitle').textContent = 'Übersicht & Bezahlung';
        document.getElementById('view-player').classList.remove('hidden');
        loadPlayerInvoices();

    } else if (mode === 'create') {
        document.getElementById('header-title').textContent = 'Rechnung ausstellen';
        document.getElementById('header-subtitle').textContent = data.job ? data.job.label : '';
        document.getElementById('view-create').classList.remove('hidden');
        initCreateForm(data);

    } else if (mode === 'admin') {
        document.getElementById('header-title').textContent = 'Adminpanel';
        document.getElementById('header-subtitle').textContent = 'Rechnungssystem Verwaltung';
        document.getElementById('admin-sidebar').classList.remove('hidden');
        switchTab('invoices');
    }

    injectIcons();
}

// ============================================================
// Hilfsfunktionen
// ============================================================

/**
 * Formatiert einen Betrag als Euro-String
 */
function formatMoney(amount) {
    return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(amount || 0);
}

/**
 * Formatiert ein Datum im deutschen Format
 */
function formatDate(dateStr) {
    if (!dateStr) return '-';
    const d = new Date(dateStr);
    return d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

/**
 * Gibt den deutschen Status-Text zurück
 */
function getStatusLabel(status) {
    const labels = {
        open: 'Offen',
        paid: 'Bezahlt',
        overdue: 'Überfällig',
        cancelled: 'Storniert'
    };
    return labels[status] || status;
}

/**
 * Erstellt HTML für eine Rechnungskarte
 */
function renderInvoiceCard(inv, onClick) {
    const statusClass = `status-${inv.payment_status}`;
    const gross = parseFloat(inv.gross_amount);
    const reminderFee = inv.payment_status === 'overdue' ? parseFloat(inv.reminder_fee || 0) : 0;
    const total = gross + reminderFee;

    return `
        <div class="invoice-card" onclick="${onClick}(${inv.id})">
            <div class="invoice-card-header">
                <span class="invoice-number">${icon('file-text', 14)} ${inv.invoice_number}</span>
                <span class="status-badge ${statusClass}">${getStatusLabel(inv.payment_status)}</span>
            </div>
            <div class="invoice-card-body">
                <div class="invoice-info">
                    <div class="invoice-issuer">${inv.issuer_name || inv.company_name || inv.issuer_job}</div>
                    <div class="invoice-reason">${inv.reason}</div>
                    <div class="invoice-date">${formatDate(inv.created_at)}</div>
                </div>
                <div class="invoice-amount">
                    ${formatMoney(total)}
                    ${reminderFee > 0 ? `<small>inkl. ${formatMoney(reminderFee)} Mahngebühr</small>` : ''}
                </div>
            </div>
        </div>
    `;
}

/**
 * Zeigt leeren Zustand an
 */
function renderEmptyState(message) {
    return `
        <div class="empty-state">
            <div class="empty-icon">${icon('inbox', 28)}</div>
            <p>${message}</p>
        </div>
    `;
}

// ============================================================
// Spieler-Ansicht
// ============================================================

async function loadPlayerInvoices() {
    playerInvoices = await nuiFetch('getMyInvoices');
    renderPlayerInvoices();
}

function filterInvoices(filter) {
    currentFilter = filter;
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.filter === filter);
    });
    renderPlayerInvoices();
}

function renderPlayerInvoices() {
    const container = document.getElementById('player-invoices');
    let filtered = playerInvoices;

    if (currentFilter !== 'all') {
        filtered = playerInvoices.filter(inv => inv.payment_status === currentFilter);
    }

    if (!filtered || filtered.length === 0) {
        container.innerHTML = renderEmptyState('Keine Rechnungen vorhanden.');
        refreshIcons(container);
        return;
    }

    container.innerHTML = filtered.map(inv => renderInvoiceCard(inv, 'showPlayerInvoiceDetail')).join('');
    refreshIcons(container);
}

function showPlayerInvoiceDetail(invoiceId) {
    const inv = playerInvoices.find(i => i.id === invoiceId);
    if (!inv) return;

    selectedInvoice = inv;
    showInvoiceDetailModal(inv, 'player');
}

// ============================================================
// Rechnung erstellen
// ============================================================

async function initCreateForm(data) {
    createData = data;

    // Steuersatz vorausfüllen
    const taxRate = data.settings ? data.settings.tax_rate : 19;
    document.getElementById('create-tax-rate').value = taxRate;

    // Spieler laden
    const players = await nuiFetch('getNearbyPlayers');
    const playerSelect = document.getElementById('create-target-id');
    playerSelect.innerHTML = '<option value="">-- Spieler wählen --</option>';
    players.forEach(p => {
        playerSelect.innerHTML += `<option value="${p.source}">${p.name} (${p.distance}m)</option>`;
    });

    // Societies laden (falls erlaubt)
    if (data.settings && data.settings.can_issue_society) {
        const societies = await nuiFetch('getSocieties');
        const societySelect = document.getElementById('create-society-name');
        societySelect.innerHTML = '<option value="">-- Firma wählen --</option>';
        societies.forEach(s => {
            societySelect.innerHTML += `<option value="${s.name}">${s.label}</option>`;
        });
    }

    // Empfängertyp-Optionen anpassen
    const typeSelect = document.getElementById('create-recipient-type');
    if (!data.settings || !data.settings.can_issue_player) {
        typeSelect.querySelector('[value="player"]').disabled = true;
        typeSelect.value = 'society';
    }
    if (!data.settings || !data.settings.can_issue_society) {
        typeSelect.querySelector('[value="society"]').disabled = true;
    }

    onRecipientTypeChange();
    updateTaxPreview();
}

function onRecipientTypeChange() {
    const type = document.getElementById('create-recipient-type').value;
    document.getElementById('create-player-select').classList.toggle('hidden', type !== 'player');
    document.getElementById('create-society-select').classList.toggle('hidden', type !== 'society');
}

function updateTaxPreview() {
    const net = parseFloat(document.getElementById('create-net-amount').value) || 0;
    const rate = parseFloat(document.getElementById('create-tax-rate').value) || 0;
    const tax = Math.round(net * (rate / 100) * 100) / 100;
    const gross = Math.round((net + tax) * 100) / 100;

    document.getElementById('preview-net').textContent = formatMoney(net);
    document.getElementById('preview-tax').textContent = formatMoney(tax);
    document.getElementById('preview-gross').textContent = formatMoney(gross);
}

async function submitCreateInvoice(e) {
    e.preventDefault();

    const recipientType = document.getElementById('create-recipient-type').value;
    const data = {
        recipient_type: recipientType,
        reason: document.getElementById('create-reason').value,
        net_amount: parseFloat(document.getElementById('create-net-amount').value),
        tax_rate: parseFloat(document.getElementById('create-tax-rate').value)
    };

    if (recipientType === 'player') {
        data.target_id = parseInt(document.getElementById('create-target-id').value);
        if (!data.target_id) {
            showToast('Bitte wähle einen Spieler aus.', 'warning');
            return;
        }
    } else {
        data.society_name = document.getElementById('create-society-name').value;
        if (!data.society_name) {
            showToast('Bitte wähle eine Firma aus.', 'warning');
            return;
        }
    }

    await nuiFetch('createInvoice', data);

    // Formular zurücksetzen
    document.getElementById('create-form').reset();
    if (createData && createData.settings) {
        document.getElementById('create-tax-rate').value = createData.settings.tax_rate || 19;
    }
    updateTaxPreview();
    closeUI();
}

// ============================================================
// Admin: Tab-Navigation
// ============================================================

function switchTab(tab) {
    document.querySelectorAll('.sidebar-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tab);
    });

    document.querySelectorAll('[id^="view-admin"]').forEach(v => v.classList.add('hidden'));

    if (tab === 'invoices') {
        document.getElementById('view-admin-invoices').classList.remove('hidden');
        loadAdminInvoices();
    } else if (tab === 'jobs') {
        document.getElementById('view-admin-jobs').classList.remove('hidden');
        loadJobsTab();
    } else if (tab === 'societies') {
        document.getElementById('view-admin-societies').classList.remove('hidden');
        loadSocietiesTab();
    } else if (tab === 'settings') {
        document.getElementById('view-admin-settings').classList.remove('hidden');
        loadGlobalSettings();
    }

    injectIcons();
}

// ============================================================
// Admin: Rechnungen
// ============================================================

async function loadAdminInvoices() {
    adminInvoices = await nuiFetch('getAllInvoices');
    renderAdminStats(adminInvoices);
    renderAdminInvoices(adminInvoices);
    injectIcons();
}

/**
 * Rendert Statistik-Karten im Adminpanel
 */
function renderAdminStats(invoices) {
    const stats = {
        total: invoices.length,
        open: invoices.filter(i => i.payment_status === 'open').length,
        paid: invoices.filter(i => i.payment_status === 'paid').length,
        overdue: invoices.filter(i => i.payment_status === 'overdue').length
    };

    const totalRevenue = invoices
        .filter(i => i.payment_status === 'paid')
        .reduce((sum, i) => sum + parseFloat(i.gross_amount || 0), 0);

    document.getElementById('admin-stats').innerHTML = `
        <div class="stat-card">
            <div class="stat-icon info">${icon('file-text', 18)}</div>
            <div class="stat-content">
                <div class="stat-value">${stats.total}</div>
                <div class="stat-label">Gesamt</div>
            </div>
        </div>
        <div class="stat-card">
            <div class="stat-icon warning">${icon('clock', 18)}</div>
            <div class="stat-content">
                <div class="stat-value">${stats.open}</div>
                <div class="stat-label">Offen</div>
            </div>
        </div>
        <div class="stat-card">
            <div class="stat-icon success">${icon('check-circle', 18)}</div>
            <div class="stat-content">
                <div class="stat-value">${stats.paid}</div>
                <div class="stat-label">Bezahlt · ${formatMoney(totalRevenue)} Umsatz</div>
            </div>
        </div>
        <div class="stat-card">
            <div class="stat-icon danger">${icon('alert-circle', 18)}</div>
            <div class="stat-content">
                <div class="stat-value">${stats.overdue}</div>
                <div class="stat-label">Überfällig</div>
            </div>
        </div>
    `;
}

function searchAdminInvoices() {
    const query = document.getElementById('admin-search').value.toLowerCase();
    const filtered = adminInvoices.filter(inv =>
        inv.invoice_number.toLowerCase().includes(query) ||
        (inv.issuer_name && inv.issuer_name.toLowerCase().includes(query)) ||
        (inv.recipient_name && inv.recipient_name.toLowerCase().includes(query)) ||
        (inv.reason && inv.reason.toLowerCase().includes(query))
    );
    renderAdminInvoices(filtered);
}

function renderAdminInvoices(invoices) {
    const container = document.getElementById('admin-invoices');

    if (!invoices || invoices.length === 0) {
        container.innerHTML = renderEmptyState('Keine Rechnungen gefunden.');
        refreshIcons(container);
        return;
    }

    container.innerHTML = invoices.map(inv => renderInvoiceCard(inv, 'showAdminInvoiceDetail')).join('');
    refreshIcons(container);
}

function showAdminInvoiceDetail(invoiceId) {
    const inv = adminInvoices.find(i => i.id === invoiceId);
    if (!inv) return;

    selectedInvoice = inv;
    showInvoiceDetailModal(inv, 'admin');
}

// ============================================================
// Rechnungsdetail-Modal
// ============================================================

function showInvoiceDetailModal(inv, mode) {
    const body = document.getElementById('modal-invoice-body');
    const actions = document.getElementById('modal-invoice-actions');

    document.getElementById('modal-invoice-title').textContent = inv.invoice_number;

    const gross = parseFloat(inv.gross_amount);
    const reminderFee = inv.payment_status === 'overdue' ? parseFloat(inv.reminder_fee || 0) : 0;

    body.innerHTML = `
        <div class="invoice-detail">
            <div class="detail-section">
                <h4>Aussteller</h4>
                <div class="detail-row"><span>Firma</span><span>${inv.company_name || inv.issuer_name || '-'}</span></div>
                <div class="detail-row"><span>Adresse</span><span>${inv.company_address || '-'}</span></div>
                <div class="detail-row"><span>Steuernr.</span><span>${inv.tax_id || '-'}</span></div>
                <div class="detail-row"><span>USt-IdNr.</span><span>${inv.vat_id || '-'}</span></div>
                <div class="detail-row"><span>Mitarbeiter</span><span>${inv.issuer_name || '-'}</span></div>
            </div>
            <div class="detail-section">
                <h4>Rechnungsdetails</h4>
                <div class="detail-row"><span>Rechnungsnummer</span><span>${inv.invoice_number}</span></div>
                <div class="detail-row"><span>Datum</span><span>${formatDate(inv.created_at)}</span></div>
                <div class="detail-row"><span>Empfänger</span><span>${inv.recipient_name || '-'}</span></div>
                <div class="detail-row"><span>Grund</span><span>${inv.reason}</span></div>
                <div class="detail-row"><span>Fällig am</span><span>${formatDate(inv.due_date)}</span></div>
                <div class="detail-row"><span>Status</span><span class="status-badge status-${inv.payment_status}">${getStatusLabel(inv.payment_status)}</span></div>
            </div>
            <div class="detail-section">
                <h4>Beträge</h4>
                <div class="detail-row"><span>Netto</span><span>${formatMoney(inv.net_amount)}</span></div>
                <div class="detail-row"><span>Steuersatz</span><span>${inv.tax_rate}%</span></div>
                <div class="detail-row"><span>Steuerbetrag</span><span>${formatMoney(inv.tax_amount)}</span></div>
                ${reminderFee > 0 ? `<div class="detail-row"><span>Mahngebühr</span><span>${formatMoney(reminderFee)}</span></div>` : ''}
                <div class="detail-row total-row"><span>Brutto</span><span>${formatMoney(gross + reminderFee)}</span></div>
            </div>
            ${inv.paid_at ? `
            <div class="detail-section">
                <h4>Zahlung</h4>
                <div class="detail-row"><span>Bezahlt am</span><span>${formatDate(inv.paid_at)}</span></div>
                <div class="detail-row"><span>Methode</span><span>${inv.payment_method === 'bank' ? 'Bank' : 'Bargeld'}</span></div>
            </div>` : ''}
        </div>
    `;

    // Aktionen je nach Modus
    if (mode === 'player' && (inv.payment_status === 'open' || inv.payment_status === 'overdue')) {
        actions.innerHTML = `
            <div class="payment-buttons">
                <button class="btn btn-success" onclick="payInvoice(${inv.id}, 'bank')">${icon('credit-card', 16)} Per Bank bezahlen</button>
                <button class="btn btn-success" onclick="payInvoice(${inv.id}, 'cash')">${icon('banknote', 16)} Bar bezahlen</button>
            </div>
        `;
    } else if (mode === 'admin') {
        actions.innerHTML = `
            <button class="btn btn-secondary" onclick="openEditModal(${inv.id})">${icon('edit', 16)} Bearbeiten</button>
            <button class="btn btn-danger" onclick="cancelInvoice(${inv.id})">${icon('x', 16)} Stornieren</button>
            <button class="btn btn-danger" onclick="deleteInvoice(${inv.id})">${icon('trash', 16)} Löschen</button>
        `;
    } else {
        actions.innerHTML = '';
    }

    document.getElementById('modal-invoice').classList.remove('hidden');
    refreshIcons(document.getElementById('modal-invoice-actions'));
}

function closeModal() {
    document.getElementById('modal-invoice').classList.add('hidden');
    selectedInvoice = null;
}

async function payInvoice(invoiceId, method) {
    await nuiFetch('payInvoice', { invoiceId, paymentMethod: method });
    closeModal();
    if (currentMode === 'player') {
        setTimeout(loadPlayerInvoices, 500);
    }
}

// ============================================================
// Admin: Rechnung bearbeiten / stornieren / löschen
// ============================================================

function openEditModal(invoiceId) {
    const inv = adminInvoices.find(i => i.id === invoiceId);
    if (!inv) return;

    document.getElementById('edit-invoice-id').value = inv.id;
    document.getElementById('edit-reason').value = inv.reason;
    document.getElementById('edit-net-amount').value = inv.net_amount;
    document.getElementById('edit-tax-rate').value = inv.tax_rate;
    document.getElementById('edit-payment-status').value = inv.payment_status;

    closeModal();
    document.getElementById('modal-edit').classList.remove('hidden');
}

function closeEditModal() {
    document.getElementById('modal-edit').classList.add('hidden');
}

async function submitEditInvoice(e) {
    e.preventDefault();
    await nuiFetch('editInvoice', {
        invoiceId: parseInt(document.getElementById('edit-invoice-id').value),
        reason: document.getElementById('edit-reason').value,
        net_amount: parseFloat(document.getElementById('edit-net-amount').value),
        tax_rate: parseFloat(document.getElementById('edit-tax-rate').value),
        payment_status: document.getElementById('edit-payment-status').value
    });
    closeEditModal();
    setTimeout(loadAdminInvoices, 500);
}

async function cancelInvoice(invoiceId) {
    const reason = await showPrompt('Stornierungsgrund (optional):', '', {
        title: 'Rechnung stornieren',
        placeholder: 'Grund eingeben...'
    });
    if (reason === null) return;

    await nuiFetch('cancelInvoice', { invoiceId, reason });
    closeModal();
    showToast('Rechnung wurde storniert.', 'success');
    setTimeout(loadAdminInvoices, 500);
}

async function deleteInvoice(invoiceId) {
    const confirmed = await showConfirm('Rechnung wirklich unwiderruflich löschen?', {
        title: 'Rechnung löschen',
        danger: true,
        confirmText: 'Löschen'
    });
    if (!confirmed) return;

    await nuiFetch('deleteInvoice', { invoiceId });
    closeModal();
    showToast('Rechnung wurde gelöscht.', 'success');
    setTimeout(loadAdminInvoices, 500);
}

// ============================================================
// Admin: Job-Einstellungen
// ============================================================

async function loadJobsTab() {
    const result = await nuiFetch('getJobSettings');
    allJobs = result.jobs || [];
    jobSettingsCache = result.settings || {};

    const select = document.getElementById('job-select');
    select.innerHTML = '<option value="">-- Job auswählen oder neu --</option>';
    allJobs.forEach(job => {
        const hasSettings = jobSettingsCache[job.name] ? ' • konfiguriert' : '';
        select.innerHTML += `<option value="${job.name}">${job.label} (${job.name})${hasSettings}</option>`;
    });
    injectIcons();
}

function loadJobSettingsForm() {
    const jobName = document.getElementById('job-select').value;
    document.getElementById('job-name').value = jobName;

    const settings = jobSettingsCache[jobName] || {};

    document.getElementById('job-can-issue').checked = settings.can_issue == 1;
    document.getElementById('job-can-issue-player').checked = settings.can_issue_player !== 0;
    document.getElementById('job-can-issue-society').checked = settings.can_issue_society == 1;
    document.getElementById('job-max-amount').value = settings.max_amount || 10000;
    document.getElementById('job-require-proximity').checked = settings.require_proximity !== 0;
    document.getElementById('job-max-distance').value = settings.max_distance || 5;
    document.getElementById('job-payment-bank').checked = settings.payment_bank !== 0;
    document.getElementById('job-payment-cash').checked = settings.payment_cash !== 0;
    document.getElementById('job-money-destination').value = settings.money_destination || 'society';
    document.getElementById('job-society-percent').value = settings.society_percent || 70;
    document.getElementById('job-employee-percent').value = settings.employee_percent || 30;
    document.getElementById('job-tax-rate').value = settings.tax_rate || 19;
}

async function saveJobSettings() {
    const jobName = document.getElementById('job-select').value;
    if (!jobName) {
        showToast('Bitte wähle einen Job aus.', 'warning');
        return;
    }

    await nuiFetch('saveJobSettings', {
        job_name: jobName,
        can_issue: document.getElementById('job-can-issue').checked,
        can_issue_player: document.getElementById('job-can-issue-player').checked,
        can_issue_society: document.getElementById('job-can-issue-society').checked,
        max_amount: parseInt(document.getElementById('job-max-amount').value),
        require_proximity: document.getElementById('job-require-proximity').checked,
        max_distance: parseFloat(document.getElementById('job-max-distance').value),
        payment_bank: document.getElementById('job-payment-bank').checked,
        payment_cash: document.getElementById('job-payment-cash').checked,
        money_destination: document.getElementById('job-money-destination').value,
        society_percent: parseInt(document.getElementById('job-society-percent').value),
        employee_percent: parseInt(document.getElementById('job-employee-percent').value),
        tax_rate: parseFloat(document.getElementById('job-tax-rate').value)
    });

    showToast('Job-Einstellungen gespeichert.', 'success');
    setTimeout(loadJobsTab, 500);
}

async function deleteJobSettings() {
    const jobName = document.getElementById('job-select').value;
    if (!jobName) {
        showToast('Bitte wähle einen Job aus.', 'warning');
        return;
    }

    const confirmed = await showConfirm(`Einstellungen für "${jobName}" wirklich löschen?`, {
        title: 'Job-Einstellungen löschen',
        danger: true,
        confirmText: 'Löschen'
    });
    if (!confirmed) return;

    await nuiFetch('deleteJobSettings', { jobName });
    showToast('Job-Einstellungen gelöscht.', 'success');
    setTimeout(loadJobsTab, 500);
}

// ============================================================
// Admin: Society-Informationen
// ============================================================

async function loadSocietiesTab() {
    allSocieties = await nuiFetch('getAllSocieties');
    societyInfoCache = await nuiFetch('getSocietyInfo');

    const select = document.getElementById('society-select');
    select.innerHTML = '<option value="">-- Firma auswählen oder neu --</option>';
    allSocieties.forEach(soc => {
        const hasInfo = societyInfoCache[soc.name] ? ' • konfiguriert' : '';
        select.innerHTML += `<option value="${soc.name}">${soc.label} (${soc.name})${hasInfo}</option>`;
    });
    injectIcons();
}

function loadSocietyInfoForm() {
    const societyName = document.getElementById('society-select').value;
    document.getElementById('society-name').value = societyName;

    const info = societyInfoCache[societyName] || {};

    document.getElementById('society-company-name').value = info.company_name || '';
    document.getElementById('society-company-address').value = info.company_address || '';
    document.getElementById('society-tax-id').value = info.tax_id || '';
    document.getElementById('society-vat-id').value = info.vat_id || '';
    document.getElementById('society-invoice-prefix').value = info.invoice_prefix || 'RE';
}

async function saveSocietyInfo() {
    const societyName = document.getElementById('society-select').value;
    if (!societyName) {
        showToast('Bitte wähle eine Firma aus.', 'warning');
        return;
    }

    await nuiFetch('saveSocietyInfo', {
        society_name: societyName,
        company_name: document.getElementById('society-company-name').value,
        company_address: document.getElementById('society-company-address').value,
        tax_id: document.getElementById('society-tax-id').value,
        vat_id: document.getElementById('society-vat-id').value,
        invoice_prefix: document.getElementById('society-invoice-prefix').value || 'RE'
    });

    showToast('Firmendaten gespeichert.', 'success');
    setTimeout(loadSocietiesTab, 500);
}

async function deleteSocietyInfo() {
    const societyName = document.getElementById('society-select').value;
    if (!societyName) {
        showToast('Bitte wähle eine Firma aus.', 'warning');
        return;
    }

    const confirmed = await showConfirm(`Firmendaten für "${societyName}" wirklich löschen?`, {
        title: 'Firmendaten löschen',
        danger: true,
        confirmText: 'Löschen'
    });
    if (!confirmed) return;

    await nuiFetch('deleteSocietyInfo', { societyName });
    showToast('Firmendaten gelöscht.', 'success');
    setTimeout(loadSocietiesTab, 500);
}

// ============================================================
// Admin: Globale Einstellungen
// ============================================================

async function loadGlobalSettings() {
    const settings = await nuiFetch('getGlobalSettings');
    if (!settings) return;

    const bool = (key) => settings[key] === 'true' || settings[key] === true;

    document.getElementById('set-discord-enabled').checked = bool('discord_enabled');
    document.getElementById('set-discord-webhook').value = settings.discord_webhook || '';
    document.getElementById('set-tax-enabled').checked = bool('tax_enabled');
    document.getElementById('set-default-tax-rate').value = settings.default_tax_rate || 19;
    document.getElementById('set-auto-invoice-numbers').checked = bool('auto_invoice_numbers');
    document.getElementById('set-invoice-prefix').value = settings.invoice_prefix || 'RE';
    document.getElementById('set-payment-deadline-days').value = settings.payment_deadline_days || 14;
    document.getElementById('set-reminder-fee').value = settings.reminder_fee || 25;
    document.getElementById('set-show-unpaid-on-login').checked = bool('show_unpaid_on_login');
    document.getElementById('set-admin-can-view').checked = bool('admin_can_view');
    document.getElementById('set-admin-can-edit').checked = bool('admin_can_edit');
    document.getElementById('set-admin-can-cancel').checked = bool('admin_can_cancel');
    document.getElementById('set-admin-can-delete').checked = bool('admin_can_delete');
}

async function saveGlobalSettings() {
    const settings = {
        discord_enabled: document.getElementById('set-discord-enabled').checked,
        discord_webhook: document.getElementById('set-discord-webhook').value,
        tax_enabled: document.getElementById('set-tax-enabled').checked,
        default_tax_rate: document.getElementById('set-default-tax-rate').value,
        auto_invoice_numbers: document.getElementById('set-auto-invoice-numbers').checked,
        invoice_prefix: document.getElementById('set-invoice-prefix').value,
        payment_deadline_days: document.getElementById('set-payment-deadline-days').value,
        reminder_fee: document.getElementById('set-reminder-fee').value,
        show_unpaid_on_login: document.getElementById('set-show-unpaid-on-login').checked,
        admin_can_view: document.getElementById('set-admin-can-view').checked,
        admin_can_edit: document.getElementById('set-admin-can-edit').checked,
        admin_can_cancel: document.getElementById('set-admin-can-cancel').checked,
        admin_can_delete: document.getElementById('set-admin-can-delete').checked
    };

    await nuiFetch('saveGlobalSettings', settings);
    showToast('Globale Einstellungen gespeichert.', 'success');
}

// Icons nach dynamischem Laden (wird von icons.js beim Start aufgerufen)

// ESC-Taste (Dialoge zuerst schließen)
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (isDialogOpen()) {
            closeDialog(null);
            return;
        }
        if (!document.getElementById('modal-invoice').classList.contains('hidden')) {
            closeModal();
        } else if (!document.getElementById('modal-edit').classList.contains('hidden')) {
            closeEditModal();
        } else {
            closeUI();
        }
    }
});
