"
A materialized instance of a revision at a given precision, format and location (revision + precision + format + location). precision is a first-class typed field, never a string in a dict (I4) -- it is a hypercube axis value. format is #safetensors / #gguf / #mlx; location is a path or URL.
"
Class {
	#name : 'GcModelArtifact',
	#superclass : 'Object',
	#instVars : [
		'revision',
		'precision',
		'format',
		'location'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcModelArtifact class >> revision: aRevision precision: aPrecision [
	^ self revision: aRevision precision: aPrecision format: #safetensors location: nil
]

{ #category : 'instance creation' }
GcModelArtifact class >> revision: aRevision precision: aPrecision format: aFormat location: aLocation [
	^ self new
		revision: aRevision;
		precision: aPrecision;
		format: aFormat;
		location: aLocation;
		yourself
]

{ #category : 'hypercube' }
GcModelArtifact >> coordinate [
	"This artifact's position along the axes it fixes. Behavioral observations extend this with probe/variant/seed/etc."
	^ GcCoordinate new
		at: #revision put: (revision ifNotNil: [ :r | r id ]);
		at: #precision put: precision;
		yourself
]

{ #category : 'accessing' }
GcModelArtifact >> detailFacets [
	^ {
		'Revision' -> (revision ifNil: [ '?' ] ifNotNil: [ :r | r id ]).
		'Precision' -> precision asString.
		'Format' -> format asString.
		'Location' -> (location ifNil: [ '' ] ifNotNil: [ :l | l asString ]) }
]

{ #category : 'accessing' }
GcModelArtifact >> format [
	^ format
]

{ #category : 'accessing' }
GcModelArtifact >> format: aSymbol [
	format := aSymbol
]

{ #category : 'views' }
GcModelArtifact >> gtDetailsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Details';
		priority: 1;
		items: [ self detailFacets ];
		column: 'Facet' text: [ :each | each key ];
		column: 'Value' text: [ :each | each value ]
]

{ #category : 'accessing' }
GcModelArtifact >> location [
	^ location
]

{ #category : 'accessing' }
GcModelArtifact >> location: anObject [
	location := anObject
]

{ #category : 'accessing' }
GcModelArtifact >> precision [
	^ precision
]

{ #category : 'accessing' }
GcModelArtifact >> precision: aSymbol [
	precision := aSymbol
]

{ #category : 'printing' }
GcModelArtifact >> printOn: aStream [
	aStream nextPutAll: 'GcModelArtifact('.
	aStream nextPutAll: (revision ifNil: [ '?' ] ifNotNil: [ :r | r id ]).
	aStream nextPutAll: ' @ '.
	aStream nextPutAll: precision asString.
	aStream nextPut: $)
]

{ #category : 'accessing' }
GcModelArtifact >> revision [
	^ revision
]

{ #category : 'accessing' }
GcModelArtifact >> revision: aRevision [
	revision := aRevision
]
