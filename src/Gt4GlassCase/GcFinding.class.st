"
A divergence that survived significance AND replication. Status is never confirmed, only not-yet-refuted-at-n-replications.
"
Class {
	#name : 'GcFinding',
	#superclass : 'Object',
	#instVars : [
		'divergence',
		'significance',
		'hypothesis',
		'replications',
		'status'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcFinding class >> status: aSymbol replications: anInteger [
	^ self new
		status: aSymbol;
		replications: anInteger;
		yourself
]

{ #category : 'printing' }
GcFinding >> printOn: aStream [
	aStream nextPutAll: 'GcFinding('; nextPutAll: (status ifNil: [ '?' ]) asString; nextPutAll: ')'
]

{ #category : 'accessing' }
GcFinding >> replications [
	"How many independent replications this finding has survived."
	^ replications
]

{ #category : 'accessing' }
GcFinding >> replications: anInteger [
	replications := anInteger
]

{ #category : 'accessing' }
GcFinding >> status [
	"The finding's current status symbol (e.g. #open, #replicated, #refuted). Never confirmed, only not-yet-refuted-at-n-replications."
	^ status
]

{ #category : 'accessing' }
GcFinding >> status: aSymbol [
	status := aSymbol
]
