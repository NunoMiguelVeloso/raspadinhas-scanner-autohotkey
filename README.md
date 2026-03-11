# Raspadinhas Scanner AutoHotkey

Um script AutoHotkey v2 robusto para intercetar o input de leitores de código de barras, detetar códigos de "raspadinhas" e convertê-los automaticamente no sistema de ponto de venda (POS).

## 🚀 Funcionalidades

- **Deteção Inteligente de Scanners:** Utiliza a API nativa `InputHook` do AutoHotkey para distinguir com 100% de precisão entre a digitação manual rápida e a leitura instantânea de um scanner de código de barras (< 500ms para 14 dígitos).
- **Digitação Humana Transparente:** Os caracteres digitados manualmente pelo operador aparecem imediatamente no ecrã (modo "Visible"). Não há bloqueios nem atrasos na escrita normal.
- **Processamento Automático:**
  - Valida se o código tem exatamente 14 dígitos numéricos.
  - Verifica assincronamente os primeiros 3 dígitos numa lista centralizada no GitHub.
  - Se for uma raspadinha válida, apaga instantaneamente o código original do ecrã e injeta o formato processado (ex: `RASPA-XXX`).
  - Se não for, envia o código de barras original inalterado.
- **Audible Feedback:** Emite um breve sinal sonoro (beep áudio) simulando o som clássico de caixa de supermercado sempre que uma raspadinha é processada com sucesso.
- **Resiliência de Rede & Modo Offline:**
  - A lista de prefixos válidos é atualizada automaticamente a cada 10 minutos em background, sem interromper o trabalho.
  - Cria um cache local (`raspadinhas_cache.txt`) a cada download bem-sucedido.
  - Se o tablet perder a ligação à internet, o script arranca e funciona normalmente recorrendo ao último ficheiro de cache guardado.
  - Operação 100% silenciosa: Não mostra popups de erro exceto se forções uma atualização manual ou no arranque se não existir nem internet nem cache.
- **Menu Integrado (Tray):**
  - **Ver Estado da Lista:** Mostra rapidamente quantos códigos estão em memória e a data/hora exata do último backup offline (cache).
  - **Atualizar Lista Agora:** Força o download da lista do GitHub no momento.

## 📦 Instalação e Utilização

1. **Requisitos:** Instalar o [AutoHotkey v2](https://www.autohotkey.com/v2/).
2. **Download:** Descarregar o ficheiro `scanner.ahk` para o computador/tablet.
3. **Execução:** Fazer duplo-clique no ficheiro `scanner.ahk`.
4. (Opcional) **Arranque Automático:** Para o script iniciar sempre que o Windows liga:
   - Pressionar `Win + R`, escrever `shell:startup` e dar Enter.
   - Colocar um atalho para o `scanner.ahk` dentro dessa pasta.

## 🛠 Como Funciona a Lógica de Leitura

A lógica antiga baseava-se em acumular dígitos baseados num temporizador (Timer) com um limite de tempo estrito fixo (85ms/100ms) o que estava suscetível a "race-conditions" e instabilidade quando o temporizador `FlushBuffer` disparava antes de o scanner enviar o `Enter` final.

A nova arquitetura funciona da seguinte forma:
1. O `InputHook` captura tudo e permite que chegue à app ("V").
2. A tecla `Enter` do scanner é intercetada como "EndKey". Ela não chega à app.
3. Quando o `Enter` ocorre, o script verifica o que foi reunido na memória do Hook até agora.
4. Se foram **exatamente 14 dígitos submetidos em menos de 500 milésimos de segundo**, o script apaga o que foi teclado visivelmente recorrendo a *backspaces*, processa a regra das raspadinhas e injeta o resultado final seguido do seu próprio `Enter`.
5. Se foi um *input* manual, ele percebe pelo tempo de viagem demorado (ou comprimento do texto) que não foi o leitor laser e não apaga nada, apenas emite o `Enter` em falta.

## 📝 A Lista de Códigos

A lista de códigos válidos de raspadinhas está armazenada de forma centralizada num repositório GitHub. O script faz o download do ficheiro *raw* `.txt` para obter a versão mais recente.
O ficheiro de texto deve conter os prefixos de 3 dígitos das raspadinhas (ex: `642`), um longo por linha.

## 🐛 Debugging

Para testar ou debugar problemas:
- Se precisares de saber o estado da conexão: clica no ícone verde com o "H" na barra de tarefas (System Tray) junto ao relógio e seleciona "Ver Estado da Lista".
- Se houver falhas de internet, as notificações só aparecerão se tentares forçar pelo botão "Atualizar Lista Agora", para evitar que o operador de caixa em caso de falha de conexão na loja, fique constantemente a preencher a tela de avisos amarelos no canto.
