#ifndef MAINUTIL_H
#define MAINUTIL_H

void trace( char *msg, ... );
void traceNoFormat( char *message );

char * zlabCorePath(  char *file );
char * pluginPathVariable( );
char * pluginPath( char *file );

char * getUserLocalFilespec( char *basename, int bMustExist );

class ZHashTable;
extern ZHashTable options;

extern int copyPixels;


#endif

