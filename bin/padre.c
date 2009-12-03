/**
 * Padre Minimal Win32 Executable Launcher
 * @author Ahmad M. Zawawi <ahmad.zawawi@gmail.com>
 * @author Olivier Mengué <dolmen@cpan.org>
 */
#define WIN32_LEAN_AND_MEAN
#define STRICT
#include <windows.h>
#include <tchar.h>

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
#ifdef Mini1
VOID WINAPI __main(VOID)
#elif defined(Mini2)
VOID WINAPI WinMainCRTStartup(VOID)
#else
int WINAPI WinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance,
	LPSTR lpCmdLineArgs, int nCmdShow)
#endif
{
	// Padre.exe path
	TCHAR szExePath[MAX_PATH];
	// WPerl.exe path
	TCHAR szWPerl[MAX_PATH];
	// Padre script path
	TCHAR szPadre[MAX_PATH];
	// WPerl Command line
	TCHAR szCmdLine[1024+1];
	HMODULE hModule;
	STARTUPINFO si;
	PROCESS_INFORMATION pi;
	BOOL bSuccess;
	DWORD dwLength;
	LPCTSTR lpArgs;

	hModule = GetModuleHandle(NULL);
	//Find the the executable's path
	dwLength = GetModuleFileName(hModule, szExePath, sizeof(szExePath)/sizeof(szExePath[0]));
	if (dwLength) {
		while (dwLength && szExePath[ dwLength ] != '\\' && szExePath[ dwLength ] != '/') {
			dwLength--;
		}
		szExePath[ dwLength + 1 ] = '\0';
	}

#if 0
	lstrcpy(szWPerl, _T("C:\\strawberry\\perl\\bin\\wperl.exe"));
#else
	lstrcpy(szWPerl, szExePath);
	lstrcpy(&szWPerl[dwLength+1], _T("wperl.exe"));
#endif

	//At this point we should check if padre script exists or not
	if (! FileExists(szWPerl)) {
		LocalizedMessageBox(MAKEINTRESOURCE(IDS_ERR_WPERL), MAKEINTRESOURCE(IDS_APP_TITLE), MB_OK|MB_ICONERROR);
		ExitProcess(1);
	}


	// Build the 'padre' script path
	lstrcpy(szPadre, szExePath);
	lstrcpy(&szPadre[dwLength+1], _T("padre"));

	//At this point we should check if padre script exists or not
	if (! FileExists(szPadre)) {
		LocalizedMessageBox(MAKEINTRESOURCE(IDS_ERR_SCRIPT), MAKEINTRESOURCE(IDS_APP_TITLE), MB_OK|MB_ICONERROR);
		ExitProcess(1);
	}

	lpArgs = GetCommandLine();
	//LocalizedMessageBox(lpArgs, MAKEINTRESOURCE(IDS_APP_TITLE), MB_OK|MB_ICONINFORMATION);
	do {
		while (*lpArgs == _T(' ') || *lpArgs == _T('\t')) lpArgs++;
		if (!*lpArgs) break;
		if (*lpArgs == _T('"')) {
			lpArgs++;
			while (*lpArgs && *lpArgs != _T('"')) lpArgs++;
			if (*lpArgs == _T('"')) lpArgs++;
		} else {
			while (*lpArgs && *lpArgs != _T(' ') && *lpArgs != _T('\t')) lpArgs++;
		}
	} while (0);
	// Build the command line
	wsprintf(szCmdLine, "\"%s\" \"%s\"%s", szWPerl, szPadre, lpArgs);
	szCmdLine[(sizeof(szCmdLine)/sizeof(szCmdLine[0]))-1] = '\0';

	ZeroMemory( &pi, sizeof(pi) );
	GetStartupInfo(&si);
	//LocalizedMessageBox(szCmdLine, MAKEINTRESOURCE(IDS_APP_TITLE), MB_OK|MB_ICONINFORMATION);
	bSuccess = CreateProcess(szWPerl,
							 szCmdLine,
							 NULL,
							 NULL,
							 TRUE,
							 GetPriorityClass(hModule),
							 GetEnvironmentStrings(),
							 NULL,
							 &si,
							 &pi);
	if (bSuccess) {
		//WaitForSingleObject( pi.hProcess, INFINITE );
		CloseHandle(pi.hProcess);
		CloseHandle(pi.hThread);
	} else {
		LocalizedMessageBox(MAKEINTRESOURCE(IDS_ERR_RUN), MAKEINTRESOURCE(IDS_APP_TITLE), MB_OK|MB_ICONERROR);
	}

	// The application's return value
	ExitProcess(0);
}
/**
# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
*/
/* vim:set ts=4 sts=4 sw=4: */
