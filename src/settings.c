#include "settings.h"
#include <shlobj.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <wchar.h>

Settings g_cfg;

/* turn #n into a wide string literal (L#n is not valid C) */
#define WIDE2(x) L##x
#define WIDE(x)  WIDE2(x)

static wchar_t g_ini[MAX_PATH];
static wchar_t g_lists[LIST_COUNT][LIST_MAX][MAX_PATH];
static int     g_listN[LIST_COUNT];

static const wchar_t *k_listKey[LIST_COUNT] = { L"Start", L"Pinned", L"Taskbar", L"Tray" };

const wchar_t *Settings_Path(void)
{
    if (!g_ini[0]) {
        wchar_t dir[MAX_PATH];
        if (SHGetFolderPathW(NULL, CSIDL_APPDATA, NULL, 0, dir) != S_OK)
            lstrcpyW(dir, L"C:\\");
        lstrcatW(dir, L"\\MontyShell");
        CreateDirectoryW(dir, NULL);
        wsprintfW(g_ini, L"%s\\settings.ini", dir);
    }
    return g_ini;
}

void Settings_Defaults(Settings *s)
{
#define X(n,d) s->n = d;
    SETTINGS_INT_LIST(X)
#undef X
#define X(n,len,d) lstrcpynW(s->n, d, len);
    SETTINGS_STR_LIST(X)
#undef X
}

void Settings_Load(void)
{
    const wchar_t *ini = Settings_Path();
    Settings_Defaults(&g_cfg);
#define X(n,d) { wchar_t tmp_[24]; GetPrivateProfileStringW(L"Settings", WIDE(#n), L"", tmp_, 24, ini); g_cfg.n = tmp_[0] ? (int)wcstol(tmp_, NULL, 10) : (d); }
    SETTINGS_INT_LIST(X)
#undef X
#define X(n,len,d) GetPrivateProfileStringW(L"Settings", WIDE(#n), d, g_cfg.n, len, ini);
    SETTINGS_STR_LIST(X)
#undef X
    /* GetPrivateProfileInt returns UINT, so -1 round-trips as 0xFFFFFFFF -> (int)-1: fine. */
    AppList_Load();
}

void Settings_Save(void)
{
    const wchar_t *ini = Settings_Path();
    wchar_t buf[40];
#define X(n,d) wsprintfW(buf, L"%d", g_cfg.n); WritePrivateProfileStringW(L"Settings", WIDE(#n), buf, ini);
    SETTINGS_INT_LIST(X)
#undef X
#define X(n,len,d) WritePrivateProfileStringW(L"Settings", WIDE(#n), g_cfg.n, ini);
    SETTINGS_STR_LIST(X)
#undef X
    AppList_Save();
}

BOOL Settings_Backup(const wchar_t *dst)
{
    Settings_Save();
    return CopyFileW(Settings_Path(), dst, FALSE);
}

BOOL Settings_Restore(const wchar_t *src)
{
    if (!CopyFileW(src, Settings_Path(), FALSE)) return FALSE;
    Settings_Load();
    return TRUE;
}

void Settings_Reset(void)
{
    DeleteFileW(Settings_Path());
    memset(g_listN, 0, sizeof g_listN);
    Settings_Load();
}

/* ---------------- app lists ---------------- */
int AppList_Count(int l) { return (l >= 0 && l < LIST_COUNT) ? g_listN[l] : 0; }

const wchar_t *AppList_Get(int l, int i)
{
    if (l < 0 || l >= LIST_COUNT || i < 0 || i >= g_listN[l]) return L"";
    return g_lists[l][i];
}

BOOL AppList_Add(int l, const wchar_t *p)
{
    if (l < 0 || l >= LIST_COUNT || g_listN[l] >= LIST_MAX) return FALSE;
    for (int i = 0; i < g_listN[l]; i++)
        if (!lstrcmpiW(g_lists[l][i], p)) return FALSE;   /* no duplicates */
    lstrcpynW(g_lists[l][g_listN[l]++], p, MAX_PATH);
    return TRUE;
}

void AppList_Remove(int l, int i)
{
    if (l < 0 || l >= LIST_COUNT || i < 0 || i >= g_listN[l]) return;
    for (int k = i; k < g_listN[l] - 1; k++)
        lstrcpyW(g_lists[l][k], g_lists[l][k + 1]);
    g_listN[l]--;
}

void AppList_Move(int l, int from, int to)
{
    if (l < 0 || l >= LIST_COUNT) return;
    if (from < 0 || to < 0 || from >= g_listN[l] || to >= g_listN[l] || from == to) return;
    wchar_t tmp[MAX_PATH];
    lstrcpyW(tmp, g_lists[l][from]);
    if (from < to) for (int k = from; k < to; k++) lstrcpyW(g_lists[l][k], g_lists[l][k + 1]);
    else           for (int k = from; k > to; k--) lstrcpyW(g_lists[l][k], g_lists[l][k - 1]);
    lstrcpyW(g_lists[l][to], tmp);
}

void AppList_Load(void)
{
    const wchar_t *ini = Settings_Path();
    wchar_t key[32];
    for (int l = 0; l < LIST_COUNT; l++) {
        g_listN[l] = 0;
        int n = (int)GetPrivateProfileIntW(L"Lists", k_listKey[l], 0, ini);
        if (n > LIST_MAX) n = LIST_MAX;
        for (int i = 0; i < n; i++) {
            wsprintfW(key, L"%s%d", k_listKey[l], i);
            GetPrivateProfileStringW(L"Lists", key, L"", g_lists[l][g_listN[l]], MAX_PATH, ini);
            if (g_lists[l][g_listN[l]][0]) g_listN[l]++;
        }
    }
}

void AppList_Save(void)
{
    const wchar_t *ini = Settings_Path();
    wchar_t key[32], num[16];
    for (int l = 0; l < LIST_COUNT; l++) {
        wsprintfW(num, L"%d", g_listN[l]);
        WritePrivateProfileStringW(L"Lists", k_listKey[l], num, ini);
        for (int i = 0; i < g_listN[l]; i++) {
            wsprintfW(key, L"%s%d", k_listKey[l], i);
            WritePrivateProfileStringW(L"Lists", key, g_lists[l][i], ini);
        }
    }
}
