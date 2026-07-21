"
An optional recording of ONE forward pass: the input token ids, an ordered collection of GcLayerRecords (one per transformer block, recorded only when traceLevel is #residuals or #full), and the final-position logits. traceLevel is #none (record nothing), #residuals (residual-in / residual-mid / residual-out per layer) or #full (also attn-out / mlp-out). Kept lightweight so tracing a short prompt costs a few KB, not the model's gigabyte of weights.
"
Class {
	#name : 'GcForwardTrace',
	#superclass : 'Object',
	#instVars : [
		'inputIds',
		'layerRecords',
		'finalLogits',
		'traceLevel'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'accessing' }
GcForwardTrace >> addLayerRecord: aRecord [
	self layerRecords add: aRecord
]

{ #category : 'accessing' }
GcForwardTrace >> finalLogits [
	^ finalLogits
]

{ #category : 'accessing' }
GcForwardTrace >> finalLogits: aFloatArray [
	finalLogits := aFloatArray
]

{ #category : 'accessing' }
GcForwardTrace >> inputIds [
	^ inputIds
]

{ #category : 'accessing' }
GcForwardTrace >> inputIds: aCollection [
	inputIds := aCollection
]

{ #category : 'accessing' }
GcForwardTrace >> layerRecords [
	^ layerRecords ifNil: [ layerRecords := OrderedCollection new ]
]

{ #category : 'printing' }
GcForwardTrace >> printOn: aStream [
	super printOn: aStream.
	aStream nextPutAll: '('; print: self layerRecords size; nextPutAll: ' layers, level '; print: self traceLevel; nextPut: $)
]

{ #category : 'accessing' }
GcForwardTrace >> traceLevel [
	^ traceLevel ifNil: [ #none ]
]

{ #category : 'accessing' }
GcForwardTrace >> traceLevel: aSymbol [
	traceLevel := aSymbol
]
