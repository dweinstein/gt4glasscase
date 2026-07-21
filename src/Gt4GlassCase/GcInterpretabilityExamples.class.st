"
gtExample methods for the interpretability teaching views (logit lens + per-head attention heatmaps). syntheticLogitLensExample / syntheticAttentionHeadsExample are hermetic (NO model, tiny hand-computable dims). The e2e examples are <noTest> (load the real GPT-2 weights).
"
Class {
	#name : 'GcInterpretabilityExamples',
	#superclass : 'Object',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'asserting' }
GcInterpretabilityExamples >> assert: actual equals: expected [
	actual = expected ifFalse: [ self error: 'expected ' , expected printString , ' but got ' , actual printString ]
]

{ #category : 'asserting' }
GcInterpretabilityExamples >> assertTrue: aBoolean [
	aBoolean ifFalse: [ self error: 'assertion failed' ]
]

{ #category : 'fixtures' }
GcInterpretabilityExamples >> floats: anArray [
	^ Float64Array withAll: (anArray collect: [ :x | x asFloat ])
]

{ #category : 'fixtures' }
GcInterpretabilityExamples >> franceInContextPromptIds [
	"Token ids for 'The capital of France is Paris. The capital of France is' (reused from the inference examples)."
	^ GcGpt2InferenceExamples new franceInContextPromptIds
]

{ #category : 'examples' }
GcInterpretabilityExamples >> franceLogitLensAndAttentionExample [
	<gtExample>
	<noTest>
	"End-to-end on the real GPT-2-124M weights. Traces 'The capital of France is Paris. The capital of France is' at #full, then builds BOTH teaching views. The logit lens' FINAL depth (after block 11) reproduces the model's own greedy prediction: id 6342 = ' Paris' -- watch it emerge up the 13 depths. Also asserts the last layer captured 12 causal heads and both teaching elements build. Frees the weights at the end. <noTest>: loads ~500MB of weights."
	| model ids trace labels lens lastRec heads result |
	model := GcGpt2Model default.
	ids := self franceInContextPromptIds.
	trace := model tracedForwardTokenIds: ids level: #full.
	labels := ids collect: [ :each | GcGpt2Decoder default decodeId: each ].
	trace layerRecords do: [ :rec | rec tokenLabels: labels ].
	lens := GcLogitLens fromTrace: trace model: model.
	lastRec := trace layerRecords last.
	heads := lastRec attentionHeads.
	self assert: lens stages size equals: 13.
	self assert: lens finalStage depth equals: 12.
	self assert: lens finalStage topEntry tokenId equals: 6342.
	self assert: lens finalStage topEntry tokenText equals: ' Paris'.
	self assert: (GcTensorMath argmax: trace finalLogits) equals: 6342.
	self assert: lastRec numHeads equals: 12.
	self assert: heads size equals: 12.
	self assertTrue: (lastRec attentionOverviewElement isKindOf: BlElement).
	self assertTrue: (heads first heatmapElement isKindOf: BlElement).
	self assert: heads first seqLen equals: ids size.
	result := Dictionary new.
	result
		at: #lens put: lens;
		at: #lastLayer put: lastRec;
		at: #greedyId put: (GcTensorMath argmax: trace finalLogits);
		at: #finalTopToken put: lens finalStage topEntry tokenText;
		at: #numHeads put: lastRec numHeads.
	model unloadWeights.
	^ result
]

{ #category : 'examples' }
GcInterpretabilityExamples >> syntheticAttentionHeadsExample [
	<gtExample>
	"Hermetic: build the per-head attention heatmap elements from a synthetic layer record. Asserts one head object per captured head, causal zeros strictly above the diagonal, that the small-multiples overview and the labelled heatmap both build (BlElement, one tile per head), and that axis labels come from the record's tokenLabels. Proves the attention-view LOGIC without the model."
	| trace rec heads overview causalOk |
	trace := self syntheticForwardTrace.
	rec := trace layerRecords first.
	heads := rec attentionHeads.
	self assert: rec numHeads equals: 2.
	self assert: heads size equals: 2.
	self assert: heads first layerIndex equals: 0.
	self assert: heads first headIndex equals: 0.
	self assert: heads first seqLen equals: 3.
	causalOk := true.
	heads do: [ :head |
		1 to: head seqLen do: [ :qi |
			qi + 1 to: head seqLen do: [ :kj |
				(head weightAtQuery: qi key: kj) = 0.0 ifFalse: [ causalOk := false ] ] ] ].
	self assertTrue: causalOk.
	overview := rec attentionOverviewElement.
	self assertTrue: (overview isKindOf: BlElement).
	self assert: overview children size equals: 2.
	self assertTrue: (heads first tileElement isKindOf: BlElement).
	self assertTrue: (heads first heatmapElement isKindOf: BlElement).
	self assert: (heads first labelAt: 1) equals: 'The'.
	^ rec
]

{ #category : 'fixtures' }
GcInterpretabilityExamples >> syntheticAttentionMatrices [
	"2 heads, seq 3, causal (0 above the diagonal); each query row sums to 1 over the allowed keys."
	^ {
		{ self floats: #(1 0 0). self floats: #(0.5 0.5 0). self floats: #(0.3 0.3 0.4) }.
		{ self floats: #(1 0 0). self floats: #(0.2 0.8 0). self floats: #(0.1 0.2 0.7) } }
]

{ #category : 'fixtures' }
GcInterpretabilityExamples >> syntheticForwardTrace [
	"A hermetic #full trace: 2 layers, seq 3, dim 4. residualIn/residualOut are chosen so the logit lens' final-depth top-1 is a KNOWN token id; attnWeights are causal 2-head matrices; tokenLabels annotate the axes. NO model, NO weights."
	| r0 r1 trace |
	r0 := GcLayerRecord new
		layerIndex: 0;
		residualIn: { self floats: #(4 3 2 1). self floats: #(0 0 0 0). self floats: #(4 3 2 1) };
		residualOut: { self floats: #(9 9 9 9). self floats: #(0 0 0 0). self floats: #(0 1 0 1) };
		attnWeights: self syntheticAttentionMatrices;
		tokenLabels: self syntheticTokenLabels;
		yourself.
	r1 := GcLayerRecord new
		layerIndex: 1;
		residualIn: r0 residualOut;
		residualOut: { self floats: #(5 5 5 5). self floats: #(0 0 0 0). self floats: #(1 2 3 4) };
		attnWeights: self syntheticAttentionMatrices;
		tokenLabels: self syntheticTokenLabels;
		yourself.
	trace := GcForwardTrace new traceLevel: #full; yourself.
	trace addLayerRecord: r0; addLayerRecord: r1.
	^ trace
]

{ #category : 'fixtures' }
GcInterpretabilityExamples >> syntheticLogitLens [
	"The logit lens over the synthetic trace. ln_f is identity (gamma=1, beta=0); wte's three rows are crafted so that decoding the final residual [1,2,3,4] gives argmax token id 1."
	^ GcLogitLens
		fromTrace: self syntheticForwardTrace
		lnfWeight: (self floats: #(1 1 1 1))
		lnfBias: (self floats: #(0 0 0 0))
		wte: (self floats: #(1 1 1 1 -2 -1 1 2 2 1 -1 -2))
		dim: 4
		vocab: 3
		eps: 1.0e-5
		decoder: nil
		topK: 3
]

{ #category : 'examples' }
GcInterpretabilityExamples >> syntheticLogitLensExample [
	<gtExample>
	"Hermetic: NO model, NO weights, tiny hand-computable dims. Decoding the final residual [1,2,3,4] through the identity ln_f and the crafted unembedding must make token id 1 the argmax at the final depth. This proves the logit-lens LOGIC (ln_f -> tied unembed -> softmax -> top-k) without the 1GB model."
	| lens final |
	lens := self syntheticLogitLens.
	self assert: lens stages size equals: 3.
	self assertTrue: (lens stages collect: [ :s | s label ]) asArray = #('embed' 'block 0' 'block 1').
	final := lens finalStage.
	self assert: final depth equals: 2.
	self assert: final topEntry tokenId equals: 1.
	self assert: final entries size equals: 3.
	self assertTrue: (final entries collect: [ :e | e tokenId ]) asArray = #(1 0 2).
	self assertTrue: final topEntry logit > final entries second logit.
	self assertTrue: (final topEntry prob between: 0.0 and: 1.0).
	^ lens
]

{ #category : 'fixtures' }
GcInterpretabilityExamples >> syntheticTokenLabels [
	^ #('The' ' cap' ' of')
]
