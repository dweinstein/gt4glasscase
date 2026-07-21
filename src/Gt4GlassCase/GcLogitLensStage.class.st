"
One depth of a GcLogitLens: the top-k GcLogitLensEntry decodings of the final-position residual stream at this depth (depth 0 = embeddings, depth i = block i-1 output). logits is the full Float64Array of vocab logits at this depth.
"
Class {
	#name : 'GcLogitLensStage',
	#superclass : 'Object',
	#instVars : [
		'depth',
		'label',
		'entries',
		'logits'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'accessing' }
GcLogitLensStage >> depth [
	^ depth
]

{ #category : 'accessing' }
GcLogitLensStage >> depth: anInteger [
	depth := anInteger
]

{ #category : 'accessing' }
GcLogitLensStage >> entries [
	^ entries
]

{ #category : 'accessing' }
GcLogitLensStage >> entries: aCollection [
	entries := aCollection
]

{ #category : 'gt - views' }
GcLogitLensStage >> gtEntriesFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Top tokens';
		priority: 10;
		items: [ self entries ];
		column: 'Rank' text: [ :e | e rank printString ];
		column: 'Token' text: [ :e | e displayToken ];
		column: 'Id' text: [ :e | e tokenId printString ];
		column: 'Logit' text: [ :e | e logitString ];
		column: 'Prob' text: [ :e | e probString ]
]

{ #category : 'accessing' }
GcLogitLensStage >> label [
	^ label
]

{ #category : 'accessing' }
GcLogitLensStage >> label: aString [
	label := aString
]

{ #category : 'accessing' }
GcLogitLensStage >> logits [
	^ logits
]

{ #category : 'accessing' }
GcLogitLensStage >> logits: aFloat64Array [
	logits := aFloat64Array
]

{ #category : 'printing' }
GcLogitLensStage >> printOn: aStream [
	super printOn: aStream.
	aStream nextPutAll: ' '; nextPutAll: (label ifNil: [ '' ]).
	entries ifNotNil: [ aStream nextPutAll: ' top='; nextPutAll: self topEntry displayToken ]
]

{ #category : 'accessing' }
GcLogitLensStage >> topEntry [
	"The most likely token at this depth."
	^ entries first
]

{ #category : 'printing' }
GcLogitLensStage >> topTokensSummary [
	"The bracketed top-k decoded tokens, most likely first."
	^ String streamContents: [ :s |
		entries
			do: [ :e | s nextPutAll: e displayToken ]
			separatedBy: [ s nextPutAll: ' ' ] ]
]
