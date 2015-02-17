// @ZBS {
//		+DESCRIPTION {
//			Main file for Template Project
//		}
//		*MODULE_DEPENDS zmousemsg_glfw.cpp zuibutton.cpp zuipanel.cpp zuipluginview.cpp zuitext.cpp zuiline.cpp zuivaredit.cpp zuifpsgraph.cpp 
//			These are the dynamically bound gui objects that are used
//			by the project.  They are all components of module gui
//		*REQUIRED_FILES wingl.h wintiny.h
//		*SDK_DEPENDS glfw-2.7.2
//		*INTERFACE gui
//		+BUGS {
//			BUGS FOR the entire zlab project:
//			* In zlabbuild on mac (maybe pc too) I select a console app, save, come back it thinks it is GUI
//			* Need a way for a console to pop up IN A DIFFERENT thread for information like loading, etc. in a cross platform way
//		}
// }

//#define MSVC_MEMLEAK_DEBUG
#ifdef MSVC_MEMLEAK_DEBUG
// Microsoft Visual Studio memory leak checking.
// If this is enabled, you can call, e.g.:
//     _CrtSetBreakAlloc (663);
// to break on a particular memory allocation.
//
// This is supposed to give you a dump that tells you which source file leaked, but apparently this part
// does not work when using new/delete, only for malloc/free.
#ifndef NDEBUG
// Memory leak detection
// http://msdn.microsoft.com/en-us/library/e5ewb1h3.aspx
#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
#endif
#endif

//#define MALLOCDEBUG
#ifdef MALLOCDEBUG
	// If you want to do really robust heap checking, enable
	// #define MALLOCDEBUG here and it will replace the stdlib
	// heap routines with the hard-core replacements. See mallocdebug2.cpp
	// You must put "/force:multiple" into the linker options
	#define _WIN32_WINNT 0x0400
	extern int heapCheck( int assertOnFail=1 );
	#include "mallocdebug_linear.cpp"
	//#include "mallocdebug_heap.cpp"
	#include "zstacktrace.cpp"
	#pragma comment(linker,"/debugtype:coff")
#else
	int heapCheck( int ) {
		return 1;
	}
#endif

// OPERATING SYSTEM specific includes:
#ifdef WIN32
#include "windows.h"
#include "direct.h"	// mkdir
#else
#include "sys/stat.h"
#include "unistd.h"
#ifdef __APPLE__
#include "sys/utsname.h"
#endif
#endif

// SDK includes:
#ifdef __APPLE__
#include "OpenGL/gl.h"
#include "OpenGL/glu.h"
#else
#include "GL/gl.h"
#include "GL/glu.h"
#endif
#include "GL/glfw.h"
#ifdef ZMSG_MULTITHREAD
// @ZBSIF extraDefines( 'ZMSG_MULTITHREAD' )
// the above is for the perl-parsing of files for dependencies; we don't
// want the dependency builder to see these includes if ZMSG_MULTITHREAD is not
// defined.
	#include "pthread.h"
	#include "pmutex.h"
// @ZBSENDIF
#endif

// STDLIB includes:
#include "stdio.h"
#include "stdlib.h"
#include "assert.h"
#include "string.h"
#include "ctype.h"
#include "math.h"
#include "float.h"
#include "stdarg.h"
// MODULE includes:
#include "mainutil.h"
// ZBSLIB includes:
#include "zcmdparse.h" 
#include "zhashtable.h"
#include "zmsg.h"
#include "zvars.h"
#include "ztime.h"
#include "zmousemsg.h"
#include "zregexp.h"
#include "zconfig.h"
#include "zglfont.h"
#include "ztmpstr.h"
#include "zplugin.h"
#include "zmathtools.h"
#include "zglfwtools.h"
#include "zviewpoint.h"
#include "zui.h"
#include "zwildcard.h"
#include "zprof.h"
#include "zprofglgui.h"
#include "zconsole.h"
#include "zgltools.h"
#include "zfilespec.h"
#include "zmsgzocket.h"
#include "zfilespec.h"

// STOPFLOW timing
#include "sfmod.h"

// EXE
char exeName[255] = {0,};

// PLUGIN
char curPlugin[64] = {0,};
char newPlugin[64] = {0,};
char *startupPlugin = 0;

// OPTIONS
char statusLineText[256];
ZHashTable options;
int optionsLoaded = 0;
	// this can safely be read before main()

ZMSG_HANDLER( SetVar ) {
	ZVarPtr *var = zVarsLookup( zmsgS(key) );
	if( var ) {
		double val = var->getDouble();

		if( zmsgHas(val) ) {
			val = zmsgD(val);
		}
		else if( zmsgHas(toggle) ) {
			val = !val;
		}
		else if( zmsgHas(delta) ) {
			val += zmsgD(delta);
		}
		else if( zmsgHas(scale) ) {
			val *= zmsgD(scale);
		}
		var->setFromDouble( val );

		if( zmsgI(reset) ) {
			var->resetDefault();
		}
	}
}

// User local path determination
//===============================================================================
char * getUserLocalAppFolder() {
	// Return the path to a folder that is writeable and preferably unique by user.
	static char filepath[512];

	if( !options.getI( "ignoreUserLocal" ) ) {
		char *appdata = 0;
		char slash[3];
		#ifdef WIN32
			strcpy( slash, "\\" );
			appdata = getenv( "APPDATA" );
				// Could use API like SHGetFolderName.
		#else
			strcpy( slash, "/." );
			appdata = getenv( "HOME" );
		#endif
		if( appdata && *appdata ) {
			strncpy( filepath, appdata, 255 );
			filepath[255] = 0;
			if( curPlugin[0] ) {
				strcat( filepath, ZTmpStr( "%s%s", slash, curPlugin ).s );
				return filepath;
			}
			else if( startupPlugin ) {
				strcat( filepath, ZTmpStr( "%s%s", slash, startupPlugin ).s );
				return filepath;
			}
		}
	}

	// If we get here, no specific path was found.  Use current.
	filepath[0] = '.';
	filepath[1] = 0;
	return filepath;
}

char * getUserLocalFilespec( char *basename, int bMustExist ) {
	// bMustExist means that the file *must* already exist; the userLocal
	// folder will be checked first, and then the current folder, and NULL
	// will be returned if the file does not exist.

	static char userLocalFilename[255];
	char *appdata = getUserLocalAppFolder();
	if( appdata && *appdata ) {
		if( !zWildcardFileExists( appdata ) ) {
			#ifdef WIN32
				mkdir( appdata );
			#else
				mkdir( appdata, 0777 );
			#endif
		}
		ZFileSpec fs( ZTmpStr( "%s/%s", getUserLocalAppFolder(), basename ) );
			// this is to make use of the standardize-slash functionality
		strcpy( userLocalFilename, fs.get() );
		if( zWildcardFileExists( userLocalFilename ) || !bMustExist ) {
			return userLocalFilename;
		}
	}
	// If we get here, try the local execution folder for a path
	strcpy( userLocalFilename, basename );
	if( zWildcardFileExists( userLocalFilename ) || !bMustExist ) {
		return userLocalFilename;
	}
	assert( bMustExist );
	return 0;
}

// Trace	
//===============================================================================
#ifdef ZMSG_MULTITHREAD
static PMutex traceMutex;
#endif
static FILE *traceFile=0;


void _trace( char *message ) {
	#ifdef TRACE_TIMESTAMPED
		ZTmpStr timestamp( "[%s] ", zTimeGetLocalTimeStringNumeric( 1 ) );
		if( traceFile ) {
			fputs( timestamp, traceFile );
		}
		fputs( timestamp, stdout );
	#endif
	if( traceFile ) {
		fputs( message, traceFile );
		fflush( traceFile );
	}
	fputs( message, stdout );
	fflush( stdout );
}

void traceNoFormat( char *message ) {
	#ifdef ZMSG_MULTITHREAD
		traceMutex.lock();
	#endif
	_trace(message);
	#ifdef ZMSG_MULTITHREAD
		traceMutex.unlock();
	#endif
}

void trace( char *fmt, ... ) {
	#ifdef ZMSG_MULTITHREAD
			// if potentially many threads will call trace, it is
			// best to serialize execution of this fn lest output
			// results be scrambled
		traceMutex.lock();
	#endif
	if( !traceFile ) {
		traceFile = fopen( getUserLocalFilespec( "trace.txt", 0 ), "wt" );
		static int printFailure = 1;
		if( !traceFile && printFailure ) {
			printf( "failed to open trace.txt!\n" );
			printFailure = 0;
		}
		// assert( traceFile );
	}

	assert(fmt);

	static char buffer[2048];
	va_list argptr;
	va_start( argptr, fmt );

	vsprintf(buffer,fmt,argptr);
	buffer[sizeof(buffer)-1]=0;
  	va_end(argptr);

	_trace( buffer );

	#ifdef ZMSG_MULTITHREAD
		traceMutex.unlock();
	#endif
}

//===============================================================================

char zlabCoreFolder[256];
char optionsFolder[256];
void findFolders( char *argv0 ) {
	
	// Change dir (and drive if windows) to the location of the executable.
	// Then find the main.zui or zlabcore folder.  Write the zlabcore folder
	// location into zlabCoreFolder.

	// @TODO: This code represents the worst-case use case for zfilespec and wildcard
	// so use this as a template for refactoring that code to make it easier

	zlabCoreFolder[0] = 0;
	optionsFolder[0] = 0;

	// SEARCH up the heirarchy for core/options.cfg 
	ZFileSpec exeDir( argv0 );

	#ifdef WIN32
	// Can't count on argv[0] for windows (don't remember why, maybe exe on other drive?)
	char exeName[256];
	GetModuleFileName( NULL, exeName, 256 );
	exeDir.set( exeName );
	#endif
	zFileSpecChdir( zFileSpecMake( FS_DRIVE, exeDir.getDrive(), FS_DIR, exeDir.getDir(), FS_END ) );

	ZFileSpec searchPath;
	searchPath.set( "." );
	int foundOptions = 0;
	int foundCore = 0;
	while( !foundOptions ) {
		char *options  = zFileSpecMake( FS_DIR, searchPath.getDir(), FS_DIR, "core", FS_FILE, "options.cfg", FS_END );
		if( zWildcardFileExists( options ) ) {
			foundOptions = 1;
			searchPath.set( zFileSpecMake( FS_DIR, searchPath.get(), FS_DIR, "core", FS_FILE, ".", FS_END ) );
			zFileSpecChdir( searchPath.getDir() );
			getcwd( optionsFolder, 256 );
				// get a nice absolute path into options folder
		}
		else {
			// SEARCH parent folder
			searchPath.set( zFileSpecMake( FS_DIR, "..", FS_DIR, searchPath.get(), FS_FILE, ".", FS_END ) );
			if( !zWildcardFileExists( searchPath.get() ) ) {
				assert( !"ERROR: options.cfg not found in findFolders() search!"  );
				break;
					// we're beyond root - didn't find anything.
			}
		}
	}

	// We've found options.cfg and have chdir'd to folder above it.
	// main.zui is either in this folder or it is in ../../zlabcore
	if( zWildcardFileExists( "main.zui" ) ) {
		strcpy( zlabCoreFolder, optionsFolder );
	}
	else if( zWildcardFileExists( "../../zlabcore/main.zui" ) ) {
		sprintf( zlabCoreFolder, "%s/../../zlabcore/", optionsFolder );
	}
	else {
		assert( !"ERROR: main.zio not found in findFolders() search!"  );
	}
	
	zFileSpecChdir( ".." );
		// set current folder to parent of "core"
}

//===============================================================================

char * zlabCorePath(  char *file ) {
	static char path[256];
	strcpy( path, zFileSpecMake( FS_DIR, zlabCoreFolder, FS_FILE, file, FS_END ) );
	return path;
}

//===============================================================================

char * pluginPathVariable( ) {
// Get the variable that is used to store the plugin path.
	static char variable[256];
	strcpy (variable, "pluginPath_");
	strcat (variable, curPlugin);
	return variable;
}

//===============================================================================

char * pluginPath( char *file ) {
	static char path[256];
	char *currentPlugPath = options.getS( pluginPathVariable( ), 0 );
	assert( currentPlugPath && "Current plugin path is not set!" );

	strcpy( path, zFileSpecMake( FS_DIR, currentPlugPath, FS_FILE, file, FS_END ) );
	return path;
}

//===============================================================================


//===============================================================================

/*
// initCwd - set drive & folder to location of zlab support files
//===============================================================================

void initCwd( char* argv0, char* mainZUIFile ) {
	// SEARCH up the dir tree for the right directory if we aren't there.
	// This is particularlly important on Mac where the app lives
	// in a nested folder under zlab.  Start the search in the location
	// discovered from the command line...
	ZFileSpec cwdSpec;
	cwdSpec.getCwd();
	trace( "At startup, cwd = %s\n", cwdSpec.get() );

	ZFileSpec fs( argv0 );
		// argv0 often contains full path to executable

#ifdef WIN32
	// Don't count on argv[0]; do we need this for other OS?
	GetModuleFileName( NULL, exeName, 255 );
	if( exeName[0] ) {
		trace( "Retrieved Win32 module filename: %s\n", exeName );
		fs.set( exeName );
		int zlabDrive = toupper( fs.getDrive()[0] ) - 'A' + 1;
		_chdrive( zlabDrive );
	}
#endif

	
	char folder[255]; folder[1] = 'x';
	zFileSpecChdir( fs.getDir() );
	while( !zWildcardFileExists( mainZUIFile ) && folder[1] ) {
		cwdSpec.getCwd();
		trace( "Looking for support files in %s...\n", cwdSpec.get() );
		strcpy( folder, cwdSpec.getDir() );
		if( zFileSpecChdir( ".." ) ) {
			break;
		}
	}





	cwdSpec.getCwd();
	trace( "Looking for support files in %s...\n", cwdSpec.get() );
	if( !zWildcardFileExists( mainZUIFile ) ) {
		trace( "Main zui file '%s' not found.  Exiting.\n", mainZUIFile );
		exit( 1 );
	}
	trace( "Main zui file found: '%s/%s'\n", cwdSpec.get(), mainZUIFile );
}
*/

// Plugin
//===============================================================================

ZMSG_HANDLER( PluginChange ) {
	char *which = zmsgS(which);
	if( !*which || !strcmp( which, curPlugin ) ) {
		// Do nothing if the requested plugin is blank or already running
		return;
	}
	strcpy( newPlugin, which );
}

void pluginMaintain() {
	if( newPlugin[0] ) {
		// SEARCH for new plugin
		ZHashTable *pluginHash = zPluginGetPropertyTable( newPlugin );
		if( !pluginHash ) return;

		// CLEAR out the var list
		zMsgQueue( "type=ZUIVarEdit_Clear toZUI=pluginVars" );
		zMsgDispatch( zTime );

		// SHUTDOWN old plugin
		typedef void (*ShutdownFnPtr)();
		ShutdownFnPtr shutdown = (ShutdownFnPtr)zPluginGetP( curPlugin, "shutdown" );
		if( shutdown ) {
			(*shutdown)();
			ZUI::zuiGarbageCollect();
		}

		// CLEAR any UI that was added to the pluginExtraZUI
		ZUI *o = ZUI::zuiFindByName( "pluginExtraZUI" );
		if( o ) {
			o->killChildren();
		}

		// NOTIFY the plugin view panel that it should be rendering the new plugin
		zMsgQueue( "type=ZUISet key=selected val=0 toZUIGroup=pluginChoiceButtons" );
		zMsgQueue( "type=ZUIVarEdit_Add toZUI=pluginVars regexp='^%c%s_.*'", toupper(newPlugin[0]), &newPlugin[1] );
		zMsgQueue( "type=ZUIVarEdit_Sort which=order toZUI=pluginVars" );
		zMsgQueue( "type=PluginChanged" );
		zMsgQueue( "type=PluginLoadZUI" );

		// NOTIFY the plugin view panel that it should be rendering the new plugin
		ZUI *pluginPlanel = ZUI::zuiFindByName("pluginPanel");
		if( pluginPlanel ) {
			pluginPlanel->putS( "plugin", newPlugin );
		}

		strcpy( curPlugin, newPlugin );
		newPlugin[0] = 0;

		// STARTUP new plugin
		zviewpointReset();
		typedef void (*StartupFnPtr)();
		StartupFnPtr startup = (StartupFnPtr)zPluginGetP( curPlugin, "startup" );
		if( startup ) {
			(*startup)();
		}

	}
}

// Dispatch
//===============================================================================

void defaultDispatch( ZMsg *msg ) {
#if !defined(STOPFLOW)
	ZMsgZocket::dispatch( msg );
#endif
	if( ! zMsgIsUsed() ) {
		ZUI::zuiDispatchTree( msg );
	}
}

// Render
//===============================================================================

int line;
int copyPixels = -1;

void render() {
#if defined(STOPFLOW)
	if( !useDirtyRects ) {
		glClearColor( 0.0, 0.0, 0.0, 0.0 );
		glClearDepth( 1.0 );
		glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
	}
#endif

	glMatrixMode( GL_TEXTURE );
	glLoadIdentity();
	glMatrixMode( GL_PROJECTION );
	glLoadIdentity();
	glMatrixMode( GL_MODELVIEW );
	glLoadIdentity();
	glTranslatef( -1.0, -1.0, 0.0 );
	glScalef( 2.0, 2.0, 1.0 );
	glDisable( GL_DEPTH_TEST );

	SFTIME_START (PerfTime_ID_Zlab_render_copy, PerfTime_ID_Zlab_render);

	// If we are using dirty rects, I have seen OSX 10.6 behave differently
	// than other OS.  In our tests, other OS appear to start with a back 
	// buffer that contains the contents of the previous draw.  But in
	// my tests of 10.6 on an intel imac24, the behavior looks that this
	// is not true, so for now look for this case, and copy the pixels.

	// (See notes above) it seems this is some gl driver feature that we should
	// be querying instead.  I am also seeing odd behavior in windows xp on a 
	// intel macbook (black).  So for now, we are defaulting to copyPixels on.
	if( copyPixels == -1 ) {
		if( useDirtyRects ) {
			if( options.has( "copyPixels" ) ) {
				copyPixels = options.getI( "copyPixels" );
			}
			else {
				copyPixels = useDirtyRects;
					// default on for now when using dirtyRects, see above
				
				// the below is the logic for when we set copyPixels when we find we
				// are running on osx 10.6
				static int wroteAppleInfo=0;
				#ifdef __APPLE__
				utsname name;
				if( !wroteAppleInfo && !uname( &name ) ) {
					trace( "OSX info:\n  version = %s\n  release = %s\n  machine = %s\n\n",
						name.version, name.release, name.machine );
					wroteAppleInfo = 1;
				}
				#endif
			}
			trace( "copyPixels has been set to %d\n", copyPixels );
		}
	}
	if( copyPixels && copyPixels != -1 ) {

		float viewport[4];
		glGetFloatv( GL_VIEWPORT, viewport );

		glReadBuffer( GL_FRONT );
		glDrawBuffer( GL_BACK );
		glCopyPixels( (int)viewport[0], (int)viewport[1], (int)viewport[2], (int)viewport[3], GL_COLOR );
		//glCopyPixels( 0, 0, 10000, 10000, GL_COLOR );
	}

	SFTIME_END   (PerfTime_ID_Zlab_render_copy);
	SFTIME_START (PerfTime_ID_Zlab_render_tree, PerfTime_ID_Zlab_render);
	ZUI::zuiRenderTree();
	SFTIME_END (PerfTime_ID_Zlab_render_tree);
}

// Window 
//===============================================================================

int bFullScreen = 0;

void writeWindowPos() {
	// No writes in fullscreen mode
	if( bFullScreen ) {
		return;
	}

	// AVOID writes in popup mode
	if( zglfwWinGetWindowStyle() == zglfwWinStyleBorderless ) {
		return;
	}

	if( zTimeFrameCount == 0 ) {
		// Avoid writes on load
		return;
	}

	int x, y, w, h;
	glfwGetWindowGeom( &x, &y, &w, &h );
	if( x < -5000 || x > 5000 || y < -5000 || y > 5000 ) {
		// Sometimes we get back bogus values from glfw.
		return;
	}

	FILE *file = fopen( getUserLocalFilespec( "windowpos.txt", 0 ), "wt" );
	if( file ) {
		fprintf( file, "%d\n", x );
		fprintf( file, "%d\n", y );
		fprintf( file, "%d\n", w );
		fprintf( file, "%d\n", h );
		fclose( file );
	}
}

void readWindowPos() {
	if( !bFullScreen ) {
		char *local = getUserLocalFilespec( "windowpos.txt", 1 );
		FILE *file = fopen( local ? local : "windowpos.txt", "rt" );
		if( file ) {
			int x, y, w, h;
			fscanf( file, "%d\n", &x );
			fscanf( file, "%d\n", &y );
			fscanf( file, "%d\n", &w );
			fscanf( file, "%d\n", &h );
			
			glfwSetWindowSize( w, h );
			glfwSetWindowPos( x, y );

			int _w, _h;
			glfwGetWindowSize( &_w, &_h );

			fclose( file );
		}
	}
}

void writeConsolePos() {
	int x, y, w, h;
	zconsoleGetPosition( x, y, w, h );
	FILE *file = fopen( getUserLocalFilespec( "consolepos.txt", 0 ), "wt" );
	if( file ) {
		fprintf( file, "%d\n", x );
		fprintf( file, "%d\n", y );
		fprintf( file, "%d\n", w );
		fprintf( file, "%d\n", h );
		fclose( file );
	}
}

void readConsolePos() {
	char *local = getUserLocalFilespec( "consolepos.txt", 1 );
	FILE *file = fopen( local ? local : "consolepos.txt", "rt" );
	if( file ) {
		int x, y, w, h;
		fscanf( file, "%d\n", &x );
		fscanf( file, "%d\n", &y );
		fscanf( file, "%d\n", &w );
		fscanf( file, "%d\n", &h );

		zconsolePositionAt( x, y, w, h );

		fclose( file );
	}
}

ZMSG_HANDLER( WindowPos_Load ) {
	if( !bFullScreen ) {
		readWindowPos();
	}
}

ZMSG_HANDLER( ResetWindow ) {
	if( !bFullScreen ) {
		glfwSetWindowSize( 640, 480 );
		glfwSetWindowPos( 100, 100 );
			// 100,100 instead of 0,0 to avoid issues on OS that have permanent menubar at top
			// which can obscure title bar of zlab making hard to move.
	}
}

void moveHandler( int x, int y ) {
	if( !bFullScreen ) {
		writeWindowPos();
	}
}


// Main Loop
//===============================================================================

void mainLoop() {
	SFTIME_START (PerfTime_ID_Zlab_main_mouse, PerfTime_ID_Zlab_main);
	zMouseMsgUpdate();
	SFTIME_END (PerfTime_ID_Zlab_main_mouse);

	zTimeTick();
	
	statusLineText[0] = 0;
	strcat( statusLineText, ZTmpStr( "%3.1f", zTimeAvgFPS ) );

	#ifdef WIN32
//	SwitchToThread();
	#endif

#if !defined(STOPFLOW)
	ZMsgZocket::readList();
#endif
	
	pluginMaintain();
		// The switching between plugins needs to be synchronous

	SFTIME_START (PerfTime_ID_Zlab_main_dispatch, PerfTime_ID_Zlab_main);
	zMsgDispatch( zTime );
	SFTIME_END (PerfTime_ID_Zlab_main_dispatch);

	SFTIME_START (PerfTime_ID_Zlab_main_update, PerfTime_ID_Zlab_main);
	ZUI::zuiUpdate( zTime );
	SFTIME_END (PerfTime_ID_Zlab_main_update);
}

ZMSG_HANDLER( QuitApp ) {
	glfwCloseWindow();
}

void loadOptionsConfigFile() {
	ZRegExp keyRegExp( "^key_([a-zA-Z0-9]+)" );

	zConfigLoadFile( zFileSpecMake( FS_DIR, optionsFolder, FS_FILE, "default.cfg", FS_END ), options );
	zConfigLoadFile( zFileSpecMake( FS_DIR, optionsFolder, FS_FILE, "options.cfg", FS_END ), options );
	#ifdef _DEV
	zConfigLoadFile( zFileSpecMake( FS_DIR, optionsFolder, FS_FILE, "dev.cfg", FS_END ), options );
	#endif
	zConfigLoadFile( zFileSpecMake( FS_DIR, optionsFolder, FS_FILE, "local.cfg", FS_END ), options );
	optionsLoaded = 1;
		// code that potentially runs before main() should use this to know whether
		// extern'd options hashtable has been loaded.

	for( int i=0; i<options.size(); i++ ) {
		char *k = options.getKey(i);
		char *v = options.getValS(i);
		if( k && v ) {
			ZVarPtr *varPtr = zVarsLookup( k );
			if( varPtr ) {
				double val = strtod( v, NULL );
				varPtr->setFromDouble( val );
			}
		}
		if( k && keyRegExp.test( k ) ) {
			ZUI::zuiBindKey( keyRegExp.get(1), v );
		}
	}
}

int stringCompare(const void *a, const void *b) {
	// This just calls strcmp because undergccI had a problem linking to __cdecl
	// so I just put this stub in
	return strcmp( (const char*)a, (const char*)b );
}

ZMSG_HANDLER( BuildPluginChoiceButton ) {
	// BUILD up the list of plugin buttons that are used in the control panel
	ZUI *panel = ZUI::zuiFindByName( "pluginButtonPanel" );
	if( !panel ) return;

	char sortedPluginNames[128][32];
	int sortedPluginCount = 0;
	assert( sortedPluginCount < 128 );
	int last = -1;
	ZHashTable *plugin = 0;
	while( zPluginEnum( last, plugin ) ) {
		strcpy( sortedPluginNames[sortedPluginCount], plugin->getS("name") );
		sortedPluginCount++;
	}

	if( sortedPluginCount > 20 ) {
		panel->putI( "table_cols", 3 );
	}
	else {
		panel->putI( "table_cols", 2 );
	}

	int keyMajor = 5;
	int keyMinor = 1;

	qsort( sortedPluginNames, sortedPluginCount, 32, stringCompare );
	for( int i=0; i<sortedPluginCount; i++ ) {
		#ifndef DEV
		if( !strcmp(sortedPluginNames[i],"null") ) {
			continue;
		}
		#endif
		ZUI *button = ZUI::factory( 0, "ZUIButton" );
		button->putS( "text", sortedPluginNames[i] );
		button->putS( "keyBinding", ZTmpStr("%d.%d",keyMajor,keyMinor) );
		keyMinor++;
		if( keyMinor > 9 ) {
			keyMinor = 0;
			keyMajor++;
		}
		button->putS( "sendMsg", ZTmpStr("type=PluginChange which=%s",sortedPluginNames[i]) );
		button->attachTo( panel );
	}
}

ZMSG_HANDLER( ToggleConsole ) {
	if( zconsoleIsVisible() ) {
		zconsoleHide();
	}
	else {
		zconsoleShow();
		zconsolePositionAt( 0, 0, 800, 1000 );
//		zconsolePositionAlongsideCurrent();
	}
}


int zprofDumpFlag = 0;
int zprofToggleFlag = 0;
ZMSG_HANDLER( ZProfDump ) {
	zprofDumpFlag = 1;
}
ZMSG_HANDLER( ZProfToggle ) {
	zprofToggleFlag = 1;
}
ZMSG_HANDLER( ZProfResetAvg ) {
	zprofReset( 1 );
}

#ifdef ZMSG_MULTITHREAD
pthread_mutex_t msgQueueMutex;
void msgQueueMutexFunc( int lock ) {
	int err;
	if( lock ) {
		err = pthread_mutex_lock( &msgQueueMutex );
	}
	else {
		err = pthread_mutex_unlock( &msgQueueMutex );
	}
	assert( !err );
}
#endif

#ifdef WIN32
int CALLBACK WinMain( HINSTANCE _hInstance, HINSTANCE hPrevInstance, LPSTR nCmdParam, int nCmdShow )
#else
int main( int argc, char **argv )
#endif
{

	// Configuration file and startup plugin are handled first such that we
	// can determine the path to a per-user writeable folder for this application
	// that various config & diagnostic files can be written to.  (tfb)

	// PARSE cmdline, LOAD Configuration file, SETUP folders
	ZHashTable cmdlineOptions;
	char *exe="";
	#ifdef WIN32
		char *cmdline = GetCommandLineA();
		zCmdParseCommandLine( cmdline, cmdlineOptions );
	#else
		zCmdParseCommandLine( argc, argv, cmdlineOptions );
		exe = argv[0];
	#endif
	findFolders( exe );
		// note: on windows this arg is not used
	loadOptionsConfigFile();
		// relies on findFolders having been called
	options.copyFrom( cmdlineOptions );
		// command-line options should override those specified in cfg files
	
	options.dump(1);

	// STARTUP Plugin
	startupPlugin = options.getS( "startupPlugin" );
	if( startupPlugin && startupPlugin[0] == '_' ) {
		startupPlugin++;
	}
	if( !startupPlugin || !*startupPlugin ) {
		int last = -1;
		ZHashTable *plugin = 0;
		while( zPluginEnum( last, plugin ) ) {
			startupPlugin = plugin->getS("name");
			break;
		}
	}

	// Do math copro setup for windows debugging
	#ifdef WIN32
		_clearfp();
		#ifdef _DEBUG
			_controlfp( ~(_EM_INVALID|_EM_OVERFLOW|_EM_ZERODIVIDE), _MCW_EM );
				// These calls set the floating point unit to exception on errors
		#endif
	#endif

    // CREATE console
	#if !defined(KIN_PRO) && !defined(KIN_DEMO) && !defined(STOPFLOW)
		zconsoleCreate();
		zconsolePositionAt( 0, 0, 800, 1000 );
		trace( "Console created...\n" );
	#endif
	trace( "Command Line Options:\n%s\n", cmdlineOptions.dumpToString() );
	trace( "zlabCore folder is %s\n", zlabCoreFolder );
	trace( "optionsFolder is %s\n", optionsFolder );
	trace( "Entered main...\n" );
	trace( "Configuration options have been loaded.\n" );

    // SETUP mallocdebug if desired.
	#ifdef MALLOCDEBUG
		extern void zStackTraceBuildSymbolTable();
		zStackTraceBuildSymbolTable();
	#endif

    
	#ifndef _DEBUG
	try {
	#endif

	#ifdef ZMSG_MULTITHREAD
		// SETUP the mutex for the msgQueue
		int err = pthread_mutex_init( &msgQueueMutex, 0 );
		assert( !err );
		zMsgMutex = msgQueueMutexFunc;
	#endif

	// SETUP the font search paths
	char winPath[256]={"."};
	#ifdef WIN32
		GetWindowsDirectory( winPath, 256 );
	#endif
	zglFontSetTTFSearchPaths( ZTmpStr("./;./core/;../zlabcore/;../;../..;art/fonts/;%s/fonts/",winPath) );

	// SETUP glfw
	trace( "About to call glfwInit() ...\n" );
	glfwInit();
	trace( "glfwInit() done.\n" );

	// CREATE window
	int width  = 640;
	int height = 480;
	bFullScreen = options.getI( "fullscreen" );
	GLFWvidmode desktopMode;
	glfwGetDesktopMode( &desktopMode );
	if( bFullScreen ) {
		width  = desktopMode.Width;
		height = desktopMode.Height;
	}
	glfwOpenWindowHint( GLFW_ACCUM_RED_BITS, 8 );
	glfwOpenWindowHint( GLFW_ACCUM_BLUE_BITS, 8 );
	glfwOpenWindowHint( GLFW_ACCUM_GREEN_BITS, 8 );
	glfwOpenWindowHint( GLFW_ACCUM_ALPHA_BITS, 8 );
	#if defined(KIN_PRO) || defined(KIN_DEMO) || defined(KIN_DEV)
		glfwOpenWindowHint( GLFW_FSAA_SAMPLES, 4 );
		// I think this is a reasonable default for _everyone_, but don't want to surprise anyone, like SG.
		// Note that this does not _enable_ antialiasing, but these sample buffers are required if you will 
		// use AA.
	#endif
	trace( "Calling glfowOpenWindow() with width=%d, height=%d, fullscreen=%d ...\n", width, height, bFullScreen );
	int ret = glfwOpenWindow( width, height, 8, 8, 8, 8, 16, 8, bFullScreen ? GLFW_FULLSCREEN : GLFW_WINDOW );
	trace( "glfwOpenWindow() returned %s (%d)\n", ret ? "success!" : "FAILED!", ret );
	assert( ret && "Failed to open 3D window" );
	glClear( GL_COLOR_BUFFER_BIT );

	#ifdef TITLE
		#ifdef _DEBUG
		glfwSetWindowTitle( ZTmpStr( "%s%s", TITLE, "(debug)" ) );
		#else
		glfwSetWindowTitle( TITLE );
		#endif
	#else
		#ifdef _DEBUG
		glfwSetWindowTitle( "Zlab (debug)" );
		#else
		glfwSetWindowTitle( "Zlab (release)" );
		#endif

	#endif
	trace( "Reading window position...\n" );
	readWindowPos();
	readConsolePos();

	// SETUP window callbacks
	trace( "Setting up glfw callbacks...\n" );
	glfwSetWindowRefreshCallback( ZUI::dirtyAll ); 
	glfwEnable( GLFW_KEY_REPEAT );
	glfwSetCharCallback( zglfwCharHandler );
	glfwSetKeyCallback( zglfwKeyHandler );
	glfwSetMouseWheelCallback( zglfwMouseWheelHandler );
	if( bFullScreen ) {
		glfwEnable( GLFW_MOUSE_CURSOR );
			// in fullscreen this defaults to off, so turn it on.
	}

	zMsgQueue( "type=WindowPos_Load" );

	ZUI::zuiBindKey( "escape", "type=QuitApp" );
	ZUI::zuiBindKey( "alt_x", "type=QuitApp" );

	#if !( (defined KIN_DEMO) || (defined KIN_PRO) )
		ZUI::zuiBindKey( " ", "type=ZUISet key=hidden toggle=1 toZUI=controlPanel; type=MouseShow" );
	#endif
	ZUI::zuiBindKey( "alt_z", "type=ZUISet key=hidden toggle=1 toZUI=fpsGraph" );
	ZUI::zuiBindKey( "alt_w", "type=ResetWindow" );
	ZUI::zuiBindKey( "f11", "type=ResetWindow" );
	ZUI::zuiBindKey( "f1", "type=ToggleConsole" );
	ZUI::zuiBindKey( "f2", "type=ZProfToggle" );
	ZUI::zuiBindKey( "f3", "type=ZProfResetAvg" );
	ZUI::zuiBindKey( "f4", "type=ZProfDump" );

	// SETUP the default dispatcher
	zMsgSetHandler( "default", defaultDispatch );
	zMsgQueue( "type=WindowPos_Load" );

	// SETUP UI
	zFileSpecChdir( ZTmpStr ( "%s/..", optionsFolder ) );
		// at some point between findFolders and here, on OSX you will find the the working folder has
		// been changed behind your back to the Resources folder inside of the bundle.  This probably
		// happens in response to some cocoa/carbon event that is generated inside of the glfw window
		// code above.  But various code expects the working folder to be at the root of the plugin
		// so we chdir again here.
	char buf[256];
	getcwd( buf, 256 );
	
	char *mainzui = zlabCorePath( "main.zui" );
	trace( "From folder %s, will check to see if %s exists...\n", buf, mainzui );
	int success = zWildcardFileExists( mainzui );
	trace( success ? (char*)"Yes.\n" : (char*)"No!\n" );
	assert( zWildcardFileExists( zlabCorePath( "main.zui" ) ) );
	trace( "Loading fonts, processing ZUI file '%s'...\n", zlabCorePath( "main.zui" ) );
	zglFontLoad( "controls", zlabCorePath( "verdana.ttf" ), 10, 1, 255 );
	ZUI::zuiExecuteFile( zlabCorePath( "main.zui" ) );

	// BUILD the plugin buttons
	zMsgQueue( "type=BuildPluginChoiceButton" );

	trace( "Queuing message to start with plugin '%s'...\n", startupPlugin ? startupPlugin : "(null)" );
	zMsgQueue( "type=PluginChange which=%s", startupPlugin );

	#ifdef WIN32
		// @TODO: This should probably move into platform code once I figure out how to do it for mac and linux
		void *hIcon = LoadIcon( _hInstance, (char*)(101) );
		HWND hWnd = (HWND)glfwZBSExt_GetHWND();
		SetClassLong( hWnd, GCL_HICON, (long)hIcon );
	#endif

	int running = 1;
	trace( "Entering main loop...\n" );
	while( running ) {

		SFTIME_RESET ();
		SFTIME_START (PerfTime_ID_Zlab, PerfTime_ID_None);

		#ifdef HARDWAREKEY_USB_0
		extern int usbKeyPoll();
		if( ! usbKeyPoll() ) {
			// Bring up the license notification and then start to corrupt
			// the stack until something crashes.
			// @TODO
		}
		#endif

		if( zprofToggleFlag ) {
			// This check must be done synchronously
			#ifndef ZPROF_MAIN
				// lock profiler semaphore
			#endif
			zprofGLGUIToggle();
			zprofToggleFlag = 0;
			#ifndef ZPROF_MAIN
				// unlock profiler semaphore
			#endif
		}

//		zprofReset( 0 );
//		zprofBeg( root );

		SFTIME_START (PerfTime_ID_Zlab_main, PerfTime_ID_Zlab);
//		zprofBeg( mainLoop );
			mainLoop();
//		zprofEnd();
		SFTIME_END (PerfTime_ID_Zlab_main);

		running = glfwGetWindowParam( GLFW_OPENED );


		// CHECK WINDOW RESIZE
		int x, y, w, h;
		glfwGetWindowGeom( &x, &y, &w, &h );
		static int lastX=-1, lastY=-1, lastW=-1, lastH=-1;
		if( x!=lastX || y!=lastY || w!=lastW || h!=lastH ) {
			// Moved this code from the callback reshape handler because under some
			// mysterious conditions, the callback would go into an an infinite recursion.
			// Moving is here synchronously fixed that problem
			if( w != 0 && h != 0 ) {
				glViewport( 0, 0, w, h );
				glScissor( 0, 0, w, h );
					// keep default scissorbox in sync with viewport; see ZUI::scissorIntersect
			}
			else {
				trace ("skipping glViewport(0,0,0,0).\n");
					// mkness - this would crash on my home machine, probably due to division by zero.
			}

			glClearColor( 0.f, 0.f, 0.f, 0.f );
			glClear( GL_COLOR_BUFFER_BIT );
				// mkness - added clear to black.

			if( w!=lastW || h!=lastH ) {
				ZUI::zuiReshape( (float)w, (float)h );
			}
			if( w != 0 && h != 0 ) {
				// Don't save if we are minimizing the app
				writeWindowPos();
			}
			lastX=x; lastY=y; lastW=w; lastH=h;
		}

		// check console move
		if( zconsoleExists ) {
			static int clastX=-1, clastY=-1, clastW=-1, clastH=-1;
			zconsoleGetPosition( x, y, w, h );
			if( x!=clastX || y!=clastY || w!=clastW || h!=clastH ) {
				writeConsolePos();
				clastX=x; clastY=y; clastW=w; clastH=h;
			}
		}
		
		if( running ) {
			SFTIME_START (PerfTime_ID_Zlab_render, PerfTime_ID_Zlab);
//			zprofBeg( main_render );
				render();
//			zprofEnd();
			SFTIME_END (PerfTime_ID_Zlab_render);

//			zprofEnd();	// root

			extern int zprofGLGUIVisible;
			if( zprofGLGUIVisible ) {
				glPushMatrix();
				zglPixelMatrixInvertedFirstQuadrant();
				glColor3ub(255,255,255);
				glBegin( GL_QUADS );
					glVertex2f( 0.f, 0.f );
					glVertex2f( 300.f, 0.f );
					glVertex2f( 300.f, 300.f );
					glVertex2f( 0.f, 300.f );
				glEnd();
				glColor3ub(0,0,0);
				zprofGLGUIRender( 1 );
				glPopMatrix();
			}
#ifdef ZPROF
			if( zprofDumpFlag ) {
				zprofDumpFlag = 0;
				zprofSortTree();
				zprofDumpToFile( "zprof.txt", "root" );
			}
#endif

			SFTIME_START (PerfTime_ID_Zlab_swap, PerfTime_ID_Zlab);
//			zprofBeg( flush );
			glFlush();
			glfwSwapBuffers();
//			zprofEnd();
			SFTIME_END (PerfTime_ID_Zlab_swap);

			SFTIME_END (PerfTime_ID_Zlab);
			SFTIME_FINISH ();
		}

//zTimeSleepMils( 200 );

	}

	// SHUTDOWN the plugin
	trace( "Shutdown the plugin...\n");
	typedef void (*ShutdownFnPtr)();
	ShutdownFnPtr shutdown = (ShutdownFnPtr)zPluginGetP( curPlugin, "shutdown" );
	if( shutdown ) {
		(*shutdown)();
	}

	glfwTerminate();


	zVarsSave( getUserLocalFilespec( "varslastquit.txt", 0 ), 0 );
	zVarsSave( getUserLocalFilespec( "varslastquit.c.txt", 0 ), 1 );

	#ifndef _DEBUG
	}
	catch(...) {
 		assert( 0 && "Error - Fatal unhandled exception.");
	}
	#endif
	optionsLoaded=0;
	zconsoleFree();

	trace( "Leaving main...\n" );

#ifdef MSVC_MEMLEAK_DEBUG
#ifndef NDEBUG
    _CrtDumpMemoryLeaks();
#endif
#endif
	return 0;
}

