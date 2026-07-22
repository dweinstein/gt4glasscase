"
The SAME GcConcepts examined across N GcEmbeddingModels (local gpt2 variants, remote HF checkpoints) -- answers: how does each model organize these concepts, and where do the models DISAGREE? Holds a canonical concepts list (name+words only, colored via GcConceptSpace colorAt: but deliberately kept space-less -- GcConcept's space/color slots are single-valued, so per-model geometry is built from FRESH GcConcept copies, one per derived GcConceptSpace, to avoid one model's setup silently overwriting another's) and an ordered entries list of label -> GcEmbeddingModel associations. Each entry's GcConceptSpace is built lazily and memoized (remote row fetches are the slow part; each word is fetched once per model, never a whole-weight download -- see GcEmbeddingModel remoteLabel:repository:). gtViews: the headline gtDriftFor: (every concept pair's cosine in every model plus its cross-model spread, sorted by spread descending -- which relationships do the models disagree about most?), gtAtlasesFor: (one concept-centroid atlas tile per model, all projected into the SAME shared semantic frame so tile positions are visually comparable), gtCoherenceFor: (per concept, its intra-cluster coherence in every model plus spread -- which concepts are tight in one model but diffuse in another?), and gtModelsFor: (label/source/dim/vocab/rows-fetched per entry). Class-side defaultGpt2Sizes seeds the 7 default concepts across gpt2-124M (local) and gpt2-medium/large (remote, no weight download).
"
Class {
	#name : 'GcConceptComparison',
	#superclass : 'Object',
	#instVars : [
		'concepts',
		'entries',
		'tokenizer',
		'wordSpecs',
		'spacesCache',
		'driftRowsCache'
	],
	#category : 'Gt4GlassCase-Embedding',
	#package : 'Gt4GlassCase',
	#tag : 'Embedding'
}

{ #category : 'instance creation' }
GcConceptComparison class >> concepts: aConceptsCollection models: anEntries [
	"Build a comparison using the shared GPT-2 tokenizer (I5: no weight download -- each model fetches only the union-of-concept-words' embedding rows via HTTP Range). anEntries is an ordered collection of label -> GcEmbeddingModel associations."
	^ self new setConcepts: aConceptsCollection tokenizer: GcTokenizer gpt2 entries: anEntries
]

{ #category : 'instance creation' }
GcConceptComparison class >> concepts: aConceptsCollection wordSpecs: aSpecs models: anEntries [
	"Build a comparison from PRE-TOKENIZED specs { word. ids. pieces } -- used by hermetic tests that supply synthetic ids and need no real tokenizer."
	^ self new setConcepts: aConceptsCollection wordSpecs: aSpecs entries: anEntries
]

{ #category : 'instance creation' }
GcConceptComparison class >> defaultGpt2Sizes [
	"The 7 default concepts (GcConceptSpace defaultConcepts) examined across LOCAL gpt2-124M (f32, no network) and the REMOTE gpt2-medium/gpt2-large checkpoints (single-row HTTP Range reads only, no weight download)."
	^ self concepts: GcConceptSpace defaultConcepts models: {
		'gpt2-124M local' -> GcEmbeddingModel localGpt2.
		'gpt2-medium (remote)' -> (GcEmbeddingModel remoteLabel: 'gpt2-medium' repository: 'openai-community/gpt2-medium').
		'gpt2-large (remote)' -> (GcEmbeddingModel remoteLabel: 'gpt2-large' repository: 'openai-community/gpt2-large') }
]

{ #category : 'private' }
GcConceptComparison >> alignedConceptAtlasesElement [
	"A wrapping flow of fixed-size atlas tiles, one per model, ALL rendered at the SAME shared bound (computed once) so the per-model concept layouts are directly comparable. Mirrors GcEmbeddingComparison>>alignedScattersElement's small-multiples layout."
	| bound |
	self warmUp.
	bound := self alignedConceptSharedBound.
	^ BlElement new
		layout: BlFlowLayout new;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		padding: (BlInsets all: 6);
		addChildren: (self labels collect: [ :lbl | self alignedConceptTileForLabel: lbl bound: bound ]) asArray;
		yourself
]

{ #category : 'private' }
GcConceptComparison >> alignedConceptLineFrom: p1 to: p2 extent: anExtent color: aColor width: aWidth [
	^ BlElement new
		size: anExtent;
		geometry: (BlLineGeometry from: p1 to: p2);
		outskirts: BlOutskirts outside;
		border: (BlBorder paint: aColor width: aWidth);
		yourself
]

{ #category : 'private' }
GcConceptComparison >> alignedConceptPlotElementForLabel: aLabel bound: aBound [
	"A fresh SQUARE plot of aLabel's concept centroids at the shared half-extent aBound: a light x-axis line and one labeled, concept-colored dot per canonical concept. Clicking a dot spawns the CANONICAL GcConcept (stable identity across every tile). Built explicitly at [-aBound, aBound] on both axes (no auto-fit) so equal pixel distance means equal projected distance across every tile."
	| pts n w h pad inner r container xOf yOf |
	pts := self alignedConceptProjectionFor: (self spaceForLabel: aLabel).
	n := pts size.
	w := 380. h := 380. pad := 46. inner := w - (2 * pad).
	r := aBound.
	container := BlElement new
		size: w @ h;
		background: Color white;
		border: (BlBorder paint: (Color gray alpha: 0.4) width: 1);
		yourself.
	(n < 1 or: [ r <= 0.0 ]) ifTrue: [ ^ container ].
	xOf := [ :vx | pad + ((vx + r) / (2.0 * r) * inner) ].
	yOf := [ :vy | h - pad - ((vy + r) / (2.0 * r) * inner) ].
	container addChild: (self
		alignedConceptLineFrom: (xOf value: r negated) @ (yOf value: 0.0)
		to: (xOf value: r) @ (yOf value: 0.0)
		extent: w @ h
		color: (Color gray alpha: 0.25)
		width: 1).
	1 to: n do: [ :i |
		| name cx cy concept col dotEl lblEl |
		name := (pts at: i) at: 1.
		cx := xOf value: ((pts at: i) at: 2).
		cy := yOf value: ((pts at: i) at: 3).
		concept := concepts at: i.
		col := concept color ifNil: [ Color gray ].
		dotEl := BlElement new
			geometry: BlCircleGeometry new;
			size: 14 @ 14;
			background: col;
			position: (cx - 7) @ (cy - 7);
			yourself.
		dotEl addEventHandlerOn: BlClickEvent do: [ :e | dotEl phlow spawnObject: concept ].
		lblEl := BlTextElement new
			text: (name asRopedText foreground: Color black);
			position: (cx + 9) @ (cy - 8);
			yourself.
		container addChild: dotEl.
		container addChild: lblEl ].
	^ container
]

{ #category : 'private' }
GcConceptComparison >> alignedConceptProjectionFor: aSpace [
	"Every canonical concept's centroid, projected into a SHARED semantic frame within aSpace's own model geometry: x = the direction between the 2nd and 1st canonical concepts' centroids, y = the 3rd concept's centroid contrasted (Gram-Schmidt) against x -- the SAME semantic axis choice reused in every space even though the underlying geometry differs per model (mirrors GcEmbeddingComparison>>alignedProjectionFor:'s country->capital axis, but at concept-centroid granularity). Centered on the concepts' own mean. Returns { conceptName. x. y } per canonical concept, in canonical concept order."
	| model n units xhat c yRaw yhat xs ys mx my |
	model := aSpace model.
	n := concepts size.
	n < 1 ifTrue: [ ^ #() ].
	units := concepts collect: [ :canon | (aSpace centroidFor: (self conceptNamed: canon name inSpace: aSpace)) vector ].
	xhat := n < 2
		ifTrue: [ model normalizedArr: units first ]
		ifFalse: [ model normalizedArr: ((units at: 2) with: (units at: 1) collect: [ :a :b | a - b ]) ].
	c := n >= 3
		ifTrue: [ (units at: 3) with: (units at: 1) collect: [ :a :b | a - b ] ]
		ifFalse: [ #() ].
	yRaw := c isEmpty ifTrue: [ #() ] ifFalse: [ model orthogonalizeArr: c against: { xhat } ].
	yhat := (yRaw notEmpty and: [ (model normArr: yRaw) > 1.0e-9 ])
		ifTrue: [ model normalizedArr: yRaw ]
		ifFalse: [ self alignedFallbackYFor: model against: xhat ].
	xs := units collect: [ :u | model dotArr: u with: xhat ].
	ys := units collect: [ :u | model dotArr: u with: yhat ].
	mx := (xs inject: 0.0 into: [ :a :b | a + b ]) / n.
	my := (ys inject: 0.0 into: [ :a :b | a + b ]) / n.
	^ (1 to: n) collect: [ :i | { (concepts at: i) name. (xs at: i) - mx. (ys at: i) - my } ]
]

{ #category : 'private' }
GcConceptComparison >> alignedConceptSharedBound [
	"The single axis half-extent R shared by every atlas tile: 1.1x the max |coordinate| over ALL centered concept-centroid points of ALL models, so equal pixel distance means equal projected distance in every tile."
	| maxAbs |
	maxAbs := 0.0.
	self labels do: [ :lbl |
		(self alignedConceptProjectionFor: (self spaceForLabel: lbl)) do: [ :pt |
			maxAbs := maxAbs max: (pt at: 2) abs.
			maxAbs := maxAbs max: (pt at: 3) abs ] ].
	maxAbs <= 0.0 ifTrue: [ ^ 1.0 ].
	^ maxAbs * 1.1
]

{ #category : 'private' }
GcConceptComparison >> alignedConceptTileForLabel: aLabel bound: aBound [
	"One aligned atlas tile: a header naming the model above its concept-centroid plot at the shared scale aBound. Clicking the tile drills into that label's GcConceptSpace."
	| tile space |
	space := self spaceForLabel: aLabel.
	tile := BlElement new
		layout: BlLinearLayout vertical;
		size: 400 @ 430;
		border: (BlBorder paint: (Color gray alpha: 0.3) width: 1);
		margin: (BlInsets all: 4);
		padding: (BlInsets all: 4);
		addChild: (BlTextElement new text: aLabel asRopedText; padding: (BlInsets all: 4); yourself);
		addChild: (self alignedConceptPlotElementForLabel: aLabel bound: aBound);
		yourself.
	tile when: BlClickEvent do: [ :e | e currentTarget phlow spawnObject: space ].
	^ tile
]

{ #category : 'private' }
GcConceptComparison >> alignedFallbackYFor: aModel against: xhat [
	"Any unit vector orthogonal to xhat: the first standard basis axis with a non-negligible component orthogonal to xhat, Gram-Schmidt'd and normalized. Used when the concept contrast is degenerate or parallel to xhat."
	| d |
	d := aModel hiddenDim.
	1 to: d do: [ :axis |
		| e r |
		e := Array new: d withAll: 0.0.
		e at: axis put: 1.0.
		r := aModel orthogonalizeArr: e against: { xhat }.
		(aModel normArr: r) > 1.0e-6 ifTrue: [ ^ aModel normalizedArr: r ] ].
	^ Array new: d withAll: 0.0
]

{ #category : 'private' }
GcConceptComparison >> buildSpaceForLabel: aLabel [
	| model conceptsCopy |
	model := (entries detect: [ :assoc | assoc key = aLabel ]) value.
	conceptsCopy := self copyConceptsForSpace.
	^ tokenizer notNil
		ifTrue: [ GcConceptSpace concepts: conceptsCopy tokenizer: tokenizer model: model ]
		ifFalse: [ GcConceptSpace concepts: conceptsCopy model: model wordSpecs: wordSpecs ]
]

{ #category : 'api' }
GcConceptComparison >> coherenceFor: aConcept inLabel: aLabel [
	"aConcept's intra-cluster coherence (mean pairwise member cosine) within aLabel's own GcConceptSpace."
	| space |
	space := self spaceForLabel: aLabel.
	^ space coherenceFor: (self conceptNamed: aConcept name inSpace: space)
]

{ #category : 'api' }
GcConceptComparison >> coherenceSpreadFor: aConcept [
	| values |
	values := self labels collect: [ :lbl | self coherenceFor: aConcept inLabel: lbl ].
	^ values max - values min
]

{ #category : 'private' }
GcConceptComparison >> computeDriftRows [
	"Every unordered canonical concept pair with its per-model { label. GcConceptPair. cosine } measurements, resolved within EACH model's own GcConceptSpace (own concept copies, own geometry)."
	| n rows |
	n := concepts size.
	rows := OrderedCollection new.
	1 to: n - 1 do: [ :i |
		i + 1 to: n do: [ :j |
			| cA cB measurements |
			cA := concepts at: i.
			cB := concepts at: j.
			measurements := entries collect: [ :assoc |
				| space pair |
				space := self spaceForLabel: assoc key.
				pair := GcConceptPair
					first: (self conceptNamed: cA name inSpace: space)
					second: (self conceptNamed: cB name inSpace: space)
					in: space.
				{ assoc key. pair. pair cosine } ].
			rows add: (GcConceptDriftRow conceptA: cA conceptB: cB measurements: measurements asArray) ] ].
	^ (rows asSortedCollection: [ :a :b | a spread > b spread ]) asArray
]

{ #category : 'private' }
GcConceptComparison >> conceptNamed: aName inSpace: aSpace [
	^ aSpace concepts detect: [ :c | c name = aName ]
]

{ #category : 'accessing' }
GcConceptComparison >> concepts [
	^ concepts
]

{ #category : 'private' }
GcConceptComparison >> copyConceptsForSpace [
	"FRESH GcConcept copies (same name/words) for one GcConceptSpace to own. GcConcept's space:/color: are single-valued slots (see GcConceptSpace>>setConcepts:model:wordSpecs:) so sharing the SAME GcConcept identity across several per-model spaces would let each space's setup silently overwrite the concept's space/color to whichever space was built LAST. self concepts stays space-less on purpose (GcConcept>>gtMembersFor:/gtDetailsFor: both handle space isNil)."
	^ concepts collect: [ :c | GcConcept name: c name words: c words ]
]

{ #category : 'api' }
GcConceptComparison >> driftRows [
	^ driftRowsCache ifNil: [ driftRowsCache := self computeDriftRows ]
]

{ #category : 'accessing' }
GcConceptComparison >> entries [
	^ entries
]

{ #category : 'gt views' }
GcConceptComparison >> gtAtlasesFor: aView [
	<gtView>
	^ aView explicit
		title: 'Atlases';
		priority: 8;
		stencil: [ self alignedConceptAtlasesElement ]
]

{ #category : 'gt views' }
GcConceptComparison >> gtCoherenceFor: aView [
	<gtView>
	| list |
	list := aView columnedList
		title: 'Coherence';
		priority: 12;
		items: [ self concepts ].
	list column: 'Concept' text: [ :c | c name ].
	entries do: [ :assoc |
		list column: assoc key text: [ :c | (self coherenceFor: c inLabel: assoc key) printShowingDecimalPlaces: 3 ] ].
	list column: 'Spread' text: [ :c | (self coherenceSpreadFor: c) printShowingDecimalPlaces: 3 ].
	list send: [ :c | c ].
	^ list
]

{ #category : 'gt views' }
GcConceptComparison >> gtDriftFor: aView [
	<gtView>
	| list |
	list := aView columnedList
		title: 'Concept drift';
		priority: 5;
		items: [ self driftRows ].
	list column: 'Concept pair' text: [ :r | r pairLabel ].
	entries do: [ :assoc |
		list column: assoc key text: [ :r | (r cosineForLabel: assoc key) printShowingDecimalPlaces: 3 ] ].
	list column: 'Spread' text: [ :r | r spread printShowingDecimalPlaces: 3 ].
	list send: [ :r | r ].
	^ list
]

{ #category : 'gt views' }
GcConceptComparison >> gtModelsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Models';
		priority: 20;
		items: [ self entries ];
		column: 'Label' text: [ :assoc | assoc key ];
		column: 'Source' text: [ :assoc | self sourceLabelFor: assoc key ];
		column: 'Dim' text: [ :assoc | assoc value hiddenDim printString ];
		column: 'Vocab' text: [ :assoc | assoc value vocabSize printString ];
		column: 'Rows fetched' text: [ :assoc | (self spaceForLabel: assoc key) allWords size printString ];
		send: [ :assoc | self spaceForLabel: assoc key ]
]

{ #category : 'initialization' }
GcConceptComparison >> initialize [
	super initialize.
	spacesCache := Dictionary new
]

{ #category : 'accessing' }
GcConceptComparison >> labels [
	^ entries collect: [ :assoc | assoc key ]
]

{ #category : 'accessing' }
GcConceptComparison >> models [
	^ entries collect: [ :assoc | assoc value ]
]

{ #category : 'printing' }
GcConceptComparison >> printOn: aStream [
	aStream nextPutAll: self class name.
	concepts ifNil: [ ^ self ].
	aStream nextPutAll: ' ('; print: concepts size; nextPutAll: ' concepts x '; print: (entries ifNil: [ 0 ] ifNotNil: [ entries size ]); nextPutAll: ' models)'
]

{ #category : 'private' }
GcConceptComparison >> setConcepts: aConceptsCollection [
	"Canonical concepts (name+words only): colored via the standard palette but deliberately kept space-less -- see class comment."
	concepts := aConceptsCollection asArray.
	concepts doWithIndex: [ :c :i | c color: (GcConceptSpace colorAt: i) ]
]

{ #category : 'private' }
GcConceptComparison >> setConcepts: aConceptsCollection tokenizer: aTokenizer entries: anEntries [
	self setConcepts: aConceptsCollection.
	tokenizer := aTokenizer.
	entries := anEntries asOrderedCollection
]

{ #category : 'private' }
GcConceptComparison >> setConcepts: aConceptsCollection wordSpecs: aSpecs entries: anEntries [
	self setConcepts: aConceptsCollection.
	wordSpecs := aSpecs.
	entries := anEntries asOrderedCollection
]

{ #category : 'private' }
GcConceptComparison >> sourceLabelFor: aLabel [
	"A local/remote heuristic on the entry LABEL text (this comparison's own naming convention, e.g. defaultGpt2Sizes' 'gpt2-124M local' / 'gpt2-medium (remote)'); GcEmbeddingModel itself doesn't track provenance."
	^ (aLabel includesSubstring: 'remote') ifTrue: [ 'remote' ] ifFalse: [ 'local' ]
]

{ #category : 'api' }
GcConceptComparison >> spaceForLabel: aLabel [
	"aLabel's derived GcConceptSpace, built lazily and memoized -- each word is fetched from the model at most once."
	^ spacesCache at: aLabel ifAbsentPut: [ self buildSpaceForLabel: aLabel ]
]

{ #category : 'api' }
GcConceptComparison >> spaces [
	^ self labels collect: [ :lbl | self spaceForLabel: lbl ]
]

{ #category : 'api' }
GcConceptComparison >> warmUp [
	"Eagerly build every per-model GcConceptSpace so later view reads hit caches only (no network in views)."
	self labels do: [ :lbl | self spaceForLabel: lbl ]
]
