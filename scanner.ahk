#Requires AutoHotkey v2.0
#SingleInstance Force

; --- Configurações ---
global GitHubUrl  := "https://raw.githubusercontent.com/NunoMiguelVeloso/raspadinhas-scanner-autohotkey/main/raspadinhas.txt"
global CacheFile  := A_ScriptDir . "\raspadinhas_cache.txt"
global PrefixLength := 3
global RaspadinhasMap := Map()

; --- Menu da Tray ---
A_TrayMenu.Add()  ; Separador visual
A_TrayMenu.Add("Ver Estado da Lista", MostrarEstado)
A_TrayMenu.Add("Atualizar Lista Agora", AtualizarListaManual)

MostrarEstado(ItemName, ItemPos, MyMenu) {
    global RaspadinhasMap, CacheFile
    
    if FileExist(CacheFile) {
        time := FileGetTime(CacheFile, "M") ; Tempo de modificação
        cacheStatus := "Sim (" . FileGetSize(CacheFile) . " bytes, atualizado a " . FormatTime(time, "dd/MM/yyyy HH:mm") . ")"
    } else {
        cacheStatus := "Não existe"
    }
    
    msg := "ESTADO DO SCANNER`n`n"
    msg .= "Códigos em memória: " . RaspadinhasMap.Count . "`n"
    msg .= "Cache local: " . cacheStatus
    
    MsgBox(msg, "Estado do Scanner", 64)
}

; --- Arranque e Atualização Automática ---
AtualizarLista(true)  ; Atualização inicial no arranque (silenciosa se sucesso)
SetTimer(AtualizarListaAuto, 600000)  ; 10 minutos (600000 ms)

AtualizarListaManual(ItemName, ItemPos, MyMenu) {
    AtualizarLista(false)
}

AtualizarListaAuto() {
    AtualizarLista(true) ; Auto updates também devem ser silenciosos (tratados como startup)
}

; --- Lógica de Download e Cache ---
ParseLista(text) {
    global PrefixLength
    m := Map()
    Loop Parse, text, "`n", "`r" {
        val := RegExReplace(A_LoopField, "\D", "")
        if (StrLen(val) == PrefixLength)
            m[val] := true
    }
    return m
}

AtualizarLista(isSilent) {
    global RaspadinhasMap, GitHubUrl, CacheFile

    maxTentativas := 3
    pausaEntreTentativas := 2000
    timeoutMs := 10000
    lastErr := ""

    if (!isSilent)
        TrayTip("Atualização", "A transferir lista do GitHub...", 1)

    Loop maxTentativas {
        tentativa := A_Index
        try {
            req := ComObject("WinHttp.WinHttpRequest.5.1")
            req.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
            req.Open("GET", GitHubUrl, false) ; Síncrono
            req.Send()
            
            if (req.Status != 200)
                throw Error("HTTP " . req.Status . " " . req.StatusText)

            tempMap := ParseLista(req.ResponseText)

            if (tempMap.Count == 0)
                throw Error("Lista vazia ou inválida.")

            ; Guardar num ficheiro local para uso offline futuro
            try {
                if FileExist(CacheFile)
                    FileDelete(CacheFile)
                FileAppend(req.ResponseText, CacheFile, "UTF-8")
            } catch {
                ; Ignorar erros de escrita no cache para não falhar a atualização em memória
            }

            RaspadinhasMap := tempMap

            if (!isSilent)
                TrayTip("Lista Atualizada", "Carregados " . RaspadinhasMap.Count . " códigos (GitHub).", 2)

            return ; Sucesso — sair da função
        } catch as err {
            lastErr := err.Message
            if (tentativa < maxTentativas)
                Sleep(pausaEntreTentativas)
        }
    }

    ; --- Fallback: Se todas as tentativas de rede falharem ---
    if (FileExist(CacheFile)) {
        cached := FileRead(CacheFile, "UTF-8")
        RaspadinhasMap := ParseLista(cached)
        
        if (!isSilent)
            TrayTip("Atualização Falhou", "Sem rede. A usar cache local (" . RaspadinhasMap.Count . " códigos).`n`nErro original: " . lastErr, 3)
    } else {
        RaspadinhasMap := Map()
        TrayTip("ALERTA CRÍTICO", "Falha de rede e sem cache local. O scanner não tem a lista de raspadinhas.`n`nErro: " . lastErr, 3)
    }
}

; --- Scanner (InputHook) ---
global ScanStartTime := 0

; Modo "V" (Visible): caracteres passam para a app normalmente (digitação humana imediata)
; Quando um scan de 10 dígitos é detetado, apagamos os 10 visíveis (Backspace) e injetamos o código processado.
ih := InputHook("V")
ih.KeyOpt("{Enter}", "SE") ; Enter funciona como demilitador suprimido (nunca é enviado diretamente)
ih.OnEnd := OnScanComplete
ih.OnChar := OnCharFn
ih.Start()

OnCharFn(ih, char) {
    global ScanStartTime
    ; Registar a hora inicial (OnChar corre depois de a tecla entrar no buffer)
    if (StrLen(ih.Input) == 1)
        ScanStartTime := A_TickCount
}

OnScanComplete(ih) {
    global ScanStartTime

    collected  := ih.Input
    elapsed    := A_TickCount - ScanStartTime
    ScanStartTime := 0

    ; Reinicia imediatamente para a próxima leitura
    ih.Start()

    ; Um leitor de código de barras envia os 10 números sem letras num tempo incrivelmente rápido (< 500ms)
    isScan := (StrLen(collected) == 10 && elapsed < 500 && RegExMatch(collected, "^\d+$"))

    if (isScan) {
        ; Apagar da app os 10 caracteres que apareceram visíveis pelo modo "V"
        SendInput("{BS " . StrLen(collected) . "}")
        ProcessCompleteScan(collected)
    } else {
        ; Entrada manual finalizada. Os caracteres já estão visíveis na app, precisamos apenas do Enter que foi suprimido.
        SendInput("{Enter}")
    }
}

ProcessCompleteScan(barcode) {
    global RaspadinhasMap

    global PrefixLength

    ; Segurança passiva - confirmar o tamanho
    if (StrLen(barcode) != 10) {
        SendInput(barcode . "{Enter}")
        return
    }

    prefix := SubStr(barcode, 1, PrefixLength)
    hasPrefix := RaspadinhasMap.Has(prefix)

    if (hasPrefix) {
        ; Confirmação sonora audível de sucesso (breve e aguda) - estilo caixa de supermercado
        SoundBeep(1200, 50) 
        SendInput("RASPA-" . prefix . "{Enter}")
    } else {
        SendInput(barcode . "{Enter}")
    }
}
