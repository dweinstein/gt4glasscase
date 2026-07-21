"
A word/phrase resolved to its GPT-2 sub-token ids and a single mean-pooled embedding vector FOR ONE MODEL. The vector is the elementwise mean of the (optionally precision-quantized) embedding rows of the word's sub-tokens. Answers geometric questions between words: cosineTo:, distanceTo: (1-cosine), dot:, norm. gtView shows the word, its sub-token pieces, and vector stats.
"
Class {
	#name : 'GcWordVector',
	#superclass : 'Object',
	#instVars : [
		'word',
		'tokenIds',
		'pieces',
		'vector'
	],
	#category : 'Gt4GlassCase-Embedding',
	#package : 'Gt4GlassCase',
	#tag : 'Embedding'
}

{ #category : 'instance creation' }
GcWordVector class >> word: aWord tokenIds: anIdCollection pieces: aPieceCollection vector: aVector [
	^ self new
		setWord: aWord
		tokenIds: anIdCollection
		pieces: aPieceCollection
		vector: aVector
]

{ #category : 'computing' }
GcWordVector >> componentMax [
	| m |
	vector isEmpty ifTrue: [ ^ 0.0 ].
	m := vector at: 1.
	2 to: vector size do: [ :i | (vector at: i) > m ifTrue: [ m := vector at: i ] ].
	^ m
]

{ #category : 'computing' }
GcWordVector >> componentMean [
	| sum |
	vector isEmpty ifTrue: [ ^ 0.0 ].
	sum := 0.0.
	1 to: vector size do: [ :i | sum := sum + (vector at: i) ].
	^ sum / vector size
]

{ #category : 'computing' }
GcWordVector >> componentMin [
	| m |
	vector isEmpty ifTrue: [ ^ 0.0 ].
	m := vector at: 1.
	2 to: vector size do: [ :i | (vector at: i) < m ifTrue: [ m := vector at: i ] ].
	^ m
]

{ #category : 'computing' }
GcWordVector >> cosineTo: aWordVector [
	"Cosine similarity in [-1, 1]; 0.0 if either vector is degenerate."
	| denom |
	denom := self norm * aWordVector norm.
	denom = 0.0 ifTrue: [ ^ 0.0 ].
	^ (self dot: aWordVector) / denom
]

{ #category : 'accessing' }
GcWordVector >> dimension [
	^ vector size
]

{ #category : 'computing' }
GcWordVector >> distanceTo: aWordVector [
	"Cosine distance = 1 - cosine similarity."
	^ 1.0 - (self cosineTo: aWordVector)
]

{ #category : 'computing' }
GcWordVector >> dot: aWordVector [
	| other sum |
	other := aWordVector vector.
	sum := 0.0.
	1 to: vector size do: [ :i | sum := sum + ((vector at: i) * (other at: i)) ].
	^ sum
]

{ #category : 'gt - views' }
GcWordVector >> gtDetailsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Details';
		priority: 10;
		items: [ {
			'word' -> word printString.
			'sub-tokens' -> (pieces ifNil: [ #() ]) printString.
			'token ids' -> (tokenIds ifNil: [ #() ]) printString.
			'dimension' -> self dimension printString.
			'norm' -> self norm printString.
			'min' -> self componentMin printString.
			'max' -> self componentMax printString.
			'mean' -> self componentMean printString } ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ]
]

{ #category : 'gt - views' }
GcWordVector >> gtVectorValuesFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Vector';
		priority: 20;
		items: [ (1 to: vector size) collect: [ :i | i -> (vector at: i) ] ];
		column: 'Dim' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value printString ]
]

{ #category : 'computing' }
GcWordVector >> norm [
	| sum |
	sum := 0.0.
	1 to: vector size do: [ :i | sum := sum + ((vector at: i) * (vector at: i)) ].
	^ sum sqrt
]

{ #category : 'accessing' }
GcWordVector >> pieces [
	^ pieces
]

{ #category : 'printing' }
GcWordVector >> printOn: aStream [
	aStream nextPutAll: self class name; nextPutAll: '('.
	aStream print: word.
	aStream nextPutAll: ' dim='; print: self dimension; nextPutAll: ')'
]

{ #category : 'initialization' }
GcWordVector >> setWord: aWord tokenIds: anIdCollection pieces: aPieceCollection vector: aVector [
	word := aWord.
	tokenIds := anIdCollection.
	pieces := aPieceCollection.
	vector := aVector
]

{ #category : 'accessing' }
GcWordVector >> tokenIds [
	^ tokenIds
]

{ #category : 'accessing' }
GcWordVector >> vector [
	^ vector
]

{ #category : 'accessing' }
GcWordVector >> word [
	^ word
]
