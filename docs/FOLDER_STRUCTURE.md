# SignFix folder structure

The frontend and backend are separated by user role so files are easy to find.

```text
server/
├── customer/            Customer-only controllers, routes and repositories
│   ├── controllers/
│   ├── routes/
│   ├── repositories/
│   └── models/
├── technician/          Technician API workflow
│   ├── controllers/
│   ├── routes/
│   ├── repositories/
│   ├── services/
│   ├── middleware/
│   ├── validation/
│   └── models/
├── admin/               Admin-only management functionality
│   ├── controllers/
│   ├── routes/
│   └── models/
├── routes/              Shared and legacy cross-role endpoint registration
├── controllers/         Shared authentication and cross-role HTTP handling
├── services/            Shared integrations and cross-role workflows
├── validation/          Shared request schemas
├── middleware/          Shared auth, permissions and error handling
├── utils/               Shared helpers
└── config/              Environment configuration

database/
├── schema.mysql.sql     Canonical MySQL models and constraints
├── seed.mysql.sql       Roles, permissions, templates
└── seed.demo.mysql.sql  Development demo data
```

Customer endpoints belong under `server/customer`, technician endpoints under `server/technician`, and admin endpoints under `server/admin`. Authentication, orders, and services remain shared because multiple roles use the same records and business rules.

This project uses MySQL repositories instead of an ORM. The `models` directories document ownership while `database/schema.mysql.sql` remains the single model source of truth, preventing duplicate entities.
