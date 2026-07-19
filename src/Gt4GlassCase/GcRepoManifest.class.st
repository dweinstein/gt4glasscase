"
The full file listing (a GcFileDigest per file) of a GcModelRevision at a capture time. driftFrom: compares two snapshots of the SAME revision -- it should always be empty, and is alarming when it is not.
"
Class {
	#name : 'GcRepoManifest',
	#superclass : 'Object',
	#instVars : [
		'revision',
		'files',
		'capturedAt'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcRepoManifest class >> revision: aRevision [
	^ self new revision: aRevision; yourself
]

{ #category : 'building' }
GcRepoManifest >> addFile: aDigest [
	files add: aDigest.
	^ aDigest
]

{ #category : 'accessing' }
GcRepoManifest >> capturedAt [
	^ capturedAt
]

{ #category : 'accessing' }
GcRepoManifest >> capturedAt: aDateAndTime [
	capturedAt := aDateAndTime
]

{ #category : 'querying' }
GcRepoManifest >> driftFrom: anotherManifest [
	"Files whose content hash differs from (or is absent in) anotherManifest. For two snapshots of the same revision this should always be empty; a non-empty result is a silent re-upload."
	^ files select: [ :f |
		| prior |
		prior := anotherManifest fileNamed: f path.
		prior isNil or: [ prior sha256 ~= f sha256 ] ]
]

{ #category : 'comparing' }
GcRepoManifest >> driftReportFrom: aBaselineManifest [
	"Answer a first-class drift report comparing self (current) against aBaselineManifest (the earlier snapshot). Keep driftFrom: for the raw changed-file list."
	^ GcManifestDrift baseline: aBaselineManifest current: self
]

{ #category : 'querying' }
GcRepoManifest >> fileCount [
	^ files size
]

{ #category : 'querying' }
GcRepoManifest >> fileNamed: aPath [
	^ files detect: [ :f | f path = aPath ] ifNone: [ nil ]
]

{ #category : 'accessing' }
GcRepoManifest >> files [
	^ files
]

{ #category : 'views' }
GcRepoManifest >> gtFilesFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Files';
		priority: 1;
		items: [ files ];
		column: 'Path' text: [ :f | f path ];
		column: 'Size' text: [ :f | f size printString ];
		column: 'SHA-256' text: [ :f | f shortSha256 ]
]

{ #category : 'initialization' }
GcRepoManifest >> initialize [
	super initialize.
	files := OrderedCollection new
]

{ #category : 'printing' }
GcRepoManifest >> printOn: aStream [
	aStream nextPutAll: 'GcRepoManifest('.
	aStream print: self fileCount.
	aStream nextPutAll: ' files)'
]

{ #category : 'accessing' }
GcRepoManifest >> revision [
	^ revision
]

{ #category : 'accessing' }
GcRepoManifest >> revision: aRevision [
	revision := aRevision
]

{ #category : 'querying' }
GcRepoManifest >> totalSize [
	^ files inject: 0 into: [ :sum :f | sum + (f size ifNil: [ 0 ]) ]
]
