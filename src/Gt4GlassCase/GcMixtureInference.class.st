"
SCAFFOLD (DW-18, Tier-2 boundary object / hook): holds the inputs of a data-mixture inference -- a GcMergeList (the observed tokenizer fingerprint) and a collection of GcCategoryCorpus (candidate category corpora) -- and defines the boundary to the numerical solver. Its #solve does NOT implement a linear program: the heavy numerical mixture-inference solve (recover per-category training proportions that best explain the merge order, after Hayase et al.) is a Python/Tier-2 job delegated to the gc-harness oracle (invariant I10). #solve raises an explicit delegation error; a GcMixtureSolution is produced by that oracle (or planted for demonstration). This object exists so the Tier-1/Tier-2 boundary is a first-class, explorable thing in the image, mirroring DW-12's split.
"
Class {
	#name : 'GcMixtureInference',
	#superclass : 'Object',
	#instVars : [
		'mergeList',
		'corpora',
		'solution'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcMixtureInference class >> mergeList: aMergeList corpora: aCollection [
	^ self new setMergeList: aMergeList corpora: aCollection
]

{ #category : 'accessing' }
GcMixtureInference >> corpora [
	^ corpora ifNil: [ #() ]
]

{ #category : 'accessing' }
GcMixtureInference >> corpora: aCollection [
	corpora := aCollection
]

{ #category : 'gt views' }
GcMixtureInference >> gtCorporaFor: aView [
	<gtView>
	"The candidate category corpora (click a row to open the GcCategoryCorpus)."
	corpora ifNil: [ ^ aView empty ].
	^ aView list
		title: 'Category corpora';
		priority: 2;
		items: [ self corpora ]
]

{ #category : 'gt views' }
GcMixtureInference >> gtHookFor: aView [
	<gtView>
	"The Tier-1/Tier-2 boundary: inputs held in-image, the numerical solve delegated to the Python oracle."
	^ aView columnedList
		title: 'Inference (hook)';
		priority: 1;
		items: [ self hookFacets ];
		column: 'Facet' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value displayString ];
		send: [ :assoc | assoc value ]
]

{ #category : 'gt views' }
GcMixtureInference >> gtObservedFingerprintFor: aView [
	<gtView>
	"The observed tokenizer fingerprint that the solver must explain (forwarded from the merge list)."
	mergeList ifNil: [ ^ aView empty ].
	^ aView forward
		title: 'Observed fingerprint';
		priority: 3;
		object: [ mergeList ];
		view: #gtCorpusFingerprintFor:
]

{ #category : 'gt views' }
GcMixtureInference >> gtSolutionFor: aView [
	<gtView>
	"The attached solution (planted or from the oracle), or empty until solved."
	solution ifNil: [ ^ aView empty ].
	^ aView forward
		title: 'Solution';
		priority: 4;
		object: [ solution ];
		view: #gtSolutionFor:
]

{ #category : 'accessing' }
GcMixtureInference >> hookFacets [
	^ {
		'Merge list' -> mergeList.
		'Merges' -> (mergeList ifNil: [ 0 ] ifNotNil: [ :ml | ml size ]).
		'Category corpora' -> self corpora size.
		'Corpus names' -> ((self corpora collect: [ :c | c name ]) asArray).
		'Solved?' -> self isSolved.
		'Solver' -> 'Python oracle (gc-harness, DW-18 Tier-2) -- LP not run in-image (I10)' }
]

{ #category : 'testing' }
GcMixtureInference >> isSolved [
	^ solution notNil
]

{ #category : 'accessing' }
GcMixtureInference >> mergeList [
	^ mergeList
]

{ #category : 'accessing' }
GcMixtureInference >> mergeList: aMergeList [
	mergeList := aMergeList
]

{ #category : 'printing' }
GcMixtureInference >> printOn: aStream [
	aStream nextPutAll: 'mixture inference ('; print: self corpora size; nextPutAll: ' corpora, '; nextPutAll: (self isSolved ifTrue: [ 'solved' ] ifFalse: [ 'unsolved -- Tier-2' ]); nextPut: $)
]

{ #category : 'initialization' }
GcMixtureInference >> setMergeList: aMergeList corpora: aCollection [
	mergeList := aMergeList.
	corpora := aCollection
]

{ #category : 'accessing' }
GcMixtureInference >> solution [
	^ solution
]

{ #category : 'accessing' }
GcMixtureInference >> solution: aSolution [
	"Attach a GcMixtureSolution (produced by the Python oracle, or planted for demonstration)."
	solution := aSolution
]

{ #category : 'solving' }
GcMixtureInference >> solve [
	"NOT a Smalltalk LP. The heavy numerical data-mixture inference (recover per-category training proportions that best explain the merge order, after Hayase et al.) is a Python/Tier-2 job delegated to the gc-harness oracle (invariant I10). This object is only the in-image boundary/hook; a GcMixtureSolution is produced by that oracle or planted for demonstration."
	^ self error: 'GcMixtureInference>>solve is delegated to the Python oracle (gc-harness, DW-18 Tier-2). The data-mixture LP is not implemented in Smalltalk (invariant I10). Attach a planted GcMixtureSolution via solution: to demonstrate the view.'
]
