"""Keep development tools unobtrusive on the machine running the game."""
import os


def enable():
    if os.name == 'nt':
        import ctypes
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.GetCurrentProcess.restype = ctypes.c_void_p
        kernel.SetPriorityClass.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
        if not kernel.SetPriorityClass(kernel.GetCurrentProcess(), 0x40):
            raise ctypes.WinError(ctypes.get_last_error())
    elif hasattr(os, 'nice'):
        os.nice(10)
