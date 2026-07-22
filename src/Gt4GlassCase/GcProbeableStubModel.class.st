"
A hermetic TEST DOUBLE implementing the minimal 'probeable model' protocol that GcBehavioralConceptSpace / GcConceptProbe depend on: numLayers, prefillTokenIds:cache:, tokenizer, decoder. It has a tiny fixed vocabulary and deterministic logits (highest for the last prompt id + 1), so concept-probing machinery can be exercised in the test suite with NO weights, NO network, NO GPT-2 coupling. It doubles as executable documentation of the protocol another engine (or the Python/Modal oracle bridge) must implement to plug into the concept explorer. Its tokenizer/decoder are the stub itself (encode: maps each character to an id; decodeId: answers '<t NN>').
"
Class {
	#name : 'GcProbeableStubModel',
	#superclass : 'Object',
	#instVars : [
		'logitOverrides'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'api - probeable model' }
GcProbeableStubModel >> decodeId: anId [
	^ '<t', anId printString, '>'
]

{ #category : 'api - probeable model' }
GcProbeableStubModel >> decoder [
	"The stub is its own decoder (understands decodeId:)."
	^ self
]

{ #category : 'api - probeable model' }
GcProbeableStubModel >> encode: aString [
	"Deterministic toy tokenization: one id per character, folded into the tiny vocab."
	^ aString asArray collect: [ :ch | ch asInteger \\ self vocabSize ]
]

{ #category : 'accessing' }
GcProbeableStubModel >> logitOverrides [
	"nil by default (no override: exact original deterministic behavior). Otherwise a Dictionary keyed by an exact prompt-ids Array answering an integer peak-shift for THAT prompt, or a plain Integer applied unconditionally to every prompt -- lets two stub instances AGREE on some prompts and DISAGREE on others (see overrideFor:)."
	^ logitOverrides
]

{ #category : 'accessing' }
GcProbeableStubModel >> logitOverrides: aDictionaryOrInteger [
	logitOverrides := aDictionaryOrInteger
]

{ #category : 'api - probeable model' }
GcProbeableStubModel >> numLayers [
	"Part of the probeable-model protocol (see class comment)."
	^ 2
]

{ #category : 'private' }
GcProbeableStubModel >> overrideFor: ids [
	"The integer peak-shift to apply for this exact prompt (0 when logitOverrides is nil, or absent from a Dictionary override)."
	logitOverrides ifNil: [ ^ 0 ].
	(logitOverrides isKindOf: Dictionary) ifTrue: [ ^ logitOverrides at: ids asArray ifAbsent: [ 0 ] ].
	^ logitOverrides
]

{ #category : 'accessing' }
GcProbeableStubModel >> prefillTokenIds: ids cache: aCache [
	"Deterministic last-position 'logits' over the tiny vocab: highest at (last id + 1 + override) \\ vocabSize, then descending. override is 0 unless logitOverrides is set (see overrideFor:) -- backward compatible with the original fixed-peak behavior. No weights, no math kernels -- the protocol contract is 'answer a logits array for the last position'."
	| logits peak override |
	logits := Float64Array new: self vocabSize.
	override := self overrideFor: ids.
	peak := ((ids last + 1 + override) \\ self vocabSize) + 1.
	1 to: self vocabSize do: [ :i |
		logits at: i put: 0.0 - ((i - peak) abs / self vocabSize) ].
	^ logits
]

{ #category : 'api - probeable model' }
GcProbeableStubModel >> tokenizer [
	"The stub is its own tokenizer (understands encode:)."
	^ self
]

{ #category : 'api - probeable model' }
GcProbeableStubModel >> vocabSize [
	^ 64
]
