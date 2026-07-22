"
One canonical concept pair and how its inter-concept centroid cosine similarity changes ACROSS the models of a GcConceptComparison. measurements is an Array of per-model rows { label. GcConceptPair. cosine } (the GcConceptPair is resolved within that model's own GcConceptSpace, so its gtDetailsFor:/gtConceptsFor: views stay fully moldable) so the row materializes a drift-table cell as a domain object rather than a raw tuple. spread is max cosine - min cosine across models -- the headline 'how much do the models disagree' number GcConceptComparison sorts its drift table by. Mirrors GcWordPairDistance's per-model-measurements idiom.
"
Class {
	#name : 'GcConceptDriftRow',
	#superclass : 'Object',
	#instVars : [
		'conceptA',
		'conceptB',
		'measurements'
	],
	#category : 'Gt4GlassCase-Embedding',
	#package : 'Gt4GlassCase',
	#tag : 'Embedding'
}

{ #category : 'instance creation' }
GcConceptDriftRow class >> conceptA: aConceptA conceptB: aConceptB measurements: aCollection [
	"aCollection is an Array of per-model rows { label. GcConceptPair. cosine }."
	^ self new setConceptA: aConceptA conceptB: aConceptB measurements: aCollection
]

{ #category : 'accessing' }
GcConceptDriftRow >> conceptA [
	^ conceptA
]

{ #category : 'accessing' }
GcConceptDriftRow >> conceptB [
	^ conceptB
]

{ #category : 'accessing' }
GcConceptDriftRow >> cosineForLabel: aLabel [
	| row |
	row := measurements detect: [ :m | (m at: 1) = aLabel ] ifNone: [ ^ Float nan ].
	^ row at: 3
]

{ #category : 'gt views' }
GcConceptDriftRow >> gtAcrossModelsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Across models';
		priority: 10;
		items: [ measurements ];
		column: 'Model' text: [ :m | m at: 1 ];
		column: 'Cosine' text: [ :m | (m at: 3) printShowingDecimalPlaces: 4 ];
		send: [ :m | m at: 2 ]
]

{ #category : 'gt views' }
GcConceptDriftRow >> gtConceptsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Concepts';
		priority: 20;
		items: [ { conceptA. conceptB } ];
		column: 'Concept' text: [ :c | c name ];
		column: 'Words' text: [ :c | c wordCount printString ];
		send: [ :c | c ]
]

{ #category : 'accessing' }
GcConceptDriftRow >> maxLabel [
	^ (measurements detectMax: [ :m | m at: 3 ]) at: 1
]

{ #category : 'accessing' }
GcConceptDriftRow >> measurements [
	^ measurements
]

{ #category : 'accessing' }
GcConceptDriftRow >> minLabel [
	^ (measurements detectMin: [ :m | m at: 3 ]) at: 1
]

{ #category : 'accessing' }
GcConceptDriftRow >> pairForLabel: aLabel [
	| row |
	row := measurements detect: [ :m | (m at: 1) = aLabel ] ifNone: [ ^ nil ].
	^ row at: 2
]

{ #category : 'accessing' }
GcConceptDriftRow >> pairLabel [
	^ (conceptA ifNil: [ '?' ] ifNotNil: [ :c | c name ]) , '  vs  ' , (conceptB ifNil: [ '?' ] ifNotNil: [ :c | c name ])
]

{ #category : 'printing' }
GcConceptDriftRow >> printOn: aStream [
	aStream nextPutAll: self class name; nextPutAll: '('; nextPutAll: self pairLabel; nextPutAll: ' spread='; nextPutAll: (self spread printShowingDecimalPlaces: 3); nextPut: $)
]

{ #category : 'private' }
GcConceptDriftRow >> setConceptA: aConceptA conceptB: aConceptB measurements: aCollection [
	conceptA := aConceptA.
	conceptB := aConceptB.
	measurements := aCollection
]

{ #category : 'accessing' }
GcConceptDriftRow >> spread [
	"max cosine - min cosine across models -- how much the models disagree on this pair."
	| vals |
	vals := measurements collect: [ :m | m at: 3 ].
	^ vals max - vals min
]
