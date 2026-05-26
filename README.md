# Footrix

Footrix is a football prediction and trivia app built with Flutter and Firebase. It lets users follow real fixtures, submit score predictions before matches are locked, answer daily football trivia, compete in rankings, and create private groups to play with friends.

Footrix es una aplicacion de predicciones y trivia de futbol desarrollada con Flutter y Firebase. Permite consultar partidos reales, cargar predicciones antes del cierre definido, responder trivia diaria, competir en rankings y crear grupos privados para jugar con amigos.

---

## Espanol

### Descripcion general

Footrix combina una cartelera de partidos, un sistema de predicciones, trivia futbolera, rankings y grupos privados. La app usa Firebase como backend principal y sincroniza el fixture desde la API oficial de FIFA, evitando depender de APIs externas de pago o identificadores inestables de competiciones.

El objetivo del producto es que cada usuario pueda elegir las ligas que desea seguir, jugar predicciones sobre esos partidos, sumar puntos por aciertos y competir tanto en tablas globales como en grupos cerrados.

### Funcionalidades principales

#### Autenticacion y perfil

- Registro e inicio de sesion con correo y contrasena mediante Firebase Authentication.
- Perfil de usuario con nombre, correo, pais, provincia/estado y ciudad.
- Estadisticas personales de predicciones y trivia.
- Seleccion de ligas preferidas desde el perfil para reducir carga y personalizar el fixture.
- Persistencia de preferencias en Firestore por usuario.

#### Fixture y partidos

- Pantalla de fixture organizada por pestanas:
  - Pasados: partidos de los ultimos 30 dias.
  - Hoy: partidos del dia actual.
  - Manana.
  - Proximos dias.
  - Mas: ventana extendida futura.
- Carga progresiva orientada a rendimiento: el usuario ve primero el rango que esta consultando y la app evita cargar todo el calendario completo al abrir.
- Agrupacion de partidos por liga cuando no hay una liga puntual seleccionada.
- Seccion destacada para partidos en vivo.
- Visualizacion de equipos, horarios locales, marcadores, competencia, fase y escudos cuando estan disponibles.
- Fallback visual para escudos o banderas que no carguen.

#### Predicciones

- Los usuarios pueden predecir resultado exacto antes del cierre del partido.
- Las predicciones se validan en Cloud Functions para evitar manipulacion desde el cliente.
- La ventana de cierre se controla desde configuracion global:
  - Por defecto: 12 horas antes del inicio.
  - Un superadministrador puede modificarla desde el panel de administracion.
- Sistema de puntos:
  - 3 puntos por acertar el resultado exacto.
  - 1 punto por acertar ganador o empate.
  - 0 puntos si no coincide el signo del partido.
- Al finalizar un partido, una funcion de backend calcula los puntos y actualiza el perfil del usuario.

#### Trivia

- Trivia futbolera con preguntas de opcion multiple.
- Tiempo limite por pregunta.
- Preguntas aleatorias desde una unica base de datos.
- Las preguntas ya respondidas por un usuario no se vuelven a mostrar.
- Control diario de cantidad maxima de preguntas por usuario.
- El limite diario se configura desde el panel de superadministrador.
- Sistema de racha:
  - Suma racha por respuestas correctas consecutivas.
  - Reinicia la racha con una respuesta incorrecta.
  - Guarda mejor racha historica.
- Puntos de trivia acumulados en el perfil y en los rankings.

#### Rankings

- Ranking global de usuarios.
- Ranking por predicciones.
- Ranking por trivia.
- Ranking combinado.
- Filtros por ubicacion:
  - Mundial.
  - Pais.
  - Provincia/estado.
  - Ciudad.
- Filtro por liga para consultar desempeno en competiciones especificas.

#### Grupos

- Creacion de grupos privados con nombre y liga asociada.
- Cada grupo genera un codigo unico de 6 caracteres.
- Los usuarios pueden unirse ingresando el codigo.
- Posibilidad de crear grupos exclusivos de una liga.
- Invitacion por WhatsApp con el codigo del grupo.
- Copia automatica del codigo al portapapeles como respaldo.

#### Panel de administracion

Disponible solo para usuarios con permisos de administrador.

Permite:

- Ver usuarios.
- Activar o desactivar usuarios.
- Crear partidos manuales.
- Finalizar partidos manuales.
- Sincronizar fixture desde FIFA bajo demanda.
- Configurar cuantas horas antes se cierran las predicciones.
- Configurar cuantas preguntas de trivia puede responder cada usuario por dia.

### Fuente de datos deportivos

Footrix utiliza la API oficial de FIFA:

```text
https://api.fifa.com/api/v3/calendar/matches
```

La sincronizacion se realiza desde Cloud Functions, no directamente desde el cliente Flutter. Esto permite controlar headers, cache, rangos de consulta, normalizacion de datos y escritura centralizada en Firestore.

Detalles implementados:

- Idioma: espanol (`language=es`).
- Cantidad por consulta: `count=500`.
- User-Agent de navegador para evitar respuestas 403.
- Rango sincronizado:
  - 30 dias hacia atras.
  - 90 dias hacia adelante.
- Consulta por bloques diarios para reducir riesgo de respuestas incompletas.
- Extraccion localizada de nombres de equipos, ligas y fases.
- Transformacion de imagenes FIFA:
  - `{format}` se reemplaza por `sq`.
  - `{size}` se reemplaza por `2`.
- Normalizacion de ligas en Firestore para permitir filtrado estable por texto y por identificador interno.

### Arquitectura tecnica

#### Frontend

- Flutter.
- Dart.
- Riverpod para estado y proveedores.
- GoRouter para navegacion.
- Material Design.
- Localizacion preparada para espanol e ingles.
- Firebase Messaging para notificaciones push.

#### Backend

- Firebase Authentication.
- Cloud Firestore.
- Firebase Cloud Functions.
- Firebase Cloud Messaging.
- Firebase Hosting para version web.
- Firebase Security Rules.
- Firestore indexes para consultas de fixture, ligas, rankings y trivia.

#### Cloud Functions principales

- `syncFixturesDaily`: sincroniza diariamente partidos y ligas desde FIFA.
- `syncFixturesNow`: sincronizacion manual desde el panel admin.
- `refreshLeagueCatalog`: refresca catalogo de ligas.
- `pollMatchResults`: consulta resultados recientes cada 30 minutos.
- `validatePredictionEdit`: valida y guarda predicciones de usuarios.
- `calculatePointsOnMatchFinish`: calcula puntos cuando un partido pasa a finalizado.
- `getTriviaQuestions`: devuelve preguntas disponibles segun historial del usuario y limite diario.
- `submitTriviaAnswer`: valida respuestas de trivia y asigna puntos.
- `createGroup`: crea grupos privados.
- `joinGroup`: une usuarios a grupos existentes.
- `adminCreateMatch`: crea partidos manuales.
- `adminFinishMatch`: finaliza partidos manuales.
- `adminToggleUserStatus`: activa o desactiva usuarios.
- `adminUpdatePredictionSettings`: actualiza configuracion de cierre de predicciones.
- `adminUpdateTriviaSettings`: actualiza limite diario de trivia.
- `notifyOnGroupInvite`: notificaciones relacionadas con grupos.
- `notifyOnPointsAssigned`: notificaciones por puntos asignados.

### Modelo de datos principal en Firestore

#### `users`

Guarda perfil y estadisticas:

- `displayName`
- `email`
- `country`
- `province`
- `city`
- `totalPoints`
- `triviaPoints`
- `triviaStreak`
- `triviaBestStreak`
- `triviaAnswered`
- `selectedLeagueIds`
- `leagueStats`

#### `matches`

Guarda partidos sincronizados o creados manualmente:

- `homeTeam`
- `awayTeam`
- `kickoff`
- `status`
- `homeScore`
- `awayScore`
- `phase`
- `leagueId`
- `competitionName`
- `homeTeamLogo`
- `awayTeamLogo`
- `venue`
- `venueCity`
- `apiSource`
- `apiMatchId`
- `lockHoursBefore`

#### `leagues`

Catalogo de ligas disponibles:

- `name`
- `shortName`
- `country`
- `logo`
- `apiSource`
- `filterKeywords`
- `active`
- `syncEnabled`

#### `predictions`

Predicciones por usuario y partido:

- `userId`
- `matchId`
- `homeGuess`
- `awayGuess`
- `status`
- `pointsEarned`
- `submittedAt`
- `gradedAt`

#### `trivia_questions`

Banco unico de preguntas:

- `question`
- `options`
- `correctAnswer`
- `category`
- `points`
- `active`
- `createdAt`

#### `trivia_answers`

Historial de respuestas:

- `userId`
- `questionId`
- `selectedOption`
- `isCorrect`
- `pointsEarned`
- `streakAtAnswer`
- `answeredAt`

#### `groups`

Grupos privados:

- `groupId`
- `name`
- `code`
- `createdBy`
- `members`
- `leagueId`
- `leagueName`
- `isLeagueExclusive`
- `createdAt`
- `updatedAt`

#### `app_config`

Configuracion global:

- `predictions.lockHoursBefore`
- `trivia.dailyQuestionLimit`

### Flujo de juego

1. El usuario se registra o inicia sesion.
2. Selecciona sus ligas preferidas desde el perfil.
3. Entra al fixture y ve partidos filtrados por sus ligas.
4. Carga una prediccion antes del cierre configurado.
5. Cuando el partido finaliza, el backend calcula los puntos.
6. El usuario puede responder trivia diaria para sumar puntos extra.
7. Los puntos impactan en rankings globales, por liga y combinados.
8. El usuario puede crear o unirse a grupos para competir con amigos.

### Instalacion local

#### Requisitos

- Flutter SDK compatible con Dart `^3.11.5`.
- Node.js 20 para Firebase Functions.
- Firebase CLI.
- Android Studio o Android SDK para compilar APK.
- Un proyecto Firebase configurado.

#### Pasos

1. Clonar el repositorio.

```bash
git clone <repository-url>
cd footrix_app
```

2. Instalar dependencias Flutter.

```bash
flutter pub get
```

3. Instalar dependencias de Cloud Functions.

```bash
cd functions
npm install
cd ..
```

4. Configurar Firebase.

El proyecto espera archivos de configuracion generados por FlutterFire:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist` si se compila iOS.

5. Ejecutar la app.

```bash
flutter run
```

### Build

#### Android debug

```bash
flutter build apk --debug
```

#### Android release

```bash
flutter build apk --release
```

El APK release queda en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

#### Web

```bash
flutter build web
firebase deploy --only hosting
```

### Despliegue de Firebase

#### Functions

```bash
firebase deploy --only functions
```

#### Firestore rules

```bash
firebase deploy --only firestore:rules
```

#### Firestore indexes

```bash
firebase deploy --only firestore:indexes
```

#### Todo Firebase

```bash
firebase deploy
```

### Seguridad

- Las predicciones se escriben a traves de Cloud Functions, no directamente desde el cliente.
- Las reglas de Firestore limitan lectura y escritura segun usuario autenticado.
- Las acciones administrativas requieren custom claim de administrador.
- El calculo de puntos ocurre en backend para evitar alteraciones desde el dispositivo.
- La trivia registra respuestas por usuario para impedir repetir preguntas ya contestadas.

### Rendimiento

La app esta pensada para evitar cargas grandes en cada apertura:

- El usuario selecciona ligas preferidas.
- El fixture carga por rangos de fecha y no todo el calendario completo.
- Los escudos se cargan desde URL y tienen fallback visual.
- La sincronizacion con FIFA ocurre en backend y se escribe en Firestore como cache consultable.
- Las consultas del fixture usan filtros por fecha y liga cuando es posible.

### Estado del proyecto

Footrix se encuentra en desarrollo activo. Las areas principales ya implementadas son autenticacion, fixture FIFA, predicciones, trivia, grupos, rankings, perfil, panel admin, notificaciones y despliegue Firebase.

---

## English

### Overview

Footrix is a football prediction and trivia application built with Flutter and Firebase. It combines real fixtures, score predictions, daily football trivia, rankings, and private groups.

The product goal is to let users choose the leagues they want to follow, predict match scores, earn points for correct picks, answer trivia questions, and compete in global or private leaderboards.

### Main features

#### Authentication and profile

- Email and password sign up/sign in with Firebase Authentication.
- User profile with name, email, country, state/province, and city.
- Personal stats for prediction points and trivia points.
- League preference selection to personalize the fixture and reduce loading.
- Preferences are stored per user in Firestore.

#### Fixtures and matches

- Fixture screen organized by date tabs:
  - Past: last 30 days.
  - Today.
  - Tomorrow.
  - Upcoming days.
  - More: extended future range.
- Progressive loading focused on performance.
- Matches grouped by league when no single league is selected.
- Highlighted live section for matches currently in progress.
- Teams, local kickoff time, scores, competition, phase, and crests when available.
- Stable visual fallback when a crest or flag cannot be loaded.

#### Predictions

- Users can predict exact match scores before the configured lock window.
- Prediction validation runs in Cloud Functions to prevent client-side tampering.
- Global prediction lock setting:
  - Default: 12 hours before kickoff.
  - Superadmins can update it from the admin panel.
- Scoring:
  - 3 points for exact score.
  - 1 point for correct winner/draw.
  - 0 points for an incorrect result.
- When a match is finished, backend logic grades all pending predictions and updates user points.

#### Trivia

- Football trivia with multiple-choice questions.
- Time limit per question.
- Random questions from one shared question database.
- Already answered questions are not shown again to the same user.
- Daily question limit per user.
- Daily limit is configurable from the superadmin panel.
- Streak system:
  - Correct answers increase the streak.
  - Incorrect answers reset it.
  - Best historical streak is stored.
- Trivia points are shown in the profile and rankings.

#### Rankings

- Global leaderboard.
- Prediction leaderboard.
- Trivia leaderboard.
- Combined leaderboard.
- Location filters:
  - Worldwide.
  - Country.
  - State/province.
  - City.
- League filter to compare performance in specific competitions.

#### Groups

- Private group creation with name and associated league.
- Each group receives a unique 6-character code.
- Users can join groups by entering the code.
- Groups can be league-exclusive.
- WhatsApp invitation message with the group code.
- Automatic clipboard copy as fallback.

#### Admin panel

Available only to users with admin permissions.

It supports:

- User listing.
- User activation/deactivation.
- Manual match creation.
- Manual match finalization.
- Manual FIFA fixture sync.
- Prediction lock window configuration.
- Daily trivia question limit configuration.

### Sports data source

Footrix uses the official FIFA API:

```text
https://api.fifa.com/api/v3/calendar/matches
```

Synchronization runs in Cloud Functions instead of directly in the Flutter app. This keeps headers, caching, date ranges, parsing, and Firestore writes centralized on the backend.

Implemented details:

- Language: Spanish (`language=es`).
- Request size: `count=500`.
- Browser-like User-Agent to avoid 403 responses.
- Sync range:
  - 30 days back.
  - 90 days forward.
- Daily chunks to reduce the risk of incomplete responses.
- Localized extraction of team, competition, and phase names.
- FIFA image URL transformation:
  - `{format}` becomes `sq`.
  - `{size}` becomes `2`.
- League normalization for stable local filtering.

### Technical architecture

#### Frontend

- Flutter.
- Dart.
- Riverpod for state management.
- GoRouter for navigation.
- Material Design.
- Spanish and English localization support.
- Firebase Messaging for push notifications.

#### Backend

- Firebase Authentication.
- Cloud Firestore.
- Firebase Cloud Functions.
- Firebase Cloud Messaging.
- Firebase Hosting for web deployment.
- Firebase Security Rules.
- Firestore indexes for fixture, leagues, rankings, and trivia queries.

#### Main Cloud Functions

- `syncFixturesDaily`: daily FIFA fixture and league sync.
- `syncFixturesNow`: manual admin-triggered sync.
- `refreshLeagueCatalog`: league catalog refresh.
- `pollMatchResults`: polls recent results every 30 minutes.
- `validatePredictionEdit`: validates and stores user predictions.
- `calculatePointsOnMatchFinish`: grades predictions when a match finishes.
- `getTriviaQuestions`: returns available trivia questions based on user history and daily limit.
- `submitTriviaAnswer`: validates trivia answers and awards points.
- `createGroup`: creates private groups.
- `joinGroup`: joins existing groups.
- `adminCreateMatch`: creates manual matches.
- `adminFinishMatch`: finishes manual matches.
- `adminToggleUserStatus`: activates or deactivates users.
- `adminUpdatePredictionSettings`: updates prediction lock settings.
- `adminUpdateTriviaSettings`: updates daily trivia settings.
- `notifyOnGroupInvite`: group-related notifications.
- `notifyOnPointsAssigned`: point-award notifications.

### Main Firestore data model

#### `users`

Stores profile and stats:

- `displayName`
- `email`
- `country`
- `province`
- `city`
- `totalPoints`
- `triviaPoints`
- `triviaStreak`
- `triviaBestStreak`
- `triviaAnswered`
- `selectedLeagueIds`
- `leagueStats`

#### `matches`

Stores FIFA-synced or manually created matches:

- `homeTeam`
- `awayTeam`
- `kickoff`
- `status`
- `homeScore`
- `awayScore`
- `phase`
- `leagueId`
- `competitionName`
- `homeTeamLogo`
- `awayTeamLogo`
- `venue`
- `venueCity`
- `apiSource`
- `apiMatchId`
- `lockHoursBefore`

#### `leagues`

Available league catalog:

- `name`
- `shortName`
- `country`
- `logo`
- `apiSource`
- `filterKeywords`
- `active`
- `syncEnabled`

#### `predictions`

User predictions per match:

- `userId`
- `matchId`
- `homeGuess`
- `awayGuess`
- `status`
- `pointsEarned`
- `submittedAt`
- `gradedAt`

#### `trivia_questions`

Shared question bank:

- `question`
- `options`
- `correctAnswer`
- `category`
- `points`
- `active`
- `createdAt`

#### `trivia_answers`

Answer history:

- `userId`
- `questionId`
- `selectedOption`
- `isCorrect`
- `pointsEarned`
- `streakAtAnswer`
- `answeredAt`

#### `groups`

Private groups:

- `groupId`
- `name`
- `code`
- `createdBy`
- `members`
- `leagueId`
- `leagueName`
- `isLeagueExclusive`
- `createdAt`
- `updatedAt`

#### `app_config`

Global configuration:

- `predictions.lockHoursBefore`
- `trivia.dailyQuestionLimit`

### Game flow

1. The user signs up or signs in.
2. The user selects preferred leagues from the profile screen.
3. The fixture screen shows matches filtered by those leagues.
4. The user submits a prediction before the configured lock window.
5. When the match finishes, backend logic calculates prediction points.
6. The user can answer daily trivia questions for extra points.
7. Points affect global, league, and combined rankings.
8. The user can create or join private groups to compete with friends.

### Local setup

#### Requirements

- Flutter SDK compatible with Dart `^3.11.5`.
- Node.js 20 for Firebase Functions.
- Firebase CLI.
- Android Studio or Android SDK for APK builds.
- A configured Firebase project.

#### Steps

1. Clone the repository.

```bash
git clone <repository-url>
cd footrix_app
```

2. Install Flutter dependencies.

```bash
flutter pub get
```

3. Install Cloud Functions dependencies.

```bash
cd functions
npm install
cd ..
```

4. Configure Firebase.

The project expects FlutterFire-generated configuration files:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist` if building for iOS.

5. Run the app.

```bash
flutter run
```

### Build

#### Android debug

```bash
flutter build apk --debug
```

#### Android release

```bash
flutter build apk --release
```

The release APK is generated at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

#### Web

```bash
flutter build web
firebase deploy --only hosting
```

### Firebase deployment

#### Functions

```bash
firebase deploy --only functions
```

#### Firestore rules

```bash
firebase deploy --only firestore:rules
```

#### Firestore indexes

```bash
firebase deploy --only firestore:indexes
```

#### Full Firebase deploy

```bash
firebase deploy
```

### Security

- Predictions are written through Cloud Functions, not directly from the client.
- Firestore rules restrict reads and writes by authenticated user.
- Admin operations require an admin custom claim.
- Point calculation runs on the backend to prevent device-side manipulation.
- Trivia answers are stored per user to prevent repeated questions.

### Performance

Footrix is designed to avoid heavy loads on each app launch:

- Users choose preferred leagues.
- The fixture loads by date range instead of loading the full calendar at once.
- Crest images load from URLs and use visual fallbacks.
- FIFA synchronization runs on the backend and stores a Firestore cache.
- Fixture queries use date and league filters whenever possible.

### Project status

Footrix is under active development. The main implemented areas are authentication, FIFA fixtures, predictions, trivia, groups, rankings, profile, admin panel, notifications, and Firebase deployment.
