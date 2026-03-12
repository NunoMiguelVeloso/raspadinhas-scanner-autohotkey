#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
;  KeyLogger.ahk — Captura raw de um scan
;  Faz um scan em qualquer janela, depois Ctrl+Shift+S para ver o log
; ============================================================

global LogFile := A_ScriptDir . "\KeyLog.txt"
global Events  := []
global SessionStart := 0

if FileExist(LogFile)
    FileDelete(LogFile)

TrayTip("KeyLogger", "Pronto. Faz um scan.`nCtrl+Shift+S = Parar e ver log", 1)

OnMessage(0x0100, OnKeyDown)  ; WM_KEYDOWN
OnMessage(0x0101, OnKeyUp)    ; WM_KEYUP

^+s:: SaveAndOpen()

OnKeyDown(wParam, lParam, msg, hwnd) {
    RecordEvent("DN", wParam, lParam)
}

OnKeyUp(wParam, lParam, msg, hwnd) {
    RecordEvent("UP", wParam, lParam)
}

RecordEvent(tipo, vk, lParam) {
    global Events, SessionStart

    now := A_TickCount
    if (SessionStart == 0)
        SessionStart := now

    elapsed := now - SessionStart
    delta    := (Events.Length > 0) ? (now - Events[Events.Length].abs) : 0
    sc       := (lParam >> 16) & 0xFF

    keyName  := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
    if (keyName == "")
        keyName := Format("VK_{:02X}", vk)

    Events.Push({t: elapsed, d: delta, abs: now, tipo: tipo, nome: keyName, vk: vk, sc: sc})
}

SaveAndOpen() {
    global Events, LogFile

    out := "=== KeyLog " . FormatTime(, "dd/MM/yyyy HH:mm:ss") . " ===`r`n"
    out .= "Total eventos: " . Events.Length . "`r`n`r`n"
    out .= "Tempo    Delta  Tipo  Tecla          VK      SC`r`n"
    out .= "------------------------------------------------------`r`n"

    for ev in Events {
        out .= Format("{:6}ms {:4}ms   {:<2}   {:<14} 0x{:02X}   0x{:03X}`r`n"
            , ev.t, ev.d, ev.tipo, ev.nome, ev.vk, ev.sc)
    }

    FileAppend(out, LogFile, "UTF-8")
    TrayTip("KeyLogger", "Log guardado! A abrir...", 2)
    Sleep(500)
    Run(LogFile)
    ExitApp()
}
