"
The outcome of ONE forward pass of GPT-2 run at a given GcWeightPrecision on a fixed prompt (token ids). Holds the last-position logits (a Float64Array over the 50257 vocab), the greedy (argmax) next-token id and its decoded text, the wall-clock forward time, and a reference to the f32 BASELINE logits so it can measure its own divergence from full precision: whether the greedy token FLIPS, and the max-abs and L2 logit divergence. The #f32 result is its own baseline (zero divergence). topEntries answers 'what are the top-k next tokens at this precision?' as reusable GcLogitLensEntry objects. This is the per-precision domain object that rows in a GcPrecisionComparison drill into.
"
Class {
	#name : 'GcPrecisionResult',
	#superclass : 'Object',
	#instVars : [
		'precision',
		'promptIds',
		'logits',
		'greedyId',
		'decoded',
		'baselineLogits',
		'forwardMs'
	],
	#category : 'Gt4GlassCase-Precision',
	#package : 'Gt4GlassCase',
	#tag : 'Precision'
}

{ #category : 'instance creation' }
GcPrecisionResult class >> precision: aPrecision promptIds: ids logits: aLogits baselineLogits: baseLogits forwardMs: ms [
	^ self new
		setPrecision: aPrecision promptIds: ids logits: aLogits baselineLogits: baseLogits forwardMs: ms
]

{ #category : 'divergence' }
GcPrecisionResult >> baselineGreedyId [
	^ GcTensorMath argmax: baselineLogits
]

{ #category : 'accessing' }
GcPrecisionResult >> baselineLogits [
	"The f32 full-precision logits this result measures divergence against (its own logits for the f32 result)."
	^ baselineLogits
]

{ #category : 'accessing' }
GcPrecisionResult >> decoded [
	"Decoded text of the greedy next token."
	^ decoded
]

{ #category : 'divergence' }
GcPrecisionResult >> flips [
	"Does the greedy next token DIFFER from the full-precision greedy token? The headline security signal: a flip means reduced precision changed the model's answer."
	^ greedyId ~= self baselineGreedyId
]

{ #category : 'accessing' }
GcPrecisionResult >> forwardMs [
	"Wall-clock milliseconds of the forward pass at this precision (includes nothing else)."
	^ forwardMs
]

{ #category : 'accessing' }
GcPrecisionResult >> greedyId [
	"0-based argmax token id (the greedy next token) at this precision."
	^ greedyId
]

{ #category : 'gt - views' }
GcPrecisionResult >> gtOverviewFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Overview';
		priority: 5;
		items: [ {
			'Precision' -> precision label.
			'Greedy token' -> decoded.
			'Greedy id' -> greedyId.
			'Baseline (f32) greedy id' -> self baselineGreedyId.
			'Flips vs f32?' -> self flips.
			'Max |delta logit|' -> self maxAbsLogitDivergence.
			'L2 logit divergence' -> self l2LogitDivergence.
			'Forward ms' -> forwardMs } ];
		column: 'Field' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value asString ];
		send: [ :assoc | self ]
]

{ #category : 'gt - views' }
GcPrecisionResult >> gtTopTokensFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Top-5 next tokens';
		priority: 10;
		items: [ self topEntries ];
		column: 'Rank' text: [ :e | e rank ] width: 50;
		column: 'Token' text: [ :e | e displayToken ];
		column: 'Id' text: [ :e | e tokenId ] width: 70;
		column: 'Logit' text: [ :e | e logitString ] width: 90;
		column: 'Prob' text: [ :e | e probString ] width: 90;
		send: [ :e | e ]
]

{ #category : 'testing' }
GcPrecisionResult >> isBaseline [
	"True for the full-precision result -- the divergence baseline."
	^ precision isFullPrecision
]

{ #category : 'divergence' }
GcPrecisionResult >> l2LogitDivergence [
	"Euclidean (L2) norm of the logit difference vector vs the f32 baseline."
	| s |
	s := 0.0.
	1 to: logits size do: [ :i |
		| d |
		d := (logits at: i) - (baselineLogits at: i).
		s := s + (d * d) ].
	^ s sqrt
]

{ #category : 'accessing' }
GcPrecisionResult >> logits [
	"Last-position logits over the 50257 vocab at this precision."
	^ logits
]

{ #category : 'divergence' }
GcPrecisionResult >> maxAbsLogitDivergence [
	"Max over the vocab of |logit_i - baselineLogit_i|."
	| m |
	m := 0.0.
	1 to: logits size do: [ :i |
		| d |
		d := ((logits at: i) - (baselineLogits at: i)) abs.
		d > m ifTrue: [ m := d ] ].
	^ m
]

{ #category : 'accessing' }
GcPrecisionResult >> precision [
	^ precision
]

{ #category : 'printing' }
GcPrecisionResult >> printOn: aStream [
	super printOn: aStream.
	aStream nextPutAll: ' '; nextPutAll: precision label;
		nextPutAll: ' -> '; nextPutAll: decoded printString;
		nextPutAll: ' (id '; print: greedyId; nextPutAll: ')'
]

{ #category : 'accessing' }
GcPrecisionResult >> promptIds [
	^ promptIds
]

{ #category : 'initialization' }
GcPrecisionResult >> setPrecision: aPrecision promptIds: ids logits: aLogits baselineLogits: baseLogits forwardMs: ms [
	precision := aPrecision.
	promptIds := ids.
	logits := aLogits.
	baselineLogits := baseLogits.
	forwardMs := ms.
	greedyId := GcTensorMath argmax: logits.
	decoded := GcGpt2Decoder default decodeId: greedyId
]

{ #category : 'querying' }
GcPrecisionResult >> topEntries [
	"The top-5 next tokens at this precision."
	^ self topEntries: 5
]

{ #category : 'querying' }
GcPrecisionResult >> topEntries: k [
	"The k highest-logit next tokens as reusable GcLogitLensEntry objects, most likely first. Linear top-k selection (O(n*k)) -- NEVER asSortedCollection over the 50k vocab, which would freeze the image (reuses the GcLogitLens>>topEntriesFromLogits:probs:k: idiom)."
	| probs best |
	probs := GcTensorMath softmax: logits.
	best := OrderedCollection new.
	1 to: logits size do: [ :i |
		| v |
		v := logits at: i.
		(best size < k or: [ v > (logits at: best last) ]) ifTrue: [
			| inserted |
			inserted := false.
			1 to: best size do: [ :j |
				(inserted not and: [ v > (logits at: (best at: j)) ]) ifTrue: [
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
			tokenText: (GcGpt2Decoder default decodeId: id)
			logit: (logits at: idx)
			prob: (probs at: idx) ]
]
