"
ONE word probed across N model runs: per-model GcConceptProbeResult (perModelResults, an ordered collection of label -> GcConceptProbeResult associations), whether every model's top-1 token id AGREES, each model's matchedConcept, and the pairwise top-k Jaccard overlap between every pair of models' predicted token-id sets. Feeds GcBehavioralConceptComparison's Agreement and Top-k overlap views. View: gtPerModelFor: (Model | Top-1 | Prob | Matched concept; rows drill into their GcConceptProbeResult).
"
Class {
	#name : 'GcBehavioralWordComparison',
	#superclass : 'Object',
	#instVars : [
		'word',
		'perModelResults'
	],
	#category : 'Gt4GlassCase-Behavioral',
	#package : 'Gt4GlassCase',
	#tag : 'Behavioral'
}

{ #category : 'instance creation' }
GcBehavioralWordComparison class >> word: aWord perModelResults: assocs [
	^ self new setWord: aWord perModelResults: assocs
]

{ #category : 'computing' }
GcBehavioralWordComparison >> agree [
	"True when every model's top-1 token id is the same (nil never counts as agreement); false with fewer than 2 model results."
	| ids |
	self perModelResults size < 2 ifTrue: [ ^ false ].
	ids := self perModelResults collect: [ :a | self topIdFor: a key ].
	(ids anySatisfy: [ :i | i isNil ]) ifTrue: [ ^ false ].
	^ ids asSet size = 1
]

{ #category : 'gt views' }
GcBehavioralWordComparison >> gtPerModelFor: aView [
	<gtView>
	"Model | Top-1 | Prob | Matched concept. Rows drill into their GcConceptProbeResult."
	^ aView columnedList
		title: 'Per model';
		priority: 5;
		items: [ self perModelResults ];
		column: 'Model' text: [ :a | a key ];
		column: 'Top-1' text: [ :a | (self topTextFor: a key) ifNil: [ '-' ] ];
		column: 'Prob' text: [ :a | ((self topEntryFor: a key) ifNil: [ 0.0 ] ifNotNil: [ :e | e prob ]) printShowingDecimalPlaces: 3 ];
		column: 'Matched concept' text: [ :a | (self matchedConceptFor: a key) ifNil: [ '(none)' ] ifNotNil: [ :c | c name ] ];
		send: [ :a | a value ]
]

{ #category : 'computing' }
GcBehavioralWordComparison >> jaccardBetween: labelA and: labelB [
	| setA setB inter uni |
	setA := (self topKIdsFor: labelA) asSet.
	setB := (self topKIdsFor: labelB) asSet.
	(setA isEmpty and: [ setB isEmpty ]) ifTrue: [ ^ 1.0 ].
	inter := (setA & setB) size.
	uni := (setA | setB) size.
	^ uni = 0 ifTrue: [ 1.0 ] ifFalse: [ inter / uni asFloat ]
]

{ #category : 'accessing' }
GcBehavioralWordComparison >> labels [
	^ self perModelResults collect: [ :a | a key ]
]

{ #category : 'accessing' }
GcBehavioralWordComparison >> matchedConceptFor: aLabel [
	| r |
	r := self resultFor: aLabel.
	^ r ifNil: [ nil ] ifNotNil: [ r matchedConcept ]
]

{ #category : 'accessing' }
GcBehavioralWordComparison >> matchedConceptNames [
	"Distinct matched-concept names across all models, comma-joined; '(none)' when every model's top prediction names no known concept."
	| names |
	names := (self perModelResults collect: [ :a | self matchedConceptFor: a key ])
		reject: [ :c | c isNil ].
	names := (names collect: [ :c | c name ]) asSet asSortedCollection asOrderedCollection.
	^ names isEmpty
		ifTrue: [ '(none)' ]
		ifFalse: [ String streamContents: [ :s | names do: [ :n | s nextPutAll: n ] separatedBy: [ s nextPutAll: ', ' ] ] ]
]

{ #category : 'computing' }
GcBehavioralWordComparison >> pairwiseJaccardRows [
	"One row per unordered model pair: {labelA. labelB. jaccard}."
	| labelsArray rows |
	labelsArray := self labels asArray.
	rows := OrderedCollection new.
	1 to: labelsArray size do: [ :i |
		i + 1 to: labelsArray size do: [ :j |
			rows add: (Array
				with: (labelsArray at: i)
				with: (labelsArray at: j)
				with: (self jaccardBetween: (labelsArray at: i) and: (labelsArray at: j))) ] ].
	^ rows
]

{ #category : 'accessing' }
GcBehavioralWordComparison >> perModelResults [
	^ perModelResults ifNil: [ perModelResults := OrderedCollection new ]
]

{ #category : 'printing' }
GcBehavioralWordComparison >> printOn: aStream [
	aStream
		nextPutAll: self class name;
		nextPutAll: '(';
		nextPutAll: (self word ifNil: [ '?' ]);
		nextPutAll: ' agree=';
		print: self agree;
		nextPutAll: ')'
]

{ #category : 'accessing' }
GcBehavioralWordComparison >> resultFor: aLabel [
	^ (self perModelResults detect: [ :a | a key = aLabel ] ifNone: [ nil ]) ifNotNil: [ :a | a value ]
]

{ #category : 'private' }
GcBehavioralWordComparison >> setWord: aWord perModelResults: assocs [
	word := aWord.
	perModelResults := assocs asOrderedCollection
]

{ #category : 'accessing' }
GcBehavioralWordComparison >> topEntryFor: aLabel [
	| r |
	r := self resultFor: aLabel.
	^ r ifNil: [ nil ] ifNotNil: [ r topEntry ]
]

{ #category : 'accessing' }
GcBehavioralWordComparison >> topIdFor: aLabel [
	| e |
	e := self topEntryFor: aLabel.
	^ e ifNil: [ nil ] ifNotNil: [ e tokenId ]
]

{ #category : 'computing' }
GcBehavioralWordComparison >> topKIdsFor: aLabel [
	| r |
	r := self resultFor: aLabel.
	^ r ifNil: [ #() ] ifNotNil: [ r entriesOrEmpty collect: [ :e | e tokenId ] ]
]

{ #category : 'accessing' }
GcBehavioralWordComparison >> topTextFor: aLabel [
	| e |
	e := self topEntryFor: aLabel.
	^ e ifNil: [ nil ] ifNotNil: [ e tokenText ]
]

{ #category : 'accessing' }
GcBehavioralWordComparison >> word [
	^ word
]
