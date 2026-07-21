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
