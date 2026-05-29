# hotel-management-database

Database project for managing hotels, rooms, customers, reservations, services and payments.

## Requirements

To run the project, make sure you have installed:

- PostgreSQL 15
- GCC compiler
- libpq PostgreSQL client library


## Quickstart

```
git clone https://github.com/gaexxx/hotel-management-database
cd hotel-management-database
```

## Compile and Run

Before compiling and running `query.c`, update the PostgreSQL connection parameters at the beginning of the source file with the values of your local PostgreSQL installation.

```
#define PG_HOST "127.0.0.1"
#define PG_USER "postgres"
#define PG_DB "[DATABASE NAME]"
#define PG_PASS "[PASSWORD]"
#define PG_PORT 5432
```

### Windows

It is necessary to add the following PostgreSQL 15 directories to the system `PATH`:

```text
C:\Program Files\PostgreSQL\15\bin
C:\Program Files\PostgreSQL\15\lib
```

To compile and run:
```
gcc query.c -L dependencies\lib -lpq -o query
 .\query.exe 
```

### Linux
```
gcc query.c -I dependencies/include -L dependencies/lib -lpq -o query
 ./query
```

