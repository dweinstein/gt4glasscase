"
A byte range in a safetensors data area that is claimed by no tensor (kind #gap) or claimed twice (kind #overlap). Unclaimed bytes in a distributed artifact are a supply-chain red flag: they can carry payloads that no loader ever reads or checks.
"
Class {
	#name : 'GcSlackRange',
	#superclass : 'Object',
	#instVars : [
		'kind',
		'start',
		'end'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcSlackRange class >> kind: aSymbol start: aStart end: anEnd [
	^ self new
		kind: aSymbol;
		start: aStart;
		end: anEnd;
		yourself
]

{ #category : 'accessing' }
GcSlackRange >> byteSize [
	^ end - start
]

{ #category : 'accessing' }
GcSlackRange >> end [
	^ end
]

{ #category : 'accessing' }
GcSlackRange >> end: anEnd [
	end := anEnd
]

{ #category : 'accessing' }
GcSlackRange >> kind [
	^ kind
]

{ #category : 'accessing' }
GcSlackRange >> kind: aSymbol [
	kind := aSymbol
]

{ #category : 'printing' }
GcSlackRange >> printOn: aStream [
	aStream nextPutAll:
		kind asString , ' [' , start printString , ' .. ' , end printString , ') ' , self byteSize printString , ' bytes'
]

{ #category : 'accessing' }
GcSlackRange >> start [
	^ start
]

{ #category : 'accessing' }
GcSlackRange >> start: aStart [
	start := aStart
]
