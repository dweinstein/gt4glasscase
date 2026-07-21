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
		'cosineMatrixCache',
		'edgeThreshold'
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

{ #category : 'accessing - relationships' }
GcConceptSpace >> coherenceFor: aConcept [
	"Intra-concept coherence: the mean pairwise cosine among aConcept's member word vectors (1.0 for fewer than two members). Higher = tighter cluster; used to size the concept's graph node."
	| vecs sum count |
	vecs := aConcept memberVectors.
	vecs size < 2 ifTrue: [ ^ 1.0 ].
	sum := 0.0.
	count := 0.
	1 to: vecs size - 1 do: [ :i |
		i + 1 to: vecs size do: [ :j |
			sum := sum + ((vecs at: i) cosineTo: (vecs at: j)).
			count := count + 1 ] ].
	^ sum / count
]

{ #category : 'gt - views - support' }
GcConceptSpace >> colorForSimilarity: aCosine [
	"Map a cosine (clamped to [0,1]) to a sequential white -> deep-blue heatmap color: 0 = white, 1 = deep blue."
	| t |
	t := ((aCosine max: 0.0) min: 1.0) asFloat.
	^ Color r: 1.0 - (t * 0.78) g: 1.0 - (t * 0.55) b: 1.0 - (t * 0.12)
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

{ #category : 'accessing - relationships' }
GcConceptSpace >> defaultEdgeThreshold [
	"Mean of the unique off-diagonal (upper-triangle) centroid cosines -- a data-driven cut so the default graph shows the above-average relationships, not a fully connected mesh."
	| cm n sum count |
	cm := self cosineMatrix.
	n := concepts size.
	n < 2 ifTrue: [ ^ 0.0 ].
	sum := 0.0.
	count := 0.
	1 to: n - 1 do: [ :i |
		i + 1 to: n do: [ :j |
			sum := sum + ((cm at: i) at: j).
			count := count + 1 ] ].
	^ sum / count
]

{ #category : 'gt - views - support' }
GcConceptSpace >> edgeElementForPair: aPair [
	"A graph edge for aPair: a line whose width and opacity grow with the inter-concept cosine (stronger relation = thicker, darker)."
	| c |
	c := aPair cosine abs.
	^ BlLineElement new
		zIndex: -1;
		border: (BlBorder
			paint: ((Color r: 0.2 g: 0.3 b: 0.5) alpha: ((0.3 + (c * 0.6)) min: 0.95))
			width: 1.0 + (c * 5.0));
		yourself
]

{ #category : 'accessing - relationships' }
GcConceptSpace >> edgePairs [
	"The relationship-graph edges (GcConceptPairs) at the current edgeThreshold."
	^ self edgePairsForThreshold: self edgeThreshold
]

{ #category : 'accessing - relationships' }
GcConceptSpace >> edgePairsForThreshold: aThreshold [
	"GcConceptPairs for the upper-triangle concept index pairs (i<j) whose centroid cosine EXCEEDS aThreshold. Undirected: one pair per unordered concept couple."
	| cm n pairs |
	cm := self cosineMatrix.
	n := concepts size.
	pairs := OrderedCollection new.
	1 to: n - 1 do: [ :i |
		i + 1 to: n do: [ :j |
			((cm at: i) at: j) > aThreshold ifTrue: [
				pairs add: (GcConceptPair first: (concepts at: i) second: (concepts at: j) in: self) ] ] ].
	^ pairs
]

{ #category : 'accessing - relationships' }
GcConceptSpace >> edgeThreshold [
	"The inter-concept centroid cosine ABOVE which the relationship graph draws an edge. Lazily defaults to the mean of the off-diagonal cosines so the default graph is legible; set via edgeThreshold: to tune."
	^ edgeThreshold ifNil: [ self defaultEdgeThreshold ]
]

{ #category : 'accessing - relationships' }
GcConceptSpace >> edgeThreshold: aNumberOrNil [
	"Set the graph edge cutoff (a cosine). Pass nil to fall back to the data-driven default."
	edgeThreshold := aNumberOrNil
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

{ #category : 'gt - views' }
GcConceptSpace >> gtGraphFor: aView [
	<gtView>
	^ aView mondrian
		title: 'Graph';
		priority: 12;
		painting: [ :mondrian | self paintGraphOn: mondrian ]
]

{ #category : 'gt - views' }
GcConceptSpace >> gtHeatmapFor: aView [
	<gtView>
	^ aView explicit
		title: 'Heatmap';
		priority: 14;
		stencil: [ self heatmapElement ]
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

{ #category : 'gt - views - support' }
GcConceptSpace >> heatmapCellCount [
	"The number of cells the heatmap draws: N x N (one per ordered concept pair, diagonal included)."
	^ concepts size * concepts size
]

{ #category : 'gt - views - support' }
GcConceptSpace >> heatmapCellElement: aSimilarity pair: aPair width: aWidth height: aHeight [
	| cell label |
	cell := BlElement new
		layout: BlFrameLayout new;
		constraintsDo: [ :c | c horizontal exact: aWidth. c vertical exact: aHeight ];
		background: (self colorForSimilarity: aSimilarity);
		border: (BlBorder paint: Color white width: 1);
		yourself.
	cell userData at: #gcHeatmapCell put: aPair.
	label := BlTextElement new
		text: ((aSimilarity printShowingDecimalPlaces: 2) asRopedText
			foreground: (aSimilarity > 0.7 ifTrue: [ Color white ] ifFalse: [ Color black ]));
		constraintsDo: [ :c | c frame horizontal alignCenter. c frame vertical alignCenter ];
		yourself.
	cell addChild: label.
	cell addEventHandlerOn: BlClickEvent do: [ :e | cell phlow spawnObject: aPair ].
	^ cell
]

{ #category : 'gt - views - support' }
GcConceptSpace >> heatmapElement [
	"An N x N cosine-similarity heatmap: cells colored white->deep-blue by inter-concept centroid cosine (diagonal = 1), rows and columns labeled by concept name in the concept's color. Each cell clicks to its GcConceptPair."
	| n cellW cellH labelW cm container header |
	n := concepts size.
	cellW := 66.
	cellH := 30.
	labelW := 96.
	cm := self cosineMatrix.
	container := BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		padding: (BlInsets all: 8);
		yourself.
	container addChild: (BlTextElement new
		text: ('Inter-concept cosine similarity (diagonal = 1)' asRopedText foreground: Color gray darker)).
	header := BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		yourself.
	header addChild: (self heatmapLabelElement: '' color: Color transparent width: labelW).
	concepts do: [ :c |
		header addChild: (self heatmapLabelElement: c name color: c color width: cellW) ].
	container addChild: header.
	1 to: n do: [ :i |
		| row rowConcept |
		rowConcept := concepts at: i.
		row := BlElement new
			layout: BlLinearLayout horizontal;
			constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
			yourself.
		row addChild: (self heatmapLabelElement: rowConcept name color: rowConcept color width: labelW).
		1 to: n do: [ :j |
			| pair |
			pair := GcConceptPair first: rowConcept second: (concepts at: j) in: self.
			row addChild: (self
				heatmapCellElement: ((cm at: i) at: j)
				pair: pair
				width: cellW
				height: cellH) ].
		container addChild: row ].
	^ container
]

{ #category : 'gt - views - support' }
GcConceptSpace >> heatmapLabelElement: aString color: aColor width: aWidth [
	^ BlTextElement new
		text: (aString asRopedText foreground: aColor);
		padding: (BlInsets all: 2);
		constraintsDo: [ :c | c horizontal exact: aWidth. c vertical fitContent ];
		yourself
]

{ #category : 'accessing' }
GcConceptSpace >> model [
	^ model
]

{ #category : 'gt - views - support' }
GcConceptSpace >> nodeElementForConcept: aConcept [
	"A graph node for aConcept: a filled circle in the concept's color (diameter grows with intra-concept coherence) captioned with the concept name. The vertical container's model stays the concept, so a click drills into it."
	| coh dim circle label |
	coh := self coherenceFor: aConcept.
	dim := (26 + (((coh max: 0.0) min: 1.0) * 34)) rounded.
	circle := BlElement new
		geometry: BlCircleGeometry new;
		size: dim @ dim;
		background: aConcept color;
		border: (BlBorder paint: (Color gray alpha: 0.5) width: 1);
		constraintsDo: [ :c | c linear horizontal alignCenter ];
		yourself.
	label := BlTextElement new
		text: (aConcept name asRopedText foreground: Color black);
		constraintsDo: [ :c | c linear horizontal alignCenter ];
		yourself.
	^ BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		padding: (BlInsets all: 3);
		addChildren: { circle. label };
		yourself
]

{ #category : 'gt - views - support' }
GcConceptSpace >> paintGraphOn: aMondrian [
	"Paint the concept relationship graph: one node per concept (colored, coherence-sized) and one edge per above-threshold GcConceptPair (width/opacity ~ cosine), with a force layout."
	aMondrian nodes
		stencil: [ :concept | self nodeElementForConcept: concept ];
		with: self concepts.
	aMondrian edges
		stencil: [ :pair | self edgeElementForPair: pair ];
		connect: self edgePairs from: #first to: #second.
	aMondrian layout force
		strength: 0.2;
		charge: -420
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
