"
Stage C: a concept treated as a signed DIRECTION (the Linear Representation Hypothesis), not just a point. A named contrastive axis built from a POSITIVE GcConcept and a NEGATIVE GcConcept (e.g. gender = female-words minus male-words); the negative may be nil, in which case the anchor is the model's global word mean (single-concept-vs-mean). directionIn: aModel = unit(positiveCentroid - negativeCentroid) as a Float64Array; projectionOf: aWordVector = dot(word, direction) -- a signed scalar saying how much of this concept the word carries; angleTo:in: is the angle in degrees between two axis directions (near 90 = independent concepts, small = entangled). Reuses GcConcept centroid resolution + GcEmbeddingModel dot/normalize helpers. Carries a back-reference to its GcConceptAxisSpace (like GcConcept -> GcConceptSpace) so direction/projection/top-words resolve without an explicit model argument.
"
Class {
	#name : 'GcConceptAxis',
	#superclass : 'Object',
	#instVars : [
		'name',
		'positive',
		'negative',
		'space',
		'color'
	],
	#category : 'Gt4GlassCase-Embedding',
	#package : 'Gt4GlassCase',
	#tag : 'Embedding'
}

{ #category : 'instance creation' }
GcConceptAxis class >> name: aName positive: aPositiveConcept [
	"A single-concept axis measured against the model's global word mean."
	^ self name: aName positive: aPositiveConcept negative: nil
]

{ #category : 'instance creation' }
GcConceptAxis class >> name: aName positive: aPositiveConcept negative: aNegativeConcept [
	"A contrastive axis: unit(positive centroid - negative centroid). aNegativeConcept may be nil (anchor at the model's global word mean)."
	^ self new setName: aName positive: aPositiveConcept negative: aNegativeConcept
]

{ #category : 'geometry' }
GcConceptAxis >> angleTo: anotherAxis [
	^ self angleTo: anotherAxis in: self space model
]

{ #category : 'geometry' }
GcConceptAxis >> angleTo: anotherAxis in: aModel [
	"Angle in DEGREES between the two unit axis directions = arccos(d1 . d2). ~90 = independent concepts, small = entangled."
	| d1 d2 dot |
	d1 := self directionIn: aModel.
	d2 := anotherAxis directionIn: aModel.
	dot := aModel dotArr: d1 with: d2.
	dot := (dot max: -1.0) min: 1.0.
	^ dot arcCos * 180.0 / Float pi
]

{ #category : 'accessing' }
GcConceptAxis >> color [
	^ color ifNil: [ Color gray ]
]

{ #category : 'accessing' }
GcConceptAxis >> color: aColor [
	color := aColor
]

{ #category : 'geometry' }
GcConceptAxis >> direction [
	"My unit direction within my owning space (cached by the space)."
	^ self space directionFor: self
]

{ #category : 'geometry' }
GcConceptAxis >> directionIn: aModel [
	"The unit concept DIRECTION = unit(positive centroid - negative centroid) as a Float64Array. If negative is nil, the negative anchor is aModel's global word mean."
	| posVec negVec diff |
	posVec := (positive centroidIn: aModel) vector.
	negVec := negative
		ifNil: [ aModel vectorMean ]
		ifNotNil: [ :c | (c centroidIn: aModel) vector ].
	diff := Float64Array new: aModel hiddenDim.
	1 to: aModel hiddenDim do: [ :i | diff at: i put: (posVec at: i) - (negVec at: i) ].
	^ aModel normalizedArr: diff
]

{ #category : 'gt views' }
GcConceptAxis >> gtDetailsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Details';
		priority: 20;
		items: [ {
			'name' -> (name ifNil: [ '?' ]).
			'positive' -> self positiveLabel.
			'negative' -> self negativeLabel.
			'positive words' -> self positiveWords printString.
			'negative words' -> self negativeWords printString.
			'in space' -> space notNil printString } ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ]
]

{ #category : 'gt views' }
GcConceptAxis >> gtTopWordsFor: aView [
	<gtView>
	space ifNil: [ ^ aView empty ].
	^ aView columnedList
		title: 'Placed words';
		priority: 15;
		items: [ space placedProjectionsForAxis: self ];
		column: 'Word' text: [ :row | row first ];
		column: (self negativeLabel , ' <-> ' , self positiveLabel) text: [ :row | (row second) printShowingDecimalPlaces: 3 ];
		send: [ :row | row third ]
]

{ #category : 'accessing' }
GcConceptAxis >> name [
	^ name
]

{ #category : 'accessing' }
GcConceptAxis >> negative [
	^ negative
]

{ #category : 'accessing' }
GcConceptAxis >> negativeLabel [
	^ negative ifNil: [ 'mean' ] ifNotNil: [ :c | c name ]
]

{ #category : 'accessing' }
GcConceptAxis >> negativeWords [
	^ negative ifNil: [ #() ] ifNotNil: [ :c | c words ]
]

{ #category : 'accessing' }
GcConceptAxis >> positive [
	^ positive
]

{ #category : 'accessing' }
GcConceptAxis >> positiveLabel [
	^ positive ifNil: [ '?' ] ifNotNil: [ :c | c name ]
]

{ #category : 'accessing' }
GcConceptAxis >> positiveWords [
	^ positive words
]

{ #category : 'printing' }
GcConceptAxis >> printOn: aStream [
	aStream nextPutAll: self class name; nextPut: $(.
	aStream nextPutAll: (name ifNil: [ '?' ]).
	aStream nextPutAll: ': '; nextPutAll: self negativeLabel; nextPutAll: ' -> '; nextPutAll: self positiveLabel.
	aStream nextPut: $)
]

{ #category : 'geometry' }
GcConceptAxis >> projectionOf: aWordVector [
	"Signed scalar = dot(word, unit direction), resolved within my owning space."
	^ self space model dotArr: aWordVector vector with: self direction
]

{ #category : 'geometry' }
GcConceptAxis >> projectionOf: aWordVector in: aModel [
	"Signed scalar = dot(word, unit direction): how much of this concept aWordVector carries."
	^ aModel dotArr: aWordVector vector with: (self directionIn: aModel)
]

{ #category : 'initialization' }
GcConceptAxis >> setName: aName positive: aPositiveConcept negative: aNegativeConcept [
	name := aName.
	positive := aPositiveConcept.
	negative := aNegativeConcept
]

{ #category : 'accessing' }
GcConceptAxis >> space [
	^ space
]

{ #category : 'accessing' }
GcConceptAxis >> space: aConceptAxisSpace [
	space := aConceptAxisSpace
]
