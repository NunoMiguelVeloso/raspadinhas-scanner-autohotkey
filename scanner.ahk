#Requires AutoHotkey v2.0
#SingleInstance Force

; Configurações
global GitHubUrl  := "https://raw.githubusercontent.com/NunoMiguelVeloso/raspadinhas-scanner-autohotkey/main/raspadinhas.txt"
global CacheFile  := A_ScriptDir . "\raspadinhas_cache.txt"
global RaspadinhasMap := Map()

; Configurar Menu da Tray (Opção Manual para os Tablets)
A_TrayMenu.Add()  ; Adiciona um separador
A_TrayMenu.Add("Atualizar Lista Agora", AtualizarListaManual)

; Fazer a primeira atualização ao iniciar o script
AtualizarLista(true)

; Configurar a execução automática a cada 10 minutos (600000 ms)
SetTimer(AtualizarListaAuto, 600000)

AtualizarListaManual(ItemName, ItemPos, MyMenu) {
    AtualizarLista(false)
}

AtualizarListaAuto() {
    AtualizarLista(false)
}

; Converte texto da lista para um Map de prefixos
ParseLista(text) {
    m := Map()
    Loop Parse, text, "`n", "`r" {
        val := RegExReplace(A_LoopField, "\D", "")
        if (StrLen(val) == 3)
            m[val] := true
    }
    return m
}

AtualizarLista(isStartup) {
    global RaspadinhasMap, GitHubUrl, CacheFile

    maxTentativas := 3          ; número de tentativas
    pausaEntreTentativas := 3000 ; ms entre tentativas
    timeoutMs := 5000           ; timeout de ligação/envio/resposta

    Loop maxTentativas {
        tentativa := A_Index
        try {
            ; Tentar descarregar do GitHub com timeout
            req := ComObject("WinHttp.WinHttpRequest.5.1")
            req.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
            req.Open("GET", GitHubUrl, true)
            req.Send()
            req.WaitForResponse()
            text := req.ResponseText

            tempMap := ParseLista(text)

            ; Só aceitar se veio conteúdo válido (evita sobrescrever com lista corrompida)
            if (tempMap.Count == 0)
                throw Error("Lista vazia ou inválida recebida do GitHub.")

            ; Guardar cache local para uso offline futuro
            FileDelete(CacheFile)
            FileAppend(text, CacheFile, "UTF-8")

            RaspadinhasMap := tempMap

            if (!isStartup)
                TrayTip("Lista Atualizada", "Carregados " . RaspadinhasMap.Count . " códigos (GitHub).", 2)

            return  ; sucesso — sair da função
        } catch as err {
            ; Falhou esta tentativa — esperar antes de tentar outra vez (exceto na última)
            if (tentativa < maxTentativas)
                Sleep(pausaEntreTentativas)
        }
    }

    ; Todas as tentativas falharam — tentar carregar do cache local
    if (FileExist(CacheFile)) {
        cached := FileRead(CacheFile, "UTF-8")
        RaspadinhasMap := ParseLista(cached)
        if (isStartup)
            TrayTip("Modo Offline", "Sem ligação ao GitHub. A usar cache local (" . RaspadinhasMap.Count . " códigos).", 3)
        else
            TrayTip("Erro de Atualização", "A usar cache local (" . RaspadinhasMap.Count . " códigos).", 3)
    } else {
        ; Sem cache e sem rede — arrancar com lista vazia (script continua a funcionar)
        RaspadinhasMap := Map()
        if (isStartup)
            TrayTip("Aviso", "Sem ligação e sem cache local. A arrancar sem lista de raspadinhas.", 3)
    }
}

global ScanStartTime := 0  ; A_TickCount do primeiro dígito do scan atual

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
    global ScanStartTime

    collected  := ih.Input
    elapsed    := A_TickCount - ScanStartTime
    ScanStartTime := 0

    ; Reiniciar o hook imediatamente para a próxima entrada
    ih.Start()

    ; Scan válido: exatamente 14 dígitos (sem letras), recebidos em < 500ms
    isScan := (StrLen(collected) == 14 && elapsed < 500 && RegExMatch(collected, "^\d+$"))

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

