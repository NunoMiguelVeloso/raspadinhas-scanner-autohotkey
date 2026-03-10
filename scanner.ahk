#Requires AutoHotkey v2.0
#SingleInstance Force

; Configurações
global GitHubUrl := "https://raw.githubusercontent.com/NunoMiguelVeloso/raspadinhas-scanner-autohotkey/main/raspadinhas.txt"
global RaspadinhasMap := Map()

; Configurar Menu da Tray (Opção Manual para os Tablets)
A_TrayMenu.Add()  ; Adiciona um separador
A_TrayMenu.Add("Atualizar Lista Agora", AtualizarListaManual)

; Fazer a primeira atualização ao iniciar o script
AtualizarLista(true)

; Configurar a execução automática a cada 2 horas (7200000 ms)
SetTimer(AtualizarListaAuto, 7200000)

AtualizarListaManual(ItemName, ItemPos, MyMenu) {
    AtualizarLista(false)
}

AtualizarListaAuto() {
    AtualizarLista(false)
}

AtualizarLista(isStartup) {
    global RaspadinhasMap, GitHubUrl
    try {
        ; Create a COM object to make the HTTP request
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", GitHubUrl, true)
        req.Send()
        req.WaitForResponse()
        text := req.ResponseText
        
        ; Map temporário para evitar limpar códigos válidos se o ficheiro estiver corrompido
        tempMap := Map()
        
        ; Read the downloaded text line by line
        Loop Parse, text, "`n", "`r" {
            val := RegExReplace(A_LoopField, "\D", "")
            if (StrLen(val) == 3) {
                tempMap[val] := true
            }
        }
        
        ; Atualizar o map global de forma atómica
        RaspadinhasMap := tempMap
        
        ; Mostrar notificação se foi uma atualização manual ou erro
        if (!isStartup) {
            TrayTip("Lista Atualizada", "Foram carregados " RaspadinhasMap.Count " códigos de raspadinhas.", 2)
        }
    } catch as err {
        if (isStartup) {
            MsgBox("Aviso: Não foi possível transferir a lista do GitHub. Verifique a ligação à internet e o URL.`n`nErro: " err.Message, "Erro", 16)
            ExitApp()
        } else {
            ; Apenas falha silenciosamente ou avisa no background se não for no arranque
            TrayTip("Erro de Atualização", "Não foi possível atualizar a lista de raspadinhas. A usar a lista antiga.`n" err.Message, 3)
        }
    }
}

global BarcodeBuf := ""
global LastCharTime := 0
global IgnoreNextEnter := false

; Create a visible InputHook. "V" means keystrokes are passed to the active window normally.
ih := InputHook("V")
ih.OnChar := OnCharFn
ih.Start()

OnCharFn(ih, char) {
    global BarcodeBuf, LastCharTime
    
    ; Barcode scanners send keystrokes extremely quickly (usually 5-20ms per character).
    ; Se o tempo desde a última tecla for maior que 85ms, provavelmente é digitação humana.
    ; Tolerância aumentada para evitar falhas com leitores de código de barras mais lentos.
    if (A_TickCount - LastCharTime > 85) {
        BarcodeBuf := ""
    }
    LastCharTime := A_TickCount
    
    ; Only append digits to our buffer
    if IsDigit(char) {
        BarcodeBuf .= char
        
        ; When exactly 14 rapidly typed digits are detected
        if (StrLen(BarcodeBuf) == 14) {
            
            ; Get the first 3 digits (slicing all digits after position 3)
            prefix := SubStr(BarcodeBuf, 1, 3)
            
            ; Check if the 3 digits belong to our list
            if (RaspadinhasMap.Has(prefix)) {
                
                ; Enable a flag to absorb the natural Enter keystroke from the scanner
                global IgnoreNextEnter := true
                SetTimer(ClearIgnoreEnter, -500) ; disable flag after 500ms
                
                ; To replace the barcode:
                ; We erase the 14 characters that the scanner just naturally typed
                SendInput("{Backspace 14}")
                ; Envia os 3 dígitos correspondentes e o Enter de forma explícita
                SendEvent("RASPA-" . prefix . "{Enter}")
                
                ; Show a push notification (TrayTip)
                TrayTip("Raspadinha Identificada", "Código " prefix " detetado e substituído.", 1)
            }
            ; If it doesn't match, we do nothing. The "V" InputHook naturally allows
            ; the original barcode to stay as it was typed.
            
            ; Reset buffer after a successful 14-digit detection
            BarcodeBuf := "" 
        }
    } else {
        ; Reset the buffer if a non-digit is typed (e.g. letters)
        BarcodeBuf := ""
    }
}

ClearIgnoreEnter() {
    global IgnoreNextEnter := false
}

#HotIf IgnoreNextEnter
$Enter::
$NumpadEnter::
{
    global IgnoreNextEnter := false
    ; Absorve o Enter físico do leitor para evitar duplicação do Enter
}
#HotIf
