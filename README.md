# BetterBartender

Vlastní akční lišty pro **Bradavice Online** (klient WoW 3.3.5a). Rozhraní serveru ukazuje
jen pět lišt po 12 políčkách, hra jich ale má 120. BetterBartender je zpřístupní všechna:
lišty si poskládáš, jak chceš, a na každé políčko dáš vlastní klávesu.

*Custom action bars for the Bradavice Online server (WoW 3.3.5a client): any number of
buttons and columns, bars moved with the mouse, a key for every button. The addon talks
Czech.*

Autor: **Jim Craft**

## Co umí

- **Panely podle sebe:** počet políček, počet sloupců, velikost a mezery. Nových panelů
  přidáš, kolik chceš, dokud stačí 120 políček hry.
- **Přesouvání myší** s přichycením k ostatním panelům a ke středu obrazovky. Šipkami
  posuneš panel o jeden pixel. Okno ukazuje, jak daleko od středu panel je, a čáry
  středem obrazovky zezelenají, když je přesně uprostřed.
- **Klávesy na každé políčko:** klávesnice, kolečko myši i tlačítka myši 3 až 5, se
  Shiftem, Ctrl nebo Alt. Skrytý panel na své klávesy reaguje dál.
- **Vzhled jako rozhraní serveru** (BOCoreUI), i s popisky kouzel a cooldowny maker,
  kterými se na serveru sesílají kouzla.
- **Přepínání hlavní lišty** podle postoje a ve vozidle jako ve hře.
- **Každá postava má své rozložení.** Rozložení a klávesy jdou zkopírovat z jiné postavy.
- **Bez rizika:** akce v políčkách drží server a addon je nemění. Klávesy si ukládá zvlášť,
  nastavení hry nepřepisuje. Když addon vypneš, vrátí se původní lišty i s původními
  klávesami.

## Instalace

1. Stáhni `BetterBartender-1.0.0.zip` z
   [posledního vydání](https://github.com/MichaelGrznar/BetterBartender/releases/latest).
2. Rozbal ho do `Interface\AddOns\` ve složce hry. Vznikne složka `BetterBartender`.
   (ZIP z tlačítka **Code** obsahuje složku `BetterBartender-main`: tu musíš přejmenovat
   na `BetterBartender`, jinak ji hra nenačte.)
3. Spusť hru znovu (nový addon načte jen nové spuštění, `/reload` nestačí).
4. Při prvním vstupu do hry addon převezme lišty a klávesy, které máš teď na obrazovce.

## Ovládání

| Příkaz | Co dělá |
| --- | --- |
| `/bbt` | otevře nebo zavře režim úprav |

Tlačítko u minimapy: levý klik režim úprav, pravý klik přiřazování kláves, tažením ho
posuneš.

V režimu úprav klikni na panel a v okně nastav počet políček, sloupce, velikost a mezery.
Panel přesuneš tažením. Tlačítka **Nový panel** a **Smazat panel** jsou dole v okně.
Smazaný panel nic neztratí: akce i klávesy zůstanou uložené u políček a vrátí se, až je
dostane jiný panel.

## Dobré vědět

- V boji se lišty upravovat nedají (hra to nedovolí). Otevřený režim úprav se při začátku
  boje sám zavře.
- Nespouštěj zároveň Bartender4: používá stejná jména tlačítek.
- Addon je psaný pro rozhraní serveru Bradavice Online (BOCore, BOCoreUI) a jinde
  vyzkoušený není.
- Nastavení je v `WTF\Account\<účet>\SavedVariables\BetterBartender.lua`.

## Licence

[MIT](LICENSE): addon smíš volně používat, upravovat i šířit, jen v něm nech poznámku
o autorovi a licenci.
