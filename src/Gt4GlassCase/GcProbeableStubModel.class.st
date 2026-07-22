"
A hermetic TEST DOUBLE implementing the minimal 'probeable model' protocol that GcBehavioralConceptSpace / GcConceptProbe depend on: numLayers, prefillTokenIds:cache:, tokenizer, decoder. It has a tiny fixed vocabulary and deterministic logits (highest for the last prompt id + 1), so concept-probing machinery can be exercised in the test suite with NO weights, NO network, NO GPT-2 coupling. It doubles as executable documentation of the protocol another engine (or the Python/Modal oracle bridge) must implement to plug into the concept explorer. Its tokenizer/decoder are the stub itself (encode: maps each character to an id; decodeId: answers '<t NN>').
"
Class {
	#name : 'GcProbeableStubModel',
	#superclass : 'Object',
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

{ #category : 'api - probeable model' }
GcProbeableStubModel >> numLayers [
	"Part of the probeable-model protocol (see class comment)."
	^ 2
]

{ #category : 'api - probeable model' }
GcProbeableStubModel >> prefillTokenIds: ids cache: aCache [
	"Deterministic last-position 'logits' over the tiny vocab: highest at (last id + 1) \\ vocabSize, then descending. No weights, no math kernels -- the protocol contract is 'answer a logits array for the last position'."
	| logits peak |
	logits := Float64Array new: self vocabSize.
	peak := ((ids last + 1) \\ self vocabSize) + 1.
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
