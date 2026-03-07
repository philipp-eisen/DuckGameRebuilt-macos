#ifndef FNA3D_SDL_H
#define FNA3D_SDL_H

#ifdef FNA3D_USE_SDL3
#include <SDL3/SDL.h>
#include <SDL3/SDL_mutex.h>
#include <SDL3/SDL_thread.h>
#include <SDL3/SDL_properties.h>

#ifdef SDL_mutex
#undef SDL_mutex
#endif
#define SDL_mutex SDL_Mutex

#ifdef SDL_sem
#undef SDL_sem
#endif
#define SDL_sem SDL_Semaphore

#ifdef SDL_threadID
#undef SDL_threadID
#endif
#define SDL_threadID SDL_ThreadID

#ifdef SDL_ThreadID
#undef SDL_ThreadID
#endif
#define SDL_ThreadID() SDL_GetCurrentThreadID()

#ifdef SDL_SemPost
#undef SDL_SemPost
#endif
#define SDL_SemPost SDL_SignalSemaphore

#ifdef SDL_SemWait
#undef SDL_SemWait
#endif
#define SDL_SemWait SDL_WaitSemaphore

#ifdef SDL_SemWaitTimeout
#undef SDL_SemWaitTimeout
#endif
#define SDL_SemWaitTimeout SDL_WaitSemaphoreTimeout

#ifdef SDL_GL_DeleteContext
#undef SDL_GL_DeleteContext
#endif
#define SDL_GL_DeleteContext SDL_GL_DestroyContext

#ifdef SDL_GetWindowDisplayIndex
#undef SDL_GetWindowDisplayIndex
#endif
#define SDL_GetWindowDisplayIndex SDL_GetDisplayForWindow

#ifdef SDL_SIMD_ALIGNED
#undef SDL_SIMD_ALIGNED
#endif
#define SDL_SIMD_ALIGNED SDL_SURFACE_SIMD_ALIGNED

#ifdef SDL_PREALLOC
#undef SDL_PREALLOC
#endif
#define SDL_PREALLOC SDL_SURFACE_PREALLOCATED

static inline void *FNA3D_SDL_SIMDAlloc(size_t size)
{
    return SDL_aligned_alloc(SDL_GetSIMDAlignment(), size);
}

static inline void FNA3D_SDL_SIMDFree(void *mem)
{
    SDL_aligned_free(mem);
}

static inline void *FNA3D_SDL_SIMDRealloc(void *mem, size_t size)
{
    void *newMem = FNA3D_SDL_SIMDAlloc(size);
    if (newMem != NULL && mem != NULL)
    {
        SDL_memcpy(newMem, mem, size);
    }
    FNA3D_SDL_SIMDFree(mem);
    return newMem;
}

#define SDL_SIMDAlloc FNA3D_SDL_SIMDAlloc
#define SDL_SIMDFree FNA3D_SDL_SIMDFree
#define SDL_SIMDRealloc FNA3D_SDL_SIMDRealloc

static inline SDL_Surface *FNA3D_SDL_CreateRGBSurface(Uint32 flags, int width, int height, int depth, Uint32 rmask, Uint32 gmask, Uint32 bmask, Uint32 amask)
{
    (void) flags;
    (void) depth;
    (void) rmask;
    (void) gmask;
    (void) bmask;
    (void) amask;
    return SDL_CreateSurface(width, height, SDL_PIXELFORMAT_RGBA32);
}

static inline SDL_Surface *FNA3D_SDL_CreateRGBSurfaceFrom(void *pixels, int width, int height, int depth, int pitch, Uint32 rmask, Uint32 gmask, Uint32 bmask, Uint32 amask)
{
    (void) depth;
    (void) rmask;
    (void) gmask;
    (void) bmask;
    (void) amask;
    return SDL_CreateSurfaceFrom(width, height, SDL_PIXELFORMAT_RGBA32, pixels, pitch);
}

static inline int FNA3D_SDL_BlitScaled(SDL_Surface *src, const SDL_Rect *srcrect, SDL_Surface *dst, const SDL_Rect *dstrect)
{
    return SDL_BlitSurfaceScaled(src, srcrect, dst, dstrect, SDL_SCALEMODE_LINEAR) ? 0 : -1;
}

#define SDL_CreateRGBSurface FNA3D_SDL_CreateRGBSurface
#define SDL_CreateRGBSurfaceFrom FNA3D_SDL_CreateRGBSurfaceFrom
#ifdef SDL_BlitScaled
#undef SDL_BlitScaled
#endif
#define SDL_BlitScaled FNA3D_SDL_BlitScaled
#ifdef SDL_FreeSurface
#undef SDL_FreeSurface
#endif
#define SDL_FreeSurface SDL_DestroySurface

static inline void *FNA3D_SDL_GetWindowData(SDL_Window *window, const char *name)
{
    return SDL_GetPointerProperty(SDL_GetWindowProperties(window), name, NULL);
}

static inline int FNA3D_SDL_SetWindowData(SDL_Window *window, const char *name, void *userdata)
{
    return SDL_SetPointerProperty(SDL_GetWindowProperties(window), name, userdata) ? 0 : -1;
}

#define SDL_GetWindowData FNA3D_SDL_GetWindowData
#define SDL_SetWindowData FNA3D_SDL_SetWindowData

static inline int FNA3D_SDL_GetCurrentDisplayMode(SDL_DisplayID displayID, SDL_DisplayMode *mode)
{
    const SDL_DisplayMode *currentMode = SDL_GetCurrentDisplayMode(displayID);
    if (currentMode == NULL)
    {
        return -1;
    }
    *mode = *currentMode;
    return 0;
}

#define SDL_GetCurrentDisplayMode FNA3D_SDL_GetCurrentDisplayMode

#else
#include <SDL.h>
#endif

#endif
