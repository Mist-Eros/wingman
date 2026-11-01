# Wingman — pre-pitch de 3 minute

> **Pentru variante alternative de pitch (investor, operator, juriu tehnic, fără demo, 60 secunde), vezi [pitch-playbook.md](pitch-playbook.md).**

> **Obiectiv:** în 180 de secunde să înțeleagă (1) ce problemă rezolvăm, (2) că fluxul chiar merge, (3) de ce este sigur și (4) ce urmează.
>
> **Regulă:** nu facem tur de funcții. Arătăm doar **3 momente**: un raport vocal, un tichet în dashboard și o aprobare de admin.

---

## 1. Înainte de pitch — 10 minute de pregătire

### Stare recomandată

- Backend pornit, 5 tichete seed.
- Dashboard deschis pe **Coadă**, fereastră maximizată.
- Telefon pe ecranul **Raportare**, cu aplicația în mod **Live**.
- `adb reverse tcp:8443 tcp:8443` activ.
- Bypass locație valid pentru durata pitch-ului.
- Un tichet **SF-FIRE** adus în `pending_resolution` (2/2 voturi), ca să existe butonul **„Aprobă rezolvarea”**.
- Selectat tichetul pending în dashboard, ca detaliile și butonul verde să fie deja vizibile.
- Închise: Word, terminale, notificări, alte tab-uri.
- Telefon cu baterie > 50%, sunet pornit, ecran luminos.

### Comandă pentru reset + seed

```powershell
python backend\seed_demo.py --reset --base https://127.0.0.1:8443
```

### Dacă nu există deja un pending

Deschide dashboardul, alege `SF-FIRE`, iar din conturile de crew (pompieri + securitate) dă `Preia` și `Rezolvat`. Când apare badge-ul **„Așteaptă confirmarea”**, ești gata.

### Plan B

Dacă backendul/WSS face figuri:
- rămâi pe **modul local** din telefon („Treci pe Local”);
- spune: „Rulez acum pe build-ul local, ca să nu depindem de rețea; arhitectura live este aceeași, doar transportul diferă”;
- dashboardul rămâne pe datele live, dar nu promite sincronizare între ele.

---

## 2. Împărțirea rolurilor

| Rol | Cine | Ce face |
|---|---|---|
| **V1 — povestea** | un vorbitor | problemă, impact, închidere |
| **V2 — demo** | un vorbitor | telefonul și dashboardul, fără explicații lungi |
| **Operator** | opțional | ține dashboardul/telefonul, dă click când primește cue |

**Recomandare:** 2 vorbitori. V1 vorbește ~70 de secunde, V2 ~90 de secunde, V1 închide ~20 de secunde. Nu vorbiți simultan.

---

## 3. Scenariul pe minute

### 0:00–0:20 — Hook + problemă (V1)

**Spune:**

> „Într-un aeroport, un incident nu începe cu un formular. Începe cu cineva care vede ceva și trebuie să ajungă la echipa potrivită în câteva secunde. Azi, între acești doi pași sunt telefoane, radio-uri și informație pierdută. Wingman închide acest gol.”

**Arată:** dashboardul, fără să dai click. Se văd cele cinci carduri colorate.

**Nu spune:** „avem 16 tipuri, 512 combinații, 198 de teste”. Le spui doar dacă întreabă.

---

### 0:20–0:40 — Ce face produsul (V1)

**Spune:**

> „Angajatul raportează vocal sau din meniu. AI-ul local încadrează incidentul în taxonomia aeroportului, iar tichetul ajunge doar la echipele care trebuie să acționeze. Dispecerul vede tot, echipajul preia, iar cazurile periculoase nu se închid fără confirmarea unui om.”

**Arată:** o singură trecere cu mâna peste coadă: roșu, portocaliu, galben, verde. Nu citi fiecare card.

---

### 0:40–1:25 — Demo 1: voce → tichet (V2)

**Pregătit:** telefonul pe **Raportare**.

**Acțiune:**
1. Ține apăsat microfonul.
2. Spune clar: **„Este o scurgere mare de ulei lângă poarta 3, e alunecos și lumea trece pe lângă.”**
3. Eliberează și spune: „Whisper rulează local, iar transcriptul rămâne editabil.”
4. Când apare rezultatul, arată:
   - codul **SF-SPILL**;
   - badge-ul **Medie / galben**;
   - echipele;
   - faptul că poți corecta orice cuvânt.
5. Apasă **Trimite** (sau confirmă poza cu „fără poză”).

**Spune:**

> „Whisper local transformă vocea în text, Ollama alege codul din taxonomia închisă, iar noi vedem exact ce a înțeles. Dacă greșește, corectăm înainte de trimitere; dacă ezită, meniul este fallback-ul determinist.”

**În timp ce se procesează:** continuă propoziția, nu tăcea. Latența de 1–2 secunde este normală.

**Dacă Whisper nu răspunde în 3 secunde:**

> „Trecem pe meniu, ca să vedeți exact același flux fără dependența de microfon.”

Apasă **„Nu pot vorbi — meniu”**, alege o problemă și trimite. Nu cere scuze; tratează ca pe un fallback proiectat.

---

### 1:25–2:05 — Demo 2: dashboard + admin approval (V2 + V1)

**Acțiune:**
1. Arată noul tichet apărut în dashboard (WSS, fără refresh).
2. Spune: „A apărut în timp real; timerul curge și echipa vede imediat.”
3. Selectează tichetul **SF-FIRE pending** deja pregătit.
4. Arată:
   - status **„Așteaptă confirmarea”**;
   - **voturi 2/2**;
   - butonul verde **„✓ Aprobă rezolvarea”**.
5. Apasă butonul. Tichetul devine **Rezolvat**, coada scade, istoricul crește.

**V1 spune:**

> „Aici este diferența față de un simplu chat: echipajul a votat, dar incidentul critic nu se închide singur. Un om cu vedere de ansamblu confirmă. Oamenii rămân în buclă.”

**V2 adaugă:**

> „Un singur responder per departament, iar cazurile high/critical cer confirmare de admin. Restul se pot rezolva direct.”

---

### 2:05–2:25 — De ce este sigur (V1)

**Spune:**

> „AI-ul rulează local, nu trimite date în cloud. Dacă modelul lipsește, avem fallback determinist și meniu. Dacă serverul cade, avem build local pentru demo. Iar fiecare decizie importantă lasă un istoric: cine, când și ce a confirmat.”

**Arată:** rapid badge-urile din dashboard și eventual un timer. Nu deschide cod sau logs.

---

### 2:25–3:00 — Închidere (V1)

**Spune:**

> „Wingman nu înlocuiește oamenii. Le dă un mod rapid, clar și verificabil de a reacționa împreună. Un incident, o voce, echipa potrivită — în câteva secunde. Următorul pas este un pilot într-un singur terminal, cu KPI măsurați: timp până la preluare, timp până la rezolvare și procentul de rapoarte rutate corect din prima.”

**Ultima propoziție:**

> „Vă mulțumim. Ce ar vrea aeroportul să vadă mai întâi: viteza sau trasabilitatea?”

---

## 4. Cue card — o pagină pentru vorbitor

| Timp | Cine | Ce spune | Ce arată |
|---|---|---|---|
| 0:00 | V1 | „Un incident începe cu cineva care vede ceva...” | dashboard |
| 0:20 | V1 | „Voce → taxonomie → echipa potrivită...” | cele 5 carduri |
| 0:40 | V2 | „Whisper și Ollama rulează local...” | telefon: înregistrare |
| 1:00 | V2 | „Transcriptul e editabil; codul este SF-SPILL...” | rezultat + trimitere |
| 1:25 | V2 | „Apare live în dashboard...” | noul card |
| 1:40 | V1 | „Criticile nu se închid fără un om...” | pending + 2/2 |
| 1:50 | V2 | „Aprob acum rezolvarea.” | click Aprobă |
| 2:05 | V1 | „Local, fallback, istoric...” | status resolved |
| 2:25 | V1 | „Pilot, KPI, următorul pas.” | dashboard |

---

## 5. Ce NU faci în 3 minute

- Nu arăți autentificarea, setările, DevTools, codul, baza de date sau logs.
- Nu explici toate cele 16 coduri; spui doar „taxonomie închisă”.
- Nu spui „AI-ul decide”; spui „AI-ul propune, omul confirmă”.
- Nu promiți producție, SSO, scalare sau integrare reală.
- Nu rezolvi manual toate cele 5 tichete; arăți un flux, nu un tur.
- Nu vorbiți amândoi peste demo; V2 conduce click-urile, V1 comentariul.

---

## 6. Dacă rămâne timp / întrebări

**„Ce se întâmplă dacă AI-ul greșește?”**

> „Poate fi corectat înainte de trimitere, reclassificat de dispecer sau respins; cazurile periculoase cer confirmare umană.”

**„De ce local?”**

> „Datele nu pleacă în cloud, latența este controlată, iar demo-ul nu depinde de internet.”

**„Ce lipsește pentru producție?”**

> „Autentificare reală, audit, integrare cu sistemele aeroportului, multi-tenant, monitorizare și un pilot operațional.”

**„Care e cel mai mare risc?”**

> „Un incident real să fie ratat sau închis prematur; de aceea avem statusuri explicite, quorum, confirmare admin și fallback.”

---

## 7. Fraze de legătură între vorbitori

- V1 → V2: **„Hai să vedem fluxul real.”**
- V2 → V1: **„Aici intervine controlul uman.”**
- V1 → public: **„Și asta este Wingman.”**

---

## 8. Criteriu de succes al celor 3 minute

La final, publicul trebuie să poată spune:

1. **Ce face:** transformă o observație în tichet și coordonează echipa.
2. **Ce l-a convins:** a văzut un raport vocal și o aprobare admin.
3. **De ce este sigur:** AI local, fallback, quorum și confirmare umană.
4. **Ce urmează:** pilot, KPI, producție.
