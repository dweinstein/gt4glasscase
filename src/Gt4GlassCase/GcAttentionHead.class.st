"
One attention head's causal seq x seq probability matrix from a traced forward pass: weights is an Array of seqLen query rows, each a Float64Array of seqLen key columns (softmax over keys j <= query i; 0.0 above the diagonal). tokenLabels (or nil) labels the query rows and key columns. Renders a heatmap (query rows x key columns).
"
Class {
	#name : 'GcAttentionHead',
	#superclass : 'Object',
	#instVars : [
		'layerIndex',
		'headIndex',
		'weights',
		'tokenLabels'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcAttentionHead class >> layerIndex: aLayer headIndex: aHead weights: aMatrix tokenLabels: labelsOrNil [
	^ self new
		layerIndex: aLayer;
		headIndex: aHead;
		weights: aMatrix;
		tokenLabels: labelsOrNil;
		yourself
]

{ #category : 'rendering - elements' }
GcAttentionHead >> captionElement: aString [
	^ BlTextElement new
		text: aString asRopedText;
		padding: (BlInsets all: 4);
		yourself
]

{ #category : 'rendering - elements' }
GcAttentionHead >> cellWidth: w color: aColor [
	^ BlElement new
		constraintsDo: [ :c | c horizontal exact: w. c vertical exact: self heatmapCellHeight ];
		background: aColor;
		border: (BlBorder paint: (Color gray: 0.82) width: 0.5);
		yourself
]

{ #category : 'rendering - color' }
GcAttentionHead >> colorForQuery: qi key: kj [
	"Cells above the diagonal (key after query) are causally masked -- render a faint neutral gray. Otherwise the weight ramp."
	kj > qi ifTrue: [ ^ Color r: 0.95 g: 0.95 b: 0.96 ].
	^ self colorForWeight: (self weightAtQuery: qi key: kj)
]

{ #category : 'rendering - color' }
GcAttentionHead >> colorForWeight: aWeight [
	"Sequential ramp: 0 -> white, 1 -> deep blue."
	| c |
	c := aWeight.
	c < 0.0 ifTrue: [ c := 0.0 ].
	c > 1.0 ifTrue: [ c := 1.0 ].
	^ Color
		r: 1.0 - (0.87 * c)
		g: 1.0 - (0.80 * c)
		b: 1.0 - (0.45 * c)
]

{ #category : 'gt - views' }
GcAttentionHead >> gtHeatmapFor: aView [
	<gtView>
	^ aView explicit
		title: 'Heatmap';
		priority: 5;
		stencil: [ self heatmapElement ]
]

{ #category : 'accessing' }
GcAttentionHead >> headIndex [
	^ headIndex
]

{ #category : 'accessing' }
GcAttentionHead >> headIndex: anInteger [
	headIndex := anInteger
]

{ #category : 'printing' }
GcAttentionHead >> headTitle [
	^ 'L' , layerIndex printString , ' H' , headIndex printString
]

{ #category : 'printing' }
GcAttentionHead >> heatmapCaption [
	^ 'Layer ' , layerIndex printString , ' head ' , headIndex printString
		, ' - rows = query tokens (attending), columns = key tokens (attended to); causal, lower-triangular.'
]

{ #category : 'rendering - constants' }
GcAttentionHead >> heatmapCellHeight [
	^ 22
]

{ #category : 'rendering - constants' }
GcAttentionHead >> heatmapCellWidth [
	^ 48
]

{ #category : 'rendering - elements' }
GcAttentionHead >> heatmapElement [
	"The full labelled heatmap: a caption, a header row of key-token labels, then one row per query token (left label + the causal weight cells)."
	| seq headerCells rows children |
	seq := self seqLen.
	headerCells := OrderedCollection new.
	headerCells add: (self labelCellWidth: self heatmapLabelWidth text: 'q \ k').
	1 to: seq do: [ :kj | headerCells add: (self labelCellWidth: self heatmapCellWidth text: (self labelAt: kj)) ].
	rows := (1 to: seq) collect: [ :qi |
		| cells |
		cells := OrderedCollection new.
		cells add: (self labelCellWidth: self heatmapLabelWidth text: (self labelAt: qi)).
		1 to: seq do: [ :kj | cells add: (self cellWidth: self heatmapCellWidth color: (self colorForQuery: qi key: kj)) ].
		self horizontalStrip: cells ].
	children := OrderedCollection new.
	children add: (self captionElement: self heatmapCaption).
	children add: (self horizontalStrip: headerCells).
	children addAll: rows.
	^ self verticalStrip: children padding: 6
]

{ #category : 'rendering - constants' }
GcAttentionHead >> heatmapLabelWidth [
	^ 78
]

{ #category : 'rendering - elements' }
GcAttentionHead >> horizontalStrip: aCollectionOfElements [
	^ BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		addChildren: aCollectionOfElements asArray;
		yourself
]

{ #category : 'accessing' }
GcAttentionHead >> labelAt: i [
	"The token label for sequence position i (1-based), or the 0-based position number when unlabelled."
	(tokenLabels notNil and: [ i <= tokenLabels size ])
		ifTrue: [ ^ (tokenLabels at: i) ].
	^ (i - 1) printString
]

{ #category : 'rendering - elements' }
GcAttentionHead >> labelCellWidth: w text: aString [
	^ BlElement new
		constraintsDo: [ :c | c horizontal exact: w. c vertical exact: self heatmapCellHeight ];
		padding: (BlInsets all: 2);
		clipChildren: true;
		addChild: (BlTextElement new text: aString asRopedText; yourself);
		yourself
]

{ #category : 'accessing' }
GcAttentionHead >> layerIndex [
	^ layerIndex
]

{ #category : 'accessing' }
GcAttentionHead >> layerIndex: anInteger [
	layerIndex := anInteger
]

{ #category : 'printing' }
GcAttentionHead >> printOn: aStream [
	super printOn: aStream.
	aStream nextPutAll: ' '; nextPutAll: self headTitle;
		nextPutAll: ' seq='; print: self seqLen
]

{ #category : 'accessing' }
GcAttentionHead >> seqLen [
	^ weights size
]

{ #category : 'rendering - constants' }
GcAttentionHead >> tileCellPixels [
	"Pixels per matrix cell in the small-multiple raster tile."
	^ 8
]

{ #category : 'rendering - elements' }
GcAttentionHead >> tileElement [
	"A captioned raster tile for the small-multiples view."
	^ self
		verticalStrip: { self captionElement: self headTitle. BlFormElement new form: self tileForm }
		padding: 4
]

{ #category : 'rendering - elements' }
GcAttentionHead >> tileForm [
	"A compact raster of the causal seq x seq weight matrix (query rows x key columns)."
	| seq cell form |
	seq := self seqLen.
	cell := self tileCellPixels.
	form := Form extent: (seq * cell) @ (seq * cell) depth: 32.
	1 to: seq do: [ :qi |
		1 to: seq do: [ :kj |
			form
				fill: (((kj - 1) * cell) @ ((qi - 1) * cell) extent: cell @ cell)
				fillColor: (self colorForQuery: qi key: kj) ] ].
	^ form
]

{ #category : 'accessing' }
GcAttentionHead >> tokenLabels [
	^ tokenLabels
]

{ #category : 'accessing' }
GcAttentionHead >> tokenLabels: aCollectionOrNil [
	tokenLabels := aCollectionOrNil
]

{ #category : 'rendering - elements' }
GcAttentionHead >> verticalStrip: aCollectionOfElements padding: aNumber [
	^ BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		padding: (BlInsets all: aNumber);
		addChildren: aCollectionOfElements asArray;
		yourself
]

{ #category : 'accessing' }
GcAttentionHead >> weightAtQuery: qi key: kj [
	^ (weights at: qi) at: kj
]

{ #category : 'accessing' }
GcAttentionHead >> weights [
	^ weights
]

{ #category : 'accessing' }
GcAttentionHead >> weights: aMatrix [
	weights := aMatrix
]
