# Wingman — Pitch playbook pentru 3 minute

> **De ce ai nevoie de mai multe metode:** 3 minute nu sunt un demo lung și nici un tur de funcții. Sunt o singură promisiune, două dovezi și o cerere clară. Metoda se alege după public: juriu tehnic, investitori, operatori aeroportuari sau public non-tehnic.

---

## 1. Ce nu a funcționat în flow-ul anterior

Flow-ul vechi încerca să arate tot:
- voce + transcriere + dashboard + quorum + aprobare admin + arhitectură + teste;
- două voci care intrau una peste alta;
- prea multe click-uri pentru 180 de secunde;
- publicul trebuia să rețină funcții, nu o idee.

**Problema nu a fost conținutul, ci încărcătura.** Pentru 3 minute, o singură idee trebuie să rămână: **un incident, o voce, echipa potrivită, confirmată de un om.**

---

## 2. Regula celor 3 minute

Împarte pitch-ul în 5 blocuri, nu în 12:

1. **HOOK** — 15–25 secunde
2. **PROBLEMĂ** — 25–40 secunde
3. **SOLUȚIE** — 20–30 secunde
4. **DOVADĂ** — 60–80 secunde
5. **ÎNCHIDERE / ASK** — 20–30 secunde

> O singură promisiune. Două dovezi. Un singur call to action.

---

## 3. Alege metoda după public

| Metodă | Cel mai bun pentru | Demo | Risc |
|---|---|---|---|
| **A. Story-led proof** | juriu mixt, semifinală | 1 voce + 1 aprobare | mediu |
| **B. PAS fără demo** | non-tehnic, timp scurt | nu | mic |
| **C. Before/After** | operatori aeroportuari | dashboard | mic |
| **D. Objection-first** | juriu tehnic, AI skeptics | aprobare admin | mic |
| **E. Demo-first** | juriu vizual, hackathon | voce + dashboard | mare |
| **F. Investor thesis** | investitori/accelerator | 20 sec | mic |
| **G. Lightning 60s** | rundă scurtă, elevator | nu | mic |

**Recomandarea mea pentru pre-pitch:** **A** cu un singur vorbitor, sau **C** dacă publicul este operațional. Nu folosi E decât dacă ai un operator foarte bun.

---

## 4. Metoda A — Story-led proof (recomandată)

**Public:** juriu mixt, 3 minute, vrei impact și dovadă.
**Roluri:** 1 vorbitor + 1 operator (operatorul nu vorbește).

### 0:00–0:25 — Hook

> „E 14:10 într-un terminal. Un angajat vede o scurgere lângă poarta 3. Știe că trebuie să anunțe pe cineva, dar nu știe exact pe cine. Sună. Așteaptă. Cineva trimite mesajul mai departe. În tot acest timp, lumea trece prin zonă.”

**Arată:** dashboardul, fără click. Se vede coada colorată.

### 0:25–0:50 — Problema

> „Problema nu este că oamenii nu observă. Problema este că observația nu ajunge la echipa potrivită, cu context, la timp. Iar când un incident este critic, fiecare minut de coordonare contează.”

### 0:50–1:10 — Soluția

> „Wingman transformă o observație într-un tichet operațional. Voce sau meniu, AI local care alege din taxonomia aeroportului, apoi tichetul ajunge doar la echipele care trebuie să acționeze. Un responder per departament, iar cazurile periculoase nu se închid fără un om.”

### 1:10–1:50 — Dovada 1: voce → tichet

**Operatorul:** telefonul pe Raportare. Ține microfonul, spune:

> „Este o scurgere mare de ulei lângă poarta 3, e alunecos.”

**Vorbitorul, peste procesare:**

> „Whisper rulează local; transcriptul rămâne editabil. Ollama alege codul din taxonomie, iar noi vedem exact ce a înțeles.”

Când apare rezultatul:
- arată codul `SF-SPILL`, badge-ul **Medie**;
- arată echipele;
- spune: „Dacă a greșit, corectăm înainte de trimitere.”
- trimite.

### 1:50–2:15 — Dovada 2: aprobare umană

**Operatorul:** deschide în dashboard tichetul `SF-FIRE` deja adus în **„Așteaptă confirmarea”**; apasă **„Aprobă rezolvarea”**.

**Vorbitorul:**

> „Echipajul a votat, dar un incident critic nu se închide singur. Aici intervine omul: confirmă, iar tichetul devine rezolvat. AI-ul propune; omul confirmă.”

### 2:15–2:40 — De ce este credibil

> „Rulează local, deci datele nu pleacă în cloud. Dacă modelul lipsește, avem fallback determinist și meniu. Dacă serverul cade, avem build local pentru demo. Și fiecare decizie importantă lasă urmă.”

### 2:40–3:00 — Închidere

> „Wingman nu înlocuiește oamenii. Le dă un mod rapid, clar și verificabil de a reacționa împreună. Următorul pas este un pilot într-un terminal, cu timpi măsurați. Care parte ar merita testată prima?”

---

## 5. Metoda B — PAS fără demo

**Public:** non-tehnic, timp scurt, sală cu demo riscant.
**Roluri:** 1 vorbitor.

### 0:00–0:30 — Problem

> „Într-un aeroport, un incident începe cu cineva care vede ceva. Nu începe cu un formular. Și tocmai de aceea se pierde: omul trebuie să știe pe cine să sune, iar informația se degradează la fiecare transfer.”

### 0:30–1:10 — Agitate

> „Astăzi, același incident poate ajunge la trei oameni diferiți, pe trei canale diferite. Nimeni nu știe dacă a fost preluat, cine lucrează la el și cât timp a trecut. Iar dispecerul nu are o imagine completă.”

### 1:10–1:50 — Solution

> „Wingman unifică raportarea, rutarea și rezolvarea. Angajatul vorbește sau alege din meniu. Sistemul încadrează incidentul în taxonomia aeroportului și îl trimite echipelor primare. Un responder per departament, iar cazurile high/critical primesc confirmare umană.”

### 1:50–2:35 — Proof

> „Avem fluxul complet funcțional: raportare vocală, clasificare, dashboard în timp real, preluare, vot, confirmare admin, timer și AHT. AI-ul rulează local, are fallback determinist și este testat cu scenarii demo. Nu este un slide; este un sistem care merge.”

**Arată dashboardul 5 secunde.** Nu deschide telefonul.

### 2:35–3:00 — Close

> „Wingman nu este încă un chat. Este stratul care transformă o observație într-un răspuns coordonat, măsurabil și verificabil. Următorul pas este un pilot cu o singură echipă.”

---

## 6. Metoda C — Before/After

**Public:** operatori aeroportuari, management, oameni de proces.
**Roluri:** 1 vorbitor + operator.

### 0:00–0:30 — Before

> „Astăzi: un angajat vede o problemă, sună, explică, iar dispecerul sună mai departe. Contextul se pierde, nimeni nu știe dacă echipa a ajuns, iar la final nu există un timp clar.”

**Arată dashboardul vechi?** Nu ai nevoie; descrie.

### 0:30–1:00 — After

> „Cu Wingman: același angajat apasă un buton, vorbește 5 secunde, iar tichetul apare cu tip, urgență, locație și echipe. Dispecerul vede tot, echipa preia, iar timpul curge până la confirmare.”

### 1:00–1:45 — Dashboard demo

- arată cele 5 carduri colorate;
- selectează `SF-FIRE` pending;
- arată `2/2` voturi și butonul **Aprobă rezolvarea**;
- apasă; arată cum dispare din coadă și intră în istoric.

**Spune:**

> „Diferența nu este doar viteza. Este trasabilitatea: cine a raportat, cine a preluat, cine a confirmat.”

### 1:45–2:20 — Adoption

> „Se adoptă pe un singur terminal, cu conturi pe departamente și un training de 15 minute. KPI: timp până la preluare, timp până la rezolvare, procentul de rutare corectă.”

### 2:20–3:00 — Close

> „Nu cerem aeroportului să schimbe tot. Cerem un terminal, o echipă și 30 de zile pentru a măsura.”

---

## 7. Metoda D — Objection-first

**Public:** juriu tehnic, oameni care nu au încredere în AI.
**Roluri:** 1 vorbitor + operator.

### 0:00–0:20 — Objection

> „Cea mai bună întrebare despre un sistem cu AI este: ce face când greșește? Dacă răspunsul este «nimic», produsul nu este gata.”

### 0:20–1:00 — Guardrails

> „La Wingman, AI-ul nu decide singur. Poate alege doar din 16 coduri. Urgența poate fi ridicată, nu coborâtă. Dispecerul poate reclassifica sau respinge. Cazurile high/critical cer confirmare umană. Iar dacă modelul lipsește, există fallback determinist și meniu.”

### 1:00–1:45 — Demo

- deschide dashboardul pe `SF-FIRE` pending;
- arată `2/2`, statusul **Așteaptă confirmarea**;
- apasă **Aprobă rezolvarea**;
- spune: „omul închide bucla.”

### 1:45–2:20 — Technical proof

> „Avem taxonomie închisă, versionare, WSS, retry, teste pentru clasificare și un board local pentru demo. Nu vindem încredere oarbă; vindem un flux care greșește în siguranță.”

### 2:20–3:00 — Close

> „AI-ul nu înlocuiește dispecerul. Îl ajută să vadă repede, iar apoi îi lasă decizia finală.”

---

## 8. Metoda E — Demo-first

**Public:** hackathon, juriu vizual, timp foarte strâns.
**Roluri:** 1 vorbitor + operator foarte bun. **Risc mare.**

### 0:00–0:10 — Deschidere

> „Vă arăt direct ce se întâmplă când cineva vede o problemă.”

### 0:10–0:50 — Phone

- raportare vocală scurtă;
- arată transcriptul și codul;
- trimite.

### 0:50–1:30 — Dashboard

- arată noul tichet;
- arată urgența, echipele, timerul;
- spune: „a apărut în timp real.”

### 1:30–2:10 — Admin

- selectează pending;
- arată `2/2`;
- apasă **Aprobă**;
- spune: „un om confirmă.”

### 2:10–2:35 — Ce este dedesubt

> „AI local, taxonomie închisă, WebSocket, fallback determinist.”

### 2:35–3:00 — Close

> „Un incident, o voce, echipa potrivită. Asta este Wingman.”

**Când nu folosi E:** dacă nu ai operator, dacă vocea nu e stabilă, dacă publicul vrea business.

---

## 9. Metoda F — Investor thesis

**Public:** investitori, accelerator, oameni de business.
**Roluri:** 1 vorbitor. Demo maxim 20 secunde.

### 0:00–0:20 — Why now

> „Aeroporturile digitalizează operațiunile, dar coordonarea incidentelor rămâne fragmentată între radio, telefon și foi de calcul. AI-ul local a devenit suficient de bun și de ieftin pentru a schimba asta.”

### 0:20–0:50 — Problem + market

> „Fiecare minut de întârziere înseamnă pasageri expuși, zboruri întârziate și echipe blocate. Este o piață operațională mare, cu bugete reale și un cumpărător clar: operatorul aeroportuar.”

### 0:50–1:30 — Solution + wedge

> „Wingman pornește cu raportarea și dispatch-ul incidentelor, apoi extinde către coordonare, istoric și prevenție. Wedge-ul este un terminal, nu un aeroport întreg.”

### 1:30–2:20 — Proof

> „Avem un produs funcțional, AI local, flux complet de la voce la confirmare admin, dashboard în timp real și un build offline pentru demo. Următorul pas este un pilot plătit.”

### 2:20–3:00 — Ask

> „Căutăm un pilot cu un operator aeroportuar și feedback de la oameni care lucrează în teren. Nu vindem încă la scară; validăm un terminal.”

---

## 10. Metoda G — Lightning 60 secunde

Pentru o rundă scurtă, un elevator pitch sau începutul unui Q&A:

> „Un incident începe cu cineva care vede ceva. Problema este că observația nu ajunge la echipa potrivită la timp. Wingman transformă vocea în tichet, alege din taxonomia aeroportului și trimite doar echipele care trebuie să acționeze. Un responder per departament, confirmare umană pentru cazurile critice. AI local, fallback determinist, dashboard în timp real. Următorul pas: un pilot într-un terminal.”

**60 secunde:**
- 0–10 hook
- 10–25 problemă
- 25–40 soluție
- 40–52 dovadă
- 52–60 ask

---

## 11. Un vorbitor sau doi?

### Recomandat: un vorbitor + un operator

- Vorbitorul deține firul narativ;
- operatorul face click-urile, fără să vorbească;
- publicul urmărește o singură voce.

### Dacă trebuie doi vorbitori

- V1: 0:00–1:10 (story + problem + solution);
- V2: 1:10–2:15 (demo + admin);
- V1: 2:15–3:00 (proof + close).

**Handoff-uri scurte:**
- V1 → V2: „Hai să vedem fluxul real.”
- V2 → V1: „Aici intervine controlul uman.”
- V1 → public: „Și asta este Wingman.”

Nu alterna la fiecare propoziție; publicul pierde firul.

---

## 12. Staging pentru orice metodă

- Dashboardul deschis pe `Coadă`.
- Un `SF-FIRE` deja în `pending_resolution`, selectat, cu **Aprobă rezolvarea** vizibil.
- Telefonul pe Raportare, mod Live, reverse activ.
- Un singur click de voce; dacă ezită > 3 secunde, meniu.
- Un singur click de admin; nu deschide istoric/statistici în timpul pitch-ului.
- Dacă ceva pică: treci pe local, spui „rulez build-ul local, arhitectura live este separată” și continui. Nu depana în direct.

---

## 13. Închideri bune

Alege una, nu trei:

- **Operator:** „Care terminal ar merita pilotat primul?”
- **Investitor:** „Care este cel mai bun mod de a ajunge la un operator pentru un pilot?”
- **Juriu:** „Ce ar trebui să demonstrăm mai departe ca să merite un pilot?”
- **Feedback:** „Ce parte vi se pare cea mai puțin credibilă?”

Evită „Aveți întrebări?” — este pasiv.

---

## 14. Antrenament în 30 de minute

1. Rulează metoda aleasă o dată, cu cronometru.
2. Taie 20% din cuvinte; păstrează doar promisiunea și dovezile.
3. Repetă începutul și finalul până sunt naturale.
4. Testează cu o persoană non-tehnică: trebuie să poată spune ce face produsul și de ce este sigur.
5. Rulează din nou cu demo-ul; dacă un pas ia > 15 secunde, scoate-l.

---

## 15. Recomandarea finală

Dacă nu știi publicul, folosește **Metoda A**, cu **un singur vorbitor și un operator**:

- 25s story;
- 25s problemă;
- 20s soluție;
- 40s voce → tichet;
- 25s aprobare admin;
- 25s credibilitate;
- 20s close.

Este cea mai bună combinație între emoție, dovadă și siguranță pentru 3 minute.

Dacă publicul este non-tehnic sau demo-ul este instabil, folosește **Metoda B**.
Dacă publicul este operațional, folosește **Metoda C**.
Dacă publicul este tehnic și sceptic, folosește **Metoda D**.
