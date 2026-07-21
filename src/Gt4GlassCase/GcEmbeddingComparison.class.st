"
TOP object of the cross-model word-embedding distance explorer. Holds a word set (default ' France' ' Paris' ' Germany' ' Berlin') and a list of GcEmbeddingModels sharing the GPT-2 tokenizer. Tokenizes each word ONCE (same vocab across the gpt2 family) and pushes the specs to every model. gtViews: gtModelsFor: (list -> each model's matrix + scatter) and the headline gtSummaryFor: (every word-pair x every model, raw cosine + z-normalised score) so you see the same words' distances move with model size and quantization in one pane. Every row send:s a domain object so the Miller columns cascade.
"
Class {
	#name : 'GcEmbeddingComparison',
	#superclass : 'Object',
	#instVars : [
		'words',
		'tokenizer',
		'models',
		'wordSpecsCache',
		'wordPairsCache'
	],
	#category : 'Gt4GlassCase-Embedding',
	#package : 'Gt4GlassCase',
	#tag : 'Embedding'
}

{ #category : 'accessing' }
GcEmbeddingComparison class >> defaultWords [
	^ #(' France' ' Paris' ' Germany' ' Berlin')
]

{ #category : 'instance creation' }
GcEmbeddingComparison class >> wordSpecs: aSpecs models: aModels [
	"Build a comparison from PRE-TOKENIZED specs { word. ids. pieces } -- used by hermetic tests that supply synthetic ids and need no real tokenizer."
	^ self new setWordSpecs: aSpecs models: aModels
]

{ #category : 'instance creation' }
GcEmbeddingComparison class >> words: aWords models: aModels [
	"Build a comparison, tokenizing aWords with the shared GPT-2 tokenizer and warming each model (word vectors + baseline) so subsequent views are network-free."
	^ self new setWords: aWords models: aModels
]

{ #category : 'private - aligned' }
GcEmbeddingComparison >> alignedArrowFrom: p1 to: p2 extent: anExtent color: aColor [
	"A country->capital arrow: a shaft from p1 to p2 plus a two-segment arrowhead at p2, all as full-extent line children of one container so their local coordinates match the plot's."
	| container dx dy len ux uy px py headLen headHalf baseX baseY leftPt rightPt |
	container := BlElement new size: anExtent; yourself.
	container addChild: (self alignedLineFrom: p1 to: p2 extent: anExtent color: aColor width: 2).
	dx := p2 x - p1 x. dy := p2 y - p1 y.
	len := ((dx * dx) + (dy * dy)) sqrt.
	len <= 0.0 ifTrue: [ ^ container ].
	ux := dx / len. uy := dy / len.
	px := uy negated. py := ux.
	headLen := 12. headHalf := 6.
	baseX := p2 x - (headLen * ux). baseY := p2 y - (headLen * uy).
	leftPt := (baseX + (headHalf * px)) @ (baseY + (headHalf * py)).
	rightPt := (baseX - (headHalf * px)) @ (baseY - (headHalf * py)).
	container addChild: (self alignedLineFrom: p2 to: leftPt extent: anExtent color: aColor width: 2).
	container addChild: (self alignedLineFrom: p2 to: rightPt extent: anExtent color: aColor width: 2).
	^ container
]

{ #category : 'private - aligned' }
GcEmbeddingComparison >> alignedFallbackYFor: aModel against: xhat [
	"Any unit vector orthogonal to xhat: the first standard basis axis with a non-negligible component orthogonal to xhat, Gram-Schmidt'd and normalized. Used when the country-contrast is degenerate or parallel to xhat."
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

{ #category : 'private - aligned' }
GcEmbeddingComparison >> alignedLineFrom: p1 to: p2 extent: anExtent color: aColor width: aWidth [
	"A thin line element spanning the whole plot so its local coordinate space matches the plot's (same idiom as GcEmbeddingModel>>lineFrom:to:extent:, but with explicit color/width for the axis and arrows)."
	^ BlElement new
		size: anExtent;
		geometry: (BlLineGeometry from: p1 to: p2);
		outskirts: BlOutskirts outside;
		border: (BlBorder paint: aColor width: aWidth);
		yourself
]

{ #category : 'private - aligned' }
GcEmbeddingComparison >> alignedPlotElementForModel: aModel bound: aBound [
	"A fresh SQUARE plot of aModel's aligned projection at the shared half-extent aBound: a light x-axis (the country->capital direction), one arrow per configured consecutive pair drawn country->capital, and the words as labeled dots. Built explicitly at [aBound negated, aBound] on BOTH axes (square, NO auto-fit) so equal pixel distance means equal projected distance across every tile."
	| pts n w h pad inner r container xOf yOf |
	pts := self alignedProjectionFor: aModel.
	n := pts size.
	w := 400. h := 400. pad := 46. inner := w - (2 * pad).
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
		alignedLineFrom: (xOf value: r negated) @ (yOf value: 0.0)
		to: (xOf value: r) @ (yOf value: 0.0)
		extent: w @ h
		color: (Color gray alpha: 0.25)
		width: 1).
	1 to: n // 2 do: [ :k |
		| a b p1 p2 |
		a := 2 * k - 1. b := 2 * k.
		p1 := (xOf value: ((pts at: a) at: 2)) @ (yOf value: ((pts at: a) at: 3)).
		p2 := (xOf value: ((pts at: b) at: 2)) @ (yOf value: ((pts at: b) at: 3)).
		container addChild: (self alignedArrowFrom: p1 to: p2 extent: w @ h color: (Color r: 0.85 g: 0.33 b: 0.1)) ].
	1 to: n do: [ :i |
		| word cx cy dotEl lblEl |
		word := (pts at: i) at: 1.
		cx := xOf value: ((pts at: i) at: 2).
		cy := yOf value: ((pts at: i) at: 3).
		dotEl := BlElement new
			geometry: BlCircleGeometry new;
			size: 11 @ 11;
			background: (Color r: 0.15 g: 0.4 b: 0.85);
			position: (cx - 5.5) @ (cy - 5.5);
			yourself.
		lblEl := BlTextElement new
			text: (word asRopedText foreground: Color black);
			position: (cx + 8) @ (cy - 8);
			yourself.
		container addChild: dotEl.
		container addChild: lblEl ].
	^ container
]

{ #category : 'private - aligned' }
GcEmbeddingComparison >> alignedProjectionFor: aModel [
	"aModel's word vectors projected into the SHARED, semantically-anchored 2D frame used by every aligned tile: unit-normalize (cosine geometry, removing per-model magnitude scale), project onto x = the country->capital direction (normalized mean of the configured consecutive pair displacements capital-country) and y = a country-contrast orthogonalized (Gram-Schmidt) against x, then CENTER on the words' centroid. Returns { word. x. y } per word so the plot draws the same meaning (country->capital ~ +x) in EVERY model."
	| wvs units n d pairCount diffSum xhat c yRaw yhat xs ys mx my |
	wvs := aModel wordVectors.
	n := wvs size.
	n < 1 ifTrue: [ ^ #() ].
	d := aModel hiddenDim.
	units := wvs collect: [ :wv | aModel normalizedArr: wv vector ].
	pairCount := n // 2.
	diffSum := Array new: d withAll: 0.0.
	1 to: pairCount do: [ :k |
		| country capital |
		country := units at: 2 * k - 1.
		capital := units at: 2 * k.
		1 to: d do: [ :j | diffSum at: j put: (diffSum at: j) + ((capital at: j) - (country at: j)) ] ].
	xhat := aModel normalizedArr: diffSum.
	c := pairCount >= 2
		ifTrue: [ (1 to: d) collect: [ :j | ((units at: 1) at: j) - ((units at: 3) at: j) ] ]
		ifFalse: [ #() ].
	yRaw := c isEmpty
		ifTrue: [ #() ]
		ifFalse: [ aModel orthogonalizeArr: c against: { xhat } ].
	yhat := (yRaw notEmpty and: [ (aModel normArr: yRaw) > 1.0e-9 ])
		ifTrue: [ aModel normalizedArr: yRaw ]
		ifFalse: [ self alignedFallbackYFor: aModel against: xhat ].
	xs := units collect: [ :u | aModel dotArr: u with: xhat ].
	ys := units collect: [ :u | aModel dotArr: u with: yhat ].
	mx := (xs inject: 0.0 into: [ :a :b | a + b ]) / n.
	my := (ys inject: 0.0 into: [ :a :b | a + b ]) / n.
	^ (1 to: n) collect: [ :i | { (wvs at: i) word. (xs at: i) - mx. (ys at: i) - my } ]
]

{ #category : 'private - aligned' }
GcEmbeddingComparison >> alignedScattersElement [
	"A wrapping flow of fixed-size aligned tiles, one per model, ALL rendered at the SAME shared bound R (computed once) so the per-model planes are directly comparable -- unlike gtScattersFor: whose per-model PCA axes have arbitrary orientation/scale. Mirrors allScattersElement's small-multiples layout."
	| bound |
	bound := self alignedSharedBound.
	^ BlElement new
		layout: BlFlowLayout new;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		padding: (BlInsets all: 6);
		addChildren: (models withIndexCollect: [ :model :idx | self alignedTileForModel: model sharedBound: bound index: idx ]) asArray;
		yourself
]

{ #category : 'private - aligned' }
GcEmbeddingComparison >> alignedSharedBound [
	"The single axis half-extent R shared by every aligned tile: 1.1x the max |coordinate| over ALL centered projected points of ALL models, so equal pixel distance means equal cosine-projected distance in every tile. Computed ONCE and passed to each tile."
	| maxAbs |
	maxAbs := 0.0.
	models do: [ :m |
		(self alignedProjectionFor: m) do: [ :pt |
			maxAbs := maxAbs max: (pt at: 2) abs.
			maxAbs := maxAbs max: (pt at: 3) abs ] ].
	maxAbs <= 0.0 ifTrue: [ ^ 1.0 ].
	^ maxAbs * 1.1
]

{ #category : 'private - aligned' }
GcEmbeddingComparison >> alignedTileForModel: aModel sharedBound: aBound index: anIndex [
	"One aligned small-multiples tile: the shared header (model label + first word-pair z-score) above this model's ALIGNED plot drawn at the shared bound aBound. Clicking drills into the GcEmbeddingModel. Mirrors scatterTileForModel:index: but plots the aligned projection at the shared scale rather than the model's own PCA."
	| tile |
	tile := BlElement new
		layout: BlLinearLayout vertical;
		size: 430 @ 470;
		border: (BlBorder paint: (Color gray alpha: 0.3) width: 1);
		margin: (BlInsets all: 4);
		padding: (BlInsets all: 4);
		addChild: (self tileHeaderForModel: aModel index: anIndex);
		addChild: (self alignedPlotElementForModel: aModel bound: aBound);
		yourself.
	tile when: BlClickEvent do: [ :e | e currentTarget phlow spawnObject: aModel ].
	^ tile
]

{ #category : 'private - scatters' }
GcEmbeddingComparison >> allScattersElement [
	"A wrapping flow of fixed-size tiles, one per model, each embedding that model's own scatterElement -- the same small-multiples idiom as GcLayerRecord>>attentionOverviewElement (a BlFlowLayout of captioned tiles)."
	^ BlElement new
		layout: BlFlowLayout new;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		padding: (BlInsets all: 6);
		addChildren: (models withIndexCollect: [ :model :idx | self scatterTileForModel: model index: idx ]) asArray;
		yourself
]

{ #category : 'computing' }
GcEmbeddingComparison >> computeWordPairDistances [
	"Every unordered word pair with its per-model { model. cosine. distance. z } measurements."
	| n pairs |
	n := words size.
	pairs := OrderedCollection new.
	1 to: n - 1 do: [ :i |
		i + 1 to: n do: [ :j |
			| measurements |
			measurements := models collect: [ :m |
				| c |
				c := m cosineBetweenIndex: i and: j.
				{ m. c. 1.0 - c. (m normalizedScoreFor: c) } ].
			pairs add: (GcWordPairDistance
				wordA: (words at: i)
				wordB: (words at: j)
				measurements: measurements asArray) ] ].
	^ pairs asArray
]

{ #category : 'gt views' }
GcEmbeddingComparison >> gtAlignedScattersFor: aView [
	"Small multiples like gtScattersFor:, but every model is projected into a SHARED, semantically-anchored, SAME-SCALE frame so the tiles are directly comparable. Each word set is unit-normalized and projected onto x = the country->capital direction and an orthogonal country-contrast y, centered, and drawn at ONE shared bound R across all tiles. The country->capital pair is drawn as an arrow (~horizontal by construction) so how horizontal/equal the pair arrows are shows how linear the analogy is in that model. The existing PCA gtScattersFor: is left untouched. Clicking a tile opens the GcEmbeddingModel."
	<gtView>
	^ aView explicit
		title: 'Aligned';
		priority: 8;
		stencil: [ self alignedScattersElement ]
]

{ #category : 'gt - views' }
GcEmbeddingComparison >> gtModelsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Models';
		priority: 10;
		items: [ models ];
		column: 'Label' text: [ :m | m label ];
		column: 'Dim' text: [ :m | m hiddenDim printString ];
		column: 'Precision' text: [ :m | m precision label ];
		column: 'Baseline cos' text: [ :m | (m baselineMean printShowingDecimalPlaces: 3) , ' +/- ' , (m baselineStd printShowingDecimalPlaces: 3) ]
]

{ #category : 'gt views' }
GcEmbeddingComparison >> gtScattersFor: aView [
	"Small multiples: EVERY model's 2D PCA word-embedding scatter as a labelled tile, all laid out at once so the planes can be compared side by side without drilling into each model one at a time. Clicking a tile opens that GcEmbeddingModel. Mirrors the small-multiples idiom of GcLayerRecord>>attentionOverviewElement and reuses each model's own scatterElement (no re-plotting)."
	<gtView>
	^ aView explicit
		title: 'Scatters';
		priority: 7;
		stencil: [ self allScattersElement ]
]

{ #category : 'gt - views' }
GcEmbeddingComparison >> gtSummaryFor: aView [
	<gtView>
	| list |
	list := aView columnedList
		title: 'Summary';
		priority: 5;
		items: [ self wordPairDistances ].
	list column: 'Pair' text: [ :p | p pairLabel ].
	models doWithIndex: [ :m :idx |
		list column: m label text: [ :p |
			((p cosineForModelIndex: idx) printShowingDecimalPlaces: 3) , ' (z=' , ((p zForModelIndex: idx) printShowingDecimalPlaces: 2) , ')' ] ].
	list send: [ :p | p ].
	^ list
]

{ #category : 'accessing' }
GcEmbeddingComparison >> models [
	^ models
]

{ #category : 'initialization' }
GcEmbeddingComparison >> prepareModels [
	| specs |
	specs := self wordSpecs.
	models doWithIndex: [ :m :i | m wordSpecs: specs; seed: i ]
]

{ #category : 'printing' }
GcEmbeddingComparison >> printOn: aStream [
	aStream nextPutAll: self class name; nextPutAll: '('.
	aStream print: (words ifNil: [ #() ]) size; nextPutAll: ' words x '.
	aStream print: (models ifNil: [ #() ]) size; nextPutAll: ' models)'
]

{ #category : 'private - scatters' }
GcEmbeddingComparison >> scatterTileForModel: aModel index: anIndex [
	"One fixed-size small-multiples tile: a self-describing header (model label + first word-pair z-score) above the model's own scatterElement. The tile is sized to hold the scatter (a fixed 460x340 plot) so tiles sit side by side and wrap. Clicking the tile drills into the GcEmbeddingModel."
	| tile |
	tile := BlElement new
		layout: BlLinearLayout vertical;
		size: 500 @ 420;
		border: (BlBorder paint: (Color gray alpha: 0.3) width: 1);
		margin: (BlInsets all: 4);
		padding: (BlInsets all: 4);
		addChild: (self tileHeaderForModel: aModel index: anIndex);
		addChild: aModel scatterElement;
		yourself.
	tile when: BlClickEvent do: [ :e | e currentTarget phlow spawnObject: aModel ].
	^ tile
]

{ #category : 'initialization' }
GcEmbeddingComparison >> setWordSpecs: aSpecs models: aModels [
	wordSpecsCache := aSpecs.
	words := aSpecs collect: [ :s | s first ].
	models := aModels.
	models doWithIndex: [ :m :i | m wordSpecs: aSpecs; seed: i ].
	self warmUp
]

{ #category : 'initialization' }
GcEmbeddingComparison >> setWords: aWords models: aModels [
	words := aWords.
	models := aModels.
	tokenizer := GcTokenizer gpt2.
	self prepareModels.
	self warmUp
]

{ #category : 'private - scatters' }
GcEmbeddingComparison >> tileHeaderForModel: aModel index: anIndex [
	"A one-line caption naming the model and its first word-pair z-score, so each tile is self-describing. Uses the already-cached wordPairDistances (both live examples call wordPairDistances, so no extra computation)."
	| pairs caption |
	pairs := self wordPairDistances.
	caption := pairs isEmpty
		ifTrue: [ aModel label ]
		ifFalse: [ aModel label , '   ' , pairs first pairLabel , '  z=' , ((pairs first zForModelIndex: anIndex) printShowingDecimalPlaces: 2) ].
	^ BlTextElement new
		text: caption asRopedText;
		padding: (BlInsets all: 4);
		yourself
]

{ #category : 'accessing' }
GcEmbeddingComparison >> tokenizer [
	^ tokenizer ifNil: [ tokenizer := GcTokenizer gpt2 ]
]

{ #category : 'initialization' }
GcEmbeddingComparison >> warmUp [
	"Eagerly compute each model's word vectors and random-pair baseline (the network work for remote models) so gtViews only read caches (I5: no network in views)."
	models do: [ :m | m wordVectors. m randomPairBaseline ].
	self wordPairDistances
]

{ #category : 'computing' }
GcEmbeddingComparison >> wordPairDistances [
	^ wordPairsCache ifNil: [ wordPairsCache := self computeWordPairDistances ]
]

{ #category : 'computing' }
GcEmbeddingComparison >> wordSpecs [
	"Each word tokenized ONCE (shared across the gpt2 family): { word. tokenIds. pieces }."
	^ wordSpecsCache ifNil: [ wordSpecsCache := words collect: [ :w |
		| ids |
		ids := self tokenizer encode: w.
		{ w. ids. (ids collect: [ :id | self tokenizer decode: { id } ]) } ] ]
]

{ #category : 'accessing' }
GcEmbeddingComparison >> words [
	^ words
]
