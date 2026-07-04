/**
 * ESX Rechnungssystem - Ingame-Dialoge
 * Ersetzt alert(), confirm() und prompt() – alles bleibt im Spiel-Overlay
 */

let activeDialogResolver = null;

/**
 * Initialisiert Schutz gegen externe Browser-Fenster
 */
function initNuiProtection() {
    // System-Dialoge blockieren (Fallback)
    window.alert = (msg) => { showToast(msg, 'warning'); };
    window.confirm = () => false;
    window.prompt = () => null;
    window.open = () => null;

    // Rechtsklick und externe Links verhindern
    document.addEventListener('contextmenu', (e) => e.preventDefault());
    document.addEventListener('click', (e) => {
        const link = e.target.closest('a');
        if (link) {
            e.preventDefault();
        }
    }, true);

    // Drag & Drop blockieren
    document.addEventListener('dragstart', (e) => e.preventDefault());
}

/**
 * Zeigt eine Toast-Benachrichtigung im Spiel
 * @param {string} message
 * @param {'info'|'success'|'warning'|'error'} type
 */
function showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;

    const iconMap = {
        info: 'file-text',
        success: 'check-circle',
        warning: 'alert-circle',
        error: 'x'
    };

    toast.innerHTML = `
        <span class="toast-icon">${icon(iconMap[type] || 'file-text', 18)}</span>
        <span class="toast-text">${message}</span>
    `;

    container.appendChild(toast);

    requestAnimationFrame(() => toast.classList.add('show'));

    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => toast.remove(), 250);
    }, 3500);
}

/**
 * Schließt den aktiven Dialog
 * @param {any} result
 */
function closeDialog(result) {
    const overlay = document.getElementById('dialog-overlay');
    overlay.classList.add('hidden');

    const input = document.getElementById('dialog-input');
    input.classList.add('hidden');
    input.value = '';

    if (activeDialogResolver) {
        const resolver = activeDialogResolver;
        activeDialogResolver = null;
        resolver(result);
    }
}

/**
 * Öffnet einen Ingame-Dialog
 * @param {object} options
 * @returns {Promise<any>}
 */
function openDialog(options) {
    return new Promise((resolve) => {
        if (activeDialogResolver) {
            closeDialog(null);
        }

        activeDialogResolver = resolve;

        const overlay = document.getElementById('dialog-overlay');
        const iconWrap = document.getElementById('dialog-icon-wrap');
        const title = document.getElementById('dialog-title');
        const message = document.getElementById('dialog-message');
        const input = document.getElementById('dialog-input');
        const actions = document.getElementById('dialog-actions');

        const type = options.type || 'info';
        const iconMap = {
            info: 'file-text',
            success: 'check-circle',
            warning: 'alert-circle',
            danger: 'trash',
            prompt: 'edit'
        };

        iconWrap.innerHTML = icon(iconMap[type] || 'file-text', 28);
        iconWrap.className = `dialog-icon-wrap dialog-type-${type}`;
        title.textContent = options.title || 'Hinweis';
        message.textContent = options.message || '';

        if (options.prompt) {
            input.classList.remove('hidden');
            input.value = options.defaultValue || '';
            input.placeholder = options.placeholder || '';
            setTimeout(() => input.focus(), 50);
        } else {
            input.classList.add('hidden');
        }

        actions.innerHTML = '';

        if (options.confirmOnly) {
            const okBtn = document.createElement('button');
            okBtn.className = 'btn btn-primary';
            okBtn.innerHTML = `${icon('check-circle', 16)} OK`;
            okBtn.onclick = () => closeDialog(true);
            actions.appendChild(okBtn);
        } else if (options.prompt) {
            const cancelBtn = document.createElement('button');
            cancelBtn.className = 'btn btn-secondary';
            cancelBtn.innerHTML = `${icon('x', 16)} Abbrechen`;
            cancelBtn.onclick = () => closeDialog(null);

            const okBtn = document.createElement('button');
            okBtn.className = 'btn btn-primary';
            okBtn.innerHTML = `${icon('check-circle', 16)} Bestätigen`;
            okBtn.onclick = () => closeDialog(input.value);

            input.onkeydown = (e) => {
                if (e.key === 'Enter') closeDialog(input.value);
                if (e.key === 'Escape') closeDialog(null);
            };

            actions.appendChild(cancelBtn);
            actions.appendChild(okBtn);
        } else {
            const cancelBtn = document.createElement('button');
            cancelBtn.className = 'btn btn-secondary';
            cancelBtn.innerHTML = `${icon('x', 16)} Abbrechen`;
            cancelBtn.onclick = () => closeDialog(false);

            const confirmBtn = document.createElement('button');
            confirmBtn.className = options.danger ? 'btn btn-danger' : 'btn btn-primary';
            confirmBtn.innerHTML = `${icon(options.danger ? 'trash' : 'check-circle', 16)} ${options.confirmText || 'Bestätigen'}`;
            confirmBtn.onclick = () => closeDialog(true);

            actions.appendChild(cancelBtn);
            actions.appendChild(confirmBtn);
        }

        overlay.classList.remove('hidden');
    });
}

/** Einfacher Hinweis */
function showAlert(message, title = 'Hinweis') {
    return openDialog({ title, message, type: 'warning', confirmOnly: true });
}

/** Bestätigungsdialog */
function showConfirm(message, options = {}) {
    return openDialog({
        title: options.title || 'Bestätigung',
        message,
        type: options.danger ? 'danger' : 'warning',
        danger: options.danger || false,
        confirmText: options.confirmText || 'Bestätigen'
    });
}

/** Eingabe-Dialog */
function showPrompt(message, defaultValue = '', options = {}) {
    return openDialog({
        title: options.title || 'Eingabe',
        message,
        type: 'prompt',
        prompt: true,
        defaultValue,
        placeholder: options.placeholder || ''
    });
}

/** Prüft ob ein Dialog offen ist */
function isDialogOpen() {
    return !document.getElementById('dialog-overlay').classList.contains('hidden');
}

initNuiProtection();
