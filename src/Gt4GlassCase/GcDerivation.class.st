"
The lineage of a group: the parent group it came from + the operation applied (#select:, #partitionBy:, #varyingAxis:, #sample:, ...) + parameters (e.g. the sample seed). Walk parent backwards to reconstruct any group from source (I3).
"
Class {
	#name : 'GcDerivation',
	#superclass : 'Object',
	#instVars : [
		'parent',
		'operation',
		'parameters'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcDerivation class >> parent: aGroup operation: aSymbol [
	^ self parent: aGroup operation: aSymbol parameters: Dictionary new
]

{ #category : 'instance creation' }
GcDerivation class >> parent: aGroup operation: aSymbol parameters: aDictionary [
	^ self new
		parent: aGroup;
		operation: aSymbol;
		parameters: aDictionary;
		yourself
]

{ #category : 'initialization' }
GcDerivation >> initialize [
	super initialize.
	parameters := Dictionary new
]

{ #category : 'testing' }
GcDerivation >> isRoot [
	^ parent isNil
]

{ #category : 'accessing' }
GcDerivation >> operation [
	^ operation
]

{ #category : 'accessing' }
GcDerivation >> operation: aSymbol [
	operation := aSymbol
]

{ #category : 'accessing' }
GcDerivation >> parameterAt: aKey [
	^ self parameters at: aKey ifAbsent: [ nil ]
]

{ #category : 'accessing' }
GcDerivation >> parameters [
	^ parameters ifNil: [ parameters := Dictionary new ]
]

{ #category : 'accessing' }
GcDerivation >> parameters: aDictionary [
	parameters := aDictionary
]

{ #category : 'accessing' }
GcDerivation >> parent [
	^ parent
]

{ #category : 'accessing' }
GcDerivation >> parent: aGroup [
	parent := aGroup
]

{ #category : 'printing' }
GcDerivation >> printOn: aStream [
	aStream nextPutAll: 'GcDerivation('.
	aStream nextPutAll: (operation ifNil: [ '?' ]) asString.
	parameters ifNotNil: [ parameters isEmpty ifFalse: [
		aStream space.
		aStream print: parameters ] ].
	aStream nextPut: $)
]
