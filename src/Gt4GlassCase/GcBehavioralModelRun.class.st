"
One model's behavioral probe run: a label, the per-word GcConceptProbeResults, the wall-clock milliseconds the probes took, and a small dims summary (numLayers/hiddenSize/numHeads/vocabSize) read off the model AT CONSTRUCTION TIME -- the model itself is NEVER retained (memory discipline: its weights get unloaded and the next model opened right after, in GcBehavioralConceptComparison>>run). meanTopProb averages each result's top-1 probability. View: gtResultsFor: (word | top-1 | prob | matched concept, reusing the GcBehavioralConceptSpace gtProbesFor: idiom; rows drill into their GcConceptProbeResult).
"
Class {
	#name : 'GcBehavioralModelRun',
	#superclass : 'Object',
	#instVars : [
		'label',
		'results',
		'wallClockMs',
		'numLayers',
		'hiddenSize',
		'numHeads',
		'vocabSize'
	],
	#category : 'Gt4GlassCase-Behavioral',
	#package : 'Gt4GlassCase',
	#tag : 'Behavioral'
}

{ #category : 'instance creation' }
GcBehavioralModelRun class >> label: aLabel results: aResults wallClockMs: ms model: aModel [
	^ self new setLabel: aLabel results: aResults wallClockMs: ms model: aModel
]

{ #category : 'accessing' }
GcBehavioralModelRun >> dimsSummary [
	"A small formatted dims summary, e.g. '6L/768H/12heads'; fields the model didn't answer (e.g. a stub) print as '?' or are omitted."
	^ String streamContents: [ :s |
		s nextPutAll: (self numLayers ifNil: [ '?' ] ifNotNil: [ :n | n printString ]); nextPutAll: 'L'.
		self hiddenSize ifNotNil: [ :h | s nextPutAll: '/'; nextPutAll: h printString; nextPutAll: 'H' ].
		self numHeads ifNotNil: [ :h | s nextPutAll: '/'; nextPutAll: h printString; nextPutAll: 'heads' ] ]
]

{ #category : 'gt views' }
GcBehavioralModelRun >> gtResultsFor: aView [
	<gtView>
	"Word | top-1 | prob | matched concept, reusing the GcBehavioralConceptSpace gtProbesFor: idiom. Rows drill into their GcConceptProbeResult."
	^ aView columnedList
		title: 'Results';
		priority: 5;
		items: [ self results ];
		column: 'Word' text: [ :r | r word ];
		column: 'Top-1' text: [ :r | r topText ];
		column: 'Prob' text: [ :r | (r topEntry ifNil: [ 0.0 ] ifNotNil: [ :e | e prob ]) printShowingDecimalPlaces: 3 ];
		column: 'Matched concept' text: [ :r | r matchedConcept ifNil: [ '(none)' ] ifNotNil: [ :c | c name ] ];
		send: [ :r | r ]
]

{ #category : 'accessing' }
GcBehavioralModelRun >> hiddenSize [
	^ hiddenSize
]

{ #category : 'accessing' }
GcBehavioralModelRun >> label [
	^ label
]

{ #category : 'computing' }
GcBehavioralModelRun >> meanTopProb [
	"The mean of every result's top-1 predicted-token probability (0.0 for a result with no entries)."
	| probs |
	probs := self results collect: [ :r | r topEntry ifNil: [ 0.0 ] ifNotNil: [ :e | e prob ] ].
	probs isEmpty ifTrue: [ ^ 0.0 ].
	^ (probs inject: 0.0 into: [ :sum :p | sum + p ]) / probs size asFloat
]

{ #category : 'accessing' }
GcBehavioralModelRun >> numHeads [
	^ numHeads
]

{ #category : 'accessing' }
GcBehavioralModelRun >> numLayers [
	^ numLayers
]

{ #category : 'printing' }
GcBehavioralModelRun >> printOn: aStream [
	aStream
		nextPutAll: self class name;
		nextPutAll: '(';
		nextPutAll: (self label ifNil: [ '?' ]);
		nextPutAll: ' ';
		print: self results size;
		nextPutAll: ' words, ';
		print: self wallClockMs;
		nextPutAll: 'ms)'
]

{ #category : 'accessing' }
GcBehavioralModelRun >> results [
	^ results ifNil: [ results := OrderedCollection new ]
]

{ #category : 'private' }
GcBehavioralModelRun >> setLabel: aLabel results: aResults wallClockMs: ms model: aModel [
	label := aLabel.
	results := aResults asOrderedCollection.
	wallClockMs := ms.
	numLayers := (aModel respondsTo: #numLayers) ifTrue: [ aModel numLayers ] ifFalse: [ nil ].
	hiddenSize := (aModel respondsTo: #hiddenSize) ifTrue: [ aModel hiddenSize ] ifFalse: [ nil ].
	numHeads := (aModel respondsTo: #numHeads) ifTrue: [ aModel numHeads ] ifFalse: [ nil ].
	vocabSize := (aModel respondsTo: #vocabSize) ifTrue: [ aModel vocabSize ] ifFalse: [ nil ]
]

{ #category : 'accessing' }
GcBehavioralModelRun >> vocabSize [
	^ vocabSize
]

{ #category : 'accessing' }
GcBehavioralModelRun >> wallClockMs [
	^ wallClockMs
]
