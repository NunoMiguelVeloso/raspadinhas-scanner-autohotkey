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

global LastCharTime := 0

; InputHook SEM "V" — os caracteres NÃO chegam à aplicação enquanto estamos a capturar.
; Termina quando o leitor envia Enter. Timeout de 2s para segurança.
ih := InputHook("T2")
ih.KeyOpt("{Enter}{NumpadEnter}", "E")  ; Enter termina o input
ih.OnChar := OnCharFn
ih.OnEnd := OnEndFn
ih.Start()

OnCharFn(ih, char) {
    global LastCharTime
    
    ; Se passou mais de 85ms desde o último caracter, é digitação humana → repassar e reiniciar.
    if (A_TickCount - LastCharTime > 85) {
        ; Reenviar os caracteres acumulados até agora (que eram digitação humana)
        buffered := ih.Input
        ih.Stop()
        ih.Start()
        if (buffered != "")
            SendText(buffered)
        SendText(char)
        LastCharTime := A_TickCount
        return
    }
    LastCharTime := A_TickCount
}

OnEndFn(ih) {
    captured := ih.Input
    reason   := ih.EndReason
    
    ; Reiniciar o hook imediatamente para não perder inputs seguintes
    ih.Start()
    
    ; Só processar se terminou via Enter e tem exatamente 14 dígitos
    if (reason != "EndKey" || !RegExMatch(captured, "^\d{14}$")) {
        ; Não é um código de barras — repassar o texto original e o Enter
        if (captured != "")
            SendText(captured)
        Send("{Enter}")
        return
    }
    
    ; Extrair os primeiros 3 dígitos e verificar na lista
    prefix := SubStr(captured, 1, 3)
    if (RaspadinhasMap.Has(prefix)) {
        ; Código reconhecido → enviar "RASPA-" + prefixo + Enter
        SendText("RASPA-" . prefix)
        Send("{Enter}")
        TrayTip("Raspadinha Identificada", "Código " . prefix . " detetado e substituído.", 1)
    } else {
        ; Código não reconhecido → repassar o código original e o Enter
        SendText(captured)
        Send("{Enter}")
    }
}
