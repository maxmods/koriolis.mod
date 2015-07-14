// Small support functions for BlitzMax
// Author: Thomas Mayer
// License: Public domain code

#include "unzip.h"
#include "zip.h"

#include "brl.mod/blitz.mod/blitz.h"

#ifdef BMX_NG
#define CB_PREF(func) func
#else
#define CB_PREF(func) _##func
#endif

int unzGetCurrentFileSize (unzFile* zipFile)
{
	unz_file_info	fileinfo;

	if (!zipFile) {
		return 0;
	}

	unzGetCurrentFileInfo ( zipFile, &fileinfo,
							0,
							0,
							0,
							0,
							0,
							0);
	return fileinfo.uncompressed_size;
}

int zipOpenNewFileWithPassword (file, filename, zipfi,
                                         extrafield_local, size_extrafield_local,
                                         extrafield_global, size_extrafield_global,
                                         comment, method, level,password)
    zipFile file;
    const char* filename;
    const zip_fileinfo* zipfi;
    const void* extrafield_local;
    uInt size_extrafield_local;
    const void* extrafield_global;
    uInt size_extrafield_global;
    const char* comment;
    int method;
    int level;
    const char* password;
{
	return zipOpenNewFileInZip3(file,filename,zipfi,extrafield_local,size_extrafield_local,extrafield_global,size_extrafield_global,comment,method,level,0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY,password, 0);
}

#ifdef BMX_NG
extern void* CB_PREF(koriolis_zipstream_TZipStream_open_file_func)(voidpf opaque, const char* filename, int mode);
extern BBInt64 CB_PREF(koriolis_zipstream_TZipStream_read_file_func)(voidpf opaque, voidpf stream, void* buf, BBInt64 size);
extern BBInt64 CB_PREF(koriolis_zipstream_TZipStream_write_file_func)(voidpf opaque, voidpf stream, void* buf, BBInt64 size);
extern BBInt64 CB_PREF(koriolis_zipstream_TZipStream_tell_file_func)(voidpf opaque, voidpf stream);
extern BBInt64 CB_PREF(koriolis_zipstream_TZipStream_seek_file_func)(voidpf opaque, voidpf stream, BBInt64 offset, int origin);
extern int CB_PREF(koriolis_zipstream_TZipStream_close_file_func)(voidpf opaque, voidpf stream);
extern int CB_PREF(koriolis_zipstream_TZipStream_testerror_file_func)(voidpf opaque, voidpf stream);
#else
extern void* CB_PREF(koriolis_zipstream_TZipStream_open_file_func)(voidpf opaque, const char* filename, int mode);
extern int CB_PREF(koriolis_zipstream_TZipStream_read_file_func)(voidpf opaque, voidpf stream, void* buf, int size);
extern int CB_PREF(koriolis_zipstream_TZipStream_write_file_func)(voidpf opaque, voidpf stream, void* buf, int size);
extern int CB_PREF(koriolis_zipstream_TZipStream_tell_file_func)(voidpf opaque, voidpf stream);
extern int CB_PREF(koriolis_zipstream_TZipStream_seek_file_func)(voidpf opaque, voidpf stream, int offset, int origin);
extern int CB_PREF(koriolis_zipstream_TZipStream_close_file_func)(voidpf opaque, voidpf stream);
extern int CB_PREF(koriolis_zipstream_TZipStream_testerror_file_func)(voidpf opaque, voidpf stream);
#endif

voidpf bmx_zipstream_open_file_func(voidpf opaque, const char* filename, int mode) {
	return CB_PREF(koriolis_zipstream_TZipStream_open_file_func)(opaque, filename, mode);
}

uLong bmx_zipstream_read_file_func(voidpf opaque, voidpf stream, void* buf, uLong size) {
	return CB_PREF(koriolis_zipstream_TZipStream_read_file_func)(opaque, stream, buf, size);
}

uLong bmx_zipstream_write_file_func(voidpf opaque, voidpf stream, const void* buf, uLong size) {
	return CB_PREF(koriolis_zipstream_TZipStream_write_file_func)(opaque, stream, buf, size);
}

long bmx_zipstream_tell_file_func(voidpf opaque, voidpf stream) {
	return CB_PREF(koriolis_zipstream_TZipStream_tell_file_func)(opaque, stream);
}

long bmx_zipstream_seek_file_func(voidpf opaque, voidpf stream, uLong offset, int origin) {
	CB_PREF(koriolis_zipstream_TZipStream_seek_file_func)(opaque, stream, offset, origin);
	/* Unlike the standard seek function which returns success flag, BRL.Stream returns position in file. */
	return 0;
}

int bmx_zipstream_close_file_func(voidpf opaque, voidpf stream) {
	return CB_PREF(koriolis_zipstream_TZipStream_close_file_func)(opaque, stream);
}

int bmx_zipstream_testerror_file_func(voidpf opaque, voidpf stream) {
	return CB_PREF(koriolis_zipstream_TZipStream_testerror_file_func)(opaque, stream);
}


unzFile bmx_zipstream_unzOpen2(char * zipFileName, void * opaque) {
	zlib_filefunc_def zfd;
	
	zfd.zopen_file = bmx_zipstream_open_file_func;
    zfd.zread_file = bmx_zipstream_read_file_func;
    zfd.zwrite_file = bmx_zipstream_write_file_func;
    zfd.ztell_file = bmx_zipstream_tell_file_func;
    zfd.zseek_file = bmx_zipstream_seek_file_func;
    zfd.zclose_file = bmx_zipstream_close_file_func;
    zfd.zerror_file = bmx_zipstream_testerror_file_func;
    zfd.opaque = opaque;
	
	return unzOpen2(zipFileName, &zfd);
}
