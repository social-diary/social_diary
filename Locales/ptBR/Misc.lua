-- Portuguese (Brazil): os ganchos do jogo, o Kit, o mapa, o controle e o papel.
-- Voice and decisions: .claude/skills/translate/voices/ptBR.md
local addonName, ns = ...
if not ns.Locale.Is("ptBR") then return end

ns.Locale.Add("ptBR", {
    -- UI/Blizzard/Minimap.lua
    ["Click to open or close the journal."] = "Clique para abrir ou fechar o diário.",
    ["Right-click to open the settings."] = "Clique com o botão direito para abrir as configurações.",
    ["Drag to move this button."] = "Arraste para mover este botão.",
    -- UI/Blizzard/Signpost.lua
    ["The settings live in your journal now, behind the grey ribbon at the bottom of the book."] = "As configurações agora ficam no seu diário, atrás da fita cinza na base do livro.",
    ["Open the settings"] = "Abrir as configurações",
    -- UI/Blizzard/SocialTab.lua
    ["Open your journal."] = "Abra o seu diário.",
    -- UI/Blizzard/Tooltip.lua
    ["Seen %1$s, last %2$s"] = "Visto %1$s, a última %2$s",
    ["in your diary"] = "no seu diário",
    ["|cffffd100Diary:|r %s"] = "|cffffd100Diário:|r %s",
    ["Met %1$d time, last %2$s|Met %1$d times, last %2$s##plural"] = "Se encontraram %1$d vez, a última %2$s|Se encontraram %1$d vezes, a última %2$s",
    -- UI/Kit/Confirm.lua
    ["Delete"] = "Excluir",
    ["Cancel"] = "Cancelar",
    ["Delete everything Social Diary knows about %s?\n\nThis cannot be undone."] = "Excluir tudo o que o Social Diary sabe sobre %s?\n\nIsso não pode ser desfeito.",
    ["Remove %s from the diary?\n\nTheir history can stay as an ordinary character, where the buffer's retention rules apply to it again."] = "Remover %s do diário?\n\nO histórico pode ficar como o de qualquer outro personagem, e as regras de retenção do histórico temporário voltam a valer.",
    ["Keep history"] = "Manter histórico",
    ["Delete everything"] = "Excluir tudo",
    -- UI/Kit/Keys.lua
    ["That key stays with the game. Choose another."] = "Essa tecla fica com o jogo. Escolha outra.",
    ["Not during a fight. Try again after it."] = "Não durante um combate. Tente de novo quando ele acabar.",
    ["%1$s is set to %2$s.\n\nUse it for %3$s instead?"] = "A tecla %1$s está configurada para %2$s.\n\nQuer usá-la para %3$s em vez disso?",
    ["Use it"] = "Usar",
    ["It was %s until now."] = "Até agora era %s.",
    ["press a key"] = "pressione uma tecla",
    ["Escape to cancel"] = "Esc para cancelar",
    ["Change"] = "Trocar",
    ["no key"] = "sem tecla",
    ["Choose one"] = "Escolher",
    -- UI/Map/HeatSheet.lua
    ["Map %d"] = "Mapa %d",
    ["%1$s (%2$d)"] = "%1$s (%2$d)",
    ["Show map"] = "Mostrar mapa",
    ["Everyone"] = "Todos",
    ["ALSO SEEN IN"] = "TAMBÉM VISTO EM",
    ["Your diary was seen here %d time|Your diary was seen here %d times##plural"] = "Seu diário registrou %d avistamento aqui|Seu diário registrou %d avistamentos aqui",
    ["Seen here %d time|Seen here %d times##plural"] = "Visto aqui %d vez|Visto aqui %d vezes",
    ["Just %s"] = "Só %s",
    ["Just them"] = "Só esta",
    ["No maps yet"] = "Ainda sem mapas",
    ["Nobody from your diary seen on a map yet."] = "Ainda ninguém do seu diário foi visto num mapa.",
    ["Not seen on a map yet.\nThis fills in as you see them nearby."] = "Ainda não apareceu num mapa.\nIsso se preenche conforme você os vê por perto.",
    -- UI/Pad/Controls.lua
    ["Write"] = "Escrever",
    ["Done writing"] = "Terminar de escrever",
    ["Choose"] = "Escolher",
    ["Add the tag"] = "Adicionar a etiqueta",
    ["Take the tag off"] = "Retirar a etiqueta",
    ["Unlink them"] = "Desvincular",
    ["Choose a keyboard key"] = "Escolher uma tecla do teclado",
    ["Pick it up"] = "Pegar",
    ["Stop listening"] = "Parar de ouvir",
    ["Tick"] = "Marcar",
    ["Untick"] = "Desmarcar",
    -- UI/Pad/Menu.lua
    ["See the choices"] = "Ver as opções",
    ["Put the menu away"] = "Guardar o menu",
    ["Back to the menu"] = "Voltar ao menu",
    -- UI/Paper/LinkSheet.lua
    ["WITH THEM THEN"] = "JUNTOS NAQUELE MOMENTO",
    ["WITH THEM BEFORE"] = "JUNTOS ANTES",
    ["EVERYONE ELSE"] = "TODOS OS OUTROS",
    ["Link others"] = "Vincular outras pessoas",
    ["Search names, tags, notes"] = "Pesquisar nomes, etiquetas, notas",
    ["Nobody in the diary matches."] = "Ninguém do diário corresponde à busca.",
    ["%d linked"] = "Vinculadas: %d",
    -- UI/Paper/NoteSheet.lua
    ["Unlink %s"] = "Desvincular %s",
    ["ABOUT"] = "SOBRE",
    ["What happened? Write it down while you remember it."] = "O que aconteceu? Escreva enquanto ainda lembra.",
    ["Delete this note"] = "Excluir esta nota",
    ["Save"] = "Salvar",
    ["Link who it is about"] = "Vincular a quem se refere",
    ["A new note"] = "Uma nova nota",
    ["Your note"] = "Sua nota",
    ["Written %1$s %2$s##zone"] = "Escrita em %1$s, %2$s",
    ["Written %s"] = "Escrita em %s",
    -- UI/Paper/Strip.lua
    ["“##quote open"] = "“",
    ["”##quote close"] = "”",
})
