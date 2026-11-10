# Voice: frFR (French, France)

First submittal (10 Nov 2026), written by the translator from the English
voice (`/copywriter` §1 to §6) because the project has no French speaker.
**Every decision below is open to the French contributors**; when one
changes a decision, change it here too. Marked (?) = a guess worth a
native's first look. Companion: `frFR-code-changes.md` (framework faults).

## Address and people
- **tu**, never vous, for the player. A diary talks to its owner. French
  cannot drop the pronoun as Spanish does, so use it where the verb needs
  it ("Tu as atteint le niveau 12"), and drop it in ledger lines
  ("Quête terminée ensemble pendant 1 h 5 min").
- The diary calls itself **le journal** ("D'après ce que le journal a pu
  voir"), never "je". Sample notes the player wrote stay first person.
- **Gender.** French agrees participles and adjectives with the person,
  and the game says each character's sex (`Locales/Locale.lua`, "A
  person's gender"). Write the natural sentence and let the forms agree:
  `<you:tué/tuée>` for the reader, `<1:est mort/est morte/a péri>` for the
  character named in the key's first value (check at the call site that it
  is a player character's name). Where braces hold the participle, brace
  each form whole, `<you:{t’a sauvé}/{t’a sauvée}>`, and give each its
  line in `YOU_FOR`. "Tu es morte", "Zuri a été tuée par Hogger", "t’a
  vue mourir" replace the first pass's "tu as péri", "tu as succombé".
  For another character, a third form covers a sex not known (a typed
  name, an old row, the value "Cette personne"): an avoir-verb there ("a
  péri"), never "(e)" or a middle dot. For the reader two forms are
  enough (the masculine is the fallback). A sentence about two people at
  once ("toi et Numa") keeps its avoir-verb.
- Other players: the **name**, or **cette personne** where English says
  "they". Never "il" or "elle" for someone we know nothing about; a group
  "they" is "eux" only where unavoidable, preferably the names or "tous".
  No "le joueur", and no adjective that agrees with someone whose sex no
  value carries ("cette personne", a group).
- `{you}` braces: the brace holds the **verb phrase in its reader form**
  ("{Tu as tué} Bram"); the other-character form is the third person with
  the name ("%s a tué"). A braced word is looked up lower-case in
  `YOU_FOR`; the reader form keeps what is written, so a capital inside the
  brace is fine ("{Tu as tué} Bram", "{Ton groupe} a tué"); the other-character
  form of a sentence opener is not capitalised by the code. Elision before a
  name ("d'Ana") is done by a function in `YOU_FOR`.

## Tense
- **Prose** (Your Diary, profile, tour): **passé composé** for events
  ("Tu as atteint le niveau 12 le 6 octobre. La route continue."),
  présent for state ("Il est déjà niveau 14"), **conditionnel** for
  hindsight ("Vous vous retrouveriez au niveau 15").
- **Ledger** (rows, tooltips): the same, short, subject dropped, often a
  noun or participle that needs no agreement ("Quête accomplie ensemble",
  "t'a tué deux fois").

## Typography
- Quotes: **« … »** with a no-break space (U+00A0) inside each, for quest
  titles and notes; nested “ ”. Apostrophe: **’** (curly) everywhere.
  Ellipsis: … (one character).
- **A no-break space (U+00A0) before ; : ! ? and »** and after «. Write it
  as a literal character in the file, never an ordinary space there.
  Exclamation marks only where the English has its two allowed ones
  ("Ton premier objet vert !").
- Dates: "6 octobre", with the year only when not this year ("6 octobre
  2025"); "1er octobre" (`G.Day`); "lundi 6 octobre", no comma. Months and
  weekdays lower-case. "le" before a date where the value is always a
  date ("Écrit le 6 octobre"); where it may be "aujourd’hui" or "hier", a
  colon instead ("Ajout : hier"). No zero padding (the `/sd` chat dates
  keep the code's).
- Time: "18 h 05" in sentences (`G.Clock`); the timeline's time column and
  the `/sd` lists keep "18:05".
- Numbers in words up to ten, as English; figures after. Decimal comma.
- **Counts.** A plural value has three forms: 1, then 0 (singular, with
  the figure: "0 combat"), then the rest. Form 1 leaves the count out
  wherever the English's first form does ("une fois", "une note", "un
  autre"), and holds the article itself, so a number word never has to
  agree there. Where a number word arrives in another sentence before a
  feminine noun, mark it `%s<f>` ("un" becomes "une").
  Thousands with a no-break space. Number and unit together by the
  no-break space the code uses.
- Ordinals: "25e", "1er", "1re" for a feminine noun (`grammar.Ordinal`,
  its `FEMININE` table: death and match); the words "première,
  deuxième…" of `##death` and `##match` agree with "mort" and "partie".
- **No middle dots, ever.**
- Case: sentence case. Months, days, languages lower-case. Proper names
  keep their case (*Social Diary*, *Ton journal* for "Your Diary" (?)).
- Elision: the translator writes "d’" / "l’" by hand where the word after
  is fixed text. Before a game-supplied name or a value, rewrite so no
  elision is needed; a place's preposition elides in `PLACE` ("près
  d’Orgrimmar", "autour d’Orgrimmar"), a name's "de" in `G.Genitive`.

## Game terms (as the frFR client says them; verify in the client)
| English | French |
|---|---|
| level | niveau |
| group / party | groupe |
| raid | raid |
| quest | quête |
| duel | duel |
| guild | guilde |
| rare (creature) | rare |
| elite | élite |
| pet (hunter) | familier |
| dungeon | donjon |
| battleground | champ de bataille |
| match (battleground) | partie (?) |
| World PvP | JcJ en monde ouvert (?) |
| boss | boss |
| wipe | anéantissement du groupe (?) |
| Need / Greed roll | Besoin / Cupidité |
| gold / silver / copper | or / argent / cuivre |
| zone | zone |
| profession | métier |
| campfire | feu de camp |
| ghost / spirit | fantôme / esprit |
| flight path | trajet de vol (?) |
| hearthstone | pierre de foyer |
| nameplate | barre d’identité (?) |
| Horde / Alliance | Horde / Alliance |

## The diary's own words (one word each, kept)
| English | French |
|---|---|
| the diary | le journal |
| Your Diary | Ton journal |
| ink in / add to the diary | consigner dans le journal / ajouter au journal |
| pencilled in | noté au crayon (?) |
| rubbed out / forgotten | effacé / oublié |
| remove from the diary | retirer du journal |
| delete (for good) | supprimer |
| the road | la route |
| route (one setting label) | itinéraire |
| crossed paths / met | se croiser / rencontrer |
| toast (Settings, changelog) | alerte (?) |
| card (on the card only) | fiche (?) |
| foe | adversaire |
| People | Personnes |
| Recently nearby | Croisés récemment (?) |
| sighting | aperçu (?) |
| reunion | retrouvailles |

## Length
French runs about 15 to 30 % longer than English. Tight surfaces: toast
cards, key-binding column, tickets, Settings labels, tab names, map keys,
`Windows/Reunion` lines. There prefer the shorter phrasing ("Retrouvailles",
not "Des retrouvailles avec quelqu’un").

## Not settled
- Gender of "they" for a stranger; "cette personne" can get repetitive.
- "alerte", "fiche", "aperçu" as the diary's words (?).
- Whether "Ton journal" or "Mon journal" fits the tab name.
- "partie" for a battleground match (the first pass mixed "match" and
  "partie"; the second chose "partie" throughout).
