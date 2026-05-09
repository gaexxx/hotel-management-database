# hotel-management-database

Prima di compilare ed eseguire query.c, è necessario modificare i parametri di connessione al database PostgreSQL presenti all’inizio del file sorgente con quelli relativi alla propria installazione di PostgreSQL

## Quickstart

```
git clone https://github.com/gaexxx/hotel-management-database
cd hotel-management-database
```

## Compile and Run

### Windows
```
gcc query.c -L dependencies\lib -lpq -o query
 .\query.exe 
```

### Linux
```
gcc query.c -I dependencies/include -L dependencies/lib -lpq -o query
 ./query
```

