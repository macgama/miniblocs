# Pagina Steam di MiniBlocs (italiano)

Testi pronti da incollare in Steamworks (Modifica pagina del negozio → Italian). I blocchi
di codice usano il markup di Steam (BBCode) e si incollano così come sono. La versione
francese è in [page-steam-fr.md](page-steam-fr.md), le istruzioni in [README.md](README.md).

Nota: il gioco è tradotto in italiano (Opzioni → Gioco → Lingua). Prima di pubblicare,
passare una volta ogni schermata in italiano.

## Informazioni di base

| Campo Steamworks | Valore |
|---|---|
| Nome | MiniBlocs |
| Sviluppatore | ManiGames |
| Editore | Lo stesso (autopubblicato) |
| Data di uscita | «2027» (indicativa, da precisare) |
| Generi | Simulazione, Strategia, Indie |
| Modalità | Giocatore singolo (il multigiocatore arriverà dopo: non spuntare ancora) |
| Controller | Supporto parziale del controller, Steam Deck testato a 1280 × 800 (vedi docs/succes-manette.md) |
| Funzioni Steam | Obiettivi di Steam (62, succes-steam.csv) e Steam Workshop (docs/partage.md): da spuntare quando GodotSteam sarà nel gioco |
| Lingue | Italiano (interfaccia, sottotitoli) |
| Sito web | https://www.manigames.online |

## Descrizione breve

Mostrata sotto la capsula, al massimo 300 caratteri (questa ne ha 282).

```
Scegli un punto qualsiasi della Terra, posa il municipio e costruisci una città viva su un terreno reale, un metro quadro alla volta. Strade, reti, abitanti che nascono, lavorano e votano, parchi divertimenti, zoo e squadra di calcio: sei il sindaco... finché gli elettori vorranno.
```

## Descrizione lunga («Informazioni sul gioco»)

```
[h2]La tua città, ovunque sulla Terra[/h2]
Fai girare il globo, cerca la tua città, una valle alpina o una costa in capo al mondo, e comincia. Il terreno è reale, e così i boschi, i campi e i fiumi. L'unica differenza con la realtà: nessuno ha ancora costruito niente. Tocca a te.

Si gioca su caselle di un metro quadro, in scala reale. Una casa è grande come una casa, una strada di campagna è larga come una strada di campagna, e un tragitto di 10 km dura quanto deve durare.

[h2]Qualche pioniere, un municipio, e si parte[/h2]
Arrivi con un centinaio di fondatori, un accampamento e un budget che sembra enorme fino alla prima fattura delle fogne. Posa il municipio, traccia le prime strade, allaccia luce e acqua e guarda i cantieri avanzare in tempo reale, un operaio alla volta.

[list]
[*][b]Costruisci a modo tuo[/b]: oltre 700 edifici in 29 stili da tutto il mondo, zone in cui la città cresce da sola, oppure il Laboratorio per progettare i tuoi edifici muro dopo muro (384 materiali, 27 aperture, 12 tipi di tetto), arredamento compreso.
[*][b]Strade e trasporti[/b]: strade curve, incroci, ponti e gallerie sul terreno reale, ferrovia, sentieri, vie d'acqua, aeroporti. Autobus, tram, metropolitane, treni, navi e aerei tra 131 veicoli, con linee che fanno guadagnare (o perdere) soldi.
[*][b]Reti che si vedono[/b]: elettricità, acqua, fogne, fibra e antenne 4G/5G, giri di raccolta dei rifiuti. Se un quartiere non è allacciato, i suoi abitanti te lo faranno sapere.
[/list]

[h2]Abitanti, non statistiche[/h2]
Ogni abitante ha un'età, una famiglia, un curriculum, un lavoro e un budget. Va a scuola, lavora in panetteria o in ospedale, si sposa, invecchia e finisce al cimitero della città (prevedi un'impresa di pompe funebri). Seguine uno durante la giornata, cammina per strada in terza o prima persona, sali su un autobus o mettiti al volante.

[list]
[*]Tenore di vita, soddisfazione, opinioni degli abitanti, e manifestazioni quando le cose vanno male.
[*]Servizi pubblici, più vigili del fuoco, ambulanze e polizia che circolano sulle tue strade.
[*]Giorno e notte, meteo, stagioni, fusi orari reali: le campane suonano a mezzogiorno, e il gallo all'alba.
[/list]

[h2]Sindaco... fino alle prossime elezioni[/h2]
Fissa le tasse, chiedi prestiti, emana ordinanze per ogni quartiere (zone 30, isole pedonali, notti tranquille...) e raggiungi gli obiettivi del tuo paese. Poi gli elettori vanno alle urne. Se la tua lista perde, puoi ancora costruire, ma è il nuovo consiglio a decidere le impostazioni. In caso di sconfitta suona un trombone triste.

La città cresce? Fonda paesi vicini, ognuno con la propria cassa, e affidali al pilota automatico se preferisci concentrarti sulla tua capitale.

[h2]Qualcosa per il fine settimana degli abitanti[/h2]
[list]
[*][b]Parchi divertimenti[/b] con editor di montagne russe e scivoli d'acqua.
[*][b]Zoo[/b] con recinti e 34 specie.
[*][b]Musei[/b]: 208 opere, 24 temi espositivi.
[*][b]Spettacoli[/b]: cinema, teatri, sale da concerto, studi cinematografici.
[*][b]Squadra di calcio[/b]: rosa, trasferimenti, un campionato dal regionale fino alla massima serie, partite giocate nel tuo stadio.
[*]Mercati, feste di paese, campi sportivi, spiagge e 160 decorazioni da spargere col pennello.
[/list]

[h2]E dietro, l'economia[/h2]
Fattorie e raccolti, cave a gradoni, fabbriche, camion di consegna: le risorse si producono, si trasportano e si vendono. Niente è gratis, tranne forse il buono dello Stato per la tua prima centrale.

[h2]Una sandbox con regole (scelte da te)[/h2]
Gioca in modalità Normale o apri il pannello Admin: soldi iniziali o illimitati, costo delle costruzioni, velocità del tempo, esaurimento delle risorse, edifici sbloccati. Nessun game over improvviso: una città indebitata rallenta, non crolla.

[h2]In arrivo[/h2]
MiniBlocs è fatto da un solo sviluppatore. Prossimi passi: una mappa sempre accessibile da condividere con gli amici, poi una mappa del mondo condivisa in cui ogni giocatore è sindaco della propria città, altri sport, catastrofi e turismo.
```

## Punti di forza (social, cartella stampa)

- Tutto il pianeta è giocabile: terreno reale, biomi reali (ESA WorldCover), fiumi reali, terra vergine.
- Scala reale, caselle da 1 m², tempo coerente (1 giorno di gioco = 1 minuto di default).
- Oltre 700 edifici, 29 stili, 131 veicoli, 160 decorazioni, editor libero di costruzione e arredamento.
- Abitanti simulati uno per uno: famiglie, lavoro, scuola, invecchiamento, morte.
- Reti complete: elettricità, acqua, fogne, telecomunicazioni, rifiuti.
- Elezioni, paesi, più città con la propria cassa, pilota automatico.
- Vista a livello della strada in terza e prima persona, guida dei veicoli.
- Parchi divertimenti, zoo, musei, luoghi di spettacolo, squadra di calcio.
- Musica originale: *Valzer del permesso di costruire*, *Blues della buca*, *Consiglio comunale (in ritardo)*...
- Demo guidata di 30 minuti.
- 62 obiettivi, controller e Steam Deck, condivisione delle creazioni (Workshop).
- In italiano, inglese, francese, tedesco e spagnolo.

## Slogan

- «Tutta la Terra. Senza permesso di costruire. Be', quasi.»
- «Terreno vero. Tasse vere. Buche vere.»
- «Sei il sindaco. Fino alle elezioni.»
- «Il city builder in cui tutto il pianeta è il tuo cantiere.»
- «1 m² per casella, 510 milioni di km² da urbanizzare. Quando cominciamo?»
- «Costruire, gestire e spiegare al consiglio perché il ponte finisce in un campo.»

## Tag Steam

Stessa lista della pagina francese (i tag si impostano una volta, in inglese): City Builder,
Simulation, Building, Sandbox, Management, Economy, Strategy, Open World, Realistic,
Life Sim, Transportation, Trains, Low Poly, Singleplayer, Relaxing, Soccer, Agriculture,
Third Person, Indie, 3D.

## Requisiti di sistema (Windows)

Stime da verificare su PC reali prima dell'uscita. Il gioco usa il renderer Vulkan di
Godot (Forward+).

```
[h2]Minimi[/h2]
[list]
[*][b]Sistema operativo:[/b] Windows 10 a 64 bit
[*][b]Processore:[/b] 4 core, 3 GHz (Intel Core i5-6500 / AMD Ryzen 3 1200)
[*][b]Memoria:[/b] 8 GB di RAM
[*][b]Scheda video:[/b] compatibile Vulkan, 2 GB (NVIDIA GTX 1050 / AMD RX 560 / Intel Iris Xe)
[*][b]Memoria di archiviazione:[/b] 2 GB di spazio disponibile
[*][b]Rete:[/b] connessione a Internet la prima volta che si gioca in un luogo (terreno e biomi vengono scaricati, poi tenuti in cache)
[/list]

[h2]Consigliati[/h2]
[list]
[*][b]Sistema operativo:[/b] Windows 10 o 11 a 64 bit
[*][b]Processore:[/b] 6 core (Intel Core i5-10400 / AMD Ryzen 5 3600)
[*][b]Memoria:[/b] 16 GB di RAM
[*][b]Scheda video:[/b] NVIDIA GTX 1660 / AMD RX 5600 XT, 6 GB
[*][b]Memoria di archiviazione:[/b] 4 GB di spazio disponibile (SSD)
[*][b]Rete:[/b] connessione a Internet a banda larga
[/list]
```

## Accesso anticipato (se scelto)

**Perché l'accesso anticipato?**
MiniBlocs è fatto da una sola persona e il gioco è già grande. Le opinioni dei giocatori
decideranno cosa rifinire per primo, quali edifici mancano per la loro parte di mondo e
come deve funzionare la mappa condivisa.

**Per quanto tempo, all'incirca, il gioco resterà in accesso anticipato?**
Circa un anno, a seconda dei riscontri.

**In cosa differirà la versione completa?**
La mappa tra amici, poi la mappa del mondo condivisa, altri sport per il club, catastrofi
e stagioni più marcate, turismo, altre lingue.

**Qual è lo stato attuale della versione in accesso anticipato?**
Un gioco completo per giocatore singolo: fondazione, crescita fino alla grande città, reti,
abitanti, elezioni, più città, svago e squadra di calcio. La demo guidata dura 30 minuti.

**Il prezzo cambierà durante e dopo l'accesso anticipato?**
Il prezzo aumenterà leggermente all'uscita della versione completa.

**Come pensate di coinvolgere la community?**
Con le discussioni di Steam, un server Discord e sondaggi a ogni aggiornamento.

## Note legali

```
© 2027 ManiGames. Terreno: Mapzen Terrain Tiles (AWS Open Data: SRTM, GMTED, ETOPO1, EU-DEM). Biomi: ESA WorldCover 2021 (CC BY 4.0). Corsi d'acqua: © collaboratori di OpenStreetMap (ODbL). Città: GeoNames (CC BY 4.0). Bandiere: flag-icons (MIT). Realizzato con Godot Engine (MIT).
```
