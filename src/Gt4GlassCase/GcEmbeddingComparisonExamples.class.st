"
Executable documentation for the cross-model word-embedding distance explorer (GcEmbeddingComparison and friends). Hermetic <gtExample> methods prove the cosine / mean-pool math, the distance matrix, the 2D PCA scatter, the random-pair baseline, and the cross-model summary on tiny synthetic models with NO network and NO real GPT-2 file. The <noTest> examples exercise the real LOCAL gpt2 (f32 + int4) and the REMOTE gpt2-medium/large HTTP single-row range reads, reporting how cos(' France',' Paris') moves with model size and quantization.
"
Class {
	#name : 'GcEmbeddingComparisonExamples',
	#superclass : 'Object',
	#category : 'Gt4GlassCase-Embedding',
	#package : 'Gt4GlassCase',
	#tag : 'Embedding'
}

{ #category : 'private - synthetic' }
GcEmbeddingComparisonExamples >> alignedParallelMatrix [
	"Four unit word rows (dim 3) engineered so the two consecutive pair displacements are EXACTLY parallel and equal after unit-normalization: (w1->w2) = (w3->w4) = (-1,1,0). The countries (w1,w3) and capitals (w2,w4) are DISTINCT points and the country-contrast (w1-w3) is non-degenerate, so the aligned projection must yield two horizontal, equal-length arrows. 0.7071067811865476 = sqrt(1/2)."
	^ { #(1.0 0.0 0.0).
		#(0.0 1.0 0.0).
		#(0.5 -0.5 0.7071067811865476).
		#(-0.5 0.5 0.7071067811865476) }
]

{ #category : 'examples' }
GcEmbeddingComparisonExamples >> alignedScattersExample [
	<gtExample>
	"Hermetic: gtAlignedScattersFor: projects every model into a SHARED, semantically-anchored, same-scale frame. Proves (1) a model whose pair differences are exactly parallel & equal yields horizontal, equal-length country->capital arrows; (2) a single shared bound R bounds every tile and is 1.1x the global max coordinate; (3) the view element builds one aligned tile per model. No network, no real GPT-2."
	| parallel proj a1x a1y a2x a2y len1 len2 comparison r maxA maxB element |
	parallel := GcEmbeddingComparison
		wordSpecs: self syntheticSpecs
		models: { self syntheticModelLabel: 'par' matrix: self alignedParallelMatrix }.
	proj := parallel alignedProjectionFor: parallel models first.
	self assert: proj size equals: 4.
	a1x := ((proj at: 2) at: 2) - ((proj at: 1) at: 2).
	a1y := ((proj at: 2) at: 3) - ((proj at: 1) at: 3).
	a2x := ((proj at: 4) at: 2) - ((proj at: 3) at: 2).
	a2y := ((proj at: 4) at: 3) - ((proj at: 3) at: 3).
	self assert: a1y abs closeTo: 0.0 within: 1.0e-6.
	self assert: a2y abs closeTo: 0.0 within: 1.0e-6.
	self assert: a1x > 0.0.
	self assert: a2x > 0.0.
	len1 := ((a1x * a1x) + (a1y * a1y)) sqrt.
	len2 := ((a2x * a2x) + (a2y * a2y)) sqrt.
	self assert: len1 closeTo: len2 within: 1.0e-6.
	comparison := GcEmbeddingComparison
		wordSpecs: self syntheticSpecs
		models: { self syntheticModelLabel: 'A' matrix: self syntheticMatrixA.
			self syntheticModelLabel: 'B' matrix: self syntheticMatrixB }.
	r := comparison alignedSharedBound.
	self assert: r > 0.0.
	maxA := self maxAbsCoordOf: (comparison alignedProjectionFor: comparison models first).
	maxB := self maxAbsCoordOf: (comparison alignedProjectionFor: comparison models second).
	self assert: maxA <= (r + 1.0e-9).
	self assert: maxB <= (r + 1.0e-9).
	self assert: r closeTo: ((maxA max: maxB) * 1.1) within: 1.0e-6.
	self assert: (comparison gtAlignedScattersFor: GtPhlowView empty) notNil.
	element := comparison alignedScattersElement.
	self assert: (element isKindOf: BlElement).
	self assert: element children size equals: 2.
	self assert: (element children allSatisfy: [ :tile | tile isKindOf: BlElement ]).
	^ comparison
]

{ #category : 'asserting' }
GcEmbeddingComparisonExamples >> assert: actual closeTo: expected [
	(actual - expected) abs <= 1.0e-9
		ifFalse: [ self error: 'expected ', expected printString, ' but got ', actual printString ]
]

{ #category : 'asserting' }
GcEmbeddingComparisonExamples >> assert: actual closeTo: expected within: tol [
	(actual - expected) abs <= tol
		ifFalse: [ self error: 'expected ', expected printString, ' but got ', actual printString ]
]

{ #category : 'examples - hermetic' }
GcEmbeddingComparisonExamples >> cosineOfKnownVectorsExample [
	<gtExample>
	"Cosine + distance on tiny hand-computed vectors: cos(#(1 0 0), #(1 1 0)) = 1/sqrt(2)."
	| a b |
	a := GcWordVector word: 'a' tokenIds: #(1) pieces: #('a') vector: #(1.0 0.0 0.0).
	b := GcWordVector word: 'b' tokenIds: #(2) pieces: #('b') vector: #(1.0 1.0 0.0).
	self assert: (a cosineTo: b) closeTo: 2 sqrt reciprocal.
	self assert: (a distanceTo: b) closeTo: 1.0 - 2 sqrt reciprocal.
	self assert: (a cosineTo: a) closeTo: 1.0.
	self assert: b norm closeTo: 2 sqrt.
	^ { a. b }
]

{ #category : 'examples - local e2e' }
GcEmbeddingComparisonExamples >> localGpt2PrecisionComparisonExample [
	<gtExample>
	<noTest>
	"LOCAL e2e (no network): the default 4 words across gpt2 f32 and gpt2 int4. Proves each model yields a 4x4 matrix and the summary builds, and pins how int4 quantization moves cos(' France',' Paris')."
	| comparison pairs franceParis cosF32 cosInt4 |
	comparison := GcEmbeddingComparison
		words: GcEmbeddingComparison defaultWords
		models: { GcEmbeddingModel localGpt2. GcEmbeddingModel localGpt2Precision: GcWeightPrecision int4 }.
	self assert: comparison models size equals: 2.
	comparison models do: [ :m |
		self assert: m wordVectors size equals: 4.
		self assert: m cosineMatrix size equals: 4.
		self assert: m hiddenDim equals: 768 ].
	pairs := comparison wordPairDistances.
	self assert: pairs size equals: 6.
	franceParis := pairs first.
	self assert: franceParis wordA equals: ' France'.
	self assert: franceParis wordB equals: ' Paris'.
	cosF32 := franceParis cosineForModelIndex: 1.
	cosInt4 := franceParis cosineForModelIndex: 2.
	self assert: cosF32 closeTo: 0.6344057138813657 within: 1.0e-9.
	self assert: cosInt4 closeTo: 0.6125026804107724 within: 1.0e-6.
	self assert: (cosF32 - cosInt4) abs > 1.0e-4.
	self assert: (comparison gtSummaryFor: GtPhlowView empty) notNil.
	^ comparison
]

{ #category : 'private - synthetic' }
GcEmbeddingComparisonExamples >> maxAbsCoordOf: aProjection [
	"Max |coordinate| over a projection's { word. x. y } points."
	| m |
	m := 0.0.
	aProjection do: [ :pt |
		m := m max: (pt at: 2) abs.
		m := m max: (pt at: 3) abs ].
	^ m
]

{ #category : 'examples - hermetic' }
GcEmbeddingComparisonExamples >> meanPoolExample [
	<gtExample>
	"A word with two sub-tokens (ids 0 and 2) mean-pools to the elementwise mean of rows 0 and 2."
	| model wv |
	model := self syntheticModelLabel: 'syn' matrix: self syntheticMatrixA.
	wv := model wordVectorForSpec: { 'w02'. #(0 2). #(' w0' ' w2') }.
	self assert: wv dimension equals: 4.
	self assert: (wv vector at: 1) closeTo: 0.5.
	self assert: (wv vector at: 2) closeTo: 0.5.
	self assert: (wv vector at: 3) closeTo: 0.0.
	self assert: (wv vector at: 4) closeTo: 0.05.
	^ wv
]

{ #category : 'examples - network e2e' }
GcEmbeddingComparisonExamples >> remoteSizeComparisonExample [
	<gtExample>
	<noTest>
	"NETWORK e2e: the default 4 words across gpt2 (local), gpt2-medium and gpt2-large, the two remote sizes read via HTTP single-row RANGE GETs (never a whole-file download). Reports how cos(' France',' Paris') moves with model size."
	| models comparison pairs franceParis |
	models := OrderedCollection new.
	models add: GcEmbeddingModel localGpt2.
	models add: (GcEmbeddingModel remoteLabel: 'gpt2-medium' repository: 'openai-community/gpt2-medium').
	models add: (GcEmbeddingModel remoteLabel: 'gpt2-large' repository: 'openai-community/gpt2-large').
	comparison := GcEmbeddingComparison words: GcEmbeddingComparison defaultWords models: models asArray.
	self assert: comparison models size equals: 3.
	self assert: comparison models first hiddenDim equals: 768.
	self assert: comparison models second hiddenDim equals: 1024.
	self assert: comparison models third hiddenDim equals: 1280.
	comparison models do: [ :m | self assert: m wordVectors size equals: 4 ].
	pairs := comparison wordPairDistances.
	self assert: pairs size equals: 6.
	franceParis := pairs first.
	self assert: franceParis wordA equals: ' France'.
	self assert: ((franceParis cosineForModelIndex: 2) between: 0.0 and: 1.0).
	self assert: (comparison gtSummaryFor: GtPhlowView empty) notNil.
	^ comparison
]

{ #category : 'examples' }
GcEmbeddingComparisonExamples >> scattersOverviewExample [
	<gtExample>
	"Hermetic: gtScattersFor: builds a small-multiples element with one scatter tile per model, all at once, with no network and no real GPT-2 file. Two synthetic models -> two tiles."
	| comparison element |
	comparison := GcEmbeddingComparison
		wordSpecs: self syntheticSpecs
		models: { self syntheticModelLabel: 'A' matrix: self syntheticMatrixA.
			self syntheticModelLabel: 'B' matrix: self syntheticMatrixB }.
	self assert: comparison models size equals: 2.
	self assert: (comparison gtScattersFor: GtPhlowView empty) notNil.
	element := comparison allScattersElement.
	self assert: (element isKindOf: BlElement).
	self assert: element children size equals: 2.
	self assert: (element children allSatisfy: [ :tile | tile isKindOf: BlElement ]).
	self assert: (element children first childrenCount) >= 2.
	^ comparison
]

{ #category : 'examples - hermetic' }
GcEmbeddingComparisonExamples >> summaryTableExample [
	<gtExample>
	"The cross-model summary builds for two synthetic models: C(4,2)=6 word-pairs, each with a per-model measurement (cosine, distance, z), distances differ across models, and the summary + models + pair views build."
	| comparison pairs meas |
	comparison := GcEmbeddingComparison
		wordSpecs: self syntheticSpecs
		models: { self syntheticModelLabel: 'A' matrix: self syntheticMatrixA.
			self syntheticModelLabel: 'B' matrix: self syntheticMatrixB }.
	pairs := comparison wordPairDistances.
	self assert: pairs size equals: 6.
	meas := pairs first measurements.
	self assert: meas size equals: 2.
	self assert: ((meas first) at: 1) label equals: 'A'.
	self assert: (((meas first) at: 2) between: -1.0001 and: 1.0001).
	self assert: ((meas first) at: 3) closeTo: 1.0 - ((meas first) at: 2).
	self assert: ((meas first) at: 4) isNumber.
	self assert: (pairs anySatisfy: [ :p | ((p cosineForModelIndex: 1) - (p cosineForModelIndex: 2)) abs > 1.0e-6 ]).
	self assert: (comparison gtSummaryFor: GtPhlowView empty) notNil.
	self assert: (comparison gtModelsFor: GtPhlowView empty) notNil.
	self assert: (pairs first gtAcrossModelsFor: GtPhlowView empty) notNil.
	^ comparison
]

{ #category : 'fixtures' }
GcEmbeddingComparisonExamples >> syntheticMatrixA [
	"6 synthetic vocab rows of dim 4 (ids 0..5); the first 4 are the word rows."
	^ { #(1.0 0.0 0.0 0.1).
		#(0.8 0.2 0.0 0.0).
		#(0.0 1.0 0.0 0.0).
		#(0.1 0.8 0.2 0.0).
		#(0.2 0.1 1.0 0.3).
		#(0.0 0.0 0.4 1.0) }
]

{ #category : 'fixtures' }
GcEmbeddingComparisonExamples >> syntheticMatrixB [
	"A DIFFERENT synthetic geometry so cross-model distances vary."
	^ { #(0.2 1.0 0.0 0.0).
		#(0.1 0.9 0.2 0.0).
		#(1.0 0.1 0.0 0.0).
		#(0.9 0.0 0.1 0.2).
		#(0.0 0.2 1.0 0.1).
		#(0.3 0.0 0.5 1.0) }
]

{ #category : 'examples - hermetic' }
GcEmbeddingComparisonExamples >> syntheticModelExample [
	<gtExample>
	"A synthetic GcEmbeddingModel: word vectors, cosine/distance matrix, 2D PCA scatter and random-pair baseline all build with no network."
	| model cm dm dirs pts baseline |
	model := self syntheticModelLabel: 'synA' matrix: self syntheticMatrixA.
	model wordSpecs: self syntheticSpecs; seed: 1.
	self assert: model wordVectors size equals: 4.
	cm := model cosineMatrix.
	self assert: cm size equals: 4.
	1 to: 4 do: [ :i | self assert: ((cm at: i) at: i) closeTo: 1.0 ].
	self assert: ((cm at: 1) at: 2) closeTo: ((cm at: 2) at: 1).
	dm := model distanceMatrix.
	1 to: 4 do: [ :i | self assert: ((dm at: i) at: i) closeTo: 0.0 ].
	dirs := model principalDirections2.
	self assert: dirs size equals: 2.
	self assert: (model dotArr: (dirs at: 1) with: (dirs at: 1)) closeTo: 1.0 within: 1.0e-6.
	self assert: (model dotArr: (dirs at: 1) with: (dirs at: 2)) closeTo: 0.0 within: 1.0e-6.
	pts := model projectedPoints.
	self assert: pts size equals: 4.
	self assert: (model scatterElement isKindOf: BlElement).
	self assert: (model gtScatterFor: GtPhlowView empty) notNil.
	self assert: (model gtCosineMatrixFor: GtPhlowView empty) notNil.
	self assert: (model gtDistanceMatrixFor: GtPhlowView empty) notNil.
	baseline := model randomPairBaseline.
	self assert: ((baseline at: 1) between: -1.0001 and: 1.0001).
	self assert: (baseline at: 2) >= 0.0.
	self assert: (baseline at: 3) equals: 200.
	^ model
]

{ #category : 'fixtures' }
GcEmbeddingComparisonExamples >> syntheticModelLabel: aLabel matrix: rows [
	"A GcEmbeddingModel whose rows come from an in-memory matrix (id is 0-based). No network, no real model."
	| d |
	d := rows first size.
	^ GcEmbeddingModel new
		label: aLabel;
		hiddenDim: d;
		vocabSize: rows size;
		precision: GcWeightPrecision f32;
		rowBlock: [ :id | rows at: id + 1 ];
		bandBlock: [ :count |
			| flat |
			flat := Array new: count * d.
			1 to: count do: [ :r |
				| row base |
				row := rows at: r.
				base := (r - 1) * d.
				1 to: d do: [ :c | flat at: base + c put: (row at: c) ] ].
			flat ];
		yourself
]

{ #category : 'fixtures' }
GcEmbeddingComparisonExamples >> syntheticSpecs [
	"Four single-token synthetic words mapping to vocab ids 0..3."
	^ { { 'w0'. #(0). #('w0') }.
		{ 'w1'. #(1). #('w1') }.
		{ 'w2'. #(2). #('w2') }.
		{ 'w3'. #(3). #('w3') } }
]
