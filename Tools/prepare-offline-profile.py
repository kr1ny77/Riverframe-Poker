#!/usr/bin/env python3
"""Compile a host-kernel QA network restriction; no app or host policy is changed."""
import ctypes
import hashlib
import json
from pathlib import Path

class Profile(ctypes.Structure):
    _fields_ = [('builtin',ctypes.c_char_p),('data',ctypes.c_void_p),('size',ctypes.c_size_t)]

root = Path(__file__).resolve().parent.parent
source = '(version 1)(allow default)(deny network-outbound (remote ip "*:*"))(deny network-inbound (local ip "*:*"))'
library = ctypes.CDLL('/usr/lib/libsandbox.1.dylib')
library.sandbox_compile_string.argtypes = [ctypes.c_char_p,ctypes.c_void_p,ctypes.POINTER(ctypes.c_char_p)]
library.sandbox_compile_string.restype = ctypes.POINTER(Profile)
library.sandbox_free_profile.argtypes = [ctypes.POINTER(Profile)]
error = ctypes.c_char_p()
profile = library.sandbox_compile_string(source.encode(),None,ctypes.byref(error))
assert profile, error.value
try:
    assert not profile.contents.builtin
    assert 0 < profile.contents.size < 1_000_000
    data = ctypes.string_at(profile.contents.data,profile.contents.size)
finally:
    library.sandbox_free_profile(profile)
path = root/'.build/qa-no-network.bin'
path.parent.mkdir(exist_ok=True)
path.write_bytes(data)
metadata = {'profile':source,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),
            'path':str(path),'scope':'QA app process only; compile step applies no policy'}
path.with_suffix('.json').write_text(json.dumps(metadata,indent=2)+'\n')
print(json.dumps(metadata,indent=2))
