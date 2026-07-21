"
A bytes port backed by a LOCAL FILE, implementing the same transport-free port as GcInMemoryBytesProvider / GcHuggingFaceBytesProvider: provideBytesFrom:to: (absolute, inclusive, 0-based byte range) and provideByteDataOffset. It SEEKS to the requested offset and reads only the requested span, so reading one tensor does not read the whole file -- lets GcSafetensorsFile load real safetensors weights from disk. provideByteDataOffset reads the 8-byte little-endian uint64 length prefix of a safetensors file and returns 8 + headerLength.
"
Class {
	#name : 'GcLocalFileBytesProvider',
	#superclass : 'Object',
	#instVars : [
		'path'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcLocalFileBytesProvider class >> forPath: aStringOrFileReference [
	"Build a local-file bytes port for a FileReference or path String."
	^ self new path: aStringOrFileReference; yourself
]

{ #category : 'accessing' }
GcLocalFileBytesProvider >> path [
	^ path
]

{ #category : 'accessing' }
GcLocalFileBytesProvider >> path: aStringOrFileReference [
	path := aStringOrFileReference asFileReference
]

{ #category : 'reading' }
GcLocalFileBytesProvider >> provideByteDataOffset [
	"Absolute offset where tensor data begins for a real on-disk safetensors file: 8 (the length prefix) + the header length. Reads the leading 8-byte little-endian uint64 length prefix."
	| lenBytes headerLen |
	lenBytes := self provideBytesFrom: 0 to: 7.
	headerLen := 0.
	0 to: 7 do: [ :i | headerLen := headerLen + ((lenBytes at: i + 1) bitShift: 8 * i) ].
	^ 8 + headerLen
]

{ #category : 'reading' }
GcLocalFileBytesProvider >> provideBytesFrom: startAbs to: endAbs [
	"Absolute, inclusive byte range [startAbs, endAbs] (0-based) read from the local file by SEEKING to startAbs and reading only (endAbs - startAbs + 1) bytes -- never the whole file. Transport-free counterpart of GcInMemoryBytesProvider>>provideBytesFrom:to:."
	| count stream |
	count := endAbs - startAbs + 1.
	stream := path binaryReadStream.
	^ [ stream position: startAbs. stream next: count ] ensure: [ stream close ]
]
