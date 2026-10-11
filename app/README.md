# Family Funds — App

Flutter app (Android, iOS and web) for the Family Funds API. See the [root README](../README.md) for setup.

The API URL defaults to `http://localhost:3000/api` and can be changed with `--dart-define=API_URL=...`.

```
lib/
  main.dart          app entry, theme and session routing
  theme.dart         green & blue palette (FFColors) and Material 3 theme
  models/            data models
  services/api.dart  HTTP client
  state/             AppState (session, members, accounts, categories, selected month)
  screens/           dashboard, transactions, accounts & cards, financial health, investments & goals, family members
  widgets/           shared widgets and charts
```
