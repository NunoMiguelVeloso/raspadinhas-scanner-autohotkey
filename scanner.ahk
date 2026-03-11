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
global ScanMode := false  ; true quando estamos a acumular dígitos rápidos (provável scan)

; InputHook SEM "V" — os caracteres físicos são suprimidos e NÃO chegam à aplicação.
; Somos nós que decidimos o que enviar. Isto elimina qualquer necessidade de backspaces ou seleção.
ih := InputHook("")
ih.OnChar := OnCharFn
ih.OnKeyDown := OnKeyDownFn
ih.Start()

OnCharFn(ih, char) {
    global BarcodeBuf, LastCharTime, ScanMode

    now := A_TickCount
    timeSinceLast := now - LastCharTime
    LastCharTime := now

    if IsDigit(char) {
        ; Se passou demasiado tempo desde o último caracter, era digitação humana
        if (BarcodeBuf != "" && timeSinceLast > 85) {
            FlushBuffer()
        }

        ; Adicionar dígito ao buffer
        BarcodeBuf .= char
        ScanMode := (BarcodeBuf != "" && (timeSinceLast < 85 || StrLen(BarcodeBuf) == 1))

        ; Se não vierem mais caracteres rápidos em 100ms, enviar o buffer (é digitação humana)
        SetTimer(FlushBuffer, -100)
    } else {
        ; Caracter não numérico (exceto Enter que é tratado em OnKeyDownFn)
        FlushBuffer()
        SendInput(char)
    }
}

OnKeyDownFn(ih, vk, sc) {
    global BarcodeBuf, LastCharTime, ScanMode

    ; VK 0x0D = Enter / NumpadEnter
    if (vk != 0x0D)
        return

    now := A_TickCount
    timeSinceLast := now - LastCharTime

    ; Se temos um buffer e o Enter veio rápido — é o fim de um scan
    if (BarcodeBuf != "" && ScanMode && timeSinceLast < 85) {
        SetTimer(FlushBuffer, 0)  ; cancelar timer de flush

        ProcessCompleteScan(BarcodeBuf)

        BarcodeBuf := ""
        ScanMode := false
        return  ; absorver o Enter do scanner
    }

    ; Se não é scan — enviar buffer acumulado + o Enter normalmente
    FlushBuffer()
    ScanMode := false
    SendInput("{Enter}")
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
        TrayTip("Raspadinha Identificada", "Código " . prefix . " detetado e substituído.", 1)
    } else {
        ; Não é raspadinha — enviar o código de barras original + Enter
        SendInput(barcode . "{Enter}")
    }
}

; Envia os dígitos acumulados no buffer para a aplicação (digitação humana)
FlushBuffer() {
    global BarcodeBuf, ScanMode
    SetTimer(FlushBuffer, 0)  ; cancelar timer pendente
    if (BarcodeBuf != "") {
        SendInput(BarcodeBuf)
        BarcodeBuf := ""
    }
    ScanMode := false
}

