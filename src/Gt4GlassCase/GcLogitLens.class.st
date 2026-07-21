"
The logit lens over ONE GcForwardTrace: decode the FINAL-position residual stream at each depth (token+position embeddings, then each transformer block output) through the model's final LayerNorm (ln_f) and the tied unembedding (wte), revealing the top-k predicted tokens as they sharpen with depth. Holds the model's ln_f params + wte + config so it needs no live model. stages is an ordered collection of GcLogitLensStage (depth 0 = embeddings, depth i = output of block i-1). decoder may be nil (renders 'id N').
"
Class {
	#name : 'GcLogitLens',
	#superclass : 'Object',
	#instVars : [
		'lnfWeight',
		'lnfBias',
		'wte',
		'vocabSize',
		'dim',
		'eps',
		'decoder',
		'topK',
		'stages'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcLogitLens class >> fromTrace: aTrace lnfWeight: w lnfBias: b wte: table dim: d vocab: v eps: e decoder: dec topK: k [
	"Build a logit lens from a #residuals or #full GcForwardTrace, decoding each depth's final-position residual through ln_f (w, b) + the tied unembedding (table). dec may be nil (entries render 'id N')."
	| lens |
	lens := self new.
	lens
		lnfWeight: w;
		lnfBias: b;
		wte: table;
		dim: d;
		vocabSize: v;
		eps: e;
		decoder: dec;
		topK: k.
	lens buildStagesFromTrace: aTrace.
	^ lens
]

{ #category : 'instance creation' }
GcLogitLens class >> fromTrace: aTrace model: aModel [
	"Convenience: pull ln_f params, wte, dims and eps from a live GcGpt2Model and use the shared decoder with top-5."
	^ self
		fromTrace: aTrace
		lnfWeight: (aModel weight: 'ln_f.weight')
		lnfBias: (aModel weight: 'ln_f.bias')
		wte: (aModel weight: 'wte.weight')
		dim: aModel hiddenSize
		vocab: aModel vocabSize
		eps: aModel eps
		decoder: GcGpt2Decoder default
		topK: 5
]

{ #category : 'building' }
GcLogitLens >> buildStagesFromTrace: aTrace [
	"Depth 0 = the token+position embeddings (residualIn of the first block); depth i = the output of block i-1 (residualOut). Only the FINAL sequence position is decoded (the position whose next-token prediction the model actually emits)."
	| records |
	records := aTrace layerRecords.
	stages := OrderedCollection new.
	records isEmpty ifTrue: [ ^ stages ].
	stages add: (self stageAtDepth: 0 label: 'embed' residual: records first residualIn last).
	records doWithIndex: [ :rec :i |
		stages add: (self
			stageAtDepth: i
			label: ('block ' , rec layerIndex printString)
			residual: rec residualOut last) ].
	^ stages
]

{ #category : 'building' }
GcLogitLens >> decodeTokenId: anId [
	^ decoder isNil
		ifTrue: [ 'id ' , anId printString ]
		ifFalse: [ decoder decodeId: anId ]
]

{ #category : 'accessing' }
GcLogitLens >> decoder [
	^ decoder
]

{ #category : 'accessing' }
GcLogitLens >> decoder: aDecoderOrNil [
	decoder := aDecoderOrNil
]

{ #category : 'accessing' }
GcLogitLens >> dim [
	^ dim
]

{ #category : 'accessing' }
GcLogitLens >> dim: anInteger [
	dim := anInteger
]

{ #category : 'accessing' }
GcLogitLens >> eps [
	^ eps
]

{ #category : 'accessing' }
GcLogitLens >> eps: aNumber [
	eps := aNumber
]

{ #category : 'accessing' }
GcLogitLens >> finalStage [
	"The deepest depth: after the last transformer block. Decoding it must equal the model's own greedy prediction."
	^ stages last
]

{ #category : 'gt - views' }
GcLogitLens >> gtLogitLensFor: aView [
	"The heat strip: one row per depth (embeddings, then each block), showing how the top prediction for the final position sharpens as the residual stream is decoded through ln_f + the tied unembedding. Clicking a row opens that depth's full top-k."
	<gtView>
	^ aView columnedList
		title: 'Logit lens';
		priority: 5;
		items: [ self stages ];
		column: 'Depth' text: [ :st | st depth printString ];
		column: 'Layer' text: [ :st | st label ];
		column: 'Top token' text: [ :st | st topEntry displayToken ];
		column: 'Prob' text: [ :st | st topEntry probString ];
		column: 'Logit' text: [ :st | st topEntry logitString ];
		column: 'Top-k' text: [ :st | st topTokensSummary ]
]

{ #category : 'accessing' }
GcLogitLens >> lnfBias [
	^ lnfBias
]

{ #category : 'accessing' }
GcLogitLens >> lnfBias: aFloat64Array [
	lnfBias := aFloat64Array
]

{ #category : 'accessing' }
GcLogitLens >> lnfWeight [
	^ lnfWeight
]

{ #category : 'accessing' }
GcLogitLens >> lnfWeight: aFloat64Array [
	lnfWeight := aFloat64Array
]

{ #category : 'printing' }
GcLogitLens >> printOn: aStream [
	super printOn: aStream.
	stages ifNotNil: [
		aStream nextPutAll: ' ('; print: stages size; nextPutAll: ' stages'.
		stages ifNotEmpty: [ aStream nextPutAll: ', final='; nextPutAll: self finalStage topEntry displayToken ].
		aStream nextPutAll: ')' ]
]

{ #category : 'building' }
GcLogitLens >> stageAtDepth: aDepth label: aLabel residual: aVector [
	"Decode one residual vector: ln_f, tied unembed, softmax, top-k."
	| normed theLogits probs k |
	normed := GcTensorMath layerNorm: aVector gamma: lnfWeight beta: lnfBias eps: eps.
	theLogits := GcTensorMath unembedHidden: normed dim: dim table: wte vocab: vocabSize.
	probs := GcTensorMath softmax: theLogits.
	k := topK min: vocabSize.
	^ GcLogitLensStage new
		depth: aDepth;
		label: aLabel;
		entries: (self topEntriesFromLogits: theLogits probs: probs k: k);
		logits: theLogits;
		yourself
]

{ #category : 'accessing' }
GcLogitLens >> stages [
	^ stages
]

{ #category : 'accessing' }
GcLogitLens >> stages: aCollection [
	stages := aCollection
]

{ #category : 'building' }
GcLogitLens >> topEntriesFromLogits: logitsArray probs: probsArray k: k [
	"The k highest-logit tokens as GcLogitLensEntry objects, most likely first. Linear top-k selection (O(n*k)) -- NEVER asSortedCollection over the 50k vocab, which would be O(n^2) and freeze the image."
	| best |
	best := OrderedCollection new.
	1 to: logitsArray size do: [ :i |
		| v |
		v := logitsArray at: i.
		(best size < k or: [ v > (logitsArray at: best last) ]) ifTrue: [
			| inserted |
			inserted := false.
			1 to: best size do: [ :j |
				(inserted not and: [ v > (logitsArray at: (best at: j)) ]) ifTrue: [
					best add: i beforeIndex: j.
					inserted := true ] ].
			inserted ifFalse: [ best addLast: i ].
			best size > k ifTrue: [ best removeLast ] ] ].
	^ best withIndexCollect: [ :idx :r |
		| id |
		id := idx - 1.
		GcLogitLensEntry
			rank: r
			tokenId: id
			tokenText: (self decodeTokenId: id)
			logit: (logitsArray at: idx)
			prob: (probsArray at: idx) ]
]

{ #category : 'accessing' }
GcLogitLens >> topK [
	^ topK
]

{ #category : 'accessing' }
GcLogitLens >> topK: anInteger [
	topK := anInteger
]

{ #category : 'accessing' }
GcLogitLens >> vocabSize [
	^ vocabSize
]

{ #category : 'accessing' }
GcLogitLens >> vocabSize: anInteger [
	vocabSize := anInteger
]

{ #category : 'accessing' }
GcLogitLens >> wte [
	^ wte
]

{ #category : 'accessing' }
GcLogitLens >> wte: aFloat64Array [
	wte := aFloat64Array
]
