"
A tensor's shape as a first-class object (I1: nothing is a bare array). Holds the ordered dimensions and answers rank, elementCount, isSquare, at:. Prints like a PyTorch/safetensors shape, e.g. [1536, 576]. Wrapped automatically by GcTensorRef>>shape:.
"
Class {
	#name : 'GcTensorShape',
	#superclass : 'Object',
	#instVars : [
		'dimensions'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcTensorShape class >> fromArray: anArray [
	^ self new dimensions: anArray; yourself
]

{ #category : 'comparing' }
GcTensorShape >> = anObject [
	^ self class = anObject class and: [ self dimensions = anObject dimensions ]
]

{ #category : 'accessing' }
GcTensorShape >> at: anIndex [
	^ self dimensions at: anIndex
]

{ #category : 'accessing' }
GcTensorShape >> dimensions [
	^ dimensions ifNil: [ #() ]
]

{ #category : 'accessing' }
GcTensorShape >> dimensions: aCollection [
	dimensions := aCollection ifNil: [ #() ] ifNotNil: [ :c | c asArray ]
]

{ #category : 'querying' }
GcTensorShape >> elementCount [
	^ self dimensions isEmpty ifTrue: [ 1 ] ifFalse: [ self dimensions inject: 1 into: [ :p :d | p * d ] ]
]

{ #category : 'printing' }
GcTensorShape >> formatDimension: anInteger [
	"Group digits in threes with a narrow no-break space (U+202F), matching HuggingFace: 1536 -> '1 536'. The narrow NBSP won't line-wrap mid-number and never clashes with the comma between dimensions."
	| s size |
	s := anInteger printString.
	size := s size.
	size <= 3 ifTrue: [ ^ s ].
	^ String streamContents: [ :stream |
		s doWithIndex: [ :ch :i |
			(i > 1 and: [ ((size - i + 1) rem: 3) = 0 ]) ifTrue: [ stream nextPut: (Character value: 8239) ].
			stream nextPut: ch ] ]
]

{ #category : 'views' }
GcTensorShape >> gtMatrixFor: aView [
	"Visualize the shape as a proportional rectangle (log-scaled so a 49152x576 embedding still fits). Tall vs wide vs square is visible at a glance."
	<gtView>
	^ aView explicit
		title: 'Matrix';
		priority: 2;
		stencil: [
			| rows cols w h |
			rows := self rank >= 1 ifTrue: [ self at: 1 ] ifFalse: [ 1 ].
			cols := self rank >= 2 ifTrue: [ self at: 2 ] ifFalse: [ 1 ].
			w := ((cols + 1) ln * 30) max: 14.
			h := ((rows + 1) ln * 30) max: 14.
			BlElement new
				background: (Color r: 0.20 g: 0.45 b: 0.80 alpha: 0.35);
				border: (BlBorder paint: (Color r: 0.20 g: 0.45 b: 0.80) width: 2);
				size: w @ h;
				margin: (BlInsets all: 25);
				yourself ]
]

{ #category : 'views' }
GcTensorShape >> gtOverviewFor: aView [
	"What are this tensor's dimensions?"
	<gtView>
	^ aView columnedList
		title: 'Shape';
		priority: 1;
		items: [ self overviewFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | (assoc value isCollection and: [ assoc value isString not ]) ifTrue: [ assoc value printString ] ifFalse: [ assoc value displayString ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'comparing' }
GcTensorShape >> hash [
	^ self dimensions hash
]

{ #category : 'testing' }
GcTensorShape >> isScalar [
	^ self dimensions isEmpty
]

{ #category : 'testing' }
GcTensorShape >> isSquare [
	^ self rank = 2 and: [ (self at: 1) = (self at: 2) ]
]

{ #category : 'views' }
GcTensorShape >> overviewFacets [
	^ {
		'Dimensions' -> self dimensions.
		'Rank' -> self rank.
		'Elements' -> self elementCount.
		'Square' -> self isSquare }
]

{ #category : 'printing' }
GcTensorShape >> printOn: aStream [
	aStream nextPut: $[.
	self dimensions
		do: [ :d | aStream nextPutAll: (self formatDimension: d) ]
		separatedBy: [ aStream nextPutAll: ', ' ].
	aStream nextPut: $]
]

{ #category : 'accessing' }
GcTensorShape >> rank [
	^ self dimensions size
]
