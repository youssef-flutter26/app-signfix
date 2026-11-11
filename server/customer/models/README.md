# Customer data model

Customer tables and constraints are defined centrally in `database/schema.mysql.sql`. Customer-specific queries live in `../repositories`; this project deliberately does not duplicate MySQL entities as ORM model classes.
