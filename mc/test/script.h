/* 12AM Commander, scripted for tests: keys and typed lines come from
   /mckeys.txt on the card instead of the keyboard. See script.c. */
#ifndef SCRIPT_H_
#define SCRIPT_H_

#include <stdint.h>

char script_getch(void);
uint8_t script_vkey(void);
uint8_t script_editline(char *buf, uint24_t len, uint8_t clear);
void script_done(const char *left, const char *right, uint8_t which);

#define getch() script_getch()
#define getsysvar_vkeycode() script_vkey()
#define mos_editline(b, n, c) script_editline((b), (n), (c))

#endif
