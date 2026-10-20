#!/usr/bin/env python3
"""Exit 0 if two thin 64-bit Mach-O files are identical apart from their code signature.

Re-signing rewrites the signature blob at the end of __LINKEDIT and the three header fields that describe it
(LC_CODE_SIGNATURE datasize, __LINKEDIT filesize and vmsize). This compares everything else: the header and every load
command with those fields zeroed, and every byte before the signature blob. If the blob starts at different offsets,
the gap in the longer file must be zero padding.
Usage: macho-same-code.py <file a> <file b>
"""
import struct
import sys

MH_MAGIC_64 = 0xFEEDFACF
LC_SEGMENT_64 = 0x19
LC_CODE_SIGNATURE = 0x1D


def normalise(path):
    data = bytearray(open(path, 'rb').read())
    magic, _cpu, _sub, _ftype, ncmds, sizeofcmds, _flags, _res = struct.unpack_from('<IiiIIIII', data, 0)
    if magic != MH_MAGIC_64:
        raise SystemExit(f'{path}: not a thin 64-bit little-endian Mach-O (magic {magic:#x})')
    off = 32
    sigoff = len(data)
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from('<II', data, off)
        if cmd == LC_SEGMENT_64:
            segname = data[off + 8:off + 24].rstrip(b'\0')
            if segname == b'__LINKEDIT':
                struct.pack_into('<Q', data, off + 32, 0)   # vmsize
                struct.pack_into('<Q', data, off + 48, 0)   # filesize
        elif cmd == LC_CODE_SIGNATURE:
            dataoff, _datasize = struct.unpack_from('<II', data, off + 8)
            sigoff = dataoff
            struct.pack_into('<II', data, off + 8, 0, 0)    # dataoff, datasize
        off += cmdsize
    if off != 32 + sizeofcmds:
        raise SystemExit(f'{path}: load commands do not add up')
    return data, sigoff


def main():
    a, sa = normalise(sys.argv[1])
    b, sb = normalise(sys.argv[2])
    lo, hi = min(sa, sb), max(sa, sb)
    if a[:lo] != b[:lo]:
        i = next(i for i in range(lo) if a[i] != b[i])
        print(f'differs at byte {i} (before the signature)')
        return 1
    longer = a if sa > sb else b
    if any(longer[lo:hi]):
        print(f'signature offsets {sa} vs {sb}: the gap is not zero padding')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
