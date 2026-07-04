let dialogResolve = null;

function initProtection() {
    window.alert = function(m) { showToast(m, 'warning'); };
    window.confirm = function() { return false; };
    window.prompt = function() { return null; };
    window.open = function() { return null; };
    document.addEventListener('contextmenu', function(e) { e.preventDefault(); });
}

function showToast(message, type) {
    var c = document.getElementById('toast-container');
    var t = document.createElement('div');
    t.className = 'toast toast-' + (type || 'info');
    t.textContent = message;
    c.appendChild(t);
    requestAnimationFrame(function() { t.classList.add('show'); });
    setTimeout(function() {
        t.classList.remove('show');
        setTimeout(function() { t.remove(); }, 250);
    }, 3500);
}

function closeDialog(result) {
    document.getElementById('dialog-overlay').classList.add('hidden');
    document.getElementById('dialog-input').classList.add('hidden');
    if (dialogResolve) { var r = dialogResolve; dialogResolve = null; r(result); }
}

function openDialog(opts) {
    return new Promise(function(resolve) {
        dialogResolve = resolve;
        var overlay = document.getElementById('dialog-overlay');
        var iconEl = document.getElementById('dialog-icon');
        document.getElementById('dialog-title').textContent = opts.title || 'Hinweis';
        document.getElementById('dialog-message').textContent = opts.message || '';
        setIcon(iconEl, opts.icon || 'alert-circle', 24);
        var input = document.getElementById('dialog-input');
        var actions = document.getElementById('dialog-actions');
        actions.innerHTML = '';

        if (opts.prompt) {
            input.classList.remove('hidden');
            input.value = opts.defaultValue || '';
            input.placeholder = opts.placeholder || '';
        } else {
            input.classList.add('hidden');
        }

        if (opts.confirmOnly) {
            var ok = document.createElement('button');
            ok.className = 'btn btn-primary';
            ok.textContent = 'OK';
            ok.onclick = function() { closeDialog(true); };
            actions.appendChild(ok);
        } else if (opts.prompt) {
            var cancel = document.createElement('button');
            cancel.className = 'btn btn-ghost';
            cancel.textContent = 'Abbrechen';
            cancel.onclick = function() { closeDialog(null); };
            var confirm = document.createElement('button');
            confirm.className = 'btn btn-primary';
            confirm.textContent = 'Bestätigen';
            confirm.onclick = function() { closeDialog(input.value); };
            actions.append(cancel, confirm);
        } else {
            var c2 = document.createElement('button');
            c2.className = 'btn btn-ghost';
            c2.textContent = 'Abbrechen';
            c2.onclick = function() { closeDialog(false); };
            var c3 = document.createElement('button');
            c3.className = opts.danger ? 'btn btn-danger' : 'btn btn-primary';
            c3.textContent = opts.confirmText || 'Bestätigen';
            c3.onclick = function() { closeDialog(true); };
            actions.append(c2, c3);
        }

        overlay.classList.remove('hidden');
        if (opts.prompt) setTimeout(function() { input.focus(); }, 50);
    });
}

function showConfirm(message, opts) {
    opts = opts || {};
    return openDialog({ title: opts.title || 'Bestätigung', message: message, danger: opts.danger, confirmText: opts.confirmText, icon: opts.danger ? 'trash' : 'alert-circle' });
}

function showPrompt(message, def, opts) {
    opts = opts || {};
    return openDialog({ title: opts.title || 'Eingabe', message: message, prompt: true, defaultValue: def, placeholder: opts.placeholder, icon: 'edit' });
}

function isDialogOpen() {
    return !document.getElementById('dialog-overlay').classList.contains('hidden');
}

initProtection();
