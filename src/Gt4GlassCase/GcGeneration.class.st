"
The result of greedy generation: the prompt token ids, the greedily generated token ids (in order), the per-step last-position logits (Float64Array per generated token), and the producing GcGpt2Model. Decodes text lazily via GcGpt2Decoder default: promptText, generatedText and decodedText (prompt + continuation). gtTokensFor: shows the token strip, distinguishing prompt tokens from generated ones.
"
Class {
	#name : 'GcGeneration',
	#superclass : 'Object',
	#instVars : [
		'promptIds',
		'generatedIds',
		'stepLogits',
		'model'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'accessing' }
GcGeneration >> allIds [
	"Prompt ids followed by generated ids, as a single Array."
	^ promptIds asArray , generatedIds asArray
]

{ #category : 'decoding' }
GcGeneration >> decodedText [
	"The full decoded text: prompt continuation together."
	^ GcGpt2Decoder default decodeIds: self allIds
]

{ #category : 'accessing' }
GcGeneration >> generatedIds [
	^ generatedIds
]

{ #category : 'accessing' }
GcGeneration >> generatedIds: aCollection [
	generatedIds := aCollection
]

{ #category : 'decoding' }
GcGeneration >> generatedText [
	"The decoded continuation (generated tokens only)."
	^ GcGpt2Decoder default decodeIds: generatedIds asArray
]

{ #category : 'views' }
GcGeneration >> gtTextFor: aView [
	<gtView>
	"The full decoded prompt + continuation as readable text."
	^ aView textEditor
		title: 'Text';
		priority: 20;
		text: [ self decodedText ]
]

{ #category : 'views' }
GcGeneration >> gtTokensFor: aView [
	<gtView>
	"A token strip of the prompt followed by the greedily generated tokens: position, kind (prompt vs generated), id and decoded piece. Clicking a row opens the decoded piece text."
	| decoder rows pos |
	decoder := GcGpt2Decoder default.
	rows := OrderedCollection new.
	pos := 0.
	promptIds asArray do: [ :id | pos := pos + 1. rows add: { pos. id. (decoder decodeId: id). true } ].
	generatedIds asArray do: [ :id | pos := pos + 1. rows add: { pos. id. (decoder decodeId: id). false } ].
	^ aView columnedList
		title: 'Tokens';
		priority: 10;
		items: [ rows ];
		column: '#' text: [ :row | row first asString ];
		column: 'Kind' text: [ :row | (row fourth) ifTrue: [ 'prompt' ] ifFalse: [ 'generated' ] ];
		column: 'Id' text: [ :row | row second asString ];
		column: 'Piece' text: [ :row | row third ];
		send: [ :row | row third ]
]

{ #category : 'accessing' }
GcGeneration >> model [
	^ model
]

{ #category : 'accessing' }
GcGeneration >> model: aModel [
	model := aModel
]

{ #category : 'printing' }
GcGeneration >> printOn: aStream [
	super printOn: aStream.
	aStream nextPutAll: ' ('; print: promptIds size; nextPutAll: ' prompt + '; print: generatedIds size; nextPutAll: ' generated)'
]

{ #category : 'accessing' }
GcGeneration >> promptIds [
	^ promptIds
]

{ #category : 'accessing' }
GcGeneration >> promptIds: aCollection [
	promptIds := aCollection
]

{ #category : 'decoding' }
GcGeneration >> promptText [
	^ GcGpt2Decoder default decodeIds: promptIds asArray
]

{ #category : 'accessing' }
GcGeneration >> stepLogits [
	^ stepLogits
]

{ #category : 'accessing' }
GcGeneration >> stepLogits: aCollection [
	stepLogits := aCollection
]
