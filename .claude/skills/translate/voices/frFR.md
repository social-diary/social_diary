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
- **Gender.** French agrees participles and adjectives with the person. The
  player's own sex is not known to the text and neither is a stranger's.
  So: prefer verbs that take **avoir** ("tu as atteint", "tu as tué",
  "tu as trouvé"), present tense, infinitives and noun phrases. Avoid
  être-verbs with a participle ("tu es arrivé", "mort", "parti"): reword
  ("tu as atteint", "tu as succombé", "tu as pris la route"). Never write
  the "(e)" or middle-dot inclusive forms.
- Other players: the **name**, or **cette personne** where English says
  "they". Never "il" or "elle" for someone we know nothing about; a group
  "they" is "eux" only where unavoidable, preferably the names or "tous".
  No "le joueur", no adjectives that agree ("fatigué").
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
  2025"). Months and weekdays lower-case ("le lundi"). **1er** for the
  first of the month: not producible, see code changes. No zero padding.
- Time: French writes "18 h 30"; the code writes 18:30 (see code
  changes). In translated text use "18 h 30" only when the template holds
  the time in words; otherwise leave the code's form.
- Numbers in words up to ten, as English; figures after. Decimal comma.
  Thousands with a no-break space. Number and unit together by the
  no-break space the code uses.
- Ordinals: "25e", "1er" (`grammar.Ordinal`); words "premier, deuxième…"
  take the noun's gender per `##context` key (premier / première).
- **No middle dots, ever.**
- Case: sentence case. Months, days, languages lower-case. Proper names
  keep their case (*Social Diary*, *Ton journal* for "Your Diary" (?)).
- Elision: the translator writes "d’" / "l’" by hand where the word after
  is fixed text. Before a game-supplied name or a value, rewrite so no
  elision is needed ("autour de" and "près de" before a bare name break
  on a vowel name: a framework fault, see code changes).

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
- "1er" and "18 h 30" forms need code (see code changes).
