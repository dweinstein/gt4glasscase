"
A reference to one tensor: name, dtype, shape, byte offsets, owning file. NEVER holds bytes (I5) -- browsing a 671B model must work on a laptop.
"
Class {
	#name : 'GcTensorRef',
	#superclass : 'Object',
	#instVars : [
		'name',
		'dtype',
		'shape',
		'beginOffset',
		'endOffset',
		'file'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcTensorRef class >> name: aName dtype: aDtype shape: aShape [
	^ self new
		name: aName;
		dtype: aDtype;
		shape: aShape;
		yourself
]

{ #category : 'accessing' }
GcTensorRef >> beginOffset [
	^ beginOffset
]

{ #category : 'accessing' }
GcTensorRef >> beginOffset: anInteger [
	beginOffset := anInteger
]

{ #category : 'querying' }
GcTensorRef >> byteSize [
	^ (beginOffset notNil and: [ endOffset notNil ])
		ifTrue: [ endOffset - beginOffset ]
		ifFalse: [ 0 ]
]

{ #category : 'accessing' }
GcTensorRef >> dtype [
	^ dtype
]

{ #category : 'accessing' }
GcTensorRef >> dtype: aSymbol [
	dtype := aSymbol
]

{ #category : 'accessing' }
GcTensorRef >> endOffset [
	^ endOffset
]

{ #category : 'accessing' }
GcTensorRef >> endOffset: anInteger [
	endOffset := anInteger
]

{ #category : 'accessing' }
GcTensorRef >> file [
	^ file
]

{ #category : 'accessing' }
GcTensorRef >> file: aFile [
	file := aFile
]

{ #category : 'querying' }
GcTensorRef >> layerIndex [
	^ self parsedName layerIndex
]

{ #category : 'querying' }
GcTensorRef >> module [
	^ self parsedName module
]

{ #category : 'accessing' }
GcTensorRef >> name [
	^ name
]

{ #category : 'accessing' }
GcTensorRef >> name: aString [
	name := aString
]

{ #category : 'querying' }
GcTensorRef >> parsedName [
	^ GcTensorName from: name
]

{ #category : 'printing' }
GcTensorRef >> printOn: aStream [
	aStream nextPutAll: 'GcTensorRef('.
	aStream nextPutAll: (name ifNil: [ '?' ]).
	aStream nextPut: $)
]

{ #category : 'accessing' }
GcTensorRef >> shape [
	^ shape
]

{ #category : 'accessing' }
GcTensorRef >> shape: aCollection [
	shape := aCollection
]
