/**
 * Windows Explorer thumbnail provider for .wiretuner files.
 *
 * Implements IThumbnailProvider interface to provide File Explorer with
 * thumbnail previews by:
 * 1. Extracting artboard data from .wiretuner file
 * 2. Generating bitmap thumbnail via WireTuner CLI
 * 3. Returning HBITMAP for Explorer display
 *
 * ## Architecture
 *
 * This shell extension integrates with Windows Shell (IThumbnailProvider)
 * and delegates thumbnail generation to the WireTuner app's thumbnail service.
 *
 * Flow:
 * - Explorer requests thumbnail for .wiretuner file
 * - Extension extracts document metadata
 * - CLI command generates thumbnail: `wiretuner.exe --generate-thumbnail <file> <output>`
 * - Extension loads PNG and converts to HBITMAP
 *
 * ## Registration
 *
 * Registered in Windows Registry during installation:
 * - HKCR\.wiretuner\ShellEx\{E357FCCD-A995-4576-B01F-234630154E96}
 * - COM server CLSID registered in HKCR\CLSID\{...}
 *
 * Related: FR-048 (Windows Platform Integration)
 */

#include <windows.h>
#include <thumbcache.h>
#include <shlwapi.h>
#include <gdiplus.h>
#include <string>
#include <filesystem>
#include <fstream>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "gdiplus.lib")

using namespace Gdiplus;

// {12345678-1234-1234-1234-123456789ABC} - Replace with actual GUID
const CLSID CLSID_WireTunerThumbnailProvider =
    { 0x12345678, 0x1234, 0x1234, { 0x12, 0x34, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC } };

/**
 * Thumbnail provider COM object.
 */
class WireTunerThumbnailProvider :
    public IThumbnailProvider,
    public IInitializeWithFile
{
public:
    WireTunerThumbnailProvider() : m_refCount(1) {
        GdiplusStartupInput gdiplusStartupInput;
        GdiplusStartup(&m_gdiplusToken, &gdiplusStartupInput, NULL);
    }

    virtual ~WireTunerThumbnailProvider() {
        GdiplusShutdown(m_gdiplusToken);
    }

    // IUnknown methods
    STDMETHODIMP QueryInterface(REFIID riid, void** ppv) {
        static const QITAB qit[] = {
            QITABENT(WireTunerThumbnailProvider, IThumbnailProvider),
            QITABENT(WireTunerThumbnailProvider, IInitializeWithFile),
            { 0 }
        };
        return QISearch(this, qit, riid, ppv);
    }

    STDMETHODIMP_(ULONG) AddRef() {
        return InterlockedIncrement(&m_refCount);
    }

    STDMETHODIMP_(ULONG) Release() {
        ULONG count = InterlockedDecrement(&m_refCount);
        if (count == 0) {
            delete this;
        }
        return count;
    }

    // IInitializeWithFile methods
    STDMETHODIMP Initialize(LPCWSTR pszFilePath, DWORD grfMode) {
        m_filePath = pszFilePath;
        return S_OK;
    }

    // IThumbnailProvider methods
    STDMETHODIMP GetThumbnail(UINT cx, HBITMAP* phbmp, WTS_ALPHATYPE* pdwAlpha) {
        *phbmp = NULL;
        *pdwAlpha = WTSAT_ARGB;

        // Generate thumbnail via CLI
        std::wstring thumbnailPath;
        HRESULT hr = GenerateThumbnail(cx, thumbnailPath);
        if (FAILED(hr)) {
            // Fallback to placeholder
            return GeneratePlaceholder(cx, phbmp);
        }

        // Load PNG and convert to HBITMAP
        Bitmap* bitmap = Bitmap::FromFile(thumbnailPath.c_str());
        if (!bitmap || bitmap->GetLastStatus() != Ok) {
            delete bitmap;
            return GeneratePlaceholder(cx, phbmp);
        }

        // Convert to HBITMAP
        Color background(255, 255, 255, 255);
        bitmap->GetHBITMAP(background, phbmp);

        delete bitmap;
        return (*phbmp) ? S_OK : E_FAIL;
    }

private:
    LONG m_refCount;
    ULONG_PTR m_gdiplusToken;
    std::wstring m_filePath;

    /**
     * Generates thumbnail using WireTuner CLI.
     */
    HRESULT GenerateThumbnail(UINT cx, std::wstring& outPath) {
        // Create cache directory
        wchar_t tempPath[MAX_PATH];
        GetTempPathW(MAX_PATH, tempPath);

        std::wstring cacheDir = std::wstring(tempPath) + L"wiretuner-thumbnails\\";
        CreateDirectoryW(cacheDir.c_str(), NULL);

        // Generate cache key from file path and modification time
        WIN32_FILE_ATTRIBUTE_DATA fileInfo;
        if (!GetFileAttributesExW(m_filePath.c_str(), GetFileExInfoStandard, &fileInfo)) {
            return E_FAIL;
        }

        ULARGE_INTEGER modTime;
        modTime.LowPart = fileInfo.ftLastWriteTime.dwLowDateTime;
        modTime.HighPart = fileInfo.ftLastWriteTime.dwHighDateTime;

        wchar_t cacheKey[512];
        swprintf_s(cacheKey, L"%s-%llu-%u.png",
            PathFindFileNameW(m_filePath.c_str()),
            modTime.QuadPart,
            cx);

        outPath = cacheDir + cacheKey;

        // Check if cached thumbnail exists
        if (PathFileExistsW(outPath.c_str())) {
            return S_OK;
        }

        // Find WireTuner CLI
        std::wstring cliPath = FindWireTunerCLI();
        if (cliPath.empty()) {
            return E_FAIL; // CLI not found
        }

        // Build command line
        wchar_t cmdLine[2048];
        swprintf_s(cmdLine, L"\"%s\" --generate-thumbnail \"%s\" \"%s\" --size %u",
            cliPath.c_str(),
            m_filePath.c_str(),
            outPath.c_str(),
            cx);

        // Execute CLI
        STARTUPINFOW si = { sizeof(si) };
        PROCESS_INFORMATION pi;
        si.dwFlags = STARTF_USESHOWWINDOW;
        si.wShowWindow = SW_HIDE;

        if (!CreateProcessW(NULL, cmdLine, NULL, NULL, FALSE,
                           CREATE_NO_WINDOW, NULL, NULL, &si, &pi)) {
            return E_FAIL;
        }

        // Wait for completion (with timeout)
        DWORD waitResult = WaitForSingleObject(pi.hProcess, 5000); // 5 second timeout
        DWORD exitCode = 1;
        GetExitCodeProcess(pi.hProcess, &exitCode);

        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);

        if (waitResult != WAIT_OBJECT_0 || exitCode != 0) {
            return E_FAIL;
        }

        return S_OK;
    }

    /**
     * Finds WireTuner CLI executable.
     */
    std::wstring FindWireTunerCLI() {
        // Check common installation paths
        const wchar_t* searchPaths[] = {
            L"C:\\Program Files\\WireTuner\\wiretuner.exe",
            L"C:\\Program Files (x86)\\WireTuner\\wiretuner.exe",
            NULL
        };

        for (int i = 0; searchPaths[i] != NULL; i++) {
            if (PathFileExistsW(searchPaths[i])) {
                return searchPaths[i];
            }
        }

        // Check PATH environment variable
        wchar_t pathBuf[32768];
        DWORD pathLen = GetEnvironmentVariableW(L"PATH", pathBuf, 32768);
        if (pathLen > 0) {
            std::wstring path(pathBuf);
            size_t pos = 0;
            while ((pos = path.find(L';')) != std::wstring::npos) {
                std::wstring dir = path.substr(0, pos);
                std::wstring exePath = dir + L"\\wiretuner.exe";
                if (PathFileExistsW(exePath.c_str())) {
                    return exePath;
                }
                path.erase(0, pos + 1);
            }
        }

        return L"";
    }

    /**
     * Generates placeholder thumbnail.
     */
    HRESULT GeneratePlaceholder(UINT cx, HBITMAP* phbmp) {
        // Create placeholder bitmap with WireTuner icon
        Bitmap bitmap(cx, cx, PixelFormat32bppARGB);
        Graphics graphics(&bitmap);

        // White background
        SolidBrush whiteBrush(Color(255, 255, 255));
        graphics.FillRectangle(&whiteBrush, 0, 0, cx, cx);

        // Blue circle (simple icon)
        SolidBrush blueBrush(Color(255, 33, 150, 243));
        INT margin = cx / 4;
        graphics.FillEllipse(&blueBrush, margin, margin, cx - margin * 2, cx - margin * 2);

        // Convert to HBITMAP
        Color background(255, 255, 255);
        bitmap.GetHBITMAP(background, phbmp);

        return (*phbmp) ? S_OK : E_FAIL;
    }
};

/**
 * Class factory for creating thumbnail provider instances.
 */
class WireTunerThumbnailProviderFactory : public IClassFactory
{
public:
    WireTunerThumbnailProviderFactory() : m_refCount(1) {}

    // IUnknown
    STDMETHODIMP QueryInterface(REFIID riid, void** ppv) {
        if (riid == IID_IUnknown || riid == IID_IClassFactory) {
            *ppv = static_cast<IClassFactory*>(this);
            AddRef();
            return S_OK;
        }
        *ppv = NULL;
        return E_NOINTERFACE;
    }

    STDMETHODIMP_(ULONG) AddRef() {
        return InterlockedIncrement(&m_refCount);
    }

    STDMETHODIMP_(ULONG) Release() {
        ULONG count = InterlockedDecrement(&m_refCount);
        if (count == 0) {
            delete this;
        }
        return count;
    }

    // IClassFactory
    STDMETHODIMP CreateInstance(IUnknown* pUnkOuter, REFIID riid, void** ppv) {
        if (pUnkOuter != NULL) {
            return CLASS_E_NOAGGREGATION;
        }

        WireTunerThumbnailProvider* provider = new WireTunerThumbnailProvider();
        HRESULT hr = provider->QueryInterface(riid, ppv);
        provider->Release();
        return hr;
    }

    STDMETHODIMP LockServer(BOOL fLock) {
        return S_OK;
    }

private:
    LONG m_refCount;
};

/**
 * DLL entry points.
 */
STDAPI DllGetClassObject(REFCLSID rclsid, REFIID riid, LPVOID* ppv) {
    if (rclsid == CLSID_WireTunerThumbnailProvider) {
        WireTunerThumbnailProviderFactory* factory = new WireTunerThumbnailProviderFactory();
        HRESULT hr = factory->QueryInterface(riid, ppv);
        factory->Release();
        return hr;
    }
    return CLASS_E_CLASSNOTAVAILABLE;
}

STDAPI DllCanUnloadNow() {
    // Simplified - in production, would track object count
    return S_OK;
}

STDAPI DllRegisterServer() {
    // Register COM server in registry
    // Implementation would use registry APIs to register CLSID and file associations
    return S_OK;
}

STDAPI DllUnregisterServer() {
    // Unregister COM server
    return S_OK;
}
