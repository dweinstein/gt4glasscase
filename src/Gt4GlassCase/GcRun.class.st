"
One execution: artifact + backend + decoding params + timestamp + harness git SHA and image digest (I6). A silently rebuilt image manufactures fake findings, so the observation records itself.
"
Class {
	#name : 'GcRun',
	#superclass : 'Object',
	#instVars : [
		'artifact',
		'backend',
		'variant',
		'seed',
		'decodingParams',
		'timestamp',
		'harnessVersion'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcRun class >> artifact: anArtifact variant: aVariant seed: aSeed [
	^ self new
		artifact: anArtifact;
		variant: aVariant;
		seed: aSeed;
		yourself
]

{ #category : 'accessing' }
GcRun >> artifact [
	^ artifact
]

{ #category : 'accessing' }
GcRun >> artifact: anArtifact [
	artifact := anArtifact
]

{ #category : 'accessing' }
GcRun >> backend [
	^ backend
]

{ #category : 'accessing' }
GcRun >> backend: aBackend [
	backend := aBackend
]

{ #category : 'hypercube' }
GcRun >> coordinate [
	"The run's cell in the hypercube: the artifact's coordinate plus the seed axis."
	| coord |
	coord := artifact ifNil: [ GcCoordinate new ] ifNotNil: [ :a | a coordinate ].
	seed ifNotNil: [ coord at: #seed put: seed ].
	^ coord
]

{ #category : 'accessing' }
GcRun >> decodingParams [
	^ decodingParams
]

{ #category : 'accessing' }
GcRun >> decodingParams: aDictionary [
	decodingParams := aDictionary
]

{ #category : 'accessing' }
GcRun >> harnessVersion [
	^ harnessVersion
]

{ #category : 'accessing' }
GcRun >> harnessVersion: aVersion [
	harnessVersion := aVersion
]

{ #category : 'printing' }
GcRun >> printOn: aStream [
	aStream nextPutAll: 'GcRun('.
	aStream nextPutAll: (artifact ifNil: [ '?' ] ifNotNil: [ :a | a printString ]).
	aStream nextPutAll: ' seed='.
	aStream print: seed.
	aStream nextPut: $)
]

{ #category : 'accessing' }
GcRun >> seed [
	^ seed
]

{ #category : 'accessing' }
GcRun >> seed: anInteger [
	seed := anInteger
]

{ #category : 'accessing' }
GcRun >> timestamp [
	^ timestamp
]

{ #category : 'accessing' }
GcRun >> timestamp: aDateAndTime [
	timestamp := aDateAndTime
]

{ #category : 'accessing' }
GcRun >> variant [
	^ variant
]

{ #category : 'accessing' }
GcRun >> variant: aVariant [
	variant := aVariant
]
