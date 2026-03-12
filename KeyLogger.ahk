#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
;  KeyLogger.ahk — Captura raw de um scan via InputHook
;  Faz um scan em qualquer janela, depois Ctrl+Shift+S para ver o log
; ============================================================

global LogFile := A_ScriptDir . "\KeyLog.txt"
global Events  := []
global SessionStart := 0

if FileExist(LogFile)
    FileDelete(LogFile)

TrayTip("KeyLogger", "Pronto. Faz um scan.`nCtrl+Shift+S = Parar e ver log", 1)

; InputHook em modo Visible — os caracteres passam normalmente para a app
; L0 = sem limite de comprimento, B = captura backspace
ih := InputHook("V B")
ih.OnChar    := LogChar
ih.OnKeyDown := LogKeyDown
ih.Start()

; Ctrl+Shift+S para parar e ver o log
^+s:: SaveAndOpen()

LogChar(ih, char) {
    global Events, SessionStart

    now := A_TickCount
    if (SessionStart == 0)
        SessionStart := now

    elapsed := now - SessionStart
    delta    := (Events.Length > 0) ? (now - Events[Events.Length].abs) : 0

    Events.Push({t: elapsed, d: delta, abs: now, tipo: "CHAR", nome: char, vk: Ord(char), sc: 0})
}

LogKeyDown(ih, vk, sc) {
    global Events, SessionStart

    ; Ignorar teclas que já aparecem como CHAR (evitar duplicados para teclas imprimíveis)
    if (vk >= 0x30 && vk <= 0x39)  ; 0-9
        return
    if (vk >= 0x41 && vk <= 0x5A)  ; A-Z
        return

    now := A_TickCount
    if (SessionStart == 0)
        SessionStart := now

    elapsed := now - SessionStart
    delta    := (Events.Length > 0) ? (now - Events[Events.Length].abs) : 0

    keyName  := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
    if (keyName == "")
        keyName := Format("VK_{:02X}", vk)

    Events.Push({t: elapsed, d: delta, abs: now, tipo: "KEY", nome: keyName, vk: vk, sc: sc})
}

SaveAndOpen() {
    global Events, LogFile

    out := "=== KeyLog " . FormatTime(, "dd/MM/yyyy HH:mm:ss") . " ===`r`n"
    out .= "Total eventos: " . Events.Length . "`r`n`r`n"
    out .= "Tempo     Delta   Tipo   Caracter/Tecla`r`n"
    out .= "----------------------------------------------`r`n"

    for ev in Events {
        out .= Format("{:6}ms  {:4}ms   {:<4}   {}`r`n"
            , ev.t, ev.d, ev.tipo, ev.nome)
    }

    FileAppend(out, LogFile, "UTF-8")
    TrayTip("KeyLogger", "Log guardado! A abrir...", 2)
    Sleep(500)
    Run(LogFile)
    ExitApp()
}
