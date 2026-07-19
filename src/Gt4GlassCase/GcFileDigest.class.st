"
One file in a repo revision: path, byte size, sha256 content hash, and the date first seen. The sha256 history across snapshots is what catches silent re-uploads -- a real supply-chain vector (I: observation/provenance is data).
"
Class {
	#name : 'GcFileDigest',
	#superclass : 'Object',
	#instVars : [
		'path',
		'size',
		'sha256',
		'firstSeen'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcFileDigest class >> path: aPath size: aSize sha256: aHash [
	^ self new
		path: aPath;
		size: aSize;
		sha256: aHash;
		yourself
]

{ #category : 'comparing' }
GcFileDigest >> = anObject [
	^ self class = anObject class
		and: [ path = anObject path and: [ sha256 = anObject sha256 ] ]
]

{ #category : 'accessing' }
GcFileDigest >> firstSeen [
	^ firstSeen
]

{ #category : 'accessing' }
GcFileDigest >> firstSeen: aDate [
	firstSeen := aDate
]

{ #category : 'comparing' }
GcFileDigest >> hash [
	^ path hash bitXor: sha256 hash
]

{ #category : 'accessing' }
GcFileDigest >> path [
	^ path
]

{ #category : 'accessing' }
GcFileDigest >> path: aString [
	path := aString
]

{ #category : 'printing' }
GcFileDigest >> printOn: aStream [
	aStream nextPutAll: 'GcFileDigest('.
	aStream nextPutAll: (path ifNil: [ '?' ]).
	aStream nextPut: $ .
	aStream nextPutAll: self shortSha256.
	aStream nextPut: $)
]

{ #category : 'accessing' }
GcFileDigest >> sha256 [
	^ sha256
]

{ #category : 'accessing' }
GcFileDigest >> sha256: aString [
	sha256 := aString
]

{ #category : 'accessing' }
GcFileDigest >> shortSha256 [
	^ sha256 ifNil: [ '' ] ifNotNil: [ :s | s copyFrom: 1 to: (s size min: 12) ]
]

{ #category : 'accessing' }
GcFileDigest >> size [
	^ size
]

{ #category : 'accessing' }
GcFileDigest >> size: anInteger [
	size := anInteger
]
