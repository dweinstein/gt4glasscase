"
The comparison of two dated GcRepoManifest snapshots of one revision. Holds the baseline (earlier) and current (later) manifests and derives changed, added and removed files. Should always be clean; a non-empty drift means a silently re-uploaded file — the digest history is the only instrument that catches it.
"
Class {
	#name : 'GcManifestDrift',
	#superclass : 'Object',
	#instVars : [
		'baseline',
		'current'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcManifestDrift class >> baseline: aBaselineManifest current: aCurrentManifest [
	^ self new
		baseline: aBaselineManifest;
		current: aCurrentManifest;
		yourself
]

{ #category : 'comparing' }
GcManifestDrift >> addedFiles [
	"Current files with no matching path in the baseline."
	^ current files select: [ :each | (baseline fileNamed: each path) isNil ]
]

{ #category : 'accessing' }
GcManifestDrift >> baseline [
	^ baseline
]

{ #category : 'accessing' }
GcManifestDrift >> baseline: aManifest [
	baseline := aManifest
]

{ #category : 'comparing' }
GcManifestDrift >> changedFiles [
	"Current files whose path is known to the baseline but whose sha256 differs."
	^ current files select: [ :each |
		(baseline fileNamed: each path)
			ifNil: [ false ]
			ifNotNil: [ :baseFile | baseFile sha256 ~= each sha256 ] ]
]

{ #category : 'accessing' }
GcManifestDrift >> current [
	^ current
]

{ #category : 'accessing' }
GcManifestDrift >> current: aManifest [
	current := aManifest
]

{ #category : 'comparing' }
GcManifestDrift >> driftRows [
	"Array of row Arrays: {statusString. path. detailString. payload}, ordered changed, added, removed."
	| rows |
	rows := OrderedCollection new.
	self changedFiles do: [ :each |
		| baseFile |
		baseFile := baseline fileNamed: each path.
		rows add: {
			'changed'.
			each path.
			baseFile shortSha256 , ' -> ' , each shortSha256.
			each } ].
	self addedFiles do: [ :each |
		rows add: {
			'added'.
			each path.
			'not in baseline (' , each size printString , ' bytes)'.
			each } ].
	self removedFiles do: [ :each |
		rows add: {
			'removed'.
			each path.
			'gone from current'.
			each } ].
	^ rows asArray
]

{ #category : 'views' }
GcManifestDrift >> gtDriftFor: aView [
	<gtView>
	"Has any file in this repo changed since I first pulled it? Should always be empty; non-empty means a silent re-upload - a supply-chain red flag the digest history alone can catch."
	^ aView columnedList
		title: 'Drift';
		priority: 1;
		items: [ self isClean
			ifTrue: [ { {
				'clean'.
				'no drift: ' , current fileCount printString , ' files match baseline'.
				''.
				self } } ]
			ifFalse: [ self driftRows ] ];
		column: 'Status' text: [ :row | row at: 1 ];
		column: 'Path' text: [ :row | row at: 2 ];
		column: 'Detail' text: [ :row | row at: 3 ];
		send: [ :row | row at: 4 ]
]

{ #category : 'comparing' }
GcManifestDrift >> isClean [
	^ self changedFiles isEmpty
		and: [ self addedFiles isEmpty and: [ self removedFiles isEmpty ] ]
]

{ #category : 'printing' }
GcManifestDrift >> printOn: aStream [
	self isClean
		ifTrue: [ aStream nextPutAll: 'clean drift (' , current fileCount printString , ' files)' ]
		ifFalse: [ aStream nextPutAll:
			'DRIFT: ' , self changedFiles size printString , ' changed, '
				, self addedFiles size printString , ' added, '
				, self removedFiles size printString , ' removed' ]
]

{ #category : 'comparing' }
GcManifestDrift >> removedFiles [
	"Baseline files with no matching path in the current manifest."
	^ baseline files select: [ :each | (current fileNamed: each path) isNil ]
]
