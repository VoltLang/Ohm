module lib.readline.c.readline;


public import lib.readline.c.rltypedefs;

// This is very incomplete at the moment.

extern (C):


char* readline(const(char)*);


/* Modifying text. */
void rl_replace_line(const(char)*, int);
int rl_insert_text(const(char)*);
int rl_delete_text(int, int);
int rl_kill_text(int, int);
char *rl_copy_text(int, int);


/* Variables */
extern __gshared rl_hook_func_t rl_startup_hook;