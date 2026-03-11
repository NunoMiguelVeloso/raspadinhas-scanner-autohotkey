#Requires AutoHotkey v2.0
#SingleInstance Force

; Configurações
global GitHubUrl  := "https://raw.githubusercontent.com/NunoMiguelVeloso/raspadinhas-scanner-autohotkey/main/raspadinhas.txt"
global CacheFile  := A_ScriptDir . "\raspadinhas_cache.txt"
global LogFile    := A_ScriptDir . "\raspadinhas_debug.log"
global RaspadinhasMap := Map()

; ─── Debug ────────────────────────────────────────────────────────────────────
DebugLog(msg) {
    global LogFile
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    FileAppend("[" . timestamp . "] " . msg . "`n", LogFile, "UTF-8")
}

; ─── Tray Menu ────────────────────────────────────────────────────────────────
A_TrayMenu.Add()
A_TrayMenu.Add("Atualizar Lista Agora", AtualizarListaManual)
A_TrayMenu.Add("Abrir Log de Debug", AbrirLog)

AbrirLog(ItemName, ItemPos, MyMenu) {
    global LogFile
    if FileExist(LogFile)
        Run("notepad.exe " . LogFile)
    else
        MsgBox("Ficheiro de log não encontrado: " . LogFile, "Debug", 48)
}

; ─── Arranque ─────────────────────────────────────────────────────────────────
DebugLog("=== Script iniciado. AHK: " . A_AhkVersion . " | Script: " . A_ScriptFullPath)
DebugLog("GitHubUrl: " . GitHubUrl)
DebugLog("CacheFile: " . CacheFile . " | Existe: " . (FileExist(CacheFile) ? "SIM" : "NÃO"))

AtualizarLista(true)

; Mostrar resultado de arranque em MsgBox para debug
MsgBox("Arranque concluído.`n`nCódigos carregados: " . RaspadinhasMap.Count
    . "`nCache existe: " . (FileExist(CacheFile) ? "SIM" : "NÃO")
    . "`n`nDetalhes em:`n" . LogFile,
    "Raspadinhas Scanner - Debug", 64)

; Configurar a execução automática a cada 10 minutos (600000 ms)
SetTimer(AtualizarListaAuto, 600000)

; ─── Atualização da lista ─────────────────────────────────────────────────────
AtualizarListaManual(ItemName, ItemPos, MyMenu) {
    AtualizarLista(false)
}

AtualizarListaAuto() {
    AtualizarLista(false)
}

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

    maxTentativas := 3
    pausaEntreTentativas := 2000
    timeoutMs := 10000
    lastErr := ""

    Loop maxTentativas {
        tentativa := A_Index
        DebugLog("HTTP tentativa " . tentativa . "/" . maxTentativas . " — URL: " . GitHubUrl)
        TrayTip("🔄 Lista [" . tentativa . "/" . maxTentativas . "]", "A ligar ao GitHub...", 1)

        try {
            req := ComObject("WinHttp.WinHttpRequest.5.1")
            req.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
            DebugLog("  ComObject criado. SetTimeouts: " . timeoutMs . "ms")

            req.Open("GET", GitHubUrl, false)
            DebugLog("  Open() OK")

            req.Send()
            DebugLog("  Send() OK — Status HTTP: " . req.Status . " " . req.StatusText)
            TrayTip("🔄 Lista [" . tentativa . "/" . maxTentativas . "]", "Resposta: HTTP " . req.Status . " — " . StrLen(req.ResponseText) . " bytes", 1)

            text := req.ResponseText
            DebugLog("  ResponseText: " . StrLen(text) . " bytes | Primeiros 80: [" . SubStr(text, 1, 80) . "]")

            if (req.Status != 200)
                throw Error("HTTP " . req.Status . " " . req.StatusText)

            tempMap := ParseLista(text)
            DebugLog("  ParseLista: " . tempMap.Count . " códigos encontrados")
            TrayTip("🔄 Lista [" . tentativa . "/" . maxTentativas . "]", "Códigos encontrados: " . tempMap.Count, 1)

            if (tempMap.Count == 0)
                throw Error("Lista vazia (0 códigos de 3 dígitos encontrados).")

            if FileExist(CacheFile)
                FileDelete(CacheFile)
            FileAppend(text, CacheFile, "UTF-8")
            DebugLog("  Cache guardado: " . CacheFile)

            RaspadinhasMap := tempMap
            DebugLog("  SUCESSO: " . RaspadinhasMap.Count . " códigos carregados do GitHub.")

            if (!isStartup)
                TrayTip("Lista Atualizada", "Carregados " . RaspadinhasMap.Count . " códigos (GitHub).", 2)

            return
        } catch as err {
            lastErr := err.Message
            DebugLog("  ERRO na tentativa " . tentativa . ": " . lastErr)
            TrayTip("❌ Erro [" . tentativa . "/" . maxTentativas . "]", lastErr, 2)
            if (tentativa < maxTentativas) {
                DebugLog("  A aguardar " . pausaEntreTentativas . "ms antes de tentar novamente...")
                Sleep(pausaEntreTentativas)
            }
        }
    }

    ; Todas as tentativas falharam
    DebugLog("Todas as tentativas falharam. Último erro: " . lastErr)
    if (FileExist(CacheFile)) {
        cached := FileRead(CacheFile, "UTF-8")
        RaspadinhasMap := ParseLista(cached)
        DebugLog("Cache local carregado: " . RaspadinhasMap.Count . " códigos.")
        if (isStartup)
            TrayTip("Modo Offline", "Cache local: " . RaspadinhasMap.Count . " códigos.`nErro: " . lastErr, 3)
        else
            TrayTip("Erro de Atualização", "Cache local: " . RaspadinhasMap.Count . " códigos.`nErro: " . lastErr, 3)
    } else {
        RaspadinhasMap := Map()
        DebugLog("Sem cache local. A arrancar sem lista.")
        if (isStartup)
            TrayTip("Aviso", "Sem cache local.`nErro: " . lastErr, 3)
    }
}

; ─── Scanner ──────────────────────────────────────────────────────────────────
global ScanStartTime := 0

ih := InputHook("V")
ih.KeyOpt("{Enter}", "SE")
ih.OnEnd := OnScanComplete
ih.OnChar := OnCharFn
ih.Start()
DebugLog("InputHook iniciado.")

OnCharFn(ih, char) {
    global ScanStartTime
    if (StrLen(ih.Input) == 1)
        ScanStartTime := A_TickCount
}

OnScanComplete(ih) {
    global ScanStartTime

    collected := ih.Input
    elapsed   := A_TickCount - ScanStartTime
    ScanStartTime := 0

    ih.Start()

    isScan := (StrLen(collected) == 14 && elapsed < 500 && RegExMatch(collected, "^\d+$"))

    DebugLog("Enter | Input=[" . collected . "] Len=" . StrLen(collected)
        . " Elapsed=" . elapsed . "ms isScan=" . (isScan ? "SIM" : "NÃO"))

    if (isScan) {
        SendInput("{BS " . StrLen(collected) . "}")
        ProcessCompleteScan(collected)
    } else {
        SendInput("{Enter}")
    }
}

ProcessCompleteScan(barcode) {
    global RaspadinhasMap

    if (StrLen(barcode) != 14) {
        DebugLog("ProcessCompleteScan: len inválido (" . StrLen(barcode) . ") — a enviar tal qual")
        SendInput(barcode . "{Enter}")
        return
    }

    prefix := SubStr(barcode, 1, 3)

    if (RaspadinhasMap.Has(prefix)) {
        DebugLog("Raspadinha! Barcode=" . barcode . " Prefix=" . prefix . " → RASPA-" . prefix)
        SendInput("RASPA-" . prefix . "{Enter}")
    } else {
        DebugLog("Não raspadinha. Barcode=" . barcode . " Prefix=" . prefix . " (não na lista, total=" . RaspadinhasMap.Count . ")")
        SendInput(barcode . "{Enter}")
    }
}
