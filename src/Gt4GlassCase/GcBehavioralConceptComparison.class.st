"
Stage D across MULTIPLE models: the SAME words/template/concepts probed through N GPT-2-family checkpoints (models: an ordered collection of label -> zero-arg BLOCK opening the model lazily), answering where the models AGREE and DISAGREE about what a word IS. run executes SEQUENTIALLY (memory discipline: open one model, probe every word, unload it, THEN open the next -- at most one model's weights resident at a time), building one GcBehavioralModelRun per model. wordComparisons pairs each word's per-model results into a GcBehavioralWordComparison. Views: gtAgreementFor: (word | top-1 per model | agree? | matched concepts, disagreements sorted first; rows drill into their GcBehavioralWordComparison), gtTopKOverlapFor: (word | model pair | Jaccard), gtModelRunsFor: (label | dims | ms | mean top-1 prob; rows drill into their GcBehavioralModelRun). Class-side defaultGpt2Family seeds the three local GPT-2-family checkpoints (gpt2-124M / distilgpt2 / gpt2-medium, via GcGpt2Model openCheckpoint:) on the standard 7-word hypernym probe with the default template and Stage-A default concepts.
"
Class {
	#name : 'GcBehavioralConceptComparison',
	#superclass : 'Object',
	#instVars : [
		'words',
		'template',
		'models',
		'concepts',
		'runs'
	],
	#category : 'Gt4GlassCase-Behavioral',
	#package : 'Gt4GlassCase',
	#tag : 'Behavioral'
}

{ #category : 'instance creation' }
GcBehavioralConceptComparison class >> defaultGpt2Family [
	"The three GPT-2-family checkpoints (gpt2-124M, distilgpt2, gpt2-medium; all local, no network) on the standard 7-word hypernym probe with the default template and Stage-A default concepts. Cheap to build -- call run to execute the sequential forwards (gpt2-medium's forward alone takes ~18 minutes; see GcBehavioralConceptComparisonExamples)."
	| modelBlocks |
	modelBlocks := OrderedCollection new.
	modelBlocks
		add: 'gpt2-124M' -> [ GcGpt2Model openCheckpoint: 'gpt2' ];
		add: 'distilgpt2' -> [ GcGpt2Model openCheckpoint: 'distilgpt2' ];
		add: 'gpt2-medium' -> [ GcGpt2Model openCheckpoint: 'gpt2-medium' ];
		yourself.
	^ self
		words: #('dog' 'cat' 'king' 'France' 'red' 'apple' 'happy')
		template: GcConceptProbe defaultTemplate
		models: modelBlocks
]

{ #category : 'instance creation' }
GcBehavioralConceptComparison class >> words: aWords template: aTemplate models: modelAssocs [
	^ self new setWords: aWords template: aTemplate models: modelAssocs
]

{ #category : 'accessing' }
GcBehavioralConceptComparison >> concepts [
	^ concepts ifNil: [ concepts := GcConceptSpace defaultConcepts ]
]

{ #category : 'accessing' }
GcBehavioralConceptComparison >> concepts: aConceptsCollection [
	concepts := aConceptsCollection
]

{ #category : 'gt views' }
GcBehavioralConceptComparison >> gtAgreementFor: aView [
	<gtView>
	"Word | top-1 per model | agree? | matched concepts. Disagreements sort first. Rows drill into their GcBehavioralWordComparison."
	| list |
	list := aView columnedList
		title: 'Agreement';
		priority: 5;
		items: [ self wordComparisonsSortedByDisagreementFirst ].
	list column: 'Word' text: [ :c | c word ].
	self models do: [ :labelToBlock |
		| label |
		label := labelToBlock key.
		list column: label text: [ :c | (c topTextFor: label) ifNil: [ '-' ] ] ].
	list column: 'Agree?' text: [ :c | c agree ifTrue: [ 'yes' ] ifFalse: [ 'no' ] ].
	list column: 'Matched concepts' text: [ :c | c matchedConceptNames ].
	list send: [ :c | c ].
	^ list
]

{ #category : 'gt views' }
GcBehavioralConceptComparison >> gtModelRunsFor: aView [
	<gtView>
	"Label | dims | ms | mean top-1 prob. Rows drill into their GcBehavioralModelRun."
	^ aView columnedList
		title: 'Models';
		priority: 20;
		items: [ self runs ];
		column: 'Label' text: [ :r | r label ];
		column: 'Dims' text: [ :r | r dimsSummary ];
		column: 'ms' text: [ :r | r wallClockMs printString ];
		column: 'Mean top-1 prob' text: [ :r | r meanTopProb printShowingDecimalPlaces: 3 ];
		send: [ :r | r ]
]

{ #category : 'actions' }
GcBehavioralConceptComparison >> gtRunProbesActionFor: anAction [
	<gtAction>
	"Toolbar button to execute the probes when inspecting a not-yet-run comparison (e.g. straight from defaultGpt2Family). Guarded: a second click is a no-op. HONEST WARNING in the tooltip: the full gpt2 family loads each model sequentially and the image is single-threaded, so the UI freezes for the duration (~2 min for gpt2/distilgpt2 each, ~18 min for gpt2-medium's cold f64 decode). Fires the view update wish so the open Agreement/Overlap/Models views refresh in place with the results."
	^ anAction button
		tooltip: 'Run the probes now (no-op if already run). Freezes the UI while models load + probe sequentially -- minutes for small models, ~18 min if gpt2-medium is included.';
		priority: 5;
		icon: BrGlamorousVectorIcons play;
		action: [ :aButton |
			self isRun ifFalse: [ self run ].
			aButton phlow fireViewUpdateWish ]
]

{ #category : 'gt views' }
GcBehavioralConceptComparison >> gtTopKOverlapFor: aView [
	<gtView>
	"Pairwise top-k Jaccard overlap between every pair of models, per word. Rows drill into the word's GcBehavioralWordComparison."
	| list |
	list := aView columnedList
		title: 'Top-k overlap';
		priority: 8;
		items: [ self topKOverlapRows ].
	list column: 'Word' text: [ :r | r at: 1 ].
	list column: 'Model A' text: [ :r | r at: 2 ].
	list column: 'Model B' text: [ :r | r at: 3 ].
	list column: 'Jaccard' text: [ :r | (r at: 4) printShowingDecimalPlaces: 3 ].
	list send: [ :r | self wordComparisonNamed: (r at: 1) ].
	^ list
]

{ #category : 'testing' }
GcBehavioralConceptComparison >> isRun [
	"Whether the probes have been executed. runs is initialized to an empty collection, so emptiness -- not nil -- is the test."
	^ runs notNil and: [ runs notEmpty ]
]

{ #category : 'accessing' }
GcBehavioralConceptComparison >> models [
	^ models ifNil: [ models := OrderedCollection new ]
]

{ #category : 'printing' }
GcBehavioralConceptComparison >> printOn: aStream [
	aStream
		nextPutAll: self class name;
		nextPutAll: '(';
		print: self words size;
		nextPutAll: ' words x ';
		print: self models size;
		nextPutAll: ' models)'
]

{ #category : 'actions' }
GcBehavioralConceptComparison >> run [
	"SEQUENTIAL per memory discipline: open one model, probe every word, unload it, THEN open the next -- at most one model's weights resident at a time. Builds one GcBehavioralModelRun per model (dims summary read off the model before it is unloaded; the model itself is never retained)."
	| collected |
	collected := OrderedCollection new.
	self models do: [ :labelToBlock |
		| label modelBlock model results ms |
		label := labelToBlock key.
		modelBlock := labelToBlock value.
		model := modelBlock value.
		(model respondsTo: #useBlasBackendIfAvailable) ifTrue: [ model useBlasBackendIfAvailable ].
		ms := [
			results := self words collect: [ :w |
				| r |
				r := (GcConceptProbe word: w template: self template model: model) run.
				r concepts: self concepts.
				r ] ] millisecondsToRun.
		collected add: (GcBehavioralModelRun label: label results: results wallClockMs: ms model: model).
		(model respondsTo: #unloadWeights) ifTrue: [ model unloadWeights ] ].
	runs := collected.
	^ runs
]

{ #category : 'accessing' }
GcBehavioralConceptComparison >> runs [
	^ runs ifNil: [ runs := OrderedCollection new ]
]

{ #category : 'private' }
GcBehavioralConceptComparison >> setWords: aWords template: aTemplate models: modelAssocs [
	words := aWords asOrderedCollection.
	template := aTemplate.
	models := modelAssocs asOrderedCollection.
	concepts := GcConceptSpace defaultConcepts.
	runs := OrderedCollection new
]

{ #category : 'accessing' }
GcBehavioralConceptComparison >> template [
	^ template
]

{ #category : 'computing' }
GcBehavioralConceptComparison >> topKOverlapRows [
	"One row per word per unordered model pair: {word. labelA. labelB. jaccard}."
	| rows |
	rows := OrderedCollection new.
	self wordComparisons do: [ :c |
		c pairwiseJaccardRows do: [ :pr |
			rows add: (Array with: c word with: (pr at: 1) with: (pr at: 2) with: (pr at: 3)) ] ].
	^ rows
]

{ #category : 'computing' }
GcBehavioralConceptComparison >> wordComparisonNamed: aWord [
	^ self wordComparisons detect: [ :c | c word = aWord ] ifNone: [ nil ]
]

{ #category : 'computing' }
GcBehavioralConceptComparison >> wordComparisons [
	"One GcBehavioralWordComparison per word, pairing each model run's same-index result (runs and words share index order established by run)."
	| comps |
	self runs isEmpty ifTrue: [ ^ OrderedCollection new ].
	comps := OrderedCollection new.
	self words doWithIndex: [ :w :idx |
		| assocs |
		assocs := self runs collect: [ :r | r label -> (r results at: idx) ].
		comps add: (GcBehavioralWordComparison word: w perModelResults: assocs) ].
	^ comps
]

{ #category : 'computing' }
GcBehavioralConceptComparison >> wordComparisonsSortedByDisagreementFirst [
	"Word comparisons with disagreements (agree = false) first."
	^ (self wordComparisons asSortedCollection: [ :a :b |
		(a agree ifTrue: [ 1 ] ifFalse: [ 0 ]) <= (b agree ifTrue: [ 1 ] ifFalse: [ 0 ]) ]) asOrderedCollection
]

{ #category : 'accessing' }
GcBehavioralConceptComparison >> words [
	^ words ifNil: [ words := OrderedCollection new ]
]
