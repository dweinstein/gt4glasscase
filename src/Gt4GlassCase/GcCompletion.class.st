"
One model output: text, token ids, logprobs, stop reason, latency. A single cell in the hypercube.
"
Class {
	#name : 'GcCompletion',
	#superclass : 'Object',
	#instVars : [
		'run',
		'text',
		'tokenIds',
		'logprobs',
		'stopReason',
		'latencyMs'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcCompletion class >> run: aRun text: aString [
	^ self new
		run: aRun;
		text: aString;
		yourself
]

{ #category : 'hypercube' }
GcCompletion >> coordinate [
	^ run ifNil: [ GcCoordinate new ] ifNotNil: [ :r | r coordinate ]
]

{ #category : 'accessing' }
GcCompletion >> latencyMs [
	^ latencyMs
]

{ #category : 'accessing' }
GcCompletion >> latencyMs: aNumber [
	latencyMs := aNumber
]

{ #category : 'accessing' }
GcCompletion >> logprobs [
	^ logprobs
]

{ #category : 'accessing' }
GcCompletion >> logprobs: aCollection [
	logprobs := aCollection
]

{ #category : 'printing' }
GcCompletion >> printOn: aStream [
	aStream nextPutAll: 'GcCompletion('.
	aStream print: self tokenCount.
	aStream nextPutAll: ' tokens)'
]

{ #category : 'accessing' }
GcCompletion >> run [
	^ run
]

{ #category : 'accessing' }
GcCompletion >> run: aRun [
	run := aRun
]

{ #category : 'accessing' }
GcCompletion >> stopReason [
	^ stopReason
]

{ #category : 'accessing' }
GcCompletion >> stopReason: aSymbol [
	stopReason := aSymbol
]

{ #category : 'accessing' }
GcCompletion >> text [
	^ text
]

{ #category : 'accessing' }
GcCompletion >> text: aString [
	text := aString
]

{ #category : 'querying' }
GcCompletion >> tokenCount [
	^ tokenIds ifNil: [ 0 ] ifNotNil: [ :t | t size ]
]

{ #category : 'accessing' }
GcCompletion >> tokenIds [
	^ tokenIds
]

{ #category : 'accessing' }
GcCompletion >> tokenIds: aCollection [
	tokenIds := aCollection
]
