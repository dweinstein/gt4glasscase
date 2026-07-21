"
A Stage-B relationship between two GcConcepts within one GcConceptSpace: the ordered pair (first, second) plus their inter-concept centroid cosine similarity. It materializes a heatmap-cell click and a relationship-graph edge as a MOLDABLE domain object -- so those clicks land here (with views onto both concepts and onto the similarity number) rather than on a raw two-element Array. The cosine is resolved lazily against the owning space (reusing space cosineBetween:and:).
"
Class {
	#name : 'GcConceptPair',
	#superclass : 'Object',
	#instVars : [
		'first',
		'second',
		'space'
	],
	#category : 'Gt4GlassCase-Embedding',
	#package : 'Gt4GlassCase',
	#tag : 'Embedding'
}

{ #category : 'instance creation' }
GcConceptPair class >> first: aConcept second: anotherConcept in: aSpace [
	^ self new setFirst: aConcept second: anotherConcept space: aSpace
]

{ #category : 'accessing' }
GcConceptPair >> cosine [
	"Inter-concept centroid cosine similarity of my two concepts within my space."
	^ space cosineBetween: first and: second
]

{ #category : 'accessing' }
GcConceptPair >> first [
	^ first
]

{ #category : 'gt - views' }
GcConceptPair >> gtConceptsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Concepts';
		priority: 10;
		items: [ { first. second } ];
		column: 'Concept' text: [ :c | c name ];
		column: 'Words' text: [ :c | c wordCount printString ];
		send: [ :c | c ]
]

{ #category : 'gt - views' }
GcConceptPair >> gtDetailsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Details';
		priority: 20;
		items: [ {
			'first' -> (first ifNil: [ '?' ] ifNotNil: [ :c | c name ]).
			'second' -> (second ifNil: [ '?' ] ifNotNil: [ :c | c name ]).
			'cosine' -> (self cosine printShowingDecimalPlaces: 4) } ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ]
]

{ #category : 'printing' }
GcConceptPair >> printOn: aStream [
	aStream nextPutAll: (first ifNil: [ '?' ] ifNotNil: [ :c | c name ]).
	aStream nextPutAll: ' ~ '.
	aStream nextPutAll: (second ifNil: [ '?' ] ifNotNil: [ :c | c name ]).
	(space notNil and: [ first notNil and: [ second notNil ] ]) ifTrue: [
		aStream nextPutAll: ' ('; nextPutAll: (self cosine printShowingDecimalPlaces: 3); nextPut: $) ]
]

{ #category : 'accessing' }
GcConceptPair >> second [
	^ second
]

{ #category : 'initialization' }
GcConceptPair >> setFirst: aConcept second: anotherConcept space: aSpace [
	first := aConcept.
	second := anotherConcept.
	space := aSpace
]

{ #category : 'accessing' }
GcConceptPair >> space [
	^ space
]
