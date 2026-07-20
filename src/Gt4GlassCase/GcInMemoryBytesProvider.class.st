"
An in-image bytes port backed by a ByteArray already resident in memory. Implements the same provideBytesFrom:to: / provideByteDataOffset port as GcHuggingFaceBytesProvider, but transport-free -- for hermetic tests and embedded fixtures that decode REAL tensor bytes (through GcTensorRef>>sampleSlice / sliceFromElement:count:) without any network. Absolute offsets index into `bytes` from 0; dataOffset is where tensor data begins (0 when the buffer already starts at the data region).
"
Class {
	#name : 'GcInMemoryBytesProvider',
	#superclass : 'Object',
	#instVars : [
		'bytes',
		'dataOffset'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcInMemoryBytesProvider class >> bytes: aByteArray dataOffset: anInteger [
	^ self new bytes: aByteArray; dataOffset: anInteger; yourself
]

{ #category : 'accessing' }
GcInMemoryBytesProvider >> bytes [
	^ bytes
]

{ #category : 'accessing' }
GcInMemoryBytesProvider >> bytes: aByteArray [
	bytes := aByteArray
]

{ #category : 'accessing' }
GcInMemoryBytesProvider >> dataOffset [
	^ dataOffset ifNil: [ 0 ]
]

{ #category : 'accessing' }
GcInMemoryBytesProvider >> dataOffset: anInteger [
	dataOffset := anInteger
]

{ #category : 'printing' }
GcInMemoryBytesProvider >> printOn: aStream [
	aStream nextPutAll: 'in-memory bytes ('; print: (bytes ifNil: [ 0 ] ifNotNil: [ :b | b size ]); nextPutAll: ' B)'
]

{ #category : 'bytes port' }
GcInMemoryBytesProvider >> provideByteDataOffset [
	"Absolute offset where tensor data begins; 0 when the buffer already starts at the data region."
	^ self dataOffset
]

{ #category : 'bytes port' }
GcInMemoryBytesProvider >> provideBytesFrom: startAbs to: endAbs [
	"Absolute, inclusive byte range copied out of the in-memory buffer (0-based absolute offsets). Transport-free counterpart of GcHuggingFaceBytesProvider>>provideBytesFrom:to:."
	^ bytes copyFrom: startAbs + 1 to: endAbs + 1
]
