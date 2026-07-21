"
A named concept: a set of example words that, together, point at a region of a model's embedding space (e.g. 'royalty' = king/queen/prince/duke). Resolved AGAINST a GcEmbeddingModel (which holds the mean-pooled GcWordVector for every word), a concept answers: memberVectorsIn: (its member GcWordVectors) and centroidIn: (a UNIT centroid = normalized elementwise mean of the member vectors, wrapped as a GcWordVector so cosineTo: and the geometry helpers are reused). Within a GcConceptSpace the concept also carries a display color (assigned by the space) and a back-reference to the space, so centroid/memberVectors/cosineTo: work without an explicit model argument. Centroid-based for now; Stage C will add a signed concept DIRECTION (king-queen style) -- deliberately not modeled yet.
"
Class {
	#name : 'GcConcept',
	#superclass : 'Object',
	#instVars : [
		'name',
		'words',
		'color',
		'space'
	],
	#category : 'Gt4GlassCase-Embedding',
	#package : 'Gt4GlassCase',
	#tag : 'Embedding'
}

{ #category : 'instance creation' }
GcConcept class >> name: aName words: aWords [
	^ self new setName: aName words: aWords
]

{ #category : 'resolving' }
GcConcept >> centroid [
	"My UNIT centroid GcWordVector within my owning space (cached by the space)."
	^ self space centroidFor: self
]

{ #category : 'resolving' }
GcConcept >> centroidIn: aModel [
	"A UNIT centroid: the normalized elementwise mean of my member vectors, wrapped as a GcWordVector so cosineTo: / norm are reused. Stage C will add a signed direction alongside this."
	| vecs mean unit |
	vecs := (self memberVectorsIn: aModel) collect: [ :wv | wv vector ].
	mean := aModel meanOfRows: vecs.
	unit := aModel normalizedArr: mean.
	^ GcWordVector word: name tokenIds: #() pieces: #() vector: unit
]

{ #category : 'accessing' }
GcConcept >> color [
	^ color
]

{ #category : 'accessing' }
GcConcept >> color: aColor [
	color := aColor
]

{ #category : 'comparing' }
GcConcept >> cosineTo: aConcept [
	"Cosine similarity between my centroid and aConcept's centroid (both within my space)."
	^ self centroid cosineTo: aConcept centroid
]

{ #category : 'gt views' }
GcConcept >> gtDetailsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Details';
		priority: 20;
		items: [ {
			'name' -> (name ifNil: [ '?' ]).
			'words' -> (words ifNil: [ #() ]) printString.
			'member count' -> (words ifNil: [ #() ]) size printString.
			'in space' -> space notNil printString } ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ]
]

{ #category : 'gt views' }
GcConcept >> gtMembersFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Members';
		priority: 10;
		items: [ self space isNil ifTrue: [ #() ] ifFalse: [ self memberVectors ] ];
		column: 'Word' text: [ :wv | wv word ];
		column: 'Norm' text: [ :wv | wv norm printShowingDecimalPlaces: 3 ];
		column: 'Cos to centroid' text: [ :wv | (wv cosineTo: self centroid) printShowingDecimalPlaces: 3 ];
		send: [ :wv | wv ]
]

{ #category : 'resolving' }
GcConcept >> memberVectors [
	"My member GcWordVectors within my owning space."
	^ self memberVectorsIn: self space model
]

{ #category : 'resolving' }
GcConcept >> memberVectorsIn: aModel [
	"My member GcWordVectors, resolved from aModel (which holds the mean-pooled vector for every word in the space)."
	| modelWords |
	modelWords := aModel words.
	^ words collect: [ :w |
		| idx |
		idx := modelWords indexOf: w.
		idx = 0 ifTrue: [ self error: 'word not embedded in model: ', w printString ].
		aModel wordVectorAt: idx ]
]

{ #category : 'accessing' }
GcConcept >> name [
	^ name
]

{ #category : 'accessing' }
GcConcept >> name: aString [
	name := aString
]

{ #category : 'printing' }
GcConcept >> printOn: aStream [
	aStream nextPutAll: self class name; nextPutAll: '('.
	aStream nextPutAll: (name ifNil: [ '?' ]).
	aStream nextPutAll: ', '; print: (words ifNil: [ #() ]) size; nextPutAll: ' words)'
]

{ #category : 'initialization' }
GcConcept >> setName: aName words: aWords [
	name := aName.
	words := aWords asArray
]

{ #category : 'accessing' }
GcConcept >> space [
	^ space
]

{ #category : 'accessing' }
GcConcept >> space: aConceptSpace [
	space := aConceptSpace
]

{ #category : 'accessing' }
GcConcept >> wordCount [
	^ (words ifNil: [ #() ]) size
]

{ #category : 'accessing' }
GcConcept >> words [
	^ words
]

{ #category : 'accessing' }
GcConcept >> words: aCollection [
	words := aCollection asArray
]
