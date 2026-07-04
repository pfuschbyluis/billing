Locales = Locales or {}

Locales['de'] = {
    -- Allgemein
    no_permission = 'Keine Berechtigung.',
    invoice_created = 'Rechnung %s erfolgreich erstellt.',
    invoice_paid = 'Rechnung %s bezahlt.',
    invoice_rejected = 'Rechnung %s abgelehnt.',
    invoice_rejected_notify = 'Deine Rechnung %s wurde von %s abgelehnt: %s',
    open_invoices_login = 'Du hast %d offene Rechnung(en). Drücke F7 zum Öffnen.',

    -- Erstellen
    cannot_issue = 'Dein Job "%s" ist nicht freigeschaltet.',
    cannot_issue_admin = ' Ein Admin muss ihn im Rechnungs-Adminpanel unter Jobs aktivieren.',
    cannot_issue_config = ' Bitte Config.InvoiceJobs oder Blacklist prüfen.',
    grade_too_low = 'Dein Rang (%d) reicht nicht aus. Mindestens Rang %d erforderlich.',
    job_blacklisted = 'Dein Job "%s" ist für das Rechnungssystem gesperrt.',
    invalid_amount = 'Ungültiger Rechnungsbetrag.',
    max_amount = 'Der Betrag überschreitet das Maximum von %s€.',
    max_items = 'Maximal %d Positionen pro Rechnung erlaubt.',
    note_too_long = 'Notizen dürfen maximal %d Zeichen lang sein.',
    recipient_too_far = 'Der Empfänger ist zu weit entfernt (max. %.1fm).',
    signature_required = 'Bitte unterschreibe die Rechnung.',

    -- UI
    ui_overview = 'ÜBERSICHT',
    ui_statistics = 'STATISTIK',
    ui_templates = 'VORLAGEN',
    ui_create = 'RECHNUNG ERSTELLEN',
    ui_view = 'ANSEHEN',
    ui_reject = 'ABLEHNEN',
    ui_pay = 'BEZAHLEN',
    status_open = 'OFFEN',
    status_paid = 'BEZAHLT',
    status_overdue = 'ÜBERFÄLLIG',
    status_cancelled = 'STORNIERT',
    status_rejected = 'ABGELEHNT',

    -- Erinnerung
    reminder_before_due = 'Rechnung %s ist in %d Tag(en) fällig (%s€).',
    reminder_overdue = 'Rechnung %s ist überfällig! Offener Betrag: %s€',
}
