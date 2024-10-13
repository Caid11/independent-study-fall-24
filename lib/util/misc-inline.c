#if defined(WIN32)
#include <Windows.h>
#include <Psapi.h>

#pragma comment(lib,"psapi.lib")

kk_integer_t kk_getCurrMemUsage(kk_context_t* ctx) {
    PROCESS_MEMORY_COUNTERS info;
    GetProcessMemoryInfo(GetCurrentProcess(), &info, sizeof(info));

    return kk_integer_from_ssize_t(info.WorkingSetSize, ctx);
}

kk_integer_t kk_getPeakMemUsage(kk_context_t* ctx) {
    PROCESS_MEMORY_COUNTERS info;
    GetProcessMemoryInfo(GetCurrentProcess(), &info, sizeof(info));

    return kk_integer_from_ssize_t(info.PeakWorkingSetSize, ctx);
}
#else
// FIXME: Non-windows support
#endif
