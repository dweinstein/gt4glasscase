"
One safetensors shard. Lazy header parse: 8-byte little-endian length + JSON header (tensor name -> dtype/shape/offsets), then the raw buffer. Holds refs, never the bytes (I5).
"
Class {
	#name : 'GcSafetensorsFile',
	#superclass : 'Object',
	#instVars : [
		'path',
		'header',
		'tensors',
		'byteDataOffset'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'parsing' }
GcSafetensorsFile >> buildTensors [
	tensors := OrderedCollection new.
	header keysAndValuesDo: [ :tensorName :info |
		tensorName = '__metadata__' ifFalse: [
			| offsets ref |
			offsets := info at: 'data_offsets'.
			ref := GcTensorRef
				name: tensorName
				dtype: (info at: 'dtype') asLowercase asSymbol
				shape: (info at: 'shape') asArray.
			ref beginOffset: (offsets at: 1).
			ref endOffset: (offsets at: 2).
			ref file: self.
			tensors add: ref ] ]
]

{ #category : 'accessing' }
GcSafetensorsFile >> byteDataOffset [
	^ byteDataOffset
]

{ #category : 'accessing' }
GcSafetensorsFile >> byteDataOffset: anInteger [
	byteDataOffset := anInteger
]

{ #category : 'accessing' }
GcSafetensorsFile >> header [
	^ header
]

{ #category : 'parsing' }
GcSafetensorsFile >> parseHeaderDictionary: aDictionary [
	"Build GcTensorRefs from an already-parsed safetensors header (a plain Dictionary of name -> {dtype, shape, data_offsets}). Generic: no coupling to any transport."
	header := aDictionary.
	self buildTensors.
	^ self
]

{ #category : 'parsing' }
GcSafetensorsFile >> parseHeaderString: aJsonString [
	^ self parseHeaderDictionary: (STONJSON fromString: aJsonString)
]

{ #category : 'accessing' }
GcSafetensorsFile >> path [
	^ path
]

{ #category : 'accessing' }
GcSafetensorsFile >> path: aString [
	path := aString
]

{ #category : 'printing' }
GcSafetensorsFile >> printOn: aStream [
	aStream nextPutAll: 'GcSafetensorsFile('.
	aStream nextPutAll: (path ifNil: [ '?' ]).
	aStream nextPutAll: ', '.
	aStream print: self tensorCount.
	aStream nextPutAll: ' tensors)'
]

{ #category : 'querying' }
GcSafetensorsFile >> tensorCount [
	^ self tensors size
]

{ #category : 'converting' }
GcSafetensorsFile >> tensorGroup [
	"A GcTensorGroup wrapping every tensor in this file -- ready for partitionBy:, statistics, etc."
	^ GcTensorGroup withAll: self tensors
]

{ #category : 'accessing' }
GcSafetensorsFile >> tensors [
	^ tensors ifNil: [ tensors := OrderedCollection new ]
]

{ #category : 'querying' }
GcSafetensorsFile >> totalTensorBytes [
	^ self tensors inject: 0 into: [ :sum :t | sum + t byteSize ]
]
