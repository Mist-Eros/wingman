# Teammate onboarding — what to give the team

## 1. Recommended: one private GitHub repo

Best for 3 people + merge protocol. On the demo laptop:

```powershell
# 1) create an empty private repo on github.com (no README, no .gitignore)
#    e.g. https://github.com/Mist-Eros/wingman

cd D:\Hackathon\Wingman
git remote add origin https://github.com/Mist-Eros/wingman.git
git push -u origin main
# 2) GitHub → Settings → Collaborators → add the 3 teammates (write access)
```

Teammates:

```powershell
git clone https://github.com/Mist-Eros/wingman.git
cd wingman
flutter pub get
flutter analyze
flutter test
```

Branch rule: `feat/reporter`, `feat/dispatcher`, `feat/crew`. Only the Lead merges into `main`
(integration windows — see `docs/48h-timeline.md`). Never edit `lib/core/`, `lib/main.dart`,
`backend/`, `scripts/` — read `CONTRACTS.md` §1.

## 2. No GitHub account right now: git bundle (works today)

The Lead can export the full history into one file:

```powershell
cd D:\Hackathon\Wingman
git bundle create ..\Wingman.bundle --all
```

Send `D:\Hackathon\Wingman.bundle`. Teammates clone from it and can later switch origin to GitHub:

```powershell
git clone Wingman.bundle Wingman
cd Wingman
git remote remove origin        # later: git remote add origin https://github.com/Mist-Eros/wingman
flutter pub get && flutter analyze && flutter test
```

## 3. Fallback: zip

`D:\Hackathon\Wingman-repo.zip` — no git history, no merge protocol. Use only if the above fail.
Re-download it after every integration window.

## 4. What every teammate needs installed

| Tool | Version | Notes |
|---|---|---|
| Flutter SDK | 3.47.x (Dart 3.13) | `flutter --version`; older 3.2x may work but not tested |
| Android SDK | platform 36 + **37** , build-tools 37 | needed because `compileSdk = 37` (permission_handler) |
| JDK | 17 | Gradle build |
| A device or emulator | Android | `flutter devices` |

Commands (Windows):

```powershell
winget install --id EclipseAdoptium.Temurin.17.JDK -e
# Android cmdline tools + platforms (once):
sdkmanager "platform-tools" "platforms;android-36" "platforms;android-37.0" "build-tools;37.0.0"
flutter config --android-sdk <path-to-sdk>
flutter doctor
```

iOS builds need macOS/Xcode — currently out of the critical path (cloud Mac later).

## 5. First 30 minutes per person

1. Clone/bundle, `flutter pub get`, `flutter analyze` → must say **No issues found**.
2. `flutter test` → 16 passed, live tests skipped.
3. Read `CONTRACTS.md` §1–§7 and `docs/analyze-contract.md` (F1).
4. Run the app with the demo backend:
   `flutter run --dart-define=API_BASE=https://10.10.28.37:8443 --dart-define=API_TOKEN=demo-token`
5. Confirm in chat: "app boots to the role picker; board shows N tickets".

## 6. What each owner builds

| Owner | Folder | First milestone |
|---|---|---|
| F1 | `lib/features/reporter/` | voice + menu, `api.analyze` conversation loop, submit to `/api/reports` |
| F2 | `lib/features/dispatcher/` | live list from `board.tickets`, 5 s override card (`board.confirm/deny/reclassify`) |
| F3 | `lib/features/crew/` | dispatch list, `board.join` + `board.vote` with quorum progress |
| Lead | `lib/core`, `main.dart`, `backend` | contracts frozen, backend live, gates green |

## 7. Message to paste in the group chat

> Salut! Repo-ul: **`https://github.com/Mist-Eros/wingman`** (sau `Wingman.bundle` dacă nu ai încă git).
> Înainte de cod: citește `CONTRACTS.md` §1–§7. Reguli scurte:
> • lucrezi doar în `lib/features/<rolul tău>/`; nu atingi `lib/core/`, `lib/main.dart`, `backend/`;
> • branch propriu (`feat/reporter` / `feat/dispatcher` / `feat/crew`), PR doar în ferestrele de integrare;
> • înainte de PR: `flutter analyze` curat + `flutter test` verde;
> • backend-ul e live pe `https://10.10.28.37:8443` (token `demo-token`) — app-ul se rulează cu
>   `--dart-define=API_BASE=https://10.10.28.37:8443 --dart-define=API_TOKEN=demo-token`;
> • dacă ai nevoie de schimbare de contract, cere-i Lead-ului, nu o face local.
