"
A set of GcConcepts embedded in ONE GcEmbeddingModel. The model is built over the UNION of every concept's member words (each word tokenized + mean-pooled ONCE), so the whole space shares a single geometry. Provides: concepts (each colored), per-concept UNIT centroids, the member GcWordVectors tagged by concept + color, an inter-concept centroid cosine matrix (reused heavily in Stage B), and the headline ATLAS view -- a 2D PCA scatter (the model's power-iteration projection over the full concept-word set) of every member word plotted as a labeled point COLORED by its concept, with a concept color legend and centroid rings. Points click to their GcWordVector, rings/legend rows to their GcConcept. Class-side defaultGpt2 seeds a 7-concept default set on the LOCAL gpt2 (no network). Mirrors the GcEmbeddingComparison word-spec/warm-up idiom and the GcEmbeddingModel scatter idiom.
"
Class {
	#name : 'GcConceptSpace',
	#superclass : 'Object',
	#instVars : [
		'concepts',
		'model',
		'tokenizer',
		'allWordsCache',
		'wordVectorsByWordCache',
		'conceptForWordCache',
		'centroidsCache',
		'cosineMatrixCache'
	],
	#category : 'Gt4GlassCase-Embedding',
	#package : 'Gt4GlassCase',
	#tag : 'Embedding'
}

{ #category : 'defaults' }
GcConceptSpace class >> colorAt: anIndex [
	| pal |
	pal := self defaultColors.
	^ pal at: ((anIndex - 1) \\ pal size) + 1
]

{ #category : 'instance creation' }
GcConceptSpace class >> concepts: aConcepts model: aModel wordSpecs: aSpecs [
	"Build a space from pre-tokenized union word specs (each { word. tokenIds. pieces }). Used for synthetic / no-tokenizer models."
	^ self new setConcepts: aConcepts model: aModel wordSpecs: aSpecs
]

{ #category : 'instance creation' }
GcConceptSpace class >> concepts: aConcepts tokenizer: aTokenizer model: aModel [
	"Build a space by tokenizing the union of aConcepts' words with aTokenizer and pushing the specs to aModel."
	^ self new setConcepts: aConcepts tokenizer: aTokenizer model: aModel
]

{ #category : 'defaults' }
GcConceptSpace class >> defaultColors [
	"A categorical palette; concept i gets colorAt: i."
	^ {
		Color r: 0.55 g: 0.2 b: 0.7.
		Color r: 0.8 g: 0.45 b: 0.15.
		Color r: 0.15 g: 0.4 b: 0.85.
		Color r: 0.2 g: 0.65 b: 0.3.
		Color r: 0.85 g: 0.2 b: 0.25.
		Color r: 0.1 g: 0.6 b: 0.6.
		Color r: 0.85 g: 0.3 b: 0.6.
		Color r: 0.5 g: 0.5 b: 0.2.
		Color r: 0.35 g: 0.35 b: 0.35 }
]

{ #category : 'defaults' }
GcConceptSpace class >> defaultConcepts [
	"Seven ~4-word concepts of leading-space GPT-2 words; mean-pooling handles multi-token words."
	^ {
		GcConcept name: 'royalty' words: #(' king' ' queen' ' prince' ' duke').
		GcConcept name: 'animal' words: #(' dog' ' cat' ' horse' ' cow').
		GcConcept name: 'country' words: #(' France' ' Germany' ' Japan' ' Spain').
		GcConcept name: 'color' words: #(' red' ' blue' ' green' ' yellow').
		GcConcept name: 'emotion' words: #(' happy' ' sad' ' angry' ' afraid').
		GcConcept name: 'number' words: #(' one' ' two' ' three' ' four').
		GcConcept name: 'food' words: #(' bread' ' cheese' ' apple' ' rice') }
]

{ #category : 'instance creation' }
GcConceptSpace class >> defaultGpt2 [
	"The 7-concept default set embedded in the LOCAL gpt2 (f32, no network)."
	^ self concepts: self defaultConcepts tokenizer: GcTokenizer gpt2 model: GcEmbeddingModel localGpt2
]

{ #category : 'atlas' }
GcConceptSpace >> addCentroidRingsTo: container points: pts px: px py: py [
	"Mark each concept's centroid as the 2D mean of its member points (equals the projection of the concept mean, since projection is linear)."
	| n |
	n := pts size.
	concepts do: [ :c |
		| idxs mcx mcy ring |
		idxs := (1 to: n) select: [ :i | (self conceptForWord: ((pts at: i) at: 1)) == c ].
		idxs notEmpty ifTrue: [
			mcx := (idxs inject: 0.0 into: [ :s :i | s + (px at: i) ]) / idxs size.
			mcy := (idxs inject: 0.0 into: [ :s :i | s + (py at: i) ]) / idxs size.
			ring := BlElement new
				geometry: BlCircleGeometry new;
				size: 22 @ 22;
				background: (c color alpha: 0.16);
				border: (BlBorder paint: c color width: 2);
				position: (mcx - 11) @ (mcy - 11);
				yourself.
			ring addEventHandlerOn: BlClickEvent do: [ :e | ring phlow spawnObject: c ].
			container addChild: ring ] ]
]

{ #category : 'atlas' }
GcConceptSpace >> addWordDotsTo: container points: pts px: px py: py [
	"Plot each member word as a labeled dot colored by its concept; clicking a dot spawns its GcWordVector."
	| n |
	n := pts size.
	1 to: n do: [ :i |
		| word cx cy concept col wv dotEl lblEl |
		word := (pts at: i) at: 1.
		cx := px at: i.
		cy := py at: i.
		concept := self conceptForWord: word.
		col := concept ifNil: [ Color gray ] ifNotNil: [ concept color ].
		wv := self wordVectorForWord: word.
		dotEl := BlElement new
			geometry: BlCircleGeometry new;
			size: 10 @ 10;
			background: col;
			position: (cx - 5) @ (cy - 5);
			yourself.
		dotEl addEventHandlerOn: BlClickEvent do: [ :e | dotEl phlow spawnObject: wv ].
		lblEl := BlTextElement new
			text: (word asRopedText foreground: (Color black alpha: 0.75));
			position: (cx + 7) @ (cy - 7);
			yourself.
		container addChild: dotEl.
		container addChild: lblEl ]
]

{ #category : 'accessing' }
GcConceptSpace >> allWords [
	"The de-duplicated union of every concept's member words -- one embedded point each."
	^ allWordsCache ifNil: [ allWordsCache := self unionWordsOf: concepts ]
]

{ #category : 'atlas' }
GcConceptSpace >> atlasCaption [
	^ 'Concept atlas: PCA (2D) of ', self allWords size printString, ' ', (model label ifNil: [ '?' ]), ' word embeddings, colored by concept; rings mark each concept centroid (2D mean of its member points)'
]

{ #category : 'atlas' }
GcConceptSpace >> atlasConceptColors [
	"The distinct concept colors among the plotted member words."
	^ (self allWords collect: [ :w | (self conceptForWord: w) color ]) asSet
]

{ #category : 'atlas' }
GcConceptSpace >> atlasElement [
	| caption body |
	caption := BlTextElement new text: (self atlasCaption asRopedText foreground: Color gray darker).
	body := BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		addChildren: { self atlasPlotElement. self atlasLegendElement };
		yourself.
	^ BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		padding: (BlInsets all: 8);
		addChildren: { caption. body };
		yourself
]

{ #category : 'atlas' }
GcConceptSpace >> atlasLegendElement [
	| col |
	col := BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		padding: (BlInsets all: 10);
		yourself.
	col addChild: (BlTextElement new text: ('Concepts' asRopedText foreground: Color gray darker)).
	concepts do: [ :c |
		| swatch lbl row |
		swatch := BlElement new
			geometry: BlCircleGeometry new;
			size: 12 @ 12;
			background: c color;
			margin: (BlInsets right: 6);
			yourself.
		lbl := BlTextElement new text: (c name asRopedText foreground: Color black).
		row := BlElement new
			layout: BlLinearLayout horizontal;
			constraintsDo: [ :x | x horizontal fitContent. x vertical fitContent ];
			padding: (BlInsets top: 3 left: 0 bottom: 3 right: 0);
			addChildren: { swatch. lbl };
			yourself.
		row addEventHandlerOn: BlClickEvent do: [ :e | row phlow spawnObject: c ].
		col addChild: row ].
	^ col
]

{ #category : 'atlas' }
GcConceptSpace >> atlasPlotElement [
	"A 2D PCA scatter of every member word (model projectedPoints), each dot colored by its concept and clickable to its GcWordVector, with concept centroid rings. Mirrors GcEmbeddingModel>>scatterPlotElement."
	| pts n w h pad xs ys minX maxX minY maxY spanX spanY px py container |
	pts := model projectedPoints.
	n := pts size.
	w := 540. h := 430. pad := 48.
	container := BlElement new
		size: w @ h;
		background: Color white;
		border: (BlBorder paint: (Color gray alpha: 0.4) width: 1);
		yourself.
	(n < 1 or: [ model hiddenDim < 2 ]) ifTrue: [ ^ container ].
	xs := pts collect: [ :p | p at: 2 ].
	ys := pts collect: [ :p | p at: 3 ].
	minX := xs min. maxX := xs max. minY := ys min. maxY := ys max.
	spanX := maxX - minX. spanX = 0 ifTrue: [ spanX := 1.0 ].
	spanY := maxY - minY. spanY = 0 ifTrue: [ spanY := 1.0 ].
	px := Array new: n.
	py := Array new: n.
	1 to: n do: [ :i |
		px at: i put: pad + (((xs at: i) - minX) / spanX * (w - (2 * pad))).
		py at: i put: h - pad - (((ys at: i) - minY) / spanY * (h - (2 * pad))) ].
	self addCentroidRingsTo: container points: pts px: px py: py.
	self addWordDotsTo: container points: pts px: px py: py.
	^ container
]

{ #category : 'atlas' }
GcConceptSpace >> atlasWordCount [
	"One point per member word = the number of union words plotted in the atlas."
	^ model projectedPoints size
]

{ #category : 'accessing' }
GcConceptSpace >> centroidFor: aConcept [
	^ self centroids at: aConcept
]

{ #category : 'accessing' }
GcConceptSpace >> centroids [
	"concept -> its UNIT centroid GcWordVector."
	^ centroidsCache ifNil: [
		| d |
		d := IdentityDictionary new.
		concepts do: [ :c | d at: c put: (c centroidIn: model) ].
		centroidsCache := d ]
]

{ #category : 'accessing' }
GcConceptSpace >> conceptForWord: aWord [
	"The (first) concept that lists aWord, or nil."
	^ self conceptsByWord at: aWord ifAbsent: [ nil ]
]

{ #category : 'accessing' }
GcConceptSpace >> concepts [
	^ concepts
]

{ #category : 'accessing' }
GcConceptSpace >> conceptsByWord [
	"word -> the first concept that lists it."
	^ conceptForWordCache ifNil: [
		| d |
		d := Dictionary new.
		concepts do: [ :c | c words do: [ :w | d at: w ifAbsentPut: [ c ] ] ].
		conceptForWordCache := d ]
]

{ #category : 'accessing' }
GcConceptSpace >> cosineBetween: aConcept and: anotherConcept [
	^ (self centroidFor: aConcept) cosineTo: (self centroidFor: anotherConcept)
]

{ #category : 'accessing' }
GcConceptSpace >> cosineMatrix [
	"The N x N inter-concept centroid cosine matrix (rows and columns in concept order). Reused heavily in Stage B."
	^ cosineMatrixCache ifNil: [
		cosineMatrixCache := concepts collect: [ :a |
			concepts collect: [ :b | (self centroidFor: a) cosineTo: (self centroidFor: b) ] ] ]
]

{ #category : 'gt views' }
GcConceptSpace >> gtAtlasFor: aView [
	<gtView>
	^ aView explicit
		title: 'Atlas';
		priority: 10;
		stencil: [ self atlasElement ]
]

{ #category : 'gt views' }
GcConceptSpace >> gtConceptsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Concepts';
		priority: 20;
		items: [ self concepts ];
		column: 'Concept' text: [ :c | c name ];
		column: 'Words' text: [ :c | c wordCount printString ];
		column: 'Members' text: [ :c | (c words ifNil: [ #() ]) printString ];
		send: [ :c | c ]
]

{ #category : 'gt views' }
GcConceptSpace >> gtSimilarityFor: aView [
	<gtView>
	| list |
	list := aView columnedList
		title: 'Similarity';
		priority: 30;
		items: [ self concepts ].
	list column: 'Concept' text: [ :c | c name ].
	self concepts do: [ :colConcept |
		list column: colConcept name text: [ :rowConcept |
			(self cosineBetween: rowConcept and: colConcept) printShowingDecimalPlaces: 3 ] ].
	list send: [ :c | c ].
	^ list
]

{ #category : 'accessing' }
GcConceptSpace >> model [
	^ model
]

{ #category : 'printing' }
GcConceptSpace >> printOn: aStream [
	aStream nextPutAll: self class name.
	concepts ifNil: [ ^ self ].
	aStream nextPutAll: ' ('; print: concepts size; nextPutAll: ' concepts)'
]

{ #category : 'initialization' }
GcConceptSpace >> setConcepts: aConcepts model: aModel wordSpecs: aSpecs [
	concepts := aConcepts asArray.
	model := aModel.
	concepts doWithIndex: [ :c :i | c space: self. c color: (self class colorAt: i) ].
	model wordSpecs: aSpecs; seed: 1.
	self warmUp
]

{ #category : 'initialization' }
GcConceptSpace >> setConcepts: aConcepts tokenizer: aTokenizer model: aModel [
	| unionWords specs |
	tokenizer := aTokenizer.
	unionWords := self unionWordsOf: aConcepts.
	specs := unionWords collect: [ :w |
		| ids |
		ids := aTokenizer encode: w.
		{ w. ids. (ids collect: [ :id | aTokenizer decode: { id } ]) } ].
	self setConcepts: aConcepts model: aModel wordSpecs: specs
]

{ #category : 'accessing' }
GcConceptSpace >> tokenizer [
	^ tokenizer
]

{ #category : 'private' }
GcConceptSpace >> unionWordsOf: aConcepts [
	"The de-duplicated union of every concept's words, in first-seen order."
	| seen ordered |
	seen := Set new.
	ordered := OrderedCollection new.
	aConcepts do: [ :c | c words do: [ :w |
		(seen includes: w) ifFalse: [ seen add: w. ordered add: w ] ] ].
	^ ordered asArray
]

{ #category : 'initialization' }
GcConceptSpace >> warmUp [
	"Eagerly compute the word vectors, per-word index, centroids and cosine matrix so gtViews read caches only (no network in views)."
	model wordVectors.
	self wordVectorsByWord.
	self centroids.
	self cosineMatrix
]

{ #category : 'accessing' }
GcConceptSpace >> wordVectorForWord: aWord [
	^ self wordVectorsByWord at: aWord ifAbsent: [ nil ]
]

{ #category : 'accessing' }
GcConceptSpace >> wordVectorsByWord [
	"word -> its mean-pooled GcWordVector in this space's model."
	^ wordVectorsByWordCache ifNil: [
		| d |
		d := Dictionary new.
		model words doWithIndex: [ :w :i | d at: w put: (model wordVectorAt: i) ].
		wordVectorsByWordCache := d ]
]
