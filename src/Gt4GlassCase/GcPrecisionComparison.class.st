"
THE precision-differential audit made executable (the Glass Case headline). Given a prompt (token ids) and a list of GcWeightPrecisions, it runs the SAME GPT-2 forward once per precision on a FRESH model (never the shared default) and holds one GcPrecisionResult each, with #f32 as the divergence baseline. It answers the security-relevant question: does the model stay clean at bf16 yet MISBEHAVE at int4? i.e. does the greedy next token flip, and how far do the logits move, as precision drops. gtComparisonFor: is the side-by-side table (precision | greedy token | flips? | max|delta-logit| | L2) whose rows drill into each GcPrecisionResult. Build one with #promptIds: then #runWith:precisions: (slow: each precision is a cold weight decode + re-quantize + forward).
"
Class {
	#name : 'GcPrecisionComparison',
	#superclass : 'Object',
	#instVars : [
		'promptIds',
		'results',
		'baselineResult'
	],
	#category : 'Gt4GlassCase-Precision',
	#package : 'Gt4GlassCase',
	#tag : 'Precision'
}

{ #category : 'instance creation' }
GcPrecisionComparison class >> promptIds: ids [
	^ self new setPromptIds: ids
]

{ #category : 'running' }
GcPrecisionComparison >> addPrecision: aPrecisionOrSymbol with: aModel [
	"Run one non-f32 precision forward on aModel and append its result, measuring divergence against the already-computed f32 baseline. Enables driving the (slow) comparison one precision per step."
	| p result |
	baselineResult ifNil: [ ^ self error: 'run the f32 baseline first (runBaselineWith:)' ].
	p := GcWeightPrecision fromSymbol: aPrecisionOrSymbol.
	result := self runPrecision: p on: aModel baseline: baselineResult logits.
	results add: result.
	^ result
]

{ #category : 'accessing' }
GcPrecisionComparison >> baselineResult [
	"The f32 full-precision result (the divergence baseline)."
	^ baselineResult
]

{ #category : 'gt - views' }
GcPrecisionComparison >> gtComparisonFor: aView [
	"THE precision-differential view: one row per precision, f32 baseline first, showing the greedy next token and how far each reduced-precision run diverges from full precision. A FLIP (greedy token changed) is the headline security signal. Rows drill into the per-precision GcPrecisionResult."
	<gtView>
	results isEmpty ifTrue: [ ^ aView empty ].
	^ aView columnedList
		title: 'Precision differential';
		priority: 10;
		items: [ results ];
		column: 'Precision' text: [ :r | r precision label ] width: 90;
		column: 'Greedy token' text: [ :r | r decoded printString ];
		column: 'Id' text: [ :r | r greedyId ] width: 70;
		column: 'Flips vs f32?' text: [ :r | r isBaseline ifTrue: [ '-- (baseline)' ] ifFalse: [ r flips ifTrue: [ 'YES' ] ifFalse: [ 'no' ] ] ] width: 110;
		column: 'Max |delta logit|' text: [ :r | r isBaseline ifTrue: [ '0' ] ifFalse: [ r maxAbsLogitDivergence printShowingDecimalPlaces: 4 ] ] width: 130;
		column: 'L2 divergence' text: [ :r | r isBaseline ifTrue: [ '0' ] ifFalse: [ r l2LogitDivergence printShowingDecimalPlaces: 4 ] ] width: 120;
		column: 'Forward ms' text: [ :r | r forwardMs ] width: 90;
		send: [ :r | r ]
]

{ #category : 'gt - views' }
GcPrecisionComparison >> gtPromptFor: aView [
	"The prompt this differential was run on, decoded."
	<gtView>
	^ aView textEditor
		title: 'Prompt';
		priority: 4;
		text: [ self promptText , String cr , String cr , 'token ids: ' , promptIds printString ]
]

{ #category : 'querying' }
GcPrecisionComparison >> nonBaselineResults [
	^ results reject: [ :r | r isBaseline ]
]

{ #category : 'printing' }
GcPrecisionComparison >> printOn: aStream [
	super printOn: aStream.
	aStream nextPutAll: ' ('; print: results size; nextPutAll: ' precisions)'
]

{ #category : 'accessing' }
GcPrecisionComparison >> promptIds [
	^ promptIds
]

{ #category : 'accessing' }
GcPrecisionComparison >> promptText [
	"The decoded prompt text."
	^ String streamContents: [ :s |
		promptIds do: [ :id | s nextPutAll: (GcGpt2Decoder default decodeId: id) ] ]
]

{ #category : 'accessing' }
GcPrecisionComparison >> results [
	"One GcPrecisionResult per precision, f32 baseline first."
	^ results
]

{ #category : 'running' }
GcPrecisionComparison >> runBaselineWith: aModel [
	"Run the #f32 full-precision baseline forward on aModel and record it as the divergence baseline. Must be called before any non-f32 precision."
	baselineResult := self runPrecision: GcWeightPrecision f32 on: aModel baseline: nil.
	results add: baselineResult.
	^ baselineResult
]

{ #category : 'running' }
GcPrecisionComparison >> runPrecision: aPrecision on: aModel baseline: baseLogitsOrNil [
	"Set aModel to aPrecision (invalidating + re-quantizing its weight cache), run one forward on promptIds, and package the result. For the f32 baseline pass baseLogitsOrNil = nil (it becomes its own baseline)."
	| logits ms |
	aModel precision: aPrecision.
	ms := [ logits := aModel forwardTokenIds: promptIds ] millisecondsToRun.
	^ GcPrecisionResult
		precision: aPrecision
		promptIds: promptIds
		logits: logits
		baselineLogits: (baseLogitsOrNil ifNil: [ logits ])
		forwardMs: ms
]

{ #category : 'running' }
GcPrecisionComparison >> runWith: aModel precisions: aCollectionOfPrecisionsOrSymbols [
	"Run the SAME forward once per precision on aModel -- which MUST be a FRESH model (e.g. GcGpt2Model openDefault), never the shared default, since setting precision invalidates its weight cache. Always computes the #f32 baseline FIRST so every other result measures divergence against it, then each requested non-f32 precision in order. Leaves aModel with its weights unloaded. Returns self."
	| precs |
	precs := aCollectionOfPrecisionsOrSymbols collect: [ :each | GcWeightPrecision fromSymbol: each ].
	results := OrderedCollection new.
	self runBaselineWith: aModel.
	precs do: [ :p | p isFullPrecision ifFalse: [ self addPrecision: p with: aModel ] ].
	aModel unloadWeights.
	^ self
]

{ #category : 'initialization' }
GcPrecisionComparison >> setPromptIds: ids [
	promptIds := ids.
	results := OrderedCollection new
]
