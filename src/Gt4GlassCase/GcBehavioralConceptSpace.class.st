"
Stage D: a set of `words` probed through ONE GcGpt2Model with a shared hypernym `template`, holding one GcConceptProbeResult per word (`results`) and the `concepts` (GcConcepts) their top predictions are matched against. Builds the model's concept relations from what it actually PREDICTS (forward pass + logit lens) so they can be compared to the Stage-B embedding-cosine graph. probeAll runs one short forward per word (fresh KV cache each; leaves the shared model clean). Class-side defaultGpt2 seeds ~7 words spanning the Stage-A concept set (dog, cat, king, France, red, apple, happy) over GcGpt2Model default, with the Stage-A concepts palette-colored so graph nodes match the embedding views.

Views: gtProbesFor: (word | top-3 completions | matched concept), gtBehavioralGraphFor: (a Mondrian graph of word->matchedConcept edges, reusing GcConceptSpace's circle-layout + below-label node idiom; unmatched words float as isolated light nodes), and gtVsEmbeddingFor: (word-by-word, the concept the top prediction NAMES beside the nearest Stage-B centroid concept + cosine + agree?). `embeddingSpace` is the Stage-B GcConceptSpace for that comparison, built lazily on first view-open (settable, e.g. to an already-built space). `results` is settable so the graph/table can be exercised hermetically on synthetic GcConceptProbeResults with NO model.
"
Class {
	#name : 'GcBehavioralConceptSpace',
	#superclass : 'Object',
	#instVars : [
		'words',
		'template',
		'model',
		'concepts',
		'results',
		'embeddingSpace'
	],
	#category : 'Gt4GlassCase-Behavioral',
	#package : 'Gt4GlassCase',
	#tag : 'Behavioral'
}

{ #category : 'instance creation' }
GcBehavioralConceptSpace class >> defaultGpt2 [
	"~7 words spanning the Stage-A concept set, probed through the shared default GPT-2 with the default hypernym template. Concepts are the Stage-A defaults, colored with the shared palette so graph nodes match the embedding views. Cheap to build; call probeAll to run the forwards."
	| concepts |
	concepts := GcConceptSpace defaultConcepts.
	concepts withIndexDo: [ :c :i | c color: (GcConceptSpace colorAt: i) ].
	^ self
		words: #('dog' 'cat' 'king' 'France' 'red' 'apple' 'happy')
		template: GcConceptProbe defaultTemplate
		model: GcGpt2Model default
		concepts: concepts
]

{ #category : 'instance creation' }
GcBehavioralConceptSpace class >> words: aWords template: aTemplate model: aModel concepts: aConcepts [
	^ self new setWords: aWords template: aTemplate model: aModel concepts: aConcepts
]

{ #category : 'embedding comparison' }
GcBehavioralConceptSpace >> agreementLabelFor: aRow [
	"'yes' when the behavioral matched concept equals the embedding-nearest concept, 'no' when both are known but differ, '-' when either is missing."
	| beh emb |
	beh := aRow at: 2.
	emb := aRow at: 3.
	(beh isNil or: [ emb isNil ]) ifTrue: [ ^ '-' ].
	^ beh name = emb key name ifTrue: [ 'yes' ] ifFalse: [ 'no' ]
]

{ #category : 'accessing' }
GcBehavioralConceptSpace >> concepts [
	^ concepts ifNil: [ #() ]
]

{ #category : 'graph' }
GcBehavioralConceptSpace >> edgeElement [
	"A word->concept edge line."
	^ BlLineElement new
		zIndex: -1;
		border: (BlBorder paint: ((Color r: 0.2 g: 0.3 b: 0.5) alpha: 0.6) width: 2.0);
		yourself
]

{ #category : 'graph' }
GcBehavioralConceptSpace >> edgePairs [
	"One (result -> matchedConcept) association per probed word whose top prediction names a concept."
	^ self resultsOrEmpty
		select: [ :r | r matchedConcept notNil ]
		thenCollect: [ :r | r -> r matchedConcept ]
]

{ #category : 'embedding comparison' }
GcBehavioralConceptSpace >> embeddingComparisonRows [
	"One row per probed word: { result. behavioralConcept-or-nil. (embeddingConcept -> cosine)-or-nil }."
	^ self resultsOrEmpty collect: [ :r |
		{ r. r matchedConcept. (self embeddingNearestConceptFor: r) } ]
]

{ #category : 'embedding comparison' }
GcBehavioralConceptSpace >> embeddingNearestConceptFor: aResult [
	"The (concept -> cosine) whose Stage-B centroid is nearest to the probed word's leading-space embedding, or nil when the word is not in the embedding space."
	| es vec best bestCos |
	es := self embeddingSpace.
	vec := es wordVectorForWord: (' ' , aResult word).
	vec ifNil: [ ^ nil ].
	best := nil.
	bestCos := -2.0.
	es concepts do: [ :c |
		| cs |
		cs := (es centroidFor: c) cosineTo: vec.
		cs > bestCos ifTrue: [ bestCos := cs. best := c ] ].
	^ best ifNil: [ nil ] ifNotNil: [ best -> bestCos ]
]

{ #category : 'embedding comparison' }
GcBehavioralConceptSpace >> embeddingSpace [
	"The Stage-B embedding-cosine space used for the behavior-vs-geometry comparison, built lazily on first use (loads the local gpt2 embedding model; fresh concepts, so nothing shared is mutated)."
	^ embeddingSpace ifNil: [ embeddingSpace := GcConceptSpace defaultGpt2 ]
]

{ #category : 'embedding comparison' }
GcBehavioralConceptSpace >> embeddingSpace: aConceptSpace [
	embeddingSpace := aConceptSpace
]

{ #category : 'gt - views' }
GcBehavioralConceptSpace >> gtBehavioralGraphFor: aView [
	<gtView>
	"The behavioral relationship graph, built from what the model PREDICTS (word->matchedConcept), for side-by-side comparison with the Stage-B embedding-cosine graph."
	^ aView mondrian
		title: 'Behavioral graph';
		priority: 10;
		painting: [ :mondrian | self paintBehavioralGraphOn: mondrian ]
]

{ #category : 'gt - views' }
GcBehavioralConceptSpace >> gtProbesFor: aView [
	<gtView>
	"Word | top-3 predicted completions | matched concept. Each row drills into its GcConceptProbeResult."
	^ aView columnedList
		title: 'Probes';
		priority: 5;
		items: [ self resultsOrEmpty ];
		column: 'Word' text: [ :r | r word ];
		column: 'Top-3 completions' text: [ :r | r topTokensStringUpTo: 3 ];
		column: 'Matched concept' text: [ :r | r matchedConcept ifNil: [ '(none)' ] ifNotNil: [ :c | c name ] ];
		send: [ :r | r ]
]

{ #category : 'gt - views' }
GcBehavioralConceptSpace >> gtVsEmbeddingFor: aView [
	<gtView>
	"Behavior vs geometry: for each probed word, the concept its top prediction NAMES (Stage D) beside the concept whose Stage-B embedding centroid is NEAREST (with cosine), and whether they agree. Opening this view builds the embedding space on demand."
	^ aView columnedList
		title: 'Behavior vs embedding';
		priority: 15;
		items: [ self embeddingComparisonRows ];
		column: 'Word' text: [ :row | (row at: 1) word ];
		column: 'Behavioral' text: [ :row | (row at: 2) ifNil: [ '(none)' ] ifNotNil: [ :c | c name ] ];
		column: 'Embedding nearest' text: [ :row | (row at: 3) ifNil: [ '(n/a)' ] ifNotNil: [ :assoc | assoc key name ] ];
		column: 'Cosine' text: [ :row | (row at: 3) ifNil: [ '' ] ifNotNil: [ :assoc | assoc value printShowingDecimalPlaces: 3 ] ];
		column: 'Agree?' text: [ :row | self agreementLabelFor: row ];
		send: [ :row | row at: 1 ]
]

{ #category : 'graph' }
GcBehavioralConceptSpace >> matchedConcepts [
	"The distinct concepts named by the probed words' top predictions, in first-seen order."
	| seen |
	seen := OrderedCollection new.
	self resultsOrEmpty do: [ :r |
		r matchedConcept ifNotNil: [ :c | (seen includes: c) ifFalse: [ seen add: c ] ] ].
	^ seen
]

{ #category : 'accessing' }
GcBehavioralConceptSpace >> model [
	^ model
]

{ #category : 'graph' }
GcBehavioralConceptSpace >> nodeCircle: dim color: aColor label: aString [
	"A graph node: a filled circle in aColor with aString captioned in a small font BELOW it (so labels stay clear of the circles). Mirrors GcConceptSpace>>nodeElementForConcept:."
	| circle labelText label |
	circle := BlElement new
		geometry: BlCircleGeometry new;
		size: dim @ dim;
		background: aColor;
		border: (BlBorder paint: (Color gray alpha: 0.5) width: 1);
		constraintsDo: [ :c | c linear horizontal alignCenter ];
		yourself.
	labelText := aString asRopedText.
	labelText foreground: Color black.
	labelText fontSize: 11.
	label := BlTextElement new
		text: labelText;
		constraintsDo: [ :c | c linear horizontal alignCenter ];
		yourself.
	^ BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		padding: (BlInsets all: 3);
		addChildren: { circle. label };
		yourself
]

{ #category : 'graph' }
GcBehavioralConceptSpace >> nodeElementForConcept: aConcept [
	"A colored concept node (the behavioral category the model routed some word into)."
	^ self nodeCircle: 40 color: (aConcept color ifNil: [ Color gray ]) label: aConcept name
]

{ #category : 'graph' }
GcBehavioralConceptSpace >> nodeElementForResult: aResult [
	"A word node: light gray when the model's completion matched no concept, else a translucent tint of the matched concept's color."
	| color |
	color := aResult matchedConcept
		ifNil: [ Color veryLightGray ]
		ifNotNil: [ :c | (c color ifNil: [ Color gray ]) alpha: 0.5 ].
	^ self nodeCircle: 26 color: color label: aResult word
]

{ #category : 'graph' }
GcBehavioralConceptSpace >> paintBehavioralGraphOn: aMondrian [
	"Word nodes (model = GcConceptProbeResult) plus matched-concept nodes (model = GcConcept), connected word->matchedConcept. Circle layout keeps captions clear. Words the model named no concept for appear as isolated light nodes -- an honest picture of coverage."
	aMondrian nodes
		stencil: [ :r | self nodeElementForResult: r ];
		with: self resultsOrEmpty.
	aMondrian nodes
		stencil: [ :c | self nodeElementForConcept: c ];
		with: self matchedConcepts.
	aMondrian edges
		stencil: [ :assoc | self edgeElement ];
		connect: self edgePairs from: [ :assoc | assoc key ] to: [ :assoc | assoc value ].
	aMondrian layout circle
		radius: (80 + ((self resultsOrEmpty size + self matchedConcepts size) * 20))
]

{ #category : 'printing' }
GcBehavioralConceptSpace >> printOn: aStream [
	aStream
		nextPutAll: self class name;
		nextPutAll: '(';
		print: (words ifNil: [ #() ]) size;
		nextPutAll: ' words)'
]

{ #category : 'running' }
GcBehavioralConceptSpace >> probeAll [
	"Run ONE short forward per word (each with a fresh KV cache -- the shared model stays clean) and store a GcConceptProbeResult per word, matched against this space's concepts. Heavy-demo path: opts the model into the Accelerate BLAS backend when the model supports it (seconds instead of minutes; guarded respondsTo: so stub or non-GPT-2 probeable models work too). The float32 weight buffers stay warm for repeat probes; free them with the model's unloadWeights or useNaiveBackend."
	(self model respondsTo: #useBlasBackendIfAvailable) ifTrue: [ self model useBlasBackendIfAvailable ].
	results := self words collect: [ :w |
		| r |
		r := (GcConceptProbe word: w template: self template model: self model) run.
		r concepts: self concepts.
		r ].
	^ results
]

{ #category : 'accessing' }
GcBehavioralConceptSpace >> results [
	^ results
]

{ #category : 'accessing' }
GcBehavioralConceptSpace >> results: aCollection [
	"Set the per-word results directly (e.g. synthetic GcConceptProbeResults for hermetic testing, no model)."
	results := aCollection
]

{ #category : 'accessing' }
GcBehavioralConceptSpace >> resultsOrEmpty [
	^ results ifNil: [ #() ]
]

{ #category : 'initialization' }
GcBehavioralConceptSpace >> setWords: aWords template: aTemplate model: aModel concepts: aConcepts [
	words := aWords.
	template := aTemplate.
	model := aModel.
	concepts := aConcepts
]

{ #category : 'accessing' }
GcBehavioralConceptSpace >> template [
	^ template ifNil: [ template := GcConceptProbe defaultTemplate ]
]

{ #category : 'accessing' }
GcBehavioralConceptSpace >> words [
	^ words
]
