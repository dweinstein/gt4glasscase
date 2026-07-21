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
		'model',
		'phaseSteps'
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

{ #category : 'gt - views' }
GcGeneration >> gtPhasesFor: aView [
	<gtView>
	phaseSteps isNil ifTrue: [ ^ aView empty ].
	^ aView columnedList
		title: 'Phases';
		priority: 6;
		items: [ phaseSteps ];
		column: 'Phase' text: [ :step | step phase printString ];
		column: 'Tokens' text: [ :step | step tokenCount printString ];
		column: 'ms' text: [ :step | step milliseconds printString ];
		column: 'ms / token' text: [ :step | step msPerToken printString ];
		column: 'seqLen after' text: [ :step | step seqLengthAfter printString ];
		column: 'time' text: [ :step |
			| maxMs bars |
			maxMs := (phaseSteps collect: [ :s | s milliseconds ]) max.
			bars := maxMs = 0 ifTrue: [ 1 ] ifFalse: [ (step milliseconds / maxMs * 30) rounded max: 1 ].
			String new: bars withAll: $= ];
		send: [ :step | step ]
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

{ #category : 'gt - views' }
GcGeneration >> gtTokenBoxesFor: aView [
	<gtView>
	"The generation as teaching token boxes: prompt tokens (blue) vs greedily generated tokens (green), special / EOT tokens highlighted; a box click spawns the token object."
	^ aView explicit
		title: 'Token boxes';
		priority: 11;
		stencil: [ self tokenBoxesElement ]
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
GcGeneration >> isCached [
	"True when produced by the KV-cached path (has recorded prefill/decode phase steps)."
	^ phaseSteps notNil
]

{ #category : 'accessing' }
GcGeneration >> model [
	^ model
]

{ #category : 'accessing' }
GcGeneration >> model: aModel [
	model := aModel
]

{ #category : 'accessing' }
GcGeneration >> phaseSteps [
	^ phaseSteps
]

{ #category : 'accessing' }
GcGeneration >> phaseSteps: aCollection [
	phaseSteps := aCollection
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

{ #category : 'displaying' }
GcGeneration >> tokenBoxesElement [
	"A wrapping row of teaching token boxes for the whole generation: prompt tokens vs greedily generated tokens in distinct colours, special / EOT tokens highlighted; a box click spawns the GcEncodedToken."
	| decoder promptSize flow |
	decoder := GcGpt2Decoder default.
	promptSize := promptIds size.
	flow := BrHorizontalFlow new
		matchParent;
		padding: (BlInsets all: 10);
		yourself.
	self allIds doWithIndex: [ :id :i |
		| piece isSpecial tok color |
		piece := (decoder pieceForId: id) ifNil: [ '?' ].
		isSpecial := (piece beginsWith: '<|') and: [ piece endsWith: '|>' ].
		tok := GcEncodedToken new
			index: i;
			tokenId: id;
			piece: piece;
			special: isSpecial;
			yourself.
		color := isSpecial
			ifTrue: [ GcEncodedToken specialColor ]
			ifFalse: [ i <= promptSize
				ifTrue: [ GcEncodedToken promptColor ]
				ifFalse: [ GcEncodedToken generatedColor ] ].
		flow addChild: (tok boxElementBackground: color) ].
	^ flow
]
