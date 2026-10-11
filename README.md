# FamilyFunds - Finance and Family Activities Management System
<h4 align="center"> 
	🚧  🚀 Under construction...  🚧
</h4>

FamilyFunds is a finance and family activities management system designed to help families control their expenses, save, and plan effectively. The system offers an intuitive interface that enables users to track their finances and also keep track of their family activities.


## Key Features

- :heavy_check_mark: **Expense and Income Tracking:** Users can easily input their expenses and income, categorize them, and keep track of their cash flows — per family member (e.g. you and your spouse), per checking account and per credit card (with installments, bill cycle and limit usage).

- :heavy_check_mark: **Family Budgeting:** The system allows families to set monthly budgets for different expense categories, aiding in controlling overspending.

- :heavy_check_mark: **Financial Health Score:** A 0–100 score built from savings rate, emergency fund, credit card usage, card bill vs. income and budget adherence, with practical recommendations.

- :heavy_check_mark: **Long-Term Financial Planning:** Savings goals and an investment portfolio (allocation, returns, liquidity) with investment insights.

- :heavy_multiplication_x: **Family Activities:** In addition to financial management, the system enables families to plan and organize activities such as trips, special events, and family goals.

## Project Structure

```
backend/   REST API — Node.js 22, Express 5, PostgreSQL (pg), JWT auth, zod validation
app/       Mobile/web app — Flutter (Material 3, green & blue theme), provider, fl_chart
```

## Prerequisites

- Node.js 22+
- PostgreSQL 16+ (or Docker: `docker compose up -d`)
- Flutter 3.38+ (stable)

## Getting Started

### API

```bash
docker compose up -d            # starts PostgreSQL (skip if you already have one)
cd backend
cp .env.example .env
npm install
npm run migrate                 # creates the schema
npm run seed                    # optional: demo family (demo@familyfunds.app / familia123)
npm run dev                     # http://localhost:3000
npm test                        # integration tests (uses the familyfunds_test database)
```

Main endpoints (all under `/api`, authenticated with `Authorization: Bearer <token>`):

| Resource | Endpoints |
|---|---|
| Auth | `POST /auth/register`, `POST /auth/login`, `GET /auth/me` |
| Family members | `GET/POST /members`, `PATCH/DELETE /members/:id` |
| Accounts & credit cards | `GET/POST /accounts`, `GET/PATCH/DELETE /accounts/:id` (balances, limit usage, current bill) |
| Categories | `GET/POST /categories`, `PATCH/DELETE /categories/:id` |
| Transactions | `GET /transactions?month=&type=&member_id=&account_id=&category_id=&search=`, `POST` (supports `installments`), `PATCH`, `DELETE ?scope=all` |
| Budgets | `GET/POST /budgets`, `PATCH/DELETE /budgets/:id` |
| Investments & goals | `/investments`, `/goals` (CRUD) |
| Reports | `GET /reports/summary`, `/reports/cashflow`, `/reports/health`, `/reports/investments`, `/reports/dashboard` |

### App

```bash
cd app
flutter pub get
flutter run -d chrome                                         # web
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api   # Android emulator
flutter test
```

## How to Contribute

If you wish to contribute to FamilyFunds, follow these steps:

1. clone this repository.

2. Create a new branch for your changes:
      `git checkout -b feature/your-new-feature`
   or `git checkout -b bugfix/your-bugfix`
   or `git checkout -b refactor/your-refactor`

4. Make desired changes and commit them using good message commits:
   `git commit -m 'Update {your feature description}'`
   or `git commit -m 'BugFix {your bug description}'`
   or `git commit -m 'Refactor {your refactor description}'`

6. Push to the branch: `git push origin your-branch`.

7. Submit a pull request indicating your changes.

## Technologies Used

- [Flutter](https://flutter.dev/)
- [Node.js](https://nodejs.org/en/)
- [PostgreSQL](https://www.postgresql.org/)
- Integration: Azure DevOps, GitHub Actions
- Hosting: TBD

## License

This project is under the [Personal License](#license)
