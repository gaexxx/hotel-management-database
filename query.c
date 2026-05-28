#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "dependencies/include/libpq-fe.h"

#define PG_HOST "127.0.0.1"
#define PG_USER "postgres"
#define PG_DB "hotel_db"
#define PG_PASS "****"
#define PG_PORT 5432

void checkResults(PGresult *res, const PGconn *conn) {
    if (PQresultStatus(res) != PGRES_TUPLES_OK) {
        printf("Risultati inconsistenti: %s\n", PQerrorMessage(conn));
        PQclear(res);
        PQfinish((PGconn *)conn);
        exit(1);
    }
}

void stampaRisultati(PGresult *res) {
    int tuple = PQntuples(res);
    int campi = PQnfields(res);

    // Stampa intestazioni colonne
    for (int i = 0; i < campi; i++) {
        printf("%-25s", PQfname(res, i));
    }
    printf("\n");

    // Riga separatrice
    for (int i = 0; i < campi; i++) {
        printf("-------------------------");
    }
    printf("\n");

    // Stampa valori
    for (int i = 0; i < tuple; i++) {
        for (int j = 0; j < campi; j++) {
            printf("%-25s", PQgetvalue(res, i, j));
        }
        printf("\n");
    }
}

int main(int argc, char **argv) {
    char conninfo[250];

    sprintf(conninfo, "user=%s password=%s dbname=%s hostaddr=%s port=%d",
            PG_USER, PG_PASS, PG_DB, PG_HOST, PG_PORT);

    PGconn *conn = PQconnectdb(conninfo);

    if (PQstatus(conn) != CONNECTION_OK) {
        printf("Errore di connessione: %s\n", PQerrorMessage(conn));
        PQfinish(conn);
        exit(1);
    } else {
        printf("Connessione avvenuta correttamente\n\n");
    }

    int scelta;
    char continua;

    do {
        const char *query = NULL;
        PGresult *res = NULL;
        
        printf("Scegli la query da eseguire:\n");
        printf("1. Numero di prenotazioni per hotel\n");
        printf("2. Incasso totale per hotel\n");
        printf("3. Numero medio di ospiti per prenotazione per hotel\n");
        printf("4. Hotel con piu' di 3 servizi offerti\n");
        printf("5. Numero di dipendenti per hotel\n");
        printf("6. Camere libere con prezzo massimo scelto dall'utente\n");
        printf("\nInserisci scelta: ");

        scanf("%d", &scelta);

        

        switch (scelta) {
            case 1:
                query =
                    "SELECT h.Nome, COUNT(p.Codice_Prenotazione) AS Totale_Prenotazioni "
                    "FROM Hotel h "
                    "JOIN Prenotazione p ON h.Codice = p.Hotel "
                    "GROUP BY h.Codice, h.Nome "
                    "ORDER BY Totale_Prenotazioni DESC;";
                break;

            case 2:
                query =
                    "SELECT h.Nome, SUM(pa.Importo) AS Incasso_Totale "
                    "FROM Hotel h "
                    "JOIN Prenotazione pr ON h.Codice = pr.Hotel "
                    "JOIN Pagamento pa ON pr.Codice_Prenotazione = pa.Prenotazione "
                    "WHERE pa.Stato = 'Effettuato' "
                    "GROUP BY h.Codice, h.Nome "
                    "ORDER BY Incasso_Totale DESC;";
                break;

            case 3:
                query =
                    "SELECT h.Nome, AVG(pr.N_Ospiti) AS Media_Ospiti "
                    "FROM Hotel h "
                    "JOIN Prenotazione pr ON h.Codice = pr.Hotel "
                    "GROUP BY h.Codice, h.Nome "
                    "ORDER BY Media_Ospiti DESC;";
                break;

            case 4:
                query =
                    "SELECT h.Nome, COUNT(o.Servizio) AS Numero_Servizi "
                    "FROM Hotel h "
                    "JOIN Offerta o ON h.Codice = o.Hotel "
                    "GROUP BY h.Codice, h.Nome "
                    "HAVING COUNT(o.Servizio) > 3 "
                    "ORDER BY Numero_Servizi DESC;";
                break;

            case 5:
                query =
                    "SELECT h.Nome, COUNT(p.CF) AS Numero_Dipendenti "
                    "FROM Hotel h "
                    "JOIN Persona p ON h.Codice = p.Hotel "
                    "WHERE p.Codice_Dipendente IS NOT NULL "
                    "GROUP BY h.Codice, h.Nome "
                    "ORDER BY Numero_Dipendenti DESC;";
                break;

            case 6: {
                char prezzoMassimo[20];

                printf("Inserisci il prezzo massimo per notte: ");
                scanf("%19s", prezzoMassimo);

                query =
                    "SELECT h.Nome AS Hotel, c.Numero, c.Tipo, c.Prezzo "
                    "FROM Hotel h "
                    "JOIN Camera c ON h.Codice = c.Hotel "
                    "WHERE c.Stato = 'Libera' "
                    "AND c.Prezzo <= $1 "
                    "ORDER BY c.Prezzo ASC;";

                const char *paramValues[1];
                paramValues[0] = prezzoMassimo;

                res = PQexecParams(conn, query, 1, NULL, paramValues, NULL, NULL, 0);

                break;
            }

            default:
                printf("Scelta non valida.\n");
                PQfinish(conn);
                return 1;
        }

        // Per le query non parametrizzate
        if (scelta != 6) {
            res = PQexec(conn, query);
        }

        if (res != NULL) {
                checkResults(res, conn);

                printf("\nRisultato query %d:\n\n", scelta);
                stampaRisultati(res);

                PQclear(res);
            }

            printf("\nVuoi eseguire un'altra query? (s/n): ");
            scanf(" %c", &continua);

    } while (continua == 's' || continua == 'S');

    PQfinish(conn);

    printf("\nProgramma terminato.\n");

    return 0;
}