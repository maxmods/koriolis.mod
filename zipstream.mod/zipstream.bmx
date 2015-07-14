Strict

Rem
bbdoc: 	Zip stream support (read-only)
End Rem
Module koriolis.zipstream

Import koriolis.bufferedstream

ModuleInfo "Version: 1.04"
ModuleInfo "Author: Régis JEAN-GILLES (Koriolis), Bruce A Henderson"
ModuleInfo "License: Public Domain"
ModuleInfo "Credit: This mod makes use if the ZLib C functions by Gilles Vollant (http://www.winimage.com/zLibDll/unzip.html), with tidbits from the ZipEngine module by gman)"
ModuleInfo "History: 1.04"
ModuleInfo "History: Updated for bmx-ng. Now 64-bit compatible."
ModuleInfo "History: 1.0.3 Fixed crash when attempting to close an already closed ZipStream. Corrected misspell in SetZipStreamPassword and ClearZipStreamPassword (but also kept misspelled version for backward compatibility)."
ModuleInfo "History: 1.0.2 ZipStream now seekable. The raw Seek method uses simple brute force (restarts from the beginning of the file) but the stream is now wrapped with a a TBufferedStream, amortizing any potential inefficiency"

Import pub.zlib
Import brl.stream
Import "zip.c"
Import "unzip.c"
Import "ioapi.c"
Import "bmxsupport.c"
Import brl.filesystem
Import brl.map

Private


Const ZLIB_FILEFUNC_SEEK_CUR% = 1
Const ZLIB_FILEFUNC_SEEK_END% = 2
Const ZLIB_FILEFUNC_SEEK_SET% = 0

Rem
Return codes for the compression/decompression functions. Negative
values are errors, positive values are used for special but normal events.
EndRem
Const Z_OK            = 0
Const Z_STREAM_END    = 1
Const Z_NEED_DICT     = 2
Const Z_ERRNO        = -1
Const Z_STREAM_ERROR = -2
Const Z_DATA_ERROR   = -3
Const Z_MEM_ERROR    = -4
Const Z_BUF_ERROR    = -5
Const Z_VERSION_ERROR = -6

Extern

Rem
Open a zip file for unzip, using the specified IO functions
End Rem
'Function unzOpen2:Byte Ptr(zipFileName$z, pzlib_filefunc_def:Byte Ptr)
Function bmx_zipstream_unzOpen2:Byte Ptr(zipFileName$z, bmxStream:TStream)

Rem
Give the current position in uncompressed data
End Rem
?bmxng
Function unztell:Long( file:Byte Ptr )
?Not bmxng
Function unztell:Int( file:Byte Ptr )
?

Rem
Read current file, returns number of bytes
End Rem
Function unzReadCurrentFile:Int( file:Byte Ptr, buffer:Byte Ptr, size:Int )

Rem
Gets info about the current file
End Rem
Function unzGetCurrentFileSize:Int( file:Byte Ptr )

Rem
Close unzip zip file
End Rem
Function unzClose( file:Byte Ptr )

Rem
Close current file
End Rem
Function unzCloseCurrentFile( file:Byte Ptr )

Rem
Opens the currently focused file
End Rem
Function unzOpenCurrentFile:Int( file:Byte Ptr )

Rem
Opens the currently focused file using a password
End Rem
Function unzOpenCurrentFilePassword:Int(file:Byte Ptr, password$z)

Rem
Return status of desired file and sets the unzipped focus to it
End Rem
Function unzLocateFile:Int( zipFilePtr:Byte Ptr, fileName$z, caseCheck:Int )

'Rem
'Set the current file offset
'End Rem
'Function unzSetOffset:Int(zipFilePtr:Byte Ptr, pos:Int)

'Rem
'Get the current file offset
'EndRem
'Function unzGetOffset:Int(zipFilePtr:Byte Ptr)

EndExtern



Type TZipStream Extends TStream
	Field innerStream:TStream
	Field unzfile:Byte Ptr
	Field size_:Int
	Field pos_:Int
	Field zipUrl$
	Global trash:Byte[] = New Byte[1024]
	
	Global gPasswordMap:TMap = New TMap
	
	Function GetCanonicalZipPath$(zipPath$)
		If zipPath.Find("::") < 0 Then
			' No protocol specified, we get the absolute path to be able to handle correctly the use of relative file pathes
			zipPath = RealPath(zipPath)
		EndIf
?Win32			
		zipPath = zipPath.ToLower().Replace("/", "\\")
?
		Return zipPath
	End Function
	
	Function SetPassword(zipPath$, password$)
		gPasswordMap.Insert(GetCanonicalZipPath(zipPath), password)
	End Function
	
	Function ClearPassword(zipPath$)
		gPasswordMap.Remove(GetCanonicalZipPath(zipPath))
	End Function
	
	Function GetPassword$(zipPath$)
		Return String(gPasswordMap.ValueForKey(GetCanonicalZipPath(zipPath)))
	End Function
	
	Method OpenCurrentFile_:Int()
		Local password$ = GetPassword(zipUrl)
		If password <> "" Then
			Return unzOpenCurrentFilePassword(unzfile, password)
		Else
			Return unzOpenCurrentFile(unzfile)
		EndIf
	End Method
	
	Method Open_:TZipStream(zipUrl$, fileUrl$, innerStream:TStream)		
		Self.zipUrl = zipUrl
		'DebugLog "Open_" + zipUrl + " # " + fileUrl
		Local filePath$ = fileUrl
		Local lastProtoPos% = filePath.FindLast("::")
		If lastProtoPos >= 0 Then
			' Remove the protocols, non meaningful here
			filePath = filePath[lastProtoPos+2..]
		EndIf

		unzfile = bmx_zipstream_unzOpen2(zipUrl, innerStream) ' NOTE: zipUrl not really useful here
		If unzfile = Null Then

			'DebugLog ("KO: " + zipUrl)
			Return Null
		Else
			If unzLocateFile(unzfile , filepath, 0) <> 0 Then
				'DebugLog ("unzLocateFile KO: " + filePath)
				Return Null
			EndIf
			Local password$ = GetPassword(zipUrl)
			'Local openRet%
			'If password <> "" Then
			'	openRet = unzOpenCurrentFilePassword(unzfile, password)
			'Else
			'	openRet = unzOpenCurrentFile(unzfile)
			'EndIf
			'If openRet = 0 Then
			If OpenCurrentFile_() = 0 Then
				'DebugLog ("OK: " + filePath)
				size_ = unzGetCurrentFileSize (unzfile)
				Self.innerStream = innerStream ' Just to keep the GC from collecting it
				Return Self
			Else
				Return Null
			EndIf
		EndIf
	End Method
	
	Function open_file_func:Byte Ptr(bmxStream:TStream, filename:Byte Ptr, Mode:Int)
		' Do nothing, stream already open
		'DebugLog "open_file_func" + Int(Byte Ptr(bmxStream))
		Return Byte Ptr(bmxStream) ' return dummy address
	End Function
	
?bmxng
	Function read_file_func:Long(bmxStream:TStream, stream:Byte Ptr, buf:Byte Ptr, size:Long)
?Not bmxng
	Function read_file_func:Int(bmxStream:TStream, stream:Byte Ptr, buf:Byte Ptr, size:Int)
?
		'DebugLog "read_file_func"
		Return bmxStream.Read(buf, size)
	End Function
	
?bmxng
	Function write_file_func:Long(bmxStream:TStream, stream:Byte Ptr, buf:Byte Ptr, size:Long)
?Not bmxng
	Function write_file_func:Int(bmxStream:TStream, stream:Byte Ptr, buf:Byte Ptr, size:Int)
?
		' Do nothing (not writeable)
		'DebugLog "write_file_func"
	End Function
	
?bmxng
	Function tell_file_func:Long(bmxStream:TStream, stream:Byte Ptr)
?Not bmxng
	Function tell_file_func:Int(bmxStream:TStream, stream:Byte Ptr)
?
		'DebugLog "tell_file_func"
		Return bmxStream.Pos()
	End Function
	
?bmxng
	Function seek_file_func:Long(bmxStream:TStream, stream:Byte Ptr, offset:Long, origin:Int)
?Not bmxng
	Function seek_file_func:Int(bmxStream:TStream, stream:Byte Ptr, offset:Int, origin:Int)
?
		'DebugLog "seek_file_func"
		'Print Int(Byte Ptr(bmxStream))'!!!
		Select origin
			Case ZLIB_FILEFUNC_SEEK_SET
				Return bmxStream.Seek(offset)
			Case ZLIB_FILEFUNC_SEEK_CUR
				Return bmxStream.Seek(bmxStream.Pos()+offset)
			Case ZLIB_FILEFUNC_SEEK_END
				Return bmxStream.Seek(offset, origin)'bmxStream.Size()-offset)
			Default
				RuntimeError("Invalid seek origin")
		End Select
		Return 0
	End Function
	
	Function close_file_func:Int(bmxStream:TStream, stream:Byte Ptr)
		'DebugLog "close_file_func"
		bmxStream.Close()
		Return 0
	End Function
	
	Function testerror_file_func:Int(bmxStream:TStream, stream:Byte Ptr)
		'DebugLog "testerror_file_func"
		'Return bmxStream.Eof() ' !!! ?
		Return 0
	End Function
		
?bmxng
	Method Pos:Long()
?Not bmxng
	Method Pos()
?
		'DebugLog "Pos " + unztell(unzfile)
		'Return unztell(unzfile)
		Return pos_
	End Method

?bmxng
	Method Size:Long()
?Not bmxng
	Method Size()
?
		'DebugLog "Size " + size_
		Return size_
	End Method

?bmxng
	Method Seek:Long( newPos:Long, whence:Int = SEEK_SET_ )
?Not bmxng
	Method Seek( newPos )
?
		If newPos <> pos_ Then							
			' WARN: this implementation of Seek is extremely inefficient 
			' (we reopen the file - if needed - and then read and discard the needed amount of bytes)
			' For this reason, the "zip" protocol adds a TBufferedStream on top of the TZipStream, in order to
			' amortize the cost of seeking (and of reading itself).
			' Thanks to the buffered stream, small files will be entirely loaded in memory, giving a fast access,
			' and big files will be loaded blocks by blocks, allowing a fast access without the downside of 
			' allocating big chunks of memory.
			If newPos < pos_ Then
				unzCloseCurrentFile(unzfile)	' Close the file
				OpenCurrentFile_()				' Reopen it
				pos_ = 0
			EndIf
			DiscardBytes_(newPos - pos_)
		EndIf
		Assert Pos() = newPos Else "TZipStream.Seek : Pos() should be " + newPos + " but is " + Pos()
		Return Pos()
	End Method
	
	Method DiscardBytes_(count%)
		Assert count >= 0 Else "TZipStream.DiscardBytes_ : negative count (" + count + ")"
		Repeat
			If count > trash.Length Then
				Read(trash, trash.Length)
				count :- trash.Length
			Else
				If count > 0 Then
					Read(trash, count)
				EndIf
				Exit
			EndIf			
		Forever
	End Method

?bmxng
	Method Read:Long( buf:Byte Ptr,count:Long )
?Not bmxng
	Method Read( buf:Byte Ptr, count )
?
		'DebugLog "Read"
		'DebugStop
		Assert unzfile Else "Attempt to read from closed stream"
		Local ret% = unzReadCurrentFile(unzfile , buf, count)
		'DebugLog "Read(post) " + ret
		CheckZlibError(ret)
		pos_ :+ ret
		Return ret
	End Method

?bmxng
	Method Write:Long( buf:Byte Ptr,count:Long )
?Not bmxng
	Method Write( buf:Byte Ptr, count )
?
		'DebugLog "Write"
		RuntimeError "Stream is not writeable"
		Return 0	
	End Method

	Method Flush()
		'DebugLog "Flush"
	End Method

	Method Close()
		'DebugLog "Close"
		If unzfile <> Null Then
			unzCloseCurrentFile(unzfile)
			unzClose(unzfile)
			unzfile = Null
		EndIf
	End Method
	
	
	Function CheckZLibError(code%)
		Local msg$
		Select code
			Case Z_ERRNO        	msg$ = "Zip file error"
			Case Z_STREAM_ERROR 	msg$ = "Zip stream error"
			Case Z_DATA_ERROR   	msg$ = "Zip data error"
			Case Z_MEM_ERROR    	msg$ = "Zip memory error"
			Case Z_BUF_ERROR    	msg$ = "Zip buffer error"
			Case Z_VERSION_ERROR 	msg$ = "Zip version error"
			Default	
				' No error, retrun silently
				Return
		End Select
		
		Local ex:TZipStreamReadException = New TZipStreamReadException
		ex.msg = msg
		Throw ex
	End Function
End Type



Type TZipStreamFactory Extends TStreamFactory
	Method CreateStream:TStream ( url:Object,proto$,path$,readable,writeable )
		'DebugStop

		If (proto="zip" Or proto="zip?") And writeable = False
			Local sepPos:Int = path.Find("//")
			If sepPos >= 0 Then
				Local zipUrl$ = path$[0..sepPos]
?Win32				
				zipUrl = zipUrl.Replace("/", "\\")
?
				Local innerStream:TStream = ReadStream(zipUrl)
				If innerStream <> Null Then
					Local filePath$ = path$[sepPos+2..]
					Local zipStream:TStream = (New TZipStream).Open_(zipUrl, filePath, innerStream)
					If zipStream <> Null Then
						Return CreateBufferedStream(zipStream)
					Else
						If proto="zip?" Then
							'Special protocol "zip?" means "attempt to find it in zip, or else attempt other protocols
							Return ReadStream(filePath)
						EndIf
					EndIf
				EndIf
			EndIf
		EndIf
	End Method
End Type

New TZipStreamFactory

Public

Rem
bbdoc: This exception is thrown  in the event of read error in a zip file.
EndRem
Type TZipStreamReadException Extends TStreamReadException
	Field msg$

	Method ToString$()
		Return msg
	End Method
End Type


Rem
bbdoc: Registers a password for a given zip file. Must be done before attempting to read any password protected zip file (or else, a TZipStreamReadException is thrown)
End Rem
Function SetZipStreamPassword(zipUrl$, password$)
	TZipStream.SetPassword(zipUrl, password)
End Function

Rem
bbdoc: Clears a password for a given zip file.
End Rem
Function ClearZipStreamPassword(zipUrl$)
	TZipStream.ClearPassword(zipUrl)
End Function

