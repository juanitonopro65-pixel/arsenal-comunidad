/* sensorlog — visor de registros de sensores (de mentira, para la clase)
 *
 * Lee un fichero .slog y muestra los registros que contiene.
 * Formato:
 *     bytes 0-3    magia "SLOG"
 *     bytes 4-7    cuantos registros hay (entero de 32 bits)
 *     desde el 8   los registros, 16 bytes cada uno
 *
 * Tiene UN defecto puesto a proposito. No te lo decimos todavia.
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define MAX_REGISTROS 100

struct registro {
    char nombre[12];
    int  valor;
};

int main(int argc, char **argv) {
    struct registro tabla[MAX_REGISTROS];   /* capacidad fija: 100 */
    unsigned char cabecera[8];
    unsigned int cuantos;
    FILE *f;

    if (argc < 2) { printf("uso: %s fichero.slog\n", argv[0]); return 1; }

    f = fopen(argv[1], "rb");
    if (!f) { printf("no puedo abrir %s\n", argv[1]); return 1; }

    if (fread(cabecera, 1, 8, f) != 8) { printf("fichero muy corto\n"); return 1; }
    if (memcmp(cabecera, "SLOG", 4) != 0) { printf("no es un fichero SLOG\n"); return 1; }

    cuantos = cabecera[4] | (cabecera[5]<<8) | (cabecera[6]<<16) | (cabecera[7]<<24);
    printf("registros declarados: %u\n", cuantos);

    /* aqui esta el fallo */
    for (unsigned int i = 0; i < cuantos; i++) {
        if (fread(&tabla[i], 1, 16, f) != 16) break;
    }

    printf("leidos. primer registro: %.12s = %d\n", tabla[0].nombre, tabla[0].valor);
    fclose(f);
    return 0;
}
