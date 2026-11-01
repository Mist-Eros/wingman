# Wingman — 500 de întrebări și răspunsuri

**Material de pregătire pentru demo și interviu.** 500 de întrebări cu răspunsuri scurte, tehnice și non-tehnice, structurate pe produs, operațiuni, AI, backend, testare și business.

> Document generat din `docs/qa/` și verificat automat să conțină **exact 500** de perechi întrebare–răspuns. Faptele reflectă build-ul cu commit-ul `55f52fc` și starea demo curentă.

## Cum îl folosești

1. Citește întâi **Fapte-cheie de memorat** (la final) — sunt numerele și comenzile pe care le repeți înainte de demo.
2. Pentru interviu, exersează secțiunile 1, 2, 5 și 10 cu voce tare.
3. Pentru întrebări tehnice, folosește secțiunile 3, 4, 8 și 9.
4. Nu învăța răspunsurile pe de rost: învață cele 4–5 principii și reformulează.

## Cuprins

1. [Produs, problemă și pitch](#1.-produs-problema-si-pitch) — 50 întrebări
2. [Roluri, conturi și permisiuni](#2.-roluri-conturi-si-permisiuni) — 50 întrebări
3. [Taxonomie, meniu și raportare](#3.-taxonomie-meniu-si-raportare) — 50 întrebări
4. [AI, Whisper și LLM](#4.-ai-whisper-si-llm) — 50 întrebări
5. [Dispecerat, quorum și timp real](#5.-dispecerat-quorum-si-timp-real) — 50 întrebări
6. [Recompense, statistici și timere](#6.-recompense-statistici-si-timere) — 50 întrebări
7. [UI/UX, limbă și accesibilitate](#7.-ui/ux-limba-si-accesibilitate) — 50 întrebări
8. [Backend, arhitectură și securitate](#8.-backend-arhitectura-si-securitate) — 50 întrebări
9. [Testare, demo și depanare](#9.-testare-demo-si-depanare) — 50 întrebări
10. [Interviu, tradeoff-uri și roadmap](#10.-interviu-tradeoff-uri-si-roadmap) — 50 întrebări

[Fapte-cheie de memorat](#fapte-cheie-de-memorat)

---

## 1. Produs, problemă și pitch

### 1. Ce este Wingman?

**Răspuns:** Wingman este o aplicație de raportare și răspuns la incidente pentru aeroporturi: angajații trimit un incident prin voce sau meniu, AI-ul îl clasifică, iar dispecerul și echipajele îl rezolvă în timp real.

### 2. Ce problemă rezolvă Wingman?

**Răspuns:** Reduce timpul dintre momentul în care un angajat observă o problemă și momentul în care echipa potrivită ajunge la ea, înlocuind telefoanele, radio-ul și mesajele pierdute cu un flux unic și urmăribil.

### 3. Pentru cine este Wingman?

**Răspuns:** Pentru personalul aeroportuar care raportează incidente, pentru dispeceratul care prioritizează și pentru echipajele de intervenție: securitate, pompieri, medical, mentenanță, operațiuni, terminal, IT, bagaje și airside.

### 4. De ce un aeroport?

**Răspuns:** Aeroporturile au multe echipe, zone sensibile și incidente care se suprapun; o informație trimisă echipei greșite sau prea târziu costă minute prețioase.

### 5. De ce Craiova?

**Răspuns:** Craiova este aeroportul internațional folosit ca scenariu concret în demo; coordonatele, zonele și taxonomia sunt adaptate aeroportului, nu inventate generic.

### 6. Care este pitch-ul într-o propoziție?

**Răspuns:** „Un incident, o voce, echipa potrivită în câteva secunde.”

### 7. Care sunt cele trei avantaje principale?

**Răspuns:** Raportare rapidă fără formular, rutare automată către departamentul potrivit și urmărire completă până la confirmarea rezolvării.

### 8. Ce înseamnă incident response în contextul aplicației?

**Răspuns:** Ciclul complet: observare → raportare → clasificare → dispatch → preluare de către echipaj → vot de rezolvare → confirmare admin → istoric și statistici.

### 9. Care este fluxul end-to-end?

**Răspuns:** Reporterul apasă microfonul sau alege din meniu, backendul clasifică, tichetul ajunge la echipele primare, un responder pe departament preia, echipajul votează rezolvarea, iar cazurile high/critical primesc confirmarea adminului.

### 10. Cât durează un raport vocal?

**Răspuns:** În demo, transcrierea unui clip scurt durează aproximativ 1–2 secunde după ce modelul Whisper este încărcat; clasificarea LLM adaugă de obicei sub o secundă.

### 11. Ce înseamnă taxonomie închisă?

**Răspuns:** AI-ul poate alege doar dintr-o listă fixă de 16 tipuri de incidente; nu inventează coduri și nu produce categorii imposibile.

### 12. De ce taxonomie închisă și nu text liber?

**Răspuns:** Pentru că rutarea, departamentele, urgența și statisticile trebuie să fie consistente; textul liber rămâne în transcript, dar decizia operațională folosește un cod controlat.

### 13. Care este rolul dispecerului?

**Răspuns:** Dispecerul vede toate tichetele, poate reclassifica, respinge, urmări timpul și confirma rezolvarea cazurilor high/critical.

### 14. Care este rolul echipajului?

**Răspuns:** Fiecare echipaj vede incidentele pentru departamentul lui, preia tichetul, lucrează la el și votează când consideră că problema este rezolvată.

### 15. Ce face adminul?

**Răspuns:** Adminul are acces total, vede dashboardul, poate confirma rezolvarea cazurilor periculoase și poate verifica statisticile și istoricul.

### 16. Ce face reporterul?

**Răspuns:** Reporterul descrie incidentul prin voce sau meniu, poate adăuga o poză, verifică transcriptul și îl poate edita inclusiv după trimitere.

### 17. Ce se întâmplă când un raport este critic?

**Răspuns:** Tichetul este marcat critical, este trimis imediat echipelor primare, iar după votul de rezolvare trece prin confirmarea adminului înainte de a fi închis definitiv.

### 18. Ce înseamnă quorum?

**Răspuns:** Numărul minim de aprobări necesare pentru ca un tichet să fie considerat rezolvat; regula de bază este un responder pentru fiecare departament primar.

### 19. De ce un singur responder per departament?

**Răspuns:** Pentru a evita ca aceeași echipă să trimită mai mulți oameni pe același tichet și pentru a păstra rezerva disponibilă pentru alte incidente.

### 20. De ce este nevoie de confirmarea adminului?

**Răspuns:** Pentru incidentele high/critical, votul echipajului nu este suficient; un om cu vedere de ansamblu trebuie să verifice că rezolvarea este reală înainte de închidere.

### 21. Cum se vede că un tichet este rezolvat?

**Răspuns:** Statusul devine `resolved` doar după votul necesar (și confirmarea adminului la high/critical), cardul dispare din coada activă și apare în istoric și statistici.

### 22. Ce se întâmplă dacă AI-ul greșește?

**Răspuns:** Dispecerul poate reclassifica tichetul, poate schimba urgența și poate respinge un raport; utilizatorul poate corecta orice cuvânt din transcript înainte de trimitere.

### 23. Ce se întâmplă dacă serverul cade?

**Răspuns:** Build-ul live arată eroare de conexiune și reîncearcă; pentru demo există build-ul local mock, care rulează board-ul complet în memorie, fără server.

### 24. Ce este modul local mock?

**Răspuns:** Un mod al aplicației care încarcă cele cinci tichete demo direct în memorie și aplică instant preluarea, votul și confirmarea, fără REST, WSS sau adb reverse.

### 25. De ce ai făcut modul local mock?

**Răspuns:** Pentru că demo-ul nu trebuie să depindă de cablu, Wi-Fi, reporniri de backend sau întârzieri de rețea; modul local garantează un flux fluid pentru juriu.

### 26. Ce date sunt demo în aplicație?

**Răspuns:** Conturile hardcodate, cele cinci tichete seed, dashboardul și statisticile demo; nu există date reale de pasageri sau date personale reale.

### 27. Ce nu este Wingman?

**Răspuns:** Nu este un sistem de producție certificat, nu înlocuiește procedurile de siguranță ale aeroportului și nu este conectat la sisteme reale de operare sau la servicii de urgență.

### 28. Ce ar fi nevoie pentru producție?

**Răspuns:** Autentificare reală (SSO/MFA), audit, permisiuni fine, integrare cu sistemele aeroportuare, SLA-uri, monitorizare, backup, conformitate și un proces de aprobare operațional.

### 29. Care este KPI-ul principal?

**Răspuns:** Timpul mediu de la raportare la preluare și timpul mediu de la raportare la rezolvare, plus procentul de incidente rutate corect din prima.

### 30. Cum măsori succesul?

**Răspuns:** Privești AHT (average handling time), numărul de tichete rezolvate, timpul până la primul responder, rata de re clasificare și feedback-ul echipajelor.

### 31. Care este ROI-ul pentru un aeroport?

**Răspuns:** Mai puține minute pierdute pe telefoane și coordonare, intervenții mai rapide, mai puține incidente uitate și un istoric care ajută la prevenție.

### 32. Cine cumpără o astfel de soluție?

**Răspuns:** Operatorul aeroportuar, departamentul de operațiuni, safety/security și echipele de facility management; într-o versiune comercială, și operatori de terminal sau ground handling.

### 33. Cine o folosește zilnic?

**Răspuns:** Dispecerii, echipajele de intervenție și angajații din terminal, bagaje, mentenanță, securitate și airside.

### 34. Cum se adoptă în realitate?

**Răspuns:** Cu un pilot într-un singur terminal, conturi pe departamente, training scurt de 15 minute și KPI urmăriți săptămânal; abia apoi extindere la întregul aeroport.

### 35. Care este povestea demo-ului?

**Răspuns:** Un angajat vede fum lângă o poartă, raportează vocal, AI-ul îl clasează ca incendiu, pompierii și securitatea sunt alertate, un responder din fiecare departament preia, iar adminul confirmă rezolvarea.

### 36. Care este cel mai puternic moment din demo?

**Răspuns:** Când un raport vocal ambiguu devine un tichet cu echipa corectă, iar apoi se vede în dashboard și pe telefon în aceeași secundă.

### 37. Care este riscul principal al produsului?

**Răspuns:** Un incident real să fie ratat sau închis prematur; de aceea există confirmare admin, status explicit, istoric, urgențe și posibilitatea de reclassificare.

### 38. Care este planul de mitigare?

**Răspuns:** Mod local pentru demo, fallback determinist când AI-ul nu răspunde, gărzi de context pentru fraze ambigue, validare pe backend și teste automate.

### 39. Ce ai învățat făcând aplicația?

**Răspuns:** Că în domenii operaționale, claritatea și predictibilitatea bat inteligența spectaculoasă; un flux simplu și verificabil este mai valoros decât un AI care impresionează dar greșește.

### 40. De ce numele Wingman?

**Răspuns:** „Wingman” sugerează un coleg care te acoperă și te ajută să reacționezi rapid, exact rolul aplicației față de personalul aeroportuar.

### 41. Ce înseamnă „airport incident response”?

**Răspuns:** Totalitatea acțiunilor declanșate de un incident: raportare, clasificare, alertare, intervenție, rezolvare și învățare din date.

### 42. Ce categorii mari de incidente acoperă?

**Răspuns:** Siguranță/incendiu, securitate, mentenanță, operațiuni, ground handling, aeronave/tehnic, pasageri/terminal și mediu/meteo.

### 43. Cât de mare este taxonomia?

**Răspuns:** 16 tipuri operaționale închise, fiecare cu urgență implicită, departamente primare și departamente standby.

### 44. Ce înseamnă 8×8×8?

**Răspuns:** Meniul de rezervă are 8 categorii, fiecare cu 8 subcategorii, fiecare cu 8 probleme concrete: 512 combinații posibile.

### 45. Câte combinații are meniul?

**Răspuns:** 8 × 8 × 8 = 512 combinații, fiecare mapată la un cod operațional.

### 46. Ce este un incident major?

**Răspuns:** Un incident cu potențial de rănire, incendiu, securitate sau întrerupere majoră; în aplicație este tratat ca high sau critical și cere confirmare admin la închidere.

### 47. Ce este un incident mediu?

**Răspuns:** O problemă care afectează operarea dar nu pune imediat vieți în pericol, cum ar fi o scurgere sau o bandă defectă; poate fi rezolvată de echipa primară.

### 48. Ce este un incident minor?

**Răspuns:** O problemă de curățenie, aglomerare sau facility care nu necesită intervenție de urgență și poate fi rezolvată în flux normal.

### 49. Ce face sistemul diferit de un formular clasic?

**Răspuns:** Formularul colectează text; Wingman transformă textul în decizie operațională, rutare, alertă, stare în timp real și istoric măsurabil.

### 50. Care este concluzia pitch-ului?

**Răspuns:** Wingman transformă o observație vocală într-un răspuns coordonat, măsurabil și verificabil, fără să înlocuiască oamenii din teren.

## 2. Roluri, conturi și permisiuni

### 51. Câte conturi are aplicația?

**Răspuns:** Zece conturi demo: un admin/dispecer și nouă conturi de echipaj, câte unul pentru fiecare departament de răspuns.

### 52. Care sunt conturile de echipaj?

**Răspuns:** Security, fire/rescue, medical, maintenance, operations, terminal services, IT, baggage și airside.

### 53. Care este contul de admin?

**Răspuns:** `admin` / `admin123`, cu numele Andy Admin și acces total la dashboard, istoric și confirmări.

### 54. Care este diferența dintre admin și dispecer?

**Răspuns:** În demo, adminul cumulează rolul de dispecer cu acces total; un dispecer normal ar avea dashboardul, dar fără unele acțiuni administrative.

### 55. Cum se autentifică utilizatorii?

**Răspuns:** Prin conturile demo afișate pe ecranul de login; parola este verificată față de un hash salted SHA-256, nu față de text clar.

### 56. De ce parolele sunt hash-uite dacă sunt demo?

**Răspuns:** Pentru a demonstra o practică corectă de stocare și pentru a nu avea parole în clar în cod, chiar dacă utilizatorii le văd pe cardul de demo.

### 57. Ce se întâmplă după login?

**Răspuns:** Sesiunea este salvată, aplicația deschide ecranul rolului (reporter, dispecer sau echipaj), iar utilizatorul poate reveni la selector cu back.

### 58. Sesiunea supraviețuiește repornirii aplicației?

**Răspuns:** Da, sesiunea este persistată și restaurată; la deschidere apare cardul „Bine ai revenit” cu opțiunea Continuă.

### 59. Cum se schimbă contul?

**Răspuns:** Din ecranul de rol se poate ieși în rol, iar selectorul de conturi redevine disponibil; nu trebuie reinstalată aplicația.

### 60. Cine poate raporta un incident?

**Răspuns:** Orice utilizator autentificat poate raporta; rolul controlează în principal ce notificări primește, nu dreptul de a raporta.

### 61. Cine primește notificări?

**Răspuns:** Echipajele primesc notificări doar pentru tichetele din departamentele lor primare; adminul/dispecerul vede tot.

### 62. Ce sunt departamentele primare?

**Răspuns:** Echipele care trebuie să răspundă efectiv la incident și din care este necesar un responder pentru quorum.

### 63. Ce sunt departamentele standby?

**Răspuns:** Echipe avertizate pentru context, dar care nu sunt chemate automat și nu blochează rezolvarea; ele pot fi implicate dacă situația escaladează.

### 64. De ce există un singur cont per departament?

**Răspuns:** Pentru demo și pentru a impune o regulă clară de răspuns: o echipă, un flux, fără conflicte de identitate între mai mulți membri ai aceluiași departament.

### 65. Ce se întâmplă dacă doi oameni încearcă să preia din același departament?

**Răspuns:** Serverul respinge al doilea join cu conflict 409; un singur responder per departament primar poate prelua tichetul.

### 66. Poate un utilizator să preia un tichet din alt departament?

**Răspuns:** Nu; join-ul este permis doar pentru un departament primar al tichetului și doar pentru departamentul contului.

### 67. Cum știe aplicația ce departament are contul?

**Răspuns:** Fiecare cont are un set de departamente în `Session`; ecranul de echipaj folosește acel set pentru filtrare și pentru preluare.

### 68. Ce vede un membru al echipajului?

**Răspuns:** Doar tichetele active pentru departamentul lui, cu urgență, locație, echipe necesare, timer, voturi și acțiuni de preluare/vot.

### 69. Ce vede dispecerul?

**Răspuns:** Toată coada activă, filtre, detalii, hartă/foto, istoric, statistici, acțiuni de respingere/reclasificare și confirmare admin.

### 70. Ce vede reporterul?

**Răspuns:** Fluxul de raportare vocală sau meniu, transcriptul editabil, locația, poza opțională și ecranul de confirmare/trimis.

### 71. Ce este ecranul „Contul meu”?

**Răspuns:** Un rezumat al punctelor și al activității utilizatorului, cu două categorii: Raportare și Rezolvare.

### 72. Cine poate confirma rezolvarea unui tichet high/critical?

**Răspuns:** Doar un utilizator cu rol de dispecer/admin, prin acțiunea de confirmare a rezolvării.

### 73. Pot echipajele să închidă singure un incident critical?

**Răspuns:** Nu; după quorum, tichetul intră în `pending_resolution` și așteaptă confirmarea adminului.

### 74. Pot echipajele să închide un incident low/medium?

**Răspuns:** Da, dacă quorum-ul este atins; nu este necesară confirmarea adminului pentru nivelurile normale.

### 75. Ce face un echipaj când nu poate rezolva?

**Răspuns:** Poate lăsa tichetul în lucru, poate cere sprijin verbal și poate permite dispecerului să reclassifice sau să escaladeze.

### 76. Se poate retrage un responder din tichet?

**Răspuns:** Da, există acțiunea „retrage-mă”; votul lui este șters, iar tichetul revine în coadă dacă nu mai are responderi.

### 77. Ce se întâmplă dacă un responder pleacă după ce a votat?

**Răspuns:** La leave, votul și contribuția lui sunt eliminate, iar statusul se recalculează.

### 78. Ce se întâmplă dacă nimeni nu preia un tichet?

**Răspuns:** Tichetul rămâne în coada activă și este vizibil echipei; dashboardul îl arată, iar timpul continuă să curgă.

### 79. Există escaladare automată după timp?

**Răspuns:** Nu în demo; dispecerul vede timpul și poate reclassifica/respinge, iar echipele sunt alertate imediat pentru departamentele primare.

### 80. Cum se face reassignarea unui tichet?

**Răspuns:** Dispecerul poate reclassifica tipul și/sau urgența; noile departamente primare rezultă din taxonomie.

### 81. Ce este un „responder”?

**Răspuns:** Un membru al unei echipe primare care a preluat tichetul și poate vota rezolvarea.

### 82. Care este relația dintre responder și vot?

**Răspuns:** Doar un crew member care a preluat tichetul poate vota; un vot fără join este respins.

### 83. Ce înseamnă „un singur responder per departament” în practică?

**Răspuns:** Pentru fiecare departament primar este necesar exact un om; al doilea om din același departament este respins.

### 84. Cum se vede această regulă în UI?

**Răspuns:** Cardul arată „Nimeni nu a preluat încă”, apoi „Preia”; după preluare arată progresul voturilor și butonul „Rezolvat”.

### 85. Cum se vede un tichet deja preluat de alt departament?

**Răspuns:** Rămâne vizibil dacă ești într-un alt departament primar, dar nu poți prelua din departamentul deja ocupat.

### 86. Ce se întâmplă dacă un utilizator dă tap de două ori pe „Preia”?

**Răspuns:** UI-ul dezactivează butonul cât timp cererea este în curs, iar serverul tratează idempotent același crew.

### 87. Ce se întâmplă dacă dă tap de două ori pe „Rezolvat”?

**Răspuns:** Al doilea vot nu este numărat din nou; UI-ul marchează „Ai votat” și serverul ignoră dublura.

### 88. Cum se face diferența între „Preia” și „Rezolvat”?

**Răspuns:** „Preia” creează join-ul și trece tichetul în lucru; „Rezolvat” înregistrează votul de rezolvare.

### 89. Ce se întâmplă când un tichet este respins de dispecer?

**Răspuns:** Statusul devine `denied`, nu mai apare în coada activă și rămâne în istoric cu motivul.

### 90. Cine poate respinge un tichet?

**Răspuns:** Dispecerul/adminul, din dashboard sau din cardul de detaliu.

### 91. Cine poate reclassifica?

**Răspuns:** Dispecerul/adminul; reclassificarea schimbă codul, urgența și departamentele implicate.

### 92. Ce este istoricul?

**Răspuns:** Lista tichetelor închise (rezolvate sau respinse), cu detalii, motiv și timp de rezolvare.

### 93. Cine poate șterge istoricul?

**Răspuns:** Adminul, printr-o acțiune explicită de golire a istoricului; este utilă pentru resetarea demo-ului.

### 94. Ce este „reset date locale”?

**Răspuns:** O acțiune de demo care șterge tichetele și readuce aplicația la starea inițială; în modul local, board-ul este reîncărcat din seed.

### 95. Ce se întâmplă la reset cu conturile?

**Răspuns:** Conturile demo rămân; se resetează datele operaționale, nu identitățile hardcodate.

### 96. Se pot adăuga conturi noi?

**Răspuns:** În demo nu; conturile sunt hardcodate. Producția ar avea un sistem real de identitate și administrare.

### 97. Cum se comportă aplicația cu mai multe telefoane?

**Răspuns:** Fiecare telefon are propria sesiune, dar board-ul live este sincronizat prin backend/WSS; acțiunile apar la toți clienții.

### 98. Ce se întâmplă dacă același cont este folosit pe două telefoane?

**Răspuns:** Ambele pot trimite acțiuni; serverul validează starea, iar UI-ul se resincronizează după răspuns sau eveniment WSS.

### 99. Cum se vede că un cont este admin?

**Răspuns:** Cardul de login are badge-ul ADMIN și textul „Vezi și decizi tot”; după login, dashboardul este accesibil.

### 100. Care este fluxul unui incident mediu în demo?

**Răspuns:** `SF-SPILL` are quorum demo 1; un responder din mentenanță îl preia, votează, iar tichetul devine rezolvat fără confirmare admin.

## 3. Taxonomie, meniu și raportare

### 101. Câte tipuri de incidente există?

**Răspuns:** Șaisprezece tipuri operaționale închise, de la incendiu și FOD până la acces neautorizat, bandă de bagaje, problemă IT și urgență medicală.

### 102. Care sunt cele 16 coduri?

**Răspuns:** `SF-FIRE`, `SF-FOD`, `SF-SPILL`, `SF-EQUIP`, `SC-BAG`, `SC-ACCESS`, `SC-ITEM`, `SC-BEHAV`, `MT-BELT`, `MT-ESC`, `MT-JBRIDGE`, `OP-QUEUE`, `OP-IT`, `OP-MED`, `OP-RESCUE` și `OP-OTHER`.

### 103. Ce reprezintă prefixele codurilor?

**Răspuns:** `SF` = safety/fire, `SC` = security, `MT` = maintenance și `OP` = operations; prefixul este doar o convenție de citire, decizia reală este codul complet.

### 104. Ce categorii mari există?

**Răspuns:** Siguranță/incendiu, securitate, mentenanță, operațiuni, ground handling, aeronave/tehnic, pasageri/terminal și mediu/meteo.

### 105. Care este urgența implicită a unui cod?

**Răspuns:** Fiecare tip are o urgență implicită în taxonomie; AI-ul poate ridica urgența pentru un raport concret, dar nu o poate coborî sub implicit.

### 106. Care sunt nivelurile de urgență?

**Răspuns:** `low`, `medium`, `high` și `critical`, afișate ca verde, galben, portocaliu și roșu.

### 107. De ce `SF-*` și `SC-*` pornesc de la high/critical?

**Răspuns:** Pentru că un incendiu, un corp străin sau o breșă de securitate pot deveni pericole majore; este preferabil să trimiți prea repede echipa decât prea târziu.

### 108. Ce este `OP-OTHER`?

**Răspuns:** Codul de triaj pentru un incident aeroportuar real care nu se încadrează clar în celelalte 15 tipuri; nu este un coș universal pentru orice text.

### 109. Ce este meniul 8×8×8?

**Răspuns:** Un fallback determinist în care reporterul alege 8 categorii, apoi 8 subcategorii, apoi 8 probleme concrete.

### 110. Câte combinații are meniul?

**Răspuns:** 512 combinații (8 × 8 × 8), fiecare cu un cod operațional și o locație implicită.

### 111. De ce există meniul dacă există voce?

**Răspuns:** Pentru situații cu zgomot, microfon indisponibil, Whisper nesigur sau un utilizator care preferă să apese în loc să vorbească.

### 112. Când apare meniul automat?

**Răspuns:** Când al doilea attempt vocal este încă neclar sau când utilizatorul alege explicit „schimbă tipul din meniu”.

### 113. Ce se întâmplă la prima încercare vocală eșuată?

**Răspuns:** Aplicația cere o singură repetare, apoi, dacă rezultatul rămâne neutilizabil, deschide meniul determinist.

### 114. De ce o singură repetare?

**Răspuns:** Pentru a nu transforma un incident într-un loop frustrant; dacă vocea nu funcționează, meniul este mai rapid și mai sigur.

### 115. Ce este transcriptul?

**Răspuns:** Textul brut rezultat din Whisper, împărțit în cuvinte, pe care reporterul îl verifică înainte de trimitere.

### 116. Pot corecta un singur cuvânt?

**Răspuns:** Da; toate cuvintele sunt editabile, inclusiv cele cu încredere mare, nu doar cele galbene.

### 117. Ce înseamnă cuvânt galben?

**Răspuns:** Că Whisper a avut încredere mică în acel cuvânt; rămâne editabil și este marcat vizual pentru verificare.

### 118. Ce înseamnă cuvânt alb/verde?

**Răspuns:** Că transcrierea a avut încredere mai mare; cu toate acestea, rămâne editabil, pentru că utilizatorul are ultimul cuvânt.

### 119. Se poate șterge un cuvânt?

**Răspuns:** Da; înlocuirea cu text gol elimină cuvântul din transcript.

### 120. Se poate adăuga un cuvânt?

**Răspuns:** Da; editezi un cuvânt existent sau folosești câmpul de text pentru a completa raportul.

### 121. Cum arată transcriptul?

**Răspuns:** Ca o listă compactă de chip-uri, cu spațiere redusă și font lizibil, ca să încapă mai mult text pe ecran.

### 122. Ce este sursa raportului?

**Răspuns:** `voice` pentru raportare vocală sau `menu` pentru selecția din meniu; sursa este păstrată pe tichet.

### 123. Ce este `hint_code`?

**Răspuns:** Codul ales explicit de utilizator în meniu; backendul îl folosește ca adevăr operațional când `use_ai=false`.

### 124. Ce este `use_ai=false`?

**Răspuns:** Modul în care serverul nu mai întreabă LLM-ul și folosește codul ales de om; este folosit de meniu și de seed-ul demo.

### 125. Ce se trimite într-un raport?

**Răspuns:** Transcript, sursă, identitatea reporterului, locația (terminal/zonă/coordonate), codul-hint opțional și poza opțională.

### 126. Care este lungimea maximă a transcriptului?

**Răspuns:** 4000 de caractere în schema de raportare; suficient pentru un raport verbal normal, dar limitat pentru a evita payload-uri aberante.

### 127. Care este limita pentru poză?

**Răspuns:** Payload-ul JSON are o limită de 2,5 MB pentru base64; imaginea este comprimată la maximum 1280 px și calitate 60 în aplicație.

### 128. Când se cere poza?

**Răspuns:** Opțional, imediat după raportare, cu un prompt de 5 secunde; poate fi adăugată sau schimbată și după trimitere, cât timp tichetul e activ.

### 129. Se poate trimite raportul fără poză?

**Răspuns:** Da; poza este complet opțională, iar raportul pleacă și dacă utilizatorul sare peste prompt.

### 130. Ce se întâmplă dacă poza nu este confirmată în camera Samsung?

**Răspuns:** Promptul explică faptul că trebuie apăsat OK după shutter și permite retry sau trimitere fără poză.

### 131. Se poate edita raportul după trimitere?

**Răspuns:** Da; ecranul „Raport trimis” are butoanele „Editează textul” și „Adaugă poză” pentru tichetele active.

### 132. De ce numai tichetele active pot fi editate?

**Răspuns:** Pentru că un tichet rezolvat/respins este istoric operațional; modificarea lui ar schimba auditul și statisticile.

### 133. Cine poate edita un tichet?

**Răspuns:** Doar reporterul original; backendul verifică `reporter_id` și respinge alte conturi.

### 134. Editează transcrierea clasificarea?

**Răspuns:** Nu automat; backendul nu re-rulează AI-ul la editare, ca un text modificat să nu schimbe silentios dispatch-ul. Dispecerul poate reclassifica explicit.

### 135. Ce este locația unui tichet?

**Răspuns:** Terminal, zonă, coordonate GPS opționale și o notă; este folosită pentru hartă, dispatch și context.

### 136. Cât de precisă este locația?

**Răspuns:** Depinde de GPS-ul telefonului; aplicația păstrează ultima poziție bună și afișează precizia, iar locația poate fi și textuală.

### 137. Ce este location gate-ul?

**Răspuns:** O regulă care verifică dacă telefonul este în apropierea aeroportului ( aproximativ 2 km în configuratia demo ) înainte de a permite raportarea.

### 138. Ce se întâmplă dacă GPS-ul este oprit?

**Răspuns:** Aplicația explică problema și oferă fie retry, fie continuarea explicită fără locație, în funcție de starea gate-ului.

### 139. Se poate raporta de acasă?

**Răspuns:** În build-ul normal, nu, dacă ești în afara razei; există un bypass temporar de build pentru demo, care expiră.

### 140. Ce este o locație „nespecificată”?

**Răspuns:** O locație pe care utilizatorul nu a putut sau nu a vrut să o ofere; tichetul poate fi trimis, dar dispecerul are mai puțin context.

### 141. Ce se întâmplă dacă același incident este raportat de două ori?

**Răspuns:** În demo sunt create tichete separate; nu există deduplicare automată garantată. Dispecerul poate respinge duplicatul sau îl poate folosi ca semnal suplimentar.

### 142. Ce este confidence?

**Răspuns:** Scorul 0–1 prin care sistemul își exprimă încrederea în clasificare; sub pragul de 0.65 raportul este tratat cu prudență.

### 143. Ce se întâmplă sub pragul de încredere?

**Răspuns:** Raportul poate fi trimis cu confidence redus și ajunge la dispecer pentru verificare; AI-ul nu ascunde incertitudinea.

### 144. Ce este rationale?

**Răspuns:** O explicație scurtă a deciziei, maximum aproximativ 12 cuvinte, afișată în detaliile tichetului pentru audit.

### 145. De ce rationale este util?

**Răspuns:** Pentru că un operator trebuie să poată înțelege de ce sistemul a ales un cod, fără să aibă încredere oarbă în AI.

### 146. Ce este o reclamă falsă sau „fals pozitiv”?

**Răspuns:** Un raport clasificat greșit sau fără substanță; dispecerul îl poate respinge cu motiv, iar acțiunea rămâne în istoric.

### 147. Ce se întâmplă cu tichetul respins?

**Răspuns:** Devine `denied`, iese din coada activă, rămâne în istoric și nu mai poate fi editat.

### 148. Ce se întâmplă cu tichetul rezolvat?

**Răspuns:** Devine `resolved`, primește `resolved_at`, intră în statistici și se afișează în istoricul echipei.

### 149. Care este diferența dintre „trimis” și „dispecerizat”?

**Răspuns:** „Trimis” este momentul creării; „dispecerizat” este starea în care tichetul a fost rutat către echipele primare.

### 150. Ce se întâmplă dacă raportul are o eroare de tip?

**Răspuns:** Utilizatorul poate schimba tipul din meniu înainte de trimitere; după trimitere, dispecerul poate reclassifica.

## 4. AI, Whisper și LLM

### 151. Ce modele AI folosește aplicația?

**Răspuns:** Două modele locale: **faster-whisper small** pe CPU, int8, pentru vorbă → text, și **Ollama qwen2.5:1.5b**, pentru clasificarea raportului în taxonomia închisă.

### 152. De ce AI local și nu un API cloud?

**Răspuns:** Pentru confidențialitate, cost zero per request, latență mică pe laptop și pentru că demo-ul poate rula fără internet sau fără chei API.

### 153. Ce face Whisper?

**Răspuns:** Transformă înregistrarea audio a reporterului în text și returnează probabilități pe cuvinte, folosite pentru a marca incertitudinea.

### 154. Ce face LLM-ul?

**Răspuns:** Citește transcriptul și alege un cod din cele 16, o urgență și o explicație scurtă; nu inventează coduri și nu decide singur cine primește tichetul în afara taxonomiei.

### 155. De ce qwen2.5:1.5b?

**Răspuns:** Este suficient de mic pentru a răspunde rapid pe CPU și suficient de bun pentru o taxonomie închisă; gărzile de context acoperă frazele în care modelul mic ezită.

### 156. De ce nu un model mai mare?

**Răspuns:** Un model de 7B ar fi mai bun semantic, dar mult mai lent pe laptopul demo; arhitectura permite schimbarea modelului prin configurație dacă hardware-ul permite.

### 157. Ce este promptul de sistem?

**Răspuns:** Instrucțiunile care definesc rolul de clasificator, regulile, taxonomia, exemplele și schema JSON obligatorie.

### 158. Ce este temperatura 0?

**Răspuns:** O setare care face răspunsul aproape determinist; pentru un clasificator operațional nu vrei creativitate, vrei consistență.

### 159. De ce răspunsul LLM este JSON?

**Răspuns:** Pentru că backendul are nevoie de câmpuri clare: cod, urgență, confidence și rationale; JSON-ul este validat, nu executat ca text liber.

### 160. Ce se întâmplă dacă LLM-ul returnează JSON invalid?

**Răspuns:** Backendul îl respinge și folosește clasificatorul determinist pe cuvinte-cheie; raportul nu este pierdut.

### 161. Ce se întâmplă dacă Ollama este oprit?

**Răspuns:** Clasificarea trece pe fallback determinist, iar utilizatorul poate folosi meniul; aplicația nu rămâne blocată.

### 162. Ce se întâmplă dacă modelul Whisper lipsește?

**Răspuns:** Endpointul de transcriere răspunde 503 cu un mesaj clar, iar meniul și raportarea text rămân funcționale.

### 163. Ce este warm-up-ul Whisper?

**Răspuns:** Încărcarea modelului în fundal la pornirea backendului, ca prima raportare să nu plătească întârzierea de inițializare.

### 164. Cât durează transcrierea acum?

**Răspuns:** Pe fixture-ul demo de 3.9 secunde, Whisper a măsurat aproximativ 1.2–1.4 secunde, iar endpointul total aproximativ 1.4–1.8 secunde după warm-up.

### 165. De ce Whisper părea uneori că „gândește” foarte mult?

**Răspuns:** Din două motive: modelul se încărca la prima cerere, iar corectarea LLM avea un timeout de 12 secunde. Am încărcat modelul la startup și am limitat corectarea la 3 secunde.

### 166. Ce este corectarea transcriptului de către LLM?

**Răspuns:** O prelucrare opțională care repară doar erori evidente de ASR, diacritice și cuvinte asemănătoare; nu are voie să schimbe fapte, numere sau locații.

### 167. Cât durează corectarea transcriptului?

**Răspuns:** Maximum 3 secunde; dacă modelul nu răspunde în acest timp, se păstrează transcriptul Whisper brut.

### 168. Corectarea poate modifica un număr?

**Răspuns:** Nu; logica de merge protejează numerele și cuvintele cu încredere mare, iar modificările nesigure sunt marcate cu probabilitate mică.

### 169. Ce este un „context guard”?

**Răspuns:** O regulă deterministă care recunoaște intenția din frază și corectează o clasificare greșită a modelului mic pentru cazuri clare.

### 170. Ce exemple de context guards există?

**Răspuns:** „miroase a ars” → incendiu, „nu răspunde” → medical, „blocat cu cineva” → rescue, „net/rețea” → IT, „gard” → acces neautorizat, „ceva pe pistă” → FOD și „scaun rupt” → OP-OTHER.

### 171. De ce context guards dacă există LLM?

**Răspuns:** Pentru că un model de 1.5B poate confunda „lift” cu o defecțiune tehnică atunci când este vorba de o persoană blocată; guard-ul apără cazurile critice.

### 172. Guard-urile nu fac AI-ul prea rigid?

**Răspuns:** Sunt folosite doar pe fraze cu sens clar și verificat; restul textului rămâne în sarcina LLM-ului și a dispecerului.

### 173. Ce este fallback-ul determinist?

**Răspuns:** Un clasificator pe cuvinte-cheie și catalog de incidente, folosit când Ollama nu răspunde sau nu produce un răspuns utilizabil.

### 174. Fallback-ul are încredere mare?

**Răspuns:** Nu; confidence-ul este limitat, astfel încât tichetul să ajungă la dispecer dacă potrivirea este slabă.

### 175. LLM-ul poate inventa un cod?

**Răspuns:** Nu; codul este verificat față de taxonomia închisă, iar un cod necunoscut este respins sau mapat la cel mai apropiat cod valid.

### 176. LLM-ul poate inventa un departament?

**Răspuns:** Nu; departamentele sunt derivate din taxonomie, nu din textul liber al modelului.

### 177. LLM-ul poate coborî urgența?

**Răspuns:** Nu; poate doar să o ridice față de urgența implicită a codului, niciodată să o coboare sub ea.

### 178. Cine decide urgența finală?

**Răspuns:** Taxonomia stabilește minimul, LLM-ul poate escalada, iar dispecerul poate reclassifica explicit dacă are context suplimentar.

### 179. Ce este confidence-ul?

**Răspuns:** Un scor 0–1 care exprimă cât de sigură este clasificarea; sub 0.65 este tratat ca incert și trimis la dispecer.

### 180. De ce confidence-ul nu este suficient?

**Răspuns:** Un model poate fi încrezut și greșit; de aceea există gărzi, rationale, reclassificare și confirmare umană.

### 181. Ce este rationale?

**Răspuns:** O justificare scurtă a clasificării, utilă pentru audit și pentru a vedea ce a „văzut” modelul.

### 182. Ce se întâmplă cu un text fără sens?

**Răspuns:** Poate primi OP-OTHER cu confidence mic sau este trimis la dispecer; utilizatorul poate alege manual un tip din meniu.

### 183. Cum testezi că LLM-ul ghicește bine?

**Răspuns:** Cu un set de fraze ambigue, verificând codul, urgența și faptul că niciun guard nu coboară urgența; în demo, 12/12 fraze au ieșit corect.

### 184. Poți antrena modelul pe datele aeroportului?

**Răspuns:** Nu în demo; se pot îmbunătăți promptul, exemplele și gărzile. Un sistem real ar putea face fine-tuning cu date aprobate.

### 185. Modelul învață din acțiunile utilizatorilor?

**Răspuns:** Nu; nu există learning online. Fiecare clasificare este independentă, iar corecturile umane sunt vizibile doar ca evenimente operaționale.

### 186. Ce limbă folosește Whisper?

**Răspuns:** Limba selectată din toggle-ul RO/EN; este forțată explicit pentru a evita detectarea greșită pe fraze scurte.

### 187. Ce limbă folosește LLM-ul?

**Răspuns:** Promptul și taxonomia sunt în română, dar acceptă și text în engleză; răspunsul rămâne un cod și un JSON, nu o conversație liberă.

### 188. Cum sunt traduse întrebările serverului în engleză?

**Răspuns:** Întrebările cunoscute (tip/locație) sunt mapate la varianta locală RO/EN; întrebările complet noi pot rămâne în română, ceea ce este o limitare a demo-ului.

### 189. Ce este un „low confidence word”?

**Răspuns:** Un cuvânt pentru care Whisper a avut probabilitate mică; este marcat galben și poate fi corectat de utilizator.

### 190. Se poate edita transcriptul dacă Whisper a avut încredere mare?

**Răspuns:** Da; toate cuvintele sunt editabile, indiferent de culoare. Culoarea este doar un indiciu, nu o interdicție.

### 191. Ce se întâmplă dacă utilizatorul corectează transcriptul după trimitere?

**Răspuns:** Textul tichetului este actualizat pe backend; clasificarea nu este re-rulată automat, pentru a nu schimba dispatch-ul fără o decizie explicită.

### 192. AI-ul vede poza?

**Răspuns:** Nu; poza este un atașament pentru oameni și pentru dashboard, nu este trimisă către Whisper sau LLM.

### 193. AI-ul vede locația?

**Răspuns:** Da, primește o etichetă de locație în prompt; coordonatele sunt folosite de aplicație și dashboard, nu sunt trimise ca imagine.

### 194. AI-ul poate recunoaște o limbă greșită?

**Răspuns:** Da, dar riscul este redus prin selectarea explicită a limbii și printr-un singur reask; dacă rezultatul rămâne slab, meniul este fallback-ul sigur.

### 195. Ce se întâmplă cu zgomotul de fond?

**Răspuns:** Whisper folosește VAD, iar aplicația poate ignora tăcerile; zgomotul puternic rămâne o limitare, de aceea există meniul și editarea transcriptului.

### 196. Care este limita de audio?

**Răspuns:** 25 MB per request; aplicația recomandă clipuri scurte, de ordinul a 5–15 secunde, pentru latență bună și acuratețe.

### 197. Ce se întâmplă dacă audio-ul este prea lung?

**Răspuns:** Serverul îl respinge cu 400 și un mesaj clar; utilizatorul poate înregistra din nou sau folosi meniul.

### 198. Ce se întâmplă dacă modelul Ollama nu este descărcat?

**Răspuns:** Backendul raportează indisponibilitatea, iar aplicația poate continua cu fallback-ul determinist și cu meniul.

### 199. Cum se vede latența în aplicație?

**Răspuns:** Există starea „AI analizează…” în timpul transcrierii/clasificării, iar răspunsul apare când este gata; utilizatorul poate corecta sau alege meniul dacă așteaptă prea mult.

### 200. De ce nu se folosește doar LLM-ul, fără Whisper?

**Răspuns:** Pentru că inputul natural al utilizatorului este vocea; Whisper face conversia, LLM-ul face clasificarea, iar meniul este plasă de siguranță.

## 5. Dispecerat, quorum și timp real

### 201. Care sunt stările unui tichet?

**Răspuns:** `pending_override`, `dispatched`, `in_progress`, `pending_resolution`, `resolved` și `denied`.

### 202. Cine este singurul care scrie starea unui tichet?

**Răspuns:** Backendul; aplicațiile trimit acțiuni, dar serverul validează și decide tranzițiile de stare.

### 203. Ce înseamnă `dispatched`?

**Răspuns:** Tichetul a fost creat și rutat către departamentele primare, dar nu a fost încă preluat.

### 204. Ce înseamnă `in_progress`?

**Răspuns:** Cel puțin un responder a preluat tichetul și lucrează la el.

### 205. Ce înseamnă `pending_resolution`?

**Răspuns:** Quorum-ul a fost atins la un tichet high/critical, dar rezolvarea așteaptă confirmarea adminului/dispecerului.

### 206. Ce înseamnă `resolved`?

**Răspuns:** Tichetul este închis ca rezolvat, are `resolved_at` și intră în istoric/statistici.

### 207. Ce înseamnă `denied`?

**Răspuns:** Dispecerul a respins raportul; tichetul este închis fără rezolvare operațională.

### 208. Ce este `pending_override`?

**Răspuns:** O stare moștenită pentru rapoarte cu încredere foarte mică, care așteaptă o decizie de dispecer; fluxul demo actual dispecerizează imediat și folosește meniul ca fallback.

### 209. Ce este dispatch-ul?

**Răspuns:** Calculul departamentelor primare și standby din codul incidentului și trimiterea tichetului către echipele potrivite.

### 210. Cum se calculează departamentele?

**Răspuns:** Din taxonomia închisă: fiecare cod are o listă de departamente primare și una de standby.

### 211. Ce este quorum-ul?

**Răspuns:** Numărul de aprobări necesare pentru rezolvare; regula de bază este un responder pentru fiecare departament primar.

### 212. Cine stabilește quorum-ul?

**Răspuns:** Configurația de domeniu și numărul de departamente primare; seed-ul demo poate fixa quorum-ul pentru un caz controlat.

### 213. De ce un singur responder per departament?

**Răspuns:** Pentru a păstra echipele disponibile și a evita dublarea intervenției pe același tichet.

### 214. Un al doilea om din același departament poate intra?

**Răspuns:** Nu; serverul returnează conflict 409 și explică faptul că departamentul are deja un responder.

### 215. Ce se întâmplă dacă primul responder pleacă?

**Răspuns:** Poate folosi „retrage-mă”; join-ul și votul îi sunt eliminate, iar locul din departament se eliberează.

### 216. Ce se întâmplă dacă un tichet are două departamente primare?

**Răspuns:** Este nevoie de câte un responder din fiecare departament; ambii trebuie să voteze pentru quorum.

### 217. Care este exemplul demo cu doi responderi?

**Răspuns:** `SF-FIRE`, cu pompieri și securitate; primul vot lasă tichetul în lucru, al doilea îl duce în confirmare admin.

### 218. Care sunt cele patru cazuri demo cu un responder?

**Răspuns:** `OP-OTHER` low, `SF-SPILL` medium, `SC-BAG` high și `SC-ITEM` high; fiecare are quorum 1 în seed-ul demo.

### 219. De ce `SC-BAG` și `SC-ITEM` au quorum 1?

**Răspuns:** Ambele au un singur departament primar în taxonomie (security), deci un singur responder este suficient.

### 220. De ce `SF-SPILL` are quorum 1 în demo dacă taxonomia are două departamente?

**Răspuns:** Seed-ul demo fixează explicit quorum-ul la 1 pentru cazul mediu, ca fluxul de test să fie simplu; regula generală rămâne per departament primar.

### 221. Ce se întâmplă după ce quorum-ul este atins la low/medium?

**Răspuns:** Tichetul devine direct `resolved`, fără confirmare admin.

### 222. Ce se întâmplă după quorum la high/critical?

**Răspuns:** Tichetul devine `pending_resolution` și așteaptă confirmarea adminului.

### 223. Cine poate confirma rezolvarea?

**Răspuns:** Doar un utilizator cu rol de dispecer/admin, prin endpointul de confirmare a rezolvării.

### 224. Ce se întâmplă dacă adminul nu confirmă?

**Răspuns:** Tichetul rămâne în `pending_resolution`, nu este considerat rezolvat și nu intră în AHT ca rezolvat.

### 225. Se poate respinge un tichet în `pending_resolution`?

**Răspuns:** Da; dispecerul poate respinge cu motiv, iar tichetul devine `denied`.

### 226. Ce se întâmplă dacă un echipaj votează de două ori?

**Răspuns:** Votul dublu este ignorat; serverul ține lista votanților și nu numără același crew de două ori.

### 227. Ce se întâmplă dacă un utilizator încearcă să voteze fără să fi preluat?

**Răspuns:** Serverul îl respinge; votul este permis doar după join.

### 228. Ce se întâmplă dacă un utilizator încearcă să preia un tichet deja rezolvat?

**Răspuns:** Primește conflict; tichetul nu mai este deschis pentru join.

### 229. Ce se întâmplă dacă un tichet este șters de un reset?

**Răspuns:** Aplicația primește evenimentul de reset, golește lista și afișează un mesaj; nu mai păstrează carduri moarte.

### 230. Ce se întâmplă dacă un eveniment WSS sosește out-of-order?

**Răspuns:** Clientul păstrează versiunea cea mai mare a tichetului și ignoră evenimentele mai vechi.

### 231. Ce este versiunea tichetului?

**Răspuns:** Un contor monoton incrementat de server la fiecare modificare; ajută la rezolvarea conflictelor și la ordonarea evenimentelor.

### 232. Ce este WSS?

**Răspuns:** WebSocket Secure, canalul prin care serverul împinge în timp real crearea și actualizarea tichetelor către toate ecranele.

### 233. Ce se întâmplă când WSS cade?

**Răspuns:** Aplicația afișează „WSS: deconectat”, încearcă reconectarea automată și continuă să poată face acțiuni prin REST.

### 234. De ce WSS nu este singurul canal?

**Răspuns:** Acțiunile utilizatorului trebuie să fie confirmate de server prin REST; WSS este pentru sincronizarea rapidă a tuturor clienților.

### 235. Ce este un eveniment `ticket.updated`?

**Răspuns:** Un mesaj WSS care conține tichetul actualizat după join, leave, vot, editare sau reclassificare.

### 236. Ce este `ticket.resolved`?

**Răspuns:** Evenimentul care anunță că tichetul a ajuns în starea finală rezolvată.

### 237. Ce este `ticket.created`?

**Răspuns:** Evenimentul prin care dashboardul și echipajele află imediat de un tichet nou.

### 238. Ce se întâmplă dacă un client pierde un eveniment?

**Răspuns:** La reconectare poate reîncărca lista completă prin REST; cache-ul local este reconstruit.

### 239. Cum se vede timpul pe un tichet?

**Răspuns:** Printr-un timer live calculat din `created_at`; se oprește când tichetul este rezolvat sau respins.

### 240. Ce este AHT?

**Răspuns:** Average Handling Time, media timpului dintre crearea și rezolvarea tichetelor rezolvate.

### 241. AHT include timpul de confirmare admin?

**Răspuns:** Da, dacă tichetul așteaptă confirmarea; `resolved_at` este setat abia după confirmare.

### 242. Ce se întâmplă cu timerul în `pending_resolution`?

**Răspuns:** Continuă să curgă, pentru că tichetul nu este încă rezolvat definitiv.

### 243. Cum se calculează timpul mediu de preluare?

**Răspuns:** Din diferența dintre primul join și creare; este un indicator separat de AHT.

### 244. Ce se întâmplă dacă nimeni nu preia un tichet?

**Răspuns:** Timpul continuă, dashboardul îl arată ca activ, iar dispecerul poate interveni.

### 245. Ce face dispecerul cu un tichet blocat?

**Răspuns:** Poate reclassifica, poate schimba urgența, poate respinge sau poate contacta echipa; aplicația nu ascunde tichetul blocat.

### 246. Ce este reclassificarea?

**Răspuns:** Schimbarea codului și/sau urgenței unui tichet; noile departamente primare sunt recalculate de taxonomie.

### 247. Ce se întâmplă cu echipajele după reclassificare?

**Răspuns:** Tichetul este rerutat; echipele noi primesc evenimentul, iar cele vechi nu mai sunt vizate dacă nu mai sunt primare.

### 248. Ce se întâmplă cu voturile după reclassificare?

**Răspuns:** Starea și voturile pot fi recalculate de backend în funcție de noul tip; operația este explicită și auditată.

### 249. Cine vede istoricul unui tichet?

**Răspuns:** Adminul/dispecerul vede toate evenimentele; echipajul vede istoricul relevant pentru tichetul lui.

### 250. Ce este un „decided_by”?

**Răspuns:** Identitatea dispecerului/adminului care a confirmat, respins sau reclassificat tichetul.

## 6. Recompense, statistici și timere

### 251. Câte puncte primește un raport?

**Răspuns:** Două puncte pentru un raport trimis, indiferent dacă incidentul este apoi rezolvat sau respins.

### 252. Câte puncte primește un responder?

**Răspuns:** Cinci puncte când preia și contribuie la rezolvarea unui tichet; doar join-ul fără rezolvare nu aduce puncte.

### 253. De ce raportarea valorează 2 puncte?

**Răspuns:** Pentru a încuraja oamenii să semnaleze probleme, fără a transforma raportarea într-o competiție de volum.

### 254. De ce rezolvarea valorează 5 puncte?

**Răspuns:** Pentru că intervenția și închiderea unui tichet cer mai mult efort și au impact operațional mai mare.

### 255. Punctele se acordă pentru fiecare vot?

**Răspuns:** Nu; punctele de rezolvare se acordă când tichetul este rezolvat, nu pentru fiecare apăsare de buton.

### 256. Ce se întâmplă dacă cineva preia un tichet și apoi pleacă?

**Răspuns:** Nu primește punctele de rezolvare, iar contribuția lui este eliminată la leave.

### 257. Ce este anti-farm?

**Răspuns:** O regulă care împiedică un utilizator să raporteze și să rezolve singur un incident minor doar pentru a-și umfla punctajul.

### 258. Ce incidente sunt exceptate de la anti-farm?

**Răspuns:** Cele high/critical, unde intervenția este periculoasă și este legitim să acționezi chiar dacă ai raportat tu incidentul.

### 259. Ce vede utilizatorul în cont?

**Răspuns:** Punctajul total, două categorii de activitate — Raportare și Rezolvare — și istoricul tichetelor sale.

### 260. Ce categorii de puncte apar în UI?

**Răspuns:** Doar două: **Raportare** și **Rezolvare**, conform cerinței de produs.

### 261. De ce nu mai apare categoria „intervenții”?

**Răspuns:** Pentru că utilizatorul a cerut două categorii clare; „intervențiile” au fost eliminate din rezumatul vizibil.

### 262. Ce este ledger-ul de recompense?

**Răspuns:** Structura care calculează punctele și intrările din lista de tichete, fără să depindă de un serviciu extern.

### 263. Punctele sunt persistate?

**Răspuns:** În modul live, punctele sunt derivate din tichetele persistate în SQLite; nu există un tabel separat de puncte care să poată diverge.

### 264. Ce se întâmplă cu punctele la reset?

**Răspuns:** Resetarea demo-ului șterge tichetele, deci și istoricul din care sunt calculate punctele; punctajul revine la zero.

### 265. Ce se întâmplă cu punctele în modul local?

**Răspuns:** Sunt calculate din board-ul local și se resetează la schimbarea modului sau la repornirea aplicației.

### 266. Un utilizator poate vedea punctele altcuiva?

**Răspuns:** În demo, ecranul de cont este al utilizatorului curent; nu există leaderboard public între conturi.

### 267. Ce este un tichet „rezolvat” pentru rewards?

**Răspuns:** Un tichet cu status `resolved`, nu unul doar preluat sau aflat în `pending_resolution`.

### 268. Un tichet high/critical aflat în așteptare admin aduce puncte?

**Răspuns:** Nu încă; punctele de rezolvare se acordă după confirmarea finală.

### 269. Cum se vede progresul voturilor?

**Răspuns:** În card apare „Voturi: X / Y” și bara de progres; la atingerea quorum-ului statusul se schimbă.

### 270. Ce este timerul de tichet?

**Răspuns:** Un cronometru live pornit la `created_at`, care arată de cât timp tichetul este activ.

### 271. Când se oprește timerul?

**Răspuns:** Când tichetul devine `resolved` sau `denied`; în `pending_resolution` continuă.

### 272. De ce timerul continuă în pending_resolution?

**Răspuns:** Pentru că timpul de răspuns nu s-a încheiat operațional până la confirmarea adminului.

### 273. Ce este AHT?

**Răspuns:** Average Handling Time, media timpului de la creare la rezolvare pentru tichetele rezolvate.

### 274. Cum se calculează AHT?

**Răspuns:** Se face media diferențelor `resolved_at - created_at` pentru tichetele final rezolvate.

### 275. Ce înseamnă `handled_count`?

**Răspuns:** Numărul de tichete rezolvate folosite în calculul AHT.

### 276. Dacă nu există tichete rezolvate, ce afișează AHT?

**Răspuns:** Valoare indisponibilă / `null`; nu se inventează o medie din zero tichete.

### 277. Ce perioade de statistici există?

**Răspuns:** Zi, săptămână, lună și an; dashboardul permite schimbarea perioadei.

### 278. Ce arată statisticile?

**Răspuns:** Numărul de tichete, distribuția pe urgențe, top probleme, AHT, volumul pe perioadă și alte agregate operaționale.

### 279. Statisticile includ tichetele respinse?

**Răspuns:** Zonele de volum pot include toate tichetele, dar AHT-ul se calculează doar pe cele rezolvate.

### 280. Ce este „top probleme”?

**Răspuns:** Clasamentul codurilor de incidente după frecvență în perioada selectată.

### 281. La ce folosește topul problemelor?

**Răspuns:** Pentru prevenție: dacă aceeași problemă apare repetat, aeroportul poate interveni la cauză, nu doar la simptom.

### 282. Statisticile sunt live?

**Răspuns:** Se reîncarcă la schimbarea perioadei și pot fi reîmprospătate; dashboardul citește endpointul de stats al backendului.

### 283. Ce fus orar folosesc timestampurile?

**Răspuns:** Serverul lucrează cu UTC; UI-ul afișează ore locale și calculează perioadele în funcție de configurație.

### 284. Ce este un tichet „activ”?

**Răspuns:** Un tichet care nu este nici rezolvat, nici respins; include dispatched, in_progress, pending_override și pending_resolution.

### 285. Ce este un tichet „terminal”?

**Răspuns:** Un tichet în starea resolved sau denied, care nu mai poate fi editat și intră în istoric.

### 286. Cum se vede un tichet în istoric?

**Răspuns:** Cu statusul final, motivul/decizia, timpul de rezolvare și eventuala notă a dispecerului.

### 287. Ce se întâmplă cu istoricul la reclassificare?

**Răspuns:** Reclassificarea este o acțiune nouă, nu șterge istoricul; tichetul rămâne urmăribil.

### 288. Cine poate vedea statisticile?

**Răspuns:** Adminul/dispecerul din dashboard; ecranul de cont al utilizatorului arată doar propriile puncte și istoric.

### 289. Ce este „blocked self resolutions”?

**Răspuns:** Numărul de cazuri în care un utilizator a încercat să obțină puncte raportând și rezolvând singur un incident nepericulos; ele sunt raportate, dar nu punctate.

### 290. De ce anti-farm nu blochează cazurile periculoase?

**Răspuns:** Pentru că în situații critice este mai important să acționezi, chiar dacă ai raportat tu; siguranța bate competiția de puncte.

### 291. Cum se poate abuza de puncte?

**Răspuns:** Prin raportări repetate sau auto-rezolvări; anti-farm-ul și confirmarea adminului reduc acest risc, dar nu sunt un sistem antifraudă complet.

### 292. Ce lipsește pentru un sistem real de recompense?

**Răspuns:** Reguli de business, aprobare, audit, limite pe perioadă, integrare HR și un mecanism de contestare.

### 293. Ce este un „punct” din perspectivă tehnică?

**Răspuns:** Un număr derivat din starea tichetelor și din relația reporter/responder, nu o monedă sau un sold independent.

### 294. Punctele pot fi negative?

**Răspuns:** Nu în modelul demo; se acordă doar puncte pozitive pentru raportare și rezolvare.

### 295. Ce se întâmplă dacă un tichet este rezolvat de un responder care nu a raportat?

**Răspuns:** Primește punctele de rezolvare; reporterul primește punctele de raportare, dacă nu este același utilizator.

### 296. Ce se întâmplă dacă același om raportează și rezolvă un incident high/critical?

**Răspuns:** Poate primi ambele categorii, pentru că anti-farm-ul permite cazurile periculoase.

### 297. De ce sunt utile cele două categorii pentru management?

**Răspuns:** Raportarea arată implicarea în detectare, iar rezolvarea arată capacitatea de intervenție; împreună dau o imagine mai corectă decât un singur total.

### 298. Cum se vede contribuția în cont?

**Răspuns:** Prin cardurile Raportare/Rezolvare și prin lista de tichete cu punctele asociate.

### 299. Ce este „Istoricul meu”?

**Răspuns:** Lista tichetelor în care utilizatorul a fost reporter sau responder, cu status și puncte.

### 300. Ce se întâmplă cu istoricul în modul local?

**Răspuns:** Se recalculează din board-ul local; nu este sincronizat cu backendul.

## 7. UI/UX, limbă și accesibilitate

### 301. Cum sunt colorate cardurile?

**Răspuns:** După urgență: verde pentru low, galben pentru medium, portocaliu pentru high și roșu pentru critical.

### 302. De ce un card medium apărea roșiatic?

**Răspuns:** Cardul de echipaj colora bara după categoria incidentului (mentenanță = portocaliu), nu după urgență; am corectat ca accentul să urmeze întotdeauna urgența.

### 303. Ce culoare are `SF-SPILL` medium?

**Răspuns:** Galben, cu badge-ul „Medie” și bară galbenă; categoria mentenanță nu mai schimbă culoarea cardului.

### 304. De ce este importantă consistența culorilor?

**Răspuns:** Un operator trebuie să recunoască urgența dintr-o privire; dacă aceeași culoare înseamnă lucruri diferite, reacția devine mai lentă.

### 305. Ce culori folosește dashboardul?

**Răspuns:** Aceeași semantică: roșu critical, portocaliu high, galben medium, alb/verde low; statusul are culori separate.

### 306. Ce este un badge de urgență?

**Răspuns:** Eticheta text plus culoare care apare pe card și în detalii, ca să nu te bazezi doar pe culoare.

### 307. Ce este un badge de status?

**Răspuns:** Eticheta pentru dispatched, in_progress, pending_resolution, resolved sau denied.

### 308. De ce statusul are culoare separată de urgență?

**Răspuns:** Pentru că un tichet critical poate fi în lucru sau în așteptare admin; statusul spune unde este în flux, urgența spune cât de grav este.

### 309. Ce este limba aplicației?

**Răspuns:** Fluxul de raportare are toggle RO/EN; meniul, promptul foto, statusurile și textele principale ale reporterului se traduc.

### 310. Toată aplicația este bilingvă?

**Răspuns:** Nu încă; ecranele de crew/dispecer și unele texte administrative sunt în română. Toggle-ul este complet pentru fluxul de raportare, nu pentru fiecare ecran.

### 311. De ce nu este totul bilingv?

**Răspuns:** Localizarea completă a tuturor ecranelor cere timp și teste; pentru demo am prioritizat fluxul principal, unde utilizatorul alege limba.

### 312. Ce se întâmplă când schimbi limba?

**Răspuns:** Se schimbă textele fluxului de raportare, întrebările locale, etichetele meniului, promptul foto și statusurile.

### 313. Se schimbă limba și în dashboard?

**Răspuns:** Nu; dashboardul este un instrument separat, în română, folosit de operatori.

### 314. Cum este tradus meniul 8×8×8?

**Răspuns:** Categoriile, subcategoriile și problemele au etichete englezești într-un dicționar dedicat; codurile rămân neschimbate.

### 315. Ce se întâmplă cu întrebările venite de la server în engleză?

**Răspuns:** Întrebările cunoscute (tip/locație) sunt mapate la varianta locală în limba selectată; unele întrebări noi pot rămâne în română, o limitare cunoscută.

### 316. Ce este ecranul de login?

**Răspuns:** Selectorul de conturi demo, cu carduri pentru fiecare rol, parola afișată pentru demo și starea sesiunii salvate.

### 317. Ce este cardul „Bine ai revenit”?

**Răspuns:** Oferă continuarea rapidă cu sesiunea salvată, ca un utilizator să nu mai aleagă din nou contul.

### 318. Cum se schimbă contul?

**Răspuns:** Din ecranul de rol, prin „Ieși din rol”; aplicația revine la selectorul de conturi.

### 319. Cum se vede modul local?

**Răspuns:** Badge-ul „Demo local · instant” în header și butonul „Treci pe Live (server)” dedesubt.

### 320. Cum se vede modul live?

**Răspuns:** Badge-ul „Server conectat · live” și butonul „Treci pe Local (instant)”.

### 321. De ce există butonul de mod pe login?

**Răspuns:** Ca să poți schimba local/live fără să reinstalezi aplicația și fără să intri într-un meniu de admin.

### 322. Ce se întâmplă când apeși switch-ul?

**Răspuns:** Board-ul este înlocuit în memorie; în modul local primești imediat seed-ul, în modul live se pornește conexiunea REST/WSS.

### 323. Modul local persistă după repornire?

**Răspuns:** Nu dacă APK-ul a fost construit cu `LOCAL_MOCK=true`; la repornire revine modul implicit al build-ului. Poți schimba din nou din login.

### 324. Ce este bannerul WSS?

**Răspuns:** O bandă care arată „WSS: conectat” sau „WSS: deconectat”; în modul local afișează „Demo local · instant”.

### 325. Ce face aplicația când WSS este deconectat?

**Răspuns:** Afișează bannerul, încearcă reconectarea și permite acțiuni REST; nu ascunde starea proastă.

### 326. Ce face aplicația când o acțiune eșuează?

**Răspuns:** Afișează un mesaj scurt, păstrează cardul și îți permite să reîncerci; la eroare de rețea face un retry automat scurt.

### 327. Ce este starea de loading?

**Răspuns:** Un indicator cât timp se încarcă lista, se trimite raportul sau se așteaptă răspunsul AI; butoanele sunt dezactivate ca să eviți dublurile.

### 328. Ce se întâmplă dacă lista este goală?

**Răspuns:** Se afișează un mesaj de empty state, nu o listă confuză; în modul local lista este populată din seed.

### 329. Cum arată un card de tichet?

**Răspuns:** Cod, titlu, urgență, status, departamente, locație, număr de reporteri, timer, voturi și acțiuni.

### 330. De ce cardul are un timer?

**Răspuns:** Pentru ca echipa să vadă de cât timp tichetul este deschis și să prioritizeze intervenția.

### 331. Ce acțiuni are un card de echipaj?

**Răspuns:** Preia, Rezolvat, retrage-mă, plus acces la detalii, foto/hartă și istoric.

### 332. Ce acțiuni are un card de dispecer?

**Răspuns:** Selectare, reclassificare, respingere, confirmare admin, istoric și detalii.

### 333. De ce butoanele au stare disabled?

**Răspuns:** Pentru a preveni acțiuni invalide, cum ar fi votul fără join, dublu tap sau trimiterea în timpul unei cereri.

### 334. Cum este afișată harta?

**Răspuns:** Într-un panou de media al tichetului, cu locația GPS dacă există; poți comuta între foto și hartă.

### 335. Ce se întâmplă dacă nu există poză?

**Răspuns:** Panoul afișează harta sau un mesaj „fără foto”; poza este opțională.

### 336. Cum arată transcriptul pe telefon?

**Răspuns:** Ca o listă compactă de cuvinte apăsabile; cuvintele galbene arată unde Whisper a avut încredere mică.

### 337. De ce toate cuvintele sunt apăsabile?

**Răspuns:** Pentru că utilizatorul trebuie să poată corecta orice, nu doar ce a marcat modelul ca nesigur.

### 338. Cum se editează un cuvânt?

**Răspuns:** Atingi cuvântul, apare un dialog cu textul curent; poți înlocui sau goli câmpul pentru a șterge cuvântul.

### 339. Ce este dialogul de corectare?

**Răspuns:** Un câmp simplu cu Salvează/Anulează, care păstrează fluxul rapid și nu te obligă să editezi tot raportul.

### 340. Cum se adaugă o poză?

**Răspuns:** Din promptul foto de 5 secunde sau din butonul „Adaugă poză” de pe ecranul raportului trimis.

### 341. Cum se editează textul după trimitere?

**Răspuns:** Butonul „Editează textul” deschide un dialog cu transcriptul curent; salvarea actualizează tichetul dacă este activ.

### 342. Ce este accesibilitatea?

**Răspuns:** Un set de setări pentru contrast, ținte mari, text mărit și culori sigure pentru daltonism.

### 343. Cum se activează accesibilitatea?

**Răspuns:** Din ecranul de accesibilitate, accesibil din login/cont, dacă feature-ul este activ în domain config.

### 344. Ce face contrastul ridicat?

**Răspuns:** Crește contrastul textului și al bordurilor, ca interfața să fie lizibilă în lumină puternică sau pentru vedere slabă.

### 345. Ce înseamnă ținte mari?

**Răspuns:** Butoanele și zonele de atingere devin mai mari, ca să fie mai ușor de apăsat pe telefon.

### 346. Ce înseamnă color-blind safe?

**Răspuns:** Culorile sunt ajustate astfel încât diferențele să fie vizibile și pentru daltonism; în plus, badge-urile au text, nu doar culoare.

### 347. Cum se comportă pe tabletă/desktop?

**Răspuns:** Dispatcherul are un layout wide cu feed și detaliu; pe telefon layout-ul devine compact, iar acțiunile rămân accesibile.

### 348. Ce este dashboardul web?

**Răspuns:** O interfață pentru control room, separată de aplicația mobilă, care arată coada, acțiunile și statisticile.

### 349. De ce dashboardul folosește WSS?

**Răspuns:** Ca să vezi imediat tichetele noi și schimbările de status, fără refresh manual.

### 350. Ce face butonul Reîncarcă?

**Răspuns:** Reîncarcă datele din backend și resincronizează lista după o întrerupere.

## 8. Backend, arhitectură și securitate

### 351. Ce stack folosește aplicația?

**Răspuns:** Flutter/Dart pentru mobil și dashboardul Flutter, FastAPI/Python pentru backend, SQLite pentru persistență, WebSocket pentru timp real și modele locale Whisper/Ollama.

### 352. De ce Flutter?

**Răspuns:** Un singur cod pentru Android, web și desktop, cu UI rapid de construit și potrivit pentru prototipuri care trebuie demonstrate pe telefon și laptop.

### 353. De ce FastAPI?

**Răspuns:** Este rapid de dezvoltat, are validare Pydantic, suport async bun pentru WebSocket și documentație API generată automat.

### 354. De ce SQLite?

**Răspuns:** Pentru un demo local este suficient, nu cere server separat, persistă pe disc și este ușor de inspectat/resetat.

### 355. Unde este baza de date?

**Răspuns:** În `backend/data/wingman.db`; tichetele supraviețuiesc repornirii backendului.

### 356. Ce se stochează într-un tichet?

**Răspuns:** Id, cod, etichetă, categorie, urgență, status, sursă, reporter, transcript, locație, departamente, poze, voturi, quorum, timestamps și versiune.

### 357. Cum se asigură persistența?

**Răspuns:** Store-ul scrie prin `TicketDatabase` în SQLite la fiecare modificare și reîncarcă starea la pornire.

### 358. Ce este `TicketStore`?

**Răspuns:** Sursa de adevăr pentru mutațiile de tichete: create, join, leave, vote, deny, override, editare și confirmare.

### 359. Ce este `Hub`?

**Răspuns:** Componenta care ține conexiunile WebSocket și difuzează evenimentele către toți clienții conectați.

### 360. Ce endpoint creează un raport?

**Răspuns:** `POST /api/reports`.

### 361. Ce endpoint face transcrierea?

**Răspuns:** `POST /api/transcribe`, cu audio base64 sau varianta multipart `/api/transcribe/upload`.

### 362. Ce endpoint face clasificarea conversațională?

**Răspuns:** `POST /api/analyze`.

### 363. Ce endpoint listează tichetele?

**Răspuns:** `GET /api/tickets`, cu filtrare opțională pe status.

### 364. Ce endpoint face join?

**Răspuns:** `POST /api/tickets/{id}/join`.

### 365. Ce endpoint înregistrează votul?

**Răspuns:** `POST /api/tickets/{id}/vote`.

### 366. Ce endpoint retrage un responder?

**Răspuns:** `POST /api/tickets/{id}/leave`.

### 367. Ce endpoint respinge un tichet?

**Răspuns:** `POST /api/tickets/{id}/deny`.

### 368. Ce endpoint reclassifică?

**Răspuns:** `POST /api/tickets/{id}/override`.

### 369. Ce endpoint confirmă rezolvarea high/critical?

**Răspuns:** `POST /api/tickets/{id}/resolution-confirm`.

### 370. Ce endpoint returnează statistici?

**Răspuns:** `GET /api/stats?period=day|week|month|year`.

### 371. Ce endpoint returnează sănătatea sistemului?

**Răspuns:** `GET /api/health`, cu stare Ollama, STT, baza de date și numărul de clienți WSS.

### 372. Ce endpoint returnează taxonomia?

**Răspuns:** `GET /api/taxonomy`, folosit de dashboard/UI pentru lista închisă.

### 373. Ce endpoint editează un tichet după trimitere?

**Răspuns:** `PATCH /api/tickets/{id}`, disponibil doar reporterului și doar pentru tichete active.

### 374. Ce endpoint golește istoricul?

**Răspuns:** Un endpoint administrativ de clear history, folosit pentru demo/reset.

### 375. Ce endpoint face dev reset?

**Răspuns:** `POST /api/dev/reset`, protejat de token și de flagul de configurare.

### 376. Cum este protejat API-ul?

**Răspuns:** Printr-un bearer token demo (`demo-token`) verificat pe fiecare request și pe WebSocket.

### 377. Ce este tokenul demo?

**Răspuns:** Un secret partajat compilat în aplicație și configurat pe backend; nu este un sistem real de identitate.

### 378. Care este riscul tokenului static?

**Răspuns:** Cine îl obține poate apela API-ul; pentru producție ar trebui SSO, tokenuri pe utilizator, expirare și audit.

### 379. Cum este protejat transportul?

**Răspuns:** HTTPS/WSS pe portul 8443, cu certificat self-signed și CA locală; aplicația poate pinui CA-ul.

### 380. Ce este `DEV_INSECURE`?

**Răspuns:** Un flag de dezvoltare care acceptă orice certificat; nu se folosește în demo-ul judged.

### 381. Cum se validează payload-urile?

**Răspuns:** Cu modele Pydantic: câmpuri obligatorii, lungimi maxime, valori permise și `extra=forbid` acolo unde vrem să respingem câmpuri necunoscute.

### 382. Ce se întâmplă la un payload invalid?

**Răspuns:** FastAPI returnează 422 cu detalii de validare; aplicația afișează un mesaj prietenos, nu JSON brut.

### 383. Ce înseamnă eroarea 409?

**Răspuns:** Conflict de stare: de exemplu, un al doilea responder din același departament, un vot fără join sau un tichet deja închis.

### 384. Ce înseamnă eroarea 404?

**Răspuns:** Tichetul nu mai există, de obicei după un reset sau o ștergere; clientul reîncarcă lista.

### 385. Ce înseamnă eroarea 503?

**Răspuns:** Un serviciu local nu este disponibil, de exemplu modelul Whisper nu este instalat.

### 386. Cum se tratează concurența?

**Răspuns:** Mutațiile trec printr-un lock asincron în store, astfel încât două voturi simultane să nu corupă starea.

### 387. Ce este un lock în store?

**Răspuns:** Un `asyncio.Lock` care serializează operațiile de scriere pe tichete; nu blochează citirile neapărat, dar protejează tranzițiile.

### 388. Cum se evită evenimentele duplicate?

**Răspuns:** Fiecare modificare incrementează versiunea tichetului; clientul ignoră evenimentele cu versiune mai mică decât cea pe care o are.

### 389. Ce este un eveniment WSS?

**Răspuns:** Un mesaj JSON cu tip (`ticket.created`, `ticket.updated`, `ticket.resolved`, connection etc.) și, de obicei, tichetul complet.

### 390. Ce face clientul când primește un eveniment?

**Răspuns:** Actualizează cache-ul local, reordonează lista și notifică toate ecranele care ascultă board-ul.

### 391. Ce se întâmplă dacă WSS se deconectează?

**Răspuns:** Clientul încearcă reconectarea cu backoff și poate reîncărca lista prin REST.

### 392. De ce este nevoie de REST dacă există WSS?

**Răspuns:** Pentru acțiuni și adevărul final; WSS este pentru difuzare, nu pentru a înlocui request/response-ul validat.

### 393. Backendul este stateless?

**Răspuns:** Nu complet: ține store-ul și conexiunile WSS în memorie, dar starea durabilă este în SQLite.

### 394. Ce se întâmplă dacă backendul repornește?

**Răspuns:** Tichetele se reîncarcă din SQLite; clienții WSS se reconectează, iar app-ul resincronizează lista.

### 395. Ce se pierde la repornire?

**Răspuns:** Conexiunile WSS active și eventualele request-uri în zbor; datele persistate rămân.

### 396. Cum se face backup-ul?

**Răspuns:** Copierea fișierului SQLite și a configurilor; pentru producție ar fi nevoie de backup automat și WAL.

### 397. Cum se scalează?

**Răspuns:** Demo-ul rulează pe un singur proces/laptop; pentru scalare ar trebui un broker/event bus, DB partajat și WebSocket fan-out.

### 398. Ce lipsește pentru multi-aeroport?

**Răspuns:** Izolare pe tenant, configurare per aeroport, taxonomii diferite, identități separate și politici de acces.

### 399. Ce lipsește pentru producție?

**Răspuns:** Auth real, autorizare fină, audit, monitorizare, SLA, testare de securitate, backup, conformitate și integrare operațională.

### 400. Ce date sensibile există?

**Răspuns:** Nume de utilizator demo, transcripturi și locații; nu există date reale de pasageri, dar un sistem real ar putea primi informații sensibile.

## 9. Testare, demo și depanare

### 401. Câte teste are proiectul?

**Răspuns:** 198 de teste Flutter, 24 de teste backend și 111 verificări de smoke live.

### 402. Ce verifică testele Flutter?

**Răspuns:** Widget-uri, controllerul reporterului, modele, board-ul local, timere, statistici, conturi, permisiuni și fluxuri de UI.

### 403. Ce verifică testele backend?

**Răspuns:** Clasificare, gărzi, store, bază de date, domeniu, recompense, statistici și STT.

### 404. Ce verifică smoke testul?

**Răspuns:** Fluxul real prin API: raportare, clasificare, join, vot, confirmare admin, WSS, reset și date demo.

### 405. Ce comandă rulează toate testele Flutter?

**Răspuns:** `flutter test` din rădăcina proiectului.

### 406. Ce comandă verifică analiza statică?

**Răspuns:** `flutter analyze`; trebuie să iasă „No issues found!”.

### 407. Ce comandă rulează testele backend?

**Răspuns:** Din `backend`: `.venv\Scripts\python.exe -m unittest discover -s tests`.

### 408. Ce comandă rulează smoke testul?

**Răspuns:** Din rădăcină: `python scripts\smoke_test.py --base https://127.0.0.1:8443`.

### 409. De ce smoke testul are nevoie de un store curat?

**Răspuns:** Pentru că verifică numărul de tichete și un singur `SF-FIRE` deschis; seed-ul demo poate interfera, deci rulează după reset.

### 410. Ce este seed-ul demo?

**Răspuns:** Un script care creează cele cinci tichete demo cu distribuția 1 low, 1 medium, 2 high, 1 critical.

### 411. Cum readuci demo-ul la starea inițială?

**Răspuns:** Rulezi resetul, apoi `python backend\seed_demo.py --base https://127.0.0.1:8443`.

### 412. Ce se întâmplă dacă rulezi seed-ul fără reset?

**Răspuns:** Se adaugă încă cinci tichete, deci apar duplicate; folosește `--reset` sau resetează înainte.

### 413. De ce seed-ul nu este idempotent?

**Răspuns:** Pentru că fiecare raport creează un tichet nou; nu există o cheie naturală unică pentru un incident demo.

### 414. Cum pornești backendul?

**Răspuns:** Din folderul `backend`, cu uvicorn, cheile TLS și certificatul; comanda completă este în README.

### 415. Ce face `adb reverse tcp:8443 tcp:8443`?

**Răspuns:** Leagă portul 8443 al telefonului la portul 8443 al laptopului, ca aplicația să poată folosi `127.0.0.1` prin cablu USB.

### 416. De ce apare „serverul nu răspunde” uneori?

**Răspuns:** De obicei pentru că reverse-ul USB, WSS-ul sau backendul a picat o clipă; aplicația reîncearcă și poți reveni la modul local.

### 417. Cum verifici că backendul este pornit?

**Răspuns:** Deschizi `GET /api/health`; trebuie să răspundă 200 cu `status: ok`.

### 418. Cum verifici că telefonul este conectat?

**Răspuns:** `adb devices` trebuie să arate dispozitivul ca `device`, nu `unauthorized`.

### 419. Ce faci dacă telefonul apare `unauthorized`?

**Răspuns:** Deblochezi telefonul, accepți promptul „Allow USB debugging” și activezi „Always allow from this computer”.

### 420. Ce faci dacă nu apare promptul?

**Răspuns:** Revoci autorizările USB, repornești USB debugging, schimbi modul USB în File transfer și încerci alt cablu/port.

### 421. Cum instalezi APK-ul?

**Răspuns:** `adb install -r nume.apk`; după instalare pornești aplicația cu `adb shell am start`.

### 422. Ce APK-uri există?

**Răspuns:** Build-ul live (`wingman-tls-release...apk`) și build-ul local mock (`wingman-local-mock.apk`).

### 423. Care este diferența dintre ele?

**Răspuns:** Build-ul live folosește backendul; build-ul local pornește implicit board-ul mock, dar poți schimba din login.

### 424. Cum deschizi dashboardul?

**Răspuns:** Deschizi `scripts/dashboard/index.html` în browser; dashboardul cheamă API-ul configurat.

### 425. De ce dashboardul nu vede tichetele din modul local?

**Răspuns:** Pentru că modul local este doar în memoria telefonului; dashboardul citește backendul/SQLite.

### 426. Cum revii la dashboardul live?

**Răspuns:** Comuți telefonul pe Live și te asiguri că backendul rulează; dashboardul și telefonul partajează aceeași bază.

### 427. Ce faci dacă dashboardul arată date vechi?

**Răspuns:** Reîncarcă pagina (F5) și verifică WSS-ul; datele pot fi cache în browser.

### 428. Ce faci dacă baza de date este goală?

**Răspuns:** Rulezi seed-ul demo sau creezi un raport; dashboardul va arăta 0 până atunci.

### 429. Ce faci dacă vrei să ștergi tot demo-ul?

**Răspuns:** Folosești resetul din DevTools sau endpointul de dev reset, apoi seed dacă vrei datele inițiale.

### 430. Ce faci dacă Whisper este lent la prima folosire?

**Răspuns:** Aștepți warm-up-ul de la pornire; modelul se încarcă în fundal, iar prima transcriere ar trebui să fie de ordinul secundelor.

### 431. Ce faci dacă Whisper nu răspunde deloc?

**Răspuns:** Verifici `/api/health` secțiunea `stt`, logs pentru eroarea modelului și folosești meniul ca fallback.

### 432. Ce faci dacă Ollama nu răspunde?

**Răspuns:** Verifici că Ollama rulează pe 11434, că modelul este descărcat și că backendul nu are timeout; fallback-ul determinist rămâne disponibil.

### 433. Ce faci dacă AI-ul clasifică greșit?

**Răspuns:** Corectezi transcriptul, alegi tipul din meniu sau reclassifici din dashboard; nu forța AI-ul să aibă dreptate.

### 434. Ce faci dacă un card dispare brusc?

**Răspuns:** Poate fi un reset sau o tranziție de status; verifici bannerul WSS și reîncarci lista.

### 435. Ce faci dacă „Rezolvat” dă eroare?

**Răspuns:** Verifici că ai preluat tichetul, că ai votul disponibil și că backendul răspunde; în modul local nu ar trebui să depindă de rețea.

### 436. De ce „Rezolvat” nu închide un tichet high/critical?

**Răspuns:** Pentru că intră intenționat în `pending_resolution`; adminul trebuie să confirme.

### 437. Ce faci dacă ai votat și vrei să schimbi?

**Răspuns:** În demo, votul este final; pentru corecție ar fi nevoie de un flux administrativ, care nu există încă.

### 438. Ce faci dacă ai apăsat „Preia” din greșeală?

**Răspuns:** Folosești „retrage-mă”; tichetul și votul se curăță, iar locul se eliberează.

### 439. Cum verifici rapid că totul merge înainte de demo?

**Răspuns:** Rulezi `flutter analyze`, `flutter test`, testele backend, apoi smoke-ul pe un store curat.

### 440. Care este checklist-ul de demo?

**Răspuns:** Backend pornit, telefon pe Live, ADB reverse activ, seed încărcat, dashboard deschis, Ollama/Whisper calde și un plan B pe modul local.

### 441. Cum faci un backup al stării demo?

**Răspuns:** Copiezi `wingman.db` după seed, ca să poți reveni fără să recreezi totul.

### 442. Cum resetezi complet mediul?

**Răspuns:** Oprit backendul, șters `wingman.db` sau reset endpoint, repornit backendul, rulat seed-ul.

### 443. Ce loguri sunt utile când ceva pică?

**Răspuns:** `backend.log`/`backend.log.err`, consola Flutter, logcat pentru Android și Network tab pentru dashboard.

### 444. De ce testele nu prind toate bug-urile de rețea?

**Răspuns:** Testele rulează de obicei local și determinist; condițiile reale de cablu, Wi-Fi, somn și reverse sunt testate manual și prin smoke.

### 445. Ce este testarea manuală în demo?

**Răspuns:** Parcurgerea flow-urilor reale pe telefon și dashboard: raportare, preluare, vot, confirmare, eroare și revenire.

### 446. Cum demonstrezi că aplicația este stabilă?

**Răspuns:** Arăți testele verzi, smoke-ul 111/111, un flow live complet și un plan B local.

### 447. Ce faci dacă rămâi fără timp în demo?

**Răspuns:** Treci pe modul local, arăți cele cinci cazuri instant și explici că arhitectura live există separat.

### 448. Care este cel mai frecvent motiv de confuzie în demo?

**Răspuns:** Amestecul dintre modul local și live; spune explicit pe care ești înainte de a arăta un flux.

### 449. Cum arăți că un tichet este real?

**Răspuns:** Arăți id-ul, statusul, joinedCrewIds, voturile, timestamps și intrarea din baza de date/istoric.

### 450. Cum demonstrezi flagship-ul de quorum?

**Răspuns:** Preiei un tichet cu un responder, arăți că nu se închide când lipsește al doilea, apoi finalizezi cu al doilea și adminul.

## 10. Interviu, tradeoff-uri și roadmap

### 451. De ce ai construit Wingman?

**Răspuns:** Pentru că în aeroporturi informația se pierde între echipe, iar un răspuns rapid depinde de cine aude primul și pe cine sună; Wingman transformă observația într-un flux coordonat.

### 452. Care a fost cea mai grea problemă tehnică?

**Răspuns:** Sincronizarea în timp real combinată cu reguli stricte de quorum și stări care trebuie să fie identice pe telefon, dashboard și backend.

### 453. Ce compromis ai făcut între viteză și acuratețe?

**Răspuns:** Am ales un model mic, rapid, plus gărzi deterministe și verificare umană, în locul unui model mare care ar fi fost mai lent și mai greu de controlat.

### 454. De ce nu ai antrenat un model propriu?

**Răspuns:** Pentru un demo, promptul, taxonomia închisă, gărzile și fallback-ul oferă un raport calitate/timp mai bun decât antrenarea unui model nou.

### 455. Ce ai face cu mai mult timp?

**Răspuns:** Aș adăuga autentificare reală, audit, notificări push, integrare cu sistemele aeroportuare și un pilot cu utilizatori reali.

### 456. Ce este cel mai important lucru pe care l-ai învățat?

**Răspuns:** În sisteme operaționale, încrederea se câștigă prin predictibilitate și audit, nu prin spectacolul AI-ului.

### 457. Cum ai prioritizat feature-urile?

**Răspuns:** Am pornit de la fluxul critic: raportare, clasificare, dispatch, preluare, rezolvare, confirmare; abia apoi am adăugat detalii de UI și optimizări.

### 458. Ce feature ai tăia primul?

**Răspuns:** Orice element cosmetic care nu ajută un operator să raporteze sau să rezolve un tichet; în demo, claritatea fluxului bate ornamentul.

### 459. Care este diferența față de un chatbot?

**Răspuns:** Wingman creează tichete cu reguli de stare, quorum și audit; un chatbot doar conversează, nu coordonează echipe.

### 460. Care este diferența față de un sistem de ticketing clasic?

**Răspuns:** Wingman pornește de la voce și context, clasifică automat și are reguli de răspuns adaptate incidentelor aeroportuare.

### 461. Cine este concurența?

**Răspuns:** Sistemele de dispecerat, aplicațiile de incident reporting, radio-ul și telefoanele; Wingman le unifică într-un flux mobil și local-first.

### 462. Care este avantajul competitiv?

**Răspuns:** Fluxul complet, local, cu AI controlabil și posibilitatea de a demonstra în câteva minute pe telefon și dashboard.

### 463. Cum vinzi ideea unui aeroport?

**Răspuns:** Cu un pilot pe un terminal, KPI clari și o demonstrație care arată timpul economisit între raportare și preluare.

### 464. Care este modelul de business posibil?

**Răspuns:** Abonament per aeroport sau per număr de utilizatori, cu servicii de integrare și suport; pentru hackathon, produsul este demonstrativ.

### 465. Care este piața adresată?

**Răspuns:** Aeroporturi regionale și internaționale, operatori de terminal, ground handling și echipe de facility management.

### 466. Cât costă rularea demo-ului?

**Răspuns:** Aproximativ zero cost de cloud, pentru că AI-ul rulează local; costul real este laptopul și timpul de integrare.

### 467. Cum scalezi la zeci de aeroporturi?

**Răspuns:** Cu multi-tenant, identitate reală, configurare per aeroport, un event bus pentru WSS și o bază de date gestionată.

### 468. Ce se întâmplă dacă AI-ul nu este disponibil?

**Răspuns:** Meniul și fallback-ul determinist permit continuarea; un incident nu trebuie blocat de indisponibilitatea unui model.

### 469. Ce se întâmplă dacă backendul nu este disponibil?

**Răspuns:** Build-ul local mock permite demonstrarea board-ului; pentru producție ar trebui un mod offline cu sincronizare ulterioară.

### 470. De ce modul local nu este suficient pentru producție?

**Răspuns:** Pentru că datele sunt în memorie și nu există sincronizare multi-device; este un instrument de demo, nu o bază de date distribuită.

### 471. Care este cel mai mare risc de securitate?

**Răspuns:** Tokenul demo partajat și lipsa autentificării reale; pentru producție trebuie SSO, MFA, autorizare și audit.

### 472. Cum protejezi datele?

**Răspuns:** Local-first, TLS, token, acces pe roluri; pentru producție se adaugă criptare at-rest, politici de retenție și conformitate.

### 473. Ce reglementări ar conta?

**Răspuns:** GDPR, politici de securitate aeroportuară, standarde operaționale și cerințe interne de audit; nu sunt implementate complet în demo.

### 474. Cum măsori adoptarea?

**Răspuns:** Numărul de rapoarte pe utilizator, timpul până la primul raport, procentul de tichete preluate și retenția echipajelor.

### 475. Cum măsori calitatea clasificării?

**Răspuns:** Procentul de coduri acceptate fără reclassificare, dar și costul unei greșeli critice, nu doar acuratețea medie.

### 476. Ce feedback ai primi de la un dispecer?

**Răspuns:** Probabil că vrea mai puține alerte, filtre mai bune și o confirmare rapidă; dashboardul trebuie să reducă zgomotul, nu să-l adauge.

### 477. Ce feedback ai primi de la un reporter?

**Răspuns:** Vrea să raporteze în câteva secunde, fără formular și fără să repete; de aceea vocea și meniul sunt prioritare.

### 478. Cum tratezi utilizatorii cu accent sau limbă diferită?

**Răspuns:** Limba forțată și meniul reduc riscul, dar nu elimină dificultatea; un sistem real ar avea feedback și antrenament pe accent.

### 479. Ce faci dacă un utilizator raportează în engleză?

**Răspuns:** Whisper este forțat pe limba selectată, iar LLM-ul acceptă text englez; meniul are etichete englezești în fluxul de raportare.

### 480. De ce nu folosești un singur buton „panic”?

**Răspuns:** Pentru că un incident are nevoie de tip, locație și context; un buton panică poate declanșa prea multe echipe și prea puțină informație.

### 481. Care este cel mai bun demo de 30 de secunde?

**Răspuns:** Raportezi vocal fum, arăți clasificarea, aduci pompierii și securitatea, preiei cu un responder, arăți pending admin și confirmi rezolvarea.

### 482. Ce spui dacă juriul întreabă „de ce nu folosiți ChatGPT?”

**Răspuns:** „Pentru că datele și latența trebuie controlate local, iar decizia operațională trebuie să rămână în taxonomie și sub control uman.”

### 483. Ce spui dacă juriul întreabă „de ce SQLite?”

**Răspuns:** „Pentru demo este suficient, persistă și e ușor de resetat; producția ar folosi PostgreSQL sau un serviciu gestionat.”

### 484. Ce spui dacă juriul întreabă „ce se întâmplă la scară?”

**Răspuns:** „Arhitectura actuală este single-node; scalarea cere event bus, DB partajat, izolare per tenant și autentificare reală.”

### 485. Care este cel mai bun argument pentru investitor?

**Răspuns:** Reduce timpul de reacție și creează un istoric operațional care poate preveni incidente viitoare.

### 486. Care este cel mai bun argument pentru un operator?

**Răspuns:** Echipele ajung mai repede la incidentul potrivit, cu mai puține telefoane și mai multă urmăribilitate.

### 487. Care este cel mai bun argument pentru un angajat?

**Răspuns:** Poate raporta în câteva secunde, fără să știe taxonomia pe de rost și fără să sune pe cineva.

### 488. Ce ai face diferit dacă ai lua-o de la zero?

**Răspuns:** Aș defini mai devreme contractul stărilor și al testelor, apoi aș construi UI-ul peste un backend stabil.

### 489. Care a fost cel mai util test?

**Răspuns:** Smoke-ul live, pentru că a prins diferențe între API, WSS, stări și datele demo pe care testele izolate nu le vedeau.

### 490. Care a fost cel mai mare risc de demo?

**Răspuns:** Conexiunea USB/WSS și timpul de încărcare a modelelor; le-am redus cu modul local, warm-up și retry.

### 491. Ce faci dacă demo-ul pică în fața juriului?

**Răspuns:** Treci pe modul local, explici separat arhitectura live și arăți testele; nu ascunzi eroarea.

### 492. Ce înseamnă „fail safe” în acest produs?

**Răspuns:** Dacă AI-ul sau serverul nu răspunde, utilizatorul poate folosi meniul sau modul local, iar incidentul nu este pierdut.

### 493. Ce înseamnă „human in the loop”?

**Răspuns:** Dispecerul poate reclassifica/respinge, iar adminul confirmă rezolvarea cazurilor periculoase.

### 494. Ce ai vrea să implementezi în continuare?

**Răspuns:** Autentificare reală, notificări push, offline sync, integrare cu CAD/radio, audit și un pilot real.

### 495. Care este următorul pas pentru produs?

**Răspuns:** Un pilot într-un singur terminal, cu 20–30 de utilizatori, KPI măsurați și feedback structurat.

### 496. Ce înseamnă succesul în 6 luni?

**Răspuns:** Un aeroport folosește zilnic fluxul, are timpi de răspuns măsurabili și nu mai pierde rapoarte între echipe.

### 497. Ce înseamnă succesul în 5 ani?

**Răspuns:** Wingman devine stratul de coordonare pentru incidentele aeroportuare, cu integrare în sistemele operaționale și date pentru prevenție.

### 498. Care este cea mai bună întrebare pe care ți-a pus-o cineva?

**Răspuns:** „Ce se întâmplă dacă AI-ul greșește?” — pentru că a forțat designul să fie sigur, nu doar inteligent.

### 499. Care este cel mai important lucru pe care să-l spui la final?

**Răspuns:** Wingman nu înlocuiește oamenii; le dă un mod rapid, clar și verificabil de a lucra împreună.

### 500. Care este cea mai mare limitare a demo-ului?

**Răspuns:** Demo-ul este un prototip local: nu are autentificare reală, scalare multi-aeroport sau integrare cu sisteme operaționale; acestea sunt pași de producție, nu promisiuni ascunse.

---
## Fapte-cheie de memorat

### Stack
- **Mobil:** Flutter/Dart, Android.
- **Backend:** FastAPI/Python, REST + WSS, TLS pe portul `8443`.
- **Persistență:** SQLite, `backend/data/wingman.db`; persistă între reporniri.
- **AI local:** Ollama `qwen2.5:1.5b` pentru clasificare; faster-whisper `small` pe CPU, int8, pentru voce.
- **Control room:** dashboard web separat, care citește același backend.

### Produs
- 10 conturi demo: `admin` + 9 departamente.
- 16 tipuri de incidente într-o taxonomie închisă.
- Meniu 8×8×8 = **512 combinații**.
- Urgențe: `low`, `medium`, `high`, `critical` (verde, galben, portocaliu, roșu).
- Stări: `dispatched`, `in_progress`, `pending_resolution`, `resolved`, `denied`.
- Regula de quorum: un responder per departament primar.
- High/critical: quorum → `pending_resolution` → confirmare admin → `resolved`.
- Low/medium: quorum → `resolved` direct.
- Rewards: **2 puncte** raportare, **5 puncte** join + rezolvare; UI cu două categorii, Raportare și Rezolvare.

### Demo
- Seed: **1 low** (`OP-OTHER`), **1 medium** (`SF-SPILL`), **2 high** (`SC-BAG`, `SC-ITEM`), **1 critical** (`SF-FIRE`).
- `SF-FIRE` are 2 departamente primare și cere 2 responderi; celelalte 4 cazuri au quorum 1 în seed.
- Dashboardul și telefonul partajează backendul în modul live.
- Build local mock: board în memorie, fără REST/WSS, switch din login: **Treci pe Local / Live**.

### Teste
- **198 teste Flutter**
- **24 teste backend**
- **111/111 smoke checks**
- `flutter analyze` curat.

### Comenzi utile
```powershell
# backend
cd backend
.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8443 ^
  --ssl-keyfile certs/server.key --ssl-certfile certs/server.crt

# teste
flutter analyze
flutter test
cd backend; .venv\Scripts\python.exe -m unittest discover -s tests

# seed + smoke
python backend\seed_demo.py --base https://127.0.0.1:8443
python scripts\smoke_test.py --base https://127.0.0.1:8443

# local mock APK
flutter build apk --release --dart-define=LOCAL_MOCK=true ^
  --dart-define=API_BASE=https://127.0.0.1:8443 ^
  --dart-define=API_TOKEN=demo-token
```

### Endpointuri principale
- `POST /api/reports`
- `POST /api/analyze`
- `POST /api/transcribe`
- `GET /api/tickets`
- `POST /api/tickets/{id}/join`
- `POST /api/tickets/{id}/vote`
- `POST /api/tickets/{id}/leave`
- `POST /api/tickets/{id}/deny`
- `POST /api/tickets/{id}/override`
- `POST /api/tickets/{id}/resolution-confirm`
- `PATCH /api/tickets/{id}`
- `GET /api/stats?period=day|week|month|year`
- `GET /api/health`
- `WS /ws`

### Limite pe care trebuie să le spui sincer
- Autentificarea este demo (conturi hardcodate + token partajat), nu SSO/MFA de producție.
- Modul local este in-memory și nu se sincronizează cu dashboardul.
- Localizarea completă RO/EN este pentru fluxul de raportare; ecranele de crew/dispecer sunt încă în română.
- AI-ul este un model mic local; are gărzi, fallback și verificare umană, nu garanții de producție.
- Sistemul este single-node; scalarea cere altă arhitectură.
