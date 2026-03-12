#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
;  KeyLogger.ahk — Captura raw de um scan
;  
;  Abre qualquer editor de texto, faz um scan, e este script
;  regista todos os eventos de teclado em KeyLog.txt
;  
;  Ctrl+Shift+S = Parar e abrir o log
; ============================================================

global LogFile := A_ScriptDir . "\KeyLog.txt"
global Events := []
global SessionStart := 0

if FileExist(LogFile)
    FileDelete(LogFile)

TrayTip("KeyLogger", "Pronto. Faz um scan em qualquer janela.`nCtrl+Shift+S = Parar e ver log", 1)

OnMessage(0x0100, OnKeyMsg.Bind("DN"))  ; WM_KEYDOWN
OnMessage(0x0101, OnKeyMsg.Bind("UP"))  ; WM_KEYUP

^+s:: {
    global Events, LogFile, SessionStart
    
    out := "=== KeyLog — " . FormatTime(, "dd/MM/yyyy HH:mm:ss") . " ===`r`n"
    out .= "Total eventos: " . Events.Length . "`r`n`r`n"
    out .= Format("{:-8s} {:-6s} {:-5s} {:-12s} {:-8s} {:-8s}`r`n", "Tempo", "Delta", "Tipo", "Tecla", "VK", "SC")
    out .= "------------------------------------------------------`r`n"
    
    for ev in Events {
        out .= Format("{:>6}ms {:>4}ms  {:-4s}  {:-12s} 0x{:02X}     0x{:03X}`r`n"
            , ev.t, ev.d, ev.tipo, ev.nome, ev.vk, ev.sc)
    }
    
    FileAppend(out, LogFile, "UTF-8")
    TrayTip("KeyLogger", "Log guardado! A abrir...", 2)
    Sleep(500)
    Run(LogFile)
    ExitApp()
}

OnKeyMsg(tipo, wParam, lParam, msg, hwnd) {
    global Events, SessionStart
    
    now := A_TickCount
    if (SessionStart == 0)
        SessionStart := now
    
    elapsed := now - SessionStart
    delta := (Events.Length > 0) ? (now - Events[Events.Length].abs) : 0
    
    sc := (lParam >> 16) & 0xFF
    keyName := GetKeyName(Format("vk{:02X}sc{:03X}", wParam, sc))
    if (keyName == "")
        keyName := Format("VK_{:02X}", wParam)
    
    Events.Push({t: elapsed, d: delta, abs: now, tipo: tipo, nome: keyName, vk: wParam, sc: sc})
}
