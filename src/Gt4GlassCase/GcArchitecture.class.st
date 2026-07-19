"
Derived shape of a model: n_layers, n_heads, kv_heads, hidden size, MoE topology. The model's own internal regularity baseline.
"
Class {
	#name : 'GcArchitecture',
	#superclass : 'Object',
	#instVars : [
		'numLayers',
		'numHeads',
		'kvHeads',
		'hiddenSize',
		'moeExperts'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcArchitecture class >> fromConfig: aConfig [
	^ self new
		numLayers: aConfig numLayers;
		numHeads: aConfig numHeads;
		kvHeads: aConfig kvHeads;
		hiddenSize: aConfig hiddenSize;
		yourself
]

{ #category : 'views' }
GcArchitecture >> gtOverviewFor: aView [
	"What shape is this model?"
	<gtView>
	^ aView columnedList
		title: 'Shape';
		priority: 1;
		items: [ self overviewFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ifNil: [ '-' ] ifNotNil: [ :v | v displayString ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'derived' }
GcArchitecture >> headDim [
	^ (hiddenSize notNil and: [ numHeads notNil and: [ numHeads > 0 ] ])
		ifTrue: [ hiddenSize // numHeads ]
		ifFalse: [ nil ]
]

{ #category : 'accessing' }
GcArchitecture >> hiddenSize [
	^ hiddenSize
]

{ #category : 'accessing' }
GcArchitecture >> hiddenSize: anInteger [
	hiddenSize := anInteger
]

{ #category : 'accessing' }
GcArchitecture >> kvHeads [
	^ kvHeads
]

{ #category : 'accessing' }
GcArchitecture >> kvHeads: anInteger [
	kvHeads := anInteger
]

{ #category : 'accessing' }
GcArchitecture >> moeExperts [
	^ moeExperts
]

{ #category : 'accessing' }
GcArchitecture >> moeExperts: anInteger [
	moeExperts := anInteger
]

{ #category : 'accessing' }
GcArchitecture >> numHeads [
	^ numHeads
]

{ #category : 'accessing' }
GcArchitecture >> numHeads: anInteger [
	numHeads := anInteger
]

{ #category : 'accessing' }
GcArchitecture >> numLayers [
	^ numLayers
]

{ #category : 'accessing' }
GcArchitecture >> numLayers: anInteger [
	numLayers := anInteger
]

{ #category : 'views' }
GcArchitecture >> overviewFacets [
	^ {
		'Layers' -> numLayers.
		'Attention heads' -> numHeads.
		'KV heads (GQA)' -> kvHeads.
		'Hidden size' -> hiddenSize.
		'Head dim' -> self headDim.
		'MoE experts' -> moeExperts }
]

{ #category : 'printing' }
GcArchitecture >> printOn: aStream [
	aStream nextPutAll: 'GcArchitecture('.
	aStream print: numLayers.
	aStream nextPutAll: 'L x '.
	aStream print: hiddenSize.
	aStream nextPutAll: 'd)'
]
