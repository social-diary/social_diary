**# Voice：zhTW（繁體中文）**

本規範為草案，於2026年11月20日擬定。譯文以英文原文為準，並參照
`Locales/zhCN/` 的結構與用語，但遊戲名詞改用台灣客戶端的用語，
其餘用詞與語氣依台灣讀者的習慣重寫，不是把簡體轉成繁體。
遊戲名詞的依據是 WoW Forever 客戶端（build 1.60.1.70959）的繁體中文
字串表，經 wago.tools 取得；表內查不到的詞，在最後一節列為待查。
已由台灣母語者審閱，並在 WoW Forever 客戶端實測。

**## 稱謂與人物**
- **你**，絕不使用「您」。日記以平靜的語氣對單個玩家說話；
  不使用敬稱，也不以「我們」代替單數的「我」。
- 日記在普通敘述中稱為**這本日記**，在簡短文字中稱為**日記**；
  外掛名稱 **Social Diary** 保留英文（外掛標題、設定頁面、
  登入包裹）。「Your Diary」是日記裡的一個頁面，稱為**你的日記**，
  不與外掛名稱混用。
- 其他玩家統一稱為**對方**，單複數通用，也不帶性別。句子需要補上
  英文省略的動詞時，應明確寫出（"they whispered" -> 對方傳了悄悄話）。
- 玩家**名字**直接使用：前面不加「位／名／個」，中文不需要時後面也不加
  「的」。示範用的虛構角色名（Thex、Bram）保留原文，不音譯。
  不使用 `<N:he/she>` 或 `<you:...>`（中文動詞沒有人稱和性別變化）。
- 讀者相關的花括號佔位符：`{你}` -> `%s`，`{你的}` -> `%s的`，
  `{你們}` -> `%s和對方`（`G.YOU_FOR`）。
- **一位**用於人（見證者、玩家）；**個**用於角色、任務、首領；
  **隻**用於寵物和怪物；不使用**名**，但「另有3名」這類接在人數後的
  補述例外。

**## 時態**
- 中文以體貌而不是動詞變位表達時態。已完成的動作用**了**，回顧經歷用
  **過**，持續的狀態不加標記。列舉發生過的事時，可以像英文一樣省略主語。
- **敘述文字**（你的日記、個人資料、導覽）要像日記：句子短，一句一件事，
  不用「將會」。
- **紀錄文字**（列表行、提示資訊、卡片、設定頁的靜音清單）用短語，
  不用「你」，除非動作已完成本身很重要，否則不用「了」。
- 回顧本可能發生的事（"would meet again"）用**會／本會**：
  你們本會在15級再次相遇。
- 英文的 fell（倒下、死去）在對戰與路線的敘述裡譯為**倒下**；
  died（死亡的事實）譯為**死亡**。

**## 排版**
- 全文使用全形標點：**，。：；！？（）「」**，半角標點視為錯誤
  （目前沒有測試掃描這一點；`tests/copy_rules.lua` 只掃描間隔號，也會掃描 `Locales/`）。
- 引號使用**「…」**，內層使用**『…』**。字元來自
  `L["“##quote open"]` / `L["”##quote close"]`；模板需要包住引文時用
  `L["“%s”"]`。絕不使用直引號 `"` 或 `“”`。
- 省略號在敘述與列舉裡寫成**……**（兩個字元，與 `Locales/zhCN/` 現況相同）；
  選單與按鈕標籤結尾、表示後面還有步驟的省略號（「新增自訂事件…」）
  用單一字元**…**。不使用 `...`。字串內部換行用 `\n`，段落之間用兩個換行。
- **絕不使用間隔號（·）**。
- **數字一律使用阿拉伯數字**，包括計數與一般敘述：1次、2次、5次。
  固定習慣說法裡的漢字數字可以保留（第一次、一起、兩次），
  以及程式要求的 `one..twenty` 數字詞列表。序數（第13次）用阿拉伯數字，
  1 至 12 的序數詞表沿用漢字（第一次、第十二次），與 `Locales/zhCN/` 相同。
- 日期格式為**2026年11月14日**，簡短日期為**11月14日**；星期寫成
  **星期六**（不用「周六」「週六」），放在日期前：星期六，11月14日。
  時間用24小時制**18:30**；敘述中的時長用5分鐘、1小時5分鐘。
- 金錢縮寫：**%d金／%d銀／%d銅**（客戶端字串表的縮寫為金、銀、銅，
  全稱為「%d金幣」）。
- 列表項目之間用**、**，最後兩項之間用**和**（`%1$s、%2$s##list`，
  最後 `%1$s和%2$s`）。
- 中文與英文單字之間加一個半形空格（`開啟 Social Diary`、
  `按 Esc 取消`、`Beta 測試者`），斜線指令前後也一樣
  （`輸入 |cffffd100/sd add <名字>|r`）；英文緊接全形標點時不加。
  中文與數字之間不加空格（`%d小時`、`%d級`）。需要空格的單位
  （`%d MB`）與斜線指令本身（`/reload`、`/sd sightings help`）
  必須保持遊戲客戶端顯示的原樣。
- 指令說明裡的參數佔位詞翻成中文（`<名字>`、`[地圖 ID]`）；
  玩家要打的指令字本身保持英文。
- 授權條款與字型授權的名稱保留英文原名（GNU General Public
  License v3、MIT License、SIL Open Font License 1.1）。
- 斜線指令的子指令（`recent`、`of`、`city`、`add`、`remove`）是玩家要打的
  字，保持英文，只翻譯說明。
- 破折號使用**——**。標籤與其值之間用**：**。

**## 量詞規範（每種意思固定一個）**
| 英文 | zhTW | 使用場景 |
|---|---|---|
| a match | 場 | 對戰、決鬥、戰場 |
| a time / a count | 次 | 死亡、擊殺、交易、偶遇、地城、團隊副本、狩獵、死裡逃生 |
| a pet / a creature | 隻 | 寵物、稀有怪、首領之外的怪物 |
| a killing blow | 次最後一擊 | 最後一擊 |
| a person | 位 | 見證者、玩家、對方 |
| a character | 個 | 角色 |
| a quest | 個 | 任務 |
| a boss | 個 | 首領 |
| a note / a message | 則 | 筆記、訊息 |
| a record | 筆 | 日記條目、互動紀錄 |
| a place | 處 | 停留 |

**## 遊戲名詞（以台灣客戶端字串表為準）**
括號內是字串表的標籤，供日後核對。

| 英文 | zhCN | zhTW |
|---|---|---|
| level | 等级 | 等級（LEVEL）；數字後寫成「45級」 |
| group / party | 小队 | 隊伍（PARTY、ERR_NOT_IN_GROUP）；GROUP 雖為「小隊」，只見於少數標籤 |
| raid | 团队 | 團隊；團隊副本（RAID、MAP_LEGEND_RAID） |
| dungeon | 副本 | 地城（LFG_TYPE_DUNGEON）；instance 才是副本（INSTANCE） |
| boss | 首领 | 首領（BOSS） |
| rare (creature) | 稀有怪物 | 稀有怪（字串表為「稀有生物」，採口語） |
| elite (creature) | 精英怪物 | 精英怪（字串表為「精英」，採口語） |
| rare elite | 稀有精英 | 稀有精英怪（字串表為「稀有精英生物」，採口語） |
| uncommon / rare / epic (item) | 优秀／精良／史诗 | 優秀／精良／史詩（ITEM_QUALITY2、3、4_DESC） |
| Apprentice / Journeyman / Expert / Artisan | 初级／中级／高级／大师 | 初級／中級／高級／專家級（APPRENTICE 至 ARTISAN；zhCN 把 Artisan 譯成「大师」，那是 Master） |
| profession | 专业 | 專業技能（PROFESSIONS_BUTTON） |
| quest / duel / battleground | 任务／决斗／战场 | 任務／決鬥／戰場 |
| zone | 地区 | 地區（ZONE） |
| flight | 飞行 | 飛行 |
| pet / tame | 宠物／驯服 | 寵物／馴服 |
| campfire | 营火 | 營火 |
| whisper | 密语 | 悄悄話（WHISPER；舊教學字串仍有「密語」，見待決事項） |
| say / yell | 说话／喊话 | 說話／大喊（CHAT_MSG_SAY、CHAT_MSG_YELL） |
| trade | 交易 | 交易 |
| resurrection | 复活 | 復活 |
| Horde / Alliance | 部落／联盟 | 部落／聯盟（FactionGroup） |
| Need / Greed | 未出現（zhCN 的 voice 表寫「需求／贪婪」，檔案內沒有） | 需求／貪婪（NEED、GREED） |
| gold / silver / copper | 金／银／铜 | 金／銀／銅（GOLD_AMOUNT_SYMBOL） |
| health | 生命值 | 生命力（HEALTH） |
| focus (target) | 焦点目标 | 專注目標（CLEAR_FOCUS） |
| skull | 骷髅 | 頭顱（RAID_TARGET_8） |
| killing blow | 致命一击 | 最後一擊（BF_KILLBLOWS） |
| scoreboard | 记分板 | 計分板（TOGGLE_SCOREBOARD） |
| Hardcore | 硬核模式 | 專家模式（HARDCORE_REALM_NAME） |
| macro / action bar | 宏／动作条 | 巨集／快捷列（MACRO、ACTIONBARS_LABEL） |
| nameplate | 姓名板 | 名條（NAMEPLATES_LABEL） |
| minimap / tooltip | 小地图／鼠标提示 | 小地圖／提示資訊 |
| reload | 重载 | 重新載入（RELOADUI） |
| Night Elf / Undead | 暗夜精灵／亡灵 | 夜精靈／不死族（ChrRaces） |
| The Barrens | 贫瘠之地 | 貧瘠之地 |
| The Crossroads / Lushwater Oasis | 十字路口／甜水绿洲 | 十字路口／甜水綠洲 |
| Stonetalon Mountains | 石爪山脉 | 石爪山脈 |
| Deeprun Tram | 深流地铁（誤） | 礦道地鐵 |
| Warsong Gulch / Arathi Basin / Alterac Valley | 战歌峡谷／阿拉希盆地／奥特兰克山谷 | 戰歌峽谷／阿拉希盆地／奧特蘭克山谷 |
| Ratchet | 棘齿城 | 棘齒城 |
| Wolfskin Bracers | 狼皮护腕 | 狼皮護腕（ItemSparse 6070） |
| wipe | 团灭 | 滅團（PHRASES_DUNGEON_WIPE） |
| bug | 问题 | Bug（SEND_BUG、BUG_BUTTON） |
| Beta | （略去） | Beta（BETA_BUILD） |
| RP | RP | 角色扮演（RP）（GAMETYPE_RP） |
| Forever（遊戲名） | Forever | 《魔獸世界：永恆》（CATALOG_SHOP_WOW_FLAVOR_FOREVER） |
| Tinker Town | 工匠镇 | 地精區（WMOAreaTable） |

**## 日記專用詞彙（每個英文詞固定對應一個中文）**
| 英文 | zhTW |
|---|---|
| Social Diary | Social Diary（保留英文） |
| the diary | 這本日記／日記 |
| Your Diary | 你的日記 |
| the journal (the book) | 日誌 |
| add to the diary | 加入日記／寫進日記 |
| pencilled in | 用鉛筆寫下 |
| inked | 用墨水寫定 |
| rubbed out | 擦掉 |
| remove from the diary | 從日記中移除 |
| delete (for good) | 刪除 |
| the road / route | 路線 |
| sighting | 偶遇（偶遇紀錄） |
| reunion | 重逢 |
| witness | 見證者 |
| close call | 死裡逃生 |
| lucky hunt | 幸運狩獵 |
| slow hunt | 漫長的狩獵 |
| hunt | 狩獵 |
| first met | 初次相遇 |
| first seen | 初次見到 |
| foe | 仇人 |
| someone to avoid | 想避開的人 |
| card | 卡片 |
| plate | 圖版 |
| page | 頁面 |
| slip | 紙條 |
| People | 人物 |
| session | 相處紀錄 |
| toast | 通知 |
| Remember this | 記下這件事 |

**## 與 zhCN 的主要差異**
- 遊戲名詞改用台灣客戶端用語（見上表）。
- 外掛名稱 Social Diary 保留英文，Your Diary 譯為「你的日記」；
  zhCN 兩者都譯成「冒险日记」。
- sighting 譯為「偶遇」，不用「邂逅」，因為它只是記下在路上見過對方，
  不含相識的意思。
- 斜線指令的子指令保持英文；zhCN 把 `recent`、`add`、`remove`
  也譯了，玩家照著打會打不出指令。
- 修正語序：地點片語（「在X」）放在動詞前面，不接在「了」之後；
  「Times」詞已含「次」，模板不再重複寫「次」。
- 「killing blow」譯為「最後一擊」，不是「擊殺」。

**## 文字長度**
中文通常比英文短三到四成，英文已很緊湊的地方才要留意：通知卡片、
重逢通知、按鍵設定欄、票券、設定頁標籤與單行說明、分頁名稱、地圖圖例。
這些位置優先用更短、更自然的說法，不為了裝飾而硬用四字詞。較長的
設定說明（刪除日記的確認、效能警告）保留完整句子，一句一件事。

**## 尚未最終確定的事項**
- **悄悄話與密語**：字串表的 WHISPER 為「悄悄話」，部分舊教學字串仍寫
  「密語」。目前一律用「悄悄話」，待台灣玩家確認。
- **外掛名稱**：保留英文 Social Diary。程式裡有幾處名稱是寫死的英文
  （小地圖提示、按鍵設定、巨集名），翻譯檔改不到；deDE、esES、frFR、
  itIT、ptBR、ruRU 的翻譯也保留英文。zhCN 用「冒险日记」。是否要有
  中文名待維護者決定。
- **空格**：中文與英文單字之間已全面加空格；客戶端字串本身不加
  （`提交Bug`、`Beta測試`）。中文與數字之間目前不加，與客戶端相同
  （`%d小時`、`11月14日`）：句子裡的數字、時長與日期多半是執行時
  才填進去的，翻譯檔只能在固定的字面上加空格，會出現只有一邊有空格
  的句子。執行時填入的英文名字（玩家名）兩側同樣不會有空格。
  數字目前不加，之後再處理。
- **偶遇**：用詞待台灣玩家確認；備選為「目擊」「遇見」。
- **session**：英文是內部用語，譯為「相處紀錄」只是權宜，
  需要確認它在遊戲內實際顯示的位置後再定。
- **稀有怪／精英怪**：字串表只有「稀有生物」「精英」，口語縮稱未在表內
  找到原文。
- **序數**：1 至 12 的序數詞表用漢字，13 以上用阿拉伯數字，
  與前述「數字一律阿拉伯數字」並存；是否統一待審閱者決定。
- **Article 選項**：`Disable ("A Hogger")` 與「冠詞」在中文不會顯示
  （`NO_ARTICLE`），已翻譯但不會被讀到。
- 虛構的招牌名（Wizzlebolt & Daughter、Grizzik's Diaries）
  無法在字串表找到官方譯名，目前是音譯，待查。Tinker Town 用客戶端的
  地名「地精區」（WMOAreaTable）。
- 遊戲內實測：通知寬度、票券文字行、設定頁說明在 WoW Forever 客戶端
  顯示正常。
