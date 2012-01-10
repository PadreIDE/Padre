/**
 * Padre Win32 executable Launcher
 * @author Olivier Mengué <dolmen@cpan.org>
 */
#define WIN32_LEAN_AND_MEAN
#define STRICT

#define _WIN32_WINNT 0x0501
#include <windows.h>
#include <tchar.h>


#include <EXTERN.h>               /* from the Perl distribution     */
#include <perl.h>                 /* from the Perl distribution     */

#include "padre-rc.h"


/* perl -MExtUtils::Embed -e xsinit -- -o perlxsi.c */
EXTERN_C void xs_init (pTHX);



static void LocalizedMessageBox(LPCTSTR lpMessage, LPCTSTR lpTitle, DWORD dwFlags)
{
	HMODULE hModule;
	TCHAR szTitle[256];
	TCHAR szMessage[256];

	hModule = GetModuleHandle(NULL);
	if (IS_INTRESOURCE(lpMessage)) {
		LoadString(hModule, (UINT)lpMessage, szMessage, sizeof(szMessage)/sizeof(szMessage[0]));
		lpMessage = szMessage;
	}
	if (IS_INTRESOURCE(lpTitle)) {
		LoadString(hModule, (UINT)lpTitle, szTitle, sizeof(szTitle)/sizeof(szTitle[0]));
		lpTitle = szTitle;
	}
	MessageBox(NULL, lpMessage, lpTitle, dwFlags);
}

static BOOL FileExists(LPCTSTR lpFileName)
{
	DWORD att = GetFileAttributes(lpFileName);
	return (att != INVALID_FILE_ATTRIBUTES); //&& (att & (FILE_ATTRIBUTE_DEVICE|FILE_ATTRIBUTE_DIRECTORY) == 0);
}

static int GetDirectory(LPTSTR lpDir, LPCTSTR lpFilename, int iBufSize)
{
	int len, len2;
	LPCTSTR p;
	LPTSTR q;

	len = lstrlen(lpFilename);
	if (len == 0) {
		lpDir[0] = _T('\0');
		return 0;
	}
	p = lpFilename + len;
	while (--p > lpFilename) {
		if (*p == _T('\\') || *p == _T('/'))
			break;
	};
	len = p - lpFilename;
	if (lpDir == lpFilename) {
		*(LPTSTR)p = _T('\0');
	} else {
		if (len+1 > iBufSize) {
			lpDir[0] = _T('\0');
			return 0;
		}
		p = lpFilename;
		q = lpDir;
		len2 = len;
		while (len2--)
			*q++ = *p++;
		*q = _T('\0');
	}
	return len;
}







int main(int argc, char **argv, char **env)
{
	// Padre.exe path
	TCHAR szExePath[MAX_PATH];
	// Padre script path
	TCHAR szPadre[MAX_PATH];
	// wperl.exe path
	TCHAR szWPerlExePath[MAX_PATH];
	HMODULE hModule, hModulePerlDll;
	DWORD dwLength;
	HANDLE hHeap;
	char **new_argv;
	PerlInterpreter *my_perl;  /***    The Perl interpreter    ***/
	int i;
	int exitcode;

	hModule = GetModuleHandle(NULL);
	// Find the the executable's path
	dwLength = GetModuleFileName(hModule, szExePath, sizeof(szExePath)/sizeof(szExePath[0]));


	// Build the 'padre' script path
	dwLength = GetDirectory(szPadre, szExePath, sizeof(szPadre)/sizeof(szPadre[0]));
	lstrcpy(szPadre+dwLength, _T("\\padre"));
	//MessageBox(NULL, szPadre, "Padre", MB_OK|MB_ICONINFORMATION);

	// At this point we should check if padre script exists or not
	if (! FileExists(szPadre)) {
		LocalizedMessageBox(MAKEINTRESOURCE(IDS_ERR_SCRIPT), MAKEINTRESOURCE(IDS_APP_TITLE), MB_OK|MB_ICONERROR);
		return 1;
	}

	// Rewrite the command line to insert the padre script
	hHeap = GetProcessHeap();
	new_argv = HeapAlloc(hHeap, 0, (argc+2)*sizeof(new_argv[0]));
	new_argv[0] = argv[0];
	new_argv[1] = "--";
	new_argv[2] = szPadre;
	for(i=1; i<argc; i++)
		new_argv[i+2] = argv[i];
	argc += 2;
	argv = new_argv;

	// We must set $^X to wperl.exe
	// We do that by changing argv[0]

	// Get the module of the Perl DLL to which we have been linked
	// as this is where wperl.exe is.
	if (GetModuleHandleEx(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS
						| GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
						(LPCTSTR)RunPerl, &hModulePerlDll)
			&& hModulePerlDll != hModule) {
		// If hModulePerlDll == hModule, we have to for another function

		dwLength = GetModuleFileName(hModulePerlDll, szWPerlExePath,
					sizeof(szWPerlExePath)/sizeof(szWPerlExePath[0]));
		//MessageBox(NULL, szWPerlExePath, "Padre", MB_OK|MB_ICONINFORMATION);
		dwLength = GetDirectory(szWPerlExePath, szWPerlExePath,
					sizeof(szWPerlExePath)/sizeof(szWPerlExePath[0]));
		lstrcpy(szWPerlExePath+dwLength, _T("\\wperl.exe"));
		if (FileExists(szWPerlExePath))
			argv[0] = szWPerlExePath;
	}

	//MessageBox(NULL, argv[0], "Padre", MB_OK|MB_ICONINFORMATION);
	
#if 0
	/*
	 * Unfortunately it seems RunPerl() ignores the changed argv[0] and
	 * overrides argv[0] so that $^X is still Padre.exe
	 */
	exitcode = RunPerl(argc, argv, env);
#else

#if defined(TOP_CLONE) && defined(USE_ITHREADS)
	// See the RunPerl source
	MessageBox(NULL, "FIXME: ithreads support not implemented in Padre.exe launcher!", "Padre", MB_OK|MB_ICONERROR);
#endif

	/* This is derived from the source of RunPerl() */

	PERL_SYS_INIT3(&argc, &argv, &env);
	if (!(my_perl = perl_alloc())) {
		MessageBox(NULL, "Can't allocate Perl interpreter!", "Padre", MB_OK|MB_ICONERROR);
		exitcode = 1;
	} else {
		perl_construct(my_perl);
		PL_exit_flags |= PERL_EXIT_DESTRUCT_END;
		PL_perl_destruct_level = 0;
		exitcode = perl_parse(my_perl, xs_init, argc, argv, env)
				|| perl_run(my_perl);
		perl_destruct(my_perl);
		perl_free(my_perl);
	}
	PERL_SYS_TERM();

#endif

	HeapFree(hHeap, 0, new_argv);
	return exitcode;
}
/**
# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
*/
/* vim:set ts=4 sts=4 sw=4: */
