# Market Based Auction

Помощник аукциона для WoW 3.3.5a: цены и история предметов, сравнение крафтов,
пути получения материалов, списки реагентов, избранное, отслеживание, оценка
распыления, торговля у NPC, учёт сделок и стоимость прокачки.

Оригинальный клиент 3.3.5a (сборка 12340, Interface 30300). Интерфейс русский и английский,
по языку клиента. Retail и Classic 3.4 не поддерживаются.

Папку `ManaCode_AuctionScan` поместить в `Interface/AddOns`, затем полностью
перезапустить клиент. В аукционе появится вкладка Market. Auctionator необязателен.
При обновлении с 0.10 тоже нужен полный перезапуск: в аддоне новые файлы и `Bindings.xml`.

Слэш-команд нет: всё в интерфейсе.

## Что нового в 0.11.0-beta.1

**Обновление.** После установки полностью перезапусти игру. Бета поддерживает русский и английский интерфейс; язык выбирается по клиенту.

**Рынки и пути.** Появились способы получения предметов с переносом в Партию, торговля у NPC и оценка валют. Партия показывает продукт, маржу, вложенные реагенты и запасы персонажей.

**Покупка и учёт.** План закупки учитывает целые стопки и предел цены. Учёт объединяет крафт, переработку и перепродажу; стрелки истории возвращают выбор и настройки.

**Мелочи.** Добавлены экскурсия, справочник и темы окна. Исправлены перекрытия реагентов и работа длинных сканов. Старые сканы хранятся около месяца; учёт сохраняется.

| Что | Где |
|---|---|
| Скан всего рынка по страницам | «Скан рынка» в подвале вкладки ManaCode |
| Остановить, продолжить, доскан | «Стоп», «Продолжить», «Доскан» и «Сбросить» там же |
| Объём сохранения, бюджет, копия ценного | Окно настроек, раздел «Сохранение» |
| Интервал запросов и его сброс | Окно настроек, «Темп запросов» → «Сбросить замедление» |
| Учёт вне аукциона | «Учёт» в окне настроек или правый клик по кнопке у миникарты |
| Кнопки закупок на почте | Флажок «Кнопки на почте» в настройках и внизу окна учёта |
| Пропавшее сохранение | Окно настроек открывается само: «Вернуть из копии» или «Принять как есть» |

Окно настроек открывается кнопкой у миникарты, в настройках интерфейса клиента
(вкладка «Модификации» → Market Based Auction) и шестерёнкой в шапке вкладки
Market. Кнопку у миникарты можно перетащить по краю или спрятать флажком в настройках.

В разделе прокачки доступны наложение чар и алхимия 1–450: начальный и целевой навык,
альтернативные рецепты, жезлы для наложения чар, реагенты и их состав. Расчёт использует цены аукциона,
учитывает выбранные запасы и показывает закупку целыми лотами. Негарантированные
очки навыка требуют запаса; показанная стоимость не гарантирует итоговые расходы.

В распылении можно выбрать нужную пыль, субстанцию, осколок или кристалл.
Обратный поиск находит подходящую экипировку, показывает шанс цели и другие
возможные результаты. Теоретическая маржа учитывает все исходы, комиссию и резерв
залога. Галочка «До маржи» ограничивает глубину обхода; по умолчанию −10% оставляет
немного убыточные вещи для просмотра, подвал называет этот порог рядом с порогом
выкупа («показаны от -10%»). В режиме «По цене» обход заканчивается на лимите цены
за штуку: страницы дороже лимита не читаются. Если цены или порядок выдачи не
позволяют проверить границу, быстрый обход останавливается с объяснением; без цен
всех исходов вещи не ищутся, пока не дополнены исходы. Для полного обхода галочку
можно снять.

Главная кнопка подвала зависит от состояния: без скана группы — «Дополнить»
(исходы и вещи), без цены исхода — «Дополнить исходы», после скана — «Выкуп по
марже» или «Выкуп по цене». Клик по карточке исхода показывает в панели сам
материал и блок «Куда дальше»: продажа как есть и три лучших применения с переходом
в рецепт или переработку. «К вещи» возвращает выбранную вещь.

Скан запускается кнопкой игрока. Аддон использует события ответа аукциона,
CanSendAuctionQuery и общий ограничитель. Свежие данные повторно используются;
отдельную позицию можно обновить вручную. Сырые сканы сохраняются в SavedVariables
при `/reload` и выходе из игры. Хранится около месяца и не больше ~150 МиБ: после
очередного скана самые старые удаляются, последний полный скан рынка каждого
реалма и фракции остаётся. Учёт и журнал распыла ротация не трогает.
Объём и бюджет видны в окне настроек, раздел «Сохранение».

Кнопки цен говорят одним словом. «Дополнить …» по клику ищет устаревшее и без цены,
с Shift — всё заново, с Ctrl — только без цены; подсказка заранее показывает число
поисков. «Обновить» ищет один предмет заново. «Дополнить профессии» в шапке
охватывает камни, каталоги крафта, рецепты у NPC и прокачку.

«Лоты» показывает сохранённые предложения по ценам, продавцам и размерам стопок.
Исчезновение лота не подтверждает продажу. Маржа рассчитывается по ценам предложения
и не гарантирует продажу. Модели распыления и залога основаны на обычной 3.3.5;
правила конкретного сервера могут отличаться.

В распылении кнопка «Исходы» обновляет только цены результатов, «Вещи» ищет
только экипировку, «Всё» обходит оба набора. Цены результатов
переиспользуются 30 минут; свои цены сохраняются. Выкуп по марже запоминает
выбранные предложения и проверяет их общим поиском категории. Одно подтверждение
покупает подходящие разные вещи текущей страницы. Цена, продавец, случайные
свойства и количество проверяются заново; отправленные покупки учитываются
до нового скана в рамках игровой сессии.

Кандидаты появляются во время обхода и сохраняются после остановки или закрытия
аукциона. Кнопка в строке выбирает один самый выгодный лот предмета независимо от
порога массового выкупа; «Выкуп по марже» собирает лоты выше заданного процента.
Устаревшие цены дают предупреждение, но не блокируют покупку.

Для выбранной цели автоматически заполняются минимальный и максимальный ilvl.
Серверный запрос использует соответствующие требуемые уровни персонажа по базе
предметов, отдельно для брони и оружия. Реальные ilvl и результат распыления
проверяются дополнительно. Галочка «Ур. 0» включает вещи без требования уровня
через расширенный поиск; по умолчанию они исключены.

Обновления устанавливает [ManaCode Updater](https://github.com/dmitriinosach/-MANACODE-Update).
Обмен общей историей настраивается отдельно в Updater; серверные адреса, токены
и личные сканы в этот аддон не включены. Перед покупкой выполняется свежий поиск,
подтверждение остаётся за игроком.

## Переработка

Сравнение продажи малых и больших субстанций, кристаллизованных и извечных стихий,
сборки частиц в изначальные стихии. Показаны цены, комиссия, запасы и варианты
размера аукционных стопок. «Купить малые» и «Купить большие» открывают ручной поиск.

## Партия в профессиях

Рецепт в списке крафтов или огранка открывает справа «Партию», список остаётся на месте.
Первая строка — сам продукт и маржа всей партии, ниже количество готовых предметов.
«Партия» округлит число крафтов по выходу рецепта, покажет состав, излишек,
свои запасы и стоимость докупки. Молоток у составного реагента включает его
изготовление и раскрывает состав, стрелка открывает «Пути», если способов
несколько. Главная кнопка называет реагент: «Купить: Алый рубин x1 (1 из 2)» —
по очереди открывает недостающие материалы; каждую покупку подтверждает игрок.
Чипы «Реагенты крафтить» и «Свои запасы» стоят после итога. Проки и случайный
дополнительный выход в прибыль не включены. Настройки Партии помнятся по рецепту
до конца сессии.

Каталоги: 58 товаров алхимии, 125 свитков чар, 96 товаров портняжного дела,
122 кузнечного, 155 кожевничества, 428 начертания, 54 кулинарии, 33 инженерии,
17 первой помощи и 26 горного дела. Это подборки, а не полная база всех рецептов
игры. Товары, привязанные при получении, исключены; восстановление
трансмутаций и ледовой сумки отмечено отдельно.

У каждого рецепта есть эпоха: WotLK, БК или Классика. Чипы над списком выбирают
показанные эпохи, по умолчанию WotLK; старые рецепты, которые ещё продаются,
видны всегда, рецепты под прокачку подписаны. Эпохи действуют и на «Дополнить
профессию». Горное дело показывает выплавку, цепочка «титановая руда → слиток →
титансталь» строится в Партии кузнечного. В ювелирке группа «Кулдауны» с Ледяной
призмой, в начертании — Карта Новолуния: их случайный выход считается по ожиданию,
Око дракона и неизвестная доля карт отмечены. Северные пряности считаются по
условной цене, поэтому у пиров есть маржа.

У руды, трав, шкур и рыбы есть сырьевые экраны. «Материалы» показывают также
применения в личных улучшениях профессий и наблюдавшиеся размеры пачек.

Строки применений раскрываются на месте: рецепт — составом, улучшение — входами,
просеивание и измельчение — исходами. Переход в профессию или переработку — отдельная
стрелка справа. «Состав крафта» раскрывает лучший крафт материала в таблице. У
Ледяного шара третий исход — «Обменять» у Ледо в Даларане: аддон выбирает лучший
продаваемый товар обмена по ценам аукциона.

## Пути получения

Кнопка «Пути» в панели предмета рядом с «Рынок» и «Лоты» открывает все способы
получить предмет: купить, скрафтить любой профессией, трансмут, огранка, просеивание,
измельчение, переработка. «Схема» показывает способы по уровням со стоимостью за
штуку и пометками (кулдаун, нет цены, устарело, лотерея, кто из персонажей умеет);
«Таблица» — полные пути с себестоимостью, маржой и ограничениями. Клик выбирает путь,
«Применить к Партии» переносит его в открытую профессию, «Дополнить путь» обновляет
цены пути. Окно на аукцион само не ходит. Изученность у твинов видна, если на каждом
хотя бы раз открыть окно профессии; твин другой фракции помечен.

## Камни БК

В ювелирном деле доступны 18 семейств БК и 18 WotLK. Включите чип «БК», чтобы
увидеть старые камни и включить их в обход. Семейства раскрывают огранки,
показывают изученность по своей книге профессии и маржу по текущим ценам.

## Просмотр от выкупа

Штатный «Просмотр» показывает сверху полный выкуп лота, у стопок ниже — «За шт.:».
Лоты текущей страницы отсортированы по выкупу за штуку; без выкупа идут последними.
Выбор, подсказки, ставки и покупки сохраняют настоящий индекс лота.

## Окно «Рынок»

Кнопка «Рынок» в панели предмета открывает модальное окно с историей цены,
предложения и движения лотов за 1, 7 или 30 дней. Закрывается крестиком, Esc или кликом
по затемнению; Esc закрывает только верхнее окно, аукцион остаётся открытым.
Открытие истории не запускает поиск; «Обновить» запрашивает цены по клику.
В правой панели профессии остаётся состав партии.

## Ниже рынка

По последнему полному скану раздел отбирает лоты со скидкой к рынку и выгодные
ставки с коротким остатком срока. Выгода учитывает комиссию и резерв залога;
в панели видны расчёт, глубина предложения и наличие истории. Скан обновляется
вручную кнопкой «Скан всего рынка». Действие сначала ищет и проверяет лот, затем
ждёт подтверждения игрока. Ставку могут перебить, а цена из скана может измениться.

## У NPC

«NPC-трейдинг» сравнивает покупку у торговца с продажей на аукционе: обмен Ледяного
шара у Ледо, обмены у торговцев, питомцы и ограниченный запас. «Валюта» показывает,
что купить за эмблемы, честь, очки арены, печати и жетоны, курс одной единицы в
золоте по лучшему товару и сколько валюты у персонажа. В панели — где NPC, запас и
маржа после комиссии. Цены у NPC взяты из данных эмулятора и помечены как
непроверенные на сервере. Рецепты торговцев открываются в режиме профессии.

## Покупка

Введите название или перенесите предмет Shift-кликом. Выберите найденный предмет,
нужное количество и вариант плана: аддон считает целые стопки и исключает свои лоты.
Лимит «Дешевле, з/шт.» отбирает все найденные лоты строго дешевле указанной цены
за штуку. План можно поправить кнопками -/+. Панель показывает цены текущей выдачи,
историю и действия «Рынок», «Пути», «Лоты». Покупка требует свежей проверки и клика.

## Назад и вперёд

Стрелки в шапке вкладки слева от «Дополнить профессии» листают историю переходов,
как в браузере: раздел, выбранный предмет, прокрутку и настройки Партии. Стрелки ничего
не ищут на аукционе: в «Покупке» возвращается прошлая выдача. Пока идёт скан, покупка
или очередь цен, стрелки выключены. Кнопки мыши 4/5 или клавиши назначаются в штатном
«Назначении клавиш», раздел ManaCode; над пустым фоном вкладки кнопки мыши 4/5 работают
и без назначения.

## Учёт / Анализ

Журнал текущего персонажа сам отслеживает покупку, получение с почты, распыление,
просеивание, измельчение и крафт из учтённых материалов, выставление и получение
денег за продажу. В учёт попадают покупки из каталогов: экипировка под распыл, руда,
травы, реагенты и сырые камни; остальное — при флажке «Всё в учёт» как перепродажа.
Фильтр вида (Распыл, Просеивание, Измельчение, Крафт, Перепродажа) работает в «Вещах»,
«Анализе» и «Прогнозе». Плитка «Ожидаемый итог» подписана формулой: прибыль + остаток
− себестоимость. «Учёт» открывается и вне аукциона: кнопкой в окне настроек или правым кликом по кнопке у миникарты.
Неподтверждённые события можно уточнить вручную; отмена добавляет обратную запись.
«Анализ» сравнивает фактический выход переработки с моделью по предмету, ilvl или
полосе. Малые выборки отмечены отдельно.

«Следующий шаг» — что сделать из полученного: до десяти рецептов по марже на
материалы партии и сумок, с «есть / докупить» по реагентам и тем, кто из твинов
знает рецепт. Открывается из «Прогноза» и кнопкой «Что сделать из полученного» в
распылении; ничего не изготавливает.

Вещи не с аукциона (от другого персонажа или игрока по почте, своя добыча) заводятся
кнопкой «Из сумок» в «Учёте» или «В учёт» на панели почты после забора письма игрока.
Себестоимость выбирается явно: ожидание распыла, цена торговца, своя сумма или 0 с
предупреждением, что прибыль по таким материалам равна выручке. Дальше распыл,
материалы и продажа учитываются как у купленных.

Купленное за сеанс отмечается «Куплено N» в таблицах распыла, просеивания и «Ниже
рынка», пока таблица построена по скану старше покупки.

## Журнал распыла

Записываются наблюдавшиеся распыления игрока, включая вещи вне цепочек учёта:
предмет, время и полученные материалы. Учтённая вещь связывается с её покупкой.
Если наблюдение не сработало, выход для учтённой вещи можно указать вручную.
Журнал хранится в SavedVariables; модельный выход не выдаётся за полученный.

## Выставление

Откройте «Материалы», выберите предмет из сумок и настройте цену за штуку, размер
пачки, число лотов и срок 12/24/48 часов. Панель сравнивает чужие предложения,
показывает безубыток при известной себестоимости и результат после комиссии.
«Выставить» отправляет одну пачку за клик; перед следующим лотом нужен ответ сервера.

## Просеивание / измельчение

В «Переработке» можно сравнить руду или травы либо выбрать нужный камень или краситель.
Расчёт относится к операции из пяти штук: показывает возможные исходы, среднюю
маржу, удачный и неудачный варианты. Укажите свой навык и дополнения; обновите цены
по строке или обойдите видимый набор. Выкуп по марже или цене сначала проверяет
предложения и ждёт подтверждения. Переработку предметов выполняет игрок.

## Списки

«+» в панели предмета добавляет рецепт в избранное или предмет в отслеживание.
В «Списках» есть избранное, отслеживаемые предметы и сезонные подборки. Для
отслеживания можно ввести ссылку или itemID. Панель показывает цену и дату
наблюдения; «Рынок» открывает историю, «Лоты» — сохранённые предложения.

Комиссия расчётов определяется при открытии аукциона: 5% на фракционном и 15%
в Пиратской Бухте, Прибамбасске и Круговзоре. Вне аукциона сохраняется последнее
значение. Комиссия учёта записанных сделок настраивается отдельно.

## English

# Market Based Auction

**Compare the price of a finished item with the cost of making it, buying its materials or processing raw materials.** Market Based Auction brings these calculations into the Market tab at the auction house.

Built for the original **WoW 3.3.5a client, build 12340 (Interface 30300)**. **Russian and English** follow the client language. Retail and Classic 3.4 are not supported. Auctionator is optional.

## Prices and shopping

- Search by name or Shift-click an item, choose a quantity and compare plans using whole auction stacks.
- Set a maximum unit price to select offers strictly below that price. Your own auctions are excluded.
- Inspect saved offers by unit price, stack size and seller. View price and supply history for 1, 7 or 30 days.
- Track items, keep favourite recipes and browse seasonal selections.
- The Below Market section compares buyouts and short-duration bids with the latest full-market scan; it also finds offers below vendor value.
- Back and Forward arrows in the tab header return to earlier sections with their selection, scroll and batch settings, without new auction queries. Bind them to mouse buttons 4/5 or keys in the game's Key Bindings menu, section ManaCode.

## Professions and crafting batches

Compare recipes from jewelcrafting, alchemy, enchanting, tailoring, blacksmithing, engineering, leatherworking, inscription, cooking, first aid and mining. The catalogs are curated selections, not every recipe in the game. Every recipe is tagged WotLK, TBC or Classic; chips above the list choose which expansions are shown, WotLK by default, and older recipes that still sell stay visible.

Choose a target output quantity. The batch panel starts with the product and the margin of the whole batch, rounds crafts up to the recipe's guaranteed yield, expands craftable reagents and shows surplus, existing stock, missing materials, costs and margin after the auction fee. The main button names the next reagent to buy. Your stock reduces new shopping expenses while retaining its value in the cost calculation. Random specialization procs are not counted as guaranteed output. Recipes with random output, such as Icy Prism and Darkmoon Card of the North, are valued by their expected outcomes.

The **Paths** window shows every way to obtain an item — buy, craft with any profession, transmute, cut, prospect, mill or convert — as a scheme by level or a table of complete paths with cost, margin and limits: cooldowns, which of your characters know the recipe, low-chance outcomes and missing prices. A chosen path can be applied to the open crafting batch.

Gathering views cover ore, herbs, leather and fish. Materials show recipe uses, personal profession enhancements and observed stack sizes; a recipe, enhancement or processing use expands in place, and a separate arrow opens its section. Leveling plans for **enchanting and alchemy, 1–450**, include alternatives and a material shopping list; training fees are excluded and extra attempts must be allowed for explicitly.

## Vendors and currency

- Vendor trades: buy from an NPC and sell at the auction house — Frozen Orb trades with Frozo, vendor exchanges, pets and limited stock — with the margin after the auction fee.
- Currency: what emblems, honor, arena points, seals and tokens buy, the gold value of one unit by the best tradable item, and how much your character has.
- Vendor prices come from emulator data and are marked as not verified on your server.

## Processing

- Find equipment that can disenchant into a chosen dust, essence, shard or crystal. Compare the expected value of all modeled outcomes, auction fees and a deposit reserve. The main button follows the screen state: fill prices first, then buy by margin or unit price. In unit-price mode the scan stops at the price limit.
- Outcome cards switch the panel to the material itself, with a "Where next" block: selling as is and the three best uses.
- Compare prospecting ore and milling herbs in batches of five, either by raw material or desired gem/pigment.
- Compare selling, combining or splitting essences and elemental materials.
- Prepare purchases by margin or unit-price limit. Offers are searched again and checked before the player confirms them.

## Ledger and selling

The ledger follows purchases, auction mail, disenchanting, prospecting, milling, crafting from tracked materials, posting and collecting sale proceeds. Catalog items are tracked automatically; other items can be tracked for resale. A cycle filter, separate batches, a journal across characters of the same account, an "Expected result" tile with its formula and actual-versus-modeled processing results help review the outcome. "Next step" lists the best recipes for the materials you received, with what you have and what to buy. Unconfirmed events can be corrected manually. Items obtained elsewhere can be added from bags with an explicit cost basis.

The Materials panel can post one stack per click with a chosen unit price, stack size and duration.

## How scans work

Start scans yourself. Price buttons share one rule: "Fill" searches stale and missing prices, Shift searches everything again, Ctrl only missing prices; the tooltip previews the number of searches. Server errors, AFK and closing the auction house can pause scanning. Continue with a player action. Whole-market scans can be long; the one-request full scan may be truncated by the server.

Prices describe observed offers, not completed sales. Disappearing auctions do not prove a sale. Profit and random processing yields are estimates, and server rules can differ. Purchases require player confirmation; the addon does not automatically buy or process items.

## Install and open

1. Close the game and extract the archive into `Interface\AddOns`.
2. Check that `ManaCode_AuctionScan\ManaCode_AuctionScan.toc` sits directly inside that folder.
3. Start the game and open the **Market** auction tab. Open your profession window once on each character to read known recipes.

When updating from an earlier version, restart the game completely: new files were added, `/reload` is not enough.

There are no slash commands: everything is in the interface. **Market scan** sits in the footer of the Market tab; **Stop** appears during a scan. The settings window opens from the minimap button, the interface options (AddOns tab) or the gear in the header. It includes storage limits, request interval controls, the ledger and mail buttons. **Tour** and **Market guide** open directly from the header. If saved data is lost, settings open with **Restore from copy** and **Accept as is**.

Scans and the ledger are saved in `AuctionScanDB` on logout or `/reload`. Raw scans are kept for about 30 days and up to about 150 MiB; older ones are removed after the next scan, while the latest full-market scan of each realm and faction, the ledger and the disenchanting journal are kept. Back up your SavedVariables before changing installations.

Bug reports: [GitHub issues](https://github.com/dmitriinosach/-MANACODE-MarketBasedAuction/issues) or [Discord](https://discord.gg/CYnxS6R9qY). Include the addon version, client language, steps and the full Lua error, if any.


## What's new in 0.11.0-beta.1

**Update.** Restart the game after installing. Russian and English follow the client language.

**Markets and paths.** Apply obtaining paths to a Batch. Compare vendor trades and currency values. Batch shows the product, margin, nested materials and character stock.

**Shopping and ledger.** Shopping plans use whole stacks and a unit-price limit. Track crafting, processing and resale; history arrows restore selection and settings.

**Small fixes.** Added a tour, guide and window themes. Fixed reagent overlaps and long scans. Raw scans are kept for about a month; ledger records are preserved.
