"
A decoded contiguous sample of one tensor: the Float values for elements [elementStart, elementStart+sampleCount) of its tensor, plus provenance -- whether this is the full tensor or a sample, and how many of the tensor's total elements it covers (I14: provenance is part of the object model, so every view can honestly say 'n of N sampled'). Raw bytes are decoded once and never retained. GcTensorStats is computed from a slice.
"
Class {
	#name : 'GcTensorSlice',
	#superclass : 'Object',
	#instVars : [
		'tensorRef',
		'elementStart',
		'values',
		'isFull',
		'totalCount',
		'samplingStrategy'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcTensorSlice class >> fromValues: aCollection [
	"A synthetic, fully-sampled slice with no owning tensor -- for tests and ad-hoc stats."
	| arr |
	arr := aCollection asArray.
	^ self new
		values: arr;
		elementStart: 0;
		isFull: true;
		totalCount: arr size;
		samplingStrategy: #full;
		yourself
]

{ #category : 'instance creation' }
GcTensorSlice class >> tensorRef: aRef elementStart: aStart values: aCollection isFull: aBoolean [
	^ self new
		tensorRef: aRef;
		elementStart: aStart;
		values: aCollection asArray;
		isFull: aBoolean;
		totalCount: aRef paramCount;
		samplingStrategy: (aBoolean ifTrue: [ #full ] ifFalse: [ #leadingSpan ]);
		yourself
]

{ #category : 'provenance' }
GcTensorSlice >> coverageLabel [
	(totalCount isNil or: [ totalCount = 0 ]) ifTrue: [ ^ '-' ].
	^ ((self sampleCount / totalCount * 100.0) roundTo: 0.1) printString, ' %'
]

{ #category : 'accessing' }
GcTensorSlice >> elementStart [
	^ elementStart
]

{ #category : 'accessing' }
GcTensorSlice >> elementStart: anInteger [
	elementStart := anInteger
]

{ #category : 'accessing' }
GcTensorSlice >> firstIndexedValues: n [
	"The first n values paired with their (0-based) element index in the tensor."
	| limit |
	limit := values size min: n.
	^ (1 to: limit) collect: [ :i | (elementStart + i - 1) -> (values at: i) ]
]

{ #category : 'gt - views' }
GcTensorSlice >> gtProvenanceFor: aView [
	"How much of the tensor does this sample cover?"
	<gtView>
	^ aView columnedList
		title: 'Provenance';
		priority: 1;
		items: [ self provenanceFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value isNil ifTrue: [ '-' ] ifFalse: [ assoc value displayString ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'gt - views' }
GcTensorSlice >> gtSampleValuesFor: aView [
	"What are the actual numbers in this sample? (first 256 shown)"
	<gtView>
	^ aView columnedList
		title: 'Sample values';
		priority: 2;
		items: [ self firstIndexedValues: 256 ];
		column: '#' text: [ :assoc | assoc key printString ];
		column: 'Value' text: [ :assoc | assoc value printString ];
		send: [ :assoc | assoc value ]
]

{ #category : 'accessing' }
GcTensorSlice >> isFull [
	^ isFull
]

{ #category : 'accessing' }
GcTensorSlice >> isFull: aBoolean [
	isFull := aBoolean
]

{ #category : 'testing' }
GcTensorSlice >> isSampled [
	^ isFull not
]

{ #category : 'printing' }
GcTensorSlice >> printOn: aStream [
	aStream nextPutAll: 'GcTensorSlice('; nextPutAll: self provenanceLabel; nextPut: $)
]

{ #category : 'provenance' }
GcTensorSlice >> provenanceFacets [
	^ {
		'Tensor' -> (tensorRef ifNotNil: [ :r | r name ]).
		'Sampled elements' -> self sampleCount.
		'Total elements' -> totalCount.
		'Coverage' -> self coverageLabel.
		'Strategy' -> samplingStrategy.
		'Complete' -> isFull }
]

{ #category : 'provenance' }
GcTensorSlice >> provenanceLabel [
	"e.g. 'sampled 65,536 of 442,368' -- honest coverage in every view (I14)."
	^ (isFull ifTrue: [ 'full ' ] ifFalse: [ 'sampled ' ]),
		self sampleCount asStringWithCommas, ' of ', totalCount asStringWithCommas
]

{ #category : 'accessing' }
GcTensorSlice >> sampleCount [
	^ values size
]

{ #category : 'accessing' }
GcTensorSlice >> samplingStrategy [
	^ samplingStrategy
]

{ #category : 'accessing' }
GcTensorSlice >> samplingStrategy: aSymbol [
	samplingStrategy := aSymbol
]

{ #category : 'statistics' }
GcTensorSlice >> stats [
	^ GcTensorStats fromSlice: self
]

{ #category : 'accessing' }
GcTensorSlice >> tensorRef [
	^ tensorRef
]

{ #category : 'accessing' }
GcTensorSlice >> tensorRef: aRef [
	tensorRef := aRef
]

{ #category : 'accessing' }
GcTensorSlice >> totalCount [
	^ totalCount
]

{ #category : 'accessing' }
GcTensorSlice >> totalCount: anInteger [
	totalCount := anInteger
]

{ #category : 'accessing' }
GcTensorSlice >> values [
	^ values
]

{ #category : 'accessing' }
GcTensorSlice >> values: aCollection [
	values := aCollection
]
