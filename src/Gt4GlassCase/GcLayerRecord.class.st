"
Per-transformer-block snapshot captured during a traced forward pass. Each slot is an Array of per-position Float64Array hidden states: residualIn (block input), attnOut (attention sublayer output before the residual add), residualMid (input + attnOut), mlpOut (MLP sublayer output before the residual add), residualOut (block output). attnOut / mlpOut are populated only at trace level #full.
"
Class {
	#name : 'GcLayerRecord',
	#superclass : 'Object',
	#instVars : [
		'layerIndex',
		'residualIn',
		'attnOut',
		'residualMid',
		'mlpOut',
		'residualOut',
		'attnWeights',
		'tokenLabels'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'attention' }
GcLayerRecord >> attentionHeads [
	"One GcAttentionHead per captured head (0-based headIndex), sharing this record's tokenLabels for axis labelling."
	self hasAttentionWeights ifFalse: [ ^ #() ].
	^ (0 to: self numHeads - 1) collect: [ :h |
		GcAttentionHead
			layerIndex: layerIndex
			headIndex: h
			weights: (attnWeights at: h + 1)
			tokenLabels: tokenLabels ]
]

{ #category : 'attention' }
GcLayerRecord >> attentionOverviewElement [
	"A flow of small raster tiles, one per head -- the small-multiples overview."
	self hasAttentionWeights ifFalse: [
		^ BlTextElement new
			text: 'No attention weights (trace level was not #full).' asRopedText;
			yourself ].
	^ BlElement new
		layout: BlFlowLayout new;
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		padding: (BlInsets all: 4);
		addChildren: (self attentionHeads collect: [ :head | head tileElement ]) asArray;
		yourself
]

{ #category : 'accessing' }
GcLayerRecord >> attnOut [
	^ attnOut
]

{ #category : 'accessing' }
GcLayerRecord >> attnOut: aCollection [
	attnOut := aCollection
]

{ #category : 'accessing' }
GcLayerRecord >> attnWeights [
	"Per-head causal attention probability matrices captured at trace level #full: an Array of numHeads elements, each an Array of seqLen query rows, each a Float64Array of seqLen key columns (0.0 above the diagonal). nil unless level was #full."
	^ attnWeights
]

{ #category : 'accessing' }
GcLayerRecord >> attnWeights: anArray [
	attnWeights := anArray
]

{ #category : 'gt - views' }
GcLayerRecord >> gtAttentionGridFor: aView [
	"The whole layer's heads as one small-multiples grid (overview, no drill-in)."
	<gtView>
	^ aView explicit
		title: 'Attention grid';
		priority: 6;
		stencil: [ self attentionOverviewElement ]
]

{ #category : 'gt - views' }
GcLayerRecord >> gtAttentionHeadsFor: aView [
	"Small multiples of the per-head causal attention matrices, laid out as a grid. Clicking a head opens its full labelled heatmap."
	<gtView>
	^ aView mondrian
		title: 'Attention heads';
		priority: 5;
		painting: [ :m |
			m nodes
				stencil: [ :head | head tileElement ];
				with: self attentionHeads.
			m layout grid ]
]

{ #category : 'attention' }
GcLayerRecord >> hasAttentionWeights [
	^ attnWeights notNil
]

{ #category : 'accessing' }
GcLayerRecord >> layerIndex [
	^ layerIndex
]

{ #category : 'accessing' }
GcLayerRecord >> layerIndex: anInteger [
	layerIndex := anInteger
]

{ #category : 'accessing' }
GcLayerRecord >> mlpOut [
	^ mlpOut
]

{ #category : 'accessing' }
GcLayerRecord >> mlpOut: aCollection [
	mlpOut := aCollection
]

{ #category : 'attention' }
GcLayerRecord >> numHeads [
	"The number of attention heads captured (0 if this record was not traced at #full)."
	^ attnWeights isNil ifTrue: [ 0 ] ifFalse: [ attnWeights size ]
]

{ #category : 'printing' }
GcLayerRecord >> printOn: aStream [
	super printOn: aStream.
	aStream nextPutAll: '(layer '; print: layerIndex; nextPut: $)
]

{ #category : 'accessing' }
GcLayerRecord >> residualIn [
	^ residualIn
]

{ #category : 'accessing' }
GcLayerRecord >> residualIn: aCollection [
	residualIn := aCollection
]

{ #category : 'accessing' }
GcLayerRecord >> residualMid [
	^ residualMid
]

{ #category : 'accessing' }
GcLayerRecord >> residualMid: aCollection [
	residualMid := aCollection
]

{ #category : 'accessing' }
GcLayerRecord >> residualOut [
	^ residualOut
]

{ #category : 'accessing' }
GcLayerRecord >> residualOut: aCollection [
	residualOut := aCollection
]

{ #category : 'accessing' }
GcLayerRecord >> tokenLabels [
	"An Array of per-position token label Strings, or nil if the record was not labelled. Used only to annotate attention-heatmap axes."
	^ tokenLabels
]

{ #category : 'accessing' }
GcLayerRecord >> tokenLabels: aCollection [
	tokenLabels := aCollection
]
