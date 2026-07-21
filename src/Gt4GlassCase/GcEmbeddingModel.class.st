"
One entry in a cross-model embedding comparison: a labelled way to turn a token id into a mean-pooled embedding vector, unified over LOCAL gpt2 (rowSliceAt: on the local wte tensor), REMOTE sizes (rowSliceAt: on an HTTP-range-backed GcTensorRef), and PRECISION variants (a GcWeightPrecision applied per row). rowBlock: tokenId -> raw Float row; bandBlock: count -> flat values of the first `count` rows (ONE ranged read) used for the random-pair cosine baseline. Computes the word-set pairwise cosine/distance matrix, a 2D PCA scatter of the words (power iteration, reusing the GcMoeRouter idiom), and a deterministic random-pair baseline (mean+std cosine) so cross-model cosines can be z-normalised for fair comparison. gtViews: distance matrix, scatter, overview.
"
Class {
	#name : 'GcEmbeddingModel',
	#superclass : 'Object',
	#instVars : [
		'label',
		'rowBlock',
		'bandBlock',
		'vocabSize',
		'hiddenDim',
		'precision',
		'wordSpecs',
		'seed',
		'baselineN',
		'baselinePoolTarget',
		'wordVectorsCache',
		'baselineCache'
	],
	#category : 'Gt4GlassCase-Embedding',
	#package : 'Gt4GlassCase',
	#tag : 'Embedding'
}

{ #category : 'instance creation' }
GcEmbeddingModel class >> fromEmbeddingTensor: aTensorRef label: aLabel precision: aPrecision [
	"Build a model whose word/band rows come from a GcTensorRef (LOCAL file- or REMOTE HTTP-range-backed alike -- rowSliceAt: does ONE ranged read either way), with aPrecision applied per row."
	^ self new
		label: aLabel;
		hiddenDim: aTensorRef innerSize;
		vocabSize: aTensorRef dimensions first;
		precision: aPrecision;
		rowBlock: [ :id | (aTensorRef rowSliceAt: id) values ];
		bandBlock: [ :count | (aTensorRef rowBandSliceFrom: 0 count: count) values ];
		yourself
]

{ #category : 'instance creation' }
GcEmbeddingModel class >> localGpt2 [
	"The LOCAL gpt2 at full f32 precision."
	^ self localGpt2Precision: GcWeightPrecision f32
]

{ #category : 'instance creation' }
GcEmbeddingModel class >> localGpt2Precision: aPrecision [
	"The LOCAL openai-community/gpt2 (124M) wte tensor, optionally simulated at aPrecision. No network."
	| wte lbl |
	wte := GcGpt2Model default tensorNamed: 'wte.weight'.
	lbl := aPrecision isFullPrecision
		ifTrue: [ 'gpt2' ]
		ifFalse: [ 'gpt2@', aPrecision label ].
	^ self fromEmbeddingTensor: wte label: lbl precision: aPrecision
]

{ #category : 'instance creation' }
GcEmbeddingModel class >> remoteLabel: aLabel repository: aRepoId [
	"A REMOTE openai-community size (e.g. gpt2-medium/large). The safetensors header is fetched once over HTTP; each word/band row is then a single HTTP Range GET of just those bytes -- never a whole-file download (I5)."
	| src file wte |
	src := GcHuggingFaceModelSource forRepository: aRepoId.
	file := src safetensorsFile.
	wte := src embeddingTensorIn: file.
	^ self fromEmbeddingTensor: wte label: aLabel precision: GcWeightPrecision f32
]

{ #category : 'accessing' }
GcEmbeddingModel >> bandBlock: aBlock [
	bandBlock := aBlock
]

{ #category : 'computing - baseline' }
GcEmbeddingModel >> baselineComputed [
	^ baselineCache notNil
]

{ #category : 'computing - baseline' }
GcEmbeddingModel >> baselineMean [
	^ self randomPairBaseline at: 1
]

{ #category : 'accessing' }
GcEmbeddingModel >> baselineN [
	^ baselineN
]

{ #category : 'accessing' }
GcEmbeddingModel >> baselineN: anInteger [
	baselineN := anInteger.
	baselineCache := nil
]

{ #category : 'computing - baseline' }
GcEmbeddingModel >> baselinePoolSize [
	"How many contiguous vocabulary rows to sample the random-pair baseline from -- fetched in ONE ranged band read."
	^ (baselinePoolTarget min: vocabSize) max: 1
]

{ #category : 'computing - baseline' }
GcEmbeddingModel >> baselineSampleCount [
	^ self randomPairBaseline at: 3
]

{ #category : 'computing - baseline' }
GcEmbeddingModel >> baselineStd [
	^ self randomPairBaseline at: 2
]

{ #category : 'projection' }
GcEmbeddingModel >> centeredVectors [
	"The word vectors with the centroid subtracted (rows of the PCA data matrix X)."
	| mean wvs |
	mean := self vectorMean.
	wvs := self wordVectors.
	^ wvs collect: [ :wv |
		| v c |
		v := wv vector.
		c := Float64Array new: hiddenDim.
		1 to: hiddenDim do: [ :i | c at: i put: (v at: i) - (mean at: i) ].
		c ]
]

{ #category : 'computing - baseline' }
GcEmbeddingModel >> computeBaseline [
	"Deterministic (seeded by index) random-pair cosine baseline: mean+std cosine over baselineN random distinct pairs among the first baselinePoolSize vocab rows (ONE band read). Returns { mean. std. sampleCount }."
	| pool rows rng sum sumSq mean var i j cij |
	pool := self baselinePoolSize.
	pool < 2 ifTrue: [ ^ { 1.0. 0.0. 0 } ].
	rows := self precisedBandRows: pool.
	rng := Random seed: seed.
	sum := 0.0. sumSq := 0.0.
	baselineN timesRepeat: [
		i := (rng next * pool) truncated + 1.
		j := (rng next * pool) truncated + 1.
		[ i = j ] whileTrue: [ j := (rng next * pool) truncated + 1 ].
		cij := self cosineOfRow: (rows at: i) and: (rows at: j).
		sum := sum + cij.
		sumSq := sumSq + (cij * cij) ].
	mean := sum / baselineN.
	var := (sumSq / baselineN) - (mean * mean).
	var < 0.0 ifTrue: [ var := 0.0 ].
	^ { mean. var sqrt. baselineN }
]

{ #category : 'computing - distances' }
GcEmbeddingModel >> cosineBetweenIndex: i and: j [
	^ (self wordVectorAt: i) cosineTo: (self wordVectorAt: j)
]

{ #category : 'computing - distances' }
GcEmbeddingModel >> cosineMatrix [
	"N x N cosine similarity matrix over the word set (diagonal = 1)."
	| wvs n |
	wvs := self wordVectors.
	n := wvs size.
	^ (1 to: n) collect: [ :i | (1 to: n) collect: [ :j | (wvs at: i) cosineTo: (wvs at: j) ] ]
]

{ #category : 'computing - baseline' }
GcEmbeddingModel >> cosineOfRow: a and: b [
	| d x y denom |
	d := 0.0. x := 0.0. y := 0.0.
	1 to: a size do: [ :i |
		d := d + ((a at: i) * (b at: i)).
		x := x + ((a at: i) * (a at: i)).
		y := y + ((b at: i) * (b at: i)) ].
	denom := x sqrt * y sqrt.
	denom = 0.0 ifTrue: [ ^ 0.0 ].
	^ d / denom
]

{ #category : 'computing - distances' }
GcEmbeddingModel >> distanceMatrix [
	"N x N cosine-distance matrix (1 - cosine) over the word set (diagonal = 0)."
	| wvs n |
	wvs := self wordVectors.
	n := wvs size.
	^ (1 to: n) collect: [ :i | (1 to: n) collect: [ :j | (wvs at: i) distanceTo: (wvs at: j) ] ]
]

{ #category : 'projection - linalg' }
GcEmbeddingModel >> dotArr: a with: b [
	| sum |
	sum := 0.0.
	1 to: a size do: [ :i | sum := sum + ((a at: i) * (b at: i)) ].
	^ sum
]

{ #category : 'gt - views' }
GcEmbeddingModel >> gtCosineMatrixFor: aView [
	<gtView>
	| wvs list |
	wvs := self wordVectors.
	list := aView columnedList
		title: 'Cosine matrix';
		priority: 10;
		items: [ self wordVectors ].
	list column: 'word' text: [ :wv | wv word ].
	wvs doWithIndex: [ :colWv :j |
		list column: colWv word text: [ :rowWv | (rowWv cosineTo: colWv) printShowingDecimalPlaces: 3 ] ].
	^ list
]

{ #category : 'gt - views' }
GcEmbeddingModel >> gtDistanceMatrixFor: aView [
	<gtView>
	| wvs list |
	wvs := self wordVectors.
	list := aView columnedList
		title: 'Distance matrix';
		priority: 12;
		items: [ self wordVectors ].
	list column: 'word' text: [ :wv | wv word ].
	wvs doWithIndex: [ :colWv :j |
		list column: colWv word text: [ :rowWv | (rowWv distanceTo: colWv) printShowingDecimalPlaces: 3 ] ].
	^ list
]

{ #category : 'gt - views' }
GcEmbeddingModel >> gtOverviewFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Overview';
		priority: 30;
		items: [ {
			'label' -> (label ifNil: [ '?' ]).
			'hidden dim' -> hiddenDim printString.
			'vocab size' -> vocabSize printString.
			'precision' -> precision label.
			'words' -> self wordCount printString.
			'baseline mean cos' -> (self baselineComputed ifTrue: [ self baselineMean printShowingDecimalPlaces: 4 ] ifFalse: [ 'pending' ]).
			'baseline std cos' -> (self baselineComputed ifTrue: [ self baselineStd printShowingDecimalPlaces: 4 ] ifFalse: [ 'pending' ]).
			'baseline samples' -> (self baselineComputed ifTrue: [ self baselineSampleCount printString ] ifFalse: [ 'pending' ]) } ];
		column: 'Property' text: [ :a | a key ];
		column: 'Value' text: [ :a | a value ]
]

{ #category : 'gt views' }
GcEmbeddingModel >> gtScatterFor: aView [
	<gtView>
	^ aView explicit
		title: 'Scatter';
		priority: 14;
		stencil: [ self responsiveScatterElement ]
]

{ #category : 'gt - views' }
GcEmbeddingModel >> gtWordsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Words';
		priority: 20;
		items: [ self wordVectors ];
		column: 'Word' text: [ :wv | wv word ];
		column: 'Sub-tokens' text: [ :wv | wv pieces size printString ];
		column: 'Norm' text: [ :wv | wv norm printShowingDecimalPlaces: 3 ]
]

{ #category : 'accessing' }
GcEmbeddingModel >> hiddenDim [
	^ hiddenDim
]

{ #category : 'accessing' }
GcEmbeddingModel >> hiddenDim: anInteger [
	hiddenDim := anInteger
]

{ #category : 'initialization' }
GcEmbeddingModel >> initialize [
	super initialize.
	precision := GcWeightPrecision f32.
	baselineN := 200.
	baselinePoolTarget := 256.
	seed := 1
]

{ #category : 'accessing' }
GcEmbeddingModel >> label [
	^ label
]

{ #category : 'accessing' }
GcEmbeddingModel >> label: aString [
	label := aString
]

{ #category : 'scatter' }
GcEmbeddingModel >> lineFrom: p1 to: p2 extent: anExtent [
	"A thin line element spanning the whole plot so its local coordinate space matches the plot's."
	^ BlElement new
		size: anExtent;
		geometry: (BlLineGeometry from: p1 to: p2);
		outskirts: BlOutskirts outside;
		border: (BlBorder paint: (Color gray alpha: 0.6) width: 1.5);
		yourself
]

{ #category : 'projection - linalg' }
GcEmbeddingModel >> matrixTimesVec: aHiddenVector rows: centeredRows [
	"X . x : an N-vector of per-word dot products of the centred rows with x."
	^ centeredRows collect: [ :row | self dotArr: row with: aHiddenVector ]
]

{ #category : 'computing - rows' }
GcEmbeddingModel >> meanOfRows: aCollectionOfRows [
	"Elementwise mean of the rows as a Float64Array (mean pooling of a word's sub-tokens)."
	| n out |
	n := aCollectionOfRows size.
	out := Float64Array new: hiddenDim.
	aCollectionOfRows do: [ :row |
		1 to: hiddenDim do: [ :i | out at: i put: (out at: i) + (row at: i) ] ].
	n > 0 ifTrue: [ 1 to: hiddenDim do: [ :i | out at: i put: (out at: i) / n ] ].
	^ out
]

{ #category : 'projection - linalg' }
GcEmbeddingModel >> normArr: a [
	^ (self dotArr: a with: a) sqrt
]

{ #category : 'projection - linalg' }
GcEmbeddingModel >> normalizedArr: a [
	| n |
	n := self normArr: a.
	n = 0.0 ifTrue: [ ^ a ].
	^ a collect: [ :each | each / n ]
]

{ #category : 'computing - baseline' }
GcEmbeddingModel >> normalizedScoreFor: aCosine [
	"z-score of aCosine against this model's random-pair baseline, so cross-model cosines are comparable despite different baseline scales."
	| std |
	std := self baselineStd.
	std = 0.0 ifTrue: [ ^ 0.0 ].
	^ (aCosine - self baselineMean) / std
]

{ #category : 'projection - linalg' }
GcEmbeddingModel >> orthogonalizeArr: aVector against: aCollectionOfDirections [
	"Gram-Schmidt: subtract the projection of aVector onto each unit direction."
	| residual |
	residual := aVector.
	aCollectionOfDirections do: [ :d |
		| c |
		c := self dotArr: residual with: d.
		residual := (1 to: residual size) collect: [ :i | (residual at: i) - (c * (d at: i)) ] ].
	^ residual
]

{ #category : 'computing - baseline' }
GcEmbeddingModel >> precisedBandRows: aCount [
	"The first aCount vocab rows (ONE band read), reshaped and precision-applied per row."
	| flat rows base raw |
	flat := bandBlock value: aCount.
	rows := Array new: aCount.
	1 to: aCount do: [ :r |
		base := (r - 1) * hiddenDim.
		raw := Array new: hiddenDim.
		1 to: hiddenDim do: [ :c | raw at: c put: (flat at: base + c) ].
		rows at: r put: (precision apply: raw dimensions: { 1. hiddenDim }) ].
	^ rows
]

{ #category : 'computing - rows' }
GcEmbeddingModel >> precisedRowForId: aTokenId [
	"The raw embedding row for aTokenId, with this model's precision applied per row (dims {1. hiddenDim} makes the single row its own per-row-quantized unit). f32 is the identity."
	^ precision apply: (rowBlock value: aTokenId) dimensions: { 1. hiddenDim }
]

{ #category : 'accessing' }
GcEmbeddingModel >> precision [
	^ precision
]

{ #category : 'accessing' }
GcEmbeddingModel >> precision: aWeightPrecision [
	precision := aWeightPrecision
]

{ #category : 'projection' }
GcEmbeddingModel >> principalDirections2 [
	^ self principalDirections: 2
]

{ #category : 'projection' }
GcEmbeddingModel >> principalDirections: k [
	"Top-k principal directions of the centred word matrix by power iteration on M = X^T X with Gram-Schmidt deflation (reuse of the GcMoeRouter>>principalDirections: idiom). Returns k orthonormal hiddenDim-vectors."
	| rows dirs iterations |
	rows := self centeredVectors.
	dirs := OrderedCollection new.
	iterations := 40.
	1 to: k do: [ :which |
		| x |
		x := self seedVectorOfSize: hiddenDim.
		iterations timesRepeat: [
			| mx |
			mx := self transposeTimesVec: (self matrixTimesVec: x rows: rows) rows: rows.
			mx := self orthogonalizeArr: mx against: dirs.
			x := self normalizedArr: mx ].
		dirs add: (self normalizedArr: (self orthogonalizeArr: x against: dirs)) ].
	^ dirs asArray
]

{ #category : 'printing' }
GcEmbeddingModel >> printOn: aStream [
	aStream nextPutAll: self class name; nextPutAll: '('.
	aStream nextPutAll: (label ifNil: [ '?' ]).
	aStream nextPutAll: ' d='; print: hiddenDim; nextPutAll: ')'
]

{ #category : 'projection' }
GcEmbeddingModel >> projectedPoints [
	"Each word as { word. x. y } projected onto the top-2 principal directions of the word set -- the 2D scatter coordinates."
	| rows dirs wvs d1 d2 |
	wvs := self wordVectors.
	wvs size < 1 ifTrue: [ ^ #() ].
	rows := self centeredVectors.
	dirs := self principalDirections2.
	d1 := dirs at: 1.
	d2 := dirs at: 2.
	^ (1 to: wvs size) collect: [ :i |
		| c |
		c := rows at: i.
		{ (wvs at: i) word. (self dotArr: c with: d1). (self dotArr: c with: d2) } ]
]

{ #category : 'computing - baseline' }
GcEmbeddingModel >> randomPairBaseline [
	^ baselineCache ifNil: [ baselineCache := self computeBaseline ]
]

{ #category : 'private - views' }
GcEmbeddingModel >> renderScatterPlotInto: container extent: anExtent [
	"(Re)build the scatter's pairing lines, dots and labels sized to anExtent; called on each extent change so the plot fills and rescales with the pane."
	| pts n w h pad xs ys minX maxX minY maxY spanX spanY px py |
	w := anExtent x. h := anExtent y.
	(w < 2 or: [ h < 2 ]) ifTrue: [ ^ self ].
	container removeChildren.
	pts := self projectedPoints.
	n := pts size.
	(n < 1 or: [ hiddenDim < 2 ]) ifTrue: [ ^ self ].
	pad := 46.
	xs := pts collect: [ :p | p at: 2 ].
	ys := pts collect: [ :p | p at: 3 ].
	minX := xs min. maxX := xs max. minY := ys min. maxY := ys max.
	spanX := maxX - minX. spanX = 0 ifTrue: [ spanX := 1.0 ].
	spanY := maxY - minY. spanY = 0 ifTrue: [ spanY := 1.0 ].
	px := Array new: n. py := Array new: n.
	1 to: n do: [ :i |
		px at: i put: pad + (((xs at: i) - minX) / spanX * (w - (2 * pad))).
		py at: i put: h - pad - (((ys at: i) - minY) / spanY * (h - (2 * pad))) ].
	n even ifTrue: [
		1 to: n // 2 do: [ :k |
			| a b |
			a := 2 * k - 1. b := 2 * k.
			container addChild: (self lineFrom: (px at: a) @ (py at: a) to: (px at: b) @ (py at: b) extent: w @ h) ] ].
	1 to: n do: [ :i |
		| word dotEl lblEl |
		word := (pts at: i) at: 1.
		dotEl := BlElement new
			geometry: BlCircleGeometry new;
			size: 11 @ 11;
			background: (Color r: 0.15 g: 0.4 b: 0.85);
			position: ((px at: i) - 5.5) @ ((py at: i) - 5.5);
			yourself.
		lblEl := BlTextElement new
			text: (word asRopedText foreground: Color black);
			position: ((px at: i) + 8) @ ((py at: i) - 8);
			yourself.
		container addChild: dotEl.
		container addChild: lblEl ]
]

{ #category : 'private - views' }
GcEmbeddingModel >> responsiveScatterElement [
	"Like scatterElement but the plot FILLS the pane and rescales with the window; used only by the single-view gtScatterFor:. The fixed-size scatterElement is kept for the small-multiples tiles."
	| caption |
	caption := BlTextElement new text: (self scatterCaption asRopedText foreground: Color gray darker).
	^ BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal matchParent. c vertical matchParent ];
		padding: (BlInsets all: 8);
		addChild: caption;
		addChild: self responsiveScatterPlotElement;
		yourself
]

{ #category : 'private - views' }
GcEmbeddingModel >> responsiveScatterPlotElement [
	"A pane-filling (matchParent) version of scatterPlotElement: point pixel positions are recomputed from the container's actual extent on every BlElementExtentChangedEvent so the plot rescales with the window. Kept separate from scatterPlotElement, which the fixed-size small-multiples tiles need."
	| container |
	container := BlElement new
		constraintsDo: [ :c |
			c horizontal matchParent.
			c vertical matchParent.
			c minWidth: 320.
			c minHeight: 240 ];
		background: Color white;
		border: (BlBorder paint: (Color gray alpha: 0.4) width: 1);
		yourself.
	self renderScatterPlotInto: container extent: 600 @ 440.
	container addEventHandlerOn: BlElementExtentChangedEvent
		do: [ :e | self renderScatterPlotInto: container extent: e currentTarget extent ].
	^ container
]

{ #category : 'accessing' }
GcEmbeddingModel >> rowBlock: aBlock [
	rowBlock := aBlock
]

{ #category : 'scatter' }
GcEmbeddingModel >> scatterCaption [
	^ 'PCA (2D) of ', self wordCount printString, ' ', (label ifNil: [ '?' ]), ' word embeddings -- top-2 principal directions; lines pair consecutive words'
]

{ #category : 'scatter' }
GcEmbeddingModel >> scatterElement [
	| caption |
	caption := BlTextElement new text: (self scatterCaption asRopedText foreground: Color gray darker).
	^ BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		padding: (BlInsets all: 8);
		addChild: caption;
		addChild: self scatterPlotElement;
		yourself
]

{ #category : 'scatter' }
GcEmbeddingModel >> scatterPlotElement [
	| pts w h pad xs ys minX maxX minY maxY spanX spanY px py container n |
	pts := self projectedPoints.
	n := pts size.
	w := 460. h := 340. pad := 46.
	container := BlElement new
		size: w @ h;
		background: Color white;
		border: (BlBorder paint: (Color gray alpha: 0.4) width: 1);
		yourself.
	(n < 1 or: [ hiddenDim < 2 ]) ifTrue: [ ^ container ].
	xs := pts collect: [ :p | p at: 2 ].
	ys := pts collect: [ :p | p at: 3 ].
	minX := xs min. maxX := xs max. minY := ys min. maxY := ys max.
	spanX := maxX - minX. spanX = 0 ifTrue: [ spanX := 1.0 ].
	spanY := maxY - minY. spanY = 0 ifTrue: [ spanY := 1.0 ].
	px := Array new: n. py := Array new: n.
	1 to: n do: [ :i |
		px at: i put: pad + (((xs at: i) - minX) / spanX * (w - (2 * pad))).
		py at: i put: h - pad - (((ys at: i) - minY) / spanY * (h - (2 * pad))) ].
	n even ifTrue: [
		1 to: n // 2 do: [ :k |
			| a b |
			a := 2 * k - 1. b := 2 * k.
			container addChild: (self lineFrom: (px at: a) @ (py at: a) to: (px at: b) @ (py at: b) extent: w @ h) ] ].
	1 to: n do: [ :i |
		| word dotEl lblEl |
		word := (pts at: i) at: 1.
		dotEl := BlElement new
			geometry: BlCircleGeometry new;
			size: 11 @ 11;
			background: (Color r: 0.15 g: 0.4 b: 0.85);
			position: ((px at: i) - 5.5) @ ((py at: i) - 5.5);
			yourself.
		lblEl := BlTextElement new
			text: (word asRopedText foreground: Color black);
			position: ((px at: i) + 8) @ ((py at: i) - 8);
			yourself.
		container addChild: dotEl.
		container addChild: lblEl ].
	^ container
]

{ #category : 'accessing' }
GcEmbeddingModel >> seed [
	^ seed
]

{ #category : 'accessing' }
GcEmbeddingModel >> seed: anInteger [
	seed := anInteger.
	baselineCache := nil
]

{ #category : 'projection - linalg' }
GcEmbeddingModel >> seedVectorOfSize: d [
	"A deterministic (seed-42) unit start vector so power iteration is reproducible."
	| rng x |
	rng := Random seed: 42.
	x := (1 to: d) collect: [ :i | rng next - 0.5 ].
	^ self normalizedArr: x
]

{ #category : 'projection - linalg' }
GcEmbeddingModel >> transposeTimesVec: anNVector rows: centeredRows [
	"X^T . y : a hiddenSize-vector, so M.x = X^T (X x) without materialising X^T X."
	| acc n |
	acc := Float64Array new: hiddenDim.
	n := centeredRows size.
	1 to: n do: [ :r |
		| yr row |
		yr := anNVector at: r.
		row := centeredRows at: r.
		1 to: hiddenDim do: [ :i | acc at: i put: (acc at: i) + (yr * (row at: i)) ] ].
	^ acc
]

{ #category : 'projection' }
GcEmbeddingModel >> vectorMean [
	"Elementwise mean over the word vectors (the centroid used to centre the PCA)."
	| wvs n out |
	wvs := self wordVectors.
	n := wvs size.
	out := Float64Array new: hiddenDim.
	n = 0 ifTrue: [ ^ out ].
	wvs do: [ :wv | | v | v := wv vector. 1 to: hiddenDim do: [ :i | out at: i put: (out at: i) + (v at: i) ] ].
	1 to: hiddenDim do: [ :i | out at: i put: (out at: i) / n ].
	^ out
]

{ #category : 'accessing' }
GcEmbeddingModel >> vocabSize [
	^ vocabSize
]

{ #category : 'accessing' }
GcEmbeddingModel >> vocabSize: anInteger [
	vocabSize := anInteger
]

{ #category : 'computing - words' }
GcEmbeddingModel >> wordCount [
	^ (wordSpecs ifNil: [ #() ]) size
]

{ #category : 'accessing' }
GcEmbeddingModel >> wordSpecs [
	^ wordSpecs
]

{ #category : 'accessing' }
GcEmbeddingModel >> wordSpecs: aCollectionOfSpecs [
	"Each spec is { word. tokenIds. pieces }."
	wordSpecs := aCollectionOfSpecs.
	wordVectorsCache := nil
]

{ #category : 'computing - words' }
GcEmbeddingModel >> wordVectorAt: anIndex [
	^ self wordVectors at: anIndex
]

{ #category : 'computing - words' }
GcEmbeddingModel >> wordVectorForSpec: aSpec [
	"aSpec = { word. tokenIds. pieces } -> a GcWordVector for THIS model."
	| ids rows vec |
	ids := aSpec at: 2.
	rows := ids collect: [ :id | self precisedRowForId: id ].
	vec := self meanOfRows: rows.
	^ GcWordVector word: (aSpec at: 1) tokenIds: ids pieces: (aSpec at: 3) vector: vec
]

{ #category : 'computing - words' }
GcEmbeddingModel >> wordVectors [
	^ wordVectorsCache ifNil: [
		wordVectorsCache := (wordSpecs ifNil: [ #() ]) collect: [ :spec | self wordVectorForSpec: spec ] ]
]

{ #category : 'computing - words' }
GcEmbeddingModel >> words [
	^ (wordSpecs ifNil: [ #() ]) collect: [ :spec | spec first ]
]
