"
One unordered word pair and how its distance changes ACROSS models. measurements is an Array of per-model rows { model. cosine. distance. zScore } so the same pair's geometry can be read side-by-side across model sizes and precisions. These are the rows of the cross-model summary table; each row send:s its GcEmbeddingModel so columns cascade. gtView lists the per-model measurements.
"
Class {
	#name : 'GcWordPairDistance',
	#superclass : 'Object',
	#instVars : [
		'wordA',
		'wordB',
		'measurements'
	],
	#category : 'Gt4GlassCase-Embedding',
	#package : 'Gt4GlassCase',
	#tag : 'Embedding'
}

{ #category : 'instance creation' }
GcWordPairDistance class >> wordA: aWordA wordB: aWordB measurements: aCollection [
	"aCollection is an Array of per-model rows { model. cosine. distance. zScore }."
	^ self new setWordA: aWordA wordB: aWordB measurements: aCollection
]

{ #category : 'accessing' }
GcWordPairDistance >> cosineForModelIndex: anIndex [
	^ (measurements at: anIndex) at: 2
]

{ #category : 'accessing' }
GcWordPairDistance >> distanceForModelIndex: anIndex [
	^ (measurements at: anIndex) at: 3
]

{ #category : 'gt - views' }
GcWordPairDistance >> gtAcrossModelsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Across models';
		priority: 10;
		items: [ measurements ];
		column: 'Model' text: [ :m | (m at: 1) label ];
		column: 'Cosine' text: [ :m | (m at: 2) printShowingDecimalPlaces: 4 ];
		column: 'Distance' text: [ :m | (m at: 3) printShowingDecimalPlaces: 4 ];
		column: 'z-score' text: [ :m | (m at: 4) printShowingDecimalPlaces: 3 ];
		send: [ :m | m first ]
]

{ #category : 'accessing' }
GcWordPairDistance >> measurements [
	^ measurements
]

{ #category : 'accessing' }
GcWordPairDistance >> modelAt: anIndex [
	^ (measurements at: anIndex) at: 1
]

{ #category : 'accessing' }
GcWordPairDistance >> pairLabel [
	^ (wordA ifNil: [ '?' ]) , '  |  ' , (wordB ifNil: [ '?' ])
]

{ #category : 'printing' }
GcWordPairDistance >> printOn: aStream [
	aStream nextPutAll: self class name; nextPutAll: '('; nextPutAll: self pairLabel; nextPutAll: ')'
]

{ #category : 'initialization' }
GcWordPairDistance >> setWordA: aWordA wordB: aWordB measurements: aCollection [
	wordA := aWordA.
	wordB := aWordB.
	measurements := aCollection
]

{ #category : 'accessing' }
GcWordPairDistance >> wordA [
	^ wordA
]

{ #category : 'accessing' }
GcWordPairDistance >> wordB [
	^ wordB
]

{ #category : 'accessing' }
GcWordPairDistance >> zForModelIndex: anIndex [
	^ (measurements at: anIndex) at: 4
]
