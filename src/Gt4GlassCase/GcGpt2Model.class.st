"
A loaded GPT-2 model: a parsed GcSafetensorsFile plus its GcModelConfig. Decodes each weight tensor to a row-major Float64Array LAZILY and CACHES it (weightCache: name -> Float64Array), so the ~124M F32 params are read and widened to F64 at most once. Implements the full pre-norm GPT-2 forward pass (token+position embeddings, 12 causal multi-head self-attention + gelu_new MLP blocks via the HF Conv1D no-transpose convention, final LayerNorm, tied unembedding) and greedy generation. No KV cache yet: generation recomputes the full sequence each step. openDefault / default load from the local glassbox cache. forwardTokenIds: returns last-position logits; generateFromTokenIds:maxTokens: returns a GcGeneration.
"
Class {
	#name : 'GcGpt2Model',
	#superclass : 'Object',
	#instVars : [
		'file',
		'config',
		'weightCache',
		'tensorIndex',
		'numLayers',
		'numHeads',
		'hiddenSize',
		'vocabSize',
		'headDim',
		'eps'
	],
	#classVars : [
		'DefaultModel'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'accessing' }
GcGpt2Model class >> cachePath [
	"Local glassbox cache directory holding the GPT-2 weights and config."
	^ FileLocator home / '.cache' / 'glassbox' / 'gpt2'
]

{ #category : 'instance creation' }
GcGpt2Model class >> default [
	"A memoized shared model so the ~500 MB of weights are decoded at most once per image session (both end-to-end examples reuse the warm weight cache)."
	^ DefaultModel ifNil: [ DefaultModel := self openDefault ]
]

{ #category : 'instance creation' }
GcGpt2Model class >> openDefault [
	"Load the openai-community/gpt2 weights + config from the local glassbox cache into a FRESH model (empty weight cache). Mirrors GcHuggingFaceModelSource>>safetensorsFile construction with a local-file bytes provider."
	| dir provider file hdrLenBytes hdrLen hdrBytes hdrString cfg |
	dir := self cachePath.
	provider := GcLocalFileBytesProvider forPath: dir / 'model.safetensors'.
	file := GcSafetensorsFile new bytesProvider: provider; yourself.
	hdrLenBytes := provider provideBytesFrom: 0 to: 7.
	hdrLen := 0.
	0 to: 7 do: [ :i | hdrLen := hdrLen + ((hdrLenBytes at: i + 1) bitShift: 8 * i) ].
	hdrBytes := provider provideBytesFrom: 8 to: 8 + hdrLen - 1.
	hdrString := hdrBytes utf8Decoded.
	file parseHeaderString: hdrString.
	cfg := GcModelConfig fromDictionary: (STONJSON fromString: (dir / 'config.json') contents).
	^ self new initializeFile: file config: cfg; yourself
]

{ #category : 'instance creation' }
GcGpt2Model class >> reset [
	"Drop the memoized default model (frees its decoded-weight cache)."
	DefaultModel := nil
]

{ #category : 'forward pass' }
GcGpt2Model >> applyBlock: li to: inHidden seqLen: seqLen scale: scale trace: aTrace level: level [
	"One pre-norm transformer block li (0-based) over the per-position hidden states inHidden. attn: x + c_proj(attention(LN1(x))); mlp: y + c_proj(gelu_new(c_fc(LN2(y)))). All linears use the HF Conv1D no-transpose convention. Returns the block output; records a GcLayerRecord when level is #residuals or #full."
	| d prefix ln1W ln1B cAttnW cAttnB cProjW cProjB ln2W ln2B cFcW cFcB cMlpW cMlpB normed qkv attnOut attnProj midHidden normed2 fc act mlpOut outHidden record |
	d := hiddenSize.
	prefix := 'h.', li printString, '.'.
	ln1W := self weight: prefix, 'ln_1.weight'.
	ln1B := self weight: prefix, 'ln_1.bias'.
	cAttnW := self weight: prefix, 'attn.c_attn.weight'.
	cAttnB := self weight: prefix, 'attn.c_attn.bias'.
	cProjW := self weight: prefix, 'attn.c_proj.weight'.
	cProjB := self weight: prefix, 'attn.c_proj.bias'.
	ln2W := self weight: prefix, 'ln_2.weight'.
	ln2B := self weight: prefix, 'ln_2.bias'.
	cFcW := self weight: prefix, 'mlp.c_fc.weight'.
	cFcB := self weight: prefix, 'mlp.c_fc.bias'.
	cMlpW := self weight: prefix, 'mlp.c_proj.weight'.
	cMlpB := self weight: prefix, 'mlp.c_proj.bias'.
	normed := inHidden collect: [ :x | GcTensorMath layerNorm: x gamma: ln1W beta: ln1B eps: eps ].
	qkv := normed collect: [ :a | GcTensorMath mmulNoTransposeInput: a inSize: d weight: cAttnW outSize: 3 * d bias: cAttnB ].
	attnOut := self attentionFrom: qkv seqLen: seqLen scale: scale.
	attnProj := attnOut collect: [ :o | GcTensorMath mmulNoTransposeInput: o inSize: d weight: cProjW outSize: d bias: cProjB ].
	midHidden := (1 to: seqLen) collect: [ :i | GcTensorMath add: (inHidden at: i) and: (attnProj at: i) ].
	normed2 := midHidden collect: [ :x | GcTensorMath layerNorm: x gamma: ln2W beta: ln2B eps: eps ].
	fc := normed2 collect: [ :b | GcTensorMath mmulNoTransposeInput: b inSize: d weight: cFcW outSize: 4 * d bias: cFcB ].
	act := fc collect: [ :f | GcTensorMath geluNew: f ].
	mlpOut := act collect: [ :m | GcTensorMath mmulNoTransposeInput: m inSize: 4 * d weight: cMlpW outSize: d bias: cMlpB ].
	outHidden := (1 to: seqLen) collect: [ :i | GcTensorMath add: (midHidden at: i) and: (mlpOut at: i) ].
	(level = #residuals or: [ level = #full ]) ifTrue: [
		record := GcLayerRecord new
			layerIndex: li;
			residualIn: inHidden;
			residualMid: midHidden;
			residualOut: outHidden;
			yourself.
		level = #full ifTrue: [ record attnOut: attnProj; mlpOut: mlpOut ].
		aTrace addLayerRecord: record ].
	^ outHidden
]

{ #category : 'forward pass' }
GcGpt2Model >> attentionFrom: qkv seqLen: seqLen scale: scale [
	"Causal multi-head self-attention. qkv is a per-position 3*d Float64Array with q at [0,d), k at [d,2d), v at [2d,3d); numHeads heads of headDim each. Per query position qi and head h: scores over keys j<=qi are (q_i . k_j)*scale, softmaxed, then context = sum_j prob_j * v_j. Returns a per-position d-length Float64Array (heads concatenated), before c_proj."
	| d out |
	d := hiddenSize.
	out := Array new: seqLen.
	1 to: seqLen do: [ :qi |
		| ctx qVec |
		ctx := Float64Array new: d.
		qVec := qkv at: qi.
		0 to: numHeads - 1 do: [ :h |
			| hoff scores probs |
			hoff := h * headDim.
			scores := Float64Array new: qi.
			1 to: qi do: [ :kj |
				| kVec dot |
				kVec := qkv at: kj.
				dot := 0.0.
				1 to: headDim do: [ :t | dot := dot + ((qVec at: hoff + t) * (kVec at: d + hoff + t)) ].
				scores at: kj put: dot * scale ].
			probs := GcTensorMath softmax: scores.
			1 to: headDim do: [ :t |
				| acc |
				acc := 0.0.
				1 to: qi do: [ :kj | acc := acc + ((probs at: kj) * ((qkv at: kj) at: 2 * d + hoff + t)) ].
				ctx at: hoff + t put: acc ] ].
		out at: qi put: ctx ].
	^ out
]

{ #category : 'accessing' }
GcGpt2Model >> config [
	^ config
]

{ #category : 'accessing' }
GcGpt2Model >> eps [
	^ eps
]

{ #category : 'accessing' }
GcGpt2Model >> file [
	^ file
]

{ #category : 'forward pass' }
GcGpt2Model >> forwardTokenIds: ids [
	"Full forward pass; returns the last-position logits (no trace)."
	^ self forwardTokenIds: ids trace: nil
]

{ #category : 'forward pass' }
GcGpt2Model >> forwardTokenIds: ids trace: aTraceOrNil [
	"Full pre-norm GPT-2 forward over the 0-based token id sequence. Returns the LAST-position logits (Float64Array of size vocabSize). If aTraceOrNil is not nil, records into it at its traceLevel."
	| seqLen d wte wpe hidden scale level lnfW lnfB logits |
	seqLen := ids size.
	d := hiddenSize.
	scale := 1.0 / headDim sqrt.
	level := aTraceOrNil ifNil: [ #none ] ifNotNil: [ aTraceOrNil traceLevel ].
	wte := self weight: 'wte.weight'.
	wpe := self weight: 'wpe.weight'.
	hidden := (1 to: seqLen) collect: [ :pos |
		| tokEmb posEmb |
		tokEmb := GcTensorMath embeddingRowFrom: wte dim: d index: (ids at: pos).
		posEmb := GcTensorMath embeddingRowFrom: wpe dim: d index: pos - 1.
		GcTensorMath add: tokEmb and: posEmb ].
	0 to: numLayers - 1 do: [ :li |
		hidden := self applyBlock: li to: hidden seqLen: seqLen scale: scale trace: aTraceOrNil level: level ].
	lnfW := self weight: 'ln_f.weight'.
	lnfB := self weight: 'ln_f.bias'.
	hidden := hidden collect: [ :x | GcTensorMath layerNorm: x gamma: lnfW beta: lnfB eps: eps ].
	logits := GcTensorMath unembedHidden: hidden last dim: d table: wte vocab: vocabSize.
	aTraceOrNil ifNotNil: [ aTraceOrNil inputIds: ids asArray; finalLogits: logits ].
	^ logits
]

{ #category : 'generation' }
GcGpt2Model >> generateFromTokenIds: ids maxTokens: n [
	"Greedy generation with NO KV cache: recompute the full sequence each step, take argmax of the last-position logits, and append. Returns a GcGeneration."
	| promptIds allIds gen |
	promptIds := ids asArray.
	allIds := OrderedCollection withAll: promptIds.
	gen := GcGeneration new
		promptIds: promptIds;
		generatedIds: OrderedCollection new;
		stepLogits: OrderedCollection new;
		model: self;
		yourself.
	n timesRepeat: [
		| logits next |
		logits := self forwardTokenIds: allIds asArray.
		next := GcTensorMath argmax: logits.
		gen stepLogits add: logits.
		gen generatedIds add: next.
		allIds add: next ].
	^ gen
]

{ #category : 'accessing' }
GcGpt2Model >> headDim [
	^ headDim
]

{ #category : 'accessing' }
GcGpt2Model >> hiddenSize [
	^ hiddenSize
]

{ #category : 'initialization' }
GcGpt2Model >> initializeFile: aFile config: aConfig [
	file := aFile.
	config := aConfig.
	numLayers := aConfig numLayers.
	numHeads := aConfig numHeads.
	hiddenSize := aConfig hiddenSize.
	vocabSize := aConfig vocabSize.
	headDim := hiddenSize // numHeads.
	eps := ((aConfig at: 'layer_norm_epsilon') ifNil: [ 1.0e-5 ]) asFloat.
	weightCache := Dictionary new
]

{ #category : 'accessing' }
GcGpt2Model >> numHeads [
	^ numHeads
]

{ #category : 'accessing' }
GcGpt2Model >> numLayers [
	^ numLayers
]

{ #category : 'weights' }
GcGpt2Model >> tensorIndex [
	"A lazily-built name -> GcTensorRef map over the safetensors file (160 tensors)."
	^ tensorIndex ifNil: [
		tensorIndex := Dictionary new.
		file tensors do: [ :t | tensorIndex at: t name put: t ].
		tensorIndex ]
]

{ #category : 'weights' }
GcGpt2Model >> tensorNamed: aName [
	^ self tensorIndex at: aName ifAbsent: [ self error: 'No tensor named ', aName ]
]

{ #category : 'forward pass' }
GcGpt2Model >> tracedForwardTokenIds: ids level: aLevel [
	"Run a forward pass recording a GcForwardTrace at aLevel (#none | #residuals | #full) and return the trace."
	| trace |
	trace := GcForwardTrace new traceLevel: aLevel; yourself.
	self forwardTokenIds: ids trace: trace.
	^ trace
]

{ #category : 'weights' }
GcGpt2Model >> unloadWeights [
	"Drop the decoded-weight cache (frees ~1 GB of Float64Arrays); tensors re-decode lazily on next use."
	weightCache := Dictionary new
]

{ #category : 'accessing' }
GcGpt2Model >> vocabSize [
	^ vocabSize
]

{ #category : 'weights' }
GcGpt2Model >> weight: aName [
	"The named weight tensor decoded to a row-major Float64Array -- decoded from F32 on disk to F64 at most once, then cached."
	^ self weightCache at: aName ifAbsentPut: [ (self tensorNamed: aName) asFloatArray ]
]

{ #category : 'accessing' }
GcGpt2Model >> weightCache [
	^ weightCache ifNil: [ weightCache := Dictionary new ]
]
