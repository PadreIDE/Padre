#ifdef WIN32
#define _WIN32_WINNT 0x0500
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

MODULE = Padre::Util::Win32 PACKAGE = Padre::Util::Win32

#ifdef WIN32
#include <windows.h>
#include <ShellAPI.h>
#include <Psapi.h>

SV*
_recycle_file( filename )
    char* filename
  CODE:
    SHFILEOPSTRUCT op;
    int result;
    
    /* default return is undef - for failuire */
    
    memset(&op,0,sizeof(op));
    op.wFunc  = FO_DELETE;
    op.fFlags = FOF_ALLOWUNDO;
    op.pFrom  = filename;
    
    result = SHFileOperation( &op );
    
    if(result != 0)
    {
        XSRETURN_UNDEF;
    }
    else
    {
        /* check if any errors */
        if(op.fAnyOperationsAborted)
        {
            RETVAL = newSViv(0);
        } 
        else
        {
            RETVAL = newSViv(1);
        }
    }
  OUTPUT:
    RETVAL
    
   
SV*
_allow_set_foreground_window ( processid )
    long processid
  CODE:
    int result;
    result = AllowSetForegroundWindow( processid );
    RETVAL = newSViv( result );
  OUTPUT:
    RETVAL
    
    
SV*
_execute_process_and_wait ( file, params, directory, show )
    char *file
    char *params
    char *directory
    int show
  CODE:
    SHELLEXECUTEINFO info;
    BOOL result;
    
    memset(&info,0,sizeof(info));
    info.cbSize = sizeof(info);
    info.lpVerb = "open\0";
    info.lpDirectory = directory;
    info.lpFile = file;
    info.lpParameters = params;
    info.nShow = show;
    info.fMask = SEE_MASK_NOCLOSEPROCESS;

    result = ShellExecuteEx( &info );
    
    if( !result )
      XSRETURN_UNDEF;
      
    WaitForSingleObject(info.hProcess , INFINITE );
    CloseHandle(info.hProcess);
    
    RETVAL = newSViv( 1 );
  OUTPUT:
    RETVAL
    
    
SV*
_get_current_process_memory_size()

  CODE:
    PROCESS_MEMORY_COUNTERS stats;
    
    memset(&stats,0,sizeof(stats));
    stats.cb = sizeof(stats);
    
    GetProcessMemoryInfo( GetCurrentProcess(), &stats, stats.cb );

    RETVAL = newSViv( stats.PeakWorkingSetSize );
  OUTPUT:
    RETVAL
    
#else

SV*
_no_win32_noop()
  CODE:
    XSRETURN_UNDEF;


#endif
