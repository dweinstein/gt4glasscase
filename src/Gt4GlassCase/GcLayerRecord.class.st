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
		'residualOut'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'accessing' }
GcLayerRecord >> attnOut [
	^ attnOut
]

{ #category : 'accessing' }
GcLayerRecord >> attnOut: aCollection [
	attnOut := aCollection
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
