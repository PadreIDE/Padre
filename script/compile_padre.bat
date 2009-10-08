@echo off
rem Creates Padre launcher executable
if exist padre.exe del padre.exe
if exist padre-rc.o del padre-rc.o
windres padre-rc.rc padre-rc.o
gcc -Wall -Os -mwin32 -mwindows -Wl,-s %* padre.c padre-rc.o -o padre.exe
