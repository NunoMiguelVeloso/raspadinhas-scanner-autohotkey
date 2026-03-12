#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
;  KeyLogger.ahk — V3 (Fixed Format + LF Test)
; ============================================================

global LogFile      := A_ScriptDir . "\KeyLog.txt"
global Events       := []
global SessionStart := 0
global RaspaCode    := "RASPA-606"

if FileExist(LogFile)
    FileDelete(LogFile)

TrayTip("KeyLogger", "Ctrl+Shift+S = Ver Log`nCtrl+Shift+T = Testar COM LF`nCtrl+Shift+R = Testar COM Enter (CR)", 1)

ih := InputHook("V B")
ih.OnChar    := (ih, char) => Record("CHAR", char, Ord(char))
ih.OnKeyDown := (ih, vk, sc) => (vk < 0x20 || vk > 0x7E) ? Record("KEY", GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc)), vk) : 0
ih.Start()

^+s:: SaveAndOpen()
^+c:: (global Events := [], SessionStart := 0, TrayTip("Limpo","",""))

^+t:: { ; Testar com LF (`n)
    AddMarker("INICIO TESTE LF (`n)")
    SendInput(RaspaCode . "`n")
    AddMarker("FIM TESTE LF")
}

^+r:: { ; Testar com ENTER ({Enter} = `r)
    AddMarker("INICIO TESTE ENTER (`r)")
    SendInput(RaspaCode . "{Enter}")
    AddMarker("FIM TESTE ENTER")
}

Record(tipo, nome, val) {
    global Events, SessionStart
    now := A_TickCount
    if (SessionStart == 0)
        SessionStart := now
    
    ; Traduzir teclas invisíveis
    if (tipo == "CHAR") {
        if (val == 10) nome := "[LF/LineFeed]"
        else if (val == 13) nome := "[CR/Enter]"
        else if (val == 8) nome := "[BS]"
        else if (val == 9) nome := "[TAB]"
    }
    
    Events.Push({t: now - SessionStart, d: (Events.Length ? now - Events[Events.Length].abs : 0), abs: now, tipo: tipo, nome: nome})
}

AddMarker(msg) => Events.Push({t: A_TickCount - SessionStart, d: 0, abs: A_TickCount, tipo: "---", nome: msg})

SaveAndOpen() {
    global Events, LogFile
    out := "=== KeyLog " . FormatTime(, "HH:mm:ss") . " ===`r`n`r`n"
    out .= "Tempo      Delta     Tipo     Data`r`n"
    out .= "--------------------------------------`r`n"
    for ev in Events {
        ; Use implicit concatenation or simple Format for AHK v2
        tStr := ev.t . "ms"
        dStr := ev.d . "ms"
        out .= Format("{1,-10} {2,-9} {3,-8} {4}`r`n", tStr, dStr, ev.tipo, ev.nome)
    }
    FileAppend(out, LogFile, "UTF-8")
    Run(LogFile)
}
