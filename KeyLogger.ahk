#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
;  KeyLogger.ahk — Captura e comparação de eventos de teclado
;
;  MODO 1 (padrão): Captura raw do scanner
;    → Faz um scan, depois Ctrl+Shift+S para ver o log
;
;  MODO 2: Simula o output do RaspaScanner e também captura
;    → Ctrl+Shift+T injeta "RASPA-606{Enter}" via SendInput
;      enquanto o hook está ativo (vês o que o Moloni recebe)
;
;  MODO 3: Injeta com delay por char para mimetizar scanner
;    → Ctrl+Shift+Y injeta com timing idêntico ao scanner real
;
; ============================================================

global LogFile      := A_ScriptDir . "\KeyLog.txt"
global Events       := []
global SessionStart := 0
global RaspaCode    := "RASPA-606"   ; ← altera aqui o prefixo a testar

if FileExist(LogFile)
    FileDelete(LogFile)

TrayTip("KeyLogger", "Pronto. Faz um scan.`n"
    . "Ctrl+Shift+S = Guardar log`n"
    . "Ctrl+Shift+C = Limpar log`n"
    . "Ctrl+Shift+T = Testar SendInput rápido`n"
    . "Ctrl+Shift+Y = Testar SendInput com delay (mimicando scanner)", 1)

; InputHook em modo Visible — os caracteres passam normalmente para a app
ih := InputHook("V B")
ih.OnChar    := LogChar
ih.OnKeyDown := LogKeyDown
ih.Start()

; ── Hotkeys ────────────────────────────────────────────────
^+s:: SaveAndOpen()
^+c:: ClearLog()

^+t:: {   ; SendInput rápido (como o RaspaScanner faz atualmente)
    global RaspaCode, Events
    AddMarker("── INICIO SendInput RÁPIDO (" . RaspaCode . ") ──")
    SendInput(RaspaCode . "{Enter}")
    Sleep(200)
    AddMarker("── FIM SendInput RÁPIDO ──")
}

^+y:: {   ; SendInput com delay entre chars (mimicando scanner real ~16ms/char)
    global RaspaCode, Events
    AddMarker("── INICIO SendInput COM DELAY (" . RaspaCode . ") ──")
    for i, ch in StrSplit(RaspaCode) {
        SendInput(ch)
        Sleep(8)   ; ~8ms por char → pares chegam a ~16ms como no scanner
    }
    SendInput("{Enter}")
    Sleep(200)
    AddMarker("── FIM SendInput COM DELAY ──")
}

; ── Callbacks do InputHook ─────────────────────────────────
LogChar(ih, char) {
    global Events, SessionStart

    now := A_TickCount
    if (SessionStart == 0)
        SessionStart := now

    elapsed := now - SessionStart
    delta    := (Events.Length > 0) ? (now - Events[Events.Length].abs) : 0

    ; Representação legível do char
    repr := char
    if (Ord(char) == 13)
        repr := "[ENTER/CR]"
    else if (Ord(char) == 10)
        repr := "[LF]"
    else if (Ord(char) == 8)
        repr := "[BACKSPACE]"

    Events.Push({t: elapsed, d: delta, abs: now, tipo: "CHAR", nome: repr})
}

LogKeyDown(ih, vk, sc) {
    global Events, SessionStart

    ; Capturar apenas teclas especiais (Enter, BS, Tab, etc.)
    ; Ignorar imprimíveis — já aparecem como CHAR
    if (vk >= 0x20 && vk <= 0x7E)
        return

    now := A_TickCount
    if (SessionStart == 0)
        SessionStart := now

    elapsed := now - SessionStart
    delta    := (Events.Length > 0) ? (now - Events[Events.Length].abs) : 0

    keyName  := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
    if (keyName == "")
        keyName := Format("VK_0x{:02X}", vk)

    Events.Push({t: elapsed, d: delta, abs: now, tipo: "KEY", nome: keyName})
}

; ── Funções de log ─────────────────────────────────────────
AddMarker(text) {
    global Events, SessionStart

    now := A_TickCount
    if (SessionStart == 0)
        SessionStart := now

    elapsed := now - SessionStart
    Events.Push({t: elapsed, d: 0, abs: now, tipo: "──", nome: text})
}

ClearLog() {
    global Events, SessionStart, LogFile
    Events       := []
    SessionStart := 0
    if FileExist(LogFile)
        FileDelete(LogFile)
    TrayTip("KeyLogger", "Log limpo. Pronto para novo scan.", 1)
}

SaveAndOpen() {
    global Events, LogFile

    out := "=== KeyLog " . FormatTime(, "dd/MM/yyyy HH:mm:ss") . " ===" . "`r`n"
    out .= "Total eventos: " . Events.Length . "`r`n`r`n"
    out .= "Tempo(ms)  Delta(ms)  Tipo   Caracter / Tecla`r`n"
    out .= "----------------------------------------------------`r`n"

    for ev in Events {
        tStr    := Format("{:>7}", ev.t) . "ms"
        dStr    := Format("{:>6}", ev.d) . "ms"
        tipoStr := Format("{:<6}", ev.tipo)
        out .= tStr . "  " . dStr . "  " . tipoStr . "  " . ev.nome . "`r`n"
    }

    FileAppend(out, LogFile, "UTF-8")
    TrayTip("KeyLogger", "Log guardado! A abrir...", 2)
    Sleep(500)
    Run(LogFile)
}
