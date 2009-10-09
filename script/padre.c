/**
 * Padre Minimal Win32 Executable Launcher
 * @author Olivier Mengué <dolmen@cpan.org>
 */
#define WIN32_LEAN_AND_MEAN
#define STRICT
#include <windows.h>
#include <tchar.h>


#include <EXTERN.h>               /* from the Perl distribution     */
#include <perl.h>                 /* from the Perl distribution     */

#include "padre-rc.h"


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


/**
 * When called by windows, we simply launch Padre from here
 */
int
main(int argc, char **argv, char **env)
{
	// Padre.exe path
	TCHAR szExePath[MAX_PATH];
	// Padre script path
	static TCHAR szPadre[MAX_PATH];
	HMODULE hModule;
	DWORD dwLength;
	HANDLE hHeap;
	char **new_argv;
	int i;
	int r;

	hModule = GetModuleHandle(NULL);
	//Find the the executable's path
	dwLength = GetModuleFileName(hModule, szExePath, sizeof(szExePath)/sizeof(szExePath[0]));

	// Build the 'padre' script path
	if (dwLength) {
		lstrcpy(szPadre, szExePath);
		while (--dwLength) {
			if (szPadre[ dwLength ] == _T('\\') || szPadre[ dwLength ] == _T('/')) {
				dwLength++;
				break;
			}
		}
	}
	lstrcpy(&szPadre[dwLength], _T("padre"));
	//LocalizedMessageBox(szPadre, MAKEINTRESOURCE(IDS_APP_TITLE), MB_OK|MB_ICONINFORMATION);

	//At this point we should check if padre script exists or not
	if (! FileExists(szPadre)) {
		LocalizedMessageBox(MAKEINTRESOURCE(IDS_ERR_SCRIPT), MAKEINTRESOURCE(IDS_APP_TITLE), MB_OK|MB_ICONERROR);
		ExitProcess(1);
	}

	hHeap = GetProcessHeap();
	new_argv = HeapAlloc(hHeap, 0, (argc+2)*sizeof(new_argv[0]));
	new_argv[0] = argv[0];
	new_argv[1] = "--";
	new_argv[2] = szPadre;
	for(i=1; i<argc; i++)
		new_argv[i+2] = argv[i];
	argc += 2;

	r = RunPerl(argc, new_argv, env);

	HeapFree(hHeap, 0, new_argv);
	return r;
}
/**
# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
*/
/* vim:set ts=4 sts=4 sw=4: */
