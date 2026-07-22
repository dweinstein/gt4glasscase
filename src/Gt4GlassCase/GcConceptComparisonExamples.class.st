"
Executable documentation for the cross-model concept comparison (GcConceptComparison and GcConceptDriftRow). Hermetic <gtExample> methods build TWO synthetic GcEmbeddingModels (reusing GcEmbeddingComparisonExamples>>syntheticModelLabel:matrix: and GcConceptSpaceExamples>>syntheticConcepts/syntheticConceptSpecs, no network, no real gpt2) whose geometries are deliberately engineered so concepts A and B are near-identical in 'modelX' (cosine ~1.0) but near-orthogonal in 'modelY' (cosine ~0.0) -- a PLANTED disagreement -- and prove the drift table surfaces that pair first (max spread), every measurement is finite, and the per-model GcConceptSpaces have the right concept/word counts. A <noTest> example builds GcConceptComparison defaultGpt2Sizes across the real LOCAL gpt2 and REMOTE gpt2-medium/large.
"
Class {
	#name : 'GcConceptComparisonExamples',
	#superclass : 'Object',
	#category : 'Gt4GlassCase-Embedding',
	#package : 'Gt4GlassCase',
	#tag : 'Embedding'
}

{ #category : 'testing' }
GcConceptComparisonExamples >> assert: actual closeTo: expected within: tol [
	(actual - expected) abs <= tol
		ifFalse: [ self error: 'expected ', expected printString, ' but got ', actual printString ]
]

{ #category : 'examples' }
GcConceptComparisonExamples >> remoteGpt2SizesConceptComparisonExample [
	<gtExample>
	<noTest>
	"NETWORK e2e: the 7 default concepts across gpt2-124M (local) and gpt2-medium/gpt2-large (remote, single-row HTTP Range reads only -- no weight download). Forces one drift computation and reports the headline (highest cross-model spread) concept pair."
	| comparison top |
	comparison := GcConceptComparison defaultGpt2Sizes.
	self assert: comparison concepts size equals: 7.
	self assert: comparison entries size equals: 3.
	top := comparison driftRows first.
	self assert: top spread >= 0.0.
	self assert: (comparison gtDriftFor: GtPhlowView empty) notNil.
	self assert: (comparison gtAtlasesFor: GtPhlowView empty) notNil.
	self assert: (comparison gtCoherenceFor: GtPhlowView empty) notNil.
	self assert: (comparison gtModelsFor: GtPhlowView empty) notNil.
	^ comparison
]

{ #category : 'examples' }
GcConceptComparisonExamples >> syntheticAtlasesExample [
	<gtExample>
	"The aligned concept-atlas element builds as a BlElement with one tile per model, and gtAtlasesFor:/gtModelsFor: render."
	| comparison element |
	comparison := self syntheticConceptComparison.
	element := comparison alignedConceptAtlasesElement.
	self assert: (element isKindOf: BlElement).
	self assert: element children size equals: 2.
	self assert: comparison alignedConceptSharedBound > 0.0.
	self assert: (comparison gtAtlasesFor: GtPhlowView empty) notNil.
	self assert: (comparison gtModelsFor: GtPhlowView empty) notNil.
	^ comparison
]

{ #category : 'examples' }
GcConceptComparisonExamples >> syntheticCoherenceExample [
	<gtExample>
	"Every concept's coherence is a finite cosine in EVERY model, and the cross-model spread is well-defined."
	| comparison |
	comparison := self syntheticConceptComparison.
	comparison concepts do: [ :c |
		comparison labels do: [ :lbl |
			| coh |
			coh := comparison coherenceFor: c inLabel: lbl.
			self assert: coh isNaN not.
			self assert: (coh between: -1.0001 and: 1.0001) ].
		self assert: (comparison coherenceSpreadFor: c) >= -0.0001 ].
	self assert: (comparison gtCoherenceFor: GtPhlowView empty) notNil.
	^ comparison
]

{ #category : 'examples' }
GcConceptComparisonExamples >> syntheticConceptComparison [
	<gtExample>
	"A GcConceptComparison over TWO synthetic GcEmbeddingModels sharing the GcConceptSpaceExamples 3-concept fixture (A={w0,w1}, B={w2,w3}, C={w4,w5}), reusing GcEmbeddingComparisonExamples>>syntheticModelLabel:matrix: -- no network, no real gpt2."
	| specExamples concepts specs modelX modelY comparison |
	specExamples := GcConceptSpaceExamples new.
	concepts := specExamples syntheticConcepts.
	specs := specExamples syntheticConceptSpecs.
	modelX := GcEmbeddingComparisonExamples new syntheticModelLabel: 'modelX' matrix: self syntheticMatrixX.
	modelY := GcEmbeddingComparisonExamples new syntheticModelLabel: 'modelY' matrix: self syntheticMatrixY.
	comparison := GcConceptComparison
		concepts: concepts
		wordSpecs: specs
		models: { 'modelX' -> modelX. 'modelY' -> modelY }.
	self assert: comparison concepts size equals: 3.
	self assert: comparison entries size equals: 2.
	self assert: comparison labels asArray equals: #('modelX' 'modelY').
	self assert: (comparison spaceForLabel: 'modelX') concepts size equals: 3.
	self assert: (comparison spaceForLabel: 'modelY') allWords size equals: 6.
	^ comparison
]

{ #category : 'examples' }
GcConceptComparisonExamples >> syntheticDriftExample [
	<gtExample>
	"The drift table surfaces the PLANTED A~B disagreement first (max spread ~1.0: cosine ~1.0 in modelX, ~0.0 in modelY), and every measurement is a finite cosine."
	| comparison top |
	comparison := self syntheticConceptComparison.
	top := comparison driftRows first.
	self assert: comparison driftRows size equals: 3.
	self assert: (top conceptA name = 'A' or: [ top conceptA name = 'B' ]).
	self assert: (top conceptB name = 'A' or: [ top conceptB name = 'B' ]).
	self assert: top conceptA name ~= top conceptB name.
	self assert: (top cosineForLabel: 'modelX') closeTo: 1.0 within: 1.0e-4.
	self assert: (top cosineForLabel: 'modelY') closeTo: 0.0 within: 1.0e-4.
	self assert: top spread closeTo: 1.0 within: 1.0e-4.
	self assert: top maxLabel equals: 'modelX'.
	self assert: top minLabel equals: 'modelY'.
	comparison driftRows do: [ :row |
		row measurements do: [ :m |
			| c |
			c := m at: 3.
			self assert: c isNaN not.
			self assert: (c between: -1.0001 and: 1.0001) ] ].
	self assert: (comparison gtDriftFor: GtPhlowView empty) notNil.
	self assert: (top gtAcrossModelsFor: GtPhlowView empty) notNil.
	self assert: (top gtConceptsFor: GtPhlowView empty) notNil.
	^ comparison
]

{ #category : 'fixtures' }
GcConceptComparisonExamples >> syntheticMatrixX [
	"Concept A={w0,w1} and concept B={w2,w3} are given NEAR-IDENTICAL rows -- their centroids coincide (cosine ~1.0) in this synthetic model."
	^ { #(1.0 0.0 0.0 0.0).
		#(0.9 0.1 0.0 0.0).
		#(1.0 0.0 0.0 0.0).
		#(0.9 0.1 0.0 0.0).
		#(0.0 1.0 0.0 0.0).
		#(0.0 0.0 1.0 0.0) }
]

{ #category : 'fixtures' }
GcConceptComparisonExamples >> syntheticMatrixY [
	"A DIFFERENT geometry: concept B={w2,w3} is moved to a near-orthogonal region of space, so cosine(A,B) collapses to ~0.0 -- a PLANTED disagreement with syntheticMatrixX's ~1.0."
	^ { #(1.0 0.0 0.0 0.0).
		#(0.9 0.1 0.0 0.0).
		#(0.0 0.0 1.0 0.0).
		#(0.0 0.0 0.9 0.1).
		#(0.0 1.0 0.0 0.0).
		#(0.0 0.0 1.0 0.0) }
]
