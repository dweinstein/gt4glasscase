"
Executable documentation for the Stage A concept explorer (GcConcept + GcConceptSpace). A hermetic <gtExample> builds a SYNTHETIC GcConceptSpace over tiny known vectors (reusing GcEmbeddingComparisonExamples>>syntheticModelLabel:matrix:) and proves the unit centroids, the inter-concept cosine matrix (to 1e-6) and that gtAtlasFor:'s element builds with one point per member word and the right number of distinct colors -- no network, no real GPT-2. A <noTest> example builds GcConceptSpace defaultGpt2 on the LOCAL gpt2 and reports the real inter-concept centroid cosine matrix.
"
Class {
	#name : 'GcConceptSpaceExamples',
	#superclass : 'Object',
	#category : 'Gt4GlassCase-Embedding',
	#package : 'Gt4GlassCase',
	#tag : 'Embedding'
}

{ #category : 'asserting' }
GcConceptSpaceExamples >> assert: actual closeTo: expected within: tol [
	(actual - expected) abs <= tol
		ifFalse: [ self error: 'expected ', expected printString, ' but got ', actual printString ]
]

{ #category : 'synthetic data' }
GcConceptSpaceExamples >> conceptMatrix [
	"Six synthetic vocab rows of dim 4 (ids 0..5). Concept A={w0,w1}, B={w2,w3}, C={w4,w5}."
	^ { #(1.0 0.0 0.0 0.0).
		#(0.0 1.0 0.0 0.0).
		#(0.0 0.0 1.0 0.0).
		#(0.0 0.0 0.0 1.0).
		#(1.0 1.0 0.0 0.0).
		#(1.0 0.0 0.0 0.0) }
]

{ #category : 'examples' }
GcConceptSpaceExamples >> defaultGpt2ConceptSpaceExample [
	<gtExample>
	<noTest>
	"The 7-concept default set on the LOCAL gpt2 (no network). Builds, renders the atlas, and reports the real inter-concept centroid cosine matrix."
	| space cm |
	space := GcConceptSpace defaultGpt2.
	self assert: space concepts size equals: 7.
	self assert: (space atlasElement isKindOf: BlElement).
	self assert: space atlasWordCount equals: space allWords size.
	self assert: space atlasConceptColors size equals: 7.
	cm := space cosineMatrix.
	self assert: cm size equals: 7.
	1 to: 7 do: [ :i | self assert: ((cm at: i) at: i) closeTo: 1.0 within: 1.0e-6 ].
	^ space
]

{ #category : 'examples' }
GcConceptSpaceExamples >> syntheticConceptAtlasExample [
	<gtExample>
	"gtAtlasFor:'s element builds as a BlElement with one point per member word and one distinct color per concept."
	| space element |
	space := self syntheticConceptSpace.
	element := space atlasElement.
	self assert: (element isKindOf: BlElement).
	self assert: space atlasWordCount equals: 6.
	self assert: space atlasConceptColors size equals: 3.
	self assert: (space gtAtlasFor: GtPhlowView empty) notNil.
	self assert: (space gtConceptsFor: GtPhlowView empty) notNil.
	self assert: (space gtSimilarityFor: GtPhlowView empty) notNil.
	^ space
]

{ #category : 'examples' }
GcConceptSpaceExamples >> syntheticConceptMetricsExample [
	<gtExample>
	"Centroids are correct unit-means and the inter-concept cosine matrix is right to 1e-6."
	| space cA cB cC centroidA cm invSqrt2 acCos |
	space := self syntheticConceptSpace.
	cA := space concepts first.
	cB := space concepts second.
	cC := space concepts third.
	invSqrt2 := 2 sqrt reciprocal.
	centroidA := space centroidFor: cA.
	self assert: centroidA norm closeTo: 1.0 within: 1.0e-6.
	self assert: (centroidA vector at: 1) closeTo: invSqrt2 within: 1.0e-6.
	self assert: (centroidA vector at: 2) closeTo: invSqrt2 within: 1.0e-6.
	self assert: (centroidA vector at: 3) closeTo: 0.0 within: 1.0e-6.
	self assert: (centroidA vector at: 4) closeTo: 0.0 within: 1.0e-6.
	cm := space cosineMatrix.
	self assert: cm size equals: 3.
	1 to: 3 do: [ :i | self assert: ((cm at: i) at: i) closeTo: 1.0 within: 1.0e-6 ].
	self assert: ((cm at: 1) at: 2) closeTo: 0.0 within: 1.0e-6.
	self assert: ((cm at: 2) at: 3) closeTo: 0.0 within: 1.0e-6.
	acCos := 3.0 / 10.0 sqrt.
	self assert: ((cm at: 1) at: 3) closeTo: acCos within: 1.0e-6.
	self assert: ((cm at: 1) at: 2) closeTo: ((cm at: 2) at: 1) within: 1.0e-6.
	self assert: (cA cosineTo: cC) closeTo: acCos within: 1.0e-6.
	self assert: (cA memberVectors size) equals: 2.
	^ space
]

{ #category : 'examples' }
GcConceptSpaceExamples >> syntheticConceptRelationshipsExample [
	<gtExample>
	"Stage B: the cosine heatmap element builds with N*N colored cells, and the relationship-graph edge selection is exact on the known 3-concept cosine matrix (AB=0, AC=0.9487, BC=0)."
	| space n heat cellCount defaultT edgesDefault pair edgesHalf edgesHigh edgesLow m |
	space := self syntheticConceptSpace.
	n := space concepts size.
	heat := space heatmapElement.
	self assert: (heat isKindOf: BlElement).
	cellCount := 0.
	heat allChildrenDepthFirstDo: [ :e |
		(e userData includesKey: #gcHeatmapCell) ifTrue: [ cellCount := cellCount + 1 ] ].
	self assert: cellCount equals: n * n.
	self assert: space heatmapCellCount equals: n * n.
	self assert: (space gtHeatmapFor: GtPhlowView empty) notNil.
	defaultT := space defaultEdgeThreshold.
	self assert: defaultT closeTo: (3.0 / 10.0 sqrt / 3.0) within: 1.0e-5.
	edgesDefault := space edgePairs.
	self assert: edgesDefault size equals: 1.
	pair := edgesDefault first.
	self assert: pair first == space concepts first.
	self assert: pair second == space concepts third.
	self assert: pair cosine closeTo: (3.0 / 10.0 sqrt) within: 1.0e-6.
	edgesHalf := space edgePairsForThreshold: 0.5.
	self assert: edgesHalf size equals: 1.
	edgesHigh := space edgePairsForThreshold: 0.95.
	self assert: edgesHigh size equals: 0.
	edgesLow := space edgePairsForThreshold: -0.5.
	self assert: edgesLow size equals: 3.
	space concepts do: [ :c |
		self assert: ((space nodeElementForConcept: c) isKindOf: BlElement) ].
	edgesDefault do: [ :p |
		self assert: ((space edgeElementForPair: p) isKindOf: BlLineElement) ].
	m := GtMondrian new.
	space paintGraphOn: m.
	self assert: (m asElement isKindOf: BlElement).
	self assert: (space gtGraphFor: GtPhlowView empty) notNil.
	^ space
]

{ #category : 'examples' }
GcConceptSpaceExamples >> syntheticConceptSpace [
	<gtExample>
	"A synthetic GcConceptSpace over tiny known vectors, reusing the GcEmbeddingComparisonExamples synthetic-model helper (no network, no real gpt2)."
	| model space |
	model := GcEmbeddingComparisonExamples new syntheticModelLabel: 'synConcepts' matrix: self conceptMatrix.
	space := GcConceptSpace concepts: self syntheticConcepts model: model wordSpecs: self syntheticConceptSpecs.
	self assert: space concepts size equals: 3.
	self assert: space allWords size equals: 6.
	self assert: space model wordVectors size equals: 6.
	^ space
]

{ #category : 'synthetic data' }
GcConceptSpaceExamples >> syntheticConceptSpecs [
	"One single-token spec per synthetic word (ids 0..5)."
	^ { { 'w0'. #(0). #('w0') }.
		{ 'w1'. #(1). #('w1') }.
		{ 'w2'. #(2). #('w2') }.
		{ 'w3'. #(3). #('w3') }.
		{ 'w4'. #(4). #('w4') }.
		{ 'w5'. #(5). #('w5') } }
]

{ #category : 'synthetic data' }
GcConceptSpaceExamples >> syntheticConcepts [
	^ {
		GcConcept name: 'A' words: #('w0' 'w1').
		GcConcept name: 'B' words: #('w2' 'w3').
		GcConcept name: 'C' words: #('w4' 'w5') }
]
