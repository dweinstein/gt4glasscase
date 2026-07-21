"
One step of KV-cached autoregressive generation, recorded for teaching the two regimes of inference. phase is #prefill (the single compute-bound pass over the whole prompt) or #decode (one memory-bound step processing exactly one new token while attending over the cache). tokenCount is how many tokens this step processed (prompt length for prefill, 1 for each decode), milliseconds its wall-time, seqLengthAfter the cache length after the step, and cacheBytes the cache size after the step. GcGeneration>>gtPhasesFor: renders these so the one big prefill step is visibly distinct from the many small decode steps.
"
Class {
	#name : 'GcPhaseStep',
	#superclass : 'Object',
	#instVars : [
		'phase',
		'tokenCount',
		'milliseconds',
		'seqLengthAfter',
		'cacheBytes'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'accessing' }
GcPhaseStep >> cacheBytes [
	^ cacheBytes
]

{ #category : 'accessing' }
GcPhaseStep >> cacheBytes: anInteger [
	cacheBytes := anInteger
]

{ #category : 'gt - views' }
GcPhaseStep >> gtDetailsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Details';
		priority: 10;
		items: [ {
			{ 'phase'. phase printString }.
			{ 'tokens processed'. tokenCount printString }.
			{ 'milliseconds'. milliseconds printString }.
			{ 'ms / token'. self msPerToken printString }.
			{ 'seq length after'. seqLengthAfter printString }.
			{ 'cache bytes after'. cacheBytes printString } } ];
		column: 'Property' text: [ :pair | pair first ];
		column: 'Value' text: [ :pair | pair second ]
]

{ #category : 'accessing' }
GcPhaseStep >> isPrefill [
	^ phase = #prefill
]

{ #category : 'accessing' }
GcPhaseStep >> milliseconds [
	^ milliseconds
]

{ #category : 'accessing' }
GcPhaseStep >> milliseconds: aNumber [
	milliseconds := aNumber
]

{ #category : 'accessing' }
GcPhaseStep >> msPerToken [
	"Wall-time per token processed in this step -- prefill amortizes over the whole prompt, decode is one token. A Float for readable display."
	tokenCount isNil ifTrue: [ ^ nil ].
	tokenCount = 0 ifTrue: [ ^ 0 ].
	^ (milliseconds / tokenCount) asFloat
]

{ #category : 'accessing' }
GcPhaseStep >> phase [
	^ phase
]

{ #category : 'accessing' }
GcPhaseStep >> phase: aSymbol [
	phase := aSymbol
]

{ #category : 'printing' }
GcPhaseStep >> printOn: aStream [
	aStream nextPutAll: phase printString; nextPutAll: ' ['; print: tokenCount; nextPutAll: ' tok, '; print: milliseconds; nextPutAll: ' ms]'
]

{ #category : 'accessing' }
GcPhaseStep >> seqLengthAfter [
	^ seqLengthAfter
]

{ #category : 'accessing' }
GcPhaseStep >> seqLengthAfter: anInteger [
	seqLengthAfter := anInteger
]

{ #category : 'accessing' }
GcPhaseStep >> tokenCount [
	^ tokenCount
]

{ #category : 'accessing' }
GcPhaseStep >> tokenCount: anInteger [
	tokenCount := anInteger
]
