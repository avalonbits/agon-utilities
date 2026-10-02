/* 12AM Commander, scripted for tests (built with -DMC_SCRIPT).

   /mckeys.txt holds one entry per line:

     ch <n>       getch() returns n, the virtual key code is 0
     vk <n>       the virtual key code is n, getch() returns 0
     line <text>  the next mos_editline() returns text

   getch() takes the next ch or vk entry, mos_editline() the next line
   entry. Past the end, getch() gives F10, so the commander quits rather
   than wait for a key that never comes. The commander quits and restarts
   around each external command, so under hub the position in the script
   is kept in a hub block; without hub, one run reads it from the top.

   script_done() writes /mcstate.txt as the commander quits for good --
   not when it quits for hub to run a command -- with its two
   directories, which one is selected, and how many hub frames are open --
   0 unless the commander left one behind. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <agon/mos.h>
#include <hub/hub.h>

#include "script.h"

#define F10 168

static uint8_t vkey;
static unsigned int here_alone;

/* Where the script has got to: in a hub block if there is hub. */
static unsigned int *position(void)
{
    unsigned int *at = NULL;

    if (hub_present()) {
        at = hub_block("MCKS", sizeof *at);
    }

    return at != NULL ? at : &here_alone;
}

/* The next entry of the given kind ("line" or anything else for a key):
   its text after the kind, in buf. False past the end. */
static int next_entry(int want_line, char *buf, unsigned int len)
{
    static char text[256];
    unsigned int *at = position();
    unsigned int n = 0;
    FILE *f = fopen("/mckeys.txt", "r");
    int found = 0;

    if (f == NULL) {
        return 0;
    }
    while (fgets(text, sizeof text, f) != NULL) {
        char *end = text + strlen(text);
        int is_line;

        while (end > text && (end[-1] == '\n' || end[-1] == '\r')) {
            *--end = '\0';
        }
        if (n++ < *at) {
            continue;
        }
        is_line = strncmp(text, "line ", 5) == 0;
        if (is_line != want_line) {
            continue;   /* the other kind's turn: a script out of step */
        }
        *at = n;
        strncpy(buf, text + (is_line ? 5 : 0), len - 1);
        buf[len - 1] = '\0';
        found = 1;
        break;
    }
    fclose(f);

    return found;
}

char script_getch(void)
{
    char entry[32];

    if (!next_entry(0, entry, sizeof entry)) {
        vkey = F10;

        return 0;
    }
    if (strncmp(entry, "vk ", 3) == 0) {
        vkey = (uint8_t) atoi(entry + 3);

        return 0;
    }
    vkey = 0;

    return (char) atoi(entry + 3);
}

uint8_t script_vkey(void)
{
    return vkey;
}

uint8_t script_editline(char *buf, uint24_t len, uint8_t clear)
{
    (void) clear;
    if (!next_entry(1, buf, len)) {
        buf[0] = '\0';
    }

    return 13;
}

void script_done(const char *left, const char *right, uint8_t which)
{
    FILE *f = fopen("/mcstate.txt", "w");

    if (f != NULL) {
        fprintf(f, "left %s right %s which %d depth %d\n", left, right, which,
                hub_present() ? hub_depth() : 0);
        fclose(f);
    }
}
