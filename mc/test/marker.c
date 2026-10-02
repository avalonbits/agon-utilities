/* marker: the external program the tests run from the commander. It
   writes /m_<first argument>.txt, holding all its arguments, so a test can
   see it ran and with what. */
#include <stdio.h>

int main(int argc, char **argv)
{
    char name[40];
    FILE *f;
    int i;

    snprintf(name, sizeof name, "/m_%.30s.txt", argc > 1 ? argv[1] : "none");
    f = fopen(name, "w");
    if (f == NULL) {
        return 1;
    }
    for (i = 1; i < argc; i++) {
        fprintf(f, "%s%s", i > 1 ? " " : "", argv[i]);
    }
    fprintf(f, "\n");
    fclose(f);

    return 0;
}
