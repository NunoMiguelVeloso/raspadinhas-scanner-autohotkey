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

global ScanStartTime := 0  ; A_TickCount do primeiro dígito do scan atual

; DEBUG: Muda para false para desativar os tooltips de diagnóstico
global DEBUG := true

; InputHook com "V" (Visible) — os caracteres aparecem imediatamente na app (bom para digitação humana).
; Quando detetamos um scan completo, apagamos os carateres visíveis com Backspace e enviamos o resultado processado.
; O Enter é marcado como EndKey suprimido (S=Suppress, E=End) — nunca chega à app diretamente.
ih := InputHook("V")
ih.KeyOpt("{Enter}", "SE")
ih.OnEnd := OnScanComplete
ih.OnChar := OnCharFn
ih.Start()

OnCharFn(ih, char) {
    global ScanStartTime
    ; NOTA: OnChar é chamado DEPOIS do char ser adicionado ao ih.Input.
    ; Então o primeiro char faz ih.Input ter comprimento 1, não 0.
    if (StrLen(ih.Input) == 1)
        ScanStartTime := A_TickCount
}

OnScanComplete(ih) {
    global ScanStartTime, DEBUG

    collected  := ih.Input
    elapsed    := A_TickCount - ScanStartTime
    ScanStartTime := 0

    ; Reiniciar o hook imediatamente para a próxima entrada
    ih.Start()

    isScan := (StrLen(collected) == 14 && elapsed < 500)

    if (DEBUG) {
        ToolTip("SCAN: " . (isScan ? "SIM" : "NÃO")
            . "`nCódigo: [" . collected . "]"
            . "`nLen: " . StrLen(collected)
            . "`nElapsed: " . elapsed . "ms")
        SetTimer(() => ToolTip(), -3000)  ; esconder tooltip após 3s
    }

    if (isScan) {
        ; Apagar os caracteres visíveis que já foram enviados (modo V)
        SendInput("{BS " . StrLen(collected) . "}")
        ProcessCompleteScan(collected)
    } else {
        ; Não é um scan — os carateres já estão visíveis, apenas enviar o Enter
        SendInput("{Enter}")
    }
}

; Processa um scan completo — valida tamanho e prefixo
ProcessCompleteScan(barcode) {
    global RaspadinhasMap

    ; 1. Verificar tamanho esperado (14 dígitos)
    if (StrLen(barcode) != 14) {
        ; Não tem o tamanho esperado — enviar tal como foi lido + Enter
        SendInput(barcode . "{Enter}")
        return
    }

    ; 2. Verificar prefixo na lista de raspadinhas
    prefix := SubStr(barcode, 1, 3)

    if (RaspadinhasMap.Has(prefix)) {
        ; É raspadinha! Enviar apenas o código transformado
        SendInput("RASPA-" . prefix . "{Enter}")
    } else {
        ; Não é raspadinha — enviar o código de barras original + Enter
        SendInput(barcode . "{Enter}")
    }
}

